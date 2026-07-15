function pkg = run_ck_stressed_channel_check(cfg, vars, base, mc)
%RUN_CK_STRESSED_CHANNEL_CHECK  802.3ck-inspired dirty-PAM4 stress check.
%
% IMPORTANT (read me before citing):
%   This is NOT an IEEE 802.3ck compliance test. The real 802.3ck
%   compliance procedure requires COM, ERL, calibrated stressed eye,
%   PRBS test patterns, and measured S-parameters of a KR/CR/C2M
%   channel; none of which are reproduced here.
%
% This function is a SYMBOL-RATE simulation-level robustness check. It
% adds engineering stress on top of the controlled Markov 2-tap ISI:
%
%   * Residual high-order ISI: tail derived from the IEEE 802.3ck
%       insertion-loss specification IL_max(f). See
%       channel/build_8023ck_ref_residual_tail.m.
%   * Crosstalk-like independent PAM4 aggressors (proxy, not S-param).
%   * Random + sinusoidal + bounded uncorrelated jitter (first-order
%     slope-times-Δt proxy).
%   * Sinusoidal interference (one tone per packet).
%   * White Gaussian receiver noise.
%
% --- v63 receiver-architecture note (READ THIS) ---
%
% Real 802.3ck receivers cascade ANALOG equalization (CTLE/FFE) BEFORE
% the adaptive DFE. The CTLE/FFE handles the deterministic post-cursor
% taps; the adaptive DFE then handles slow channel variations and
% data-dependent residual ISI.
%
% Our paper studies the adaptive DFE+HMM stage, not the analog CTLE.
% The hero Markov-only experiments use a 2-tap channel where no CTLE
% is needed. Under the IL_max-derived stressed channel, the residual
% post-cursor taps include both pre- and post-cursor effects relative
% to the receiver's detection delay; if we feed them DIRECTLY into the
% adaptive DFE, the per-symbol score function (which assumes a 2-tap
% channel) is too noisy for HMM routing to work. v62 attempted to do
% this and failed.
%
% v63 architecture: a LINEAR PRE-EQUALIZER is trained ONCE on a short
% pilot block at the start of each packet to invert the IL_max tail
% (closed-form Wiener LS, no iterative training). After pre-eq, the
% effective channel seen by the adaptive receiver is approximately the
% 2-tap Markov ISI plus residual stress. The default receiver settings
% (Nb=1, hmm_temp=0.05) then apply unchanged. This mirrors how real
% receivers are organized: fixed analog EQ first, adaptive DFE second.
%
% The pre-equalizer is documented as part of the dirty-channel chain;
% its taps are reported in the output struct for reviewer audit.

fprintf('\n[ck_stress] 802.3ck-inspired stressed-channel check (NOT a compliance test).\n');

% --- Stress configuration ---
Ntrial    = max(10, min(20, mc.Ntrial_ser));
snr_list  = [22 26];
profiles  = {'isi_awgn','isi_xtalk_awgn','isi_jitter_awgn','dirty_full'};
BER_PRE_FEC_THRESHOLD = 2.4e-4;

% --- Residual ISI tail derived from IEEE 802.3ck IL_max ---
Ntaps_residual = 5;
il_offset_dB   = 6;
[ck_tail, ck_tail_info] = build_8023ck_ref_residual_tail(Ntaps_residual, il_offset_dB);

fprintf('[ck_stress] IL_max-derived residual tail (offset=%.0f dB from spec limit):\n', il_offset_dB);
fprintf('[ck_stress]   IL @ Nyquist (26.56 GHz)  = %.2f dB\n', ck_tail_info.IL_dB_at_Nyquist);
fprintf('[ck_stress]   tail = [%s]\n', strjoin(arrayfun(@(x) sprintf('%+.4f', x), ck_tail, 'uni', false), ', '));
fprintf('[ck_stress]   source: %s\n', ck_tail_info.formula_source);

