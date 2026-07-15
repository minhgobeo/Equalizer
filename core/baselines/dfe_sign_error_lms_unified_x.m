function [y_samp, d_hat_sym, e_samp, update_hist] = dfe_sign_error_lms_unified_x(r, d, cfg, base)
%DFE_SIGN_ERROR_LMS_UNIFIED_X  Sign-error LMS DFE baseline.
%
% This baseline represents the canonical error-nonlinearity family used in
% transient analyses of adaptive filters: the innovation is sign(e), with no
% input-power normalization and no set-membership censoring.  The FFE/DFE
% regressor is identical to the other unified baselines.

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

if isfield(base, 'mu_sign_lms')
    mu = base.mu_sign_lms;
elseif isfield(base, 'mu_lms')
    mu = base.mu_lms;
else
    mu = 1e-3;
end

for n = 1:N
    [x, r_buf, d_hat_sym, has_ref, ~, e, y] = ...
        baseline_step_common(r(n), n, r_buf, d, d_hat_sym, cfg, theta);

    y_samp(n) = y;
    e_samp(n) = e;

    if has_ref
        theta = theta + mu * sign(e) * x;
        theta(main_idx) = 1.0;
        update_hist(n) = true;
    end
end
end
