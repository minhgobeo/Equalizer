function [theta_final, d_hat_sym, diag] = dfe_ss_lms_pam4(r, d, cfg, v_base, opts)
%DFE_SS_LMS_PAM4  Liu-style SS-LMS PAM4 DFE baseline (algorithmic).
%
% This is an algorithmic re-implementation of the adaptive-threshold and
% adaptive-DFE-tap ideas in Liu et al. (EURASIP JASP 2023). It is NOT a
% transistor/circuit-level reproduction of their 3-stage CTLE/VGA/SatAmp/CDR
% receiver. The implementation is intended for fair symbol-rate benchmarking
% inside the same PAM4 stressed-channel testbed as the proposed receiver.
%
% v66 fixes relative to v65:
%   1) DFE feedback update uses the SAME delayed-decision buffer that was used
%      in the equalizer output. The current decision is shifted in only after
%      the tap update.
%   2) The feedback update sign is corrected for the convention
%          z(n) = h^T r_n - f^T d_hat_{n-1}.
%      Hence f <- f - mu_f*sgn(e)*sgn(d_hat_{n-1}).
%   3) Optional projection/clipping is applied to FFE/DFE taps.
%   4) Default behavior updates DFE taps only, matching the receiver-side
%      tap-adaptive DFE emphasis in Liu et al.; FFE adaptation can be enabled
%      by opts.update_ffe = true.
%   5) Equalizer-output history z_hist is logged for eye-diagram comparison.

if nargin < 5 || isempty(opts), opts = struct(); end
if ~isfield(opts,'adaptive_threshold'), opts.adaptive_threshold = false; end
if ~isfield(opts,'mu_h'),               opts.mu_h               = 1e-3; end
if ~isfield(opts,'mu_f'),               opts.mu_f               = 2e-3; end
if ~isfield(opts,'mu_thr'),             opts.mu_thr             = 2e-3; end
if ~isfield(opts,'update_ffe'),         opts.update_ffe         = false; end
if ~isfield(opts,'update_dfe'),         opts.update_dfe         = true; end
if ~isfield(opts,'use_projection'),     opts.use_projection     = true; end
if ~isfield(opts,'freeze_main_tap'),    opts.freeze_main_tap    = true; end
if ~isfield(opts,'main_tap_value'),     opts.main_tap_value     = 1; end
if ~isfield(opts,'thr_clip_margin'),    opts.thr_clip_margin    = 0.95; end

N    = numel(r);
Kffe = cfg.Nf;
L    = cfg.Nb;
D    = cfg.D;
main_idx = v_base.main_idx;

% --- FFE / DFE init ---
h = zeros(Kffe, 1);
h(main_idx) = opts.main_tap_value;
f = zeros(L, 1);

% --- PAM4 thresholds (initial = midpoints of cfg.A) ---
A   = sort(cfg.A(:));
M   = numel(A);
thr = (A(1:end-1) + A(2:end)) / 2;
thr_init = thr;

% Per-level running mean for Liu-style threshold adaptation proxy.
mu_levels = A;

% --- Buffers ---
r_buf   = zeros(Kffe, 1);
dec_buf = zeros(L, 1);      % delayed decisions used by the feedback filter
d_hat_sym = zeros(numel(d), 1);

% --- Diagnostics ---
diag = struct();
diag.thr_hist     = zeros(numel(thr), N);
diag.h_main_hist  = zeros(N, 1);
diag.h_hist       = zeros(Kffe, N);
diag.f_hist       = zeros(L, N);
diag.mu_lvl_hist  = zeros(M, N);
diag.z_hist       = zeros(N, 1);
diag.e_hist       = zeros(N, 1);
diag.d_hat_hist   = zeros(N, 1);

