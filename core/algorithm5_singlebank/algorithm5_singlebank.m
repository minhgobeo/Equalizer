% Auto-split from NCKH_v53.m (original line 11654).
% Folder: core/algorithm5_singlebank

function [d_hat_sym, diag] = ...
        algorithm5_singlebank(r, d, cfg, v_base)
% Single-bank Algorithm 5 baseline (NLMS-like + lambda schedule).
    N = numel(r);
    K = cfg.Nf; L = cfg.Nb; D = cfg.D;
    main_idx = v_base.main_idx;

    theta = zeros(K+L, 1);
    theta(main_idx) = v_base.w_main_value;
    theta = Pi_H(theta, v_base, K);

    r_buf = zeros(K, 1);
    d_hat_sym = zeros(numel(d), 1);
    diag = struct();
    diag.theta_dfe_hist = zeros(N, 1);
    diag.y_hist = zeros(N, 1);

    for n = 1:N
        r_buf = [r(n); r_buf(1:end-1)];
        m = n - D;

        a_fb = get_fb_vector(m, d, d_hat_sym, cfg, L);
        x = [r_buf; v_base.dfe_sign * a_fb];

        y = theta.' * x;
        diag.y_hist(n) = y;
        if m >= 1 && m <= numel(d_hat_sym)
            d_hat_sym(m) = pam_slice_scalar(y, cfg.A);
        end

        if m >= 1 && m <= numel(d)
            if m <= cfg.trainLen
                d_ref = d(m);
            else
                d_ref = d_hat_sym(m);
            end
            e = d_ref - y;
            g = (x.'*x) + v_base.delta;
            if v_base.lambda_schedule
                lambda_n = v_base.lambda_0 / (1 + v_base.lambda_alpha * n)^v_base.lambda_beta;
                lambda_n = max(lambda_n, v_base.lambda_min);
            else
                lambda_n = v_base.lambda;
            end
            mu = get_step_size(n, v_base);
            Hn = -lambda_n * theta + x * (e / g);
            theta_new = theta + mu * Hn;
            theta = Pi_H(theta_new, v_base, K);
        end
        diag.theta_dfe_hist(n) = theta(end);
    end
    diag.theta_final = theta;
end


