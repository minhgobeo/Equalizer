function pkg = run_ck_stressed_channel_check(cfg, vars, base, mc)
%RUN_CK_STRESSED_CHANNEL_CHECK  IEEE 802.3ck-inspired controlled PAM4 stress benchmark.
%
% v70 changes:
%   * Adds Liu SS-LMS / TA-SS-LMS, Cui ExtraTrees-HMM adapted, and
%     Chen single-pulse FFE/DFE adapted baselines directly inside the
%     ck_stress benchmark.
%   * All reported baselines use the SAME 802.3ck-inspired channel/noise
%     profiles generated in this function.
%   * Oracle MSB is computed and printed only; it is not plotted.
%   * Stores representative equalizer-output traces for eye diagrams of all
%     plotted benchmark methods.
%
% IMPORTANT:
%   This is NOT an IEEE 802.3ck compliance test. It is a controlled
%   IEEE-802.3ck-inspired symbol-rate stress simulation. The residual ISI
%   tail is derived from the IEEE P802.3ck Annex 120E insertion-loss-limit
%   formula used in build_8023ck_ref_residual_tail.m. No COM, no ERL, no
%   calibrated VEC, no measured S-parameters, and no formal TP compliance
%   procedure are reproduced.

fprintf('\n[ck_stress] IEEE 802.3ck-inspired controlled stressed-channel benchmark (NOT compliance).\n');
fprintf('[ck_stress] All baselines are evaluated on the same generated CK-inspired channel/noise profiles.\n');

% --- Stress configuration ---
Ntrial    = max(10, min(20, mc.Ntrial_ser));
snr_list  = [22 26];
profiles  = {'isi_awgn','isi_xtalk_awgn','isi_jitter_awgn','dirty_full'};
BER_PRE_FEC_THRESHOLD = 2.4e-4;
EYE_SNR_REF = 22;
EYE_TRIAL_REF = 1;

% --- Residual ISI tail derived from IEEE 802.3ck IL_max ---
Ntaps_residual = 5;
il_offset_dB   = 6;
[ck_tail, ck_tail_info] = build_8023ck_ref_residual_tail(Ntaps_residual, il_offset_dB);

fprintf('[ck_stress] CK residual-tail source check:\n');
fprintf('[ck_stress]   Formula source          = %s\n', ck_tail_info.formula_source);
fprintf('[ck_stress]   URL                     = %s\n', ck_tail_info.url);
fprintf('[ck_stress]   Symbol rate             = %.3f GBd\n', ck_tail_info.fb_GHz);
fprintf('[ck_stress]   IL offset from limit    = %.1f dB\n', il_offset_dB);
fprintf('[ck_stress]   IL @ Nyquist           = %.2f dB\n', ck_tail_info.IL_dB_at_Nyquist);
fprintf('[ck_stress]   tail = [%s]\n', strjoin(arrayfun(@(x) sprintf('%+.4f', x), ck_tail, 'uni', false), ', '));

% --- Pre-equalizer: invert IL_max tail with a fixed linear FIR ---
preeq_taps = design_il_max_preeq(ck_tail, 11);
fprintf('[ck_stress] Linear pre-equalizer (CTLE/FFE proxy before adaptive DFE):\n');
fprintf('[ck_stress]   length=%d, taps = [%s]\n', numel(preeq_taps), ...
    strjoin(arrayfun(@(x) sprintf('%+.3f', x), preeq_taps, 'uni', false), ' '));

% --- Receiver config ---
cfg0 = local_ck_regime(cfg);
fprintf('[ck_stress] Controlled receiver config:\n');
fprintf('[ck_stress]   Nsym=%d, trainLen=%d, Nf=%d, Nb=%d, D=%d\n', ...
    cfg0.Nsym, cfg0.trainLen, cfg0.Nf, cfg0.Nb, cfg0.D);
fprintf('[ck_stress]   Markov h2 states = [%s], init_state=%d\n', ...
    strjoin(arrayfun(@(x) sprintf('%.2f',x), cfg0.markov.h2_states, 'uni', false), ' '), cfg0.markov.init_state);

v_base = local_alg5_base(vars, cfg0);
msb_params = default_msb_params_v69();

% The Oracle row is included in the log/table but excluded from figures.
methods = {'Algorithm 2','Oracle-MSB (printed only)','Algorithm 1','NLMS','SM-sign', ...
           'Liu SS-LMS','Liu TA-SS-LMS','Cui ExtraTrees-HMM','Chen single-pulse'};
