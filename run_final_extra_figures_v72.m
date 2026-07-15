function extra = run_final_extra_figures_v72(varargin)
%RUN_FINAL_EXTRA_FIGURES_V72 Extra paper figures requested after final pack.
%   Generates:
%   - Block A Monte-Carlo BER copy/summary and all-recursion eye diagram.
%   - Block B receiver-stage eye diagrams: Rx input, CTLE/FFE proxy, DFE sum.
%   - Block B channel/waveform impact figures for C2M/C2C and slow/medium/fast.
%   - Block C endogenous-family severe Markov BER figure without classical NLMS.

addpath(genpath(pwd));

p = inputParser;
addParameter(p, 'root_dir', fullfile(pwd, 'paper_final_all_blocks_v72'), @ischar);
addParameter(p, 'run_tracking_mc', false, @islogical);
addParameter(p, 'run_blockC', true, @islogical);
addParameter(p, 'only_blockB_stage_eye', false, @islogical);
addParameter(p, 'only_blockB_allrec_eye', false, @islogical);
parse(p, varargin{:});
opt = p.Results;

root = opt.root_dir;
fig_dir = fullfile(root, 'ExtraFigures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

extra = struct();
fprintf('[extra_v72] Output: %s\n', fig_dir);

if opt.only_blockB_stage_eye
    extra.blockB_stage_eye = local_blockB_receiver_stage_eye(fig_dir);
    save(fullfile(root, 'final_extra_figures_v72_stage_eye_only.mat'), 'extra', '-v7.3');
    fprintf('[extra_v72] Done stage-eye only.\n');
    return;
end

if opt.only_blockB_allrec_eye
    extra.blockB_allrec_eye = local_blockB_stress_eye_all_recursions(fig_dir);
    save(fullfile(root, 'final_extra_figures_v72_blockB_allrec_eye_only.mat'), 'extra', '-v7.3');
    fprintf('[extra_v72] Done Block B all-recursion stress eye only.\n');
    return;
end

extra.blockA_eye = local_blockA_eye_all_methods(fig_dir);
extra.blockB_stage_eye = local_blockB_receiver_stage_eye(fig_dir);
extra.blockB_allrec_eye = local_blockB_stress_eye_all_recursions(fig_dir);
extra.blockB_channel_impact = local_blockB_channel_impact(fig_dir);
extra.blockB_sdd21_overlay = local_blockB_sdd21_overlay(fig_dir);
extra.blockB_com_impairments = local_blockB_com_impairment_impact(fig_dir);
extra.blockB_rate_impact = local_blockB_high_speed_rate_impact(fig_dir);
if opt.run_tracking_mc
    extra.blockB_tracking_mc = local_blockB_tracking_stress_montecarlo(fig_dir);
else
    extra.blockB_tracking_mc = '';
    fprintf('[extra_v72] skipped mini tracking Monte-Carlo (set run_tracking_mc=true to enable).\n');
end
extra.blockB_markov_impact = local_blockB_markov_impact(fig_dir);
if opt.run_blockC
    extra.blockC_no_nlms = local_blockC_no_nlms_plot(fig_dir);
else
    extra.blockC_no_nlms = '';
end

save(fullfile(root, 'final_extra_figures_v72.mat'), 'extra', '-v7.3');
fprintf('[extra_v72] Done.\n');
end

% =====================================================================
function fname = local_blockA_eye_all_methods(fig_dir)
cfg = build_main_config();
base = build_baselines();
vars = build_variants(cfg);
cfgp = cfg;
cfgp.chan_mode = 'markov_2tap';
mkprof = controlled_markov_isi_profile_v72('profile', 'severe_partial_response');
cfgp.markov.h2_states = mkprof.h2_states;
cfgp.markov.P = mkprof.P;
cfgp.markov.init_state = mkprof.init_state;
if isfield(cfgp.markov,'fixed_state'), cfgp.markov = rmfield(cfgp.markov,'fixed_state'); end
cfgp.Nsym = 50000;
cfgp.trainLen = 8000;
cfgp.SNRdB = 22;

rng(720101);
d = local_pam4(cfgp);
[r_clean, ch_state] = channel_out(d, cfgp);
[r, sigma2] = add_noise_dispatch(r_clean, cfgp);

v_base = local_v_base(vars, cfgp);
msb = default_msb_params_v69();

h2_nom = cfgp.markov.h2_states(2);
[chen_w_ffe, chen_w_dfe] = local_pulse_inverse_ffedfe([1 h2_nom], cfgp.Nf, cfgp.Nb, cfgp.D);

names = {'Before EQ','Algorithm 2','Algorithm 1', ...
    'SMNLMS','SM-sign-NLMS','Liu SS-LMS','Chen pulse-ref'};
ys = cell(size(names));
dhs = cell(size(names));

ys{1} = r(:);
dhs{1} = local_slice_with_delay(r, cfgp);

[dhs{2}, diag2] = algorithm6_msb_v69(r, d, cfgp, v_base, msb, ch_state.state);
ys{2} = local_diag_output(diag2, r, cfgp);

[dhs{3}, diag3] = algorithm5_singlebank(r, d, cfgp, v_base);
ys{3} = local_diag_output(diag3, r, cfgp);

[ys{4}, dhs{4}] = dfe_smnlms_unified_x(r, d, cfgp, base, sigma2);
[ys{5}, dhs{5}] = dfe_smsign_nlms_unified_x(r, d, cfgp, base, sigma2);

cfg_liu = cfgp;
cfg_liu.Nb = max(cfgp.Nb, 4);
v_liu = local_resize_v_for_nb(v_base, cfgp, cfg_liu.Nb);
opts_liu = struct('adaptive_threshold', true, 'update_ffe', false, ...
    'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, 'use_projection', true);
[~, dhs{6}, diag_liu] = dfe_ss_lms_pam4(r, d, cfg_liu, v_liu, opts_liu);
ys{6} = local_diag_output(diag_liu, r, cfgp);

[dhs{7}, chen_sum] = local_fixed_ffedfe_slicer(r, chen_w_ffe, chen_w_dfe, cfgp.D, cfgp.A);
ys{7} = chen_sum;

metrics = local_plot_eye_grid(ys, dhs, d, cfgp, names, ...
    'Block A severe Markov-ISI eye diagrams, SNR = 22 dB', ...
    fullfile(fig_dir, 'BlockA_Eye_AllRecursions_SNR22.png'));
writetable(metrics, fullfile(fig_dir, 'BlockA_Eye_AllRecursions_SNR22_metrics.csv'));
fname = fullfile(fig_dir, 'BlockA_Eye_AllRecursions_SNR22.png');
fprintf('[extra_v72] saved %s\n', fname);
end

% =====================================================================
function fname = local_blockB_receiver_stage_eye(fig_dir)
specs = struct( ...
    'baud', {26.5625e9, 53.125e9}, ...
    'snr', {20, 30}, ...
    'tag', {'26p5625GBd_SNR20', '53p125GBd_SNR30'}, ...
    'title', {'Simulated receiver-stage eye diagrams, C2M tracking stress, 26.5625 GBd, SNR = 20 dB', ...
              'Simulated receiver-stage eye diagrams, C2M tracking stress, 53.125 GBd, SNR = 30 dB'});
fnames = cell(numel(specs),1);
for qi = 1:numel(specs)
    fnames{qi} = local_blockB_receiver_stage_eye_one(fig_dir, specs(qi));
end
fname = fnames{1};
end

function fname = local_blockB_receiver_stage_eye_one(fig_dir, spec)
cfg = build_main_config();
base = build_baselines(); %#ok<NASGU>
vars = build_variants(cfg);
cfgp = cfg;
cfgp.Nsym = 50000;
cfgp.trainLen = 10000;
cfgp.Nf = 7;
cfgp.Nb = 4;
cfgp.D = 3;
cfgp.SNRdB = spec.snr;
if isfield(cfgp,'std8023'), cfgp.std8023.enable = false; end

catalog = build_8023ck_channel_catalog('root_dir', fullfile('data','8023ck_channels'), ...
    'allow_synthetic', true, 'baud', spec.baud, 'sps', 16, 'ntaps', 9);
sel = [local_pick_case(catalog,'C2M_10dB'), local_pick_case(catalog,'C2M_14dB'), ...
       local_pick_case(catalog,'C2M_16dB')];

rng(720202);
d = local_pam4(cfgp);
tx_ffe = [1; -0.08; 0.03];
tx = local_apply_tx_ffe(d, tx_ffe);
P = [0.985 0.015 0; 0.0075 0.985 0.0075; 0 0.015 0.985];
state = local_balanced_markov(cfgp.Nsym, cfgp.trainLen, P);
h_phys = {sel.symbol_taps};
[r_clean, ~] = local_fir_state_channel(tx, h_phys, state);
[r_rx, sigma2, rx_gain] = local_add_noise_gain(r_clean, tx, cfgp);
twochain_opt = struct('markov_twochain_noise_scale', 1.25, ...
    'markov_twochain_imp_prob', 0, 'markov_twochain_imp_alpha', 0);
[r_rx, sigma2] = local_apply_twochain_disturbance_proxy(r_rx, r_clean, sigma2, rx_gain, twochain_opt);

h_bank = cellfun(@(h) conv(tx_ffe, h(:)), h_phys, 'UniformOutput', false);
h_bank_rx = cellfun(@(h) rx_gain*h, h_bank, 'UniformOutput', false);

% CTLE/FFE proxy: pulse-response optimized linear pre-equalizer.  This is
% still COM-style visualization rather than a full COM CTLE optimizer, but
% it is tied to the actual C2M pulse instead of a fixed arbitrary peaking
% filter.
h_nom_rx = h_bank_rx{2};
[ctle_taps, ~] = local_pulse_inverse_ffedfe(h_nom_rx(:), cfgp.Nf, 0, cfgp.D);
r_ctle = filter(ctle_taps, 1, r_rx);
target_rms = rms(d);
if rms(r_ctle) > eps
    r_ctle = r_ctle * (target_rms / rms(r_ctle));
end
dh_ctle = local_slice_with_delay(r_ctle, cfgp);
rx_eye = local_align_sample_history_to_symbols(r_rx, cfgp);
r_ctle_eye = local_decision_normalize_to_levels(local_align_sample_history_to_symbols(r_ctle, cfgp), dh_ctle, cfgp);

v_base = local_v_base(vars, cfgp);
msb = default_msb_params_v69();
msb.train_all_prefix = 0;
msb.oracle_train_only = true;
msb.score_mode = 'channel_likelihood';
msb.init_from_hbank = true;
msb.bank_update_rule = 'smnlms';
msb.smnlms = build_baselines().smnlms;
msb.smnlms.tau = 0.35;
msb.smnlms.beta = 0.015;
msb.eb_gate = local_default_eb_gate();
msb.adaptive_threshold = true;
msb.threshold_mu = 2e-3;
msb.threshold_clip_margin = 0.95;
msb.use_beta_anneal = false;
msb.use_adaptive_tau = true;
msb.tau_calib = 0.5;
msb.tau_min = 1e-3;
msb.tau_max = 0.5;
msb.tau_ema_alpha = 0.99;
msb.use_transition_gate = false;
msb.sigma2 = sigma2 * rx_gain^2;

[dh_prop, diag_prop] = algorithm6_msb_firbank(r_rx, d, cfgp, v_base, msb, h_bank_rx, state);
y_sum = local_diag_output(diag_prop, r_rx, cfgp);
y_sum_eye = local_decision_normalize_to_levels(y_sum, dh_prop, cfgp);

names = {'(a) Input of receiver','(b) Output of CTLE/FFE proxy','(c) DFE summing junction'};
ys = {rx_eye, r_ctle_eye, y_sum_eye};
dhs = {local_slice_with_delay(r_rx,cfgp), dh_ctle, dh_prop};
metrics = local_plot_stage_eye_figure(ys, dhs, d, cfgp, names, ...
    spec.title, ...
    fullfile(fig_dir, sprintf('BlockB_ReceiverStage_Eye_C2MTracking_%s.png', spec.tag)));
local_plot_stage_eye_figure(ys, dhs, d, cfgp, names, ...
    spec.title, ...
    fullfile(fig_dir, sprintf('BlockB_ReceiverStage_Eye_C2MTracking_%s_Figure13Style.png', spec.tag)));
writetable(metrics, fullfile(fig_dir, sprintf('BlockB_ReceiverStage_Eye_C2MTracking_%s_metrics.csv', spec.tag)));
fname = fullfile(fig_dir, sprintf('BlockB_ReceiverStage_Eye_C2MTracking_%s.png', spec.tag));
fprintf('[extra_v72] saved %s\n', fname);
end

% =====================================================================
function fnames = local_blockB_stress_eye_all_recursions(fig_dir)
specs = struct( ...
    'baud', {26.5625e9, 53.125e9}, ...
    'fallback_snr', {20, 30}, ...
    'tag', {'26p5625GBd', '53p125GBd'}, ...
    'mc_csv', { ...
        fullfile(pwd, 'paper_final_BlockB_26p5625GBd_10trials_80000samples_cleanSNR_v72', ...
            'baud26p5625GBd', 'BlockB_TrackingStress_PaperMethods_LongTable.csv'), ...
        fullfile(pwd, 'paper_final_BlockB_53p125GBd_10trials_80000samples_cleanSNR_v72', ...
            'baud53p125GBd', 'BlockB_TrackingStress_PaperMethods_LongTable.csv')});
profiles = struct( ...
    'name', {'slow','medium','fast'}, ...
    'pstay', {0.985, 0.970, 0.955});

fnames = cell(numel(specs), numel(profiles));
for qi = 1:numel(specs)
    for pi = 1:numel(profiles)
        fnames{qi,pi} = local_blockB_stress_eye_all_recursions_one(fig_dir, specs(qi), profiles(pi), qi, pi);
    end
end
end

function fname = local_blockB_stress_eye_all_recursions_one(fig_dir, spec, profile, spec_idx, profile_idx)
cfg = build_main_config();
base = build_baselines();
vars = build_variants(cfg);
kp4 = 2.4e-4;
[eye_snr, eye_ber_ref] = local_select_kp4_eye_snr(spec, profile, kp4);
cfgp = cfg;
cfgp.Nsym = 50000;
cfgp.trainLen = 10000;
cfgp.Nf = 7;
cfgp.Nb = 4;
cfgp.D = 3;
cfgp.SNRdB = eye_snr;
if isfield(cfgp,'std8023'), cfgp.std8023.enable = false; end

P = local_three_state_tracking_P(profile.pstay);
cfgp.markov.P = P;
cfgp.markov.init_state = 2;
if isfield(cfgp.markov,'fixed_state'), cfgp.markov = rmfield(cfgp.markov,'fixed_state'); end

catalog = build_8023ck_channel_catalog('root_dir', fullfile('data','8023ck_channels'), ...
    'allow_synthetic', true, 'baud', spec.baud, 'sps', 16, 'ntaps', 9);
sel = [local_pick_case(catalog,'C2M_10dB'), local_pick_case(catalog,'C2M_14dB'), ...
       local_pick_case(catalog,'C2M_16dB')];

rng(721000 + 100*spec_idx + profile_idx);
d = local_pam4(cfgp);
tx_ffe = [1; -0.08; 0.03];
tx = local_apply_tx_ffe(d, tx_ffe);
state = local_balanced_markov(cfgp.Nsym, cfgp.trainLen, P);
h_phys = {sel.symbol_taps};
[r_clean, ~] = local_fir_state_channel(tx, h_phys, state);
[r_rx, sigma2, rx_gain] = local_add_noise_gain(r_clean, tx, cfgp);
twochain_opt = struct('markov_twochain_noise_scale', 1.25, ...
    'markov_twochain_imp_prob', 0, 'markov_twochain_imp_alpha', 0);
[r_rx, sigma2] = local_apply_twochain_disturbance_proxy(r_rx, r_clean, sigma2, rx_gain, twochain_opt);

h_bank = cellfun(@(h) conv(tx_ffe, h(:)), h_phys, 'UniformOutput', false);
h_bank_rx = cellfun(@(h) rx_gain*h, h_bank, 'UniformOutput', false);
v_base = local_v_base(vars, cfgp);

names = {'Before EQ','SMNLMS-DFE','SM-sign-NLMS', ...
    'Liu SS-LMS','Chen pulse-ref','Algorithm 1','Proposed MSB'};
ys = cell(size(names));
dhs = cell(size(names));

% Before EQ: aligned receiver input, scaled using the pilot/training symbols.
dhs{1} = local_slice_with_delay(r_rx, cfgp);
ys{1} = local_rms_normalize_to_levels(local_align_sample_history_to_symbols(r_rx, cfgp), cfgp);

% Proposed MSB-FIRBANK.
msb = default_msb_params_v69();
msb.train_all_prefix = 0;
msb.oracle_train_only = true;
msb.score_mode = 'channel_likelihood';
msb.init_from_hbank = true;
msb.bank_update_rule = 'smnlms';
msb.smnlms = base.smnlms;
msb.smnlms.tau = 0.35;
msb.smnlms.beta = 0.015;
msb.eb_gate = local_default_eb_gate();
msb.adaptive_threshold = true;
msb.threshold_mu = 2e-3;
msb.threshold_clip_margin = 0.95;
msb.use_beta_anneal = false;
msb.use_adaptive_tau = true;
msb.tau_calib = 0.5;
msb.tau_min = 1e-3;
msb.tau_max = 0.5;
msb.tau_ema_alpha = 0.99;
msb.use_transition_gate = false;
msb.sigma2 = sigma2 * rx_gain^2;
[dh_prop, diag_prop] = algorithm6_msb_firbank(r_rx, d, cfgp, v_base, msb, h_bank_rx, state);
y_prop = local_decision_normalize_to_levels(local_diag_output(diag_prop, r_rx, cfgp), dh_prop, cfgp);

% Algorithm 1 single-bank.
[dh_alg1, diag_alg1] = algorithm5_singlebank(r_rx, d, cfgp, v_base);
y_alg1 = local_decision_normalize_to_levels(local_diag_output(diag_alg1, r_rx, cfgp), dh_alg1, cfgp);

% SMNLMS and SM-sign-NLMS baselines.
[y_smn, dh_smn] = dfe_smnlms_unified_x(r_rx, d, cfgp, base, sigma2);
y_smn_eye = local_decision_normalize_to_levels(local_align_sample_history_to_symbols(y_smn, cfgp), dh_smn, cfgp);
[y_sms, dh_sms] = dfe_smsign_nlms_unified_x(r_rx, d, cfgp, base, sigma2);
y_sms_eye = local_decision_normalize_to_levels(local_align_sample_history_to_symbols(y_sms, cfgp), dh_sms, cfgp);

% Liu-style threshold/tap-adaptive sign-sign LMS DFE.
cfg_liu = cfgp;
v_liu = local_v_base(vars, cfg_liu);
opts_liu = struct('adaptive_threshold', true, 'update_ffe', false, ...
    'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, 'use_projection', true);
[~, dh_liu, diag_liu] = dfe_ss_lms_pam4(r_rx, d, cfg_liu, v_liu, opts_liu);
y_liu = local_decision_normalize_to_levels(local_diag_output(diag_liu, r_rx, cfgp), dh_liu, cfgp);

% Chen pulse-response fixed reference: plot the DFE summing/pre-slicer output.
[chen_w_ffe, chen_w_dfe] = local_pulse_inverse_ffedfe(h_bank_rx{2}(:), cfgp.Nf, cfgp.Nb, cfgp.D);
[dh_chen, chen_sum] = local_fixed_ffedfe_slicer(r_rx, chen_w_ffe, chen_w_dfe, cfgp.D, cfgp.A);
y_chen = local_decision_normalize_to_levels(chen_sum, dh_chen, cfgp);

dhs(2:end) = {dh_smn, dh_sms, dh_liu, dh_chen, dh_alg1, dh_prop};
ys(2:end) = {y_smn_eye, y_sms_eye, y_liu, y_chen, y_alg1, y_prop};

ttl = sprintf('Block B %s C2M tracking-stress eye diagrams, %.4g GBd, SNR = %g dB (Proposed near KP4, BER %.3g)', ...
    profile.name, spec.baud/1e9, eye_snr, eye_ber_ref);
snr_tag = local_snr_tag(eye_snr);
fname = fullfile(fig_dir, sprintf('BlockB_StressEye_PaperMethods_%s_%s_%s.png', profile.name, spec.tag, snr_tag));
ber_override = local_lookup_mc_ber_for_eye(spec, profile, eye_snr, names);
metrics = local_plot_eye_grid(ys, dhs, d, cfgp, names, ttl, fname, 3, 3, ber_override);
csvname = fullfile(fig_dir, sprintf('BlockB_StressEye_PaperMethods_%s_%s_%s_metrics.csv', profile.name, spec.tag, snr_tag));
writetable(metrics, csvname);
fprintf('[extra_v72] saved %s\n', fname);
end

function [snr_sel, ber_sel] = local_select_kp4_eye_snr(spec, profile, kp4)
snr_sel = spec.fallback_snr;
ber_sel = NaN;
if ~isfield(spec, 'mc_csv') || exist(spec.mc_csv, 'file') ~= 2
    return;
end
try
    T = readtable(spec.mc_csv);
    idx = strcmp(string(T.Profile), string(profile.name)) & strcmp(string(T.Method), "Proposed MSB");
    T = T(idx,:);
    if isempty(T), return; end
    snr = double(T.SNRdB);
    ber = double(T.BER);
    ok = isfinite(snr) & isfinite(ber) & ber > 0;
    snr = snr(ok); ber = ber(ok);
    if isempty(snr), return; end
    above = find(ber >= kp4);
    if ~isempty(above)
        [~, ii] = max(snr(above));  % closest point just before/at the KP4 crossing
        idx_sel = above(ii);
    else
        [~, idx_sel] = min(abs(log10(max(ber, realmin) ./ kp4)));
    end
    snr_sel = snr(idx_sel);
    ber_sel = ber(idx_sel);
catch ME
    warning('Could not select KP4 eye SNR from %s: %s', spec.mc_csv, ME.message);
end
end

function tag = local_snr_tag(snr)
if abs(snr - round(snr)) < 1e-9
    tag = sprintf('SNR%02d', round(snr));
else
    tag = sprintf('SNR%s', strrep(sprintf('%.2f', snr), '.', 'p'));
end
end

function ber_override = local_lookup_mc_ber_for_eye(spec, profile, snr, names)
ber_override = nan(size(names));
if ~isfield(spec, 'mc_csv') || exist(spec.mc_csv, 'file') ~= 2
    return;
end
try
    T = readtable(spec.mc_csv);
    for k = 1:numel(names)
        if strcmp(string(names{k}), "Before EQ")
            continue;
        end
        idx = strcmp(string(T.Profile), string(profile.name)) & ...
              strcmp(string(T.Method), string(names{k})) & ...
              abs(double(T.SNRdB) - snr) < 1e-9;
        if any(idx)
            vals = double(T.BER(idx));
            ber_override(k) = vals(1);
        end
    end
catch ME
    warning('Could not look up Monte Carlo BER from %s: %s', spec.mc_csv, ME.message);
end
end

function P = local_three_state_tracking_P(pstay)
pstay = min(max(pstay, 0), 1);
q = 1 - pstay;
P = [pstay, q, 0; ...
     q/2, pstay, q/2; ...
     0, q, pstay];
P = P ./ max(sum(P,2), eps);
end

% =====================================================================
function fname = local_blockB_channel_impact(fig_dir)
cfg = build_main_config();
cfg.Nsym = 5000;
cfg.SNRdB = 30;
catalog = build_8023ck_channel_catalog('root_dir', fullfile('data','8023ck_channels'), ...
    'allow_synthetic', true, 'baud', 26.5625e9, 'sps', 16, 'ntaps', 9);
ids = {'C2M_10dB','C2M_14dB','C2M_16dB','C2C_10dB','C2C_18dB','C2C_20dB'};

fig = figure('Color','w','Visible','off','Position',[80 80 1350 820]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
for k = 1:numel(ids)
    ch = local_pick_case(catalog, ids{k});
    h = ch.symbol_taps(:);
    h = h / max(max(abs(h)), eps);
    isi_energy = sum(h(2:end).^2) / max(h(1)^2, eps);
    post1 = 0;
    if numel(h) >= 2, post1 = h(2); end
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    stem(ax, (0:numel(h)-1).', h, 'filled', 'Color',[0.0 0.45 0.74], 'LineWidth',1.2);
    yline(ax, 0, 'k:');
    title(ax, sprintf('%s | IL %.1f dB | post-ISI %.2f', ...
        ids{k}, ch.insertion_loss_db, isi_energy), 'Interpreter','none');
    xlabel(ax,'Symbol-spaced tap index'); ylabel('Normalized pulse tap');
    text(ax, 0.02, 0.08, sprintf('h_1=%.3f', post1), ...
        'Units','normalized', 'FontWeight','bold', 'Color',[0.55 0.10 0.10]);
end
sgtitle('Block B channel-impact visualization: symbol-spaced pulse/ISI severity across C2M/C2C cases');
fname = fullfile(fig_dir, 'BlockB_ChannelImpact_C2M_C2C_Waveforms.png');
local_save(fig, fname);
fname2 = fullfile(fig_dir, 'BlockB_ChannelImpact_C2M_C2C_PulseISI.png');
copyfile(fname, fname2);
fprintf('[extra_v72] saved %s\n', fname);
end

% =====================================================================
function fname = local_blockB_sdd21_overlay(fig_dir)
catalog = build_8023ck_channel_catalog('root_dir', fullfile('data','8023ck_channels'), ...
    'allow_synthetic', true, 'baud', 26.5625e9, 'sps', 16, 'ntaps', 9);
ids = {'C2M_10dB','C2M_14dB','C2M_16dB','C2C_10dB','C2C_18dB','C2C_20dB'};
nyq_26 = 26.5625e9/2;
nyq_53 = 53.125e9/2;

fig = figure('Color','w','Visible','off','Position',[80 80 980 650]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
cols = lines(numel(ids));
styles = {'-','--','-.',':','-','--'};
summary = table();
fmax_seen = 0;

for k = 1:numel(ids)
    ch = local_pick_case(catalog, ids{k});
    if isfield(ch, 'file') && ~isempty(ch.file) && exist(ch.file, 'file') == 2
        sp = load_touchstone_sparam(ch.file);
        [ff, HH] = local_sparam_through_response(sp, '12_34');
        Hdc = interp1(ff, HH, 0, 'pchip', 'extrap');
        mag_db = 20*log10(abs(HH) / max(abs(Hdc), eps));
        label = ids{k};
    else
        [ff, mag_db] = local_tap_response_db(ch.symbol_taps(:), 26.5625e9);
        label = [ids{k} ' fallback'];
    end

    plot(ax, ff/1e9, mag_db, styles{k}, 'Color', cols(k,:), ...
        'LineWidth', 1.55, 'DisplayName', label);
    fmax_seen = max(fmax_seen, max(ff));
    il26 = -interp1(ff, mag_db, min(nyq_26, max(ff)), 'pchip', 'extrap');
    il53 = -interp1(ff, mag_db, min(nyq_53, max(ff)), 'pchip', 'extrap');
    summary = [summary; table(string(ids{k}), string(ch.group), ...
        ch.insertion_loss_db, il26, il53, string(ch.file), ...
        'VariableNames', {'CaseID','Group','ManifestInsertionLoss_dB', ...
        'IL_at_26p5625GBd_Nyq_dB','IL_at_53p125GBd_Nyq_dB','File'})]; %#ok<AGROW>
end

xline(ax, nyq_26/1e9, 'k--', 'R_s/2 = 13.28 GHz (26.5625 GBd)', ...
    'LabelOrientation','horizontal', 'LabelVerticalAlignment','bottom', ...
    'HandleVisibility','off');
xline(ax, nyq_53/1e9, 'k:', 'R_s/2 = 26.56 GHz (53.125 GBd)', ...
    'LabelOrientation','horizontal', 'LabelVerticalAlignment','top', ...
    'HandleVisibility','off');
yline(ax, -3, ':', '-3 dB', 'Color',[0.45 0.45 0.45], ...
    'HandleVisibility','off');
xlabel(ax,'Frequency (GHz)');
ylabel(ax,'|Sdd21| relative to DC (dB)');
title(ax,'802.3ck-style C2M/C2C channel response with symbol-rate Nyquist markers (R_s/2)', ...
    'Interpreter','none');
legend(ax, 'Location','southwest', 'Interpreter','none');
if fmax_seen > 0
    xlim(ax, [0 min(fmax_seen/1e9, 40)]);
else
    xlim(ax, [0 40]);
end
ylim(ax, [-35 3]);

fname = fullfile(fig_dir, 'BlockB_Sdd21_Overlay_C2M_C2C_FrequencyResponse.png');
local_save(fig, fname);
writetable(summary, fullfile(fig_dir, 'BlockB_Sdd21_Overlay_C2M_C2C_FrequencyResponse.csv'));
fprintf('[extra_v72] saved %s\n', fname);
end

% =====================================================================
function fname = local_blockB_com_impairment_impact(fig_dir)
cfg = build_main_config();
cfg.Nsym = 16000;
cfg.trainLen = 3000;
cfg.SNRdB = 24;
catalog = build_8023ck_channel_catalog('root_dir', fullfile('data','8023ck_channels'), ...
    'allow_synthetic', true, 'baud', 26.5625e9, 'sps', 16, 'ntaps', 9);
ch = local_pick_case(catalog, 'C2M_16dB');

rng(720505);
d = local_pam4(cfg);
tx = local_apply_tx_ffe(d, [1; -0.08; 0.03]);
h = ch.symbol_taps(:);
[rx_clean, ~] = local_fir_state_channel(tx, {h}, ones(cfg.Nsym,1));
rx_clean = rx_clean * (rms(tx) / max(rms(rx_clean), eps));
sigma2 = mean(tx.^2) / (10^(cfg.SNRdB/10));
awgn = sqrt(sigma2) * randn(size(rx_clean));

xtalk_src1 = local_apply_tx_ffe(local_pam4(cfg), [1; -0.05]);
xtalk_src2 = local_apply_tx_ffe(local_pam4(cfg), [1; 0.04]);
h_fext = 0.055 * [0; h(1:min(end,5))];
h_next = 0.035 * [h(1:min(end,5)); 0];
fext = filter(h_fext, 1, xtalk_src1);
next = filter(h_next, 1, xtalk_src2);
xtalk = fext + next;

jitter = local_symbol_timing_jitter(rx_clean, 0.035);
cases = {rx_clean, rx_clean + awgn, rx_clean + xtalk, jitter, rx_clean + awgn + xtalk + (jitter-rx_clean)};
labels = {'Channel only','+ AWGN','+ NEXT/FEXT proxy','+ timing jitter proxy','Combined stress'};

fig = figure('Color','w','Visible','off','Position',[70 70 1380 780]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
seg = cfg.trainLen + (1:360);
for k = 1:numel(cases)
    y = cases{k};
    y = y * (rms(tx) / max(rms(y), eps));
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    plot(ax, seg, tx(seg), 'Color',[0.12 0.12 0.12], 'LineWidth',0.65);
    plot(ax, seg, y(seg), 'Color',[0.00 0.45 0.74], 'LineWidth',0.85);
    met = local_simple_channel_metrics(y, d, cfg);
    title(ax, sprintf('%s | EVM %.2f | eye proxy %.2f', labels{k}, met.evm, met.eye_proxy), ...
        'Interpreter','none');
    xlabel(ax,'Symbol index'); ylabel(ax,'Amplitude');
    if k == 1
        legend(ax, {'Tx PAM4','Impaired Rx'}, 'Location','best');
    end
end
ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
vals = zeros(numel(cases),2);
for k = 1:numel(cases)
    met = local_simple_channel_metrics(cases{k}, d, cfg);
    vals(k,:) = [met.evm, met.eye_proxy];
end
yyaxis(ax,'left'); bar(ax, vals(:,1), 0.55, 'FaceColor',[0.00 0.45 0.74]);
ylabel(ax,'EVM proxy');
yyaxis(ax,'right'); plot(ax, 1:numel(cases), vals(:,2), '-o', 'Color',[0.85 0.33 0.10], ...
    'LineWidth',1.5, 'MarkerFaceColor',[0.85 0.33 0.10]);
ylabel(ax,'vertical eye proxy');
set(ax,'XTick',1:numel(cases),'XTickLabel',labels,'XTickLabelRotation',25);
title(ax,'COM-style impairment summary');
sgtitle('Block B COM-style impairment impact: AWGN, crosstalk, timing jitter, and combined stress');
fname = fullfile(fig_dir, 'BlockB_COMStyle_ImpairmentImpact.png');
local_save(fig, fname);
fprintf('[extra_v72] saved %s\n', fname);
end

% =====================================================================
function fname = local_blockB_high_speed_rate_impact(fig_dir)
cfg = build_main_config();
cfg.Nsym = 12000;
cfg.trainLen = 2500;
cfg.SNRdB = 26;
rates = [26.5625 53.125]; % 802.3ck-focused baud points.
labels = {'26.5625 GBd','53.125 GBd (100G/lane PAM4)'};
catalog = build_8023ck_channel_catalog('root_dir', fullfile('data','8023ck_channels'), ...
    'allow_synthetic', true, 'baud', 26.5625e9, 'sps', 16, 'ntaps', 9);
ch = local_pick_case(catalog, 'C2M_16dB');
sp = [];
if isfield(ch, 'file') && ~isempty(ch.file) && exist(ch.file, 'file') == 2
    sp = load_touchstone_sparam(ch.file);
end

rng(720606);
d = local_pam4(cfg);
tx = local_apply_tx_ffe(d, [1; -0.08; 0.03]);

fig = figure('Color','w','Visible','off','Position',[70 70 1280 680]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
summary = zeros(numel(rates),3);
for k = 1:numel(rates)
    if ~isempty(sp)
        chk = sparam_to_symbol_impulse(sp, 'baud', rates(k)*1e9, ...
            'sps', 16, 'ntaps', 9, 'port_order', '12_34', 'normalize_main', false);
        h = chk.symbol_taps(:);
    else
        rate_scale = rates(k) / rates(1);
        h = local_rate_stress_pulse(ch.symbol_taps(:), rate_scale);
    end
    h = h / max(abs(h(1)), eps);
    [rx, ~] = local_fir_state_channel(tx, {h}, ones(cfg.Nsym,1));
    rx = rx * (rms(tx) / max(rms(rx), eps));
    sigma2 = mean(tx.^2) / (10^(cfg.SNRdB/10));
    rx = rx + sqrt(sigma2) * randn(size(rx));
    rx = rx * (rms(tx) / max(rms(rx), eps));
    met = local_simple_channel_metrics(rx, d, cfg);
    isi = sum(h(2:end).^2) / max(h(1)^2, eps);
    summary(k,:) = [isi, met.evm, met.eye_proxy];

    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    if ~isempty(sp)
        [ff, HH] = local_sparam_through_response(sp, '12_34');
        Hdc = interp1(ff, HH, 0, 'pchip', 'extrap');
        mag_db = 20*log10(abs(HH) / max(abs(Hdc), eps));
        nyq = rates(k)*1e9/2;
        il_nyq = -interp1(ff, mag_db, min(nyq,max(ff)), 'pchip', 'extrap');
        plot(ax, ff/1e9, mag_db, 'Color',[0.00 0.45 0.74], 'LineWidth',1.2);
        xline(ax, nyq/1e9, '--', sprintf('R_s/2 %.1f GHz', nyq/1e9), ...
            'Color',[0.85 0.33 0.10], 'LabelOrientation','horizontal');
        title(ax, sprintf('%s | IL@symbol Nyq %.1f dB', labels{k}, il_nyq), 'Interpreter','none');
        xlabel(ax,'Frequency (GHz)'); ylabel(ax,'|Sdd21| rel. DC (dB)');
        xlim(ax, [0 min(max(ff)/1e9, max(rates)*0.65)]);
    else
        stem(ax, 0:numel(h)-1, h(:)/max(abs(h)), 'filled', 'LineWidth',1.2, ...
            'Color',[0.00 0.45 0.74]);
        title(ax, sprintf('%s pulse | post-ISI %.2e', labels{k}, isi), 'Interpreter','none');
        xlabel(ax,'Tap index'); ylabel(ax,'Normalized tap');
    end

    ax = nexttile(k+3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    seg = cfg.trainLen + (1:240);
    plot(ax, seg, tx(seg), 'Color',[0.15 0.15 0.15], 'LineWidth',0.65);
    plot(ax, seg, rx(seg), 'Color',[0.85 0.33 0.10], 'LineWidth',0.9);
    title(ax, sprintf('%s waveform | EVM %.2f', labels{k}, met.evm), 'Interpreter','none');
    xlabel(ax,'Symbol index'); ylabel(ax,'Amplitude');
end
sgtitle('Block B high-speed transmission stress: higher symbol rate increases effective postcursor ISI');
fname = fullfile(fig_dir, 'BlockB_HighSpeed_RateImpact_100GStress.png');
local_save(fig, fname);
writetable(table(string(labels(:)), summary(:,1), summary(:,2), summary(:,3), ...
    'VariableNames', {'RateCase','PostcursorISI','EVMProxy','EyeProxy'}), ...
    fullfile(fig_dir, 'BlockB_HighSpeed_RateImpact_100GStress.csv'));
fprintf('[extra_v72] saved %s\n', fname);
end

% =====================================================================
function fname = local_blockB_tracking_stress_montecarlo(fig_dir)
fprintf('[extra_v72] Running Block B two-chain tracking-stress Monte-Carlo mini sweep.\n');
out = run_paper('8023ck_sparam', ...
    'trials', 3, ...
    'snr', 15:1:30, ...
    'max_cases', 6, ...
    'run_static', false, ...
    'run_markov', true, ...
    'run_markov_sweep', false, ...
    'markov_modes', {'slow','medium','fast'}, ...
    'markov_twochain', true, ...
    'markov_twochain_noise_scale', 1.25, ...
    'markov_twochain_imp_prob', 0, ...
    'markov_twochain_imp_alpha', 0, ...
    'markov_use_adaptive_tau', true, ...
    'markov_tau_calib', 0.5, ...
    'markov_use_transition_gate', false, ...
    'plot', false, ...
    'fig_visible', 'off', ...
    'save_dir', fullfile(fig_dir, 'tmp_tracking_stress_mc'));

mk = out.markov;
cases = regexprep({mk.case_id}, '^Markov_', '');
BER = [[mk.BER_algorithm6].', [mk.BER_algorithm1].', [mk.BER_chen_pulse_ref].'];
SER = [[mk.SER_algorithm6].', [mk.SER_algorithm1].', [mk.SER_chen_pulse_ref].'];
TBER = [[mk.transition_window_BER_algorithm6].', ...
        [mk.transition_window_BER_algorithm1].', ...
        [mk.transition_window_BER_chen_pulse_ref].'];
ACC = 100*[mk.state_accuracy].';
methods = {'Proposed MSB','Algorithm 1','Chen pulse-ref'};

fig = figure('Color','w','Visible','off','Position',[80 80 1180 780]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
cols = [0.000 0.447 0.741; 0.850 0.325 0.098; 0.350 0.350 0.350];

ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for mi = 1:3
    semilogy(ax, 1:numel(cases), max(BER(:,mi),1e-8), '-o', ...
        'Color', cols(mi,:), 'LineWidth', 1.8 + 0.6*(mi==1), ...
        'MarkerFaceColor', cols(mi,:));
end
yline(ax, 2.4e-4, 'k--', 'KP4 FEC 2.4e-4');
set(ax,'XTick',1:numel(cases),'XTickLabel',cases,'YScale','log');
ylabel(ax,'pre-FEC BER'); title(ax,'Tracking-stress BER');
legend(ax, methods, 'Location','southwest', 'Interpreter','none');

ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for mi = 1:3
    semilogy(ax, 1:numel(cases), max(SER(:,mi),1e-8), '-s', ...
        'Color', cols(mi,:), 'LineWidth', 1.8 + 0.6*(mi==1), ...
        'MarkerFaceColor', cols(mi,:));
end
set(ax,'XTick',1:numel(cases),'XTickLabel',cases,'YScale','log');
ylabel(ax,'SER'); title(ax,'Tracking-stress SER');

ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for mi = 1:3
    semilogy(ax, 1:numel(cases), max(TBER(:,mi),1e-8), '-^', ...
        'Color', cols(mi,:), 'LineWidth', 1.8 + 0.6*(mi==1), ...
        'MarkerFaceColor', cols(mi,:));
end
set(ax,'XTick',1:numel(cases),'XTickLabel',cases,'YScale','log');
ylabel(ax,'transition-window BER'); title(ax,'Post-transition BER');

ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
bar(ax, 1:numel(cases), ACC, 'FaceColor', cols(1,:));
set(ax,'XTick',1:numel(cases),'XTickLabel',cases);
ylabel(ax,'state accuracy (%)'); ylim(ax,[0 100]);
title(ax,'HMM/FIR routing accuracy');

sgtitle('Block B Monte Carlo: C2M two-chain tracking stress (run\_static=false, markov\_twochain=true)', ...
    'Interpreter','none');
fname = fullfile(fig_dir, 'BlockB_MonteCarlo_TwoChainTrackingStress_BER_SER.png');
local_save(fig, fname);
save(fullfile(fig_dir, 'BlockB_MonteCarlo_TwoChainTrackingStress_BER_SER.mat'), 'out', '-v7.3');
fprintf('[extra_v72] saved %s\n', fname);
end

% =====================================================================
function fname = local_blockB_markov_impact(fig_dir)
cfg = build_main_config();
cfg.Nsym = 18000;
cfg.trainLen = 3000;
cfg.SNRdB = 30;
catalog = build_8023ck_channel_catalog('root_dir', fullfile('data','8023ck_channels'), ...
    'allow_synthetic', true, 'baud', 26.5625e9, 'sps', 16, 'ntaps', 9);
sel = [local_pick_case(catalog,'C2M_10dB'), local_pick_case(catalog,'C2M_14dB'), ...
       local_pick_case(catalog,'C2M_16dB')];
Ps = { ...
    [0.985 0.015 0; 0.0075 0.985 0.0075; 0 0.015 0.985], ...
    [0.970 0.030 0; 0.0200 0.960 0.0200; 0 0.030 0.970], ...
    [0.930 0.070 0; 0.0400 0.920 0.0400; 0 0.070 0.930]};
labels = {'slow','medium','fast'};
rng(720404);
d = local_pam4(cfg);
tx = local_apply_tx_ffe(d, [1; -0.08; 0.03]);
h_phys = {sel.symbol_taps};

fig = figure('Color','w','Visible','off','Position',[80 80 1250 760]);
tiledlayout(3,2,'Padding','compact','TileSpacing','compact');
for k = 1:3
    state = local_balanced_markov(cfg.Nsym, cfg.trainLen, Ps{k});
    [r_clean, ~] = local_fir_state_channel(tx, h_phys, state);
    r = r_clean * (rms(tx) / max(rms(r_clean), eps));
    seg = cfg.trainLen + (1:600);
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    plot(ax, seg, tx(seg), 'Color',[0.15 0.15 0.15], 'LineWidth',0.75);
    plot(ax, seg, r(seg), 'Color',[0.85 0.33 0.10], 'LineWidth',0.9);
    title(ax, sprintf('%s switching: waveform distortion', labels{k}));
    xlabel(ax,'Symbol index'); ylabel(ax,'Amplitude');
    legend(ax, {'Tx','Rx channel output'}, 'Location','best');

    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    stairs(ax, seg, state(seg), 'Color',[0.0 0.45 0.74], 'LineWidth',1.0);
    ylim(ax,[0.5 3.5]); yticks(ax,1:3); yticklabels(ax,{'10dB','14dB','16dB'});
    title(ax, sprintf('%s switching: channel state trajectory', labels{k}));
    xlabel(ax,'Symbol index'); ylabel(ax,'C2M state');
end
sgtitle('Block B Markov tracking stress: slow/medium/fast channel-state impact');
fname = fullfile(fig_dir, 'BlockB_MarkovSlowMediumFast_ChannelImpact.png');
local_save(fig, fname);
fprintf('[extra_v72] saved %s\n', fname);
end

% =====================================================================
function fname = local_blockC_no_nlms_plot(fig_dir)
root = fileparts(fig_dir);
src = fullfile(root, 'BlockC_endogenous_family', ...
    'Table_Endogenous_Aware_Family.csv');
T = readtable(src);
keep = ~strcmp(T.Method, 'NLMS');
T = T(keep,:);
methods = unique(T.Method, 'stable');

fig = figure('Color','w','Visible','off','Position',[80 80 850 620]);
hold on; grid on; box on;
cols = lines(numel(methods));
marks = {'o','s','^','d','v','>'};
for i = 1:numel(methods)
    idx = strcmp(T.Method, methods{i});
    semilogy(T.SNRdB(idx), T.BER(idx), ['-' marks{min(i,numel(marks))}], ...
        'LineWidth', 1.8, 'MarkerSize', 6, 'Color', cols(i,:), ...
        'MarkerFaceColor', cols(i,:));
end
yline(2.4e-4, 'k--', 'KP4 FEC 2.4e-4');
xlabel('SNR (dB)'); ylabel('pre-FEC BER');
title('Endogenous-aware recursion bridge');
legend(methods, 'Location','southwest', 'Interpreter','none');
set(gca,'YScale','log');
fname = fullfile(fig_dir, 'BlockC_EndogenousFamily_SevereBER_NoClassicalNLMS.png');
local_save(fig, fname);
copyfile(fname, fullfile(fig_dir, 'Endogenous_Aware_Recursion_Bridge_MonteCarlo_BER.png'));
fprintf('[extra_v72] saved %s\n', fname);
end

% =====================================================================
function metrics = local_plot_eye_grid(ys, dhs, d, cfg, names, ttl, fname, nrow, ncol, ber_override)
if nargin < 8 || isempty(nrow)
    n = numel(ys);
    nrow = ceil(sqrt(n));
    ncol = ceil(n/nrow);
end
if nargin < 10 || isempty(ber_override)
    ber_override = nan(size(names));
end
fig = figure('Color','w','Visible','off','Position',[60 60 1450 900]);
tiledlayout(nrow,ncol,'Padding','compact','TileSpacing','compact');
metrics = table();
sps = 16;
g = rc_pulse(0.5, sps, 8);
waves = cell(size(ys));
all_wave = [];
for kk = 1:numel(ys)
    waves{kk} = local_symbol_to_eye_waveform(ys{kk}, g, sps);
    x = waves{kk};
    x = x(:);
    x = x(isfinite(x));
    if numel(x) > 8000
        x = x(round(linspace(1, numel(x), 8000)));
    end
    all_wave = [all_wave; x]; %#ok<AGROW>
end
yl = local_common_ylim(all_wave);
for k = 1:numel(ys)
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    color_k = local_eye_color_for_method(names{k}, k, numel(ys));
    line_w = 0.24;
    if strcmp(string(names{k}), "Proposed MSB")
        line_w = 0.30;
    end
    local_plot_eye_waveform(ax, waves{k}, sps, color_k, 140, line_w);
    local_draw_pam4_thresholds(ax, cfg.A, yl);
    ylim(ax, yl);
    xlim(ax, [0 2]);
    met = compute_eye_height_width_metrics(ys{k}, d, cfg);
    ber_local = ser_after_training_aligned(d, dhs{k}, cfg) / log2(cfg.M);
    ber = ber_local;
    if k <= numel(ber_override) && isfinite(ber_override(k))
        ber = ber_override(k);
    end
    title(ax, sprintf('%s\nBER=%s', ...
        names{k}, local_fmt_ber(ber)), ...
        'FontSize', 9, 'FontWeight','bold', 'Interpreter','none');
    xlabel(ax,'Time (UI)'); ylabel(ax,'Amplitude');
    metrics = [metrics; table(string(names{k}), ber, met.eye_height_5_95, ...
        met.eye_width_ui, ber_local, 'VariableNames', ...
        {'Method','BER','EyeHeight','EyeWidth','SnapshotBER'})]; %#ok<AGROW>
end
sgtitle(ttl, 'FontWeight','bold');
local_save(fig, fname);
end

function c = local_eye_color_for_method(name, idx, n)
name = string(name);
mc = lines(7);  % Monte-Carlo paper-method palette before dropping ExtraTrees.
switch name
    case "Before EQ"
        c = [0.18 0.18 0.18];
    case "SMNLMS-DFE"
        c = mc(1,:);
    case "SM-sign-NLMS"
        c = mc(2,:);
    case "Liu SS-LMS"
        c = mc(3,:);
    case "Chen pulse-ref"
        c = mc(4,:);
    case "Algorithm 1"
        c = mc(6,:);
    case "Proposed MSB"
        c = mc(7,:);
    otherwise
        fallback = lines(max(n, idx));
        c = fallback(idx,:);
end
end

% =====================================================================
function metrics = local_plot_stage_eye_figure(ys, dhs, d, cfg, names, ttl, fname)
sps = 16;
g = rc_pulse(0.5, sps, 8);
waves = cell(size(ys));
all_wave = [];
for k = 1:numel(ys)
    waves{k} = local_symbol_to_eye_waveform(ys{k}, g, sps);
    x = waves{k};
    x = x(:);
    x = x(isfinite(x));
    if numel(x) > 8000
        x = x(round(linspace(1, numel(x), 8000)));
    end
    all_wave = [all_wave; x]; %#ok<AGROW>
end
yl = local_common_ylim(all_wave);
cols = {[0.18 0.45 0.78], [0.18 0.45 0.78], [0.18 0.45 0.78]};

fig = figure('Color','w','Visible','off','Position',[80 80 1180 380]);
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
metrics = table();
for k = 1:numel(waves)
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    local_plot_eye_waveform(ax, waves{k}, sps, cols{k}, 180, 0.32);
    local_draw_pam4_thresholds(ax, cfg.A, yl);
    ylim(ax, yl);
    xlim(ax, [0 2]);
    xlabel(ax, 'Time (UI)');
    ylabel(ax, 'Amplitude');
    met = compute_eye_height_width_metrics(ys{k}, d, cfg);
    ber = ser_after_training_aligned(d, dhs{k}, cfg) / log2(cfg.M);
    title(ax, sprintf('%s\nBER=%s', names{k}, local_fmt_ber(ber)), ...
        'FontSize', 9, 'FontWeight','bold', 'Interpreter','none');
    text(ax, 0.50, yl(1) + 0.06*(yl(2)-yl(1)), sprintf('(%c)', 'a'+k-1), ...
        'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize', 10);
    metrics = [metrics; table(string(names{k}), ber, met.eye_height_5_95, ...
        met.eye_width_ui, 'VariableNames', {'Method','BER','EyeHeight','EyeWidth'})]; %#ok<AGROW>
end
sgtitle(ttl, 'FontWeight','bold');
local_save(fig, fname);
end

% =====================================================================
function xos = local_symbol_to_eye_waveform(x, g, sps)
if isempty(x)
    xos = [];
    return;
end
x = x(:);
x = x(isfinite(x));
if numel(x) < 4
    xos = [];
    return;
end
xos = conv(local_upsample_zeros(x, sps), g, 'same');
gpk = max(abs(g));
if isfinite(gpk) && gpk > eps
    xos = xos / gpk;
end
end

function y = local_upsample_zeros(x, sps)
y = zeros(numel(x)*sps,1);
y(1:sps:end) = x(:);
end

function yl = local_common_ylim(x)
if isempty(x)
    yl = [-4 4];
    return;
end
x = x(:);
x = x(isfinite(x));
if isempty(x)
    yl = [-4 4];
    return;
end
q = prctile(x, [0.5 99.5]);
if ~all(isfinite(q)) || q(2) <= q(1)
    m = max(abs(x));
    if isempty(m) || ~isfinite(m) || m == 0, m = 4; end
    yl = [-1.15*m, 1.15*m];
else
    pad = 0.12 * max(q(2)-q(1), eps);
    yl = [q(1)-pad, q(2)+pad];
end
yl(1) = min(yl(1), -3.5);
yl(2) = max(yl(2),  3.5);
end

function local_plot_eye_waveform(ax, xos, sps, color, max_traces, line_width)
axes(ax); %#ok<LAXES>
if isempty(xos)
    text(ax, 0.5, 0.5, 'No trace', 'Units','normalized', ...
        'HorizontalAlignment','center', 'FontWeight','bold');
    return;
end
eye_plot_reshape_fixed(xos, sps, 'max_traces', max_traces, ...
    'color', color, 'line_width', line_width);
end

function local_draw_pam4_thresholds(ax, A, yl)
A = sort(A(:));
if numel(A) < 2, return; end
ths = 0.5*(A(1:end-1) + A(2:end));
for k = 1:numel(ths)
    th = ths(k);
    if th >= yl(1) && th <= yl(2)
        plot(ax, [0 2], [th th], ':', 'Color', [0.35 0.35 0.35], ...
            'LineWidth', 0.7, 'HandleVisibility','off');
    end
end
end

% =====================================================================
function local_eye_scatter(ax, y, cfg)
y = y(:);
N = min(numel(y), cfg.Nsym);
idx = (cfg.trainLen+1):min(N, cfg.trainLen+9000);
if isempty(idx), idx = 1:min(N,9000); end
idx = idx(:);
phase = mod(idx-1, 2);
plot(ax, phase, y(idx), '.', 'MarkerSize', 2, 'Color', [0.05 0.30 0.70]);
plot(ax, phase+1, y(idx), '.', 'MarkerSize', 2, 'Color', [0.05 0.30 0.70]);
yline(ax, [-2 0 2], ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.7);
xlim(ax,[0 2]);
end

function d = local_pam4(cfg)
sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
d = cfg.A(sym_idx).';
d = d(:);
end

function v = local_v_base(vars, cfgp)
v = make_v_alg5(vars.theorem);
K = cfgp.Nf; L = cfgp.Nb;
main_idx = round((K+1)/2);
v.main_idx = main_idx;
ffe_min = -v.w2_max*ones(K,1);
ffe_max =  v.w2_max*ones(K,1);
ffe_min(main_idx) = -Inf;
ffe_max(main_idx) =  Inf;
v.theta_min = [ffe_min; -v.b_max*ones(L,1)];
v.theta_max = [ffe_max;  v.b_max*ones(L,1)];
end

function v = local_resize_v_for_nb(v_base, cfgp, Nb)
v = v_base;
if numel(v.theta_min) ~= cfgp.Nf + Nb
    v.theta_min = [v_base.theta_min(1:cfgp.Nf); -v_base.b_max*ones(Nb,1)];
    v.theta_max = [v_base.theta_max(1:cfgp.Nf);  v_base.b_max*ones(Nb,1)];
end
end

function y = local_diag_output(diag, r, cfg)
if isstruct(diag) && isfield(diag, 'y_hist') && ~isempty(diag.y_hist)
    y = local_align_sample_history_to_symbols(diag.y_hist(:), cfg);
elseif isstruct(diag) && isfield(diag, 'z_hist') && ~isempty(diag.z_hist)
    y = local_align_sample_history_to_symbols(diag.z_hist(:), cfg);
else
    y = r(:);
end
if numel(y) < cfg.Nsym
    y(end+1:cfg.Nsym) = 0;
end
y = y(1:cfg.Nsym);
end

function y = local_align_sample_history_to_symbols(x, cfg)
x = x(:);
y = zeros(cfg.Nsym, 1);
for n = 1:min(numel(x), cfg.Nsym)
    m = n - cfg.D;
    if m >= 1 && m <= cfg.Nsym
        y(m) = x(n);
    end
end
end

function y2 = local_linear_normalize_to_ref(y, d, cfg)
y = y(:);
d = d(:);
N = min([numel(y), numel(d), cfg.Nsym]);
idx = max(1, round(0.25*cfg.trainLen)):min(N, cfg.trainLen);
idx = idx(:);
idx = idx(isfinite(y(idx)) & isfinite(d(idx)));
if numel(idx) < 100
    idx = (cfg.trainLen+1):min(N, cfg.trainLen+5000);
    idx = idx(:);
    idx = idx(isfinite(y(idx)) & isfinite(d(idx)));
end
if numel(idx) < 10 || std(y(idx)) < eps
    y2 = y;
    return;
end
X = [y(idx), ones(numel(idx),1)];
ab = X \ d(idx);
y2 = ab(1) * y + ab(2);
end

function y2 = local_rms_normalize_to_levels(y, cfg)
y = y(:);
idx = isfinite(y);
if ~any(idx)
    y2 = y;
    return;
end
y0 = y;
y0(idx) = y0(idx) - mean(y0(idx), 'omitnan');
target = rms(cfg.A(:));
src = rms(y0(idx));
if isfinite(src) && src > eps
    y2 = y0 * (target / src);
else
    y2 = y;
end
end

function y2 = local_decision_normalize_to_levels(y, dh, cfg)
y = y(:);
dh = dh(:);
N = min([numel(y), numel(dh), cfg.Nsym]);
idx = (cfg.trainLen+1):min(N, cfg.trainLen+12000);
idx = idx(:);
idx = idx(isfinite(y(idx)) & isfinite(dh(idx)) & dh(idx) ~= 0);
if numel(idx) < 50
    idx = 1:N;
    idx = idx(:);
    idx = idx(isfinite(y(idx)) & isfinite(dh(idx)) & dh(idx) ~= 0);
end
if numel(idx) < 10 || std(y(idx)) < eps
    y2 = y;
    return;
end
X = [y(idx), ones(numel(idx),1)];
ab = X \ dh(idx);
y2 = ab(1) * y + ab(2);
if rms(y2(isfinite(y2))) > 8
    y2 = y2 * (rms(cfg.A(:)) / max(rms(y2(isfinite(y2))), eps));
end
end

function dh = local_slice_with_delay(r, cfg)
dh = zeros(cfg.Nsym,1);
for n = 1:min(numel(r), cfg.Nsym)
    m = n - cfg.D;
    if m >= 1 && m <= cfg.Nsym
        dh(m) = pam_slice_scalar(r(n), cfg.A);
    end
end
end

function [w_ffe, w_dfe] = local_pulse_inverse_ffedfe(h, Kf, Lb, D)
M = numel(h);
Lconv = Kf + M - 1;
H = zeros(Lconv, Kf);
for k = 1:Kf
    H(k:k+M-1, k) = h(:);
end
e = zeros(Lconv,1);
e(min(D+1, Lconv)) = 1;
lambda = 1e-4;
w_ffe = (H.'*H + lambda*eye(Kf)) \ (H.'*e);
g = conv(w_ffe, h);
w_dfe = g(D+2:min(D+1+Lb, numel(g)));
if numel(w_dfe) < Lb
    w_dfe(end+1:Lb) = 0;
end
w_dfe = w_dfe(:);
end

function [yhat, ysum] = local_fixed_ffedfe_slicer(r, w_ffe, w_dfe, D, A)
N = numel(r);
y_ffe = filter(w_ffe, 1, r(:));
Lb = numel(w_dfe);
yhat_sample = zeros(N,1);
ysum_sample = zeros(N,1);
dec_buf = zeros(Lb,1);
for n = 1:N
    z = y_ffe(n) - w_dfe(:).' * dec_buf;
    s = pam_slice_scalar(z, A);
    ysum_sample(n) = z;
    yhat_sample(n) = s;
    if Lb > 0
        dec_buf = [s; dec_buf(1:end-1)];
    end
end
yhat = zeros(N,1);
ysum = zeros(N,1);
for n = 1:N
    m = n - D;
    if m >= 1 && m <= N
        yhat(m) = yhat_sample(n);
        ysum(m) = ysum_sample(n);
    end
end
end

function dh = local_cui_centroid_hmm(r, d, cfg)
X = local_cui_features(r);
N = min([numel(r), numel(d), size(X,1)]);
cls = local_symbol_to_class(d(1:N), cfg.A);
train_mask = false(N,1);
train_mask(1:min(cfg.trainLen,N)) = true;
M = cfg.M;
cent = zeros(M, size(X,2));
sig2 = zeros(M,1);
for c = 1:M
    idx = train_mask & cls == c;
    if ~any(idx), idx = train_mask; end
    cent(c,:) = mean(X(idx,:), 1, 'omitnan');
    dist = sum((X(idx,:) - cent(c,:)).^2, 2);
    sig2(c) = max(mean(dist, 'omitnan'), 1e-6);
end
score = zeros(N,M);
for c = 1:M
    score(:,c) = -sum((X(1:N,:) - cent(c,:)).^2, 2) / (2*sig2(c));
end
score = score - max(score, [], 2);
Pemit = exp(score);
Pemit = Pemit ./ max(sum(Pemit,2), eps);
[logA, log_pi0] = hmm_train_pam4(cls(train_mask), M, 1.0);
hat_cls = hmm_viterbi_pam4(Pemit, logA, log_pi0);
A = cfg.A(:);
sample_hat = A(max(1,min(M,hat_cls)));
dh = zeros(numel(d),1);
for n = 1:N
    m = n - cfg.D;
    if m >= 1 && m <= numel(d)
        dh(m) = sample_hat(n);
    end
end
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

function cls = local_symbol_to_class(y, A)
A = A(:);
y = y(:);
cls = zeros(numel(y),1);
for i = 1:numel(y)
    [~, cls(i)] = min(abs(A - y(i)));
end
end

function ch = local_pick_case(catalog, id)
idx = find(strcmp({catalog.case_id}, id), 1);
if isempty(idx), error('Missing channel case %s', id); end
ch = catalog(idx);
end

function y = local_apply_tx_ffe(d, taps)
y = filter(taps(:), 1, d(:));
if rms(y) > eps
    y = y * (rms(d) / rms(y));
end
end

function state = local_balanced_markov(N, trainLen, P)
S = size(P,1);
state = zeros(N,1);
state(1) = 2;
for n = 2:N
    prev = state(n-1);
    u = rand;
    cs = cumsum(P(prev,:));
    state(n) = find(u <= cs, 1, 'first');
end
% Ensure all states occur during training to initialize banks.
for s = 1:S
    idx = s:S:min(trainLen,N);
    state(idx) = s;
end
end

function [r_clean, st] = local_fir_state_channel(tx, h_bank, state)
N = numel(tx);
r_clean = zeros(N,1);
for n = 1:N
    h = h_bank{state(n)};
    acc = 0;
    for k = 1:numel(h)
        if n-k+1 >= 1
            acc = acc + h(k) * tx(n-k+1);
        end
    end
    r_clean(n) = acc;
end
st = struct('state', state);
end

function [r, sigma2, gain] = local_add_noise_gain(r_clean, tx, cfg)
sigma2 = mean(r_clean(:).^2) / (10^(cfg.SNRdB/10));
r = r_clean(:) + sqrt(sigma2) * randn(size(r_clean(:)));
gain = rms(tx) / max(rms(r), eps);
r = r * gain;
end

function [r2, sigma2_eff] = local_apply_twochain_disturbance_proxy(r, r_clean, sigma2, rx_gain, opt)
N = numel(r);
clean_rx = rx_gain * r_clean(:);
base_noise = r(:) - clean_rx(:);
P2 = [0.975 0.025; 0.100 0.900];
q = ones(N,1);
for n = 2:N
    u = rand;
    cs = cumsum(P2(q(n-1),:));
    q(n) = find(u <= cs, 1, 'first');
end
noise_scale = opt.markov_twochain_noise_scale(:).';
imp_prob = opt.markov_twochain_imp_prob(:).';
if numel(noise_scale) < 2, noise_scale(2) = noise_scale(1); end
if numel(imp_prob) < 2, imp_prob(2) = imp_prob(1); end
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

function y = local_symbol_timing_jitter(x, jitter_ui)
x = x(:);
N = numel(x);
n = (1:N).';
dn = jitter_ui * randn(N,1);
yp = interp1(n, x, n + dn, 'linear', 'extrap');
y = yp(:);
end

function h2 = local_rate_stress_pulse(h, rate_scale)
h = h(:);
if isempty(h), h = 1; end
idx = (0:numel(h)-1).';
tail_gain = min(2.2, max(1.0, rate_scale^0.65));
tail_spread = min(0.18, 0.045 * (rate_scale - 1));
h2 = h;
if numel(h2) >= 2
    h2(2:end) = tail_gain * h2(2:end);
end
if tail_spread > 0
    smear = exp(-idx / max(1.5, 3.5/rate_scale));
    smear = smear / max(sum(abs(smear)), eps);
    h2 = (1-tail_spread)*h2 + tail_spread*conv(h2, smear, 'same');
end
h2 = h2 / max(abs(h2(1)), eps);
end

function met = local_simple_channel_metrics(y, d, cfg)
y = y(:);
d = d(:);
idx = (cfg.trainLen+1):min([numel(y), numel(d), cfg.Nsym]);
if isempty(idx), idx = 1:min(numel(y), numel(d)); end
err = y(idx) - d(idx);
met.evm = sqrt(mean(err.^2, 'omitnan')) / max(rms(d(idx)), eps);
A = sort(cfg.A(:));
eye_gap = nan(numel(A)-1,1);
for k = 1:numel(A)-1
    lo = y(idx(d(idx)==A(k)));
    hi = y(idx(d(idx)==A(k+1)));
    if numel(lo) > 10 && numel(hi) > 10
        eye_gap(k) = prctile(hi,5) - prctile(lo,95);
    end
end
met.eye_proxy = min(eye_gap, [], 'omitnan');
if ~isfinite(met.eye_proxy), met.eye_proxy = NaN; end
end

function [f, H] = local_sparam_through_response(sp, port_order)
S = sp.S;
if sp.nport >= 4
    switch lower(port_order)
        case '13_24'
            H = 0.5 * squeeze(S(2,1,:) - S(2,3,:) - S(4,1,:) + S(4,3,:));
        case '12_34'
            H = 0.5 * squeeze(S(3,1,:) - S(3,2,:) - S(4,1,:) + S(4,2,:));
        otherwise
            error('Unsupported port_order: %s', port_order);
    end
else
    H = squeeze(S(2,1,:));
end
f = sp.freq_hz(:);
H = H(:);
good = isfinite(f) & isfinite(real(H)) & isfinite(imag(H));
f = f(good);
H = H(good);
[f, ia] = unique(f, 'stable');
H = H(ia);
if min(f) > 0
    f = [0; f];
    H = [H(1); H];
end
end

function [f, mag_db] = local_tap_response_db(h, baud)
h = h(:);
nfft = 2048;
H = fft(h, nfft);
f = linspace(0, baud/2, floor(nfft/2)+1).';
H = H(1:numel(f));
mag_db = 20*log10(abs(H) / max(abs(H(1)), eps));
end

function g = local_default_eb_gate()
g = struct('enabled', true, 'lambda_entropy', 1.0, ...
    'lambda_cross', 3.0, 'lambda_confidence', 0.5, ...
    'gamma_max_scale', 3.0, 'beta_min_scale', 0.35, ...
    'use_fast_reroute', true, 'reroute_entropy', 0.33, ...
    'reroute_conf_gap', 0.55, 'reroute_pi_reset', 0.75);
end

function s = local_fmt_ber(x)
if ~isfinite(x)
    s = 'N/A';
elseif x == 0
    s = '0';
else
    s = sprintf('%.3e', x);
end
end

function local_save(fig, fname)
set(fig, 'PaperPositionMode', 'auto');
try
    exportgraphics(fig, fname, 'Resolution', 300);
catch
    saveas(fig, fname);
end
close(fig);
end
