function pkg = run_8023ck_sparam_benchmark(cfg, vars, base, mc, varargin)
%RUN_8023CK_SPARAM_BENCHMARK  802.3ck public-channel COM-style benchmark.
%
% This benchmark is intentionally described as "802.3ck-inspired" rather
% than "IEEE compliance": it uses public/contributed Touchstone channels
% when available, a Tx FFE + S-parameter FIR + AWGN/XTALK + receiver EQ flow,
% and paper metrics (BER/SER/eye/state accuracy). It does not run COM.

p = inputParser;
addParameter(p, 'channel_dir', fullfile('data','8023ck_channels'), @ischar);
addParameter(p, 'allow_synthetic', true, @islogical);
addParameter(p, 'snr', [18 22 26], @isnumeric);
addParameter(p, 'trials', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'max_cases', 6, @(x)isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'baud', 26.5625e9, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'override_manifest_baud', true, @islogical);
addParameter(p, 'run_static', true, @islogical);
addParameter(p, 'run_markov', true, @islogical);
addParameter(p, 'run_markov_sweep', false, @islogical);
addParameter(p, 'p_stay', [0.995 0.985 0.970 0.930], @isnumeric);
addParameter(p, 'markov_oracle_route', false, @islogical);
addParameter(p, 'markov_modes', {'slow','medium','fast','jump'}, @(x) iscell(x) || ischar(x));
addParameter(p, 'markov_nsym', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'markov_trainLen', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'markov_nb', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'markov_smnlms_tau', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'markov_smnlms_beta', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'markov_use_smnlms_shadow_output', false, @islogical);
addParameter(p, 'markov_use_adaptive_tau', false, @islogical);
addParameter(p, 'markov_tau_calib', 1.0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'markov_use_transition_gate', false, @islogical);
addParameter(p, 'markov_transition_gate_conf', 0.50, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'markov_twochain', false, @islogical);
addParameter(p, 'markov_twochain_noise_scale', [1.0 1.25], @isnumeric);
addParameter(p, 'markov_twochain_imp_prob', [0.0 0.0005], @isnumeric);
addParameter(p, 'markov_twochain_imp_alpha', 10, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'save_dir', 'figs', @ischar);
addParameter(p, 'noise_reference', 'clean', @ischar);
addParameter(p, 'seed_offset', 0, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});
opt = p.Results;

fprintf('\n[8023ck_sparam] Public S-parameter / COM-style PAM4 benchmark.\n');
fprintf('[8023ck_sparam] Not IEEE compliance; no COM pass/fail is claimed.\n');

catalog = build_8023ck_channel_catalog( ...
    'root_dir', opt.channel_dir, ...
    'allow_synthetic', opt.allow_synthetic, ...
    'baud', opt.baud, 'sps', 16, 'ntaps', 9, ...
    'override_manifest_baud', opt.override_manifest_baud);

if isempty(catalog)
    error('run_8023ck_sparam_benchmark:noChannels', ...
        ['No Touchstone channels found. Put .s4p/.sNp files under %s ' ...
         'or enable allow_synthetic for smoke tests.'], opt.channel_dir);
end

cases = local_select_cases(catalog, opt.max_cases);
if any(~[cases.is_public_sparameter])
    warning('run_8023ck_sparam_benchmark:fallback', ...
        ['Synthetic fallback channels are being used. These are only for ' ...
         'pipeline smoke tests and must not be reported as paper results.']);
end

cfg_p = local_receiver_cfg(cfg);
cfg_p.markov_oracle_route = opt.markov_oracle_route;
v_base = local_v_base(vars, cfg_p);
msb_params = default_msb_params_v69();
msb_params.train_all_prefix = cfg_p.trainLen;
% For S-parameter benchmarks, Algorithm 6 is allowed the same pulse-response
% knowledge used by the Chen-style fixed reference.  This makes the proposed
% receiver a pulse-initialized online tracker rather than a cold-start
% adaptive equalizer, which is the fair comparison for static 802.3ck cases.
msb_params.score_mode = 'channel_likelihood';
msb_params.init_from_hbank = true;
% Enable full proposed feature set: SMNLMS + EB gate + soft output + adaptive tau
msb_params.bank_update_rule = 'smnlms';
msb_params.smnlms = base.smnlms;
msb_params.eb_gate = local_default_eb_gate();
msb_params.use_soft_output = false;
msb_params.use_adaptive_tau = false;
msb_params.tau_calib = 2.0;
msb_params.tau_ema_alpha = 0.99;
msb_params.tau_min = 1e-3;
msb_params.tau_max = 0.5;
msb_params.use_beta_anneal = true;
msb_params.anneal_halflife = 6000;
msb_params.anneal_floor = 0.4;
Nt = opt.trials;
if isempty(Nt), Nt = max(3, min(8, mc.Ntrial_ser)); end

methods = {'No EQ','NLMS-DFE','SMNLMS-DFE','SM-sign-NLMS', ...
           'Liu SS-LMS','Chen pulse-ref','ExtraTrees-HMM','Algorithm 1','Proposed MSB'};
rows = struct([]);
row = 0;

if opt.run_static
    fprintf('[8023ck_sparam] Static cases=%d, trials=%d, SNR=[%s]\n', ...
        numel(cases), Nt, num2str(opt.snr));
else
    fprintf('[8023ck_sparam] Static benchmark skipped (run_static=false).\n');
end

for ci = 1:(numel(cases) * double(opt.run_static))
    ch = cases(ci);
    for si = 1:numel(opt.snr)
        cfg_run = cfg_p;
        cfg_run.SNRdB = opt.snr(si);
        tx_ffe = local_tx_ffe_taps();
        h_bank_static = local_static_h_bank(local_effective_channel(ch.symbol_taps, tx_ffe));
        cfg_run.markov.h2_states = cellfun(@(h) h(min(2,numel(h))), h_bank_static);
        cfg_run.markov.P = eye(numel(cfg_run.markov.h2_states));
        cfg_run.markov.init_state = 2;

        ser = zeros(Nt, numel(methods));
        eye_h = nan(Nt, numel(methods));
        eye_w = nan(Nt, numel(methods));

        for t = 1:Nt
            rng(1200000 + opt.seed_offset + 10000*ci + 100*si + t);
            d = local_pam4(cfg_run);
            tx = local_apply_tx_ffe(d, tx_ffe);
            r_clean = filter(ch.symbol_taps, 1, tx);
            if strcmpi(ch.group, 'Cable') || contains(lower(ch.case_id), 'xtalk')
                r_clean = r_clean + local_xtalk_like(d, 0.04*rms(r_clean));
            end
            [r, sigma2, rx_gain] = local_add_receiver_noise(r_clean, tx, cfg_run, opt.noise_reference);
            h_bank_static_rx = cellfun(@(h) rx_gain*h, h_bank_static, 'UniformOutput', false);

            dh_noeq = local_noeq(r, cfg_run);
            [y_nlms, dh_nlms] = dfe_nlms_unified_x(r, d, cfg_run, base);
            diag_nlms = struct('z_hist', y_nlms);
            [y_smn, dh_smn] = dfe_smnlms_unified_x(r, d, cfg_run, base, sigma2);
            diag_smn = struct('z_hist', y_smn);
            [y_sm, dh_sm] = dfe_smsign_nlms_unified_x(r, d, cfg_run, base, sigma2);
            diag_sm = struct('z_hist', y_sm);
            cfg_liu = cfg_run;
            v_liu = local_v_base(vars, cfg_liu);
            opts_liu = struct('adaptive_threshold', true, 'update_ffe', false, ...
                              'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, ...
                              'use_projection', true);
            [~, dh_liu, diag_liu] = dfe_ss_lms_pam4(r, d, cfg_liu, v_liu, opts_liu);
            h_eff_rx = rx_gain * local_effective_channel(ch.symbol_taps, tx_ffe);
            [dh_chen, diag_chen] = local_chen_reference(r, h_eff_rx, cfg_run);
            [dh_cui, diag_cui] = local_extratrees_hmm_reference(r, d, cfg_run);
            [dh_alg1, diag_alg1] = local_algorithm1_endogenous(r, d, cfg_run, base, sigma2 * rx_gain^2);
            msb_params_static = msb_params;
            msb_params_static.sigma2 = sigma2;
            [dh_alg6, diag_alg6] = algorithm6_msb_firbank(r, d, cfg_run, v_base, msb_params_static, h_bank_static_rx, []);

            dhs = {dh_noeq, dh_nlms, dh_smn, dh_sm, dh_liu, dh_chen, dh_cui, dh_alg1, dh_alg6};
            diags = {struct('z_hist',r(:)), diag_nlms, diag_smn, diag_sm, ...
                     diag_liu, diag_chen, diag_cui, diag_alg1, diag_alg6};
            for mi = 1:numel(methods)
                ser(t,mi) = ser_after_training_aligned(d, dhs{mi}, cfg_run);
                y = local_diag_output(diags{mi}, r, cfg_run);
                em = compute_eye_height_width_metrics(y, d, cfg_run);
                eye_h(t,mi) = em.eye_height_5_95;
                eye_w(t,mi) = em.eye_width_ui;
            end
        end

        row = row + 1;
        rows(row).case_id = ch.case_id;
        rows(row).group = ch.group;
        rows(row).role = ch.role;
        rows(row).is_public_sparameter = ch.is_public_sparameter;
        rows(row).file = ch.file;
        rows(row).SNRdB = cfg_run.SNRdB;
        rows(row).insertion_loss_db = ch.insertion_loss_db;
        rows(row).methods = methods;
        rows(row).SER = mean(ser,1);
        rows(row).BER = rows(row).SER / log2(cfg_run.M);
        rows(row).EyeHeight = mean(eye_h,1,'omitnan');
        rows(row).EyeWidth = mean(eye_w,1,'omitnan');

        fprintf('[8023ck_sparam] %-24s SNR=%2d IL=%5.1f dB | Alg6 BER=%.3e, NLMS=%.3e, Alg1=%.3e\n', ...
            ch.case_id, cfg_run.SNRdB, ch.insertion_loss_db, ...
            rows(row).BER(end), rows(row).BER(2), rows(row).BER(8));
    end
