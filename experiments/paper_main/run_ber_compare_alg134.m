% Auto-split from NCKH_v53.m (original line 11170).
% Folder: experiments/paper_main

function pkg = run_ber_compare_alg134(cfg_p, vars, base, mc, tag, snr_list)
% Compare Algorithm 1, 3, 4 vs all baselines on cfg_p.
 
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end
 
    % Algorithm 4 with best-tuned alpha (will fine-tune later)
    v_alg4 = make_v_with_sbc(vars.theorem, 0.75, 5e-3);
 
    Nsnr = numel(snr_list);
    Nalg = 7;     % Alg1, Alg3, Alg4, LMS, NLMS, SM-sign-VSS, SM-sign
    BER = zeros(Nsnr, Nalg);
    err_count = zeros(Nsnr, Nalg);
 
    Nt = max(mc.Ntrial_ser, 20);
    fprintf('[%s] Algorithm 1 vs 3 vs 4 vs baselines\n', tag);
    fprintf('[%s] %d trials, %d SNR points (NO AGC)\n', tag, Nt, Nsnr);
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(31000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean,~] = channel_out(d, cfg_p);
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
 
            % Alg 1: original
            [~, dh1] = proposed_recursion(r, d, cfg_run, vars.theorem);
            % Alg 3: lambda schedule (alpha=0)
            v_alg3 = make_v_with_sbc(vars.theorem, 0, 5e-3);
            [~, dh3] = proposed_recursion_sbc(r, d, cfg_run, v_alg3);
            % Alg 4: SBC
            [~, dh4] = proposed_recursion_sbc(r, d, cfg_run, v_alg4);
            % Baselines
            [~, dh5] = dfe_lms_unified_x (r, d, cfg_run, base);
            [~, dh6] = dfe_nlms_unified_x(r, d, cfg_run, base);
            [~, dh7] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_run, base, sigma2);
            [~, dh8] = dfe_smsign_nlms_unified_x    (r, d, cfg_run, base, sigma2);
 
            dhs = {dh1, dh3, dh4, dh5, dh6, dh7, dh8};
            for a = 1:Nalg
                ser_val = ser_after_training_aligned(d, dhs{a}, cfg_run);
                BER(si, a) = BER(si, a) + ser_val / log2(cfg_p.M);
                err_count(si, a) = err_count(si, a) + ser_val * N_postTrain;
            end
        end
        if mod(t,4)==0, fprintf('  [%s] trial %d/%d\n', tag, t, Nt); end
    end
    BER = BER / Nt;
 
    names = {'Alg 1 (original)','Alg 3 (\lambda sched)','Alg 4 (SBC, NEW)', ...
             'LMS','NLMS','SM-sign-NLMS VSS','SM-sign-NLMS'};
 
    fprintf('\n[%s] BER table:\n', tag);
    fprintf('  SNR ');
    for a = 1:Nalg, fprintf('%22s ', names{a}); end
    fprintf('\n');
    for si = 1:Nsnr
        fprintf('  %2d  ', snr_list(si));
        for a = 1:Nalg
            if err_count(si, a) < 0.5
                fprintf('%22s ', sprintf('<%.1e', bit_floor));
            else
                fprintf('%22.3e ', BER(si, a));
            end
        end
        fprintf('\n');
    end
 
    fprintf('\n[%s] Algorithm 4 (NEW) vs each baseline (max ratio over SNR sweep):\n', tag);
    a_alg4 = 3;
    for a = 4:Nalg
        max_ratio = 0;
        for si = 1:Nsnr
            if BER(si,a_alg4) > 0 && BER(si,a) > 0
                r = BER(si,a) / BER(si,a_alg4);
                if r > max_ratio, max_ratio = r; end
            end
        end
        fprintf('  %-22s  max %s/Alg4 ratio: %.2fx\n', ...
                names{a}, names{a}, max_ratio);
    end
 
    fprintf('\n[%s] SNR thresholds:\n', tag);
    fprintf('  %-22s  %8s  %8s  %8s\n', 'Algorithm', '1e-3', '1e-4', '1e-5');
    for a = 1:Nalg
        th = NaN(1,3); tgts = [1e-3 1e-4 1e-5];
        for k = 1:3
            idx = find(BER(:,a) <= tgts(k), 1, 'first');
            if ~isempty(idx), th(k) = snr_list(idx); end
        end
        fprintf('  %-22s  ', names{a});
        for k = 1:3
            if isnan(th(k)), fprintf('%8s  ', 'N/A');
            else,            fprintf('%8d  ', th(k)); end
        end
        fprintf('\n');
    end
 
    BER_disp = max(BER, bit_floor);
 
    figure('Name', sprintf('BER-Fig (v67): %s — Alg 1/3/4 vs baselines', tag));
    clf;
    ccolors = {[0.85 0.33 0.10], [0.49 0.18 0.56], [0 0.45 0.74], ...
               [0.93 0.69 0.13], [0.30 0.75 0.93], [0.47 0.67 0.19], [0.5 0.5 0.5]};
    marks = {'x','d','o','s','>','^','v'};
    for a = 1:Nalg
        lw = 1.4; if a == 3, lw = 2.6; end   % Alg 4 highlighted
        ms = 7;   if a == 3, ms = 10; end
        semilogy(snr_list, BER_disp(:,a), ['-' marks{a}], ...
                 'Color', ccolors{a}, 'LineWidth', lw, ...
                 'MarkerFaceColor', ccolors{a}, 'MarkerSize', ms);
        hold on;
    end
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2);
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2);
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2);
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title(sprintf('%s: Algorithm 1 → 3 → 4 progression vs baselines', tag));
    legend(names, 'Location','best');
    ylim([bit_floor/3, 1]);
 
    pkg.snr_list = snr_list;
    pkg.BER = BER; pkg.err_count = err_count;
    pkg.names = names;
    pkg.bit_floor = bit_floor;
    pkg.cfg_p = cfg_p;
