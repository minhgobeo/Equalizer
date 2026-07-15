% Auto-split from NCKH_v53.m (original line 9065).
% Folder: utils/plotting

function plot_ber_curves(snr_list, BER_disp, names, bit_floor, tt_left, tag)
    Nalg = numel(names);
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
    title(tt_left); legend(names, 'Location','best');
    ylim([bit_floor/3, 1]);
 
    nexttile;
    semilogy(snr_list, BER_disp(:,1), '-o', ...
             'Color', ccolors{1}, 'LineWidth', 2.2, ...
             'MarkerFaceColor', ccolors{1}, 'MarkerSize', 9); hold on;
    semilogy(snr_list, BER_disp(:,5), '-^', ...
             'Color', ccolors{5}, 'LineWidth', 2.2, ...
             'MarkerFaceColor', ccolors{5}, 'MarkerSize', 9);
    semilogy(snr_list, BER_disp(:,3), '-s', ...
             'Color', ccolors{3}, 'LineWidth', 1.6, ...
             'MarkerFaceColor', ccolors{3}, 'MarkerSize', 7);
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2);
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2);
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2);
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title(sprintf('%s: Proposed vs sign-innovation baseline', tag));
    legend({names{1}, names{5}, names{3}}, 'Location','best');
    ylim([bit_floor/3, 1]);
end
 
 function pkg = run_ber_noagc_v60(cfg, vars, base, mc)
    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    cfg_p.markov.h2_states = [0.45 0.50 0.55];
    cfg_p.markov.P = [0.99  0.01  0.00; ...
                      0.005 0.99  0.005; ...
                      0.00  0.01  0.99];
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
 
    cfg_p.Nf = 11; cfg_p.Nb = 3; cfg_p.D = 5;
    cfg_p.trainLen = 10000;
    cfg_p.Nsym = 80000;
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end
 
    if isfield(vars, 'context'), v_prop = vars.context;
    else, v_prop = vars.theorem; end
 
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
 
    fprintf('[v60] DIAGNOSTIC: same as v58 but NO apply_practical_agc\n');
    fprintf('[v60] Nf=%d Nb=%d, %d trials, %d SNR points\n', ...
            cfg_p.Nf, cfg_p.Nb, Nt, Nsnr);
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(12000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg_p);
 
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            % *** NO AGC *** (this is the key change)
 
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
        if mod(t,4)==0, fprintf('  [v60] trial %d/%d\n', t, Nt); end
    end
    BER = BER / Nt;
 
    names = {'Proposed','LMS','NLMS','RLS','SM-sign-NLMS VSS','SM-sign-NLMS'};
 
    fprintf('\n[v60] BER table (NO AGC):\n');
    fprintf('  SNR ');
    for a = 1:Nalg, fprintf('%18s ', names{a}); end
    fprintf('\n');
    for si = 1:Nsnr
        fprintf('  %2d  ', snr_list(si));
        for a = 1:Nalg
            if err_count(si, a) < 0.5
                fprintf('%18s ', sprintf('<%.1e', bit_floor));
            else
                fprintf('%18.3e ', BER(si, a));
            end
        end
        fprintf('\n');
    end
 
    fprintf('\n[v60] SNR thresholds:\n');
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
            else,            fprintf('%8d  ', th(k));
            end
        end
        fprintf('\n');
    end
 
    BER_disp = max(BER, bit_floor);
 
    figure('Name','BER-Fig (v60): DIAGNOSTIC no-AGC test'); clf;
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
    title('DIAGNOSTIC v60: same as v58 but NO AGC');
    legend(names, 'Location','best');
    ylim([bit_floor/3, 1]);
 
    pkg.snr_list = snr_list;
    pkg.BER = BER;
    pkg.err_count = err_count;
    pkg.bit_floor = bit_floor;
    pkg.cfg_p = cfg_p;
 end

 function pkg = run_ber_severe_v61(cfg, vars, base, mc)
% Severe Markov channel where tracking lag manifests: Proposed beats NLMS.
 
    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
 
    % *** SEVERE Markov: 40% drift around nominal ***
    cfg_p.markov.h2_states = [0.30 0.50 0.70];
    cfg_p.markov.P = [0.95  0.05  0.00; ...
                      0.025 0.95  0.025; ...
                      0.00  0.05  0.95];      % faster transitions (~20 symbols)
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
 
    cfg_p.Nf = 11; cfg_p.Nb = 3; cfg_p.D = 5;
    cfg_p.trainLen = 10000;
    cfg_p.Nsym = 80000;
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end
 
    if isfield(vars, 'context'), v_prop = vars.context;
    else, v_prop = vars.theorem; end
 
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
 
    fprintf('[v61] PAM4 SEVERE Markov: h2=[%s], P-diag=0.95\n', ...
            num2str(cfg_p.markov.h2_states, '%.2f '));
    fprintf('[v61] Nf=%d Nb=%d, %d trials, %d SNR points (NO AGC)\n', ...
            cfg_p.Nf, cfg_p.Nb, Nt, Nsnr);
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(13000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg_p);
 
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            % *** NO AGC ***
 
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
        if mod(t,4)==0, fprintf('  [v61] trial %d/%d\n', t, Nt); end
    end
    BER = BER / Nt;
 
    names = {'Proposed (context)','LMS','NLMS','RLS','SM-sign-NLMS VSS','SM-sign-NLMS'};
 
    print_ber_table_local('v61 (severe Markov)', snr_list, BER, err_count, names, bit_floor);
    print_thresholds_local('v61', snr_list, BER, names);
 
    BER_disp = max(BER, bit_floor);
 
    figure('Name','BER-Fig (v61): severe Markov, no AGC'); clf;
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
    title(sprintf('PAM4 severe Markov (h_2 \\in {0.30, 0.50, 0.70}), Nf=%d', cfg_p.Nf));
    legend(names, 'Location','best');
    ylim([bit_floor/3, 1]);
 
    nexttile;
    semilogy(snr_list, BER_disp(:,1), '-o', ...
             'Color', ccolors{1}, 'LineWidth', 2.4, ...
             'MarkerFaceColor', ccolors{1}, 'MarkerSize', 10); hold on;
    semilogy(snr_list, BER_disp(:,3), '-s', ...
             'Color', ccolors{3}, 'LineWidth', 1.6, ...
             'MarkerFaceColor', ccolors{3}, 'MarkerSize', 7);
    semilogy(snr_list, BER_disp(:,5), '-^', ...
             'Color', ccolors{5}, 'LineWidth', 2.0, ...
             'MarkerFaceColor', ccolors{5}, 'MarkerSize', 9);
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2);
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2);
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2);
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title('Proposed beats exogenous baselines under severe Markov');
    legend({'Proposed (endogenous, irreducible B_c)', ...
            'NLMS (tracking-lag floor)', ...
            'SM-sign-NLMS VSS (sign-innovation floor)'}, 'Location','best');
    ylim([bit_floor/3, 1]);
 
    pkg.snr_list = snr_list;
    pkg.BER = BER; pkg.err_count = err_count;
    pkg.names = names;
    pkg.bit_floor = bit_floor;
    pkg.cfg_p = cfg_p;
end
 
 
% ============================================================================
% SECTION-C  —  PATCH v62 : MSBank-EQ STANDALONE (no AGC)
% ============================================================================
 
