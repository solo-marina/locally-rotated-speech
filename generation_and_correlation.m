%% Setup
clear all
close all

path2out = '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/selected_aru_wav_out_extra';
path2orig = '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/selected_aru_wav';
path2table = '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/Correlation table 24 32.csv';

Bandscond = [14, 20, 24, 32];
results = table();
%% Loop over all original files
D_orig = dir([path2orig filesep '*.wav']);

for i_wav = 1:200
    sentence_name = D_orig(i_wav).name(1:end-4);
    disp(['Processing: ' sentence_name]);

    % Load original and run king2019
    [S_orig, fs] = audioread([D_orig(i_wav).folder filesep D_orig(i_wav).name]);
    [outsig_orig, ~] = king2019(S_orig, fs, 1000, 'no_mfb', 'flow', 20, 'fhigh', 9535, 'no_compression');

    % Loop over band conditions
    for i_band = 1:length(Bandscond)
        Nbands = Bandscond(i_band);

        % LR version
        S_LR = localrotating(S_orig, fs, Nbands, 0, 9535);
        S_LR = S_LR / max(abs(S_LR));
        fname_LR = [sentence_name '_LR_shift' num2str(Nbands) '.wav'];
        [outsig_LR, ~] = king2019(S_LR, fs, 1000, 'no_mfb', 'flow', 20, 'fhigh', 9535, 'no_compression');
        audiowrite([path2out filesep fname_LR], S_LR, fs);
        
        % Correlations
        r_LR = corr(outsig_orig(:), outsig_LR(:));
        
        disp(['  Bands=' num2str(Nbands) ' | LR_vs_Orig=' num2str(r_LR,'%.3f')]);
        
        % Store row
        row = table({[sentence_name '_' num2str(Nbands) 'bands']}, r_LR, ...
        'VariableNames', {'sentence', 'LR_vs_Original'});
        
        results = [results; row];
        
    end
end

%% Save to CSV
writetable(results, path2table);
disp(['Saved to: ' path2table]);