% Auto-split from NCKH_v53.m (original line 3779).
% Folder: core/baselines

function [y, d_hat, e, beta_hist] = dfe_smsign_nlms_vss_unified_x(r, d, cfg, base, sigma2)
% SM-sign-NLMS with variable step size (VSS-SM-sign-NLMS)
% Replaces old VSS-NLMS branch as the adaptive-step-size exogenous baseline.
%
% Update rule:
%   theta_{n+1} = theta_n + beta_n * sign(e_n) / (||x_n||^2 + eps) * x_n
%   when |e_n| > gamma_n  (set-membership gate)
%
% Variable-step adaptation (SIMPLIFIED):
%   beta_n is smoothed toward a normalized instantaneous target via EMA.
%   This is a practical simplification of the exact formula in [b5] eq(66):
%     beta_opt(k) = sqrt(2/(pi*xi)) * exp(-gamma^2/(2*xi)) * [xi-sigma_v^2_hat]/Tr[R]
%   which requires knowledge of Tr[R] and joint Gaussian assumptions.
%   The simplified EMA-based adaptation preserves the qualitative behavior:
%   faster convergence when error is large, slower in steady state.
%   For rigorous theoretical comparison, only the FIXED-beta version
%   (dfe_smsign_nlms_unified_x) is used in the Table 1 benchmarks.

    %#ok<INUSD>
    K = cfg.Nf;
    L = cfg.Nb;
    D = cfg.D;
    main_idx = cfg.D + 1;

    N = numel(r);
    y = zeros(N,1);
    e = zeros(N,1);
    d_hat = zeros(numel(d),1);
    beta_hist = zeros(N,1);

    theta = zeros(K+L,1);
    theta(main_idx) = 1.0;

    r_buf = zeros(K,1);

    beta_k   = base.smsign_vss.beta0;
    beta_min = base.smsign_vss.beta_min;
    beta_max = base.smsign_vss.beta_max;
    tau_k    = base.smsign_vss.tau;
    alpha_b  = base.smsign_vss.alpha_beta;
    eps_pow  = base.smsign_vss.eps_pow;

    for n = 1:N
        r_buf = [r(n); r_buf(1:end-1)];

        m = n - D;
        a_fb = get_fb_vector(m, d, d_hat, cfg, L);

        x = [r_buf; -a_fb];
        y(n) = theta.' * x;

        if m >= 1 && m <= numel(d)
            d_hat(m) = pam_slice_scalar(y(n), cfg.A);

            if m <= cfg.trainLen
                d_ref = d(m);
            else
                d_ref = d_hat(m);
            end

            e(n) = d_ref - y(n);

            g = (x.' * x) + eps_pow;

            % bounded-error gate
            if abs(e(n)) > tau_k
                theta = theta + (beta_k * sign(e(n)) / g) * x;
                theta(main_idx) = 1.0;
            end

            % smooth variable-step update
            eta_n = min(1.0, abs(e(n)) / (sqrt(g) + 1e-12));
            beta_target = beta_min + (beta_max - beta_min) * eta_n;
            beta_k = alpha_b * beta_k + (1 - alpha_b) * beta_target;
            beta_k = min(beta_max, max(beta_min, beta_k));
        else
            e(n) = 0;
        end

        beta_hist(n) = beta_k;
    end
end

