% Auto-split from NCKH_v53.m (original line 9499).
% Folder: experiments/paper_main

function pkg = run_ber_compare_v62(cfg, vars, base, mc)
% IEEE Access main contribution figure.
% On realistic Markov + severe Markov, compare:
%   1) Proposed standard (single bank, Nf=11)
%   2) Proposed + MSBank-EQ (S=3 banks)
%   3) NLMS
%   4) SM-sign-NLMS VSS
 
    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    cfg_p.markov.h2_states = [0.30 0.50 0.70];   % use severe (where it matters)
    cfg_p.markov.P = [0.95  0.05  0.00; ...
                      0.025 0.95  0.025; ...
                      0.00  0.05  0.95];
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
    Nt = max(mc.Ntrial_ser, 20);
    Nalg = 4;
    BER = zeros(Nsnr, Nalg);
    err_count = zeros(Nsnr, Nalg);
 
    fprintf('[v62b] Side-by-side: Standard vs MSBank-EQ on severe Markov\n');
    fprintf('[v62b] h2=[%s], Nf=%d Nb=%d  (NO AGC)\n', ...
            num2str(cfg_p.markov.h2_states, '%.2f '), cfg_p.Nf, cfg_p.Nb);
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(15000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg_p);
 
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            % *** NO AGC ***
 
            [~, dh1] = proposed_recursion(r, d, cfg_run, v_prop);
            [dh2, ~, ~] = proposed_recursion_msbank(r, d, cfg_run, v_prop);
            [~, dh3] = dfe_nlms_unified_x(r, d, cfg_run, base);
            [~, dh4] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_run, base, sigma2);
 
            dhs = {dh1, dh2, dh3, dh4};
            for a = 1:Nalg
                ser_val = ser_after_training_aligned(d, dhs{a}, cfg_run);
                BER(si, a) = BER(si, a) + ser_val / log2(cfg_p.M);
                err_count(si, a) = err_count(si, a) + ser_val * N_postTrain;
            end
        end
        if mod(t,4)==0, fprintf('  [v62b] trial %d/%d\n', t, Nt); end
    end
    BER = BER / Nt;
 
    names = {'Proposed (standard, single bank)', ...
             'Proposed + MSBank-EQ (S=3, NEW)', ...
             'NLMS', ...
             'SM-sign-NLMS VSS [2024]'};
 
    print_ber_table_local('v62b (Standard vs MSBank)', snr_list, BER, err_count, names, bit_floor);
    print_thresholds_local('v62b', snr_list, BER, names);
 
    BER_disp = max(BER, bit_floor);
 
    figure('Name','BER-Fig (v62b): Standard vs MSBank-EQ — IEEE Access main result');
    clf;
    ccolors = {[0 0.45 0.74], [0.85 0.10 0.10], [0.93 0.69 0.13], [0.47 0.67 0.19]};
    marks = {'o','d','s','^'};
    lwidths = [1.6, 2.6, 1.4, 1.4];
    for a = 1:Nalg
        semilogy(snr_list, BER_disp(:,a), ['-' marks{a}], ...
                 'Color', ccolors{a}, 'LineWidth', lwidths(a), ...
                 'MarkerFaceColor', ccolors{a}, 'MarkerSize', 9);
        hold on;
    end
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2, 'LabelHorizontalAlignment','left');
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2, 'LabelHorizontalAlignment','left');
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2, 'LabelHorizontalAlignment','left');
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title(sprintf('MSBank-EQ on severe Markov (h_2 \\in {0.30, 0.50, 0.70})'));
    legend(names, 'Location','southwest');
    ylim([bit_floor/3, 1]);
 
    pkg.snr_list = snr_list;
    pkg.BER = BER; pkg.err_count = err_count;
    pkg.names = names;
    pkg.bit_floor = bit_floor;
    pkg.cfg_p = cfg_p;
end
 
 
% ============================================================================
% SECTION-E  —  CORE: Markov-State-Bank Equalizer
% ============================================================================
 