for n = 1:N
    r_buf = [r(n); r_buf(1:end-1)];
    m = n - D;

    % Use the delayed-decision buffer that existed BEFORE the current slice.
    dec_used = dec_buf;

    % Equalizer output. The DFE term is subtracted by convention.
    y_ffe = h.' * r_buf;
    y_dfe = f.' * dec_used;
    z     = y_ffe - y_dfe;

    % Slice with current thresholds.
    s = local_pam_slice_thr(z, A, thr);

    if m >= 1 && m <= numel(d_hat_sym)
        d_hat_sym(m) = s;
    end

    if m >= 1 && m <= numel(d)
        if m <= cfg.trainLen
            d_ref = d(m);
        else
            d_ref = s;
        end
        e = d_ref - z;
        sign_e = sign(e);

        if sign_e ~= 0
            % FFE update: z = h^T r - f^T d_prev, so h uses + sign.
            if opts.update_ffe
                h = h + opts.mu_h * sign_e .* sign(r_buf);
            end

            % DFE update: because z subtracts f^T d_prev, gradient sign is negative.
            if opts.update_dfe && L > 0
                f = f - opts.mu_f * sign_e .* sign(dec_used);
            end

            % Projection / clipping after update.
            if opts.use_projection
                [h, f] = local_project_hf(h, f, v_base, Kffe, L, main_idx, opts);
            end
        end

        % Liu-style threshold adaptation proxy. The original paper uses
        % auxiliary samplers; at symbol-rate we approximate this with slow
        % per-level running means and threshold midpoints.
        if opts.adaptive_threshold && m > round(cfg.trainLen/4)
            [~, lev_idx] = min(abs(A - d_ref));
            alpha = opts.mu_thr;
            mu_levels(lev_idx) = (1 - alpha) * mu_levels(lev_idx) + alpha * z;
            mu_levels = sort(mu_levels);
            thr = (mu_levels(1:end-1) + mu_levels(2:end)) / 2;

            % Keep thresholds inside the constellation range to avoid runaway.
            span = max(A) - min(A);
            lo = min(A) - opts.thr_clip_margin*span;
            hi = max(A) + opts.thr_clip_margin*span;
            thr = min(max(thr, lo), hi);
            thr = sort(thr);
        end

        diag.e_hist(n) = e;
    end

    % Shift current decision AFTER update; this fixes the timing mismatch.
    if L > 0
        dec_buf = [s; dec_buf(1:end-1)];
    end

    diag.thr_hist(:, n)    = thr;
    diag.h_main_hist(n)    = h(main_idx);
    diag.h_hist(:, n)      = h;
    diag.f_hist(:, n)      = f;
    diag.mu_lvl_hist(:, n) = mu_levels;
    diag.z_hist(n)         = z;
    diag.d_hat_hist(n)     = s;
end

theta_final = struct('h', h, 'f', f, 'thr', thr, 'thr_init', thr_init, ...
                     'mu_levels', mu_levels);
end

% =====================================================================
function [h, f] = local_project_hf(h, f, v_base, Kffe, L, main_idx, opts)
% Project taps using v_base bounds when available; otherwise use conservative defaults.
if isfield(v_base,'theta_min') && numel(v_base.theta_min) >= Kffe+L
    lo = v_base.theta_min(:);
    hi = v_base.theta_max(:);
    theta = [h(:); f(:)];
    theta = min(max(theta, lo), hi);
    h = theta(1:Kffe);
    f = theta(Kffe+1:Kffe+L);
else
    h = min(max(h, -1.5), 1.5);
    f = min(max(f, -1.5), 1.5);
end

% For this Liu-style baseline, the main forward path is normally fixed.
if opts.freeze_main_tap
    h(main_idx) = opts.main_tap_value;
end
end

% =====================================================================
function s = local_pam_slice_thr(z, A, thr)
% Slice a scalar z to one of A's levels using thresholds thr.
if z < thr(1)
    s = A(1); return;
end
for k = 1:numel(thr)-1
    if z < thr(k+1)
        s = A(k+1); return;
    end
end
s = A(end);
end