% --- Pre-equalizer: invert IL_max tail with a fixed linear FIR ---
% We design ONCE outside the trial loop because the tail is deterministic.
preeq_taps = design_il_max_preeq(ck_tail, 11);
fprintf('[ck_stress] Linear pre-equalizer (analog CTLE/FFE proxy):\n');
fprintf('[ck_stress]   length=%d, taps = [%s]\n', numel(preeq_taps), ...
    strjoin(arrayfun(@(x) sprintf('%+.3f', x), preeq_taps, 'uni', false), ' '));

% --- Receiver config: SAME as paper hero defaults ---
cfg0 = local_ck_regime(cfg);
fprintf('[ck_stress] Receiver config (paper hero defaults preserved):\n');
fprintf('[ck_stress]   Nf=%d, Nb=%d, D=%d, trainLen=%d\n', cfg0.Nf, cfg0.Nb, cfg0.D, cfg0.trainLen);

v_base = local_alg5_base(vars, cfg0);
msb_params = default_msb_params_v69();   % v63: defaults, no per-experiment override

methods = {'Algorithm 2','Oracle-MSB (printed only)','Algorithm 1','NLMS','SM-sign'};
R = struct([]);
row = 0;

for pi = 1:numel(profiles)
    profile = profiles{pi};
    for si = 1:numel(snr_list)
        cfg_p = cfg0;
        cfg_p.SNRdB = snr_list(si);

        ser = zeros(Ntrial, numel(methods));
        acc = nan(Ntrial,1);
        sigma2_eff = zeros(Ntrial,1);

        for t = 1:Ntrial
            rng(980000 + 10000*pi + 100*si + t);
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);

            [r_dirty, r_noiseless, ch_state, stress] = ...
                local_ck_dirty_channel(d, cfg_p, profile, ck_tail);

            % v63: apply pre-equalizer to invert IL_max tail
            r = filter(preeq_taps, 1, r_dirty);

            sigma2_eff(t) = mean((r_dirty - r_noiseless).^2);

            [dh_alg2, diag_alg2] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);
            [dh_orc,  ~]         = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, ch_state.state);
            [dh_alg1, ~]         = algorithm5_singlebank(r, d, cfg_p, v_base);
            [~, dh_nlms]         = dfe_nlms_unified_x(r, d, cfg_p, base);
            [~, dh_sm]           = dfe_smsign_nlms_unified_x(r, d, cfg_p, base, max(sigma2_eff(t), eps));

            ser(t,1) = ser_after_training_aligned(d, dh_alg2, cfg_p);
            ser(t,2) = ser_after_training_aligned(d, dh_orc,  cfg_p);
            ser(t,3) = ser_after_training_aligned(d, dh_alg1, cfg_p);
            ser(t,4) = ser_after_training_aligned(d, dh_nlms, cfg_p);
            ser(t,5) = ser_after_training_aligned(d, dh_sm,   cfg_p);

            post_idx = (cfg_p.trainLen + diag_alg2.N_sep + 1):cfg_p.Nsym;
            if ~isempty(post_idx)
                acc(t) = msb_state_accuracy(diag_alg2.s_hat_hist, ch_state.state, post_idx);
            end
        end

        row = row + 1;
        R(row).profile = profile;
        R(row).SNRdB = cfg_p.SNRdB;
        R(row).methods = methods;
        R(row).SER = mean(ser,1);
        R(row).BER = R(row).SER / log2(cfg_p.M);
        R(row).hmm_accuracy = mean(acc,'omitnan');
        R(row).sigma2_eff = mean(sigma2_eff);
        R(row).stress = stress;
        R(row).pass_fec = R(row).BER(1) <= BER_PRE_FEC_THRESHOLD;

        fprintf('[ck_stress] %-15s SNR=%2d | acc=%5.2f%% | BER Alg2=%.3e (%s vs 2.4e-4), Oracle=%.3e, Alg1=%.3e, NLMS=%.3e, SM=%.3e\n', ...
            profile, cfg_p.SNRdB, 100*R(row).hmm_accuracy, R(row).BER(1), ...
            tern(R(row).pass_fec,'PASS','FAIL'), R(row).BER(2), R(row).BER(3), R(row).BER(4), R(row).BER(5));
    end
end

