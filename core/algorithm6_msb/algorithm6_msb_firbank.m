function [d_hat_sym, diag] = ...
        algorithm6_msb_firbank(r, d, cfg, v_base, msb_params, h_bank, oracle_state)
%ALGORITHM6_MSB_FIRBANK  Algorithm 6 with FIR channel-likelihood routing.
%
% This is for S-parameter-derived benchmarks where each Markov state is a
% full symbol-rate impulse response, not only a scalar h2 postcursor.
% Adaptation remains the same bank-local DFE recursion as v70.

N = numel(r);
Kffe = cfg.Nf; L = cfg.Nb; D = cfg.D;
S = numel(h_bank);
B = msb_params.B; Kb = msb_params.K;
T_min = msb_params.T_min; delta = msb_params.delta; rho = msb_params.rho;
N_sep = S * B * Kb;
use_oracle = nargin >= 7 && ~isempty(oracle_state);
oracle_train_only = isfield(msb_params, 'oracle_train_only') && msb_params.oracle_train_only;

if ~isfield(msb_params,'train_all_prefix')
    msb_params.train_all_prefix = 1000;
end
train_all_prefix = min(msb_params.train_all_prefix, cfg.trainLen);
if isfield(msb_params,'P_assumed') && ~isempty(msb_params.P_assumed)
    P_hmm = msb_params.P_assumed;
else
    P_hmm = cfg.markov.P;
end

theta_init = zeros(Kffe+L, 1);
theta_init(v_base.main_idx) = v_base.w_main_value;
theta_init = Pi_H(theta_init, v_base, Kffe);
theta_banks = repmat(theta_init, 1, S);
if isfield(msb_params, 'init_from_hbank') && msb_params.init_from_hbank
    for s = 1:S
        theta_banks(:,s) = local_pulse_init_theta(h_bank{s}, Kffe, L, D, v_base);
    end
end
d_hat_per_bank = zeros(numel(d), S);
d_hat_sym = zeros(numel(d), 1);
use_adaptive_threshold = isfield(msb_params, 'adaptive_threshold') && msb_params.adaptive_threshold;
A_thr = sort(cfg.A(:));
thr_banks = repmat((A_thr(1:end-1) + A_thr(2:end))/2, 1, S);
level_mu_banks = repmat(A_thr(:), 1, S);

J_s = zeros(S, 1);
s_hat = 1;
T_dwell = 0;
n_switches = 0;
last_switch_n = 0;
pi_state = ones(S,1) / S;
r_buf = zeros(Kffe, 1);
score_spread_ema = 0.1;  % for adaptive tau_hmm

diag = struct();
diag.pi_hist = zeros(S, N);
diag.s_hat_hist = zeros(N, 1);
diag.s_train_hist = zeros(N, 1);
diag.J_hist = zeros(S, N);
diag.score_inst_hist = zeros(S, N);
diag.theta_dfe_hist = zeros(S, N);
diag.y_hist = zeros(N, 1);
diag.bank_active = zeros(S, 1);
diag.bank_active_post = zeros(S, 1);
diag.n_switches = 0;
diag.dwell_lengths = [];
diag.P_hmm = P_hmm;
diag.P_true = cfg.markov.P;
diag.conf_ratio_hist = zeros(N,1);
diag.update_allowed_hist = zeros(N,1);
diag.theta_update_hist = zeros(N,1);
diag.posterior_entropy_hist = zeros(N,1);
diag.dd_bias_proxy_hist = zeros(N,1);
diag.dd_bias_dfe_proxy_hist = zeros(N,1);
diag.cross_state_memory_hist = zeros(N,1);
diag.buffer_mode = 'bank_local_fir_score';
diag.h_bank = h_bank;

