function pkg = run_liu_like_eye_benchmark_mc(cfg, vars, base, mc)
%RUN_LIU_LIKE_EYE_BENCHMARK_MC Monte-Carlo Liu-style PAM4 DFE benchmark.
%
% v68: adds statistical BER confidence intervals and quantitative eye metrics.
% Oracle is computed and printed only; it is not plotted.

fprintf('\n[liu_like_eye_mc] Monte-Carlo Liu-style adaptive PAM4 DFE benchmark.\n');
fprintf('[liu_like_eye_mc] Algorithmic benchmark only; NOT a circuit-level Liu reproduction.\n');

% --- Local Liu-style profile ---
cfg_p = reviewer_set_regime(cfg, 'realistic');
cfg_p.Nsym     = 50000;
cfg_p.trainLen = 8000;
cfg_p.SNRdB    = 22;
cfg_p.Nf       = 5;
cfg_p.Nb       = 4;
cfg_p.D        = 2;
cfg_p.markov.h2_states = [0.35 0.50 0.65];
cfg_p.markov.P = [0.985 0.015 0.000; ...
                  0.0075 0.985 0.0075; ...
                  0.000 0.015 0.985];
cfg_p.markov.init_state = 2;

Ntrial = 30;
if isfield(mc,'Ntrial_liu_eye'), Ntrial = mc.Ntrial_liu_eye; end

v_base = make_v_alg5(vars.theorem);
Kffe = cfg_p.Nf; L = cfg_p.Nb; main_idx = round((Kffe+1)/2);
v_base.main_idx = main_idx;
ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];
msb_params = default_msb_params_v69();

names = {'Algorithm 2 proposed HMM-MSB','Oracle MSB upper bound','Algorithm 1 single-bank', ...
         'Liu SS-LMS DFE','Liu TA-SS-LMS DFE','SM-sign-NLMS'};
Kmeth = numel(names);
BER = nan(Ntrial, Kmeth);
SER = nan(Ntrial, Kmeth);
Qmin = nan(Ntrial, 5);
EyeOpen = nan(Ntrial, 5);

last_eye = [];

for t = 1:Ntrial
    rng(1234566 + 1009*t);
    sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
    d = cfg_p.A(sym_idx).'; d = d(:);
    [r_clean, ch_state] = channel_out(d, cfg_p);
    [r_noisy, sigma2] = add_noise_dispatch(r_clean, cfg_p);
    r_rx = local_liu_frontend_proxy_mc(r_noisy);

    [dh_alg2, diag_alg2] = algorithm6_msb_v69(r_rx, d, cfg_p, v_base, msb_params, []);
    [dh_orc,  diag_orc]  = algorithm6_msb_v69(r_rx, d, cfg_p, v_base, msb_params, ch_state.state);
    [dh_alg1, diag_alg1] = algorithm5_singlebank(r_rx, d, cfg_p, v_base);

    opts_ss = struct('adaptive_threshold', false, 'update_ffe', false, ...
                     'update_dfe', true, 'mu_f', 2e-3, 'use_projection', true);
    [~, dh_ss, diag_ss] = dfe_ss_lms_pam4(r_rx, d, cfg_p, v_base, opts_ss);

    opts_ta = struct('adaptive_threshold', true, 'update_ffe', false, ...
                     'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, ...
                     'use_projection', true);
    [~, dh_ta, diag_ta] = dfe_ss_lms_pam4(r_rx, d, cfg_p, v_base, opts_ta);

    [~, dh_sm, diag_sm] = dfe_smsign_nlms_unified_x(r_rx, d, cfg_p, base, sigma2);

    dlist = {dh_alg2, dh_orc, dh_alg1, dh_ss, dh_ta, dh_sm};
    for k = 1:Kmeth
        SER(t,k) = ser_after_training_aligned(d, dlist{k}, cfg_p);
        BER(t,k) = SER(t,k)/log2(cfg_p.M);
    end

    % Quantitative eye metrics for plotted methods only.
    ylist = {r_rx, diag_alg1.y_hist, diag_alg2.y_hist, diag_ss.z_hist, diag_ta.z_hist};
    for k = 1:5
        met = compute_eye_quality_metrics(ylist{k}, d, cfg_p);
        Qmin(t,k) = met.min_q;
        EyeOpen(t,k) = met.min_eye_opening_5_95;
    end

    if t == Ntrial
        % Save final packet for common-scale eye figure.
        seg = (cfg_p.trainLen + 1000) : min(cfg_p.Nsym, cfg_p.trainLen + 12000);
        idx_r = seg + cfg_p.D;
        idx_r = idx_r(idx_r >= 1 & idx_r <= numel(r_rx));
        seg = seg(1:min(numel(seg), numel(idx_r)));
        idx_r = idx_r(1:numel(seg));
        last_eye = struct();
        last_eye.rx_before = r_rx(idx_r);
        last_eye.alg1      = diag_alg1.y_hist(idx_r);
        last_eye.alg2      = diag_alg2.y_hist(idx_r);
        last_eye.liu_ss    = diag_ss.z_hist(idx_r);
        last_eye.liu_ta    = diag_ta.z_hist(idx_r);
    end

    if mod(t, max(1, round(Ntrial/10))) == 0
        fprintf('[liu_like_eye_mc] trial %d/%d\n', t, Ntrial);
    end
