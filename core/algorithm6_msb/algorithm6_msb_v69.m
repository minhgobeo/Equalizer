% Auto-split from NCKH_v53.m (original line 12155).
% Folder: core/algorithm6_msb
%
% v57 patch (this file):
%   * Adds msb_params.P_assumed for HMM filter, decoupled from cfg.markov.P
%     used by the channel generator. Enables transition-matrix mismatch sweeps.
%   * Adds optional theory-proxy logs (e_active_hist, theta_active_hist_full,
%     x_norm2_hist) when msb_params.log_theory_proxy = true. These are the
%     inputs needed to compute V_tr_hat and Bc_hat in the theory-proxy script.
%   * Logging is OFF by default to keep memory usage low for hero BER sweeps.

function [d_hat_sym, diag] = ...
        algorithm6_msb_v69(r, d, cfg, v_base, msb_params, oracle_state)
% Algorithm 6 v69:
% Multi-State-Bank with channel-likelihood state scoring and state-conditional training.

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

    % --------------------------------------------------------------
    % v57 PATCH 1 — decouple HMM-assumed transition matrix.
    % If msb_params.P_assumed is provided, the HMM filter uses it as the
    % prior. cfg.markov.P is still used by the channel generator.
    % --------------------------------------------------------------
    if isfield(msb_params,'P_assumed') && ~isempty(msb_params.P_assumed)
        P_hmm = msb_params.P_assumed;
    else
        P_hmm = cfg.markov.P;
    end

    % --------------------------------------------------------------
    % v57 PATCH 2 — opt-in theory-proxy logging.
    % --------------------------------------------------------------
    log_proxy = isfield(msb_params,'log_theory_proxy') && msb_params.log_theory_proxy;

    % Bank initialization
    theta_init = zeros(Kffe+L, 1);
    theta_init(main_idx) = v_base.w_main_value;
    theta_init = Pi_H(theta_init, v_base, Kffe);
    theta_banks = repmat(theta_init, 1, S);

    % EWMA scores
    J_s = zeros(S, 1);

    % State estimator
    s_hat = 1;
    T_dwell = 0;
    n_switches = 0;
    last_switch_n = 0;
    pi_state = ones(S,1) / S;
    r_buf = zeros(Kffe, 1);
    d_hat_sym = zeros(numel(d), 1);

    % Diagnostics
    diag = struct();
    diag.pi_hist = zeros(S, N);
    diag.s_hat_hist      = zeros(N, 1);
    diag.s_train_hist    = zeros(N, 1);
    diag.J_hist          = zeros(S, N);
    diag.score_inst_hist = zeros(S, N);
    diag.theta_dfe_hist  = zeros(S, N);
    diag.y_hist          = zeros(N, 1);
    diag.bank_active     = zeros(S, 1);
    diag.bank_active_post = zeros(S, 1);
    diag.n_switches      = 0;
    diag.dwell_lengths   = [];
    diag.P_hmm           = P_hmm;
    diag.P_true          = cfg.markov.P;
    diag.conf_ratio_hist = zeros(N,1);
    diag.update_allowed_hist = zeros(N,1);

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
        a_fb = get_fb_vector(m, d, d_hat_sym, cfg, L);
        x = [r_buf; v_base.dfe_sign * a_fb];

        y_s = zeros(S, 1);
        d_dec_s = zeros(S, 1);
        for s = 1:S
            y_s(s) = theta_banks(:, s).' * x;
            d_dec_s(s) = pam_slice_scalar(y_s(s), cfg.A);
        end

        has_ref = (m >= 1 && m <= numel(d));
        is_dd   = has_ref && (m > cfg.trainLen);

        score_s = msb_channel_likelihood_score(r, d, d_hat_sym, d_dec_s, ...
                                               cfg, m, h2_states);

        if any(~isfinite(score_s))
            score_s = (d_dec_s - y_s).^2;
        end
        J_s = rho * J_s + (1 - rho) * score_s;
        diag.J_hist(:, n) = J_s;
        diag.score_inst_hist(:, n) = score_s;

        if numel(score_s) >= 2
            score_sorted = sort(score_s);
            score_best = score_sorted(1);
            score_second = score_sorted(2);
            conf_gap = (score_second - score_best) / ...
                       (score_second + score_best + 1e-12);
        else
            % v57 fix: degenerate single-bank case (S=1, used by complexity
            % sweep). No state ambiguity exists, so set conf_gap to 1.
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
                pi_pred = P_hmm.' * pi_state;       % v57: use P_hmm
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

        if has_ref
            d_hat_sym(m) = d_dec_s(s_hat);
        end

        if has_ref
            if ~is_dd
                if m <= train_all_prefix
                    d_ref = d(m);
                    for s = 1:S
                        theta_banks(:,s) = msb_update_theta(theta_banks(:,s), x, ...
                                        d_ref - y_s(s), n, v_base, Kffe);
                    end
                else
                    if use_oracle && m <= numel(oracle_state)
                        s_upd = oracle_state(m);
                    else
                        [~, s_upd] = min(score_s);
                    end
                    d_ref = d(m);
                    theta_banks(:,s_upd) = msb_update_theta(theta_banks(:,s_upd), x, ...
                                                            d_ref - y_s(s_upd), n, ...
                                                            v_base, Kffe);
                end
            else
                d_ref = d_hat_sym(m);
                if update_allowed
                    theta_banks(:,s_hat) = msb_update_theta(theta_banks(:,s_hat), x, ...
                                                            d_ref - y_s(s_hat), n, ...
                                                            v_base, Kffe);
                end
            end
        end

        % v57 PATCH 3 — theory-proxy logging.
        if log_proxy
            diag.has_ref_hist(n) = has_ref;
            diag.is_dd_hist(n)   = is_dd;
            diag.x_norm2_hist(n) = x.' * x;
            diag.theta_active_hist_full(:, n) = theta_banks(:, s_hat);
            if has_ref
                if is_dd
                    e_active = d_hat_sym(m) - y_s(s_hat);
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

    post_total = sum(diag.bank_active_post);
    if post_total > 0
        diag.bank_usage_post = diag.bank_active_post / post_total;
    else
        diag.bank_usage_post = nan(S,1);
    end

    diag.N_sep = N_sep;
    diag.params = msb_params;
end
