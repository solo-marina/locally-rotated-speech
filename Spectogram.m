clear all
close all

%% SETTINGS
path2orig = '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/selected_aru_wav';
path2lr   = '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/selected_aru_wav_out_env_20';

files = {
    'ID01_ARU_Fs=65536Hz_Standard speech - List 10 - Sentence 2 - Version 1_0_standard.wav';
    'ID07_ARU_Fs=65536Hz_Standard speech - List 10 - Sentence 2 - Version 1_0_standard.wav';
    'ID09_ARU_Fs=65536Hz_Standard speech - List 10 - Sentence 2 - Version 1_0_standard.wav';
    'ID11_ARU_Fs=65536Hz_Standard speech - List 10 - Sentence 2 - Version 1_0_standard.wav';
};

talker_ids = {'ID01', 'ID07', 'ID09', 'ID11'};

Nbands = 10;
fmin   = 40;
fmax   = 7950;

%% CALCULATE ERB BAND EDGES (once, same for all files)
erb_min   = 21.4 * log10(1 + fmin / 229);
erb_max   = 21.4 * log10(1 + fmax / 229);
erb_edges = linspace(erb_min, erb_max, Nbands + 1);
freq_edges = 229 * (10.^(erb_edges / 21.4) - 1);  % back to Hz

fprintf('\n=== ERB Band Edges for %d bands ===\n', Nbands);
for b = 1:Nbands
    fprintf('  Band %2d: %6.1f Hz - %6.1f Hz\n', b, freq_edges(b), freq_edges(b+1));
end
fprintf('\nFirst band upper edge:  %.1f Hz\n', freq_edges(2));
fprintf('Second band upper edge: %.1f Hz\n\n', freq_edges(3));

%% PROCESS EACH FILE
for i = 1:length(files)
    fprintf('\n=== Processing: %s ===\n', talker_ids{i});

    % ---- LOAD ORIGINAL ----
    orig_name = files{i};
    [S_orig, fs] = audioread(fullfile(path2orig, orig_name));
    if size(S_orig, 2) > 1; S_orig = S_orig(:,1); end

    % ---- LOAD MATCHING LR_10 FILE ----
    % Build LR filename by replacing '_standard.wav' with '_standard_LR_10.wav'
    lr_name = strrep(orig_name, '_standard.wav', '_standard_LR_10.wav');
    [S_lr, fs_lr] = audioread(fullfile(path2lr, lr_name));
    if size(S_lr, 2) > 1; S_lr = S_lr(:,1); end

    % ---- F0 via HARVEST (on original) ----
    f0_parameter = Harvest(S_orig, fs);
    f0_voiced    = f0_parameter.f0;
    f0_voiced(f0_voiced == 0)   = NaN;
    f0_voiced(f0_voiced > 400)  = NaN;
    t_f0 = f0_parameter.temporal_positions;

    fprintf('  Mean F0:   %.1f Hz\n', nanmean(f0_voiced));
    fprintf('  Median F0: %.1f Hz\n', nanmedian(f0_voiced));
    fprintf('  Min F0:    %.1f Hz\n', nanmin(f0_voiced));
    fprintf('  Max F0:    %.1f Hz\n', nanmax(f0_voiced));

    % ---- GAMMATONE ENVELOPES (on LR file) ----
    [~, fc, ~, step] = king2019(S_lr, fs_lr, 1000, 'no_mfb', 'flow', 20, 'fhigh', 8000, 'no_compression');
    step.gtone_response_rec = max(step.gtone_response, 0);

    cutofffreq = 20;
    [b, a] = butter(1, cutofffreq*2/fs_lr);
    env = zeros(size(step.gtone_response_rec));
    for ii = 1:length(fc)
        env(:,ii) = filter(b, a, step.gtone_response_rec(:,ii));
    end
    t_env = (1:length(env)) / fs_lr;

    % ---- PLOT ----
    figure('Name', talker_ids{i}, 'NumberTitle', 'off', 'Position', [100 100 1000 700]);

    % --- Top panel: original spectrogram with band edges and F0 ---
    subplot(2,1,1);
    [~, fc_orig, ~, step_orig] = king2019(S_orig, fs, 1000, 'no_mfb', 'flow', 20, 'fhigh', 8000, 'no_compression');
    step_orig.gtone_response_rec = max(step_orig.gtone_response, 0);
    env_orig = zeros(size(step_orig.gtone_response_rec));
    for ii = 1:length(fc_orig)
        env_orig(:,ii) = filter(b, a, step_orig.gtone_response_rec(:,ii));
    end
    t_orig = (1:length(env_orig)) / fs;

    pcolor(t_orig, fc_orig, env_orig', 'EdgeColor', 'none');
    shading interp
    colormap jet
    hold on

    % overlay band edges
    for be = 1:length(freq_edges)
        yline(freq_edges(be), 'w--', 'LineWidth', 1);
    end

    % overlay F0
    plot(t_f0, f0_voiced, 'w-', 'LineWidth', 2);

    set(gca, 'YScale', 'log')
    ylim([20 8000])
    ylabel('Frequency (Hz)')
    xlabel('Time (s)')
    title([talker_ids{i} ' - Original + Band Edges + F0'])
    colorbar
    hold off

    % --- Bottom panel: LR spectrogram with band edges ---
    subplot(2,1,2);
    pcolor(t_env, fc, env', 'EdgeColor', 'none');
    shading interp
    colormap jet
    hold on

    % overlay band edges
    for be = 1:length(freq_edges)
        yline(freq_edges(be), 'w--', 'LineWidth', 1);
    end

    % overlay F0
    plot(t_f0, f0_voiced, 'w-', 'LineWidth', 2);

    set(gca, 'YScale', 'log')
    ylim([20 8000])
    ylabel('Frequency (Hz) - log')
    xlabel('Time (s)')
    title([talker_ids{i} ' - LR 10 bands + Band Edges + F0'])
    colorbar
    hold off

    sgtitle(talker_ids{i}, 'FontSize', 14, 'FontWeight', 'bold')
end