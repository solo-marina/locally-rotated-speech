clear all
close all

%% Paths
path2corpus = '/Users/marina-solo/Downloads/ARU_Speech_Corpus_v1_0';
path2target = '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/selected_aru_wav';
path2out    = '/Users/marina-solo/Downloads/STAGE 2026 Solo/Experiment 2/rotated babble 3.1';

if ~exist(path2out, 'dir'), mkdir(path2out); end

%% Parameters
Bandscond  = [14, 20, 24, 28, 32];
fmin       = 0;
fmax       = 8000;
SNR_dB     = 5;
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

    % --- Prepare ---
    sentence_name = D_target(i_wav).name(1:end-4);
    targetSamples = length(S);
    disp(['Processing: ' sentence_name]);

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

    %% --- Vocoding + mixing loop ---
    for i_band = 1:length(Bandscond)
        Nbands = Bandscond(i_band);
        % -- Noise rotating ------------
        N_LR = localrotating(N, fs_s, Nbands, fmin, fmax);
        N_LR = N_LR / max(abs(N_LR));
        % ── LR version ───────────────────────────────────────────────────
        S_LR = localrotating(S, fs_s, Nbands, fmin, fmax);

        % ── NV version ───────────────────────────────────────────────────
        S_NV = noisevocoding(S, fs_s, Nbands, fmin, fmax);

        S_LR_noisy = solo_SNR(S_LR, N_LR, SNR_dB, fs_s);
        S_NV_noisy = solo_SNR(S_NV, N_LR, SNR_dB, fs_s);

        audiowrite([path2out filesep sentence_name '_LR_' num2str(Nbands) 'b_LRB.wav'], S_LR_noisy, fs_s);
        disp(['  -> Saved LR ' num2str(Nbands) ' bands']);

        audiowrite([path2out filesep sentence_name '_NV_' num2str(Nbands) 'b_LRB.wav'], S_NV_noisy, fs_s);
        disp(['  -> Saved NV ' num2str(Nbands) ' bands']);
    end
end

disp('Done!');

function id = getID(f)
    [~, name] = fileparts(f);
    id = name(1:4);
end