function pkg = run_oracle_dd_burden_isolation(cfg, vars, base, mc)
%RUN_ORACLE_DD_BURDEN_ISOLATION Direct theory-to-proxy bridge for Theorem 2.
% Compares oracle-routed MSB, implementable Algorithm 6, and single-bank DD.
% This is not a proof of b_c, but an empirical proxy for the burden mechanism.

snr_db = 22;
regimes = {'severe','realistic'};
Ntrial = max(20, min(50, mc.Ntrial_ser));
BER = zeros(numel(regimes),3); SER = zeros(numel(regimes),3);
names = {'Oracle MSB', 'Algorithm 6 HMM', 'Single-bank DD'};

for rg=1:numel(regimes)
    cfg_p = reviewer_set_regime(cfg, regimes{rg}); cfg_p.SNRdB = snr_db;
    v_base = make_v_alg5(vars.theorem);
    Kffe = cfg_p.Nf; L = cfg_p.Nb; main_idx = round((Kffe+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];
    msb_params = default_msb_params_v69();
    tmpSER = zeros(Ntrial,3);
    for t=1:Ntrial
        rng(930000+10000*rg+t);
        sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
        d = cfg_p.A(sym_idx).'; d = d(:);
        [r_clean, ch_state] = channel_out(d, cfg_p);
        [r,~] = add_noise_dispatch(r_clean, cfg_p);
        [dh_orc,~] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, ch_state.state);
        [dh_msb,~] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);
        [dh_a5,~] = algorithm5_singlebank(r, d, cfg_p, v_base);
        tmpSER(t,1) = ser_after_training_aligned(d, dh_orc, cfg_p);
        tmpSER(t,2) = ser_after_training_aligned(d, dh_msb, cfg_p);
        tmpSER(t,3) = ser_after_training_aligned(d, dh_a5, cfg_p);
    end
    SER(rg,:) = mean(tmpSER,1);
    BER(rg,:) = SER(rg,:)/log2(cfg_p.M);
end

pkg.regimes = regimes; pkg.names = names; pkg.SER = SER; pkg.BER = BER; pkg.snr_db = snr_db;
fprintf('\nTheory-to-proxy burden isolation at SNR=%d dB\n', snr_db);
fprintf('Regime        OracleMSB        Alg6-HMM        SingleBank       BurdenRatio(single/alg6)\n');
for rg=1:numel(regimes)
    fprintf('%-10s  %.3e       %.3e       %.3e       %.2fx\n', regimes{rg}, BER(rg,1), BER(rg,2), BER(rg,3), BER(rg,3)/max(BER(rg,2),eps));
end
end