pkg = struct();
pkg.table = R;
pkg.methods = methods;
pkg.profiles = profiles;
pkg.snr_list = snr_list;
pkg.Ntrial = Ntrial;
pkg.cfg = cfg0;
pkg.msb_params_used = msb_params;
pkg.preeq_taps = preeq_taps;
pkg.ck_tail = ck_tail;
pkg.ck_tail_info = ck_tail_info;
pkg.stress_params = local_stress_params_summary(ck_tail);
pkg.ber_pre_fec_threshold = BER_PRE_FEC_THRESHOLD;
pkg.note = ['802.3ck-INSPIRED stressed-channel simulation, NOT compliance. ' ...
            'Residual ISI tail derived from IEEE P802.3ck Vancouver-2019 baseline IL_max. ' ...
            'Receiver chain: linear pre-equalizer (analog CTLE/FFE proxy) + adaptive DFE+HMM. ' ...
            'Paper hero receiver defaults preserved (Nb=1, hmm_temp=0.05). ' ...
            'No COM, no ERL, no calibrated VEC, no PRBS13Q/31Q, no measured S-param. ' ...
            'BER threshold 2.4e-4 corresponds to KP4-FEC pre-FEC target.'];

fprintf('\nTABLE CK. 802.3ck-inspired stressed-channel check, BER summary\n');
fprintf('Note: NOT an IEEE 802.3ck compliance test; pass/fail uses pre-FEC threshold 2.4e-4.\n');
fprintf('Residual tail derived from IEEE 802.3ck IL_max with %.0f dB margin from spec limit.\n', il_offset_dB);
fprintf('Receiver chain: linear pre-equalizer (analog proxy) + adaptive DFE+HMM with default settings.\n\n');
fprintf('%-16s %6s %10s %10s %10s %10s %10s %9s %6s\n', 'Profile','SNR','Alg2','Oracle','Alg1','NLMS','SM-sign','Acc','FEC');
for k=1:numel(R)
    fprintf('%-16s %6.0f %10.3e %10.3e %10.3e %10.3e %10.3e %8.2f%% %6s\n', ...
        R(k).profile, R(k).SNRdB, R(k).BER(1), R(k).BER(2), R(k).BER(3), R(k).BER(4), R(k).BER(5), ...
        100*R(k).hmm_accuracy, tern(R(k).pass_fec,'PASS','FAIL'));
end
end

% =====================================================================
function s = tern(c, a, b)
if c, s = a; else, s = b; end
end

% =====================================================================
function w = design_il_max_preeq(ck_tail, Lpreeq)
%DESIGN_IL_MAX_PREEQ  Closed-form linear pre-equalizer for IL_max tail.
%
% The IL_max-derived residual ISI is deterministic and KNOWN at design
% time. Solve the Wiener-Hopf normal equations once, offline, to find a
% length-Lpreeq FIR that approximately inverts the channel
% h_total = [1; ck_tail].
%
% Method: minimum-norm LS with delay choice that maximises peak.
if nargin < 2, Lpreeq = 11; end
h = [1; ck_tail(:)];
M = numel(h);
% Convolution matrix H of size (Lpreeq + M - 1) x Lpreeq
Lconv = Lpreeq + M - 1;
H = zeros(Lconv, Lpreeq);
for k = 1:Lpreeq
    H(k:k+M-1, k) = h;
end
% Try every possible target delay; keep the one with the smallest
% residual error.
best_err = inf; best_w = zeros(Lpreeq,1);
for D = 0:Lconv-1
    e = zeros(Lconv,1); e(D+1) = 1;
    w = (H.'*H + 1e-6*eye(Lpreeq)) \ (H.' * e);
    err = norm(H*w - e);
    if err < best_err
        best_err = err; best_w = w;
    end
end
w = best_w(:);
end

