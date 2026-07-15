function pkg = run_liu_like_eye_benchmark(cfg, vars, base, mc)
%RUN_LIU_LIKE_EYE_BENCHMARK  Liu-style PAM4 adaptive-DFE benchmark with eye diagrams.
%
% This runner builds a Liu-inspired symbol-rate benchmark:
%   * PAM4 receiver-side adaptive DFE comparison.
%   * Local 4-tap DFE setting, matching Liu et al.'s adaptive DFE emphasis.
%   * Optional threshold adaptation for the Liu-style baseline.
%   * Same received waveform is passed to Algorithm 1, Algorithm 2 and Liu-style
%     baselines.
%   * Oracle MSB is computed and printed only; it is not included in figures.
%
% The original Liu receiver includes circuit blocks (3-stage CTLE, VGA, SatAmp,
% CDR and auxiliary samplers). This code does not reproduce those circuits. It
% evaluates the comparable algorithmic adaptive-DFE part and adds eye diagrams
% in the same style as Liu's visual validation.

fprintf('\n[liu_like_eye] Liu-style adaptive PAM4 DFE benchmark with eye diagrams.\n');
fprintf('[liu_like_eye] Algorithmic benchmark only; NOT a circuit-level Liu reproduction.\n');

% --- Local Liu-style profile ---
cfg_p = reviewer_set_regime(cfg, 'realistic');
cfg_p.Nsym     = 50000;
cfg_p.trainLen = 8000;
cfg_p.SNRdB    = 22;
cfg_p.Nf       = 5;
cfg_p.Nb       = 4;       % Liu et al. use 4 DFE feedback taps
cfg_p.D        = 2;

% Mildly separated Markov profile: same benchmark channel for all methods.
% This keeps the user's Markov-ISI question active while using a Liu-style
% adaptive-DFE receiver configuration.
cfg_p.markov.h2_states = [0.35 0.50 0.65];
cfg_p.markov.P = [0.985 0.015 0.000; ...
                  0.0075 0.985 0.0075; ...
                  0.000 0.015 0.985];
cfg_p.markov.init_state = 2;

v_base = make_v_alg5(vars.theorem);
Kffe = cfg_p.Nf; L = cfg_p.Nb; main_idx = round((Kffe+1)/2);
v_base.main_idx = main_idx;
ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

msb_params = default_msb_params_v69();

% --- One deterministic packet for eye + BER table ---
rng(1234566);
sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
d = cfg_p.A(sym_idx).'; d = d(:);
[r_clean, ch_state] = channel_out(d, cfg_p);
[r_noisy, sigma2] = add_noise_dispatch(r_clean, cfg_p);

% Liu-style analog front-end proxy: all methods see the same waveform.
% This is a stable, low-order peaking/normalization proxy, not CTLE circuit reproduction.
r_rx = local_liu_frontend_proxy(r_noisy);

% --- Run methods ---
[dh_alg2, diag_alg2] = algorithm6_msb_v69(r_rx, d, cfg_p, v_base, msb_params, []);
[dh_orc,  ~]         = algorithm6_msb_v69(r_rx, d, cfg_p, v_base, msb_params, ch_state.state);
[dh_alg1, diag_alg1] = algorithm5_singlebank(r_rx, d, cfg_p, v_base);

opts_ss = struct('adaptive_threshold', false, 'update_ffe', false, ...
                 'update_dfe', true, 'mu_f', 2e-3, 'use_projection', true);
[~, dh_ss, diag_ss] = dfe_ss_lms_pam4(r_rx, d, cfg_p, v_base, opts_ss);

opts_ta = struct('adaptive_threshold', true, 'update_ffe', false, ...
                 'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, ...
                 'use_projection', true);
[~, dh_ta, diag_ta] = dfe_ss_lms_pam4(r_rx, d, cfg_p, v_base, opts_ta);

[~, dh_sm] = dfe_smsign_nlms_unified_x(r_rx, d, cfg_p, base, sigma2);

% --- BER table. Oracle is printed only. ---
BER_alg2 = ser_after_training_aligned(d, dh_alg2, cfg_p) / log2(cfg_p.M);
BER_orc  = ser_after_training_aligned(d, dh_orc,  cfg_p) / log2(cfg_p.M);
BER_alg1 = ser_after_training_aligned(d, dh_alg1, cfg_p) / log2(cfg_p.M);
BER_ss   = ser_after_training_aligned(d, dh_ss,   cfg_p) / log2(cfg_p.M);
BER_ta   = ser_after_training_aligned(d, dh_ta,   cfg_p) / log2(cfg_p.M);
BER_sm   = ser_after_training_aligned(d, dh_sm,   cfg_p) / log2(cfg_p.M);

fprintf('\nTABLE LIU-EYE. Liu-style receiver profile, SNR=%d dB, 4-tap DFE.\n', cfg_p.SNRdB);
fprintf('%-32s %12s\n', 'Method', 'BER');
fprintf('%-32s %12.3e\n', 'Algorithm 2 proposed HMM-MSB', BER_alg2);
fprintf('%-32s %12.3e  (printed only; not plotted)\n', 'Oracle MSB upper bound', BER_orc);
fprintf('%-32s %12.3e\n', 'Algorithm 1 single-bank', BER_alg1);
fprintf('%-32s %12.3e\n', 'Liu SS-LMS DFE', BER_ss);
fprintf('%-32s %12.3e\n', 'Liu TA-SS-LMS DFE', BER_ta);
fprintf('%-32s %12.3e\n', 'SM-sign-NLMS', BER_sm);

% --- Eye-diagram signals. Use equalizer output histories where available. ---
seg = (cfg_p.trainLen + 1000) : min(cfg_p.Nsym, cfg_p.trainLen + 12000);
nseg = numel(seg);
idx_r = seg + cfg_p.D;
idx_r = idx_r(idx_r >= 1 & idx_r <= numel(r_rx));
seg = seg(1:min(nseg, numel(idx_r)));
idx_r = idx_r(1:numel(seg));

pkg = struct();
pkg.tag = 'liu_like_eye_benchmark_v66';
pkg.cfg = cfg_p;
pkg.snr = cfg_p.SNRdB;
pkg.methods = {'Rx before EQ','Algorithm 1 single-bank','Algorithm 2 proposed', ...
               'Liu SS-LMS DFE','Liu TA-SS-LMS DFE'};
pkg.ber_methods = {'Algorithm 2 proposed','Oracle printed only','Algorithm 1', ...
                   'Liu SS-LMS','Liu TA-SS-LMS','SM-sign-NLMS'};
pkg.ber_values = [BER_alg2, BER_orc, BER_alg1, BER_ss, BER_ta, BER_sm];
pkg.eye_signals = struct();
pkg.eye_signals.rx_before = r_rx(idx_r);
pkg.eye_signals.alg1      = diag_alg1.y_hist(idx_r);
pkg.eye_signals.alg2      = diag_alg2.y_hist(idx_r);
pkg.eye_signals.liu_ss    = diag_ss.z_hist(idx_r);
pkg.eye_signals.liu_ta    = diag_ta.z_hist(idx_r);
pkg.note = ['Liu-style symbol-rate adaptive-DFE benchmark. Oracle is computed ' ...
            'for audit only and is not included in figures.'];
end

% =====================================================================
function y = local_liu_frontend_proxy(x)
% A conservative CTLE-like peaking + normalization proxy. It is applied to all
% compared methods, so it does not advantage the Liu baseline.
b = [1.00 -0.18];
a = [1.00 -0.08];
y = filter(b, a, x(:));
if std(y) > 0
    y = y * (std(x(:)) / std(y));
end
end
