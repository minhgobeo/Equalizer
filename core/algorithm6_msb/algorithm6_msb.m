% Auto-split from NCKH_v53.m (original line 11471).
% Folder: core/algorithm6_msb

function [d_hat_sym, diag] = ...
        algorithm6_msb(r, d, cfg, v_base, msb_params, oracle_state)
% Algorithm 6 core: Multi-State-Bank with hard switching + hysteresis.
%   v_base       : Algorithm 5 base variant
%   msb_params   : struct with B, K, T_min, delta, rho
%   oracle_state : if non-empty, use as ground-truth state (oracle baseline)
%
% Returns:
%   d_hat_sym    : decision output stream (single stream)
%   diag         : detailed diagnostics

    N = numel(r);
    K = cfg.Nf; L = cfg.Nb; D = cfg.D;
    main_idx = v_base.main_idx;
    S = numel(cfg.markov.h2_states);

    % Bank parameters
    B      = msb_params.B;
    Kb     = msb_params.K;
    T_min  = msb_params.T_min;
    delta  = msb_params.delta;
    rho    = msb_params.rho;
    N_sep  = S * B * Kb;     % length of separation burn-in (after training)
    use_oracle = ~isempty(oracle_state);

    % Initialize banks (identical warm-start)
    theta_init = zeros(K+L, 1);
    theta_init(main_idx) = v_base.w_main_value;
    theta_init = Pi_H(theta_init, v_base, K);
    theta_banks = repmat(theta_init, 1, S);

    % EWMA residual scores for state estimation
    J_s = zeros(S, 1);

    % State estimator state
    s_hat = 1;
    T_dwell = 0;
    n_switches = 0;

    % Shared decision buffer
    r_buf = zeros(K, 1);
    d_hat_sym = zeros(numel(d), 1);

    % Diagnostics
    diag = struct();
    diag.s_hat_hist     = zeros(N, 1);
    diag.J_hist         = zeros(S, N);
    diag.theta_dfe_hist = zeros(S, N);   % track DFE coeff per bank
    diag.bank_active    = zeros(S, 1);   % count of activations
    diag.n_switches     = 0;
    diag.dwell_lengths  = [];
    diag.update_allowed_hist = zeros(N, 1);
    diag.conf_ratio_hist     = zeros(N, 1);
    last_switch_n = 0;

    for n = 1:N
        r_buf = [r(n); r_buf(1:end-1)];
        m = n - D;

        % Build feature vector with shared decision buffer
        a_fb = get_fb_vector(m, d, d_hat_sym, cfg, L);
        x = [r_buf; v_base.dfe_sign * a_fb];

        % Compute output of all banks
        y_s = zeros(S, 1);
        for s = 1:S
            y_s(s) = theta_banks(:, s).' * x;
        end

        % Compute per-bank residual (sliced decision)
        r_score = zeros(S, 1);
        for s = 1:S
            d_dec_s = pam_slice_scalar(y_s(s), cfg.A);
            r_score(s) = (d_dec_s - y_s(s))^2;
        end

        % Update EWMA score for ALL banks
        J_s = rho * J_s + (1 - rho) * r_score;
        diag.J_hist(:, n) = J_s;

        has_ref = (m >= 1 && m <= numel(d));
        is_dd   = has_ref && (m > cfg.trainLen);

        % --- State estimator logic ---
        if use_oracle && has_ref
            % Oracle baseline: use true state from channel
            if m >= 1 && m <= numel(oracle_state)
                s_hat_new = oracle_state(m);
            else
                s_hat_new = s_hat;
            end
        elseif ~is_dd
            % Training phase: update all banks identically
            % s_hat doesn't matter for selection; use round-robin for diag
            s_hat_new = s_hat;
        else
            % DD phase
            n_dd = m - cfg.trainLen;
            if n_dd <= N_sep
                % Phase 1: separation burn-in (round-robin block assignment)
                block_idx = floor((n_dd - 1) / B);
                s_hat_new = mod(block_idx, S) + 1;
            else
                % Phase 2: residual-based switching with hysteresis
                [J_min, s_min] = min(J_s);
                T_dwell = T_dwell + 1;

                if T_dwell >= T_min && J_min < (1 - delta) * J_s(s_hat)
                    s_hat_new = s_min;
                else
                    s_hat_new = s_hat;
                end
            end
        end

        % Track switches
        if s_hat_new ~= s_hat
            n_switches = n_switches + 1;
            diag.dwell_lengths(end+1) = n - last_switch_n;
            last_switch_n = n;
            T_dwell = 0;
        end
        s_hat = s_hat_new;
        diag.s_hat_hist(n) = s_hat;
        diag.bank_active(s_hat) = diag.bank_active(s_hat) + 1;

        % --- Decision output (using s_hat bank) ---
        if m >= 1 && m <= numel(d_hat_sym)
            d_hat_sym(m) = pam_slice_scalar(y_s(s_hat), cfg.A);
        end

        % --- Update logic ---
        if has_ref
            if ~is_dd
                % Training: update ALL banks with d(m)
                d_ref = d(m);
                for s = 1:S
                    e_s = d_ref - y_s(s);
                    g = (x.'*x) + v_base.delta;
                    if isfield(v_base, 'lambda_schedule') && v_base.lambda_schedule
                        lambda_n = v_base.lambda_0 / (1 + v_base.lambda_alpha * n)^v_base.lambda_beta;
                        lambda_n = max(lambda_n, v_base.lambda_min);
                    else
                        lambda_n = v_base.lambda;
                    end
                    mu = get_step_size(n, v_base);
                    Hn = -lambda_n * theta_banks(:,s) + x * (e_s / g);
                    theta_new = theta_banks(:,s) + mu * Hn;
                    theta_banks(:,s) = Pi_H(theta_new, v_base, K);
                end
            else
                % DD: update only s_hat bank
                d_ref = d_hat_sym(m);   % shared decision
                e = d_ref - y_s(s_hat);
                g = (x.'*x) + v_base.delta;
                if isfield(v_base, 'lambda_schedule') && v_base.lambda_schedule
                    lambda_n = v_base.lambda_0 / (1 + v_base.lambda_alpha * n)^v_base.lambda_beta;
                    lambda_n = max(lambda_n, v_base.lambda_min);
                else
                    lambda_n = v_base.lambda;
                end
                mu = get_step_size(n, v_base);
                Hn = -lambda_n * theta_banks(:,s_hat) + x * (e / g);
                theta_new = theta_banks(:,s_hat) + mu * Hn;
                theta_banks(:,s_hat) = Pi_H(theta_new, v_base, K);
            end
        end

        % Track DFE coefficient evolution per bank
        for s = 1:S
            diag.theta_dfe_hist(s, n) = theta_banks(end, s);
        end
    end

    diag.n_switches    = n_switches;
    diag.theta_banks_final = theta_banks;
    diag.J_final       = J_s;
    diag.bank_usage    = diag.bank_active / N;
    diag.N_sep         = N_sep;
    diag.params        = msb_params;
end


