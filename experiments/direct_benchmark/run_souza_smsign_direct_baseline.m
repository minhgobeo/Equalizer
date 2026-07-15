function pkg = run_souza_smsign_direct_baseline(cfg, vars, base, mc)
%RUN_SOUZA_SMSIGN_DIRECT_BASELINE Direct numerical baseline.
%
% Implementation note:
%   SM-sign-NLMS and SM-sign-NLMS-VSS are taken directly from
%     dfe_smsign_nlms_unified_x.m
%     dfe_smsign_nlms_vss_unified_x.m
%   inspired by Souza et al. 2024 "Stochastic modelling of the SM-sign-NLMS
%   algorithm" (Foundations and Trends in ML / signal processing).
%
%   We call them inside the same PAM4 Markov-DD testbed (severe and realistic
%   regimes) so they appear as DIRECT numerical baselines, not adapted ones.

snr_list = [14 18 22 26];
regimes  = {'severe','realistic'};
Ntrial   = max(20, min(50, mc.Ntrial_ser));

BER_smsign_fix = nan(numel(snr_list), numel(regimes));
BER_smsign_vss = nan(numel(snr_list), numel(regimes));
BER_alg2       = nan(numel(snr_list), numel(regimes));

msb_params = default_msb_params_v69();

for rg = 1:numel(regimes)
    cfg_p0 = reviewer_set_regime(cfg, regimes{rg});

    v_base = make_v_alg5(vars.theorem);
    Kffe = cfg_p0.Nf; L = cfg_p0.Nb; main_idx = round((Kffe+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    for si = 1:numel(snr_list)
        ser_fix_t = zeros(Ntrial,1);
        ser_vss_t = zeros(Ntrial,1);
        ser_a2_t  = zeros(Ntrial,1);
        for t=1:Ntrial
            rng(970000 + 1000*rg + 100*si + t);
            cfg_p = cfg_p0; cfg_p.SNRdB = snr_list(si);
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean,~] = channel_out(d, cfg_p);
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_p);

            [~, dh_fix] = dfe_smsign_nlms_unified_x(r, d, cfg_p, base, sigma2);
            [~, dh_vss] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_p, base, sigma2);
            [dh_a2, ~]  = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);

            ser_fix_t(t) = ser_after_training_aligned(d, dh_fix, cfg_p);
            ser_vss_t(t) = ser_after_training_aligned(d, dh_vss, cfg_p);
            ser_a2_t(t)  = ser_after_training_aligned(d, dh_a2,  cfg_p);
        end
        BER_smsign_fix(si,rg) = mean(ser_fix_t)/log2(cfg_p0.M);
        BER_smsign_vss(si,rg) = mean(ser_vss_t)/log2(cfg_p0.M);
        BER_alg2(si,rg)       = mean(ser_a2_t) /log2(cfg_p0.M);
        fprintf('[souza_smsign] %s SNR=%d -> SMsign=%.3e, SMsign-VSS=%.3e, Alg2=%.3e\n', ...
            regimes{rg}, snr_list(si), BER_smsign_fix(si,rg), BER_smsign_vss(si,rg), BER_alg2(si,rg));
    end
end

pkg.snr_list = snr_list;
pkg.regimes = regimes;
pkg.BER_smsign_fix = BER_smsign_fix;
pkg.BER_smsign_vss = BER_smsign_vss;
pkg.BER_alg2       = BER_alg2;
pkg.BER_alg6       = BER_alg2;  % backward-compatible alias
pkg.tag = 'Souza_SMsign_direct_baseline';
end
