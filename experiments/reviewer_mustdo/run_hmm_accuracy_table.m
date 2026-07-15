function pkg = run_hmm_accuracy_table(cfg, vars, base, mc)
%RUN_HMM_ACCURACY_TABLE Produce Table 5: Pr(s_hat = alpha) vs SNR.
% This diagnostic supports A11/A12 and the routing-error term in Theorem 4.

snr_list = [14 18 22 26 30];
regimes = {'severe','realistic'};
Ntrial = max(20, min(50, mc.Ntrial_ser));
acc = zeros(numel(snr_list), numel(regimes));
best_acc = zeros(size(acc));
ser_alg6 = zeros(size(acc));
ser_oracle = zeros(size(acc));

for rg = 1:numel(regimes)
    cfg_p0 = reviewer_set_regime(cfg, regimes{rg});
    v_base = make_v_alg5(vars.theorem);
    Kffe = cfg_p0.Nf; L = cfg_p0.Nb;
    main_idx = round((Kffe+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];
    msb_params = default_msb_params_v69();

    for si = 1:numel(snr_list)
        raw_tmp = zeros(Ntrial,1); best_tmp = zeros(Ntrial,1);
        ser_tmp = zeros(Ntrial,1); ser_orc_tmp = zeros(Ntrial,1);
        for t = 1:Ntrial
            cfg_p = cfg_p0; cfg_p.SNRdB = snr_list(si);
            rng(910000 + 10000*rg + 100*si + t);
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ch_state] = channel_out(d, cfg_p);
            [r,~] = add_noise_dispatch(r_clean, cfg_p);

            [dh, diag_msb] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);
            [dh_orc, ~] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, ch_state.state);
            post_idx = (cfg_p.trainLen + diag_msb.N_sep + 1):cfg_p.Nsym;
            [raw_tmp(t), best_tmp(t)] = msb_state_accuracy(diag_msb.s_hat_hist, ch_state.state, post_idx);
            ser_tmp(t) = ser_after_training_aligned(d, dh, cfg_p);
            ser_orc_tmp(t) = ser_after_training_aligned(d, dh_orc, cfg_p);
        end
        acc(si,rg) = mean(raw_tmp);
        best_acc(si,rg) = mean(best_tmp);
        ser_alg6(si,rg) = mean(ser_tmp);
        ser_oracle(si,rg) = mean(ser_orc_tmp);
        fprintf('[hmm_accuracy] %s SNR=%d: raw=%.2f%% best=%.2f%%, oracle-gap SER %.3e/%.3e\n', ...
            regimes{rg}, snr_list(si), 100*acc(si,rg), 100*best_acc(si,rg), ser_alg6(si,rg), ser_oracle(si,rg));
    end
end

pkg.snr_list = snr_list;
pkg.regimes = regimes;
pkg.raw_acc = acc;
pkg.best_acc = best_acc;
pkg.ser_alg6 = ser_alg6;
pkg.ser_oracle = ser_oracle;

fprintf('\nTABLE 5. HMM state-accuracy Pr(s_hat = alpha) vs SNR\n');
fprintf('SNR(dB)    Severe(raw/best)       Realistic(raw/best)\n');
for si=1:numel(snr_list)
    fprintf('%6d    %6.2f%% / %6.2f%%      %6.2f%% / %6.2f%%\n', snr_list(si), ...
        100*acc(si,1), 100*best_acc(si,1), 100*acc(si,2), 100*best_acc(si,2));
end
end
