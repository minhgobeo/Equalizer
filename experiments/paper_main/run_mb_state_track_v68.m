% Auto-split from NCKH_v53.m (original line 11720).
% Folder: experiments/paper_main

function pkg = run_mb_state_track_v68(cfg, vars, base, mc)
% Verify: (1) banks diverge after burn-in, (2) state estimator tracks
% true state, (3) Algorithm 6 outperforms Algorithm 5 single-bank.

    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    cfg_p.markov.h2_states = [0.30 0.50 0.70];
    cfg_p.markov.P = [0.95 0.05 0.00; 0.025 0.95 0.025; 0.00 0.05 0.95];
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
    cfg_p.SNRdB = 30;
    cfg_p.Nsym = 80000;

    v_base = make_v_alg5(vars.theorem);
    K = cfg_p.Nf; L = cfg_p.Nb;
    main_idx = round((K+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(K,1); ffe_max = v_base.w2_max*ones(K,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    msb_params = default_msb_params();

    rng(1); sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
    d = cfg_p.A(sym_idx).'; d = d(:);
    [r_clean, ch_state] = channel_out(d, cfg_p);
    rng(2); [r,~] = add_noise_dispatch(r_clean, cfg_p);

    fprintf('[mb_state_track_v68] Severe Markov h2=[%s], SNR=30, Nsym=%d\n', ...
            num2str(cfg_p.markov.h2_states, '%.2f '), cfg_p.Nsym);
    fprintf('[mb_state_track_v68] msb_params: B=%d K=%d T_min=%d delta=%.2f rho=%.2f\n', ...
            msb_params.B, msb_params.K, msb_params.T_min, msb_params.delta, msb_params.rho);

    % --- Run Algorithm 6 (estimated state) ---
    [dh_msb, diag_msb] = algorithm6_msb(r, d, cfg_p, v_base, msb_params, []);
    ser_msb = ser_after_training_aligned(d, dh_msb, cfg_p);

    % --- Run oracle-state multi-bank (upper bound) ---
    [dh_orc, diag_orc] = algorithm6_msb(r, d, cfg_p, v_base, msb_params, ch_state.state);
    ser_orc = ser_after_training_aligned(d, dh_orc, cfg_p);

    % --- Run Algorithm 5 single-bank ---
    [dh_a5, diag_a5] = algorithm5_singlebank(r, d, cfg_p, v_base);
    ser_a5 = ser_after_training_aligned(d, dh_a5, cfg_p);

    % --- Run NLMS reference ---
    [~, dh_nlms] = dfe_nlms_unified_x(r, d, cfg_p, base);
    ser_nlms = ser_after_training_aligned(d, dh_nlms, cfg_p);

    % --- Summary ---
    fprintf('\n[mb_state_track_v68] Single-trial SER summary:\n');
    fprintf('  Algorithm 6 (estimated state):  SER = %.3e\n', ser_msb);
    fprintf('  Multi-bank ORACLE state:        SER = %.3e\n', ser_orc);
    fprintf('  Algorithm 5 single-bank:        SER = %.3e\n', ser_a5);
    fprintf('  NLMS reference:                 SER = %.3e\n', ser_nlms);
    N_test = cfg_p.Nsym - cfg_p.trainLen;
    ser_floor = 1 / N_test;

    ser_msb_eff = max(ser_msb, ser_floor);
    ser_orc_eff = max(ser_orc, ser_floor);

    fprintf('\n  Effective SER floor: < %.3e when zero errors\n', ser_floor);
    fprintf('  Alg6 v69 vs Alg5 ratio: %.2fx (>1 = Alg6 wins)\n', ser_a5/ser_msb_eff);
    fprintf('  Alg6 v69 vs NLMS ratio: %.2fx\n', ser_nlms/ser_msb_eff);
    fprintf('  Oracle vs Alg6 gap: %.2fx\n', ser_msb_eff/ser_orc_eff);
    fprintf('  Oracle vs Alg6 ratio: %.2fx (gap due to estimator)\n', ser_msb/max(ser_orc,eps));

    % --- State estimator accuracy ---
    post_idx = (cfg_p.trainLen + diag_msb.N_sep + 1):cfg_p.Nsym;
    state_acc = mean(diag_msb.s_hat_hist(post_idx) == ch_state.state(post_idx));
    fprintf('\n[mb_state_track_v68] State estimator accuracy: %.1f%%\n', 100*state_acc);
    fprintf('[mb_state_track_v68] Number of switches: %d\n', diag_msb.n_switches);
    if ~isempty(diag_msb.dwell_lengths)
        fprintf('[mb_state_track_v68] Mean dwell length: %.1f symbols\n', ...
                mean(diag_msb.dwell_lengths));
    end
    fprintf('[mb_state_track_v68] Bank usage: ');
    fprintf('%.1f%% ', 100*diag_msb.bank_usage);
    fprintf('\n');

    % --- Bank divergence at end ---
    fprintf('\n[mb_state_track_v68] Final theta_DFE per bank (Alg 6 estimated):\n');
    for s = 1:size(diag_msb.theta_banks_final, 2)
        fprintf('  Bank %d: theta_DFE = %.4f\n', s, diag_msb.theta_banks_final(end, s));
    end
    fprintf('  Optimal theta_DFE per state:\n');
    for s = 1:numel(cfg_p.markov.h2_states)
        fprintf('  State %d (h2=%.2f): theta_DFE_opt = %.4f\n', ...
                s, cfg_p.markov.h2_states(s), cfg_p.markov.h2_states(s));
    end

    % --- Plots ---
    figure('Name','mb_state_track_v68: bank divergence & state tracking'); clf;
    tiledlayout(3, 1, 'TileSpacing','compact','Padding','compact');

    % Panel 1: theta_DFE evolution per bank
    nexttile;
    decim = 50;
    n_axis = 1:decim:cfg_p.Nsym;
    colors = {'r','g','b'};
    for s = 1:size(diag_msb.theta_dfe_hist, 1)
        plot(n_axis, diag_msb.theta_dfe_hist(s, 1:decim:end), ...
             colors{s}, 'LineWidth', 1.4); hold on;
    end
    yline(0.30, 'k--', '\theta_{DFE}^*(state 1)=0.30','Alpha',0.5);
    yline(0.50, 'k--', '\theta_{DFE}^*(state 2)=0.50','Alpha',0.5);
    yline(0.70, 'k--', '\theta_{DFE}^*(state 3)=0.70','Alpha',0.5);
    xline(cfg_p.trainLen, 'k:','Train end');
    xline(cfg_p.trainLen + diag_msb.N_sep, 'm:','Burn-in end');
    grid on; xlabel('n'); ylabel('\theta_{DFE} per bank');
    title('Bank divergence: each bank should converge to state-conditional optimum');
    legend({'Bank 1','Bank 2','Bank 3'}, 'Location','best');

    % Panel 2: state tracking (estimator vs oracle)
    nexttile;
    plot(1:decim:cfg_p.Nsym, ch_state.state(1:decim:end), 'k-', 'LineWidth', 1.5); hold on;
    plot(1:decim:cfg_p.Nsym, diag_msb.s_hat_hist(1:decim:end), 'b-', 'LineWidth', 1.0);
    xline(cfg_p.trainLen, 'k:','Train end');
    xline(cfg_p.trainLen + diag_msb.N_sep, 'm:','Burn-in end');
    grid on; xlabel('n'); ylabel('state');
    title(sprintf('State tracking (accuracy %.1f%% post burn-in)', 100*state_acc));
    legend({'True state','Estimated s_{hat}'}, 'Location','best');
    ylim([0.5 3.5]);

    % Panel 3: J_s evolution
    nexttile;
    for s = 1:size(diag_msb.J_hist, 1)
        plot(1:decim:cfg_p.Nsym, diag_msb.J_hist(s, 1:decim:end), ...
             colors{s}, 'LineWidth', 1.0); hold on;
    end
    xline(cfg_p.trainLen, 'k:','Train end');
    xline(cfg_p.trainLen + diag_msb.N_sep, 'm:','Burn-in end');
    grid on; xlabel('n'); ylabel('J_s (EWMA residual)');
    title('Bank scores J_s — lower = better fit for current state');
    legend({'J_1','J_2','J_3'}, 'Location','best');

    pkg.diag_msb = diag_msb;
    pkg.diag_orc = diag_orc;
    pkg.diag_a5  = diag_a5;
    pkg.ser_msb  = ser_msb;
    pkg.ser_orc  = ser_orc;
    pkg.ser_a5   = ser_a5;
    pkg.ser_nlms = ser_nlms;
    pkg.state_acc = state_acc;
    pkg.cfg_p = cfg_p;
end


% ============================================================================
% SECTION-D  —  PATCH B : ALPHA SWEEP (T_min, delta tuning)
% ============================================================================

