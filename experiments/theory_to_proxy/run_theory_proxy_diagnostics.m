function pkg = run_theory_proxy_diagnostics(cfg, vars, base, mc)
%RUN_THEORY_PROXY_DIAGNOSTICS Empirical proxies for Theorem 2 quantities.
%
% v57 implementation (full):
%   For each regime in {severe, realistic} and a fixed SNR:
%     1. Run Algorithm 6 with HMM routing (DD).
%     2. Run Algorithm 6 with oracle routing (true state given).
%     3. Run Algorithm 5 single-bank (DD baseline).
%   Then extract two block-averaged proxies:
%
%     V_tr_hat(n)  = || theta_active(n) - theta_oracle_bank(n) ||^2
%                    -- parameter-tracking proxy.
%
%     B_c_hat(n)   = ( e_DD(n) - e_oracle(n) )^2 / (delta + ||x_n||^2)
%                    -- endogenous-bias proxy.
%
%   Algorithm 5 single-bank also gets a B_c_hat trace; for the single-bank
%   case it represents the cross-state averaging burden Theorem 2 quantifies.
%
% Output: block-averaged proxy traces and final-quartile means.

snr_db  = 22;
regimes = {'severe','realistic'};
Ntrial  = max(5, min(15, mc.Ntrial_ser));
block_M = 500;     % block size for averaging

msb_params = default_msb_params_v69();
msb_params.log_theory_proxy = true;     % v57: enable heavy logging

pkg.regimes = regimes;
pkg.snr_db = snr_db;
pkg.block_M = block_M;
pkg.Vtr_alg6  = cell(numel(regimes),1);
pkg.Bc_alg6   = cell(numel(regimes),1);
pkg.Bc_alg5   = cell(numel(regimes),1);
pkg.summary   = struct();