plot_methods = [1 3 4 5 6 7 8 9];

% Chen fixed equalizer is designed once from the nominal centre-state pulse.
[w_chen_ffe, w_chen_dfe, D_chen] = local_design_chen_single_pulse(cfg0);
fprintf('[ck_stress] Chen single-pulse adapted fixed EQ: FFE=[%s], DFE=[%s], delay=%d\n', ...
    sprintf('%.3f ', w_chen_ffe), sprintf('%.3f ', w_chen_dfe), D_chen);

% Cui models are trained once per CK profile on the same CK channel construction.
cui_models = cell(numel(profiles),1);
for pi = 1:numel(profiles)
    cfg_train = cfg0;
    cfg_train.SNRdB = EYE_SNR_REF;
    cui_models{pi} = local_train_cui_ck_model(cfg_train, profiles{pi}, ck_tail, preeq_taps);
    fprintf('[ck_stress] Cui adapted classifier for %-15s = %s\n', profiles{pi}, cui_models{pi}.kind);
end

R = struct([]);
row = 0;
eye_bank = struct();
eye_bank.snr_ref = EYE_SNR_REF;
eye_bank.trial_ref = EYE_TRIAL_REF;
eye_bank.profiles = profiles;
eye_bank.methods = methods(plot_methods);
eye_bank.signals = cell(numel(profiles), numel(plot_methods));
eye_bank.rx_before = cell(numel(profiles),1);
eye_bank.d_ref = cell(numel(profiles),1);
eye_bank.A = cfg0.A;
eye_bank.note = 'Representative post-training traces from the same ck_stress run; Oracle is intentionally omitted.';
eye_bank.metric_methods = [{'Before EQ'}, methods(plot_methods)];
eye_bank.metric_names = {'EyeHeight_5_95','EyeWidth_UI','MinQ','MeasuredThresholdSER'};
eye_bank.metrics = cell(numel(profiles), numel(plot_methods)+1);
eye_bank.metric_note = ['EyeHeight_5_95 is the minimum adjacent PAM4 p05/p95 vertical opening. ' ...
                        'EyeWidth_UI is an approximate horizontal opening from the same 2-UI raised-cosine eye waveform used in the figures. ' ...
                        'These are simulation audit metrics, not formal IEEE compliance measurements.'];

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

            % Fixed linear pre-equalizer before the adaptive receiver.
            r = filter(preeq_taps, 1, r_dirty);
            sigma2_eff(t) = mean((r_dirty - r_noiseless).^2);

            % --- Proposed and classical adaptive baselines ---
            [dh_alg2, diag_alg2] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);
            [dh_orc,  diag_orc]  = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, ch_state.state);
            [dh_alg1, diag_alg1] = algorithm5_singlebank(r, d, cfg_p, v_base);
            [y_nlms, dh_nlms, ~] = dfe_nlms_unified_x(r, d, cfg_p, base);
            diag_nlms = struct('z_hist', y_nlms);
            [y_sm, dh_sm, ~]     = dfe_smsign_nlms_unified_x(r, d, cfg_p, base, max(sigma2_eff(t), eps));
            diag_sm = struct('z_hist', y_sm);

            % --- Liu-style SS-LMS / TA-SS-LMS baselines under same CK channel ---
            cfg_liu = cfg_p; cfg_liu.Nb = 4;   % Liu paper uses 4-tap DFE.
            v_liu = local_alg5_base(vars, cfg_liu);
            opts_ss = struct('adaptive_threshold', false, 'update_ffe', false, ...
                             'update_dfe', true, 'mu_f', 2e-3, 'use_projection', true);
            [~, dh_liu_ss, diag_liu_ss] = dfe_ss_lms_pam4(r, d, cfg_liu, v_liu, opts_ss);
            opts_ta = struct('adaptive_threshold', true, 'update_ffe', false, ...
                             'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, 'use_projection', true);
            [~, dh_liu_ta, diag_liu_ta] = dfe_ss_lms_pam4(r, d, cfg_liu, v_liu, opts_ta);

            % --- Cui ExtraTrees-HMM adapted baseline under same CK channel ---
            Xte = local_cui_features_only(r, 5);
            dh_cui_sample = local_predict_cui_ck(cui_models{pi}, Xte, cfg_p.A);
            dh_cui = local_sample_to_symbol_index(dh_cui_sample, cfg_p.D, numel(d));

            % --- Chen single-pulse adapted baseline under same CK channel ---
            [dh_chen, diag_chen] = local_fixed_ffedfe_slicer_with_diag(r, w_chen_ffe, w_chen_dfe, D_chen, cfg_p.A);

            % --- Metrics ---
            ser(t,1) = ser_after_training_aligned(d, dh_alg2, cfg_p);
            ser(t,2) = ser_after_training_aligned(d, dh_orc,  cfg_p);
            ser(t,3) = ser_after_training_aligned(d, dh_alg1, cfg_p);
            ser(t,4) = ser_after_training_aligned(d, dh_nlms, cfg_p);
            ser(t,5) = ser_after_training_aligned(d, dh_sm,   cfg_p);
            ser(t,6) = ser_after_training_aligned(d, dh_liu_ss, cfg_p);
            ser(t,7) = ser_after_training_aligned(d, dh_liu_ta, cfg_p);
            ser(t,8) = ser_after_training_aligned(d, dh_cui, cfg_p);
            ser(t,9) = ser_after_training_aligned(d, dh_chen, cfg_p);

            post_idx = (cfg_p.trainLen + diag_alg2.N_sep + 1):cfg_p.Nsym;
            if ~isempty(post_idx)
                acc(t) = msb_state_accuracy(diag_alg2.s_hat_hist, ch_state.state, post_idx);
            end

            % Representative traces for eye plotting at reference SNR/trial.
            if cfg_p.SNRdB == EYE_SNR_REF && t == EYE_TRIAL_REF
                eye_bank.rx_before{pi} = local_eye_segment(r_dirty, cfg_p);
                eye_bank.d_ref{pi} = local_eye_segment(d, cfg_p);
                all_diag = {diag_alg2, diag_alg1, diag_nlms, diag_sm, ...
                            diag_liu_ss, diag_liu_ta, struct('z_hist',dh_cui(:)), diag_chen};
                eye_bank.metrics{pi,1} = compute_eye_height_width_metrics(r_dirty, d, cfg_p);
                for jj = 1:numel(plot_methods)
                    eye_bank.signals{pi,jj} = local_extract_eye_output(all_diag{jj}, cfg_p);
                    full_sig = local_extract_full_output(all_diag{jj}, cfg_p);
                    eye_bank.metrics{pi,jj+1} = compute_eye_height_width_metrics(full_sig, d, cfg_p);
                end
                % keep Oracle available for audit, not plotted
                eye_bank.oracle_signal{pi} = local_extract_eye_output(diag_orc, cfg_p);
                eye_bank.oracle_metric{pi} = compute_eye_height_width_metrics(local_extract_full_output(diag_orc, cfg_p), d, cfg_p);
            end
        end

        row = row + 1;
        R(row).profile = profile;
        R(row).SNRdB = cfg_p.SNRdB;
        R(row).methods = methods;
        R(row).plot_methods = plot_methods;
        R(row).SER = mean(ser,1);
        R(row).BER = R(row).SER / log2(cfg_p.M);
        R(row).hmm_accuracy = mean(acc,'omitnan');
        R(row).sigma2_eff = mean(sigma2_eff);
        R(row).stress = stress;
        R(row).pass_fec = R(row).BER(1) <= BER_PRE_FEC_THRESHOLD;

        fprintf(['[ck_stress] %-15s SNR=%2d | acc=%5.2f%% | ' ...
                 'Alg2=%.3e (%s), Oracle=%.3e, Alg1=%.3e, NLMS=%.3e, SM=%.3e, ' ...
                 'LiuSS=%.3e, LiuTA=%.3e, Cui=%.3e, Chen=%.3e\n'], ...
            profile, cfg_p.SNRdB, 100*R(row).hmm_accuracy, R(row).BER(1), ...
            tern(R(row).pass_fec,'PASS','FAIL'), R(row).BER(2), R(row).BER(3), ...
            R(row).BER(4), R(row).BER(5), R(row).BER(6), R(row).BER(7), R(row).BER(8), R(row).BER(9));
    end
end

pkg = struct();
pkg.table = R;
pkg.methods = methods;
pkg.plot_methods = plot_methods;
pkg.profiles = profiles;
pkg.snr_list = snr_list;
pkg.Ntrial = Ntrial;
pkg.cfg = cfg0;
pkg.msb_params_used = msb_params;
pkg.preeq_taps = preeq_taps;
pkg.ck_tail = ck_tail;
pkg.ck_tail_info = ck_tail_info;
pkg.stress_params = local_stress_params_summary(ck_tail);
pkg.chen = struct('w_ffe',w_chen_ffe,'w_dfe',w_chen_dfe,'D',D_chen);
pkg.cui = struct('models',{cui_models},'note','One adapted classifier trained per CK profile at the reference SNR.');
pkg.eye_bank = eye_bank;
pkg.ber_pre_fec_threshold = BER_PRE_FEC_THRESHOLD;
pkg.note = ['IEEE-802.3ck-INSPIRED controlled stressed-channel simulation, NOT compliance. ' ...
            'Residual ISI tail is derived from IEEE P802.3ck Annex 120E IL_max formula. ' ...
            'All baselines are evaluated on the same generated channel/noise profiles. ' ...
            'Receiver chain: IL_max-derived residual tail + fixed pre-equalizer proxy + adaptive equalizers. ' ...
            'Oracle MSB upper bound is computed and printed only, not plotted. ' ...
            'No COM, no ERL, no calibrated VEC, no PRBS13Q/31Q, no measured S-parameters.'];

fprintf('\nTABLE CK-v72. IEEE 802.3ck-inspired controlled stress benchmark, BER summary\n');
fprintf('Note: NOT IEEE compliance; Oracle is an upper bound printed only and excluded from plots.\n');
fprintf('Residual tail source: %s.\n', ck_tail_info.formula_source);
fprintf('All methods share the same generated CK-inspired channel/noise traces.\n\n');
fprintf('%-16s %6s ', 'Profile','SNR');
for m=1:numel(methods)
    fprintf('%12s ', local_short_method(methods{m}));
end
fprintf('%9s %6s\n', 'Acc','FEC');
for k=1:numel(R)
    fprintf('%-16s %6.0f ', R(k).profile, R(k).SNRdB);
    for m=1:numel(methods)
        fprintf('%12.3e ', R(k).BER(m));
    end
    fprintf('%8.2f%% %6s\n', 100*R(k).hmm_accuracy, tern(R(k).pass_fec,'PASS','FAIL'));
end
end

% =====================================================================
function s = local_short_method(name)
name = strrep(name,'Algorithm 2','Alg2');
name = strrep(name,'Oracle-MSB (printed only)','Oracle');
name = strrep(name,'Algorithm 1','Alg1');
name = strrep(name,'Cui ExtraTrees-HMM','Cui');
name = strrep(name,'Chen single-pulse','Chen');
name = strrep(name,'Liu TA-SS-LMS','LiuTA');
name = strrep(name,'Liu SS-LMS','LiuSS');
s = name;
if numel(s) > 12, s = s(1:12); end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end

% =====================================================================
function w = design_il_max_preeq(ck_tail, Lpreeq)
if nargin < 2, Lpreeq = 11; end
h = [1; ck_tail(:)];
M = numel(h);
Lconv = Lpreeq + M - 1;
H = zeros(Lconv, Lpreeq);
for k = 1:Lpreeq
    H(k:k+M-1, k) = h;
end
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
sp.extra_tail_source = 'IEEE P802.3ck Annex 120E IL_max formula as implemented in build_8023ck_ref_residual_tail';
sp.rj_ui = 0.006;
sp.sj_ui = 0.020;
sp.buj_ui = 0.006;
sp.sj_cycles = 37;
sp.si_cycles = 11;
sp.num_aggressors = 4;
sp.xtalk_rms_frac = 0.045;
sp.si_rms_frac = 0.020;
end

% =====================================================================
function model = local_train_cui_ck_model(cfg, profile, ck_tail, preeq_taps)
N_train = min(30000, cfg.Nsym);
rng(771000 + sum(double(profile)) + round(10*cfg.SNRdB));
cfg_t = cfg; cfg_t.Nsym = N_train;
sym_idx = randi([1 cfg_t.M], cfg_t.Nsym, 1);
d = cfg_t.A(sym_idx).'; d = d(:);
[r_dirty, ~, ~, ~] = local_ck_dirty_channel(d, cfg_t, profile, ck_tail);
r = filter(preeq_taps, 1, r_dirty);
[Xtr, ytr] = local_cui_features_aligned(r, d, 5, cfg_t.D);

% Train tree-ensemble classifier
[mdl, kind] = local_train_cui_classifier(Xtr, ytr, cfg_t.A);

% Train HMM on training labels (faithful Cui pipeline)
y_class_tr = local_symbol_to_class(ytr, cfg_t.A);
[logA, log_pi0, hmm_info] = hmm_train_pam4(y_class_tr, cfg_t.M, 1.0);

model = struct( ...
    'mdl', mdl, 'kind', kind, 'A', cfg_t.A, 'profile', profile, ...
    'N_train', N_train, 'M', cfg_t.M, ...
    'logA', logA, 'log_pi0', log_pi0, 'hmm_info', hmm_info);

fprintf('[ck_stress/cui] %-15s HMM trained, A diag = %s\n', ...
    profile, sprintf('%.3f ', diag(hmm_info.A)));
end


function X = local_cui_features_only(r, dim)
N = numel(r);
X = zeros(N, dim);
for n=1:N
    rn = r(n);
    rm1 = 0; if n>=2, rm1 = r(n-1); end
    rm2 = 0; if n>=3, rm2 = r(n-2); end
    rm3 = 0; if n>=4, rm3 = r(n-3); end
    X(n,:) = [rn, rm1, rm2, rm3, rn-rm1];
end
end

function [X, y] = local_cui_features_aligned(r, d, dim, D)
Xall = local_cui_features_only(r, dim);
N = numel(r);
mm = (1:N).' - D;
valid = mm >= 1 & mm <= numel(d);
X = Xall(valid,:);
y = d(mm(valid));
y = y(:);
end

function d_hat_sym = local_sample_to_symbol_index(yhat_sample, D, Nd)
d_hat_sym = zeros(Nd,1);
for n = 1:numel(yhat_sample)
    m = n - D;
    if m >= 1 && m <= Nd
        d_hat_sym(m) = yhat_sample(n);
    end
end
end

function P = local_classifier_scores(model, X, M)
% Return N x M emission-probability matrix from any of the 3 classifier kinds.
N = size(X,1);
P = zeros(N, M);

switch model.kind
    case 'fitcensemble_bag'
        [~, scores] = predict(model.mdl.mdl, X);
        cls = model.mdl.mdl.ClassNames;
        if iscell(cls), cls = str2double(cls); end
        for k = 1:numel(cls)
            mi = round(cls(k));
            if mi >= 1 && mi <= M
                P(:, mi) = scores(:, k);
            end
        end
        if any(P(:) < 0), P = exp(P); end
        P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);

    case 'TreeBagger'
        [~, scores] = predict(model.mdl.mdl, X);
        cls = model.mdl.mdl.ClassNames;
        if iscell(cls), cls = str2double(cls); end
        for k = 1:numel(cls)
            mi = round(cls(k));
            if mi >= 1 && mi <= M
                P(:, mi) = scores(:, k);
            end
        end
        P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);

    case 'nearest_centroid'
        C = size(model.mdl.centroids, 1);
        D = zeros(N, C);
        for c = 1:C
            d = X - model.mdl.centroids(c,:);
            D(:,c) = sum(d.*d, 2);
        end
        sig2 = max(mean(D(:)) / 4, 1e-6);
        for c = 1:C
            mi = round(model.mdl.classes(c));
            if mi >= 1 && mi <= M
                P(:, mi) = exp(-D(:,c) / (2*sig2));
            end
        end
        P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);

    otherwise
        error('Unknown classifier kind: %s', model.kind);
