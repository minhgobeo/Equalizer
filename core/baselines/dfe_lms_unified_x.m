% Auto-split from NCKH_v53.m (original line 3627).
% Folder: core/baselines

function [y_samp, d_hat_sym, e_samp] = dfe_lms_unified_x(r, d, cfg, base)
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

    mu = base.mu_lms;

    for n = 1:N
        [x, r_buf, d_hat_sym, has_ref, ~, e, y] = ...
            baseline_step_common(r(n), n, r_buf, d, d_hat_sym, cfg, theta);

        y_samp(n) = y;
        e_samp(n) = e;

        if has_ref
            theta = theta + mu * e * x;
            theta(main_idx) = 1.0;   % keep same main-tap convention for fairness
        end
    end
end