for rg = 1:numel(regimes)
    cfg_p = reviewer_set_regime(cfg, regimes{rg});
    cfg_p.SNRdB = snr_db;
    cfg_p.Nsym  = 40000;     % shorter to keep theta_active_hist_full memory low

    v_base = make_v_alg5(vars.theorem);
    Kffe = cfg_p.Nf; L = cfg_p.Nb; main_idx = round((Kffe+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    Vtr_blocks = [];
    Bc_blocks  = [];
    Bc_a5_blocks = [];

    for t=1:Ntrial
        rng(960000 + 1000*rg + t);
        sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
        d = cfg_p.A(sym_idx).'; d = d(:);
        [r_clean, ch_state] = channel_out(d, cfg_p);
        [r,~] = add_noise_dispatch(r_clean, cfg_p);

        % HMM-routed (DD)
        [~, diag_msb] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);
        % Oracle-routed (same params, log_theory_proxy on)
        [~, diag_orc] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, ch_state.state);

        % Algorithm 5 single bank with proxy logging via shadow run.
        [~, diag_a5] = algorithm5_singlebank_with_proxy(r, d, cfg_p, v_base);

        % --- V_tr_hat: ||theta_HMM_active - theta_oracle_active||^2 per n
        % Both runs log theta_active_hist_full (Kffe+L x N).
        T_hmm = diag_msb.theta_active_hist_full;
        T_orc = diag_orc.theta_active_hist_full;
        N = size(T_hmm,2);
        Vtr_n = sum((T_hmm - T_orc).^2, 1);    % 1 x N

        % --- B_c_hat: normalised gap of innovation errors
        e_hmm = diag_msb.e_active_hist;        % N x 1
        e_orc = diag_orc.e_active_hist;
        x2_hmm = diag_msb.x_norm2_hist;
        delta = 1e-3;
        Bc_n = ((e_hmm - e_orc).^2) ./ (delta + x2_hmm);

        % --- Single-bank cross-state averaging burden proxy: e_a5 vs e_orc
        e_a5  = diag_a5.e_hist;
        x2_a5 = diag_a5.x_norm2_hist;
        Bc_a5_n = ((e_a5 - e_orc).^2) ./ (delta + x2_a5);

        % Block-average over post-training, post-N_sep window.
        i0 = cfg_p.trainLen + diag_msb.N_sep + 1;
        idx_post = i0:N;
        Vtr_post = Vtr_n(idx_post);
        Bc_post  = Bc_n(idx_post);
        Bca5_post = Bc_a5_n(idx_post);

        Vtr_blk = block_average(Vtr_post(:), block_M);
        Bc_blk  = block_average(Bc_post(:),  block_M);
        Bca5_blk = block_average(Bca5_post(:), block_M);

        if t==1
            Vtr_blocks  = Vtr_blk;
            Bc_blocks   = Bc_blk;
            Bc_a5_blocks = Bca5_blk;
        else
            L_min = min([numel(Vtr_blocks), numel(Vtr_blk)]);
            Vtr_blocks  = Vtr_blocks(1:L_min) + Vtr_blk(1:L_min);
            Bc_blocks   = Bc_blocks(1:L_min)  + Bc_blk(1:L_min);
            L2 = min(numel(Bc_a5_blocks), numel(Bca5_blk));
            Bc_a5_blocks = Bc_a5_blocks(1:L2) + Bca5_blk(1:L2);
        end
    end
    Vtr_blocks  = Vtr_blocks  / Ntrial;
    Bc_blocks   = Bc_blocks   / Ntrial;
    Bc_a5_blocks = Bc_a5_blocks / Ntrial;

    pkg.Vtr_alg6{rg} = Vtr_blocks;
    pkg.Bc_alg6{rg}  = Bc_blocks;
    pkg.Bc_alg5{rg}  = Bc_a5_blocks;

    % Final-quartile means as scalar summary
    q1 = max(1, floor(0.75*numel(Vtr_blocks)));
    pkg.summary.Vtr_alg6_finalQ.(regimes{rg}) = mean(Vtr_blocks(q1:end));
    pkg.summary.Bc_alg6_finalQ.(regimes{rg})  = mean(Bc_blocks(q1:end));
    q1a5 = max(1, floor(0.75*numel(Bc_a5_blocks)));
    pkg.summary.Bc_alg5_finalQ.(regimes{rg})  = mean(Bc_a5_blocks(q1a5:end));

    fprintf('[theory_proxy] %s: V_tr(alg6) final-Q = %.3e, B_c(alg6) = %.3e, B_c(alg5) = %.3e ; ratio alg5/alg6 = %.2fx\n', ...
        regimes{rg}, ...
        pkg.summary.Vtr_alg6_finalQ.(regimes{rg}), ...
        pkg.summary.Bc_alg6_finalQ.(regimes{rg}), ...
        pkg.summary.Bc_alg5_finalQ.(regimes{rg}), ...
        pkg.summary.Bc_alg5_finalQ.(regimes{rg}) / max(pkg.summary.Bc_alg6_finalQ.(regimes{rg}), eps));
end
end

% =====================================================================
function [d_hat_sym, diag] = algorithm5_singlebank_with_proxy(r, d, cfg, v_base)
%ALGORITHM5_SINGLEBANK_WITH_PROXY Same as algorithm5_singlebank but logs e and ||x||^2.

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
    diag.e_hist        = zeros(N, 1);
    diag.x_norm2_hist  = zeros(N, 1);

    for n = 1:N
        r_buf = [r(n); r_buf(1:end-1)];
        m = n - D;
        a_fb = get_fb_vector(m, d, d_hat_sym, cfg, L);
        x = [r_buf; v_base.dfe_sign * a_fb];
        diag.x_norm2_hist(n) = x.' * x;

        y = theta.' * x;
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
            diag.e_hist(n) = e;

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

% =====================================================================
function v_blk = block_average(v, M)
% BLOCK_AVERAGE  Non-overlapping block mean of length M.
n = numel(v);
nb = floor(n / M);
v_blk = zeros(nb,1);
for k = 1:nb
    v_blk(k) = mean(v((k-1)*M + (1:M)));
end
end
