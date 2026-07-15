% Auto-split from NCKH_v53.m (original line 3250).
% Folder: core/proposed_legacy

function [y_samp, d_hat_sym, e_samp, diag] = proposed_recursion_core(r, d, cfg, v, use_pd_feedback, theta0)
    N = numel(r);
    D = cfg.D;
    K = cfg.Nf;
    L = cfg.Nb;
    main_idx = v.main_idx;

    if nargin < 6 || isempty(theta0)
        theta = zeros(K+L,1);
        theta(main_idx)  = v.w_main_value;
    else
        theta = theta0(:);
    end

    theta = Pi_H(theta, v, K);

    r_buf = zeros(K,1);
    d_hat_sym = zeros(numel(d),1);
    y_samp = zeros(N,1);
    e_samp = zeros(N,1);

    diag.theta_hist  = zeros(K+L, N);
    diag.dtheta_hist = zeros(K+L, N);
    diag.mu_hist     = zeros(N,1);
    diag.mu_scale_hist = ones(N,1);
    diag.raw_gate_hist   = zeros(N,1);
    diag.conf_hist       = zeros(N,1);
    diag.accept_hard_hist= zeros(N,1);
    diag.accept_mass_hist= zeros(N,1);
    diag.clip_hist   = zeros(N,1);
    diag.margin_hist = zeros(N,1);
    diag.gamma_hist      = zeros(N,1);
    diag.kappa_hist      = zeros(N,1);
    diag.H_hist          = zeros(K+L, N);

    % NEW: disturbance-aware internal proxy histories
    diag.bias_hat_hist   = zeros(N,1);
    diag.drift_hat_hist  = zeros(N,1);
    diag.tau_hist        = zeros(N,1);
    diag.sigma_u2_hist   = zeros(N,1);

    state = init_adaptation_state(v);

    for n = 1:N
        r_buf = [r(n); r_buf(1:end-1)];
        m = n - D;

        if use_pd_feedback
            a_fb = get_fb_vector_pd(m, d, L);
        else
            a_fb = get_fb_vector(m, d, d_hat_sym, cfg, L);
        end
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
                if m <= cfg.trainLen
                    d_ref = d(m);
                else
                    d_ref = pam_slice_scalar(y, cfg.A);
                end
            end
            e = d_ref - y;
        else
            e = 0;
        end
        e_samp(n) = e;

        g  = (x.'*x) + v.delta;
        u  = e / g;
        mu_base = get_step_size(n, v);

        [weight, update_innov, ctrl] = proposed_update_components(v, has_ref, is_dd, y, e, g, u, state);
        state = ctrl.state_next;

        mu = mu_base;
        if isfield(ctrl, 'mu_scale')
            mu = min(max(mu_base * ctrl.mu_scale, v.mu_min), v.mu_max);
        end

        % Theorem-aligned implementable field H(theta,Z)
        Hn = -v.lambda * theta + weight * x * update_innov;
        theta_u = theta + mu * Hn;
        theta_new = Pi_H(theta_u, v, K);

        diag.theta_hist(:,n)  = theta_new;
        diag.dtheta_hist(:,n) = theta_new - theta;
        diag.mu_hist(n)       = mu;
        diag.mu_scale_hist(n) = ctrl.mu_scale;
        diag.raw_gate_hist(n)    = ctrl.raw_gate;
        diag.conf_hist(n)        = ctrl.conf_value;
        diag.accept_hard_hist(n) = ctrl.accept_hard;
        diag.accept_mass_hist(n) = ctrl.accept_mass;
        diag.clip_hist(n)     = ctrl.clip_flag;
        diag.margin_hist(n)   = ctrl.margin;
        diag.gamma_hist(n)      = ctrl.gamma_log;
        diag.kappa_hist(n)      = ctrl.kappa_log;
        diag.H_hist(:,n)        = Hn;

        % NEW: disturbance-aware state logs
        diag.bias_hat_hist(n)   = state.bias_hat;
        diag.drift_hat_hist(n)  = state.drift_hat;
        diag.tau_hist(n)        = state.tau_c;
        diag.sigma_u2_hist(n)   = state.sigma_u2;
        state.dtheta_prev = theta_new - theta;  % for next-step drift proxy (eq:Dhat)
        theta = theta_new;
    end
end

