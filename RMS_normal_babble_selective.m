clear all
close all

%% Paths
path2corpus = '/Users/marina-solo/Downloads/ARU_Speech_Corpus_v1_0';
path2target = '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/selected_aru_wav';
path2out    = '/Users/marina-solo/Downloads/STAGE 2026 Solo/Experiment 2/normal babble SNR 13';

if ~exist(path2out, 'dir'), mkdir(path2out); end

%% Parameters
Bandscond  = [14, 20, 24, 28, 32];
fmin       = 0;
fmax       = 8000;
SNR_dB     = 13;
trimSec    = 0.05;
fadeSec    = 0.05;
validLists = 31:72;

%% Chunk patterns
chunkPatterns = {
    [1, 1, 1, 1, 1],
    [2.5, 2.5],
    [3, 2],
    [2, 2, 1],
    [1, 2, 2],
    [1.5, 2.5, 1],
    [1.5, 1.5, 1, 1],
    [1, 3, 1],
    [2, 3],
    [1, 1, 1, 2],
    [2.5, 2.5],
};

%% Scan CSVs for required NB files
csvFiles = dir(fullfile('/Users/marina-solo/Downloads/STAGE 2026 Solo/trials_all', '*.csv'));
neededFiles = {};
for c = 1:length(csvFiles)
    T = readtable(fullfile(csvFiles(c).folder, csvFiles(c).name), 'TextType', 'string');
    for col = 1:width(T)
        vals = string(T{:, col});
        if ~any(contains(vals, '_NB'),'all'), continue; end
        matches = vals(endsWith(vals, '_NB.mp3') | endsWith(vals, '_NB.wav') | endsWith(vals, '_NB'));
        % Extract just the filename, strip folder prefix like 'audio/'
        matches = arrayfun(@(f) regexp(f, '[^/\\]+$', 'match', 'once'), matches);
        % Strip extension
        matches = regexprep(matches, '\.(mp3|wav)$', '');
        neededFiles = [neededFiles; cellstr(matches(strlength(matches) > 0))];
    end
end
neededFiles = unique(neededFiles);
neededBase = neededFiles;  % e.g. 'ID03_L10_S7_LR_24b_NB', 'ID03_L10_S7_NV_24b_NB', etc.
disp(['CSV scan: ' num2str(length(neededBase)) ' unique NB files required.']);

%% Filter corpus to Lists 31-72
allFiles = dir(fullfile(path2corpus, '*.wav'));
filtered = {};
for i = 1:length(allFiles)
    tok = regexp(allFiles(i).name, 'List\s+(\d+)', 'tokens', 'once');
    if ~isempty(tok) && ismember(str2double(tok{1}), validLists)
        filtered{end+1} = fullfile(path2corpus, allFiles(i).name);
    end
end

allSpeakers = unique(cellfun(@(f) getID(f), filtered, 'UniformOutput', false));

%% Get corpus sample rate
[~, fs] = audioread(filtered{1});

%% Load target files
D_target = dir(fullfile(path2target, '*.wav'));

