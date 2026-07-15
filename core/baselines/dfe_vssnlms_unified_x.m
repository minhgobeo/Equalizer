% Auto-split from NCKH_v53.m (original line 3726).
% Folder: core/baselines

function [y_samp, d_hat_sym, e_samp] = dfe_vssnlms_unified_x(r, d, cfg, base)
% Legacy VSS-NLMS baseline kept for compatibility.
% Rewritten to use the common K-tap/L-tap regressor so it remains consistent
% with cfg.Nf, cfg.Nb, and the chosen main-tap convention.

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

    % If an older vssnlms block is not present, fall back to NLMS settings.
    if isfield(base,'vssnlms')
        alpha_mu = base.vssnlms.alpha_mu;
        gamma_mu = base.vssnlms.gamma_mu;
        mu_max   = base.vssnlms.mu_max;
        eps_p    = base.vssnlms.eps_pow;
    else
        alpha_mu = 0.995;
        gamma_mu = 5e-3;
        mu_max   = base.mu_nlms;
        eps_p    = base.eps_nlms;
    end

    mu_prev = 0;

    for n = 1:N
        [x, r_buf, d_hat_sym, has_ref, ~, e, y] = ...
            baseline_step_common(r(n), n, r_buf, d, d_hat_sym, cfg, theta);

        y_samp(n) = y;
        e_samp(n) = e;

        mu = alpha_mu * mu_prev + gamma_mu * (e^2);
        mu = max(0, min(mu, mu_max));
        mu_prev = mu;

        if has_ref
            p2 = (x.' * x) + eps_p;
            theta = theta + (mu * e / p2) * x;
            theta(main_idx) = 1.0;
        end
    end
end