end

ber_mean = mean(BER, 1, 'omitnan');
ber_std  = std(BER, 0, 1, 'omitnan');
ber_ci95 = 1.96 * ber_std / sqrt(Ntrial);

fprintf('\nTABLE LIU-MC. Liu-style receiver profile, SNR=%d dB, %d trials, 4-tap DFE.\n', cfg_p.SNRdB, Ntrial);
fprintf('%-32s %12s %12s %12s\n', 'Method', 'Mean BER', 'Std', '95% CI');
for k = 1:Kmeth
    if k == 2
        fprintf('%-32s %12.3e %12.3e %12.3e  (printed only; not plotted)\n', names{k}, ber_mean(k), ber_std(k), ber_ci95(k));
    else
        fprintf('%-32s %12.3e %12.3e %12.3e\n', names{k}, ber_mean(k), ber_std(k), ber_ci95(k));
    end
end

fprintf('\nTABLE LIU-EYE-METRICS. Quantitative eye metrics, post-training samples.\n');
fprintf('%-24s %12s %12s\n', 'Method', 'min Q', 'min 5-95 opening');
metric_names = {'Rx before EQ','Algorithm 1','Algorithm 2','Liu SS-LMS','Liu TA-SS-LMS'};
for k = 1:5
    fprintf('%-24s %12.3f %12.3e\n', metric_names{k}, mean(Qmin(:,k),'omitnan'), mean(EyeOpen(:,k),'omitnan'));
end

pkg = struct();
pkg.tag = 'liu_like_eye_mc_v68';
pkg.cfg = cfg_p;
pkg.snr = cfg_p.SNRdB;
pkg.Ntrial = Ntrial;
pkg.methods = names;
pkg.ber = BER;
pkg.ser = SER;
pkg.ber_mean = ber_mean;
pkg.ber_std = ber_std;
pkg.ber_ci95 = ber_ci95;
pkg.eye_q_min = Qmin;
pkg.eye_opening_5_95 = EyeOpen;
pkg.eye_metric_names = metric_names;
pkg.eye_signals = last_eye;
pkg.ber_methods = names;
pkg.ber_values = ber_mean;
pkg.note = ['Monte-Carlo Liu-style symbol-rate adaptive-DFE benchmark. Oracle is computed ' ...
            'for audit only and is not included in figures.'];
end

function y = local_liu_frontend_proxy_mc(x)
b = [1.00 -0.18];
a = [1.00 -0.08];
y = filter(b, a, x(:));
if std(y) > 0
    y = y * (std(x(:)) / std(y));
end
end