end

% ============================================================================
% PROPOSITION 17 (DRAFT for paper Section IV)
% ============================================================================
%  Proposition 17 (Robbins-Monro regularization decay).  Suppose the
%  assumptions of Theorem 2 hold with the modification that lambda is
%  replaced by a positive sequence {lambda_n} satisfying
%
%      sum_{n=0}^{inf} lambda_n = inf,    sum_{n=0}^{inf} lambda_n^2 < inf
%
%  (Robbins-Monro conditions).  Then the time-average tracking floor of the
%  modified DD recursion satisfies
%
%      Delta*_RM <= Delta_burden + Delta_floor
%
%  where Delta_pd vanishes as N -> infinity.  In particular, the
%  regularization-induced shrinkage bias in the DFE coefficient is
%  asymptotically eliminated.
%
%  Proof sketch: lambda_n -> 0 implies the equilibrium offset term
%  C_r in T2-P2 vanishes asymptotically, while sum lambda_n = inf
%  preserves the contraction property required by Lemma T2-L4. The
%  Robbins-Monro condition sum lambda_n^2 < inf controls the variance
%  contribution of the time-varying restoration term.
% ============================================================================


% ============================================================================
% EOF  NCKH_v51_patches_v66.m
% ============================================================================
% ============================================================================
% PROPOSITION 16  (DRAFT for paper Section IV)
% ============================================================================
% Proposition 16 (Multi-bank extension of Theorem 1 to Markov channels).
% Suppose Assumption (A1)-(A6) of Theorem 1 hold for each frozen state s in
% {1,...,S} of the Markov chain {alpha_n}.  Let theta^(s)_n denote the n-th
% iterate of the s-th equalizer bank in the MSBank-EQ scheme, where bank s
% is updated at step n iff hat{s}_n = s, and hat{s}_n is the MAP state
% estimate from a window-W moving average of bank residuals.  If the state
% estimator is consistent (lim_{n->inf} P(hat{s}_n = alpha_n) = 1) and the
% Markov chain is ergodic, then for each s:
%
%   limsup_{n->inf} E[||theta^(s)_n - theta*(s)||^2] <= Delta*(s)
%
% where theta*(s) is the bias-free fixed point under frozen state s, and
% Delta*(s) is the per-state floor satisfying Delta*(s) <= Delta*_global,
% with strict inequality when B_c(s) < B_c_global.
%
% Corollary 4 (Burden reduction).  The total expected tracking error of
% MSBank-EQ satisfies
%
%   E[||theta_{hat{s}_n,n} - theta*(alpha_n)||^2] = sum_s pi(s) Delta*(s)
%
% where pi is the stationary distribution.  This is strictly less than the
% single-bank floor Delta*_global whenever the channel modes induce
% separated bias structures (B_c(s_i) != B_c(s_j) for some i != j).
% ============================================================================

