function [d_hat_sym, diag] = ...
        algorithm6_msb_v71_softroute(r, d, cfg, v_base, msb_params, oracle_state)
% ALGORITHM6_MSB_V71_SOFTROUTE
% -------------------------------------------------------------------------
% Proposed EXTENSION of Algorithm 2 (reviewer-suggested, NOT yet in the paper).
%
% Goal: attack the routing-error term  C_rt * eps_routing  in Theorem 3,
%       which the diagnostics show is the dominant residual once the
%       cross-state burden has been removed (HMM accuracy is only ~87%,
%       so 1-acc ~= 0.13 feeds straight into the floor as C_rt*eps_routing).
%
% Idea (IMM / EM responsibility-weighted update):
%   Instead of HARD MAP routing -- update ONLY bank argmax_s pi_s and
%   commit the full C_rt penalty on every mis-routed symbol -- use the
%   HMM posterior pi_state as a soft RESPONSIBILITY weight:
%
%       theta_s <- Pi_H{ theta_s + mu * w_s * H_s },   w_s = pi_state(s)^kappa
%
%   normalised so sum_s w_s = 1. A symbol the HMM is UNSURE about
%   (diffuse posterior) produces small w_s for every bank, so no bank is
%   driven hard toward a wrong optimum. A symbol the HMM is CONFIDENT
%   about (peaked posterior) recovers the hard-routed update of v70.
%   kappa >= 1 sharpens the posterior; kappa -> Inf recovers hard MAP.
%
% Why this is theoretically clean (proof sketch -- see review doc Sec. G):
%   On the mis-identified event the hard scheme pays
%       C_rt * 1{s_hat ~= alpha}
%   whereas the soft scheme pays only
%       C_rt * (1 - pi_alpha(n))   <=  C_rt   (and = eps only in the hard limit).
%   By Jensen + HMM calibration, E[1 - pi_alpha] <= eps_routing, so the
%   soft floor is NEVER worse than Theorem 3's bound and is strictly
%   smaller whenever the posterior is better-than-binary calibrated.
%
% This file ALSO uses BANK-LOCAL DFE buffers, so adopting it simultaneously
% removes the shared-buffer inconsistency flagged in the code review
% (paper Remark 7 / A10 claims bank-local; v69 hero code is shared).
%
% Signature is identical to algorithm6_msb_v70_banklocal so it is a
% drop-in replacement in run_mb_ber_compare / shared_vs_banklocal_benchmark.
%
% IMPORTANT: This routine has NOT been executed in the review environment
% (no MATLAB available). It is written to the codebase conventions and is
% intended to be run, tuned (kappa), and reported by the authors. A
% verification harness suggestion is given at the end of this file.
% -------------------------------------------------------------------------

    N    = numel(r);
    Kffe = cfg.Nf;  L = cfg.Nb;  D = cfg.D;
    main_idx = v_base.main_idx;
    S        = numel(cfg.markov.h2_states);
    h2_states = cfg.markov.h2_states(:);

    rho = msb_params.rho;
    use_oracle = ~isempty(oracle_state);

    % ---- soft-routing hyper-parameters (new) ----
    if isfield(msb_params,'soft_kappa'),  kappa = msb_params.soft_kappa;
    else,                                 kappa = 2.0;   end          % posterior sharpening
    if isfield(msb_params,'soft_wfloor'), w_floor = msb_params.soft_wfloor;
    else,                                 w_floor = 1e-3; end          % keep tiny adaptation alive
    if isfield(msb_params,'soft_enable'), soft_enable = msb_params.soft_enable;
    else,                                 soft_enable = true; end

    if ~isfield(msb_params,'train_all_prefix')
        msb_params.train_all_prefix = 1000;
    end
    train_all_prefix = min(msb_params.train_all_prefix, cfg.trainLen);

    if isfield(msb_params,'P_assumed') && ~isempty(msb_params.P_assumed)
        P_hmm = msb_params.P_assumed;
    else
        P_hmm = cfg.markov.P;
    end

    % ---- bank initialisation ----
    theta_init = zeros(Kffe+L,1);
    theta_init(main_idx) = v_base.w_main_value;
    theta_init = Pi_H(theta_init, v_base, Kffe);
    theta_banks = repmat(theta_init, 1, S);

    % ---- BANK-LOCAL DFE decision buffers ----
    d_hat_per_bank = zeros(numel(d), S);

    pi_state = ones(S,1)/S;
    J_s      = zeros(S,1);
    s_hat    = 1;
    r_buf    = zeros(Kffe,1);
    d_hat_sym = zeros(numel(d),1);

    diag = struct();
    diag.pi_hist         = zeros(S,N);
    diag.s_hat_hist      = zeros(N,1);
    diag.w_hist          = zeros(S,N);     % soft responsibilities (new)
    diag.theta_dfe_hist  = zeros(S,N);
    diag.y_hist          = zeros(N,1);
    diag.buffer_mode     = 'bank_local';
    diag.route_mode      = 'soft';
    diag.soft_kappa      = kappa;

    for n = 1:N
        r_buf = [r(n); r_buf(1:end-1)];
        m = n - D;

        % ---- bank-local regressors ----
        x_per_bank = zeros(Kffe+L, S);
        for s = 1:S
            a_fb_s = get_fb_vector(m, d, d_hat_per_bank(:,s), cfg, L);
            x_per_bank(:,s) = [r_buf; v_base.dfe_sign * a_fb_s];
        end

        y_s = zeros(S,1); d_dec_s = zeros(S,1);
        for s = 1:S
            y_s(s)     = theta_banks(:,s).' * x_per_bank(:,s);
            d_dec_s(s) = pam_slice_scalar(y_s(s), cfg.A);
        end

        has_ref = (m >= 1 && m <= numel(d));
        is_dd   = has_ref && (m > cfg.trainLen);

        % ---- channel-likelihood score (bank-local previous decision) ----
        score_s = inf(S,1);
        if m >= 2 && m <= numel(r)
            if m <= cfg.trainLen && m <= numel(d)
                for s = 1:S
                    pred = d(m) + h2_states(s)*d(m-1);
                    score_s(s) = (r(m)-pred)^2;
                end
            else
                for s = 1:S
                    if (m-1) >= 1, d_prev_s = d_hat_per_bank(m-1,s);
                    else,          d_prev_s = 0; end
                    pred = d_dec_s(s) + h2_states(s)*d_prev_s;
                    score_s(s) = (r(m)-pred)^2;
                end
            end
        end
        if any(~isfinite(score_s)), score_s = (d_dec_s - y_s).^2; end
        J_s = rho*J_s + (1-rho)*score_s;

        % ---- HMM forward filter (unchanged) ----
        if is_dd && isfield(msb_params,'use_hmm_filter') && msb_params.use_hmm_filter
            pi_pred  = P_hmm.' * pi_state;
            rel      = score_s - min(score_s);
            like     = exp(-rel / max(msb_params.hmm_temp,1e-12));
            pi_state = pi_pred .* like;
            pi_state = pi_state / max(sum(pi_state),1e-12);
        elseif has_ref && ~is_dd && m > train_all_prefix
            [~,s_tr] = min(score_s);
            pi_state = zeros(S,1); pi_state(s_tr) = 1;
        end
        [~, s_hat] = max(pi_state);
        diag.pi_hist(:,n)  = pi_state;
        diag.s_hat_hist(n) = s_hat;
        diag.y_hist(n)     = y_s(s_hat);

        % ---- decision outputs ----
        if has_ref
            for s = 1:S, d_hat_per_bank(m,s) = d_dec_s(s); end
            d_hat_sym(m) = d_dec_s(s_hat);          % external = MAP bank
        end

        % ---- responsibility weights ----
        if use_oracle && has_ref && m <= numel(oracle_state)
            w = zeros(S,1); w(oracle_state(m)) = 1;          % oracle => hard
        elseif soft_enable && is_dd
            w = pi_state.^kappa;
            w = w + w_floor;
            w = w / sum(w);                                  % sum_s w_s = 1
        else
            w = zeros(S,1); w(s_hat) = 1;                    % pilot / hard fallback
        end
        diag.w_hist(:,n) = w;

        % ---- soft (responsibility-weighted) update ----
        if has_ref
            if ~is_dd
                % pilot phase: known symbol; warm-start then state-routed
                if m <= train_all_prefix
                    for s = 1:S
                        theta_banks(:,s) = msb_update_theta(theta_banks(:,s), ...
                            x_per_bank(:,s), d(m)-y_s(s), n, v_base, Kffe);
                    end
                else
                    if use_oracle && m <= numel(oracle_state)
                        s_upd = oracle_state(m);
                    else
                        [~,s_upd] = min(score_s);
                    end
                    theta_banks(:,s_upd) = msb_update_theta(theta_banks(:,s_upd), ...
                        x_per_bank(:,s_upd), d(m)-y_s(s_upd), n, v_base, Kffe);
                end
            else
                % DD phase: SOFT update of every bank, weight w_s.
                % msb_update_theta_scaled applies an extra scalar gain w_s
                % on the NLMS term so the effective step of bank s is mu*w_s.
                for s = 1:S
                    if w(s) <= 0, continue; end
                    e_s = d_dec_s(s) - y_s(s);     % bank-local DD error
                    theta_banks(:,s) = msb_update_theta_scaled(theta_banks(:,s), ...
                        x_per_bank(:,s), e_s, w(s), n, v_base, Kffe);
                end
            end
        end

        for s = 1:S, diag.theta_dfe_hist(s,n) = theta_banks(end,s); end
    end

    diag.theta_banks_final = theta_banks;
    diag.d_hat_per_bank    = d_hat_per_bank;
    diag.params            = msb_params;