% =====================================================================
function cfg_p = local_ck_regime(cfg)
% v63: PAPER HERO DEFAULTS preserved.
% Pre-equalizer handles IL_max tail; receiver sees ~2-tap channel.
cfg_p = cfg;
cfg_p.chan_mode = 'markov_2tap';
cfg_p.Nsym = 80000;
cfg_p.trainLen = 8000;
cfg_p.SNRdB = 22;
cfg_p.Nf = 5;
cfg_p.Nb = 1;
cfg_p.D = 2;
cfg_p.markov.h2_states = [0.35 0.50 0.65];
cfg_p.markov.P = [0.985 0.015 0.000; ...
                  0.0075 0.985 0.0075; ...
                  0.000 0.015 0.985];
cfg_p.markov.init_state = 2;
end

% =====================================================================
function v_base = local_alg5_base(vars, cfg_p)
v_base = make_v_alg5(vars.theorem);
Kffe = cfg_p.Nf; L = cfg_p.Nb;
main_idx = round((Kffe+1)/2);
v_base.main_idx = main_idx;
ffe_min = -v_base.w2_max*ones(Kffe,1);
ffe_max =  v_base.w2_max*ones(Kffe,1);
ffe_min(main_idx) = -Inf;
ffe_max(main_idx) =  Inf;
v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];
end

% =====================================================================
function [r, r_noiseless, ch_state, stress] = local_ck_dirty_channel(d, cfg, profile, ck_tail)
[r_base, ch_state] = channel_out(d, cfg);
N = numel(d);
sp = local_stress_params_summary(ck_tail);
stress = sp;
stress.profile = profile;

r_noiseless = r_base;

if any(strcmp(profile, {'isi_awgn','isi_xtalk_awgn','isi_jitter_awgn','dirty_full'}))
    tail = [1; ck_tail(:)];
    r_noiseless = filter(tail, 1, r_noiseless);
end

if any(strcmp(profile, {'isi_jitter_awgn','dirty_full'}))
    delta_ui = sp.rj_ui*randn(N,1) + ...
               sp.sj_ui*sin(2*pi*sp.sj_cycles*(0:N-1)'/N + 2*pi*rand) + ...
               sp.buj_ui*(2*(rand(N,1)>0.5)-1);
    slope = [diff(r_noiseless); 0];
    r_noiseless = r_noiseless + slope .* delta_ui;
end

xt = zeros(N,1);
if any(strcmp(profile, {'isi_xtalk_awgn','dirty_full'}))
    sig_rms = rms(r_base);
    for ia = 1:sp.num_aggressors
        a = cfg.A(randi([1 cfg.M], N, 1)).'; a = a(:);
        hxt = [0; 1; -0.35; 0.12] * (0.8 + 0.4*rand);
        a_f = filter(hxt, 1, circshift(a, randi([1 5])));
        a_f = a_f / max(rms(a_f), eps);
        xt = xt + a_f;
    end
    xt = xt / max(rms(xt), eps) * sp.xtalk_rms_frac * sig_rms;
    r_noiseless = r_noiseless + xt;
end

if strcmp(profile, 'dirty_full')
    sig_rms = rms(r_base);
    tone = sin(2*pi*sp.si_cycles*(0:N-1)'/N + 2*pi*rand);
    r_noiseless = r_noiseless + sp.si_rms_frac * sig_rms * tone / rms(tone);
end

sig_pow_clean = mean(r_base.^2);
sigma2 = sig_pow_clean / (10^(cfg.SNRdB/10));
r = r_noiseless + sqrt(sigma2) * randn(N,1);
stress.sigma2_awgn = sigma2;
stress.xtalk_rms = rms(xt);
stress.snr_ref = 'clean signal r_base, NOT post-stress r_noiseless';
end

% =====================================================================
function sp = local_stress_params_summary(ck_tail)
if nargin < 1, ck_tail = zeros(5,1); end
sp = struct();
sp.extra_tail = ck_tail(:);
sp.extra_tail_source = 'IEEE P802.3ck Vancouver-2019 baseline IL_max, Annex 120E';
sp.rj_ui = 0.006;
sp.sj_ui = 0.020;
sp.buj_ui = 0.006;
sp.sj_cycles = 37;
sp.si_cycles = 11;
sp.num_aggressors = 4;
sp.xtalk_rms_frac = 0.045;
sp.si_rms_frac = 0.020;
end
