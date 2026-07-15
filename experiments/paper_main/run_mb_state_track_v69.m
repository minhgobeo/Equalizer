% Auto-split from NCKH_v53.m (original line 12537).
% Folder: experiments/paper_main

function pkg = run_mb_state_track_v69(cfg, vars, base, mc)
% Same as v68 diagnostic, but using algorithm6_msb_v69.

    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    mkprof = controlled_markov_isi_profile_v72('profile', 'severe_partial_response');
    cfg_p.markov.h2_states = mkprof.h2_states;
    cfg_p.markov.P = mkprof.P;
    cfg_p.markov.init_state = mkprof.init_state;
    cfg_p.markov.profile = mkprof;
    cfg_p.markov.fixed_state = 2;
    cfg_p.SNRdB = 30;
    cfg_p.Nsym = 80000;

    v_base = make_v_alg5(vars.theorem);
    Kffe = cfg_p.Nf; L = cfg_p.Nb;
    main_idx = round((Kffe+1)/2);
    v_base.main_idx = main_idx;

    ffe_min = -v_base.w2_max*ones(Kffe,1);
    ffe_max =  v_base.w2_max*ones(Kffe,1);
    ffe_min(main_idx) = -Inf;
    ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    msb_params = default_msb_params_v69();

    rng(1);
    sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
    d = cfg_p.A(sym_idx).'; d = d(:);
    [r_clean, ch_state] = channel_out(d, cfg_p);
    rng(2);
    [r,~] = add_noise_dispatch(r_clean, cfg_p);

    % ================================================================
% Pilot-only state estimator diagnostic
% Purpose:
%   Check whether channel-likelihood score can identify Markov state
%   during training when true d(m), d(m-1) are available.
% ================================================================
idx = 2:cfg_p.trainLen;
h2 = cfg_p.markov.h2_states(:).';
S = numel(h2);

score_pilot = zeros(numel(idx), S);

for s = 1:S
    pred = d(idx) + h2(s) * d(idx-1);
    score_pilot(:, s) = (r(idx) - pred).^2;
end

[~, s_pilot] = min(score_pilot, [], 2);

% Accuracy assuming channel state is indexed by symbol m
acc_pilot_m = mean(s_pilot(:) == ch_state.state(idx));

fprintf('\n[pilot-state diagnostic]\n');
fprintf('  acc vs state(m): %.1f%%\n', 100*acc_pilot_m);

% Optional alignment check: maybe channel state is indexed by receive n = m + D
idx2 = idx(idx + cfg_p.D <= numel(ch_state.state));
s_pilot2 = s_pilot(1:numel(idx2));
acc_pilot_mD = mean(s_pilot2(:) == ch_state.state(idx2 + cfg_p.D));

fprintf('  acc vs state(m+D): %.1f%%\n', 100*acc_pilot_mD);

% Print state usage of true Markov chain in training
fprintf('  true state usage in training: ');
for s = 1:S
    fprintf('state%d=%.1f%% ', s, 100*mean(ch_state.state(idx)==s));
end
fprintf('\n\n');
    fprintf('[mb_state_track_v69] Severe Markov h2=[%s], SNR=30, Nsym=%d\n', ...
            num2str(cfg_p.markov.h2_states, '%.2f '), cfg_p.Nsym);
    fprintf('[mb_state_track_v69] score=channel-likelihood, train_all_prefix=%d\n', ...
            msb_params.train_all_prefix);

    [dh_msb, diag_msb] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);
    ser_msb = ser_after_training_aligned(d, dh_msb, cfg_p);

    [dh_orc, diag_orc] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, ch_state.state);
    ser_orc = ser_after_training_aligned(d, dh_orc, cfg_p);

    [dh_a5, diag_a5] = algorithm5_singlebank(r, d, cfg_p, v_base);
    ser_a5 = ser_after_training_aligned(d, dh_a5, cfg_p);

    [~, dh_nlms] = dfe_nlms_unified_x(r, d, cfg_p, base);
    ser_nlms = ser_after_training_aligned(d, dh_nlms, cfg_p);

    post_idx = (cfg_p.trainLen + diag_msb.N_sep + 1):cfg_p.Nsym;
    [raw_acc, best_acc, best_perm] = msb_state_accuracy(diag_msb.s_hat_hist, ch_state.state, post_idx);

    fprintf('\n[mb_state_track_v69] Single-trial SER summary:\n');
    fprintf('  Algorithm 2 (estimated state): SER = %.3e\n', ser_msb);
    fprintf('  Multi-bank ORACLE state:           SER = %.3e\n', ser_orc);
    fprintf('  Algorithm 1 single-bank:           SER = %.3e\n', ser_a5);
    fprintf('  NLMS reference:                    SER = %.3e\n', ser_nlms);
    fprintf('\n  Algorithm 2 vs Algorithm 1 ratio: %.2fx (>1 = Algorithm 2 wins)\n', ser_a5/max(ser_msb,eps));
    fprintf('  Algorithm 2 vs NLMS ratio: %.2fx\n', ser_nlms/max(ser_msb,eps));
    fprintf('  Oracle vs Algorithm 2 gap: %.2fx\n', ser_msb/max(ser_orc,eps));

    fprintf('\n[mb_state_track_v69] State estimator raw accuracy: %.1f%%\n', 100*raw_acc);
    fprintf('[mb_state_track_v69] Best-permutation accuracy: %.1f%%, perm=[%d %d %d]\n', ...
            100*best_acc, best_perm);
    fprintf('[mb_state_track_v69] Number of switches: %d\n', diag_msb.n_switches);
    if ~isempty(diag_msb.dwell_lengths)
        fprintf('[mb_state_track_v69] Mean dwell length: %.1f symbols\n', mean(diag_msb.dwell_lengths));
    end
    fprintf('[mb_state_track_v69] Bank usage total: ');
    fprintf('%.1f%% ', 100*diag_msb.bank_usage);
    fprintf('\n');
    fprintf('[mb_state_track_v69] Bank usage post:  ');
    fprintf('%.1f%% ', 100*diag_msb.bank_usage_post);
    fprintf('\n');
