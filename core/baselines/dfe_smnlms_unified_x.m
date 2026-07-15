function [y_samp, d_hat_sym, e_samp, update_hist] = dfe_smnlms_unified_x(r, d, cfg, base, sigma2)
%DFE_SMNLMS_UNIFIED_X  Set-membership NLMS DFE baseline.
%
% This is the non-signed SMNLMS counterpart to dfe_smsign_nlms_unified_x.
% It updates only when |e| exceeds the noise-bound gamma and uses the
% set-membership NLMS correction factor (1 - gamma/|e|).

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
    beta = base.smnlms.beta;
    tau = base.smnlms.tau;
    eps_p = base.smnlms.eps_pow;
else
    beta = base.smsign.beta;
    tau = base.smsign.tau;
    eps_p = base.smsign.eps_pow;
end
gamma = sqrt(max(0, tau * sigma2));

for n = 1:N
    [x, r_buf, d_hat_sym, has_ref, ~, e, y] = ...
        baseline_step_common(r(n), n, r_buf, d, d_hat_sym, cfg, theta);

    y_samp(n) = y;
    e_samp(n) = e;

    if has_ref && abs(e) > gamma
        p2 = (x.' * x) + eps_p;
        mu_sm = beta * (1 - gamma / max(abs(e), eps));
        theta = theta + (mu_sm * e / p2) * x;
        theta(main_idx) = 1.0;
        update_hist(n) = true;
    end
end
end
