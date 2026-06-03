function [NV] = noisevocoding(S, fs, Nbands, fmin, fmax)
% noisevocoding - A function to perform noise vocoding on an input signal.
% 
% Syntax: NV = noisevocoding(S, fs, Nbands, fmin, fmax)
%
% Inputs:
%   S      - Input signal to be vocoded.
%   fs     - Sampling frequency of the input signal.
%   Nbands  - Number of frequency bands for vocoding.
%   fmin   - Minimum frequency for the vocoding bands (optional, default is 40 Hz).
%   fmax   - Maximum frequency for the vocoding bands (optional, default is 7950 Hz).
%
% Outputs:
%   NV     - Vocoded output signal.
%
% Description:
%   This function decomposes the input signal into multiple frequency bands
%   using the ERB scale, modulates noise with the signal envelope, and 
%   reconstructs the vocoded signal. The function also allows for optional
%   specification of the minimum and maximum frequencies for the bands.
%
% Leo Varnet - 2025

if nargin < 4
    fmin = 40;
end
if nargin < 5
    fmax = 7950;
end

[bands, erb] = erbspace(fmin, fmax, Nbands+1);
N = randn(size(S));

%% decompose into Nbands

Sfilt = bandfiltering(S, fs, bands);

%% decompose noise similarly

Nfilt = bandfiltering(N, fs, bands);

%% Modulate noise with signal envelope using rectification and low pass filtering

NVfilt = zeros([length(N),Nbands]);
[B,A] = butter(2,20/(fs/2));
for i_band = 1:Nbands
    rectified_signal = abs(Sfilt(:,i_band)); % Rectify the signal
    envelope = filter(B,A, rectified_signal); % Low pass filter the rectified signal
    NVfilt(:,i_band) = Nfilt(:,i_band) .* envelope; % Modulate noise with the rectified envelope
end

NV = sum(NVfilt,2);

end