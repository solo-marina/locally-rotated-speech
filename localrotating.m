function [LR] = localrotating(S, fs, Nbands, fmin, fmax)
% localrotating - A function to perform local rotation on an input signal.
% 
% Syntax: LR = localrotating(S, fs, Nbands, fmin, fmax)
%
% Inputs:
%   S      - Input signal to be processed.
%   fs     - Sampling frequency of the input signal.
%   Nbands  - Number of frequency bands.
%   fmin   - Minimum frequency for the bands (optional, default is 40 Hz).
%   fmax   - Maximum frequency for the bands (optional, default is 7950 Hz).
%
% Outputs:
%   LR     - Locally rotated output signal.
%
% Description:
%   This function decomposes the input signal into multiple frequency bands
%   using the ERB scale, rotates each band (i.e. low frequencies become
%   high frequency and the other way around), and reconstructs the
%   locally-rotated signal. The function also allows for optional
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

%% decompose into Nbands

Sfilt = bandfiltering(S, fs, bands);

LR = zeros(size(S));

%% rotating band

t = (1:length(S))/fs;
for i_band = 1:Nbands

    flow = bands(i_band);
    fhigh = bands(i_band+1);
    modul = sin(2*pi*t*(fhigh+flow));
    Sdub = Sfilt(:,i_band).*modul';

    fD = fft(Sdub);
    f = fs*(1:length(S))/length(S);
    fD(f>fhigh & f<fs-fhigh) = 0;
    fD(f<flow | f>fs-flow) = 0;
    Srotband = real(ifft(fD));
    LR = LR + Srotband;
end

end