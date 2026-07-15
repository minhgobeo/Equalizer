% Auto-split from NCKH_v53.m (original line 3691).
% Folder: core/baselines

function [y_samp, d_hat_sym, e_samp] = dfe_rls_unified_x(r, d, cfg, base)
    N = numel(r);
    K = cfg.Nf;
    L = cfg.Nb;
    main_idx = cfg.D + 1;

    theta = zeros(K+L,1);
    theta(main_idx) = 1.0;

    P   = (1/base.delta_rls) * eye(K+L);
    lam = base.lambda_rls;

    r_buf = zeros(K,1);

    y_samp    = zeros(N,1);
    e_samp    = zeros(N,1);
    d_hat_sym = zeros(numel(d),1);

    for n = 1:N
        [x, r_buf, d_hat_sym, has_ref, ~, e, y] = ...
            baseline_step_common(r(n), n, r_buf, d, d_hat_sym, cfg, theta);

        y_samp(n) = y;
        e_samp(n) = e;

        if has_ref
            Px = P * x;
            g  = Px / (lam + x.' * Px);
            theta = theta + g * e;
            theta(main_idx) = 1.0;
            P = (P - g * x.' * P) / lam;
        end
    end
end

