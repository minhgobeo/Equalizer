% Auto-split from NCKH_v53.m (original line 8964).
% Folder: utils/metrics

function [pkg, names, BER, snr_list, bit_floor] = ber_sweep_standard(cfg_p, vars, base, mc, tag)
% Run a standard 6-algorithm BER sweep on cfg_p.
 
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
 
    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
 
    fprintf('[%s] Nt=%d, %.2e bits/SNR\n', tag, Nt, total_bits);
 
    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(8000 + 100*si + t);
 
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg_p);
 
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            r = apply_practical_agc(r, d, cfg_run);
 
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
        if mod(t,4)==0, fprintf('  [%s] trial %d/%d\n', tag, t, Nt); end
    end
    BER = BER / Nt;
 
    names = {'Proposed (standard)','LMS','NLMS','RLS','SM-sign-NLMS VSS','SM-sign-NLMS'};
 
    fprintf('\n[%s] BER table:\n', tag);
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
 
    fprintf('\n[%s] SNR thresholds:\n', tag);
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
 
    pkg.snr_list = snr_list;
    pkg.BER = BER; pkg.err_count = err_count;
    pkg.names = names;
    pkg.bit_floor = bit_floor;
    pkg.cfg_p = cfg_p;
end
 
