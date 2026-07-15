% Auto-split from NCKH_v53.m (original line 10850).
% Folder: core/proposed_legacy

function [y_samp, d_hat_sym, e_samp, diag] = ...
        proposed_recursion_sbc(r, d, cfg, v)
% Algorithm 4 = Algorithm 1 + lambda schedule (Algo 3) + structural bias correction.
 
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
 
    % SBC state: vector estimate of b_c
    b_hat_c = zeros(K+L, 1);
 
    state = init_adaptation_state(v);
 
    diag = struct();
    diag.theta_hist  = zeros(K+L, N);
    diag.bhatc_hist  = zeros(K+L, N);
    diag.bhatc_norm  = zeros(N, 1);
    diag.lambda_hist = zeros(N, 1);
    diag.mu_hist     = zeros(N, 1);
 
    sbc_alpha  = getfield_safe(v, 'sbc_alpha',  0);
    sbc_beta_B = getfield_safe(v, 'sbc_beta_B', 5e-3);
 
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
 
        % --- Compute IMPL drift (DD) ---
        if has_ref
            if is_dd
                d_ref_impl = pam_slice_scalar(y, cfg.A);
            else
                d_ref_impl = d(m);
            end
            e_impl = d_ref_impl - y;
        else
            e_impl = 0;
        end
        e_samp(n) = e_impl;
 
        g = (x.'*x) + v.delta;
        u_impl = e_impl / g;
        mu_base = get_step_size(n, v);
 
        [weight, update_innov, ctrl] = ...
            proposed_update_components(v, has_ref, is_dd, y, e_impl, g, u_impl, state);
        state = ctrl.state_next;
 
        mu = mu_base;
        if isfield(ctrl, 'mu_scale')
            mu = min(max(mu_base * ctrl.mu_scale, v.mu_min), v.mu_max);
        end
 
        % --- lambda schedule (Algorithm 3) ---
        if isfield(v, 'lambda_schedule') && v.lambda_schedule
            lambda_n = v.lambda_0 / (1 + v.lambda_alpha * n)^v.lambda_beta;
            lambda_n = max(lambda_n, v.lambda_min);
        else
            lambda_n = v.lambda;
        end
 
        % H_impl: drift used in standard update
        H_impl = -lambda_n * theta + weight * x * update_innov;
 
        % --- Compute PD drift (oracle, ALGORITHM 4) ---
        % Use true symbol d(m) for oracle when available.
        % Post-training: d(m) IS still the true symbol (we have access to it
        % in simulation; in real systems, this would be estimated by a slower
        % pilot insertion or by a high-confidence subset).
        if has_ref
            e_pd = d(m) - y;
            u_pd = e_pd / g;
            % Compute PD weight using same machinery but with oracle innov
            % For simplicity, use raw u_pd without gating (oracle bypass)
            H_pd = -lambda_n * theta + x * u_pd;
        else
            H_pd = H_impl;       % no oracle available, no correction
        end
 
        % --- Update b_hat_c (vector EWMA of drift mismatch) ---
        if is_dd && sbc_alpha > 0
            % Only update SBC after training (where DD is active and
            % oracle differs from impl)
            b_inst = H_impl - H_pd;
            b_hat_c = (1 - sbc_beta_B) * b_hat_c + sbc_beta_B * b_inst;
        end
 
        % --- Apply structural bias correction ---
        if sbc_alpha > 0
            H_corrected = H_impl - sbc_alpha * b_hat_c;
        else
            H_corrected = H_impl;
        end
 
        theta_u = theta + mu * H_corrected;
        theta_new = Pi_H(theta_u, v, K);
 
        diag.theta_hist(:, n)  = theta_new;
        diag.bhatc_hist(:, n)  = b_hat_c;
        diag.bhatc_norm(n)     = norm(b_hat_c);
        diag.lambda_hist(n)    = lambda_n;
        diag.mu_hist(n)        = mu;
 
        state.dtheta_prev = theta_new - theta;
        theta = theta_new;
    end
end
 
 
% ============================================================================
% SECTION-C  —  PATCH A : THETA EVOLUTION
% ============================================================================
 
