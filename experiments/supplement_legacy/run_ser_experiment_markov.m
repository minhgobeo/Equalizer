% Auto-split from NCKH_v53.m (original line 1244).
% Folder: experiments/supplement_legacy

function ser_mk = run_ser_experiment_markov(cfg, v_context, base, mc)
% SER vs SNR under MARKOV time-varying channel
% This is the key experiment that showcases Theorem 2 advantage:
% the proposed algorithm's disturbance-aware mechanism tracks
% channel changes, while baselines suffer tracking lag.
    snr_list = mc.snr_list;
    Nalg = 6;
    SER_all = zeros(numel(snr_list), Nalg);

    cfg_mk = cfg;
    cfg_mk.chan_mode = 'markov_2tap';
    % use cfg.markov settings already configured

    for si = 1:numel(snr_list)
        snr_db = snr_list(si);
        acc = zeros(1, Nalg);

        for t = 1:mc.Ntrial_ser
            rng(5000 + 100*si + t);

            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);

            [r_clean, ~] = channel_out(d, cfg_mk);

            cfg_s = cfg_mk;
            cfg_s.SNRdB = snr_db;
            if isfield(cfg_s,'std8023')
                cfg_s.std8023.enable = false;   % pure Markov channel
            end
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_s);
            r = apply_practical_agc(r, d, cfg_s);

            [~, dh1] = proposed_recursion(r, d, cfg_s, v_context);
            [~, dh2] = dfe_lms_unified_x(r, d, cfg_s, base);
            [~, dh3] = dfe_nlms_unified_x(r, d, cfg_s, base);
            [~, dh4] = dfe_rls_unified_x(r, d, cfg_s, base);
            [~, dh5] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_s, base, sigma2);
            [~, dh6] = dfe_smsign_nlms_unified_x(r, d, cfg_s, base, sigma2);

            acc(1) = acc(1) + ser_after_training_aligned(d, dh1, cfg_s);
            acc(2) = acc(2) + ser_after_training_aligned(d, dh2, cfg_s);
            acc(3) = acc(3) + ser_after_training_aligned(d, dh3, cfg_s);
            acc(4) = acc(4) + ser_after_training_aligned(d, dh4, cfg_s);
            acc(5) = acc(5) + ser_after_training_aligned(d, dh5, cfg_s);
            acc(6) = acc(6) + ser_after_training_aligned(d, dh6, cfg_s);
        end
        SER_all(si,:) = acc / mc.Ntrial_ser;
    end

    ser_mk.snr_list        = snr_list;
    ser_mk.SER_prop        = SER_all(:,1);
    ser_mk.SER_lms         = SER_all(:,2);
    ser_mk.SER_nlms        = SER_all(:,3);
    ser_mk.SER_rls         = SER_all(:,4);
    ser_mk.SER_smsign_vss  = SER_all(:,5);
    ser_mk.SER_smsign      = SER_all(:,6);
    ser_mk.channel_mode    = 'markov_2tap';
end

%% =====================================================================
% AUTO-TUNING: Grid search for best parameters per algorithm
%% =====================================================================