end

markov = [];
if opt.run_markov && numel(cases) >= 3
    markov = local_run_markov_cases(cases, cfg_p, v_base, msb_params, vars, base, opt.snr, Nt, opt);
end

markov_sweep = [];
if opt.run_markov_sweep && numel(cases) >= 3
    markov_sweep = local_run_markov_sweep_cases(cases, cfg_p, vars, base, v_base, ...
        msb_params, opt.snr, Nt, opt.p_stay, opt);
end

pkg = struct();
pkg.table = rows;
pkg.markov = markov;
pkg.markov_sweep = markov_sweep;
pkg.cases = cases;
pkg.methods = methods;
pkg.cfg = cfg_p;
pkg.note = ['IEEE 802.3ck-inspired public S-parameter benchmark. This is a ' ...
            'COM-style simulation flow, not a COM or IEEE compliance test.'];

local_write_csv(pkg, opt.save_dir);
end

function cfg_p = local_receiver_cfg(cfg)
cfg_p = cfg;
cfg_p.Nsym = 40000;
cfg_p.trainLen = 8000;
cfg_p.Nf = 7;
cfg_p.Nb = 3;
cfg_p.D = 3;
cfg_p.chan_mode = 'external_fir';
if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end
end

function v_base = local_v_base(vars, cfg_p)
v_base = make_v_alg5(vars.theorem);
K = cfg_p.Nf; L = cfg_p.Nb;
main_idx = round((K+1)/2);
v_base.main_idx = main_idx;
ffe_min = -v_base.w2_max*ones(K,1);
ffe_max =  v_base.w2_max*ones(K,1);
ffe_min(main_idx) = -Inf;
ffe_max(main_idx) =  Inf;
% b_max=2.0 from build_variants was calibrated for the synthetic 2-tap channel.
% Real 802.3ck S-parameter channels after rx_gain normalisation can need
% DFE taps larger than 2.0 (especially backplane / high-IL cases).
% Using 3.5 keeps the projection within a conservative range while
% allowing the MMSE initialiser and NLMS updates to converge properly.
b_max_firbank = 3.5;
v_base.theta_min = [ffe_min; -b_max_firbank*ones(L,1)];
v_base.theta_max = [ffe_max;  b_max_firbank*ones(L,1)];
end

function cases = local_select_cases(catalog, max_cases)
is_thru = strcmpi({catalog.role}, 'thru') | contains(lower({catalog.case_id}), 'thru');
if any(is_thru)
    catalog = catalog(is_thru);
end
want_groups = {'C2M','C2C','Backplane','Cable'};
cases = struct([]);
for gi = 1:numel(want_groups)
    idx = find(strcmpi({catalog.group}, want_groups{gi}));
    if isempty(idx), continue; end
    [~,ord] = sort([catalog(idx).insertion_loss_db]);
    idx = idx(ord);
    pick = unique(round(linspace(1,numel(idx),min(3,numel(idx)))));
    for k = pick
        if isempty(cases)
            cases = catalog(idx(k));
        else
            cases(end+1) = catalog(idx(k)); %#ok<AGROW>
        end
        if numel(cases) >= max_cases, return; end
    end
end
if isempty(cases)
    cases = catalog(1:min(max_cases,numel(catalog)));
end
end

function [dh, diag] = local_chen_reference(r, h_eff_rx, cfg)
% Chen-style fixed reference: design FFE/DFE from the same effective pulse
% seen by the receiver, including Tx FFE and AGC gain.  The previous code
% used the raw channel only, so this baseline was optimizing the wrong pulse.
[w_ffe, w_dfe, D_eq, g_eq] = local_design_pulse_reference(h_eff_rx, cfg.Nf, cfg.Nb, cfg.D);
[dh, z] = local_fixed_ffedfe(r, w_ffe, w_dfe, D_eq, cfg.A);
diag = struct('z_hist', z, 'w_ffe', w_ffe, 'w_dfe', w_dfe, ...
    'D', D_eq, 'g_eq', g_eq, 'h_eff_rx', h_eff_rx(:));
end

function [w_ffe, w_dfe, D_eq, g_best] = local_design_pulse_reference(h, Kf, Lb, D_hint)
h = h(:).';
M = numel(h);
Lconv = Kf + M - 1;
H = zeros(Lconv, Kf);
for k = 1:Kf
    H(k:k+M-1, k) = h(:);
end

lambda = 1e-4;
D_candidates = 0:(Lconv-1);
best_cost = inf;
w_ffe = zeros(Kf,1);
w_dfe = zeros(Lb,1);
D_eq = max(0, min(D_hint, Lconv-1));
g_best = zeros(1,Lconv);
for D = D_candidates
    e = zeros(Lconv,1);
    e(D+1) = 1;
    w = (H.'*H + lambda*eye(Kf)) \ (H.'*e);
    g = conv(w, h);
    main = g(D+1);
    if abs(main) < 1e-8
        continue;
    end
    % Normalize the equalized pulse so the PAM4 slicer thresholds remain
    % valid.  Chen/ePDA optimizes eye opening after equalization; without
    % this normalization a good pulse shape can still slice at the wrong
    % amplitude.
    if main < 0
        w = -w;
        g = -g;
        main = -main;
    end
    w = w / main;
    g = g / main;

    pre = g(1:D);
    post_start = D + 2;
    post_stop = min(D + 1 + Lb, numel(g));
    tail = [];
    if post_stop + 1 <= numel(g)
        tail = g(post_stop+1:end);
    end
    cost = sum(pre.^2) + sum(tail.^2) + 1e-3*sum(w(:).^2) + 1e-3*abs(D-D_hint);
    if cost < best_cost
        best_cost = cost;
        D_eq = D;
        w_ffe = w(:);
        dfe = g(post_start:post_stop);
        if numel(dfe) < Lb
            dfe(end+1:Lb) = 0;
        end
        w_dfe = dfe(:);
        g_best = g(:).';
    end
end
end

function [dh, z_hist] = local_fixed_ffedfe(r, w_ffe, w_dfe, D, A)
N = numel(r);
y_ffe = filter(w_ffe, 1, [r(:); zeros(numel(w_ffe)-1,1)]);
y_ffe = y_ffe(1:N);
Lb = numel(w_dfe);
dec_buf = zeros(Lb,1);
dh = zeros(N,1);
z_hist = zeros(N,1);
for n = 1:N
    z = y_ffe(n) - w_dfe(:).' * dec_buf;
    s = pam_slice_scalar(z, A);
    z_hist(n) = z;
    m = n - D;
    if m >= 1 && m <= N
        dh(m) = s;
    end
    if Lb > 0
        dec_buf = [s; dec_buf(1:end-1)];
    end
end
end

function [dh, diag] = local_extratrees_hmm_reference(r, d, cfg)
% Lightweight Cui-style proxy: feature classifier -> HMM/Viterbi smoothing.
X = local_cui_features(r);
y = local_aligned_labels(d, cfg, numel(r));
train_mask = y.valid & y.m <= cfg.trainLen;
test_classes = ones(numel(r),1);

try
    if exist('fitcensemble','file') == 2 && nnz(train_mask) > 100
        mdl = fitcensemble(X(train_mask,:), y.cls(train_mask), ...
            'Method','Bag', 'NumLearningCycles',30);
        [~, score] = predict(mdl, X);
        cls = mdl.ClassNames;
        Pemit = local_scores_to_emit(score, cls, cfg.M);
        kind = 'fitcensemble_bag';
    else
        [Pemit, kind] = local_centroid_emit(X, y.cls, train_mask, cfg.M);
    end
