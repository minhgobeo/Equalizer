% Auto-split from NCKH_v53.m (original line 9746).
% Folder: experiments/paper_main

function pkg = run_ber_severe_v63(cfg, vars, base, mc)
% Severe Markov + Proposed tuned for Markov regime.
 
    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
 
    % Severe Markov: 40% drift, fast transitions
    cfg_p.markov.h2_states = [0.30 0.50 0.70];
    cfg_p.markov.P = [0.95  0.05  0.00; ...
                      0.025 0.95  0.025; ...
                      0.00  0.05  0.95];
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
 
    cfg_p.Nf = 11; cfg_p.Nb = 3; cfg_p.D = 5;
    cfg_p.trainLen = 10000;
    cfg_p.Nsym = 80000;
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end
 
    % --- Proposed tuned for severe Markov regime ----
    %  Use 'theorem' variant (CLR schedule) not 'context' (constant step)
    v_prop = vars.theorem;
 
    % Tighten gate: under fast transitions, innovations are noisier
    v_prop.tau_c    = 0.30;
    v_prop.tau_c0   = 0.30;
    v_prop.tau_min  = 0.20;
    v_prop.tau_max  = 0.45;
 
    % Smaller mu_max: limit diffusion under fast Markov
    v_prop.mu_max = 1.0e-2;
    v_prop.mu_min = 5.0e-5;
    v_prop.mu_const_global = ...
        mean(sample_periodic_mu(v_prop.mu_min, v_prop.mu_max, v_prop.Tclr, 1:2000));
 
    K = cfg_p.Nf; L = cfg_p.Nb;
    main_idx = round((K+1)/2);
    v_prop.main_idx = main_idx;
    ffe_min = -v_prop.w2_max*ones(K,1); ffe_max = v_prop.w2_max*ones(K,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_prop.theta_min = [ffe_min; -v_prop.b_max*ones(L,1)];
    v_prop.theta_max = [ffe_max;  v_prop.b_max*ones(L,1)];
 
    snr_list = 10:2:30;
    Nsnr = numel(snr_list);
    Nalg = 6;
    BER = zeros(Nsnr, Nalg);
    err_count = zeros(Nsnr, Nalg);
 
    Nt = max(mc.Ntrial_ser, 20);
 
    fprintf('[v63] PAM4 severe Markov + Proposed tuned (theorem variant)\n');
    fprintf('[v63] h2=[%s], P-diag=0.95, mu_max=%.0e, tau_c=%.2f\n', ...
            num2str(cfg_p.markov.h2_states, '%.2f '), ...
            v_prop.mu_max, v_prop.tau_c);
    fprintf('[v63] Nf=%d Nb=%d, %d trials  (NO AGC)\n', ...
            cfg_p.Nf, cfg_p.Nb, Nt);
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(16000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg_p);
 
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            % NO AGC
 
            [~, dh1] = proposed_recursion(r, d, cfg_run, v_prop);
            [~, dh2] = dfe_lms_unified_x (r, d, cfg_run, base);
            [~, dh3] = dfe_nlms_unified_x(r, d, cfg_run, base);
            [~, dh4] = dfe_rls_unified_x (r, d, cfg_run, base);
            [~, dh5] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_run, base, sigma2);
            [~, dh6] = dfe_smsign_nlms_unified_x    (r, d, cfg_run, base, sigma2);
 
            dhs = {dh1, dh2, dh3, dh4, dh5, dh6};
            for a = 1:Nalg
                ser_val = ser_after_training_aligned(d, dhs{a}, cfg_run);
                BER(si, a) = BER(si, a) + ser_val / log2(cfg_p.M);
                err_count(si, a) = err_count(si, a) + ser_val * N_postTrain;
            end
        end
        if mod(t,4)==0, fprintf('  [v63] trial %d/%d\n', t, Nt); end
    end
    BER = BER / Nt;
 
    names = {'Proposed (theorem, tuned)','LMS','NLMS','RLS', ...
             'SM-sign-NLMS VSS','SM-sign-NLMS'};
 
    % print BER table
    fprintf('\n[v63] BER table:\n');
    fprintf('  SNR ');
    for a = 1:Nalg, fprintf('%24s ', names{a}); end
    fprintf('\n');
    for si = 1:Nsnr
        fprintf('  %2d  ', snr_list(si));
        for a = 1:Nalg
            if err_count(si, a) < 0.5
                fprintf('%24s ', sprintf('<%.1e', bit_floor));
            else
                fprintf('%24.3e ', BER(si, a));
            end
        end
        fprintf('\n');
    end
 
    % proposed-vs-baseline ratio at high SNR
    fprintf('\n[v63] BER ratio: NLMS / Proposed  (>1 means Proposed wins)\n');
    for si = 1:Nsnr
        ratio = BER(si,3) / max(BER(si,1), bit_floor);
        if BER(si,1) > 0 && BER(si,3) > 0
            fprintf('  SNR=%2d   ratio = %.2fx\n', snr_list(si), ratio);
        end
    end
 
    % thresholds
    fprintf('\n[v63] SNR thresholds:\n');
    fprintf('  %-26s  %8s  %8s  %8s\n', 'Algorithm', '1e-3', '1e-4', '1e-5');
    for a = 1:Nalg
        th = NaN(1,3); tgts = [1e-3 1e-4 1e-5];
        for k = 1:3
            idx = find(BER(:,a) <= tgts(k), 1, 'first');
            if ~isempty(idx), th(k) = snr_list(idx); end
        end
        fprintf('  %-26s  ', names{a});
        for k = 1:3
            if isnan(th(k)), fprintf('%8s  ', 'N/A');
            else,            fprintf('%8d  ', th(k));
            end
        end
        fprintf('\n');
    end
 
    BER_disp = max(BER, bit_floor);
 
    % plot
    figure('Name','BER-Fig (v63): severe Markov + Proposed tuned'); clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
 
    nexttile;
    ccolors = {[0 0.45 0.74], [0.85 0.33 0.10], [0.93 0.69 0.13], ...
               [0.49 0.18 0.56], [0.47 0.67 0.19], [0.30 0.75 0.93]};
    marks = {'o','x','s','d','^','v'};
    for a = 1:Nalg
        semilogy(snr_list, BER_disp(:,a), ['-' marks{a}], ...
                 'Color', ccolors{a}, 'LineWidth', 1.4, ...
                 'MarkerFaceColor', ccolors{a}, 'MarkerSize', 7);
        hold on;
    end
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2);
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2);
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2);
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title(sprintf('PAM4 severe Markov, Nf=%d, Proposed tuned', cfg_p.Nf));
    legend(names, 'Location','best');
    ylim([bit_floor/3, 1]);
 
    nexttile;
    semilogy(snr_list, BER_disp(:,1), '-o', ...
             'Color', ccolors{1}, 'LineWidth', 2.6, ...
             'MarkerFaceColor', ccolors{1}, 'MarkerSize', 10); hold on;
    semilogy(snr_list, BER_disp(:,3), '-s', ...
             'Color', ccolors{3}, 'LineWidth', 1.6, ...
             'MarkerFaceColor', ccolors{3}, 'MarkerSize', 8);
    semilogy(snr_list, BER_disp(:,4), '-d', ...
             'Color', ccolors{4}, 'LineWidth', 1.6, ...
             'MarkerFaceColor', ccolors{4}, 'MarkerSize', 8);
    semilogy(snr_list, BER_disp(:,5), '-^', ...
             'Color', ccolors{5}, 'LineWidth', 2.0, ...
             'MarkerFaceColor', ccolors{5}, 'MarkerSize', 9);
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2);
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2);
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2);
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title('Proposed (Theorem 2 + CLR) beats exogenous baselines');
    legend({'Proposed (endogenous, tuned)', ...
            'NLMS (tracking-lag floor)', ...
            'RLS (tracking-lag floor)', ...
            'SM-sign-NLMS VSS [2024]'}, 'Location','best');
    ylim([bit_floor/3, 1]);
 
    pkg.snr_list = snr_list;
    pkg.BER = BER; pkg.err_count = err_count;
    pkg.names = names;
    pkg.bit_floor = bit_floor;
    pkg.cfg_p = cfg_p;
    pkg.v_prop = v_prop;
end