for n = 1:N
    r_buf = [r(n); r_buf(1:end-1)];
    m = n - D;
    s_hat_new = s_hat;

    x_per_bank = zeros(Kffe+L, S);
    y_s = zeros(S, 1);
    d_dec_s = zeros(S, 1);
    for s = 1:S
        a_fb_s = get_fb_vector(m, d, d_hat_per_bank(:,s), cfg, L);
        x_per_bank(:,s) = [r_buf; v_base.dfe_sign * a_fb_s];
        y_s(s) = theta_banks(:, s).' * x_per_bank(:,s);
        if use_adaptive_threshold
            d_dec_s(s) = local_pam_slice_thr(y_s(s), A_thr, thr_banks(:,s));
        else
            d_dec_s(s) = pam_slice_scalar(y_s(s), cfg.A);
        end
    end

    has_ref = (m >= 1 && m <= numel(d));
    is_dd = has_ref && (m > cfg.trainLen);

    score_s = inf(S,1);
    score_mode = 'fir_likelihood';
    if isfield(msb_params, 'score_mode') && ~isempty(msb_params.score_mode)
        score_mode = msb_params.score_mode;
    end
    if has_ref
        for s = 1:S
            switch lower(score_mode)
                case {'equalizer_error','decision_error','slicer_error'}
                    score_s(s) = (d_dec_s(s) - y_s(s))^2;
                otherwise
                    % The equalizer decision at time n corresponds to symbol
                    % m=n-D.  Channel-likelihood scoring must therefore
                    % compare the FIR prediction for symbol time m against
                    % r(m), not r(n), otherwise the router is offset by the
                    % equalizer delay and collapses toward random routing.
                    obs_idx = max(1, min(numel(r), m));
                    score_s(s) = (r(obs_idx) - local_fir_pred(m, s, d, d_dec_s(s), ...
                        d_hat_per_bank(:,s), h_bank{s}, is_dd))^2;
            end
        end
    end
    if any(~isfinite(score_s))
        score_s = (d_dec_s - y_s).^2;
    end
    J_s = rho * J_s + (1 - rho) * score_s;
    diag.J_hist(:, n) = J_s;
    diag.score_inst_hist(:, n) = score_s;

    if S >= 2
        sc_sorted = sort(score_s);
        conf_gap = (sc_sorted(2) - sc_sorted(1)) / (sc_sorted(2) + sc_sorted(1) + 1e-12);
    else
        conf_gap = 1;
    end
    diag.conf_ratio_hist(n) = conf_gap;

    update_allowed = true;
    if isfield(msb_params, 'use_update_conf_gate') && msb_params.use_update_conf_gate
        update_allowed = conf_gap >= msb_params.update_conf_gap;
    end
    diag.update_allowed_hist(n) = double(update_allowed);

    use_oracle_now = use_oracle && has_ref && (~oracle_train_only || ~is_dd);

    if use_oracle_now
        if m <= numel(oracle_state)
            s_hat_new = oracle_state(m);
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
            route_score_s = score_s;
            if isfield(msb_params, 'eb_gate') && ...
                    local_getfield(msb_params.eb_gate, 'use_decision_reliability_route', false)
                decision_residual_s = (y_s(:) - d_dec_s(:)).^2;
                decision_residual_s = decision_residual_s - min(decision_residual_s);
                route_weight = local_getfield(msb_params.eb_gate, 'decision_reliability_weight', 0.15);
                route_score_s = route_score_s + route_weight * decision_residual_s;
            end
            rel_score = route_score_s - min(route_score_s);
            if isfield(msb_params, 'use_adaptive_tau') && msb_params.use_adaptive_tau
                J_spread = max(J_s) - min(J_s);
                ema_atau = local_getfield(msb_params, 'tau_ema_alpha', 0.99);
                tau_calib_v = local_getfield(msb_params, 'tau_calib', 2.0);
                tau_min_v = local_getfield(msb_params, 'tau_min', 1e-3);
                tau_max_v = local_getfield(msb_params, 'tau_max', 0.5);
                score_spread_ema = ema_atau * score_spread_ema + (1-ema_atau) * J_spread;
                tau_hmm = min(tau_max_v, max(tau_min_v, tau_calib_v / (score_spread_ema + 1e-6)));
            else
                tau_hmm = msb_params.hmm_temp;
            end
            like = exp(-rel_score / max(tau_hmm, 1e-12));
            pi_state = pi_pred .* like;
            pi_state = pi_state / max(sum(pi_state), 1e-12);
            [~, s_hat_new] = max(pi_state);

            % Transition gate: lock to current state if HMM confidence too low
            if isfield(msb_params, 'use_transition_gate') && msb_params.use_transition_gate
                pi_sorted = sort(pi_state, 'descend');
                trans_gate_conf_threshold = local_getfield(msb_params, 'trans_gate_conf_threshold', 0.50);
                trans_conf = (pi_sorted(1) - pi_sorted(min(2,S))) / (pi_sorted(1) + pi_sorted(min(2,S)) + 1e-12);
                if trans_conf < trans_gate_conf_threshold
                    s_hat_new = s_hat;  % lock to current state
                end
            end

            diag.pi_hist(:,n) = pi_state;
            if isfield(msb_params, 'eb_gate') && ...
                    local_getfield(msb_params.eb_gate, 'use_fast_reroute', false)
                posterior_entropy_now = -sum(pi_state .* log(max(pi_state, 1e-12))) / max(log(S), eps);
                reroute_entropy = local_getfield(msb_params.eb_gate, 'reroute_entropy', 0.33);
                reroute_conf_gap = local_getfield(msb_params.eb_gate, 'reroute_conf_gap', 0.55);
                reroute_pi_reset = local_getfield(msb_params.eb_gate, 'reroute_pi_reset', 0.75);
                [~, s_score] = min(route_score_s);
                if posterior_entropy_now >= reroute_entropy && conf_gap >= reroute_conf_gap
                    s_hat_new = s_score;
                    pi_state = (1 - reroute_pi_reset) * pi_state;
                    pi_state(s_score) = pi_state(s_score) + reroute_pi_reset;
                    pi_state = pi_state / max(sum(pi_state), 1e-12);
                    diag.pi_hist(:,n) = pi_state;
                end
            end
        else
            [J_min, s_min] = min(J_s);
            if n_dd <= N_sep
                s_hat_new = s_min;
            else
                T_dwell = T_dwell + 1;
                if T_dwell >= T_min && J_min < (1 - delta) * J_s(s_hat)
                    s_hat_new = s_min;
                end
            end
        end
    end

    if s_hat_new ~= s_hat
        n_switches = n_switches + 1;
        diag.dwell_lengths(end+1) = n - last_switch_n; %#ok<AGROW>
        last_switch_n = n;
        T_dwell = 0;
    end
    s_hat = s_hat_new;
    diag.s_hat_hist(n) = s_hat;
    diag.bank_active(s_hat) = diag.bank_active(s_hat) + 1;
    if has_ref && is_dd && (m > cfg.trainLen + N_sep)
        diag.bank_active_post(s_hat) = diag.bank_active_post(s_hat) + 1;
    end

    s_out = s_hat;
    if is_dd && isfield(msb_params, 'eb_gate') && ...
            local_getfield(msb_params.eb_gate, 'use_output_reliability_select', false)
        output_entropy_min = local_getfield(msb_params.eb_gate, 'output_select_entropy', 0.25);
        output_margin = local_getfield(msb_params.eb_gate, 'output_select_margin', 0.0);
        posterior_entropy_now = -sum(pi_state .* log(max(pi_state, 1e-12))) / max(log(S), eps);
        dec_res = (y_s(:) - d_dec_s(:)).^2;
        [dec_best, s_dec] = min(dec_res);
        if posterior_entropy_now >= output_entropy_min && ...
                dec_best + output_margin < dec_res(s_hat)
            s_out = s_dec;
        end
    end
    if is_dd && isfield(msb_params, 'eb_gate') && ...
            local_getfield(msb_params.eb_gate, 'use_nominal_fallback_output', false)
        posterior_entropy_now = -sum(pi_state .* log(max(pi_state, 1e-12))) / max(log(S), eps);
        fallback_entropy = local_getfield(msb_params.eb_gate, 'nominal_fallback_entropy', 0.32);
        if posterior_entropy_now >= fallback_entropy
            s_out = min(S, max(1, local_getfield(msb_params.eb_gate, 'nominal_state', ceil(S/2))));
        end
    end
    % Soft posterior-weighted output reduces eye variance during uncertain routing
    use_soft_out = is_dd && S >= 2 && ...
        isfield(msb_params, 'use_soft_output') && msb_params.use_soft_output;
    if use_soft_out
        y_out = pi_state(:).' * y_s(:);
    else
        y_out = y_s(s_out);
    end
    diag.y_hist(n) = y_out;

    if has_ref
        for s = 1:S
            d_hat_per_bank(m, s) = d_dec_s(s);
        end
        if use_soft_out
            d_hat_sym(m) = pam_slice_scalar(y_out, cfg.A);
        else
            d_hat_sym(m) = d_dec_s(s_out);
        end
    end

    if has_ref && is_dd
        delta_dd = d_dec_s(s_hat) - d(m);
        p2_active = (x_per_bank(:,s_hat).' * x_per_bank(:,s_hat)) + 1e-12;
        diag.dd_bias_proxy_hist(n) = abs(delta_dd) * norm(x_per_bank(:,s_hat)) / p2_active;
        if L > 0
            diag.dd_bias_dfe_proxy_hist(n) = abs(delta_dd) * norm(x_per_bank(Kffe+1:end,s_hat)) / p2_active;
        end
        % Estimate cross-state DFE memory from estimated state history (no oracle needed)
        % This enables the EB gate's lambda_cross term during DD phase
        cur_s = s_hat;
        n_mem_est = 0; n_cross_est = 0;
        for kk = 1:L
            idx_mem = n - kk;
            if idx_mem >= 1
                n_mem_est = n_mem_est + 1;
                n_cross_est = n_cross_est + double(diag.s_hat_hist(idx_mem) ~= cur_s);
            end
        end
        diag.cross_state_memory_hist(n) = n_cross_est / max(n_mem_est, 1);
    end

    pi_tmp = diag.pi_hist(:,n);
    if any(pi_tmp > 0)
        pi_tmp = pi_tmp / max(sum(pi_tmp), 1e-12);
    else
        pi_tmp = pi_state;
    end
    diag.posterior_entropy_hist(n) = -sum(pi_tmp .* log(max(pi_tmp, 1e-12))) / max(log(S), eps);
    n_dd_cur = 0;
    if is_dd, n_dd_cur = m - cfg.trainLen; end
    eb_ctx = struct( ...
        'is_dd', is_dd, ...
        'posterior_entropy', diag.posterior_entropy_hist(n), ...
        'confidence_gap', diag.conf_ratio_hist(n), ...
        'cross_state_memory', diag.cross_state_memory_hist(n), ...
        'dd_bias_proxy', diag.dd_bias_proxy_hist(n), ...
        'dd_bias_dfe_proxy', diag.dd_bias_dfe_proxy_hist(n), ...
        'n_dd', n_dd_cur);

    if has_ref
        did_any_update = false;
        if ~is_dd
            if m <= train_all_prefix
                d_ref = d(m);
                for s = 1:S
                    [theta_banks(:,s), did_update] = local_firbank_update_theta(theta_banks(:,s), ...
                        x_per_bank(:,s), d_ref - y_s(s), n, v_base, Kffe, msb_params, eb_ctx);
                    did_any_update = did_any_update || did_update;
                    if use_adaptive_threshold && m > round(cfg.trainLen/4)
                        [thr_banks(:,s), level_mu_banks(:,s)] = local_update_thresholds( ...
                            y_s(s), d_ref, A_thr, thr_banks(:,s), level_mu_banks(:,s), msb_params);
                    end
                end
            else
                [~, s_upd] = min(score_s);
                if use_oracle_now && m <= numel(oracle_state), s_upd = oracle_state(m); end
                [theta_banks(:,s_upd), did_any_update] = local_firbank_update_theta(theta_banks(:,s_upd), ...
                    x_per_bank(:,s_upd), d(m) - y_s(s_upd), n, v_base, Kffe, msb_params, eb_ctx);
                if use_adaptive_threshold && m > round(cfg.trainLen/4)
                    [thr_banks(:,s_upd), level_mu_banks(:,s_upd)] = local_update_thresholds( ...
                        y_s(s_upd), d(m), A_thr, thr_banks(:,s_upd), level_mu_banks(:,s_upd), msb_params);
                end
            end
        elseif update_allowed && ~(isfield(msb_params, 'freeze_dd_update') && msb_params.freeze_dd_update)
            [theta_banks(:,s_hat), did_any_update] = local_firbank_update_theta(theta_banks(:,s_hat), ...
                x_per_bank(:,s_hat), d_dec_s(s_hat) - y_s(s_hat), n, v_base, Kffe, msb_params, eb_ctx);
            if use_adaptive_threshold
                [thr_banks(:,s_hat), level_mu_banks(:,s_hat)] = local_update_thresholds( ...
                    y_s(s_hat), d_dec_s(s_hat), A_thr, thr_banks(:,s_hat), level_mu_banks(:,s_hat), msb_params);
            end
        end
        diag.theta_update_hist(n) = double(did_any_update);
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
diag.d_hat_per_bank = d_hat_per_bank;
end

function [theta_new, did_update] = local_firbank_update_theta(theta, x, e, n, v_base, Kffe, msb_params, eb_ctx)
did_update = true;
if nargin < 8 || isempty(eb_ctx)
    eb_ctx = struct('is_dd', false, 'posterior_entropy', 0, ...
        'confidence_gap', 1, 'cross_state_memory', 0, ...
        'dd_bias_proxy', 0, 'dd_bias_dfe_proxy', 0, 'n_dd', 0);
end
rule = 'alg5';
if isfield(msb_params, 'bank_update_rule') && ~isempty(msb_params.bank_update_rule)
    rule = lower(msb_params.bank_update_rule);
end

switch rule
    case {'smnlms','set_membership_nlms'}
        sigma2 = 0;
        if isfield(msb_params, 'sigma2') && isfinite(msb_params.sigma2)
            sigma2 = msb_params.sigma2;
        end
        tau = 2.0;
        beta = 0.8;
        eps_p = 1e-6;
        if isfield(msb_params, 'smnlms')
            if isfield(msb_params.smnlms, 'tau'), tau = msb_params.smnlms.tau; end
            if isfield(msb_params.smnlms, 'beta'), beta = msb_params.smnlms.beta; end
            if isfield(msb_params.smnlms, 'eps_pow'), eps_p = msb_params.smnlms.eps_pow; end
        end
        gamma = sqrt(max(0, tau * sigma2));
        gamma_scale = 1.0;
        beta_scale = 1.0;
        if isfield(msb_params, 'eb_gate') && isfield(msb_params.eb_gate, 'enabled') && ...
                msb_params.eb_gate.enabled && eb_ctx.is_dd
            g = msb_params.eb_gate;
            lambda_entropy = local_getfield(g, 'lambda_entropy', 1.0);
            lambda_cross = local_getfield(g, 'lambda_cross', 3.0);
            lambda_conf = local_getfield(g, 'lambda_confidence', 0.5);
            gamma_max_scale = local_getfield(g, 'gamma_max_scale', 3.0);
            beta_min_scale = local_getfield(g, 'beta_min_scale', 0.35);
            uncertainty = max(0, 1 - eb_ctx.confidence_gap);
            gamma_scale = 1 + lambda_entropy * eb_ctx.posterior_entropy + ...
                lambda_cross * eb_ctx.cross_state_memory + lambda_conf * uncertainty;
            gamma_scale = min(max(gamma_scale, 1.0), gamma_max_scale);
            beta_scale = max(beta_min_scale, 1 / gamma_scale);
        end
        gamma = gamma * gamma_scale;
        beta = beta * beta_scale;
        % Optional beta annealing: reduce step size after convergence to lower
        % adaptation noise (improves steady-state eye height for static channels)
        if isfield(msb_params, 'use_beta_anneal') && msb_params.use_beta_anneal && eb_ctx.is_dd
            halflife_dd = local_getfield(msb_params, 'anneal_halflife', 5000);
            anneal_floor = local_getfield(msb_params, 'anneal_floor', 0.35);
            n_dd = local_getfield(eb_ctx, 'n_dd', 0);
            decay_factor = anneal_floor + (1 - anneal_floor) * exp(-n_dd * log(2) / halflife_dd);
            beta = beta * decay_factor;
        end
        theta_new = theta;
        if abs(e) > gamma
            p2 = (x.' * x) + eps_p;
            mu_sm = beta * (1 - gamma / max(abs(e), eps));
            theta_new = theta + (mu_sm * e / p2) * x;
            theta_new = Pi_H(theta_new, v_base, Kffe);
        else
            did_update = false;
        end
    otherwise
        theta_new = msb_update_theta(theta, x, e, n, v_base, Kffe);
end
end

function v = local_getfield(s, name, default)
if isfield(s, name) && ~isempty(s.(name)) && isfinite(s.(name))
    v = s.(name);
else
    v = default;
end
end

function pred = local_fir_pred(m, s, d, d_cur_dec, d_hat_s, h, is_dd)
h = h(:);
pred = 0;
for k = 1:numel(h)
    idx = m - k + 1;
    if idx < 1, continue; end
    if ~is_dd
        if idx <= numel(d), sym = d(idx); else, sym = 0; end
    else
        if k == 1
            sym = d_cur_dec;
        elseif idx <= numel(d_hat_s)
            sym = d_hat_s(idx);
        else
            sym = 0;
        end
    end
    pred = pred + h(k) * sym;
end
end

function s = local_pam_slice_thr(z, A, thr)
if z < thr(1)
    s = A(1);
    return;
end
for k = 1:numel(thr)-1
    if z < thr(k+1)
        s = A(k+1);
        return;
    end
end
s = A(end);
end

function [thr, mu_levels] = local_update_thresholds(z, d_ref, A, thr, mu_levels, msb_params)
mu_thr = local_getfield(msb_params, 'threshold_mu', 2e-3);
clip_margin = local_getfield(msb_params, 'threshold_clip_margin', 0.95);
[~, lev_idx] = min(abs(A(:) - d_ref));
mu_levels(lev_idx) = (1 - mu_thr) * mu_levels(lev_idx) + mu_thr * z;
mu_levels = sort(mu_levels(:));
thr = (mu_levels(1:end-1) + mu_levels(2:end)) / 2;
span = max(A) - min(A);
lo = min(A) - clip_margin * span;
hi = max(A) + clip_margin * span;
thr = sort(min(max(thr, lo), hi));
end

function theta = local_pulse_init_theta(h, Kffe, L, D, v_base)
h = h(:).';
M = numel(h);
Lconv = Kffe + M - 1;
H = zeros(Lconv, Kffe);
for k = 1:Kffe
    H(k:k+M-1, k) = h(:);
end
D_eq = max(0, min(D, Lconv-1));
target = zeros(Lconv, 1);
target(D_eq+1) = 1;
lambda = 1e-3;
w_ffe = (H.' * H + lambda * eye(Kffe)) \ (H.' * target);
g = conv(w_ffe, h);
w_dfe = g(D_eq+2 : min(D_eq+1+L, numel(g)));
if numel(w_dfe) < L
    w_dfe(end+1:L) = 0;
end
theta = [w_ffe(:); w_dfe(:)];
theta = Pi_H(theta, v_base, Kffe);
end