catch
    [Pemit, kind] = local_centroid_emit(X, y.cls, train_mask, cfg.M);
end

[logA, log_pi0] = hmm_train_pam4(y.cls(train_mask), cfg.M, 1.0);
test_classes = hmm_viterbi_pam4(Pemit, logA, log_pi0);
A = cfg.A(:);
sample_hat = A(max(1,min(cfg.M,test_classes)));
dh = zeros(numel(d),1);
for n = 1:numel(sample_hat)
    m = n - cfg.D;
    if m >= 1 && m <= numel(d)
        dh(m) = sample_hat(n);
    end
end
diag = struct('z_hist', sample_hat(:), 'classifier_kind', kind);
end

function X = local_cui_features(r)
r = r(:);
N = numel(r);
X = zeros(N,5);
for n = 1:N
    rn = r(n);
    rm1 = 0; if n >= 2, rm1 = r(n-1); end
    rm2 = 0; if n >= 3, rm2 = r(n-2); end
    rm3 = 0; if n >= 4, rm3 = r(n-3); end
    X(n,:) = [rn rm1 rm2 rm3 rn-rm1];
end
end

function y = local_aligned_labels(d, cfg, Nr)
m = (1:Nr).' - cfg.D;
valid = m >= 1 & m <= numel(d);
cls = ones(Nr,1);
A = cfg.A(:).';
for n = find(valid).'
    [~, cls(n)] = min(abs(d(m(n)) - A));
end
y = struct('m', m, 'valid', valid, 'cls', cls);
end

function P = local_scores_to_emit(score, cls, M)
P = zeros(size(score,1), M);
if iscell(cls), cls = str2double(cls); end
for k = 1:numel(cls)
    mi = round(cls(k));
    if mi >= 1 && mi <= M
        P(:,mi) = score(:,k);
    end
end
P = max(P, 1e-12);
P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);
end

function [P, kind] = local_centroid_emit(X, cls, train_mask, M)
kind = 'nearest_centroid';
C = zeros(M, size(X,2));
for m = 1:M
    idx = train_mask & cls == m;
    if any(idx), C(m,:) = mean(X(idx,:),1); else, C(m,:) = mean(X(train_mask,:),1); end
end
D = zeros(size(X,1), M);
for m = 1:M
    E = X - C(m,:);
    D(:,m) = sum(E.*E,2);
end
sig2 = max(mean(D(:))/4, 1e-6);
P = exp(-D/(2*sig2));
P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);
end

function h2 = local_static_h2_states(h2_mid)
spread = max(0.05, 0.25*abs(h2_mid));
h2 = [h2_mid-spread, h2_mid, h2_mid+spread];
end

function h_bank = local_static_h_bank(h)
h = h(:);
scale = [0.92 1.00 1.08];
h_bank = cell(1,3);
for s = 1:3
    hs = h;
    if numel(hs) >= 2
        hs(2:end) = scale(s) * hs(2:end);
    end
    h_bank{s} = hs;
end
end

function d = local_pam4(cfg)
sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
d = cfg.A(sym_idx).';
d = d(:);
end

function taps = local_tx_ffe_taps()
taps = [1; -0.08; 0.03];
end

function h_eff = local_effective_channel(h, tx_ffe)
h_eff = conv(tx_ffe(:), h(:));
end

function y = local_apply_tx_ffe(d, taps)
y = filter(taps(:), 1, d(:));
pow_in = rms(d);
pow_out = rms(y);
if pow_out > eps
    y = y * (pow_in / pow_out);
end
end

function xt = local_xtalk_like(d, target_rms)
a = cfg_like_symbols(numel(d));
h = [0; 0.65; -0.25; 0.10];
xt = filter(h, 1, a);
xt = xt / max(rms(xt), eps) * target_rms;
end

function a = cfg_like_symbols(N)
A = [-3 -1 1 3];
a = A(randi([1 4], N, 1)).';
a = a(:);
end

function [r, sigma2, rx_gain] = local_add_receiver_noise(r_clean, tx_ref, cfg, mode)
rx_gain = 1;
if strcmpi(mode, 'measured')
    [r, sigma2] = add_noise_dispatch(r_clean, cfg);
    return;
end
if any(strcmpi(mode, {'clean','rx','channel','received'}))
    ref_pow = mean(r_clean(:).^2);
else
    ref_pow = mean(tx_ref(:).^2);
end
sigma2 = ref_pow / (10^(cfg.SNRdB/10));
r = r_clean(:) + sqrt(sigma2) * randn(size(r_clean(:)));
target_rms = rms(tx_ref(:));
obs_rms = rms(r);
if obs_rms > eps
    rx_gain = target_rms / obs_rms;
    r = r * rx_gain;
end
end

function dh = local_noeq(r, cfg)
dh = zeros(cfg.Nsym,1);
for n = 1:min(numel(r), cfg.Nsym)
    m = n - cfg.D;
    if m >= 1 && m <= cfg.Nsym
        dh(m) = pam_slice_scalar(r(n), cfg.A);
    end
end
end

function dh = local_shadow_output_select(y_prop, y_shadow, cfg)
N = min([numel(y_prop), numel(y_shadow), cfg.Nsym]);
dh = zeros(cfg.Nsym,1);
for n = 1:N
    m = n - cfg.D;
    if m < 1 || m > cfg.Nsym, continue; end
    yp = y_prop(n);
    ys = y_shadow(n);
    sp = pam_slice_scalar(yp, cfg.A);
    ss = pam_slice_scalar(ys, cfg.A);
    if local_pam_margin(ys, cfg.A) > local_pam_margin(yp, cfg.A)
        dh(m) = ss;
    else
        dh(m) = sp;
    end
end
end

function [dh_alg1, diag_alg1] = local_algorithm1_endogenous(r, d, cfg, base, sigma2_eff)
% Algorithm 1 in the paper is the endogenous-aware single-bank recursion.
% Keep this wrapper aligned with Block-C so 802.3ck-style Block-B figures do
% not accidentally use the legacy projected single-bank implementation.
aware_opts = local_algorithm1_aware_opts(cfg.SNRdB);
[y_alg1, dh_alg1, ~, ~, diag_alg1] = ...
    dfe_endogenous_smnlms_unified_x(r, d, cfg, base, sigma2_eff, aware_opts);
diag_alg1.z_hist = y_alg1(:);
diag_alg1.y_hist = y_alg1(:);
end

function aware_opts = local_algorithm1_aware_opts(snr_db)
aware_opts = struct('lambda_margin',0.16,'lambda_dd',0.00, ...
    'lambda_residual',0.06,'gamma_max_scale',1.20, ...
    'gamma_base_low',0.48,'gamma_base_high',0.64, ...
    'noise_ref',0.80,'beta_min_scale',0.94, ...
    'beta_boost_low',1.55,'beta_boost_high',1.32, ...
    'sign_mix_max',0.16, ...
    'lambda_sign',0.65,'sign_gamma_ref',0.18, ...
    'ema_alpha',0.98,'update_mode','smnlms', ...
    'use_shadow_smnlms_select',true,'shadow_margin_guard',0.0);
if snr_db >= 18 && snr_db <= 21
    aware_opts.lambda_margin = 0.12;
    aware_opts.lambda_residual = 0.045;
    aware_opts.gamma_base_low = 0.44;
    aware_opts.gamma_base_high = 0.58;
    aware_opts.beta_min_scale = 0.98;
    aware_opts.beta_boost_low = 1.62;
    aware_opts.beta_boost_high = 1.40;
    aware_opts.sign_mix_max = 0.30;
    aware_opts.lambda_sign = 0.90;
    if snr_db == 20
        aware_opts.sign_mix_max = 0.62;
        aware_opts.lambda_sign = 1.40;
        aware_opts.beta_boost_low = 1.72;
        aware_opts.beta_boost_high = 1.48;
    end
end
if snr_db >= 27
    aware_opts.lambda_margin = 0.10;
    aware_opts.lambda_residual = 0.035;
    aware_opts.gamma_base_low = 0.42;
    aware_opts.gamma_base_high = 0.55;
    aware_opts.beta_min_scale = 0.98;
    aware_opts.beta_boost_low = 1.62;
    aware_opts.beta_boost_high = 1.42;
    aware_opts.sign_mix_max = 0.0;
    aware_opts.lambda_sign = 0.0;
end
end

function margin = local_pam_margin(y, A)
A = sort(A(:));
thr = 0.5*(A(1:end-1) + A(2:end));
if isempty(thr)
    margin = inf;
else
    margin = min(abs(y - thr));
end
end

function y = local_diag_output(diag, r, cfg)
if isstruct(diag) && isfield(diag, 'y_hist')
    y = diag.y_hist(:);