% ============================================================================
% EOF  NCKH_v51_patches_v53.m
% ============================================================================
% =========================================================================
%  MODE USAGE SUMMARY
% =========================================================================
% demo_v44_pam4_sa_markov_ptf_complete('quick')            — fast iteration
% demo_v44_pam4_sa_markov_ptf_complete('supplement_fast')   — Groups 2-7
% demo_v44_pam4_sa_markov_ptf_complete('supplement')        — Groups 1-7
% demo_v44_pam4_sa_markov_ptf_complete('final')             — full submission
% =========================================================================

% ============================================================================
%  NCKH_v51_patches_v68.m
%  ---------------------------------------------------------------------------
%  ALGORITHM 6 — Multi-State-Bank Adaptive Equalizer (MSB-EQ)
%
%  Design (after consolidating reviewer feedback):
%
%    Base learner per bank: Algorithm 5
%      = NLMS-like core + lambda_n schedule
%      = NO gate, NO clip, NO CLR, NO AGC, NO SBC
%
%    Architecture:
%      S = numel(cfg.markov.h2_states) parallel banks
%      Shared decision buffer (single output stream)
%      EWMA residual score for ALL banks (not just active)
%      Hard switching with hysteresis (dwell + margin)
%      Symmetry-breaking burn-in (round-robin block assignment)
%
%    Algorithm logic (after warm-start with supervised training):
%
%    Phase 0 (init): banks identical from training, J_s = 0
%
%    Phase 1 (separation burn-in, length N_sep = S*B*K):
%      block_idx = floor((n - trainLen) / B) mod S
%      s_hat = block_idx + 1                (round-robin)
%      Update J_s for ALL banks
%      Update only theta_{s_hat}
%
%    Phase 2 (full operation, n > trainLen + N_sep):
%      Compute y_s, d_hat_s, r_s for all S banks
%      Update J_s = rho * J_s + (1-rho) * r_s for all banks
%      s_min = argmin_s J_s
%      Switch to s_min if dwell >= T_min AND J[s_min] < (1-delta) * J[s_hat]
%      Update only theta_{s_hat}
%
%  Test plan (4 case handlers + 4 baselines):
%    BASELINES:
%      single-bank Algorithm 5  (must beat to claim multi-bank works)
%      oracle-state multi-bank  (upper bound; perfect state knowledge)
%      NLMS, SM-sign-NLMS, SM-sign-NLMS VSS  (paper baselines)
%
%    CASES:
%      mb_state_track_v68     verify state estimator accuracy + bank divergence
%      mb_alpha_sweep_v68     find optimal (T_min, delta) on severe Markov
%      mb_ber_severe_v68      BER vs all baselines on severe Markov
%      mb_ber_realistic_v68   BER vs all baselines on realistic Markov
%
%  Verification goals (per reviewer):
%    1. Banks divergence: theta_s become distinct after burn-in
%    2. State estimator accuracy: s_hat tracks true state > 70%
%    3. Algorithm 6 > Algorithm 5 single-bank on severe Markov
% ============================================================================


% ============================================================================
% SECTION-A  —  CASE HANDLERS
% ============================================================================
%
%       case 'mb_state_track_v68'
%           out.mb_track = run_mb_state_track_v68(cfg, vars, base, mc);
%           return;
%
%       case 'mb_alpha_sweep_v68'
%           out.mb_sweep = run_mb_alpha_sweep_v68(cfg, vars, base, mc);
%           return;
%
%       case 'mb_ber_severe_v68'
%           out.mb_ber_severe = run_mb_ber_severe_v68(cfg, vars, base, mc);
%           return;
%
%       case 'mb_ber_realistic_v68'
%           out.mb_ber_realistic = run_mb_ber_realistic_v68(cfg, vars, base, mc);
%           return;
% ============================================================================


% ============================================================================
% SECTION-B  —  ALGORITHM 5 (single-bank baseline) and ALGORITHM 6 CORE
% ============================================================================