end

% =========================================================================
% Companion helper -- place in core/algorithm6_msb/ alongside this file.
% Identical to msb_update_theta but multiplies the *whole* increment by the
% responsibility weight w. With w in [0,1] this is a contraction of the
% step, so (A2)-(A3) of Theorem 2/3 are preserved verbatim: ||H_n|| bound
% and Pi_H non-expansiveness are unchanged, only mu -> mu*w <= mu.
% =========================================================================
function theta_new = msb_update_theta_scaled(theta, x, e, w, n, v_base, Kffe)
    g = (x.'*x) + v_base.delta;
    if isfield(v_base,'lambda_schedule') && v_base.lambda_schedule
        lambda_n = max(v_base.lambda_0/(1+v_base.lambda_alpha*n)^v_base.lambda_beta, ...
                       v_base.lambda_min);
    else
        lambda_n = v_base.lambda;
    end
    mu = get_step_size(n, v_base);
    Hn = -lambda_n*theta + x*(e/g);
    theta_new = theta + (mu*w) * Hn;          % effective step mu*w
    theta_new = Pi_H(theta_new, v_base, Kffe);
end

% =========================================================================
% SUGGESTED VERIFICATION HARNESS (run by the authors in MATLAB)
% -------------------------------------------------------------------------
% 1. Add to default_msb_params_v69:  p.soft_enable=true; p.soft_kappa=2.0;
%    p.soft_wfloor=1e-3;
% 2. In run_mb_ber_compare, add a 7th algorithm column:
%       [dh7,~] = algorithm6_msb_v71_softroute(r, d, cfg_run, v_base, msb_params, []);
% 3. Sweep soft_kappa in {1, 2, 4, 8, Inf}. kappa=Inf must reproduce the
%    hard-routed v70 BER to within trial noise (sanity check).
% 4. Report BER(severe, realistic) and HMM-weighted "effective accuracy"
%    sum_n pi_alpha(n)/N vs the hard accuracy Pr(s_hat=alpha). The gap
%    between them is the theoretical room the soft scheme exploits.
% 5. Expected outcome (to be confirmed, NOT promised): a measurable BER
%    improvement concentrated in the 20-26 dB range of the severe regime,
%    where HMM accuracy is 70-87% (posterior most diffuse). At >=28 dB the
%    posterior is already near-deterministic so soft ~ hard.
% =========================================================================