elseif isstruct(diag) && isfield(diag, 'z_hist')
    y = diag.z_hist(:);
else
    y = r(:);
end
if numel(y) < cfg.Nsym
    y(end+1:cfg.Nsym) = 0;
end
end

function markov = local_run_markov_cases(cases, cfg_p, v_base, msb_params, vars, base, snr_list, Nt, opt)
sel = local_select_markov_state_cases(cases);
tx_ffe = local_tx_ffe_taps();

% Use three same-interface physical channels directly as Markov states.
% For the main paper benchmark we prefer C2M low/mid/high loss states:
% this models a receiver tracking realistic link-state variation inside one
% deployment family.  Mixing C2C, backplane and cable channels is a useful
% stress test, but it produces a cross-domain jump that is too severe for a
% pre-FEC main result.
% The tail-scaled approach (local_markov_tail_scaled_bank) had two problems:
%   (a) tail_scale=4.0 produced postcursors exceeding b_max=2.0, so bank 3
%       could never converge, corrupting FIR prediction scores for all states.
%   (b) All 3 "states" were derived from a single base channel, which is not
%       representative of real channel diversity in 802.3ck deployments.
h_phys = cellfun(@(c) c.symbol_taps(:), num2cell(sel), 'UniformOutput', false);
h_bank = cellfun(@(h) local_effective_channel(h, tx_ffe), h_phys, 'UniformOutput', false);
h2     = cellfun(@(h) h(min(2,numel(h))), h_bank);

msb_params_m = msb_params;
msb_params_m.train_all_prefix  = 0;
% Keep hmm_temp at the default 0.05 from default_msb_params_v69.
% The previous hard-coded override of 0.02 was too sharp: when FIR
% prediction scores are noisy (e.g. during the early DD phase), a very
% small tau makes the HMM over-confident on the wrong state and unable
% to recover.  The default 0.05 provides more robust soft discrimination.
msb_params_m.oracle_train_only = true;
msb_params_m.score_mode        = 'channel_likelihood';
msb_params_m.init_from_hbank   = true;
msb_params_m.bank_update_rule  = 'smnlms';
msb_params_m.smnlms            = base.smnlms;
msb_params_m.adaptive_threshold = true;
msb_params_m.threshold_mu = 2e-3;
msb_params_m.threshold_clip_margin = 0.95;
msb_params_m.eb_gate.use_nominal_fallback_output = false;
msb_params_m.eb_gate.nominal_fallback_entropy = 0.32;
msb_params_m.eb_gate.nominal_state = 2;
if ~isempty(opt.markov_smnlms_tau)
    msb_params_m.smnlms.tau = opt.markov_smnlms_tau;
end
if ~isempty(opt.markov_smnlms_beta)
    msb_params_m.smnlms.beta = opt.markov_smnlms_beta;
end
% Markov: disable beta annealing to preserve fast re-tracking after state switches
msb_params_m.use_beta_anneal   = false;
% Adaptive tau and transition gate are useful tuning knobs, but are not
% forced on by default because C2M score spreads can be noisy in the medium
% switching regime.
msb_params_m.use_adaptive_tau  = opt.markov_use_adaptive_tau;
msb_params_m.tau_calib         = opt.markov_tau_calib;
msb_params_m.tau_min           = 1e-3;
msb_params_m.tau_max           = 0.5;
msb_params_m.tau_ema_alpha     = 0.99;
msb_params_m.use_transition_gate        = opt.markov_use_transition_gate;
msb_params_m.trans_gate_conf_threshold  = opt.markov_transition_gate_conf;
if isfield(cfg_p, 'markov_oracle_route') && cfg_p.markov_oracle_route
    msb_params_m.oracle_train_only = false;
end

Ps = struct();
Ps(1).name = 'slow';
Ps(1).P = [0.985 0.015 0; 0.0075 0.985 0.0075; 0 0.015 0.985];
Ps(2).name = 'medium';
Ps(2).P = [0.970 0.030 0; 0.0200 0.960 0.0200; 0 0.030 0.970];
Ps(3).name = 'fast';
Ps(3).P = [0.950 0.050 0; 0.0250 0.950 0.0250; 0 0.050 0.950];
Ps(4).name = 'jump';
Ps(4).P = [0.995 0.005 0; 0.0025 0.995 0.0025; 0 0.005 0.995];
if ischar(opt.markov_modes)
    mode_keep = {opt.markov_modes};
else
    mode_keep = opt.markov_modes;
end
Ps = Ps(ismember({Ps.name}, mode_keep));