post_idx = (cfg_p.trainLen + diag_msb.N_sep + 1):cfg_p.Nsym;

fprintf('[mb_state_track_v69] Mean routing confidence gap post: %.3f\n', ...
        mean(diag_msb.conf_ratio_hist(post_idx)));

fprintf('[mb_state_track_v69] Median routing confidence gap post: %.3f\n', ...
        median(diag_msb.conf_ratio_hist(post_idx)));

fprintf('[mb_state_track_v69] Update allowed post: %.1f%%\n', ...
        100*mean(diag_msb.update_allowed_hist(post_idx)));

fprintf('[mb_state_track_v69] Update allowed post: %.1f%%\n', ...
        100*mean(diag_msb.update_allowed_hist(post_idx)));
wrong_idx = post_idx(diag_msb.s_hat_hist(post_idx) ~= ch_state.state(post_idx));
right_idx = post_idx(diag_msb.s_hat_hist(post_idx) == ch_state.state(post_idx));

fprintf('[mb_state_track_v69] Conf gap when RIGHT: %.3f\n', ...
        median(diag_msb.conf_ratio_hist(right_idx)));

fprintf('[mb_state_track_v69] Conf gap when WRONG: %.3f\n', ...
        median(diag_msb.conf_ratio_hist(wrong_idx)));

fprintf('[mb_state_track_v69] Wrong-state update allowed: %.1f%%\n', ...
        100*mean(diag_msb.update_allowed_hist(wrong_idx)));

    fprintf('\n[mb_state_track_v69] Final theta_DFE per bank:\n');
    for s = 1:size(diag_msb.theta_banks_final, 2)
        fprintf('  Bank %d: theta_DFE = %.4f\n', s, diag_msb.theta_banks_final(end, s));
    end
    fprintf('  State optima: ');
    fprintf('%.2f ', cfg_p.markov.h2_states);
    fprintf('\n');

    % Plot
    figure('Name','mb_state_track_v69: channel-likelihood state tracking'); clf;
    tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

    decim = 50;
    n_axis = 1:decim:cfg_p.Nsym;
    colors = {'r','g','b'};

    nexttile;
    for s = 1:size(diag_msb.theta_dfe_hist,1)
        plot(n_axis, diag_msb.theta_dfe_hist(s,1:decim:end), colors{s}, 'LineWidth', 1.4); hold on;
    end
    for s = 1:numel(cfg_p.markov.h2_states)
        yline(cfg_p.markov.h2_states(s), 'k--', sprintf('state %d opt=%.2f',s,cfg_p.markov.h2_states(s)), 'Alpha',0.5);
    end
    xline(cfg_p.trainLen,'k:','Train end');
    xline(cfg_p.trainLen + diag_msb.N_sep,'m:','Estimator warm-up end');
    grid on; xlabel('n'); ylabel('\theta_{DFE} per bank');
    title('Algorithm 2 bank specialization with channel-likelihood training/routing');
    legend({'Bank 1','Bank 2','Bank 3'},'Location','best');

    nexttile;
    plot(n_axis, ch_state.state(1:decim:end), 'k-', 'LineWidth', 1.5); hold on;
    plot(n_axis, diag_msb.s_hat_hist(1:decim:end), 'b-', 'LineWidth', 1.0);
    xline(cfg_p.trainLen,'k:','Train end');
    xline(cfg_p.trainLen + diag_msb.N_sep,'m:','Warm-up end');
    grid on; xlabel('n'); ylabel('state');
    title(sprintf('State tracking: raw %.1f%%, best-perm %.1f%%', 100*raw_acc, 100*best_acc));
    legend({'True state','Estimated s_{hat}'},'Location','best');
    ylim([0.5 3.5]);

    nexttile;
    for s = 1:size(diag_msb.J_hist,1)
        plot(n_axis, diag_msb.J_hist(s,1:decim:end), colors{s}, 'LineWidth', 1.0); hold on;
    end
    xline(cfg_p.trainLen,'k:','Train end');
    xline(cfg_p.trainLen + diag_msb.N_sep,'m:','Warm-up end');
    grid on; xlabel('n'); ylabel('J_s');
    title('Algorithm 2 channel-likelihood EWMA scores');
    legend({'J_1','J_2','J_3'},'Location','best');

    pkg.diag_msb = diag_msb;
    pkg.diag_orc = diag_orc;
    pkg.diag_a5 = diag_a5;
    pkg.ser_msb = ser_msb;
    pkg.ser_orc = ser_orc;
    pkg.ser_a5 = ser_a5;
    pkg.ser_nlms = ser_nlms;
    pkg.raw_acc = raw_acc;
    pkg.best_acc = best_acc;
    pkg.best_perm = best_perm;
    pkg.cfg_p = cfg_p;
end
