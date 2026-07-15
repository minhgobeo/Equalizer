function [tail, info] = build_8023ck_ref_residual_tail(Ntaps_residual, il_offset_dB)
%BUILD_8023CK_REF_RESIDUAL_TAIL  Residual ISI tail from IEEE 802.3ck IL_max.
%
% [tail, info] = build_8023ck_ref_residual_tail(Ntaps_residual, il_offset_dB)
%
% Returns Ntaps_residual symbol-rate post-cursor taps derived from the
% IEEE P802.3ck baseline insertion-loss specification:
%
%   IL_max(f) = 0.05 + 1.8*sqrt(f) + 0.2513*f       (0.01 <= f <= 26.56 GHz)
%   IL_max(f) = -12.4192 + 1.07*f                   (26.56 < f <= 53.125 GHz)
%
% Source: IEEE P802.3ck baseline proposal, Annex 120E,
%         "100GAUI-1, 200GAUI-2, 400GAUI-4 C2M PAM4 Channel Insertion-Loss Limit",
%         Vancouver, March 2019. Slide 7.
%   https://www.ieee802.org/3/ck/public/19_03/li_3ck_02b_0319.pdf
%
% Inputs:
%   Ntaps_residual : number of post-cursor taps to return  (default 5)
%   il_offset_dB   : dB margin from the spec limit         (default 6)
%                    0  -> worst-case IL_max channel (max stress)
%                    6  -> moderate-loss channel typical of compliant links
%                    10 -> low-loss channel, light stress
%
% Outputs:
%   tail : Ntaps_residual x 1 vector, normalised so main tap = 1
%   info : metadata struct with IL values, source citation, and method
%
% Methodology:
%   1. Sample IL_max(f) on a fine frequency grid 0..fs/2 with fs = 4*fb.
%   2. Subtract il_offset_dB to model a channel inside (not at) the spec limit.
%   3. Convert to magnitude response and reconstruct minimum-phase IR via
%      cepstral method (no Signal Processing Toolbox dependency).
%   4. IFFT to time domain, decimate to symbol rate fb = 53.125 GBd.
%   5. Locate main tap, return Ntaps_residual post-cursor taps,
%      normalised to unit main tap.

if nargin < 1 || isempty(Ntaps_residual), Ntaps_residual = 5; end
if nargin < 2 || isempty(il_offset_dB),   il_offset_dB   = 6; end

% --- 1. Frequency grid ---
fb_GHz     = 53.125;
oversample = 4;
fs_GHz     = fb_GHz * oversample;
NFFT       = 4096;
f_pos      = (0:NFFT/2)' * fs_GHz / NFFT;     % positive freqs, GHz

% --- 2. IL_max profile (dB) ---
IL_dB = zeros(size(f_pos));
m1 = (f_pos >= 0.01) & (f_pos <= 26.56);
m2 = (f_pos > 26.56) & (f_pos <= 53.125);
IL_dB(m1) = 0.05 + 1.8*sqrt(f_pos(m1)) + 0.2513*f_pos(m1);
IL_dB(m2) = -12.4192 + 1.07*f_pos(m2);

m0 = f_pos < 0.01;
if any(m0)
    IL_dB(m0) = IL_dB(find(m1,1,'first'));
end
m3 = f_pos > 53.125;
if any(m3)
    IL_dB(m3) = IL_dB(find(m2,1,'last'));
end

% --- 3. Apply margin offset and cap ---
IL_dB = max(IL_dB - il_offset_dB, 0);    % keep IL >= 0 (no gain at DC)
IL_dB = min(IL_dB, 60);                  % cap to avoid log(0)

% --- 4. Magnitude response, two-sided real symmetric ---
H_mag_pos  = 10.^(-IL_dB/20);
H_mag_full = [H_mag_pos; flipud(H_mag_pos(2:end-1))];
log_mag    = log(H_mag_full + 1e-12);

% --- 5. Minimum-phase reconstruction via cepstrum (no toolbox) ---
c = real(ifft(log_mag));
n = NFFT;
c_min = zeros(n,1);
c_min(1)         = c(1);
c_min(2:n/2)     = 2*c(2:n/2);
c_min(n/2+1)     = c(n/2+1);
log_H_min = fft(c_min);
H_min     = exp(log_H_min);

% --- 6. Time-domain IR ---
h_t = real(ifft(H_min));

% --- 7. Decimate to symbol rate ---
h_sym = h_t(1:oversample:end);

% --- 8. Locate main tap, extract post-cursors ---
[~, idx_main] = max(abs(h_sym));
last = min(idx_main + Ntaps_residual, numel(h_sym));
post_cursor = h_sym(idx_main+1 : last);
if numel(post_cursor) < Ntaps_residual
    post_cursor(end+1 : Ntaps_residual) = 0;
end

% --- 9. Normalise ---
tail = post_cursor / h_sym(idx_main);
tail = tail(:);

% --- 10. Diagnostics ---
info = struct();
info.fb_GHz             = fb_GHz;
info.oversample         = oversample;
info.NFFT               = NFFT;
info.il_offset_dB       = il_offset_dB;
info.IL_dB_at_Nyquist   = interp1(f_pos, IL_dB, fb_GHz/2, 'linear', 'extrap');
info.IL_dB_at_fb        = interp1(f_pos, IL_dB, fb_GHz,    'linear', 'extrap');
info.main_tap_value     = h_sym(idx_main);
info.main_tap_index     = idx_main;
info.Ntaps_residual     = Ntaps_residual;
info.formula_source     = 'IEEE P802.3ck baseline proposal, Vancouver March 2019, Annex 120E IL_max';
info.url                = 'https://www.ieee802.org/3/ck/public/19_03/li_3ck_02b_0319.pdf';
info.phase_method       = 'minimum-phase via real cepstrum';
info.note               = sprintf(['IL_max profile with %.0f dB margin from spec limit. ' ...
                                   'Tail is the residual post-cursor beyond the main tap, ' ...
                                   'normalised to unity main tap.'], il_offset_dB);
end
