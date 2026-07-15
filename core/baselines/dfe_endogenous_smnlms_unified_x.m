function [y_samp, d_hat_sym, e_samp, update_hist, diag] = ...
    dfe_endogenous_smnlms_unified_x(r, d, cfg, base, sigma2, opts)
%DFE_ENDOGENOUS_SMNLMS_UNIFIED_X  Endogenous-bias-aware SMNLMS DFE.
%
% This is a single-bank ablation used to connect the endogenous DD-bias
% theory to the full MSB receiver.  It keeps the same DFE regressor as
% NLMS/SMNLMS, but inflates the set-membership bound and reduces the update
% step in uncertain decision-directed samples.

if nargin < 6 || isempty(opts), opts = struct(); end

N = numel(r);
K = cfg.Nf;
L = cfg.Nb;
main_idx = cfg.D + 1;

theta = zeros(K+L,1);
theta(main_idx) = 1.0;
r_buf = zeros(K,1);

y_samp = zeros(N,1);
e_samp = zeros(N,1);
update_hist = false(N,1);
d_hat_sym = zeros(numel(d),1);

if isfield(base, 'smnlms')
    beta0 = base.smnlms.beta;
    tau = base.smnlms.tau;
    eps_p = base.smnlms.eps_pow;
else
    beta0 = base.smsign.beta;
    tau = base.smsign.tau;
    eps_p = base.smsign.eps_pow;
end

lambda_margin = local_get(opts, 'lambda_margin', 1.25);
lambda_dd = local_get(opts, 'lambda_dd', 0.75);
lambda_residual = local_get(opts, 'lambda_residual', 0.50);
gamma_max_scale = local_get(opts, 'gamma_max_scale', 3.0);
gamma_base_scale = local_get(opts, 'gamma_base_scale', 1.0);
gamma_base_low = local_get(opts, 'gamma_base_low', gamma_base_scale);
gamma_base_high = local_get(opts, 'gamma_base_high', gamma_base_scale);
noise_ref = local_get(opts, 'noise_ref', inf);
beta_min_scale = local_get(opts, 'beta_min_scale', 0.35);
beta_boost = local_get(opts, 'beta_boost', 1.0);
beta_boost_low = local_get(opts, 'beta_boost_low', beta_boost);
beta_boost_high = local_get(opts, 'beta_boost_high', beta_boost);
sign_mix_max = local_get(opts, 'sign_mix_max', 0.0);
lambda_sign = local_get(opts, 'lambda_sign', 0.0);
sign_gamma_ref = local_get(opts, 'sign_gamma_ref', inf);
ema_alpha = local_get(opts, 'ema_alpha', 0.98);
update_mode = lower(local_get(opts, 'update_mode', 'smnlms'));
% Experimental branch kept for reproducibility notes only.  Final Block-C
% results use the default legacy endogenous-aware gate unless opts.variant
% explicitly requests 'gazor_sayed'/'selfcal'/'self_calibrated'.
variant = lower(local_get(opts, 'variant', 'legacy'));
use_gazor_sayed = any(strcmp(variant, {'gazor_sayed','selfcal','self_calibrated'}));
bound_alpha = local_get(opts, 'bound_alpha', 0.995);
bound_kappa = local_get(opts, 'bound_kappa', 1.10);
bound_clip_scale = local_get(opts, 'bound_clip_scale', 3.5);
gamma_floor_scale = local_get(opts, 'gamma_floor_scale', 0.30);
gamma_ceil_scale = local_get(opts, 'gamma_ceil_scale', 1.55);
reliability_floor = local_get(opts, 'reliability_floor', 0.35);
sign_gamma_scale = local_get(opts, 'sign_gamma_scale', 1.0);

gamma_raw = sqrt(max(0, tau * sigma2));
noise_level = min(1, gamma_raw / max(noise_ref, eps));
gamma_base_eff = gamma_base_high - (gamma_base_high - gamma_base_low) * noise_level;
beta_boost_eff = beta_boost_high + (beta_boost_low - beta_boost_high) * noise_level;
gamma0 = gamma_base_eff * gamma_raw;
res_ema = gamma0^2;
abs_err_ema = max(gamma0, eps);

diag = struct();
diag.gamma_hist = zeros(N,1);
diag.beta_scale_hist = zeros(N,1);
diag.margin_hist = zeros(N,1);
diag.endogenous_burden_hist = zeros(N,1);
diag.sign_mix_hist = zeros(N,1);
diag.self_bound_hist = zeros(N,1);
diag.reliability_hist = zeros(N,1);
diag.shadow_select_hist = false(N,1);

