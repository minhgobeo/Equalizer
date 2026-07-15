% Auto-split from NCKH_v53.m (original line 8415).
% Folder: experiments/paper_main

function pkg = run_ber_prefec_v57(cfg, vars, base, mc)
% Pre-FEC BER under REALISTIC Markov channel (small h2 fluctuations).
% This is the regime where Theorem 2's structural advantage manifests AND
% pre-FEC BER targets 1e-3 to 1e-5 are achievable.
 
    % ---- configuration ---------------------------------------------------
    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
 
    % *** OVERRIDE: realistic Markov state space ***
    cfg_p.markov.h2_states = [0.45 0.50 0.55];   % ±10% drift
    cfg_p.markov.P = [0.99  0.01  0.00; ...
                      0.005 0.99  0.005; ...
                      0.00  0.01  0.99];          % slower transitions
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
 
    cfg_p.Nsym      = 80000;
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end
 
    fprintf('[ber_prefec_v57] PAM4 (M=%d) on REALISTIC Markov channel\n', cfg_p.M);
    fprintf('[ber_prefec_v57] h2 states = [%s]  (10%% drift around nominal)\n', ...
            num2str(cfg_p.markov.h2_states, '%.2f '));
    fprintf('[ber_prefec_v57] init state = %d  (h2 = %.2f)\n', ...
            cfg_p.markov.init_state, ...
            cfg_p.markov.h2_states(cfg_p.markov.init_state));
    fprintf('[ber_prefec_v57] Nf=%d, Nb=%d, D=%d, trainLen=%d\n', ...
            cfg_p.Nf, cfg_p.Nb, cfg_p.D, cfg_p.trainLen);
 
    % ---- Proposed variant ------------------------------------------------
    if isfield(vars, 'context')
        v_prop = vars.context;
        prop_name = 'Proposed (context, DD+Markov)';
    else
        v_prop = vars.theorem;
        prop_name = 'Proposed (theorem)';
    end
    base_p = base;
 
    % ---- SNR sweep -------------------------------------------------------
    snr_list = 8:2:28;
    Nsnr = numel(snr_list);
    Nalg = 6;
    BER = zeros(Nsnr, Nalg);
    SER = zeros(Nsnr, Nalg);
    err_count = zeros(Nsnr, Nalg);
 
    Nt = max(mc.Ntrial_ser, 20);
 
    fprintf('[ber_prefec_v57] Nt=%d trials, %d SNR points (8..28 dB)\n', Nt, Nsnr);
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    fprintf('[ber_prefec_v57] %.2e bits per SNR point  (BER floor %.1e)\n', ...
            total_bits, bit_floor);
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(7000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
 
            [r_clean, ~] = channel_out(d, cfg_p);
 
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            r = apply_practical_agc(r, d, cfg_run);
 
            [~, dh1] = proposed_recursion(r, d, cfg_run, v_prop);
            [~, dh2] = dfe_lms_unified_x (r, d, cfg_run, base_p);
            [~, dh3] = dfe_nlms_unified_x(r, d, cfg_run, base_p);
            [~, dh4] = dfe_rls_unified_x (r, d, cfg_run, base_p);
            [~, dh5] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_run, base_p, sigma2);
            [~, dh6] = dfe_smsign_nlms_unified_x    (r, d, cfg_run, base_p, sigma2);
 
            dhs = {dh1, dh2, dh3, dh4, dh5, dh6};
            for a = 1:Nalg
                ser_val = ser_after_training_aligned(d, dhs{a}, cfg_run);
                SER(si, a) = SER(si, a) + ser_val;
                err_count(si, a) = err_count(si, a) + ser_val * N_postTrain;
            end
        end
        if mod(t,4)==0, fprintf('  [ber_prefec_v57] trial %d/%d\n', t, Nt); end
    end
    SER = SER / Nt;
    BER = SER / log2(cfg_p.M);
 
    names = {prop_name, 'LMS','NLMS','RLS','SM-sign-NLMS VSS','SM-sign-NLMS'};
 
    % ---- Print SER table -------------------------------------------------
    fprintf('\n[ber_prefec_v57] PAM4 SER on realistic Markov  (%.2e symbols/SNR):\n', ...
            N_postTrain*Nt);
    fprintf('  SNR ');
    for a = 1:Nalg, fprintf('%18s ', names{a}); end
    fprintf('\n');
    for si = 1:Nsnr
        fprintf('  %2d  ', snr_list(si));
        for a = 1:Nalg
            if err_count(si, a) < 0.5
                fprintf('%18s ', sprintf('<%.1e', 1/(N_postTrain*Nt)));
            else
                fprintf('%18.3e ', SER(si, a));
            end
        end
        fprintf('\n');
    end
 
    % ---- Print BER table -------------------------------------------------
    fprintf('\n[ber_prefec_v57] PAM4 pre-FEC BER realistic Markov (%.2e bits/SNR):\n', ...
            total_bits);
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
 
    % ---- SNR thresholds -------------------------------------------------
    fprintf('\n[ber_prefec_v57] SNR thresholds (dB) to reach pre-FEC BER target:\n');
    fprintf('  %-28s  %8s  %8s  %8s\n', 'Algorithm', '1e-3', '1e-4', '1e-5');
    for a = 1:Nalg
        th = NaN(1,3); tgts = [1e-3 1e-4 1e-5];
        for k = 1:3
            idx = find(BER(:,a) <= tgts(k), 1, 'first');
            if ~isempty(idx), th(k) = snr_list(idx); end
        end
        fprintf('  %-28s  ', names{a});
        for k = 1:3
            if isnan(th(k)), fprintf('%8s  ', 'N/A');
            else,            fprintf('%8d  ', th(k));
            end
        end
        fprintf('\n');
    end
 
    % ---- BER floor (asymptotic) -----------------------------------------
    fprintf('\n[ber_prefec_v57] Asymptotic BER floor (mean over last 3 SNR pts):\n');
    asymp_range = (Nsnr-2):Nsnr;
    for a = 1:Nalg
        ber_floor = mean(BER(asymp_range, a));
        fprintf('  %-28s  BER_floor = %.3e\n', names{a}, ber_floor);
    end
 
    BER_disp = max(BER, bit_floor);
 
    % ---- plot BER -------------------------------------------------------
    figure('Name','BER-Fig (v57): PAM4 pre-FEC BER on realistic Markov');
    clf; tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
 
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
    yline(1e-3, 'k:',  '10^{-3}', 'LineWidth', 1.2, 'LabelHorizontalAlignment','left');
    yline(1e-4, 'k:',  '10^{-4}', 'LineWidth', 1.2, 'LabelHorizontalAlignment','left');
    yline(1e-5, 'k:',  '10^{-5}', 'LineWidth', 1.2, 'LabelHorizontalAlignment','left');
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title('PAM4 on realistic Markov: pre-FEC BER vs SNR');
    legend(names, 'Location','southwest');
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
    title('Proposed vs exogenous baselines (realistic Markov)');
    legend({prop_name, 'SM-sign-NLMS VSS', 'NLMS'}, 'Location','southwest');
    ylim([bit_floor/3, 1]);
 
    % ---- eye diagram at SNR where Proposed reaches 1e-4 -----------------
    snr_target_idx = find(BER(:,1) <= 1e-4, 1, 'first');
    if isempty(snr_target_idx)
        [~, snr_target_idx] = min(BER(:,1));
    end
    snr_target = snr_list(snr_target_idx);
 
    rng(9100);
    sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
    d_eye = cfg_p.A(sym_idx).'; d_eye = d_eye(:);
    [r_clean_eye, ~] = channel_out(d_eye, cfg_p);
    rng(9200);
    cfg_eye = cfg_p; cfg_eye.SNRdB = snr_target;
    [r_eye, ~] = add_noise_dispatch(r_clean_eye, cfg_eye);
    r_eye = apply_practical_agc(r_eye, d_eye, cfg_eye);
    [y_after, ~, ~] = proposed_recursion(r_eye, d_eye, cfg_eye, v_prop);
 
    seg = (cfg_p.trainLen + 1000) : min(numel(y_after), numel(r_eye));
    r_before = r_eye(seg);
    y_postdec = y_after(seg);
 
    g_rc = rc_pulse(cfg_p.alpha_eye, cfg_p.sps_eye, cfg_p.spanUI_eye);
    y_b_os = conv(upsample_zeros(r_before,  cfg_p.sps_eye), g_rc);
    y_a_os = conv(upsample_zeros(y_postdec, cfg_p.sps_eye), g_rc);
 
    figure('Name', sprintf('EYE-Fig (v57): PAM4 realistic Markov pre-FEC eye @ SNR=%d dB', snr_target));
    clf; tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    nexttile; eye_plot_reshape_fixed(y_b_os, cfg_p.sps_eye);
    title(sprintf('Eye BEFORE (PAM4 realistic Markov ISI+AWGN, SNR=%d dB)', snr_target));
    grid on;
    nexttile; eye_plot_reshape_fixed(y_a_os, cfg_p.sps_eye);
    ber_at_target = BER(snr_target_idx, 1);
    if ber_at_target < bit_floor
        title(sprintf('Eye AFTER (Proposed, BER < %.1e)', bit_floor)); grid on;
    else
        title(sprintf('Eye AFTER (Proposed, BER = %.1e)', ber_at_target)); grid on;
    end
 
    pkg.snr_list  = snr_list;
    pkg.BER       = BER;
    pkg.SER       = SER;
    pkg.err_count = err_count;
    pkg.names     = names;
    pkg.snr_prefec_point = snr_target;
    pkg.bit_floor = bit_floor;
    pkg.cfg_p     = cfg_p;
    pkg.v_prop    = v_prop;
end

