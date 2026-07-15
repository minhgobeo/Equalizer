% Auto-split from NCKH_v53.m (original line 11070).
% Folder: experiments/paper_main

function pkg = run_alpha_sweep_v67(cfg, vars, base, mc)
% Sweep alpha to find best correction strength on Markov channel.
 
    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    cfg_p.markov.h2_states = [0.30 0.50 0.70];
    cfg_p.markov.P = [0.95 0.05 0.00; 0.025 0.95 0.025; 0.00 0.05 0.95];
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
    cfg_p.SNRdB = 30;
    cfg_p.Nsym = 80000;
 
    alpha_list = [0, 0.25, 0.50, 0.75, 1.0];
    Nalpha = numel(alpha_list);
    Nt = max(mc.Ntrial_ser, 20);
 
    SER_alpha = zeros(Nalpha, 1);
    SER_nlms  = 0;
 
    fprintf('[alpha_sweep_v67] Markov SNR=30, sweep alpha\n');
    fprintf('[alpha_sweep_v67] %d trials\n', Nt);
 
    for t = 1:Nt
        rng(30000 + t);
        sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
        d = cfg_p.A(sym_idx).'; d = d(:);
        [r_clean,~] = channel_out(d, cfg_p);
        rng(30500 + t);
        [r,~] = add_noise_dispatch(r_clean, cfg_p);
 
        for k = 1:Nalpha
            v_k = make_v_with_sbc(vars.theorem, alpha_list(k), 5e-3);
            [~, dh_k] = proposed_recursion_sbc(r, d, cfg_p, v_k);
            SER_alpha(k) = SER_alpha(k) + ser_after_training_aligned(d, dh_k, cfg_p);
        end
 
        [~, dh_n] = dfe_nlms_unified_x(r, d, cfg_p, base);
        SER_nlms = SER_nlms + ser_after_training_aligned(d, dh_n, cfg_p);
 
        if mod(t,4)==0, fprintf('  [alpha_sweep_v67] trial %d/%d\n', t, Nt); end
    end
    SER_alpha = SER_alpha / Nt;
    SER_nlms = SER_nlms / Nt;
 
    fprintf('\n[alpha_sweep_v67] Results (Markov, SNR=30):\n');
    for k = 1:Nalpha
        fprintf('  alpha = %.2f:  SER = %.3e   ratio NLMS/Prop = %.2f\n', ...
                alpha_list(k), SER_alpha(k), SER_nlms / max(SER_alpha(k), eps));
    end
    fprintf('  NLMS reference:  SER = %.3e\n', SER_nlms);
 
    [best_ser, best_idx] = min(SER_alpha);
    fprintf('\n[alpha_sweep_v67] Best alpha = %.2f (SER = %.3e, NLMS ratio = %.2fx)\n', ...
            alpha_list(best_idx), best_ser, SER_nlms / max(best_ser, eps));
 
    figure('Name','alpha_sweep_v67: Algorithm 4 correction strength'); clf;
    semilogy(alpha_list, SER_alpha, '-o', 'LineWidth', 2.0, 'MarkerSize', 9, ...
             'MarkerFaceColor', [0 0.45 0.74], 'Color', [0 0.45 0.74]); hold on;
    yline(SER_nlms, 'r--', 'LineWidth', 1.5, 'Label','NLMS reference');
    grid on; xlabel('SBC strength \alpha'); ylabel('SER (Markov, SNR=30)');
    title('Algorithm 4: SER vs bias correction strength');
    legend({'Proposed + Algorithm 4', 'NLMS'}, 'Location','best');
 
    pkg.alpha_list = alpha_list;
    pkg.SER_alpha = SER_alpha;
    pkg.SER_nlms = SER_nlms;
    pkg.best_alpha = alpha_list(best_idx);
end
 
 
% ============================================================================
% SECTION-E  —  PATCH C : BER STATIC + MARKOV WITH ALGORITHM 4
% ============================================================================
 
