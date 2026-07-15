% Auto-split from NCKH_v53.m (original line 10985).
% Folder: experiments/paper_main

function pkg = run_theta_compare_v67(cfg, vars, base, mc)
% Verify Algorithm 4 closes residual DFE bias (4% → <1%)
 
    cfg_p = cfg;
    cfg_p.chan_mode = 'baseline_2tap';
    cfg_p.h_isi = [1 0.5];
    cfg_p.SNRdB = 25;
    cfg_p.Nsym = 100000;
 
    rng(1); sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
    d = cfg_p.A(sym_idx).'; d = d(:);
    [r_clean,~] = channel_out(d, cfg_p);
    rng(2); [r,~] = add_noise_dispatch(r_clean, cfg_p);
 
    fprintf('[theta_compare_v67] DFE coefficient evolution\n');
    fprintf('[theta_compare_v67] Channel h=[1 0.5], SNR=25, Nsym=%d\n', cfg_p.Nsym);
 
    % Algorithm 1 (constant lambda)
    [~,~,~, diag_alg1] = proposed_recursion(r, d, cfg_p, vars.theorem);
 
    % Algorithm 3 (lambda schedule, no SBC)
    v_alg3 = make_v_with_sbc(vars.theorem, 0, 5e-3);   % alpha=0 → no SBC
    [~,~,~, diag_alg3] = proposed_recursion_sbc(r, d, cfg_p, v_alg3);
 
    % Algorithm 4 (lambda schedule + SBC alpha=0.5)
    v_alg4_half = make_v_with_sbc(vars.theorem, 0.5, 5e-3);
    [~,~,~, diag_alg4_half] = proposed_recursion_sbc(r, d, cfg_p, v_alg4_half);
 
    % Algorithm 4 (full SBC, alpha=1.0)
    v_alg4_full = make_v_with_sbc(vars.theorem, 1.0, 5e-3);
    [~,~,~, diag_alg4_full] = proposed_recursion_sbc(r, d, cfg_p, v_alg4_full);
 
    th_a1 = diag_alg1.theta_hist(end, :);
    th_a3 = diag_alg3.theta_hist(end, :);
    th_a4h = diag_alg4_half.theta_hist(end, :);
    th_a4f = diag_alg4_full.theta_hist(end, :);
 
    fprintf('\n[theta_compare_v67] Final theta_DFE:\n');
    fprintf('  Algorithm 1 (lambda const):              %.4f  (bias %.1f%%)\n', ...
            th_a1(end), 100*(0.5-th_a1(end))/0.5);
    fprintf('  Algorithm 3 (lambda schedule):           %.4f  (bias %.1f%%)\n', ...
            th_a3(end), 100*(0.5-th_a3(end))/0.5);
    fprintf('  Algorithm 4 (SBC alpha=0.5):             %.4f  (bias %.1f%%)\n', ...
            th_a4h(end), 100*(0.5-th_a4h(end))/0.5);
    fprintf('  Algorithm 4 (SBC alpha=1.0, full):       %.4f  (bias %.1f%%)\n', ...
            th_a4f(end), 100*(0.5-th_a4f(end))/0.5);
    fprintf('  Optimal MMSE:                            0.5000\n');
 
    fprintf('\n[theta_compare_v67] Final ||b_hat_c|| (lower=better correction):\n');
    fprintf('  Algorithm 4 (alpha=0.5): %.4e\n', diag_alg4_half.bhatc_norm(end));
    fprintf('  Algorithm 4 (alpha=1.0): %.4e\n', diag_alg4_full.bhatc_norm(end));
 
    % Plot
    figure('Name','theta_compare_v67: Algorithm 4 SBC progression'); clf;
    n_axis = 1:cfg_p.Nsym;
    decim = 50;
    n_plot = n_axis(1:decim:end);
    plot(n_plot, th_a1(1:decim:end),  '-r', 'LineWidth', 1.6); hold on;
    plot(n_plot, th_a3(1:decim:end),  '-b', 'LineWidth', 1.6);
    plot(n_plot, th_a4h(1:decim:end), '-m', 'LineWidth', 1.6);
    plot(n_plot, th_a4f(1:decim:end), '-g', 'LineWidth', 2.0);
    yline(0.5, 'k--', 'LineWidth', 1.5, 'Label','Optimal MMSE');
    xline(cfg_p.trainLen, 'k:', 'LineWidth', 1, 'Label','End training');
    grid on; xlabel('Symbol index n'); ylabel('\theta_{DFE}');
    title('Algorithm 1 → 3 → 4: progressive bias elimination');
    legend({'Algorithm 1 (const \lambda)', ...
            'Algorithm 3 (\lambda_n schedule)', ...
            'Algorithm 4 (SBC \alpha=0.5)', ...
            'Algorithm 4 (SBC \alpha=1.0, full)', ...
            'Optimal MMSE = 0.5'}, ...
           'Location','southeast');
    ylim([0.3, 0.55]);
 
    pkg.theta_alg1 = th_a1;
    pkg.theta_alg3 = th_a3;
    pkg.theta_alg4_half = th_a4h;
    pkg.theta_alg4_full = th_a4f;
    pkg.cfg_p = cfg_p;
end
 
 
% ============================================================================
% SECTION-D  —  PATCH B : ALPHA SWEEP (find optimal correction strength)
% ============================================================================
 
