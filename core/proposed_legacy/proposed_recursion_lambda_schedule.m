% Auto-split from NCKH_v53.m (original line 10657).
% Folder: core/proposed_legacy

function [y_samp, d_hat_sym, e_samp, diag] = proposed_recursion_lambda_schedule(r, d, cfg, v)
% Drop-in replacement for proposed_recursion that uses lambda_n schedule.
% All other logic identical to proposed_recursion.
 
    N = numel(r);
    K = cfg.Nf; L = cfg.Nb; D = cfg.D;
    main_idx = v.main_idx;
 
    theta = zeros(K+L, 1);
    theta(main_idx) = v.w_main_value;
    theta = Pi_H(theta, v, K);
 
    r_buf = zeros(K, 1);
    y_samp = zeros(N, 1);
    e_samp = zeros(N, 1);
    d_hat_sym = zeros(numel(d), 1);
 
    state = init_adaptation_state(v);
 
    diag = struct();
    diag.theta_hist = zeros(K+L, N);
    diag.dtheta_hist = zeros(K+L, N);
    diag.mu_hist = zeros(N, 1);
    diag.lambda_hist = zeros(N, 1);
 
    use_pd_feedback = isfield(v,'use_pd_feedback') && v.use_pd_feedback;
 
    for n = 1:N
        r_buf = [r(n); r_buf(1:end-1)];
        m = n - D;
 
        a_fb = get_fb_vector(m, d, d_hat_sym, cfg, L);
        x = [r_buf; v.dfe_sign * a_fb];
 
        y = theta.' * x;
        y_samp(n) = y;
 
        if m >= 1 && m <= numel(d_hat_sym)
            d_hat_sym(m) = pam_slice_scalar(y, cfg.A);
        end
 
        has_ref = (m >= 1 && m <= numel(d));
        is_dd   = has_ref && (m > cfg.trainLen);
 
        if has_ref
            if use_pd_feedback
                d_ref = d(m);
            else
                if m <= cfg.trainLen, d_ref = d(m);
                else, d_ref = pam_slice_scalar(y, cfg.A); end
            end
            e = d_ref - y;
        else
            e = 0;
        end
        e_samp(n) = e;
 
        g = (x.'*x) + v.delta;
        u = e / g;
        mu_base = get_step_size(n, v);
 
        [weight, update_innov, ctrl] = ...
            proposed_update_components(v, has_ref, is_dd, y, e, g, u, state);
        state = ctrl.state_next;
 
        mu = mu_base;
        if isfield(ctrl, 'mu_scale')
            mu = min(max(mu_base * ctrl.mu_scale, v.mu_min), v.mu_max);
        end
 
        % --- ALGORITHM 3: lambda schedule ---
        if isfield(v, 'lambda_schedule') && v.lambda_schedule
            lambda_n = v.lambda_0 / (1 + v.lambda_alpha * n)^v.lambda_beta;
            lambda_n = max(lambda_n, v.lambda_min);
        else
            lambda_n = v.lambda;
        end
 
        % Theorem-aligned implementable field with lambda_n
        Hn = -lambda_n * theta + weight * x * update_innov;
        theta_u = theta + mu * Hn;
        theta_new = Pi_H(theta_u, v, K);
 
        diag.theta_hist(:,n) = theta_new;
        diag.dtheta_hist(:,n) = theta_new - theta;
        diag.mu_hist(n) = mu;
        diag.lambda_hist(n) = lambda_n;
 
        state.dtheta_prev = theta_new - theta;
        theta = theta_new;
    end
end
 
 
% ============================================================================
% SECTION-F  —  HELPERS
% ============================================================================
 
