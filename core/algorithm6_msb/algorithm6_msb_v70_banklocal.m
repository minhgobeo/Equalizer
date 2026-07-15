function [d_hat_sym, diag] = ...
        algorithm6_msb_v70_banklocal(r, d, cfg, v_base, msb_params, oracle_state)
% ALGORITHM6_MSB_V70_BANKLOCAL
%
% Bank-local DFE decision buffer variant of algorithm6_msb_v69.
% Use this ONLY if you decide to go route (A) in REVISION_PLAN_VN:
% honest implementation of the "bank-local buffer" claim.
%
% Differences from v69:
%   * d_hat_per_bank(:,s) replaces the shared d_hat_sym for forming the
%     bank-s DFE feedback.
%   * d_hat_sym is still maintained as the external output (active bank's
%     decision) for compatibility with downstream eye / BER scripts.
%   * msb_channel_likelihood_score is fed the bank-local previous decision.
%
% Memory cost: O(S * L) for the per-bank DFE histories (L = cfg.Nb).
% No timing change at the bank-update step; one extra pointer fetch per bank
% in the scoring loop.

    N = numel(r);
    Kffe = cfg.Nf; L = cfg.Nb; D = cfg.D;
    main_idx = v_base.main_idx;
    S = numel(cfg.markov.h2_states);
    h2_states = cfg.markov.h2_states(:);

    B      = msb_params.B;
    Kb     = msb_params.K;
    T_min  = msb_params.T_min;
    delta  = msb_params.delta;
    rho    = msb_params.rho;
    N_sep  = S * B * Kb;
    use_oracle = ~isempty(oracle_state);

    if ~isfield(msb_params,'train_all_prefix')
        msb_params.train_all_prefix = 1000;
    end
    train_all_prefix = min(msb_params.train_all_prefix, cfg.trainLen);

    if isfield(msb_params,'P_assumed') && ~isempty(msb_params.P_assumed)
        P_hmm = msb_params.P_assumed;
    else
        P_hmm = cfg.markov.P;
    end

    log_proxy = isfield(msb_params,'log_theory_proxy') && msb_params.log_theory_proxy;

    % Bank initialization
    theta_init = zeros(Kffe+L, 1);
    theta_init(main_idx) = v_base.w_main_value;
    theta_init = Pi_H(theta_init, v_base, Kffe);
    theta_banks = repmat(theta_init, 1, S);

    % BANK-LOCAL DFE BUFFERS  <-- THE KEY CHANGE
    d_hat_per_bank = zeros(numel(d), S);

    J_s = zeros(S, 1);
    s_hat = 1;
    T_dwell = 0;
    n_switches = 0;
    last_switch_n = 0;
    pi_state = ones(S,1) / S;
    r_buf = zeros(Kffe, 1);

    % Shared external output stream (active bank's decision)
    d_hat_sym = zeros(numel(d), 1);

    diag = struct();
    diag.pi_hist          = zeros(S, N);
    diag.s_hat_hist       = zeros(N, 1);
    diag.s_train_hist     = zeros(N, 1);
    diag.J_hist           = zeros(S, N);
    diag.score_inst_hist  = zeros(S, N);
    diag.theta_dfe_hist   = zeros(S, N);
    diag.y_hist           = zeros(N, 1);
    diag.bank_active      = zeros(S, 1);
    diag.bank_active_post = zeros(S, 1);
    diag.n_switches       = 0;
    diag.dwell_lengths    = [];
    diag.P_hmm            = P_hmm;
    diag.P_true           = cfg.markov.P;
    diag.conf_ratio_hist  = zeros(N,1);
    diag.update_allowed_hist = zeros(N,1);
    diag.buffer_mode      = 'bank_local';   % marker for reviewers

    if log_proxy
        diag.e_active_hist          = zeros(N, 1);
        diag.x_norm2_hist           = zeros(N, 1);
        diag.theta_active_hist_full = zeros(Kffe+L, N);
        diag.is_dd_hist             = false(N, 1);
        diag.has_ref_hist           = false(N, 1);
    end

    for n = 1:N
        r_buf = [r(n); r_buf(1:end-1)];
        m = n - D;
        s_hat_new = s_hat;

        % ---- BANK-LOCAL REGRESSOR x_s for each bank ----
        % Build S separate regressors using each bank's own decision history.
        x_per_bank = zeros(Kffe+L, S);
        for s = 1:S
            a_fb_s = get_fb_vector(m, d, d_hat_per_bank(:,s), cfg, L);
            x_per_bank(:,s) = [r_buf; v_base.dfe_sign * a_fb_s];
        end

        % Compute bank outputs and candidate decisions
        y_s     = zeros(S, 1);
        d_dec_s = zeros(S, 1);
        for s = 1:S
            y_s(s)     = theta_banks(:, s).' * x_per_bank(:,s);
            d_dec_s(s) = pam_slice_scalar(y_s(s), cfg.A);
        end

        has_ref = (m >= 1 && m <= numel(d));
        is_dd   = has_ref && (m > cfg.trainLen);

        % Channel-likelihood score: for the bank-local variant we score
        % against the bank's *own* previous decision, not the shared one.
        score_s = inf(S,1);
        if m >= 2 && m <= numel(r)
            if m <= cfg.trainLen && m <= numel(d)
                d_cur_ref  = d(m);
                d_prev_ref = d(m-1);
                for s = 1:S
                    pred = d_cur_ref + h2_states(s) * d_prev_ref;
                    score_s(s) = (r(m) - pred)^2;
                end
            else
                for s = 1:S
                    % Bank-local previous decision. If bank s has not yet
                    % written symbol m-1 (still 0 at init), the postcursor
                    % term is simply absent for that bank at this index.
                    if (m-1) >= 1
                        d_prev_s = d_hat_per_bank(m-1, s);
                    else
                        d_prev_s = 0;
                    end
                    pred = d_dec_s(s) + h2_states(s) * d_prev_s;
                    score_s(s) = (r(m) - pred)^2;
                end
            end
        end
        if any(~isfinite(score_s))
            score_s = (d_dec_s - y_s).^2;
        end
        J_s = rho * J_s + (1 - rho) * score_s;
        diag.J_hist(:, n) = J_s;
        diag.score_inst_hist(:, n) = score_s;

        if numel(score_s) >= 2
            sc_sorted = sort(score_s);
            conf_gap = (sc_sorted(2) - sc_sorted(1)) / (sc_sorted(2) + sc_sorted(1) + 1e-12);
        else
            conf_gap = 1;
        end
        diag.conf_ratio_hist(n) = conf_gap;

        update_allowed = true;
        if isfield(msb_params, 'use_update_conf_gate') && msb_params.use_update_conf_gate
            if conf_gap < msb_params.update_conf_gap
                update_allowed = false;
            end
        end
        diag.update_allowed_hist(n) = double(update_allowed);

        % ---- Routing decision ----
        if use_oracle && has_ref
            if m >= 1 && m <= numel(oracle_state)
                s_hat_new = oracle_state(m);
            else
                s_hat_new = s_hat;
            end

        elseif has_ref && ~is_dd
            if m <= train_all_prefix
                s_hat_new = s_hat;
            else
                [~, s_train] = min(score_s);
                s_hat_new = s_train;
                diag.s_train_hist(n) = s_train;
                pi_state = zeros(S,1);
                pi_state(s_train) = 1;
                diag.pi_hist(:,n) = pi_state;
            end

        elseif is_dd
            n_dd = m - cfg.trainLen;
            if isfield(msb_params,'use_hmm_filter') && msb_params.use_hmm_filter
                pi_pred = P_hmm.' * pi_state;
                rel_score = score_s - min(score_s);
                tau_hmm = msb_params.hmm_temp;
                like = exp(-rel_score / max(tau_hmm, 1e-12));
                pi_state = pi_pred .* like;
                pi_state = pi_state / max(sum(pi_state), 1e-12);
                [~, s_hmm] = max(pi_state);
                s_hat_new = s_hmm;
                diag.pi_hist(:,n) = pi_state;
            else
                [J_min, s_min] = min(J_s);
                if n_dd <= N_sep
                    s_hat_new = s_min;
                else
                    T_dwell = T_dwell + 1;
                    if T_dwell >= T_min && J_min < (1 - delta) * J_s(s_hat)
                        s_hat_new = s_min;
                    else
                        s_hat_new = s_hat;
                    end
                end
            end
        end

        if s_hat_new ~= s_hat
            n_switches = n_switches + 1;
            diag.dwell_lengths(end+1) = n - last_switch_n;
            last_switch_n = n;
            T_dwell = 0;
        end
        s_hat = s_hat_new;
        diag.s_hat_hist(n) = s_hat;
        diag.bank_active(s_hat) = diag.bank_active(s_hat) + 1;
        if has_ref && is_dd && (m > cfg.trainLen + N_sep)
            diag.bank_active_post(s_hat) = diag.bank_active_post(s_hat) + 1;
        end

        diag.y_hist(n) = y_s(s_hat);

        % ---- Decision outputs ----
        if has_ref
            % EVERY bank stores its candidate into its OWN buffer
            for s = 1:S
                d_hat_per_bank(m, s) = d_dec_s(s);
            end
            % External output = active bank's decision
            d_hat_sym(m) = d_dec_s(s_hat);
        end

        % ---- Update ----
        if has_ref
            if ~is_dd
                if m <= train_all_prefix
                    d_ref = d(m);
                    for s = 1:S
                        theta_banks(:,s) = msb_update_theta(theta_banks(:,s), ...
                            x_per_bank(:,s), d_ref - y_s(s), n, v_base, Kffe);
                    end
                else
                    if use_oracle && m <= numel(oracle_state)
                        s_upd = oracle_state(m);
                    else
                        [~, s_upd] = min(score_s);
                    end
                    d_ref = d(m);
                    theta_banks(:,s_upd) = msb_update_theta(theta_banks(:,s_upd), ...
                        x_per_bank(:,s_upd), d_ref - y_s(s_upd), n, v_base, Kffe);
                end
            else
                d_ref = d_dec_s(s_hat);     % active bank's own decision
                if update_allowed
                    theta_banks(:,s_hat) = msb_update_theta(theta_banks(:,s_hat), ...
                        x_per_bank(:,s_hat), d_ref - y_s(s_hat), n, v_base, Kffe);
                end
            end
        end

        if log_proxy
            diag.has_ref_hist(n) = has_ref;
            diag.is_dd_hist(n)   = is_dd;
            diag.x_norm2_hist(n) = x_per_bank(:,s_hat).' * x_per_bank(:,s_hat);
            diag.theta_active_hist_full(:, n) = theta_banks(:, s_hat);
            if has_ref
                if is_dd
                    e_active = d_dec_s(s_hat) - y_s(s_hat);
                else
                    e_active = d(m) - y_s(s_hat);
                end
                diag.e_active_hist(n) = e_active;
            end
        end

        for s = 1:S
            diag.theta_dfe_hist(s, n) = theta_banks(end, s);
        end
    end

    diag.n_switches = n_switches;
    diag.theta_banks_final = theta_banks;
    diag.J_final = J_s;
    diag.bank_usage = diag.bank_active / N;
    diag.bank_usage_post = diag.bank_active_post / max(sum(diag.bank_active_post),1);
    diag.N_sep = N_sep;
    diag.params = msb_params;
    diag.d_hat_per_bank = d_hat_per_bank;     % for reviewer audit
end

% ============================================================================
% Usage notes (paste into your run script):
% ----------------------------------------------------------------------------
% % Replace algorithm6_msb_v69 with algorithm6_msb_v70_banklocal:
% [dh_alg2, diag_alg2] = algorithm6_msb_v70_banklocal( ...
%     r_rx, d, cfg_p, v_base, msb_params, []);
%
% % Reviewer can audit per-bank decisions:
% disp(size(diag_alg2.d_hat_per_bank));    % [N x S]
% ============================================================================