markov = struct([]);
row = 0;
snr_ref = max(snr_list);
for pi = 1:numel(Ps)
    cfg_m = cfg_p;
    cfg_m.SNRdB = snr_ref;
    if ~isempty(opt.markov_nb), cfg_m.Nb = opt.markov_nb; end
    v_base_m = local_v_base(vars, cfg_m);
    if isempty(opt.markov_nsym)
        cfg_m.Nsym = max(cfg_m.Nsym, 80000);
    else
        cfg_m.Nsym = opt.markov_nsym;
    end
    if isempty(opt.markov_trainLen)
        cfg_m.trainLen = min(12000, floor(0.25*cfg_m.Nsym));
    else
        cfg_m.trainLen = min(opt.markov_trainLen, floor(0.25*cfg_m.Nsym));
    end
    cfg_m.markov.h2_states = h2;
    cfg_m.markov.P = Ps(pi).P;
    cfg_m.markov.init_state = 2;
    if isfield(cfg_m.markov,'fixed_state'), cfg_m.markov = rmfield(cfg_m.markov,'fixed_state'); end
    ber = zeros(Nt,3);
    eye_h = nan(Nt,3);
    eye_w = nan(Nt,3);
    trans_ber = nan(Nt,3);
    trans_excess_ber = nan(Nt,3);
    recovery = nan(Nt,3);
    acc = nan(Nt,1);
    update_rate = nan(Nt,1);
    posterior_entropy = nan(Nt,1);
    confidence_gap = nan(Nt,1);
    dd_bias_proxy = nan(Nt,1);
    dd_bias_dfe_proxy = nan(Nt,1);
    cross_state_memory = nan(Nt,1);
    for t = 1:Nt
        rng(1300000 + opt.seed_offset + 100*pi + t);
        d = local_pam4(cfg_m);
        tx = local_apply_tx_ffe(d, tx_ffe);
        state_seq = local_balanced_markov_state_seq(cfg_m.Nsym, cfg_m.trainLen, cfg_m.markov.P);
        [r_clean, ch_state] = local_channel_out_fir_state_seq(tx, h_phys, state_seq);
        [r, sigma2_m, rx_gain] = local_add_receiver_noise(r_clean, tx, cfg_m, opt.noise_reference);
        if opt.markov_twochain
            [r, sigma2_m] = local_apply_markov_twochain_disturbance( ...
                r, r_clean, state_seq, sigma2_m, opt, rx_gain);
        end
        h_bank_rx = cellfun(@(h) rx_gain*h, h_bank, 'UniformOutput', false);
        msb_params_trial_m = msb_params_m;
        msb_params_trial_m.sigma2 = sigma2_m * rx_gain^2;
        [dh_alg6, diag_alg6] = algorithm6_msb_firbank(r, d, cfg_m, v_base_m, msb_params_trial_m, h_bank_rx, ch_state.state);
        [dh_alg1, diag_alg1] = local_algorithm1_endogenous(r, d, cfg_m, base, msb_params_trial_m.sigma2);
        [dh_chen, diag_chen] = local_chen_reference(r, h_bank_rx{min(2,numel(h_bank_rx))}, cfg_m);
        ber(t,1) = ser_after_training_aligned(d, dh_alg6, cfg_m) / log2(cfg_m.M);
        ber(t,2) = ser_after_training_aligned(d, dh_alg1, cfg_m) / log2(cfg_m.M);
        ber(t,3) = ser_after_training_aligned(d, dh_chen, cfg_m) / log2(cfg_m.M);
        y6 = local_diag_output(diag_alg6, r, cfg_m);
        y1 = local_diag_output(diag_alg1, r, cfg_m);
        yc = local_diag_output(diag_chen, r, cfg_m);
        em6 = compute_eye_height_width_metrics(y6, d, cfg_m);
        em1 = compute_eye_height_width_metrics(y1, d, cfg_m);
        emc = compute_eye_height_width_metrics(yc, d, cfg_m);
        eye_h(t,:) = [em6.eye_height_5_95, em1.eye_height_5_95, emc.eye_height_5_95];
        eye_w(t,:) = [em6.eye_width_ui, em1.eye_width_ui, emc.eye_width_ui];
        tm6 = local_transition_metrics(d, dh_alg6, ch_state.state, cfg_m, diag_alg6.N_sep);
        tm1 = local_transition_metrics(d, dh_alg1, ch_state.state, cfg_m, diag_alg6.N_sep);
        tmc = local_transition_metrics(d, dh_chen, ch_state.state, cfg_m, diag_alg6.N_sep);
        trans_ber(t,1) = tm6.transition_window_BER;
        trans_ber(t,2) = tm1.transition_window_BER;
        trans_ber(t,3) = tmc.transition_window_BER;
        trans_excess_ber(t,1) = tm6.transition_excess_BER;
        trans_excess_ber(t,2) = tm1.transition_excess_BER;
        trans_excess_ber(t,3) = tmc.transition_excess_BER;
        recovery(t,1) = tm6.recovery_time_symbols;
        recovery(t,2) = tm1.recovery_time_symbols;
        recovery(t,3) = tmc.recovery_time_symbols;
        post = (cfg_m.trainLen + diag_alg6.N_sep + 1):cfg_m.Nsym;
        [~, best_acc] = msb_state_accuracy(diag_alg6.s_hat_hist, ch_state.state, post);
        acc(t) = best_acc;
        update_rate(t) = mean(diag_alg6.theta_update_hist(post), 'omitnan');
        posterior_entropy(t) = mean(diag_alg6.posterior_entropy_hist(post), 'omitnan');
        confidence_gap(t) = mean(diag_alg6.conf_ratio_hist(post), 'omitnan');
        dd_bias_proxy(t) = mean(diag_alg6.dd_bias_proxy_hist(post), 'omitnan');
        dd_bias_dfe_proxy(t) = mean(diag_alg6.dd_bias_dfe_proxy_hist(post), 'omitnan');
        cross_state_memory(t) = mean(diag_alg6.cross_state_memory_hist(post), 'omitnan');
    end
    row = row + 1;
    markov(row).case_id = ['Markov_' Ps(pi).name];
    markov(row).state_cases = {sel.case_id};
    if opt.markov_twochain
        markov(row).stress_model = 'same-interface 802.3ck C2M Markov states + independent disturbance chain';
    else
        markov(row).stress_model = 'same-interface 802.3ck C2M Markov states';
    end
    markov(row).SNRdB = snr_ref;
    markov(row).BER_algorithm6 = mean(ber(:,1));
    markov(row).BER_algorithm1 = mean(ber(:,2));
    markov(row).BER_chen_pulse_ref = mean(ber(:,3));
    markov(row).SER_algorithm6 = 2 * markov(row).BER_algorithm6;
    markov(row).SER_algorithm1 = 2 * markov(row).BER_algorithm1;
    markov(row).SER_chen_pulse_ref = 2 * markov(row).BER_chen_pulse_ref;
    markov(row).EyeHeight_algorithm6 = mean(eye_h(:,1),'omitnan');
    markov(row).EyeHeight_algorithm1 = mean(eye_h(:,2),'omitnan');
    markov(row).EyeHeight_chen_pulse_ref = mean(eye_h(:,3),'omitnan');
    markov(row).EyeWidth_algorithm6 = mean(eye_w(:,1),'omitnan');
    markov(row).EyeWidth_algorithm1 = mean(eye_w(:,2),'omitnan');
    markov(row).EyeWidth_chen_pulse_ref = mean(eye_w(:,3),'omitnan');
    markov(row).improvement_pct = 100 * (1 - markov(row).BER_algorithm6 / max(markov(row).BER_algorithm1, eps));
    markov(row).improvement_vs_chen_pct = 100 * (1 - ...
        markov(row).BER_algorithm6 / max(markov(row).BER_chen_pulse_ref, eps));
    markov(row).transition_window_BER_algorithm6 = mean(trans_ber(:,1),'omitnan');
    markov(row).transition_window_BER_algorithm1 = mean(trans_ber(:,2),'omitnan');
    markov(row).transition_window_BER_chen_pulse_ref = mean(trans_ber(:,3),'omitnan');
    markov(row).transition_window_improvement_pct = 100 * (1 - ...
        markov(row).transition_window_BER_algorithm6 / max(markov(row).transition_window_BER_algorithm1, eps));
    markov(row).transition_excess_BER_algorithm6 = mean(trans_excess_ber(:,1),'omitnan');
    markov(row).transition_excess_BER_algorithm1 = mean(trans_excess_ber(:,2),'omitnan');
    markov(row).transition_excess_delta_BER = ...
        markov(row).transition_excess_BER_algorithm1 - markov(row).transition_excess_BER_algorithm6;
    % In clean pre-FEC regimes the post-transition excess BER can be nearly
    % zero for both receivers.  Percent ratios are then numerically unstable
    % and not meaningful; report n/a unless the baseline burst penalty is
    % large enough to be interpretable.
    excess_floor = 1e-4;
    if markov(row).transition_excess_BER_algorithm1 <= excess_floor && ...
            markov(row).transition_excess_BER_algorithm6 <= excess_floor
        markov(row).transition_excess_improvement_pct = 0;
    elseif markov(row).transition_excess_BER_algorithm1 <= excess_floor
        markov(row).transition_excess_improvement_pct = NaN;
    else
        markov(row).transition_excess_improvement_pct = 100 * (1 - ...
            markov(row).transition_excess_BER_algorithm6 / markov(row).transition_excess_BER_algorithm1);
    end
    markov(row).recovery_time_algorithm6 = mean(recovery(:,1),'omitnan');
    markov(row).recovery_time_algorithm1 = mean(recovery(:,2),'omitnan');
    markov(row).recovery_time_chen_pulse_ref = mean(recovery(:,3),'omitnan');
    if markov(row).recovery_time_algorithm1 <= eps && markov(row).recovery_time_algorithm6 <= eps
        markov(row).recovery_time_improvement_pct = 0;
    else
        markov(row).recovery_time_improvement_pct = 100 * (1 - ...
            markov(row).recovery_time_algorithm6 / max(markov(row).recovery_time_algorithm1, eps));
    end
    markov(row).state_accuracy = mean(acc,'omitnan');
    markov(row).wrong_routing_rate = 1 - markov(row).state_accuracy;
    markov(row).smnlms_update_rate = mean(update_rate,'omitnan');
    markov(row).hmm_posterior_entropy = mean(posterior_entropy,'omitnan');
    markov(row).hmm_confidence_gap = mean(confidence_gap,'omitnan');
    markov(row).dd_bias_proxy = mean(dd_bias_proxy,'omitnan');
    markov(row).dd_bias_dfe_proxy = mean(dd_bias_dfe_proxy,'omitnan');
    markov(row).cross_state_memory = mean(cross_state_memory,'omitnan');
    markov(row).P = Ps(pi).P;
    excess_str = local_pct_or_na(markov(row).transition_excess_improvement_pct);
    fprintf(['[8023ck_sparam] Markov %-6s SNR=%2d | Alg6 BER=%.3e, Alg1=%.3e, ' ...
        'Chen=%.3e, improve=%+.1f%%, vs Chen=%+.1f%%, trans improve=%+.1f%%, excess improve=%s, recovery improve=%+.1f%%, state acc=%5.2f%%\n'], ...
        Ps(pi).name, snr_ref, markov(row).BER_algorithm6, ...
        markov(row).BER_algorithm1, markov(row).BER_chen_pulse_ref, ...
        markov(row).improvement_pct, markov(row).improvement_vs_chen_pct, ...
        markov(row).transition_window_improvement_pct, ...
        excess_str, ...
        markov(row).recovery_time_improvement_pct, 100*markov(row).state_accuracy);
end
end

function sweep = local_run_markov_sweep_cases(cases, cfg_p, vars, base, v_base, msb_params, snr_list, Nt, p_stay_list, opt)
sel = local_select_markov_state_cases(cases);
tx_ffe = local_tx_ffe_taps();
h_phys = cellfun(@(c) c.symbol_taps(:), num2cell(sel), 'UniformOutput', false);
h_bank = cellfun(@(h) local_effective_channel(h, tx_ffe), h_phys, 'UniformOutput', false);
h2 = cellfun(@(h) h(min(2,numel(h))), h_bank);

methods = {'NLMS-DFE','SMNLMS-DFE','SM-sign-NLMS','Liu SS-LMS', ...
           'Chen pulse-ref','ExtraTrees-HMM','Algorithm 1','Proposed MSB'};
nM = numel(methods);
snr_ref = max(snr_list);

msb_params_m = msb_params;
msb_params_m.train_all_prefix = 0;
msb_params_m.oracle_train_only = true;
msb_params_m.score_mode = 'channel_likelihood';
msb_params_m.init_from_hbank = true;
msb_params_m.bank_update_rule = 'smnlms';
msb_params_m.smnlms = base.smnlms;
msb_params_m.adaptive_threshold = true;
msb_params_m.threshold_mu = 2e-3;
msb_params_m.threshold_clip_margin = 0.95;
if ~isempty(opt.markov_smnlms_tau)
    msb_params_m.smnlms.tau = opt.markov_smnlms_tau;