%% Main loop
for i_wav = 1:length(D_target)

    % --- Load target ---
    [S, fs_s] = audioread(fullfile(D_target(i_wav).folder, D_target(i_wav).name));
    if size(S, 2) > 1, S = mean(S, 2); end

    % --- Ensure at least 0.7s silence before first voiced fragment ---
    silenceSamples = round(0.7 * fs_s);

    noise_floor  = 0.01 * max(abs(S));
    first_voiced = find(abs(S) > noise_floor, 1, 'first');

    if isempty(first_voiced)
        first_voiced = length(S);
    end

    if first_voiced < silenceSamples
        padSamples = silenceSamples - first_voiced + 1;
        S          = [zeros(padSamples, 1); S];
        disp('  -> Padded leading silence to 0.7s');
    else
        disp('  -> Already has 0.7s leading silence');
    end

    % --- Ensure at least 0.5s silence after last voiced fragment ---
    silenceSamples = round(0.5 * fs_s);
    noise_floor    = 0.01 * max(abs(S));

    last_voiced = find(abs(S) > noise_floor, 1, 'last');
    if isempty(last_voiced)
        last_voiced = 1;
    end

    trailingSilence = length(S) - last_voiced;

    if trailingSilence < silenceSamples
        padSamples = silenceSamples - trailingSilence;
        S = [S; zeros(padSamples, 1)];
        disp('  -> Padded trailing silence to 0.5s');
    else
        disp('  -> Already has 0.5s trailing silence');
    end

    % --- Prepare ---
    sentence_name = D_target(i_wav).name(1:end-4);
    targetSamples = length(S);
    disp(['Processing: ' sentence_name]);

    % --- Check if any band/version is needed for this sentence ---
    anyNeeded = false;
    for i_band = 1:length(Bandscond)
        Nbands = Bandscond(i_band);
        if any(strcmp(neededBase, [sentence_name '_NV_' num2str(Nbands) 'b_NB'])) || ...
           any(strcmp(neededBase, [sentence_name '_LR_' num2str(Nbands) 'b_NB']))
            anyNeeded = true;
            break
        end
    end
    if ~anyNeeded
        disp('  -> No versions needed for this sentence, skipping.');
        continue
    end

    % --- Remove target speaker from masker list ---
    targetSpk    = sentence_name(1:4);
    maskerSpks   = allSpeakers(~strcmp(allSpeakers, targetSpk));
    extraIdx     = randperm(length(maskerSpks), 20 - length(maskerSpks));
    speakerOrder = [1:length(maskerSpks), extraIdx];

    % --- Build 5.5-sec babble masker ---
    fiveSecSamples = max(round(5.5 * fs), targetSamples);
    finalMix       = zeros(fiveSecSamples, 1);

    for track = 1:20
        spkIdx   = speakerOrder(track);
        pattern  = chunkPatterns{mod(track-1, length(chunkPatterns))+1};
        spkFiles = filtered(cellfun(@(f) strcmp(getID(f), maskerSpks{spkIdx}), filtered));

        trackAudio = [];

        for j = 1:length(pattern)
            chunkSamples = round(pattern(j) * fs);
            trimSamples  = round(trimSec * fs);

            randFile    = spkFiles{randi(length(spkFiles))};
            [Y_mask, ~] = audioread(randFile);
            if size(Y_mask, 2) > 1, Y_mask = mean(Y_mask, 2); end
            Y_mask = Y_mask(trimSamples+1 : end-trimSamples);

            while length(Y_mask) < chunkSamples
                [y2, ~] = audioread(spkFiles{randi(length(spkFiles))});
                if size(y2, 2) > 1, y2 = mean(y2, 2); end
                y2     = y2(trimSamples+1 : end-trimSamples);
                Y_mask = [Y_mask; y2];
            end

            maxStart = length(Y_mask) - chunkSamples;
            startIdx = randi(max(maxStart, 1));
            chunk    = Y_mask(startIdx : startIdx + chunkSamples - 1);

            Lf      = round(fadeSec * fs);
            L       = length(chunk);
            fadeIn  = sin(linspace(0, pi/2, Lf))';
            fadeOut = fadeIn(end:-1:1);
            FadEnv  = [fadeIn; ones(L - 2*Lf, 1); fadeOut];
            chunk   = chunk .* FadEnv;

            trackAudio = [trackAudio; chunk];
        end

        if length(trackAudio) > fiveSecSamples
            trackAudio = trackAudio(1:fiveSecSamples);
        else
            trackAudio = [trackAudio; zeros(fiveSecSamples - length(trackAudio), 1)];
        end

        finalMix = finalMix + trackAudio;
    end

    % Trim babble to target length and peak normalise
    N      = finalMix(1:targetSamples);
    N      = N / max(abs(N));

    %% --- Vocoding + mixing loop ---
    for i_band = 1:length(Bandscond)
        Nbands = Bandscond(i_band);

        outName_NV = [sentence_name '_NV_' num2str(Nbands) 'b_NB'];
        outName_LR = [sentence_name '_LR_' num2str(Nbands) 'b_NB'];

        needNV = any(strcmp(neededBase, outName_NV));
        needLR = any(strcmp(neededBase, outName_LR));

        if ~needNV && ~needLR
            disp(['  -> Skipping ' num2str(Nbands) ' bands (not in CSVs)']);
            continue
        end

        % ── LR version ───────────────────────────────────────────────────
        if needLR
            S_LR = localrotating(S, fs_s, Nbands, fmin, fmax);
            S_LR_noisy = solo_SNR(S_LR, N, SNR_dB, fs_s);
            audiowrite([path2out filesep outName_LR '.wav'], S_LR_noisy, fs_s);
            disp(['  -> Saved LR ' num2str(Nbands) ' bands']);
        end

        % ── NV version ───────────────────────────────────────────────────
        if needNV
            S_NV = noisevocoding(S, fs_s, Nbands, fmin, fmax);
            S_NV_noisy = solo_SNR(S_NV, N, SNR_dB, fs_s);
            audiowrite([path2out filesep outName_NV '.wav'], S_NV_noisy, fs_s);
            disp(['  -> Saved NV ' num2str(Nbands) ' bands']);
        end
    end
end

disp('Done!');

function id = getID(f)
    [~, name] = fileparts(f);
    id = name(1:4);
end