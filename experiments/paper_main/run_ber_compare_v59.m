% Auto-split from NCKH_v53.m (original line 8816).
% Folder: experiments/paper_main

function pkg = run_ber_compare_v59(cfg, vars, base, mc)
% Side-by-side: standard high-order equalizer vs MSBank-EQ.
% This is the IEEE Access main-result figure for the contribution.
 
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
 
    if isfield(vars, 'context'), v_prop = vars.context; else, v_prop = vars.theorem; end
 
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
 
    Nalg = 4;        % standard-Proposed, MSBank-Proposed, NLMS, SM-sign-VSS
    BER = zeros(Nsnr, Nalg);
    err_count = zeros(Nsnr, Nalg);
 
    fprintf('[ber_compare_v59] Side-by-side: standard vs MSBank-EQ\n');
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(11000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg_p);
 
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            r = apply_practical_agc(r, d, cfg_run);
 
            % Standard high-order Proposed
            [~, dh1] = proposed_recursion(r, d, cfg_run, v_prop);
            % MSBank
            [dh2, ~, ~] = proposed_recursion_msbank(r, d, cfg_run, v_prop);
            % NLMS baseline (high-order)
            [~, dh3] = dfe_nlms_unified_x(r, d, cfg_run, base);
            % SM-sign-VSS baseline
            [~, dh4] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_run, base, sigma2);
 
            dhs = {dh1, dh2, dh3, dh4};
            for a = 1:Nalg
                ser_val = ser_after_training_aligned(d, dhs{a}, cfg_run);
                BER(si, a) = BER(si, a) + ser_val / log2(cfg_p.M);
                err_count(si, a) = err_count(si, a) + ser_val * N_postTrain;
            end
        end
        if mod(t,4)==0, fprintf('  [ber_compare_v59] trial %d/%d\n', t, Nt); end
    end
    BER = BER / Nt;
 
    names = {'Proposed (standard, Nf=11)', ...
             'Proposed + MSBank-EQ (NEW)', ...
             'NLMS (Nf=11)', ...
             'SM-sign-NLMS VSS [2024]'};
 
    % print
    fprintf('\n[ber_compare_v59] BER comparison:\n');
    fprintf('  SNR ');
    for a = 1:Nalg, fprintf('%26s ', names{a}); end
    fprintf('\n');
    for si = 1:Nsnr
        fprintf('  %2d  ', snr_list(si));
        for a = 1:Nalg
            if err_count(si, a) < 0.5
                fprintf('%26s ', sprintf('<%.1e', bit_floor));
            else
                fprintf('%26.3e ', BER(si, a));
            end
        end
        fprintf('\n');
    end
 
    fprintf('\n[ber_compare_v59] SNR thresholds:\n');
    fprintf('  %-30s  %8s  %8s  %8s\n', 'Algorithm', '1e-3', '1e-4', '1e-5');
    for a = 1:Nalg
        th = NaN(1,3); tgts = [1e-3 1e-4 1e-5];
        for k = 1:3
            idx = find(BER(:,a) <= tgts(k), 1, 'first');
            if ~isempty(idx), th(k) = snr_list(idx); end
        end
        fprintf('  %-30s  ', names{a});
        for k = 1:3
            if isnan(th(k)), fprintf('%8s  ', 'N/A');
            else,            fprintf('%8d  ', th(k));
            end
        end
        fprintf('\n');
    end
 
    BER_disp = max(BER, bit_floor);
 
    % ---- plot -----------------------------------------------------------
    figure('Name','BER-Fig (v59): MSBank-EQ vs Standard (IEEE Access main result)');
    clf;
    ccolors = {[0 0.45 0.74], [0.85 0.10 0.10], [0.93 0.69 0.13], [0.47 0.67 0.19]};
    marks = {'o','d','s','^'};
    lwidths = [1.6, 2.4, 1.4, 1.4];
    for a = 1:Nalg
        semilogy(snr_list, BER_disp(:,a), ['-' marks{a}], ...
                 'Color', ccolors{a}, 'LineWidth', lwidths(a), ...
                 'MarkerFaceColor', ccolors{a}, 'MarkerSize', 8);
        hold on;
    end
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2, 'LabelHorizontalAlignment','left');
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2, 'LabelHorizontalAlignment','left');
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2, 'LabelHorizontalAlignment','left');
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title('Markov-State-Bank Equalizer: pre-FEC BER advantage');
    legend(names, 'Location','southwest');
    ylim([bit_floor/3, 1]);
 
    pkg.snr_list = snr_list;
    pkg.BER = BER; pkg.err_count = err_count;
    pkg.names = names;
    pkg.bit_floor = bit_floor;
    pkg.cfg_p = cfg_p;
end
 
 
% ============================================================================
% SECTION-E  —  SHARED HELPERS
% ============================================================================
 
