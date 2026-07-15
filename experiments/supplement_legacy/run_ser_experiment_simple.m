% Auto-split from NCKH_v53.m (original line 1533).
% Folder: experiments/supplement_legacy

function ser_rslt = run_ser_experiment_simple(cfg, v_tuned, base_tuned, mc, chan_mode)
% SER vs SNR using SIMPLE channel model (no 802.3).
% PAIRED SAMPLES: same symbol sequence for all SNR points per trial.
% This eliminates variance from different symbol patterns and produces
% smooth, monotonically decreasing SER curves.
    snr_list = mc.snr_list;
    Nalg = 6;
    SER_all = zeros(numel(snr_list), Nalg);

    cfg_s = cfg;
    cfg_s.chan_mode = chan_mode;
    if isfield(cfg_s,'std8023'), cfg_s.std8023.enable = false; end

    for t = 1:mc.Ntrial_ser
        % --- Generate symbols and channel ONCE per trial ---
        rng(4000 + t);   % data seed: SAME across all SNR
        sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
        d = cfg.A(sym_idx).'; d = d(:);

        cfg_base = cfg_s;
        [r_clean, ~] = channel_out(d, cfg_base);

        for si = 1:numel(snr_list)
            snr_db = snr_list(si);

            % --- Add noise with SNR-dependent seed ---
            rng(6000 + 1000*t + si);  % noise seed
            cfg_run = cfg_base;
            cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            r = apply_practical_agc(r, d, cfg_run);

            [~, dh1] = proposed_recursion(r, d, cfg_run, v_tuned);
            [~, dh2] = dfe_lms_unified_x(r, d, cfg_run, base_tuned);
            [~, dh3] = dfe_nlms_unified_x(r, d, cfg_run, base_tuned);
            [~, dh4] = dfe_rls_unified_x(r, d, cfg_run, base_tuned);
            [~, dh5] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_run, base_tuned, sigma2);
            [~, dh6] = dfe_smsign_nlms_unified_x(r, d, cfg_run, base_tuned, sigma2);

            SER_all(si,1) = SER_all(si,1) + ser_after_training_aligned(d, dh1, cfg_run);
            SER_all(si,2) = SER_all(si,2) + ser_after_training_aligned(d, dh2, cfg_run);
            SER_all(si,3) = SER_all(si,3) + ser_after_training_aligned(d, dh3, cfg_run);
            SER_all(si,4) = SER_all(si,4) + ser_after_training_aligned(d, dh4, cfg_run);
            SER_all(si,5) = SER_all(si,5) + ser_after_training_aligned(d, dh5, cfg_run);
            SER_all(si,6) = SER_all(si,6) + ser_after_training_aligned(d, dh6, cfg_run);
        end

        if mod(t, 10) == 0
            fprintf('  [SER %s] trial %d/%d done\n', chan_mode, t, mc.Ntrial_ser);
        end
    end
    SER_all = SER_all / mc.Ntrial_ser;

    % Print final results
    for si = 1:numel(snr_list)
        fprintf('  [SER %s] SNR=%2d dB: Prop=%.4f LMS=%.4f NLMS=%.4f RLS=%.4f SMV=%.4f SM=%.4f\n', ...
            chan_mode, snr_list(si), SER_all(si,1), SER_all(si,2), SER_all(si,3), ...
            SER_all(si,4), SER_all(si,5), SER_all(si,6));
    end

    ser_rslt.snr_list        = snr_list;
    ser_rslt.SER_prop        = SER_all(:,1);
    ser_rslt.SER_lms         = SER_all(:,2);
    ser_rslt.SER_nlms        = SER_all(:,3);
    ser_rslt.SER_rls         = SER_all(:,4);
    ser_rslt.SER_smsign_vss  = SER_all(:,5);
    ser_rslt.SER_smsign      = SER_all(:,6);
    ser_rslt.channel_mode    = chan_mode;
end

%% =====================================================================
% THEOREM 2 COMPLETE SHOWCASE — 8 figures for IEEE Access
%% =====================================================================
