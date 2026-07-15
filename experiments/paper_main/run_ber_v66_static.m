% Auto-split from NCKH_v53.m (original line 10475).
% Folder: experiments/paper_main

function pkg = run_ber_v66_static(cfg, vars, base, mc)
% Compare Algorithm 3 against all baselines on static h=[1 0.5].
 
    cfg_p = cfg;
    cfg_p.chan_mode = 'baseline_2tap';
    cfg_p.h_isi = [1 0.5];
    cfg_p.Nsym = 80000;
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end
 
    % Algorithm 3: lambda schedule
    v_prop = make_v_with_lambda_schedule(vars.theorem, cfg_p.Nsym);
 
    snr_list = 8:2:26;
    Nsnr = numel(snr_list);
    Nalg = 6;
    BER = zeros(Nsnr, Nalg);
    err_count = zeros(Nsnr, Nalg);
 
    Nt = max(mc.Ntrial_ser, 20);
 
    fprintf('[ber_v66_static] PAM4 static h=[1 0.5] + Algorithm 3 (lambda schedule)\n');
    fprintf('[ber_v66_static] lambda_0=%.4f, alpha=%.4f, beta=%.2f\n', ...
            v_prop.lambda_0, v_prop.lambda_alpha, v_prop.lambda_beta);
    fprintf('[ber_v66_static] %d trials, %d SNR pts (NO AGC)\n', Nt, Nsnr);
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(21000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean,~] = channel_out(d, cfg_p);
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            % NO AGC
 
            [~, dh1] = proposed_recursion_lambda_schedule(r, d, cfg_run, v_prop);
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
        if mod(t,4)==0, fprintf('  [ber_v66_static] trial %d/%d\n', t, Nt); end
    end
    BER = BER / Nt;
 
    names = {'Proposed + Algorithm 3','LMS','NLMS','RLS', ...
             'SM-sign-NLMS VSS','SM-sign-NLMS'};
 
    print_ber_local('v66_static', snr_list, BER, err_count, names, bit_floor);
    plot_ber_local('v66_static: PAM4 static + Algorithm 3', ...
                   snr_list, BER, names, bit_floor);
 
    pkg.snr_list = snr_list;
    pkg.BER = BER; pkg.err_count = err_count;
    pkg.names = names; pkg.bit_floor = bit_floor;
    pkg.cfg_p = cfg_p; pkg.v_prop = v_prop;
end
 
 
% ============================================================================
% SECTION-D  —  PATCH C : MARKOV BER WITH ALGORITHM 3
% ============================================================================
 
