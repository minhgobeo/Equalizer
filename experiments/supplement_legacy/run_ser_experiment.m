% Auto-split from NCKH_v53.m (original line 1176).
% Folder: experiments/supplement_legacy

function ser_rslt = run_ser_experiment(cfg, v_context, base, mc)
    snr_list = mc.snr_list;
    SER_prop        = zeros(numel(snr_list),1);
    SER_lms         = zeros(numel(snr_list),1);
    SER_nlms        = zeros(numel(snr_list),1);
    SER_rls         = zeros(numel(snr_list),1);
    SER_smsign_vss  = zeros(numel(snr_list),1);
    SER_smsign      = zeros(numel(snr_list),1);

    for si = 1:numel(snr_list)
        snr_db = snr_list(si);
        acc_prop = 0; acc_lms = 0; acc_nlms = 0;
        acc_rls  = 0; acc_svss = 0; acc_sms = 0;

        for t = 1:mc.Ntrial_ser
            rng(2000 + 100*si + t);

            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);

            [r_clean, ~] = channel_out(d, cfg);

            cfg_ser = cfg;
            cfg_ser.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_ser);

            % --------------------------
            % simple AGC for practical path
            % --------------------------
            r = apply_practical_agc(r, d, cfg_ser);

            [~, d_hat_prop]       = proposed_recursion(r, d, cfg_ser, v_context);
            [~, d_hat_lms]        = dfe_lms_unified_x(r, d, cfg_ser, base);
            [~, d_hat_nlms]       = dfe_nlms_unified_x(r, d, cfg_ser, base);
            [~, d_hat_rls]        = dfe_rls_unified_x(r, d, cfg_ser, base);
            [~, d_hat_smsign_vss] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_ser, base, sigma2);
            [~, d_hat_sms]        = dfe_smsign_nlms_unified_x(r, d, cfg_ser, base, sigma2);

            acc_prop = acc_prop + ser_after_training_aligned(d, d_hat_prop,       cfg_ser);
            acc_lms  = acc_lms  + ser_after_training_aligned(d, d_hat_lms,        cfg_ser);
            acc_nlms = acc_nlms + ser_after_training_aligned(d, d_hat_nlms,       cfg_ser);
            acc_rls  = acc_rls  + ser_after_training_aligned(d, d_hat_rls,        cfg_ser);
            acc_svss = acc_svss + ser_after_training_aligned(d, d_hat_smsign_vss, cfg_ser);
            acc_sms  = acc_sms  + ser_after_training_aligned(d, d_hat_sms,        cfg_ser);
        end

        SER_prop(si)        = acc_prop / mc.Ntrial_ser;
        SER_lms(si)         = acc_lms  / mc.Ntrial_ser;
        SER_nlms(si)        = acc_nlms / mc.Ntrial_ser;
        SER_rls(si)         = acc_rls  / mc.Ntrial_ser;
        SER_smsign_vss(si)  = acc_svss / mc.Ntrial_ser;
        SER_smsign(si)      = acc_sms  / mc.Ntrial_ser;
    end

    ser_rslt = struct();
    ser_rslt.snr_list        = snr_list;
    ser_rslt.SER_prop        = SER_prop;
    ser_rslt.SER_lms         = SER_lms;
    ser_rslt.SER_nlms        = SER_nlms;
    ser_rslt.SER_rls         = SER_rls;
    ser_rslt.SER_smsign_vss  = SER_smsign_vss;
    ser_rslt.SER_smsign      = SER_smsign;
    ser_rslt.variant_name    = v_context.kind;
end

%% =====================================================================
% ENHANCED SER: Markov channel + theoretical floor + multi-panel plot
%% =====================================================================
