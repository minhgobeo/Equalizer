% Auto-split from NCKH_v53.m (original line 3862).
% Folder: core/baselines

function [y_samp, d_hat_sym, e_samp] = dfe_smsign_nlms_unified_x(r, d, cfg, base, sigma2)
% Fixed-step SM-sign-NLMS baseline with fair K-tap/L-tap regressor.

    N = numel(r);
    K = cfg.Nf;
    L = cfg.Nb;
    main_idx = cfg.D + 1;

    theta = zeros(K+L,1);
    theta(main_idx) = 1.0;

    r_buf = zeros(K,1);

    y_samp    = zeros(N,1);
    e_samp    = zeros(N,1);
    d_hat_sym = zeros(numel(d),1);

    beta  = base.smsign.beta;
    tau   = base.smsign.tau;
    eps_p = base.smsign.eps_pow;
    gamma = sqrt(max(0, tau * sigma2));

    for n = 1:N
        [x, r_buf, d_hat_sym, has_ref, ~, e, y] = ...
            baseline_step_common(r(n), n, r_buf, d, d_hat_sym, cfg, theta);

        y_samp(n) = y;
        e_samp(n) = e;

        if has_ref && abs(e) > gamma
            p2 = (x.' * x) + eps_p;
            theta = theta + (beta * sign(e) / p2) * x;
            theta(main_idx) = 1.0;
        end
    end
end

%% =====================================================================
% CHANNEL / NOISE / HELPERS
%% =====================================================================
