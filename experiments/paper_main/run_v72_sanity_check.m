function run_v72_sanity_check()
% Sanity: v72 with use_adaptive_tau=false  ==  v70_banklocal exactly.
    cfg_p = build_main_config('severe');
    vars  = build_variants();
    base  = make_v_alg5(vars.theorem);
    mc.Ntrial_ser = 1;
    snr_db = 22;

    rng(42);
    sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
    d = cfg_p.A(sym_idx).'; d = d(:);
    [r_clean, ~] = channel_out(d, cfg_p);
    cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
    [r, ~] = add_noise_dispatch(r_clean, cfg_run);
    v_base = base; v_base.main_idx = round((cfg_p.Nf+1)/2);
    ffe_min = -v_base.w2_max*ones(cfg_p.Nf,1); ffe_max = v_base.w2_max*ones(cfg_p.Nf,1);
    ffe_min(v_base.main_idx) = -Inf; ffe_max(v_base.main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(cfg_p.Nb,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(cfg_p.Nb,1)];

    % v70 baseline
    p70 = default_msb_params_v69();
    [dh70, ~] = algorithm6_msb_v70_banklocal(r, d, cfg_run, v_base, p70, []);

    % v72 with flag OFF — must match v70
    p72 = default_msb_params_v72();
    p72.use_adaptive_tau = false;
    [dh72_off, ~] = algorithm6_msb_v72_adaptive_tau(r, d, cfg_run, v_base, p72, []);

    diff_off = sum(dh70 ~= dh72_off);
    fprintf('[SANITY] v70 vs v72(off):  %d mismatches (expect 0)\n', diff_off);

    % v72 with flag ON — diagnostics check
    p72.use_adaptive_tau = true;
    p72.tau_calib = 2.0;
    [dh72_on, diag72] = algorithm6_msb_v72_adaptive_tau(r, d, cfg_run, v_base, p72, []);

    ser_on  = ser_after_training_aligned(d, dh72_on,  cfg_run);
    ser_70  = ser_after_training_aligned(d, dh70,     cfg_run);
    fprintf('[SANITY] v70 SER=%.3e, v72(on) SER=%.3e\n', ser_70, ser_on);
    fprintf('[SANITY] σ̂²_ν steady=%.4e, SNR_state steady=%.3f, τ_eff=%.2f\n', ...
        mean(diag72.sigma_nu2_hist(round(end/2):end)), ...
        mean(diag72.SNR_state_hist(round(end/2):end)), ...
        diag72.tau_eff_final);
end