end

P = max(P, 1e-12);
P = bsxfun(@rdivide, P, sum(P,2));
end


function [model, kind] = local_train_cui_classifier(X, y, A)
% UNCHANGED from v72 — included only for self-containment of this patch.
y_class = local_symbol_to_class(y, A);
model = struct();
kind = 'nearest_centroid';
if exist('fitcensemble','file') == 2
    try
        model.mdl = fitcensemble(X, y_class, 'Method','Bag', 'NumLearningCycles',50);
        kind = 'fitcensemble_bag'; return;
    catch ME
        fprintf('[ck_stress/cui] fitcensemble unavailable (%s), trying TreeBagger.\n', ME.message);
    end
end
if exist('TreeBagger','file') == 2
    try
        model.mdl = TreeBagger(50, X, y_class, 'Method','classification');
        kind = 'TreeBagger'; return;
    catch ME
        fprintf('[ck_stress/cui] TreeBagger unavailable (%s), falling back.\n', ME.message);
    end
end
classes = unique(y_class);
C = numel(classes);
centroids = zeros(C, size(X,2));
for c = 1:C
    centroids(c,:) = mean(X(y_class == classes(c), :), 1);
end
model.centroids = centroids;
model.classes = classes;
end

function yhat = local_predict_cui_ck(model, X, A)
% Faithful Cui prediction: ExtraTrees soft scores -> Viterbi decode -> symbols.
M = model.M;