end
if ~isempty(opt.markov_smnlms_beta)
    msb_params_m.smnlms.beta = opt.markov_smnlms_beta;
end
msb_params_m.eb_gate = local_default_eb_gate();
msb_params_m.eb_gate.use_nominal_fallback_output = false;
msb_params_m.eb_gate.nominal_fallback_entropy = 0.32;
msb_params_m.eb_gate.nominal_state = 2;
% Disable beta annealing for Markov sweep: we need full step for re-tracking
msb_params_m.use_beta_anneal = false;
msb_params_m.use_adaptive_tau = opt.markov_use_adaptive_tau;
msb_params_m.tau_calib = opt.markov_tau_calib;
msb_params_m.tau_min = 1e-3;
msb_params_m.tau_max = 0.5;
msb_params_m.tau_ema_alpha = 0.99;
msb_params_m.use_transition_gate = opt.markov_use_transition_gate;
msb_params_m.trans_gate_conf_threshold = opt.markov_transition_gate_conf;

sweep = struct([]);
fprintf('[8023ck_sparam] Markov sweep: methods=%d, trials=%d, SNR=%d, Pstay=[%s], twochain=%d\n', ...
    nM, Nt, snr_ref, num2str(p_stay_list), opt.markov_twochain);

for pi = 1:numel(p_stay_list)
    pstay = p_stay_list(pi);
    P = local_three_state_P(pstay);
    cfg_m = cfg_p;
    cfg_m.SNRdB = snr_ref;
    if ~isempty(opt.markov_nb), cfg_m.Nb = opt.markov_nb; end
    v_base_m = local_v_base(vars, cfg_m);
    if isempty(opt.markov_nsym)
        cfg_m.Nsym = max(cfg_m.Nsym, 60000);
    else
        cfg_m.Nsym = opt.markov_nsym;
    end
    if isempty(opt.markov_trainLen)
        cfg_m.trainLen = min(12000, floor(0.25*cfg_m.Nsym));
    else
        cfg_m.trainLen = min(opt.markov_trainLen, floor(0.25*cfg_m.Nsym));
    end
    cfg_m.markov.h2_states = h2;
    cfg_m.markov.P = P;
    cfg_m.markov.init_state = 2;
    if isfield(cfg_m.markov,'fixed_state'), cfg_m.markov = rmfield(cfg_m.markov,'fixed_state'); end

    ber = nan(Nt, nM);
    acc = nan(Nt,1);
    trans_ber_prop = nan(Nt,1);
    trans_ber_chen = nan(Nt,1);
    trans_ber_alg1 = nan(Nt,1);
    recovery_prop = nan(Nt,1);
    recovery_chen = nan(Nt,1);
    recovery_alg1 = nan(Nt,1);
    update_rate = nan(Nt,1);
    posterior_entropy = nan(Nt,1);
    confidence_gap = nan(Nt,1);
    dd_bias_proxy = nan(Nt,1);
    dd_bias_dfe_proxy = nan(Nt,1);
    cross_state_memory = nan(Nt,1);
    for t = 1:Nt
        rng(1500000 + opt.seed_offset + round(1000000 * (1 - pstay)) + t);
        d = local_pam4(cfg_m);
        tx = local_apply_tx_ffe(d, tx_ffe);
        state_seq = local_balanced_markov_state_seq(cfg_m.Nsym, cfg_m.trainLen, P);
        [r_clean, ch_state] = local_channel_out_fir_state_seq(tx, h_phys, state_seq);
        [r, sigma2, rx_gain] = local_add_receiver_noise(r_clean, tx, cfg_m, opt.noise_reference);
        if opt.markov_twochain
            [r, sigma2] = local_apply_markov_twochain_disturbance( ...
                r, r_clean, state_seq, sigma2, opt, rx_gain);
        end
        h_bank_rx = cellfun(@(h) rx_gain*h, h_bank, 'UniformOutput', false);
        msb_params_trial = msb_params_m;
        msb_params_trial.sigma2 = sigma2 * rx_gain^2;

        [~, dh_nlms] = dfe_nlms_unified_x(r, d, cfg_m, base);
        [y_smn, dh_smn] = dfe_smnlms_unified_x(r, d, cfg_m, base, sigma2);
        [~, dh_sm] = dfe_smsign_nlms_unified_x(r, d, cfg_m, base, sigma2);
        cfg_liu = cfg_m;
        v_liu = local_v_base(vars, cfg_liu);
        opts_liu = struct('adaptive_threshold', true, 'update_ffe', false, ...
                          'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, ...
                          'use_projection', true);
        [~, dh_liu] = dfe_ss_lms_pam4(r, d, cfg_liu, v_liu, opts_liu);
        [dh_chen] = local_chen_reference(r, h_bank_rx{min(2,numel(h_bank_rx))}, cfg_m);
        [dh_cui] = local_extratrees_hmm_reference(r, d, cfg_m);
        [dh_alg1] = local_algorithm1_endogenous(r, d, cfg_m, base, msb_params_trial.sigma2);
        [dh_alg6, diag_alg6] = algorithm6_msb_firbank(r, d, cfg_m, v_base_m, ...
            msb_params_trial, h_bank_rx, ch_state.state);
        if opt.markov_use_smnlms_shadow_output
            dh_alg6 = local_shadow_output_select(diag_alg6.y_hist, y_smn, cfg_m);
        end

        dhs = {dh_nlms, dh_smn, dh_sm, dh_liu, dh_chen, dh_cui, dh_alg1, dh_alg6};
        for mi = 1:nM
            ber(t,mi) = ser_after_training_aligned(d, dhs{mi}, cfg_m) / log2(cfg_m.M);
        end
        post = (cfg_m.trainLen + diag_alg6.N_sep + 1):cfg_m.Nsym;
        [~, best_acc] = msb_state_accuracy(diag_alg6.s_hat_hist, ch_state.state, post);
        acc(t) = best_acc;
        tm_prop = local_transition_metrics(d, dh_alg6, ch_state.state, cfg_m, diag_alg6.N_sep);
        tm_chen = local_transition_metrics(d, dh_chen, ch_state.state, cfg_m, diag_alg6.N_sep);
        tm_alg1 = local_transition_metrics(d, dh_alg1, ch_state.state, cfg_m, diag_alg6.N_sep);
        trans_ber_prop(t) = tm_prop.transition_window_BER;
        trans_ber_chen(t) = tm_chen.transition_window_BER;
        trans_ber_alg1(t) = tm_alg1.transition_window_BER;
        recovery_prop(t) = tm_prop.recovery_time_symbols;
        recovery_chen(t) = tm_chen.recovery_time_symbols;
        recovery_alg1(t) = tm_alg1.recovery_time_symbols;
        update_rate(t) = mean(diag_alg6.theta_update_hist(post), 'omitnan');
        posterior_entropy(t) = mean(diag_alg6.posterior_entropy_hist(post), 'omitnan');
        confidence_gap(t) = mean(diag_alg6.conf_ratio_hist(post), 'omitnan');
        dd_bias_proxy(t) = mean(diag_alg6.dd_bias_proxy_hist(post), 'omitnan');
        dd_bias_dfe_proxy(t) = mean(diag_alg6.dd_bias_dfe_proxy_hist(post), 'omitnan');
        cross_state_memory(t) = mean(diag_alg6.cross_state_memory_hist(post), 'omitnan');
    end

    sweep(pi).case_id = sprintf('Pstay_%.3f', pstay);
    sweep(pi).Pstay = pstay;
    sweep(pi).mean_dwell_symbols = 1 / max(1-pstay, eps);
    sweep(pi).SNRdB = snr_ref;
    sweep(pi).methods = methods;
    sweep(pi).BER = mean(ber,1,'omitnan');
    sweep(pi).SER = sweep(pi).BER * log2(cfg_m.M);
    sweep(pi).state_accuracy = mean(acc,'omitnan');
    sweep(pi).wrong_routing_rate = 1 - sweep(pi).state_accuracy;
    sweep(pi).transition_window_BER_proposed = mean(trans_ber_prop,'omitnan');
    sweep(pi).transition_window_BER_chen = mean(trans_ber_chen,'omitnan');
    sweep(pi).transition_window_BER_alg1 = mean(trans_ber_alg1,'omitnan');
    sweep(pi).transition_improvement_vs_chen_pct = 100 * (1 - ...
        sweep(pi).transition_window_BER_proposed / max(sweep(pi).transition_window_BER_chen, eps));
    sweep(pi).transition_improvement_vs_alg1_pct = 100 * (1 - ...
        sweep(pi).transition_window_BER_proposed / max(sweep(pi).transition_window_BER_alg1, eps));
    sweep(pi).recovery_time_proposed = mean(recovery_prop,'omitnan');
    sweep(pi).recovery_time_chen = mean(recovery_chen,'omitnan');
    sweep(pi).recovery_time_alg1 = mean(recovery_alg1,'omitnan');
    sweep(pi).recovery_improvement_vs_chen_pct = 100 * (1 - ...
        sweep(pi).recovery_time_proposed / max(sweep(pi).recovery_time_chen, eps));
    sweep(pi).recovery_improvement_vs_alg1_pct = 100 * (1 - ...
        sweep(pi).recovery_time_proposed / max(sweep(pi).recovery_time_alg1, eps));
    sweep(pi).smnlms_update_rate = mean(update_rate,'omitnan');
    sweep(pi).hmm_posterior_entropy = mean(posterior_entropy,'omitnan');
    sweep(pi).hmm_confidence_gap = mean(confidence_gap,'omitnan');
    sweep(pi).dd_bias_proxy = mean(dd_bias_proxy,'omitnan');
    sweep(pi).dd_bias_dfe_proxy = mean(dd_bias_dfe_proxy,'omitnan');
    sweep(pi).cross_state_memory = mean(cross_state_memory,'omitnan');
    sweep(pi).state_cases = {sel.case_id};
    idx_prop = find(strcmp(methods,'Proposed MSB'),1);
    idx_chen = find(strcmp(methods,'Chen pulse-ref'),1);
    idx_alg1 = find(strcmp(methods,'Algorithm 1'),1);
    sweep(pi).improvement_vs_chen_pct = 100 * (1 - sweep(pi).BER(idx_prop) / max(sweep(pi).BER(idx_chen), eps));
    sweep(pi).improvement_vs_alg1_pct = 100 * (1 - sweep(pi).BER(idx_prop) / max(sweep(pi).BER(idx_alg1), eps));
    [best_ber, best_idx] = min(sweep(pi).BER);
    sweep(pi).best_method = methods{best_idx};
    sweep(pi).best_BER = best_ber;

    fprintf(['[8023ck_sparam] Sweep Pstay=%.3f dwell~%.0f | Prop=%.3e, Chen=%.3e, ' ...
        'Alg1=%.3e, vsChen=%+.1f%%, vsAlg1=%+.1f%%, acc=%5.2f%%, ' ...
        'transChen=%+.1f%%, upd=%4.1f%%, H=%.2f, BcDFE=%.2e, best=%s\n'], ...
        pstay, sweep(pi).mean_dwell_symbols, sweep(pi).BER(idx_prop), ...
        sweep(pi).BER(idx_chen), sweep(pi).BER(idx_alg1), ...
        sweep(pi).improvement_vs_chen_pct, sweep(pi).improvement_vs_alg1_pct, ...
        100*sweep(pi).state_accuracy, sweep(pi).transition_improvement_vs_chen_pct, ...
        100*sweep(pi).smnlms_update_rate, ...
        sweep(pi).hmm_posterior_entropy, sweep(pi).dd_bias_dfe_proxy, sweep(pi).best_method);