for n = 1:N
    [x, r_buf, d_hat_sym, has_ref, d_des, e, y] = ...
        baseline_step_common(r(n), n, r_buf, d, d_hat_sym, cfg, theta);

    y_samp(n) = y;
    e_samp(n) = e;

    if ~has_ref
        continue;
    end

    m = n - cfg.D;
    is_dd = m > cfg.trainLen;
    margin = local_pam_margin(y, cfg.A);
    res_ema = ema_alpha * res_ema + (1 - ema_alpha) * e^2;

    uncertainty = 1 / (1 + margin / max(gamma0, eps));
    residual_load = sqrt(res_ema) / max(gamma0, eps);
    burden = lambda_margin * uncertainty + ...
        lambda_dd * double(is_dd) + ...
        lambda_residual * max(0, residual_load - 1);
    burden = max(0, burden);

    gamma_eff = gamma0 * min(gamma_max_scale, 1 + burden);
    beta_scale = max(beta_min_scale, 1 / (1 + burden));
    beta_eff = beta0 * beta_boost_eff * beta_scale;
    sign_noise_scale = min(1, gamma0 / max(sign_gamma_ref, eps));
    sign_mix = min(sign_mix_max, lambda_sign * burden / (1 + burden)) * sign_noise_scale;

    if use_gazor_sayed
        % Gazor-style self-calibrated bound: estimate a slowly varying
        % effective disturbance magnitude from clipped error magnitudes.
        % Sayed-style error nonlinearity: scale the step by a reliability
        % factor rather than only by |e|, which reduces wrong DD updates.
        clipped_abs_e = min(abs(e), bound_clip_scale * max(gamma0, eps));
        if ~is_dd || margin > gamma0
            abs_err_ema = bound_alpha * abs_err_ema + (1 - bound_alpha) * clipped_abs_e;
        else
            abs_err_ema = bound_alpha * abs_err_ema + ...
                (1 - bound_alpha) * min(clipped_abs_e, abs_err_ema);
        end
        gamma_self = bound_kappa * abs_err_ema;
        gamma_self = min(gamma_ceil_scale * max(gamma_raw, eps), ...
            max(gamma_floor_scale * max(gamma_raw, eps), gamma_self));
        reliability = margin / (margin + gamma_self + eps);
        residual_load_self = sqrt(res_ema) / max(gamma_self, eps);
        burden = lambda_margin * (1 - reliability) + ...
            lambda_dd * double(is_dd) * (1 - reliability) + ...
            lambda_residual * max(0, residual_load_self - 1);
        burden = max(0, burden);
        gamma_eff = gamma_self * min(gamma_max_scale, 1 + burden);
        beta_scale = max(beta_min_scale, ...
            (reliability_floor + (1 - reliability_floor) * reliability) / (1 + 0.25*burden));
        beta_eff = beta0 * beta_boost_eff * beta_scale;
        sign_mix = min(sign_mix_max, lambda_sign * (1 - reliability) * ...
            min(1, abs(e) / max(gamma_eff, eps)));
    else
        reliability = 1 - uncertainty;
    end

    diag.gamma_hist(n) = gamma_eff;
    diag.beta_scale_hist(n) = beta_scale;
    diag.margin_hist(n) = margin;
    diag.endogenous_burden_hist(n) = burden;
    diag.sign_mix_hist(n) = sign_mix;
    diag.self_bound_hist(n) = abs_err_ema;
    diag.reliability_hist(n) = reliability;

    p2 = (x.' * x) + eps_p;
    switch update_mode
        case {'nlms','always','endogenous_nlms'}
            robust_innov = local_robust_innov(e, gamma_eff, sign_gamma_scale, use_gazor_sayed);
            innov = (1 - sign_mix) * e + sign_mix * robust_innov;
            theta = theta + (beta_eff * innov / p2) * x;
            theta(main_idx) = 1.0;
            update_hist(n) = true;
        otherwise
            if abs(e) > gamma_eff
        sm_innov = (1 - gamma_eff / max(abs(e), eps)) * e;
        robust_innov = local_robust_innov(e, gamma_eff, sign_gamma_scale, use_gazor_sayed);
        innov = (1 - sign_mix) * sm_innov + sign_mix * robust_innov;
        theta = theta + (beta_eff * innov / p2) * x;
        theta(main_idx) = 1.0;
        update_hist(n) = true;
            end
    end
end

if local_get(opts, 'use_shadow_smnlms_select', false)
    [y_shadow, d_shadow] = dfe_smnlms_unified_x(r, d, cfg, base, sigma2);
    guard = local_get(opts, 'shadow_margin_guard', 0.0);
    for m = max(1,cfg.trainLen+1):min(numel(d), N-cfg.D)
        n = m + cfg.D;
        margin_main = local_pam_margin(y_samp(n), cfg.A);
        margin_shadow = local_pam_margin(y_shadow(n), cfg.A);
        if margin_shadow > margin_main + guard
            y_samp(n) = y_shadow(n);
            d_hat_sym(m) = d_shadow(m);
            e_samp(n) = d_hat_sym(m) - y_samp(n);
            diag.shadow_select_hist(n) = true;
        end
    end
end

if local_get(opts, 'use_shadow_smsign_select', false)
    [y_shadow, d_shadow] = dfe_smsign_nlms_unified_x(r, d, cfg, base, sigma2);
    guard = local_get(opts, 'shadow_smsign_margin_guard', 0.0);
    for m = max(1,cfg.trainLen+1):min(numel(d), N-cfg.D)
        n = m + cfg.D;
        margin_main = local_pam_margin(y_samp(n), cfg.A);
        margin_shadow = local_pam_margin(y_shadow(n), cfg.A);
        if margin_shadow > margin_main + guard
            y_samp(n) = y_shadow(n);
            d_hat_sym(m) = d_shadow(m);
            e_samp(n) = d_hat_sym(m) - y_samp(n);
            diag.shadow_select_hist(n) = true;
        end
    end
end
end

function v = local_get(s, name, def)
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = def;
end
end

function margin = local_pam_margin(y, A)
A = sort(A(:));
if numel(A) < 2
    margin = abs(y);
    return;
end
thr = (A(1:end-1) + A(2:end)) / 2;
margin = min(abs(y - thr));
end

function innov = local_robust_innov(e, gamma_eff, sign_gamma_scale, use_scaled_sign)
if use_scaled_sign
    innov = sign_gamma_scale * max(gamma_eff, eps) * sign(e);
else
    innov = sign(e);
end
end
