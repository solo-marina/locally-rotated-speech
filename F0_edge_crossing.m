clear all
close all

%% SETTINGS
path2orig  = '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/selected_aru_wav';
path2table = '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/F0_crossing_303Hz.csv';

% The band edge to check
band_edge = 303.4;  % Hz - edge between band 2 and band 3

%% LOAD ALL WAV FILES
D = dir(fullfile(path2orig, '*.wav'));
results = table();

for i = 1:length(D)
    fname = D(i).name;
    fprintf('Processing: %s\n', fname);

    % Load audio
    [S, fs] = audioread(fullfile(path2orig, fname));
    if size(S, 2) > 1; 
        S = S(:,1);
    end

    % Extract F0 with Harvest
    f0_parameter = Harvest(S, fs);
    f0           = f0_parameter.f0;
    t_f0         = f0_parameter.temporal_positions;

    % Mask unvoiced frames
    f0_voiced        = f0;
    f0_voiced(f0_voiced == 0)   = NaN;
    f0_voiced(f0_voiced > 400)  = NaN;

    % Count crossings of band_edge
    % A crossing happens when F0 goes from below to above (or above to below)
    % the band edge between two consecutive voiced frames
    n_crossings = 0;
    crossing_times = [];

    for j = 2:length(f0_voiced)
        prev = f0_voiced(j-1);
        curr = f0_voiced(j);

        % both frames must be voiced
        if ~isnan(prev) && ~isnan(curr)
            % check if they are on opposite sides of band_edge
            if (prev < band_edge && curr >= band_edge) || ...
               (prev >= band_edge && curr < band_edge)
                n_crossings = n_crossings + 1;
                crossing_times(end+1) = t_f0(j);
            end
        end
    end

    % Sentence stats
    mean_f0   = nanmean(f0_voiced);
    median_f0 = nanmedian(f0_voiced);
    pct_above = sum(f0_voiced > band_edge, 'omitnan') / sum(~isnan(f0_voiced)) * 100;

    fprintf('  Mean F0: %.1f Hz | Crossings: %d | Pct above %.0f Hz: %.1f%%\n', ...
        mean_f0, n_crossings, band_edge, pct_above);

    % Store row
    row = table( ...
        {fname(1:end-4)}, ...
        mean_f0, ...
        median_f0, ...
        n_crossings, ...
        pct_above, ...
        {num2str(crossing_times, '%.3f ')}, ...
        'VariableNames', {'sentence', 'mean_F0', 'median_F0', 'n_crossings', 'pct_above_edge', 'crossing_times_s'} ...
    );

    results = [results; row];
    writetable(results, path2table);
end

%% SAVE
fprintf('\nSaved to: %s\n', path2table);