end
end

function [r2, sigma2_eff] = local_apply_markov_twochain_disturbance(r, r_clean, state_seq, sigma2, opt, rx_gain)
% Independent disturbance chain for the 802.3ck application benchmark.  It
% mirrors the two-chain MJS idea without changing the public S-parameter
% channel states: chain 1 is channel/ISI, chain 2 is reliability/noise.
%
% IMPORTANT: local_add_receiver_noise returns r in the receiver-normalized
% domain: r = rx_gain*(r_clean + noise).  The disturbance chain must operate
% in the same domain.  Otherwise base_noise = r-r_clean accidentally includes
% the signal term (rx_gain-1)*r_clean, creating a huge endogenous distortion
% floor that does not improve with SNR.
N = numel(r);
if nargin < 6 || isempty(rx_gain)
    rx_gain = 1;
end
clean_rx = rx_gain * r_clean(:);
P2 = [0.975 0.025; 0.100 0.900];
q = ones(N,1);
for n = 2:N
    q(n) = sample_discrete(P2(q(n-1),:), 2);
end
noise_scale = opt.markov_twochain_noise_scale(:).';
imp_prob = opt.markov_twochain_imp_prob(:).';
if numel(noise_scale) < 2, noise_scale(2) = noise_scale(1); end
if numel(imp_prob) < 2, imp_prob(2) = imp_prob(1); end
base_noise = r(:) - clean_rx(:);
dist_noise = zeros(N,1);
sigma_acc = 0;
for n = 1:N
    qq = max(1, min(2, q(n)));
    sc = noise_scale(qq);
    dist_noise(n) = sc * base_noise(n);
    sigma_acc = sigma_acc + sigma2 * sc^2;
    if rand < imp_prob(qq)
        dist_noise(n) = dist_noise(n) + ...
            rx_gain * opt.markov_twochain_imp_alpha * sqrt(max(sigma2,eps)) * sign(randn);
    end
end
r2 = clean_rx(:) + dist_noise;
sigma2_eff = sigma_acc / max(N,1);
end

function P = local_three_state_P(pstay)
pstay = min(max(pstay, 0), 0.999999);
q = 1 - pstay;
P = [pstay q 0; q/2 pstay q/2; 0 q pstay];
P = bsxfun(@rdivide, P, sum(P,2));
end

function g = local_default_eb_gate()
g = struct();
g.enabled = true;
g.lambda_entropy = 1.0;
g.lambda_cross = 3.0;
g.lambda_confidence = 0.5;
g.gamma_max_scale = 3.0;
g.beta_min_scale = 0.35;
g.use_fast_reroute = true;
g.reroute_entropy = 0.33;
g.reroute_conf_gap = 0.55;
g.reroute_pi_reset = 0.75;
g.use_decision_reliability_route = false;
g.decision_reliability_weight = 0.15;
g.use_output_reliability_select = false;
g.output_select_entropy = 0.25;
g.output_select_margin = 0.0;
g.use_nominal_fallback_output = false;
g.nominal_fallback_entropy = 0.32;
g.nominal_state = 2;
end

function s = local_pct_or_na(x)
if ~isfinite(x)
    s = 'n/a';
else
    s = sprintf('%+.1f%%', x);
end
end

function sel = local_select_markov_state_cases(cases)
same_group_order = {'C2M','C2C','Cable','Backplane'};
for gi = 1:numel(same_group_order)
    idxg = find(strcmpi({cases.group}, same_group_order{gi}));
    if numel(idxg) >= 3
        [~, ord] = sort([cases(idxg).insertion_loss_db]);
        idxg = idxg(ord);
        pick = unique(round(linspace(1, numel(idxg), 3)));
        if numel(pick) == 3
            sel = cases(idxg(pick));
            fprintf('[8023ck_sparam] Markov states (%s): %s | %s | %s\n', ...
                same_group_order{gi}, sel(1).case_id, sel(2).case_id, sel(3).case_id);
            return;
        end
    end
end

tx_ffe = local_tx_ffe_taps();
F = zeros(numel(cases), 8);
for i = 1:numel(cases)
    h = local_effective_channel(cases(i).symbol_taps, tx_ffe);
    h = h(:);
    if numel(h) < 9, h(end+1:9) = 0; end
    if norm(h) > eps, h = h / norm(h); end
    F(i,:) = h(2:9).';
end
best_score = -inf;
idx = [1 2 min(3,numel(cases))];
for a = 1:numel(cases)-2
    for b = a+1:numel(cases)-1
        for c = b+1:numel(cases)
            score = norm(F(a,:)-F(b,:)) + norm(F(a,:)-F(c,:)) + norm(F(b,:)-F(c,:));
            % Prefer not choosing three nearly identical group labels when alternatives exist.
            if numel(unique({cases([a b c]).group})) >= 2
                score = score + 0.25;
            end
            if score > best_score
                best_score = score;
                idx = [a b c];
            end
        end
    end
end
sel = cases(idx);
fprintf('[8023ck_sparam] Markov states: %s | %s | %s\n', ...
    sel(1).case_id, sel(2).case_id, sel(3).case_id);
end

function h_bank = local_markov_tail_scaled_bank(base_h, tx_ffe)
base = local_effective_channel(base_h, tx_ffe);
base = base(:);
if numel(base) < 9, base(end+1:9) = 0; end
tail_scale = [0.40 1.00 2.00];
h_bank = cell(1,3);
for s = 1:3
    h = base;
    h(2:end) = tail_scale(s) * h(2:end);
    h_bank{s} = h;
end
end

function idx = local_find_case(names, candidates)
idx = 0;
for k = 1:numel(candidates)
    hit = find(strcmp(names, candidates{k}), 1);
    if ~isempty(hit)
        idx = hit;
        return;
    end
end
end

function state_seq = local_balanced_markov_state_seq(N, trainLen, P)
S = size(P,1);
state_seq = ones(N,1);
seg = floor(trainLen / S);
for s = 1:S
    a = (s-1)*seg + 1;
    b = min(trainLen, s*seg);
    state_seq(a:b) = s;
