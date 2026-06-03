function [mix] = solo_SNR(T, N, SNR_dB, fs)
% solo_SNR is a function that claculates the RMS of the voiced fragments of the file and mixes a target signal with noise at a desired SNR.
%
% Syntax: mix = solo_SNR(T, N, SNR_dB, fs)
%
% Inputs:
%   T      - Target signal .
%   N      - Noise signal.
%   SNR_dB - Desired SNR in dB.
%   fs     - Sampling frequency (Hz).
%
% Output:
%   mix - Mixed signal at the desired SNR, peak-normalised.

% ── Voiced envelope filter (30 Hz low-pass Butterworth) ──────────────
cutoff = 30;
order  = 4;
[b, a] = butter(order, cutoff / (fs/2), 'low');

% ── Voiced mask on target ─────────────────────────────────────────────
voiced_envelope = filtfilt(b, a, max(T, 0));
voiced_mask     = voiced_envelope > 0.1 * max(voiced_envelope);
voiced_samples  = T(voiced_mask);

if isempty(voiced_samples)
    warning('solo_SNR: no voiced samples found in target signal.');
    mix = [];
    return
end

% ── RMS calculations ─────────────────────────────────────────────────
rms_voiced = sqrt(mean(voiced_samples .^ 2));
rms_noise  = sqrt(mean(N .^ 2));

% ── Scale target and mix ──────────────────────────────────────────────
A   = 10^((SNR_dB - log10(rms_voiced^2 / rms_noise^2)*10) / 20);
mix = A * T + N;
rms_mix  = sqrt(mean(mix .^ 2));
mix = 0.05*(mix / rms_mix);