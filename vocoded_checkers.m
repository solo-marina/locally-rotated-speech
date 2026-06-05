function [NV_checkers] = vocoded_checkers(S, fs, Nbands, fmin, fmax)
% localrotating - A function to perform a diabolical local rotation on an input signal.
%
% Syntax: LR = vocoded_checkers(S, fs, Nbands, fmin, fmax)
%
% Inputs:
%   S      - Input signal to be processed.
%   fs     - Sampling frequency of the input signal.
%   Nbands  - Number of frequency bands.
%   fmin   - Minimum frequency for the bands (optional, default is 40 Hz).
%   fmax   - Maximum frequency for the bands (optional, default is 7950 Hz).
%
% Outputs:
%   NV_checkers     - Locally rotated output signal.
%
% Description:
%   This function decomposes the input signal into multiple frequency bands
%   using the ERB scale, noise-vocodes each band (i.e. low frequencies become
%   high frequency and the other way around), and reconstructs the
%   locally-rotated signal. The function also allows for optional
%   specification of the minimum and maximum frequencies for the bands.
%   Odd bands are replaced with band-limited white noise.
%
% Marina Solo - 2026

if nargin < 4
    fmin = 40;
end
if nargin < 5
    fmax = 7950;
end

[bands, erb] = erbspace(fmin, fmax, Nbands+1);

%% decompose into Nbands
Sfilt = bandfiltering(S, fs, bands);
NV = zeros(size(S));

%% Modulating band

N     = randn(size(S));
Nfilt = bandfiltering(N, fs, bands);
[B,A] = butter(2, 20/(fs/2));

for i_band = 1:Nbands

    if mod(i_band, 2) == 0
        % Noise vocoding
        rectified_signal = abs(Sfilt(:, i_band));
        envelope = filter(B, A, rectified_signal);
        band_out = Nfilt(:, i_band) .* envelope;
        rms_out  = sqrt(mean(band_out .^ 2));
        rms_band = sqrt(mean(Sfilt(:, i_band) .^ 2));
        band_out = band_out * (rms_band / rms_out);
        
    else
        % Band-limited noise at the same band
        band_out = Nfilt(:, i_band);
        rms_out  = sqrt(mean(band_out .^ 2));
        rms_band = sqrt(mean(Sfilt(:, i_band) .^ 2));
        band_out = band_out * (rms_band / rms_out)*0.5;
    end
    NV = NV + band_out; % accumulate every band
end
NV_checkers = NV;
end