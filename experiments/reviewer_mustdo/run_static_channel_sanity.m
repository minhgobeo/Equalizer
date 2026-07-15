function pkg = run_static_channel_sanity(cfg, vars, base, mc)
%RUN_STATIC_CHANNEL_SANITY Produce Table 6: static-channel non-degradation.
% Purpose: show that Algorithm 6 does not damage performance when Markov switching is absent.

cfg_p = reviewer_set_regime(cfg, 'static');
cfg_p.SNRdB = 22;
cfg_p.Nsym = 80000;
Ntrial = max(20, min(50, mc.Ntrial_ser));

v_base = make_v_alg5(vars.theorem);
Kffe = cfg_p.Nf; L = cfg_p.Nb; main_idx = round((Kffe+1)/2);
v_base.main_idx = main_idx;
ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

% Algorithm 6 requires a state library. Use three identical states so it degenerates to single-bank behavior.
cfg_msb = cfg_p;
cfg_msb.chan_mode = 'markov_2tap';
cfg_msb.markov.h2_states = [0.5 0.5 0.5];
cfg_msb.markov.P = eye(3);
cfg_msb.markov.init_state = 2;
msb_params = default_msb_params_v69();

ser_alg6 = zeros(Ntrial,1); ser_alg5 = zeros(Ntrial,1); ser_nlms = zeros(Ntrial,1);
ber_alg6 = zeros(Ntrial,1); ber_alg5 = zeros(Ntrial,1); ber_nlms = zeros(Ntrial,1);
for t=1:Ntrial
    rng(920000+t);
    sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
    d = cfg_p.A(sym_idx).'; d = d(:);

    [r_clean, ~] = channel_out(d, cfg_p);
    [r,~] = add_noise_dispatch(r_clean, cfg_p);

    [dh1,~] = algorithm6_msb_v69(r, d, cfg_msb, v_base, msb_params, []);
    [dh2,~] = algorithm5_singlebank(r, d, cfg_p, v_base);
    [~, dh3] = dfe_nlms_unified_x(r, d, cfg_p, base);

    ser_alg6(t) = ser_after_training_aligned(d, dh1, cfg_p);
    ser_alg5(t) = ser_after_training_aligned(d, dh2, cfg_p);
    ser_nlms(t) = ser_after_training_aligned(d, dh3, cfg_p);
    ber_alg6(t) = ser_alg6(t)/log2(cfg_p.M);
    ber_alg5(t) = ser_alg5(t)/log2(cfg_p.M);
    ber_nlms(t) = ser_nlms(t)/log2(cfg_p.M);
end

pkg.method = {'Algorithm 6 degenerate MSB','Algorithm 5 single-bank','NLMS'};
pkg.BER = [mean(ber_alg6), mean(ber_alg5), mean(ber_nlms)];
pkg.SER = [mean(ser_alg6), mean(ser_alg5), mean(ser_nlms)];
pkg.Ntrial = Ntrial;
pkg.cfg = cfg_p;

fprintf('\nTABLE 6. Static-channel non-degradation, h=[1,0.5], SNR=22 dB\n');
for i=1:numel(pkg.method)
    fprintf('%-30s BER=%.3e, SER=%.3e\n', pkg.method{i}, pkg.BER(i), pkg.SER(i));
end
end