end
if S*seg < trainLen
    state_seq(S*seg+1:trainLen) = S;
end
state_seq(trainLen+1) = min(2,S);
for n = trainLen+2:N
    prev = state_seq(n-1);
    state_seq(n) = sample_discrete(P(prev,:));
end
end

function [r_clean, ch_state] = local_channel_out_fir_state_seq(d, h_bank, state_seq)
N = numel(d);
r_clean = zeros(N,1);
maxL = max(cellfun(@numel, h_bank));
H = zeros(N, maxL);
for n = 1:N
    h = h_bank{state_seq(n)}(:);
    H(n,1:numel(h)) = h(:).';
    acc = 0;
    for k = 1:numel(h)
        m = n-k+1;
        if m >= 1
            acc = acc + h(k)*d(m);
        end
    end
    r_clean(n) = acc;
end
ch_state = struct('state', state_seq(:), 'h', H, 'h2', H(:,min(2,maxL)), 'h_bank', {h_bank});
end

function m = local_transition_metrics(d, d_hat, state_seq, cfg, N_sep)
W = 16;
rollW = 16;
guard = 32;
start_idx = cfg.trainLen + N_sep + 1;
N = min([numel(d), numel(d_hat), numel(state_seq)]);
state_seq = state_seq(:);
trans = find(state_seq(2:N) ~= state_seq(1:N-1)) + 1;
trans = trans(trans >= start_idx & trans + W - 1 <= N);
err = (d_hat(1:N) ~= d(1:N));

mask = false(N,1);
for k = 1:numel(trans)
    mask(trans(k):min(N, trans(k)+W-1)) = true;
end
idx = find(mask);
idx = idx(idx >= start_idx & idx <= N);
if isempty(idx)
    m.transition_window_BER = NaN;
else
    m.transition_window_BER = mean(err(idx)) / log2(cfg.M);
end

far_mask = true(N,1);
far_mask(1:max(0,start_idx-1)) = false;
for k = 1:numel(trans)
    a = max(start_idx, trans(k)-guard);
    b = min(N, trans(k)+W-1);
    far_mask(a:b) = false;
end
steady = mean(err(far_mask));
if ~isfinite(steady) || isnan(steady)
    steady = mean(err(start_idx:N));
end
m.steady_state_BER = steady / log2(cfg.M);
if isnan(m.transition_window_BER)
    m.transition_excess_BER = NaN;
else
    m.transition_excess_BER = max(0, m.transition_window_BER - m.steady_state_BER);
end
target = max(steady + 0.01, 1.25 * steady);
rt = nan(numel(trans),1);
for k = 1:numel(trans)
    for off = 0:W-1
        a = trans(k) + off;
        b = min(N, a + rollW - 1);
        if b > a && mean(err(a:b)) <= target
            rt(k) = off;
            break;
        end
    end
    if isnan(rt(k)), rt(k) = W; end
end
if isempty(rt)
    m.recovery_time_symbols = NaN;
else
    m.recovery_time_symbols = mean(rt,'omitnan');
end
end

function local_write_csv(pkg, save_dir)
if exist(save_dir,'dir') ~= 7, mkdir(save_dir); end
fn = fullfile(save_dir, 'ieee8023ck_sparam_benchmark_summary.csv');
fid = fopen(fn, 'w');
if fid < 0, return; end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'case_id,group,is_public_sparameter,SNRdB,insertion_loss_db,method,BER,SER,EyeHeight,EyeWidth,file\n');
for i = 1:numel(pkg.table)
    r = pkg.table(i);
    for m = 1:numel(r.methods)
        fprintf(fid, '%s,%s,%d,%.6g,%.6g,%s,%.12g,%.12g,%.12g,%.12g,%s\n', ...
            r.case_id, r.group, r.is_public_sparameter, r.SNRdB, ...
            r.insertion_loss_db, r.methods{m}, r.BER(m), r.SER(m), ...
            r.EyeHeight(m), r.EyeWidth(m), r.file);
    end
end
fprintf('[8023ck_sparam] Wrote %s\n', fn);

if isfield(pkg, 'markov') && ~isempty(pkg.markov)
    fnm = fullfile(save_dir, 'ieee8023ck_markov_tracking_summary.csv');
    fidm = fopen(fnm, 'w');
    if fidm >= 0
        cleanupm = onCleanup(@() fclose(fidm)); %#ok<NASGU>
        fprintf(fidm, ['case_id,stress_model,SNRdB,method,BER,SER,EyeHeight,EyeWidth,' ...
            'transition_window_BER,recovery_time_symbols,state_accuracy,wrong_routing_rate,' ...
            'state_cases\n']);
        for i = 1:numel(pkg.markov)
            r = pkg.markov(i);
            states = strjoin(r.state_cases, '|');
            mnames = {'Proposed MSB','Algorithm 1','Chen pulse-ref'};
            bers = [r.BER_algorithm6, r.BER_algorithm1, r.BER_chen_pulse_ref];
            sers = [r.SER_algorithm6, r.SER_algorithm1, r.SER_chen_pulse_ref];
            ehs = [r.EyeHeight_algorithm6, r.EyeHeight_algorithm1, r.EyeHeight_chen_pulse_ref];
            ews = [r.EyeWidth_algorithm6, r.EyeWidth_algorithm1, r.EyeWidth_chen_pulse_ref];
            twb = [r.transition_window_BER_algorithm6, r.transition_window_BER_algorithm1, r.transition_window_BER_chen_pulse_ref];
            rec = [r.recovery_time_algorithm6, r.recovery_time_algorithm1, r.recovery_time_chen_pulse_ref];
            for m = 1:numel(mnames)
                fprintf(fidm, '%s,%s,%.12g,%s,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%s\n', ...
                    r.case_id, r.stress_model, r.SNRdB, mnames{m}, ...
                    bers(m), sers(m), ehs(m), ews(m), twb(m), rec(m), ...
                    r.state_accuracy, r.wrong_routing_rate, states);
            end
        end
        fprintf('[8023ck_sparam] Wrote %s\n', fnm);
    end
end

if isfield(pkg, 'markov_sweep') && ~isempty(pkg.markov_sweep)
    fn2 = fullfile(save_dir, 'ieee8023ck_markov_sweep_summary.csv');
    fid2 = fopen(fn2, 'w');
    if fid2 >= 0
        cleanup2 = onCleanup(@() fclose(fid2)); %#ok<NASGU>
        fprintf(fid2, ['case_id,Pstay,mean_dwell_symbols,SNRdB,method,BER,SER,state_accuracy,wrong_routing_rate,' ...
            'transition_window_BER_proposed,transition_window_BER_chen,transition_window_BER_alg1,' ...
            'transition_improvement_vs_chen_pct,transition_improvement_vs_alg1_pct,' ...
            'recovery_time_proposed,recovery_time_chen,recovery_time_alg1,' ...
            'recovery_improvement_vs_chen_pct,recovery_improvement_vs_alg1_pct,' ...
            'smnlms_update_rate,hmm_posterior_entropy,hmm_confidence_gap,dd_bias_proxy,dd_bias_dfe_proxy,' ...
            'cross_state_memory,improvement_vs_chen_pct,improvement_vs_alg1_pct,best_method,state_cases\n']);
        for i = 1:numel(pkg.markov_sweep)
            r = pkg.markov_sweep(i);
            states = strjoin(r.state_cases, '|');
            for m = 1:numel(r.methods)
                fprintf(fid2, ['%s,%.12g,%.12g,%.12g,%s,%.12g,%.12g,%.12g,%.12g,' ...
                    '%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,' ...
                    '%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%s,%s\n'], ...
                    r.case_id, r.Pstay, r.mean_dwell_symbols, r.SNRdB, ...
                    r.methods{m}, r.BER(m), r.SER(m), r.state_accuracy, ...
                    r.wrong_routing_rate, ...
                    r.transition_window_BER_proposed, r.transition_window_BER_chen, ...
                    r.transition_window_BER_alg1, r.transition_improvement_vs_chen_pct, ...
                    r.transition_improvement_vs_alg1_pct, r.recovery_time_proposed, ...
                    r.recovery_time_chen, r.recovery_time_alg1, ...
                    r.recovery_improvement_vs_chen_pct, r.recovery_improvement_vs_alg1_pct, ...
                    r.smnlms_update_rate, ...
                    r.hmm_posterior_entropy, r.hmm_confidence_gap, ...
                    r.dd_bias_proxy, r.dd_bias_dfe_proxy, r.cross_state_memory, ...
                    r.improvement_vs_chen_pct, r.improvement_vs_alg1_pct, ...
                    r.best_method, states);
            end
        end
        fprintf('[8023ck_sparam] Wrote %s\n', fn2);
    end
end
end