% 1. Soft class probabilities from classifier
P_emit = local_classifier_scores(model, X, M);

% 2. Viterbi decoding
y_class = hmm_viterbi_pam4(P_emit, model.logA, model.log_pi0);

% 3. Map class -> PAM4 symbol
yhat = local_class_to_symbol(y_class, A);
yhat = yhat(:);
end

function c = local_symbol_to_class(d, A)
A = A(:);
[~, c] = min(abs(d(:) - A.'), [], 2);
end

function s = local_class_to_symbol(c, A)
A = A(:);
c = round(c(:));
c = max(1, min(numel(A), c));
s = A(c);
end

% =====================================================================
function [w_ffe, w_dfe, D_eq] = local_design_chen_single_pulse(cfg)
h2_bar = cfg.markov.h2_states(ceil(numel(cfg.markov.h2_states)/2));
h_nom = [1, h2_bar];
Kf = cfg.Nf;
Lb = cfg.Nb;
D_eq = round((Kf+1)/2);
[w_ffe, w_dfe] = local_pulse_inverse_ffedfe(h_nom, Kf, Lb, D_eq);
end

function [w_ffe, w_dfe] = local_pulse_inverse_ffedfe(h, Kf, Lb, D)
M = numel(h);
Lconv = Kf + M - 1;
H = zeros(Lconv, Kf);
for k=1:Kf
    H(k:k+M-1, k) = h(:);
end
e = zeros(Lconv,1);
e(D+1) = 1;
lambda = 1e-4;
w_ffe = (H.'*H + lambda*eye(Kf)) \ (H.'*e);
g = conv(w_ffe, h);
w_dfe = g(D+2 : min(D+1+Lb, numel(g)));
if numel(w_dfe) < Lb
    w_dfe(end+1:Lb) = 0;
end
w_dfe = w_dfe(:);
end

function [yhat, diag] = local_fixed_ffedfe_slicer_with_diag(r, w_ffe, w_dfe, D, A)
N = numel(r);
y_ffe = filter(w_ffe, 1, [r; zeros(numel(w_ffe)-1,1)]);
y_ffe = y_ffe(1:N);
Lb = numel(w_dfe);
yhat_sample = zeros(N,1);
z_hist = zeros(N,1);
dec_buf = zeros(Lb,1);
for n=1:N
    z = y_ffe(n) - w_dfe(:).' * dec_buf;
    s = pam_slice_scalar(z, A);
    yhat_sample(n) = s;
    z_hist(n) = z;
    dec_buf = [s; dec_buf(1:end-1)];
end
yhat = zeros(N,1);
for n=1:N
    m = n - D;
    if m>=1 && m<=N
        yhat(m) = yhat_sample(n);
    end
end
diag = struct('z_hist',z_hist,'d_hat_hist',yhat_sample);
end

% =====================================================================
function seg = local_eye_segment(x, cfg)
idx = (cfg.trainLen + 1000):min(cfg.Nsym, cfg.trainLen + 12000);
idx = idx(:);
idx = idx(idx >= 1 & idx <= numel(x));
seg = x(idx);
end


function full = local_extract_full_output(diag, cfg)
if isstruct(diag) && isfield(diag,'y_hist')
    full = diag.y_hist(:);
elseif isstruct(diag) && isfield(diag,'z_hist')
    full = diag.z_hist(:);
elseif isstruct(diag) && isfield(diag,'d_hat_hist')
    full = diag.d_hat_hist(:);
else
    full = zeros(cfg.Nsym,1);
end
end

function seg = local_extract_eye_output(diag, cfg)
if isstruct(diag) && isfield(diag,'y_hist')
    x = diag.y_hist(:);
elseif isstruct(diag) && isfield(diag,'z_hist')
    x = diag.z_hist(:);
elseif isstruct(diag) && isfield(diag,'d_hat_hist')
    x = diag.d_hat_hist(:);
else
    x = zeros(cfg.Nsym,1);
end
idx = (cfg.trainLen + 1000):min(cfg.Nsym, cfg.trainLen + 12000);
idx = idx(:);
idx = idx(idx >= 1 & idx <= numel(x));
seg = x(idx);
end
