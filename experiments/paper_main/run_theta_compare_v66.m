% Auto-split from NCKH_v53.m (original line 10400).
% Folder: experiments/paper_main

function pkg = run_theta_compare_v66(cfg, vars, base, mc)
% Show that Algorithm 3 (lambda schedule) eliminates DFE bias.
 
    cfg_p = cfg;
    cfg_p.chan_mode = 'baseline_2tap';
    cfg_p.h_isi = [1 0.5];
    cfg_p.SNRdB = 25;
    cfg_p.Nsym = 100000;     % long enough to see asymptotic behavior
 
    rng(1); sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
    d = cfg_p.A(sym_idx).'; d = d(:);
    [r_clean,~] = channel_out(d, cfg_p);
    rng(2); [r,~] = add_noise_dispatch(r_clean, cfg_p);
 
    fprintf('[theta_compare_v66] DFE coefficient evolution\n');
    fprintf('[theta_compare_v66] Channel h=[1 0.5], SNR=%d, Nsym=%d\n', ...
            cfg_p.SNRdB, cfg_p.Nsym);
 
    % --- Variant 1: Constant lambda (original Algorithm 1) ---
    v_const = vars.theorem;
    [~,~,~, diag_const] = proposed_recursion(r, d, cfg_p, v_const);
 
    % --- Variant 2: Algorithm 3 with lambda schedule ---
    v_sched = make_v_with_lambda_schedule(vars.theorem, cfg_p.Nsym);
    [~,~,~, diag_sched] = proposed_recursion_lambda_schedule(r, d, cfg_p, v_sched);
 
    % --- Variant 3: Lambda = 0 (oracle case for upper bound) ---
    v_zero = vars.theorem;
    v_zero.lambda = 0;
    [~,~,~, diag_zero] = proposed_recursion(r, d, cfg_p, v_zero);
 
    % Track theta_DFE over time
    th_const = diag_const.theta_hist(end, :);
    th_sched = diag_sched.theta_hist(end, :);
    th_zero  = diag_zero.theta_hist(end, :);
 
    fprintf('\n[theta_compare_v66] Final theta_DFE values:\n');
    fprintf('  Algorithm 1 (lambda const = 0.001):  %.4f  (bias %.1f%%)\n', ...
            th_const(end), 100*(0.5-th_const(end))/0.5);
    fprintf('  Algorithm 3 (lambda schedule):       %.4f  (bias %.1f%%)\n', ...
            th_sched(end), 100*(0.5-th_sched(end))/0.5);
    fprintf('  Lambda = 0 (oracle upper bound):     %.4f  (bias %.1f%%)\n', ...
            th_zero(end), 100*(0.5-th_zero(end))/0.5);
    fprintf('  Optimal (MMSE):                      0.5000\n');
 
    % Plot
    figure('Name','theta_compare (v66): Algorithm 3 eliminates DFE bias'); clf;
    n_axis = 1:cfg_p.Nsym;
    decim = 50;   % decimate for plotting
    n_plot = n_axis(1:decim:end);
    plot(n_plot, th_const(1:decim:end), '-r', 'LineWidth', 1.6); hold on;
    plot(n_plot, th_sched(1:decim:end), '-b', 'LineWidth', 1.6);
    plot(n_plot, th_zero(1:decim:end),  '--k', 'LineWidth', 1.2);
    yline(0.5, 'g-', 'LineWidth', 1.5, 'Label', 'Optimal MMSE');
    xline(cfg_p.trainLen, 'k:', 'LineWidth', 1, 'Label', 'End training');
    grid on; xlabel('Symbol index n'); ylabel('\theta_{DFE} coefficient');
    title('DFE coefficient evolution: Algorithm 1 vs 3');
    legend({'Algorithm 1 (\lambda = const)', ...
            'Algorithm 3 (\lambda_n schedule)', ...
            '\lambda = 0 (oracle)', ...
            'Optimal MMSE = 0.5'}, ...
           'Location','southeast');
    ylim([0.3, 0.55]);
 
    pkg.theta_const = th_const;
    pkg.theta_sched = th_sched;
    pkg.theta_zero = th_zero;
    pkg.cfg_p = cfg_p;
end
 
 
% ============================================================================
% SECTION-C  —  PATCH B : STATIC BER WITH ALGORITHM 3
% ============================================================================
 
