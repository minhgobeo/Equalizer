% Auto-split from NCKH_v53.m (original line 9376).
% Folder: experiments/paper_main

function pkg = run_ber_msbank_v62(cfg, vars, base, mc)
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
    Nt = max(mc.Ntrial_ser, 20);
    BER = zeros(Nsnr, 1);
    err_count = zeros(Nsnr, 1);
    state_est_acc = 0;
 
    fprintf('[v62] MSBank-EQ standalone: S=%d banks, h2=[%s]  (NO AGC)\n', ...
            numel(cfg_p.markov.h2_states), ...
            num2str(cfg_p.markov.h2_states, '%.2f '));
    fprintf('[v62] Nf=%d Nb=%d, %d trials, %d SNR points\n', ...
            cfg_p.Nf, cfg_p.Nb, Nt, Nsnr);
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(14000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ch_state] = channel_out(d, cfg_p);
 
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            % *** NO AGC ***
 
            [d_hat_sym, state_est, ~] = ...
                proposed_recursion_msbank(r, d, cfg_run, v_prop);
 
            ser_val = ser_after_training_aligned(d, d_hat_sym, cfg_run);
            BER(si) = BER(si) + ser_val / log2(cfg_p.M);
            err_count(si) = err_count(si) + ser_val * N_postTrain;
 
            if si == Nsnr   % only measure on highest-SNR pass
                post_idx = (cfg_p.trainLen + 1):cfg_p.Nsym;
                if isfield(ch_state, 'state')
                    acc_t = mean(state_est(post_idx) == ch_state.state(post_idx));
                    state_est_acc = state_est_acc + acc_t;
                end
            end
        end
        if mod(t,4)==0, fprintf('  [v62] trial %d/%d\n', t, Nt); end
    end
    BER = BER / Nt;
    state_est_acc = state_est_acc / Nt;
 
    fprintf('\n[v62] BER (MSBank-EQ, %d banks):\n', numel(cfg_p.markov.h2_states));
    for si = 1:Nsnr
        if err_count(si) < 0.5
            fprintf('  SNR=%2d  BER < %.1e\n', snr_list(si), bit_floor);
        else
            fprintf('  SNR=%2d  BER = %.3e\n', snr_list(si), BER(si));
        end
    end
    fprintf('\n[v62] State estimator accuracy: %.2f%%\n', 100*state_est_acc);
 
    fprintf('\n[v62] SNR thresholds:\n');
    th = NaN(1,3); tgts = [1e-3 1e-4 1e-5];
    for k = 1:3
        idx = find(BER <= tgts(k), 1, 'first');
        if ~isempty(idx), th(k) = snr_list(idx); end
    end
    fprintf('  1e-3: %s dB,  1e-4: %s dB,  1e-5: %s dB\n', ...
            num2str_or_na(th(1)), num2str_or_na(th(2)), num2str_or_na(th(3)));
 
    BER_disp = max(BER, bit_floor);
 
    figure('Name','BER-Fig (v62): MSBank-EQ standalone'); clf;
    semilogy(snr_list, BER_disp, '-o', ...
             'Color', [0.85 0.10 0.10], 'LineWidth', 2.4, ...
             'MarkerFaceColor', [0.85 0.10 0.10], 'MarkerSize', 9);
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2);
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2);
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2);
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title(sprintf('MSBank-EQ (S=%d, state-est %.1f%%)', ...
                  numel(cfg_p.markov.h2_states), 100*state_est_acc));
    ylim([bit_floor/3, 1]);
 
    pkg.snr_list = snr_list;
    pkg.BER = BER;
    pkg.err_count = err_count;
    pkg.bit_floor = bit_floor;
    pkg.state_est_acc = state_est_acc;
    pkg.cfg_p = cfg_p;
    pkg.v_prop = v_prop;
end
 
 
% ============================================================================
% SECTION-D  —  PATCH v62b : SIDE-BY-SIDE Standard vs MSBank-EQ
% ============================================================================
 
