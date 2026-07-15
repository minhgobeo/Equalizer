function out = run_blockA_eye_diagram_snr25(varargin)
%RUN_BLOCKA_EYE_DIAGRAM_SNR25  Eye diagram for all algorithms at a given SNR.
%
%  Mirrors local_blockA_eye_all_methods() in run_final_extra_figures_v72.m
%  but parameterised for SNR=25 (or any snr_db).
%
%  Saves to <save_dir>/eye/BlockA_Eye_AllMethods_SNRxx.png
%
%  Usage (called from run_blockA_hybrid_launcher.m after BER run):
%    run_blockA_eye_diagram_snr25('snr_db', 25, 'save_dir', 'paper_final_BlockA_hybrid_v72')

p = inputParser;
addParameter(p, 'snr_db',      25,     @(x)isnumeric(x)&&isscalar(x));
addParameter(p, 'Nsym',        500000, @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, 'trainLen',    8000,   @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, 'save_dir',    'paper_final_BlockA_hybrid_v72', @ischar);
addParameter(p, 'fig_visible', 'off',  @ischar);
addParameter(p, 'rng_seed',    725001, @(x)isnumeric(x)&&isscalar(x));
addParameter(p, 'ber_from_checkpoint', true, @islogical);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));

eye_dir = fullfile(opt.save_dir, 'eye');
if ~exist(eye_dir, 'dir'), mkdir(eye_dir); end

fprintf('[eye_snr%g] Generating eye diagram (SNR=%g dB, Nsym=%d)...\n', ...
    opt.snr_db, opt.snr_db, opt.Nsym);

% ---- build config ----
cfg           = build_main_config();
cfg.Nsym      = opt.Nsym;
cfg.trainLen  = opt.trainLen;
cfg.SNRdB     = opt.snr_db;
cfg.chan_mode  = 'markov_2tap';

mkprof = controlled_markov_isi_profile_v72('profile', 'severe_partial_response');
cfg.markov.h2_states = mkprof.h2_states;
cfg.markov.P         = mkprof.P;
cfg.markov.init_state = mkprof.init_state;
if isfield(cfg.markov, 'fixed_state')
    cfg.markov = rmfield(cfg.markov, 'fixed_state');
end

% ---- simulate channel ----
rng(opt.rng_seed);
d = local_pam4_data(cfg);
[r_clean, ch_state] = channel_out(d, cfg);
[r, sigma2]         = add_noise_dispatch(r_clean, cfg);

base  = build_baselines();
vars  = build_variants(cfg);
v_base = local_v_base_wrap(vars, cfg);
msb   = default_msb_params_v69();

h2_nom = cfg.markov.h2_states(2);
[chen_w_ffe, chen_w_dfe] = local_pulse_inverse_ffedfe( ...
    [1 h2_nom], cfg.Nf, cfg.Nb, cfg.D);

% ---- run all algorithms ----
names = {'Before EQ', 'Algorithm 2 (HMM-MSB)', 'Algorithm 1 (single-bank)', ...
         'SMNLMS', 'SM-sign-NLMS', 'Liu SS-LMS', 'Chen pulse-ref'};
ys  = cell(size(names));
dhs = cell(size(names));

% (1) No EQ
ys{1}  = r(:);
dhs{1} = local_slice_with_delay(r, cfg);

% (2) Algorithm 2 — HMM-MSB
[dhs{2}, diag2] = algorithm6_msb_v69(r, d, cfg, v_base, msb, ch_state.state);
ys{2}  = local_diag_output(diag2, r, cfg);

% (3) Algorithm 1 — single-bank
[dhs{3}, diag3] = algorithm5_singlebank(r, d, cfg, v_base);
ys{3}  = local_diag_output(diag3, r, cfg);

% (4) SMNLMS
[ys{4}, dhs{4}] = dfe_smnlms_unified_x(r, d, cfg, base, sigma2);

% (5) SM-sign-NLMS
[ys{5}, dhs{5}] = dfe_smsign_nlms_unified_x(r, d, cfg, base, sigma2);

% (6) Liu SS-LMS
cfg_liu = cfg;
cfg_liu.Nb = max(cfg.Nb, 4);
v_liu = local_resize_v_for_nb_wrap(v_base, cfg, cfg_liu.Nb);
opts_liu = struct('adaptive_threshold', true, 'update_ffe', false, ...
    'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, 'use_projection', true);
[~, dhs{6}, diag_liu] = dfe_ss_lms_pam4(r, d, cfg_liu, v_liu, opts_liu);
ys{6} = local_diag_output(diag_liu, r, cfg);

% (7) Chen pulse-ref
[dhs{7}, chen_sum] = local_fixed_ffedfe_slicer_wrap( ...
    r, chen_w_ffe, chen_w_dfe, cfg.D, cfg.A);
ys{7} = chen_sum;

% ---- load pre-computed BER from checkpoint (avoids BER=0 from single run) ----
% Mapping: eye idx → checkpoint BER column
% eye: 1=BeforeEQ, 2=Alg2, 3=Alg1, 4=SMNLMS, 5=SM-sign-NLMS, 6=Liu, 7=Chen
ck_col   = [NaN, 1, 3, 7, 6, 8, 9];  % NaN = no checkpoint for Before EQ
ber_ck   = NaN(1, numel(names));
if opt.ber_from_checkpoint
    ck_file = fullfile(opt.save_dir, 'chunks', ...
        sprintf('snr%02d', round(opt.snr_db)), ...
        sprintf('blockA_snr%02d.mat', round(opt.snr_db)));
    if exist(ck_file, 'file')
        try
            ck = load(ck_file, 'out_snr');
            if isfield(ck,'out_snr') && isfield(ck.out_snr,'BER')
                ber_row = ck.out_snr.BER(1,:);
                for ki = 1:numel(names)
                    if ~isnan(ck_col(ki)) && ck_col(ki) <= numel(ber_row)
                        ber_ck(ki) = ber_row(ck_col(ki));
                    end
                end
            end
        catch
        end
    end
end

% ---- plot ----
stem_name = sprintf('BlockA_Eye_AllMethods_SNR%02d', round(opt.snr_db));
png_file  = fullfile(eye_dir, [stem_name '.png']);
ttl       = sprintf('PAM4 Markov-4SI eye diagrams (all methods), SNR = %g dB', opt.snr_db);

metrics = local_plot_eye_grid_standalone(ys, dhs, d, cfg, names, ttl, png_file, opt.fig_visible, ber_ck);
csv_file = fullfile(eye_dir, [stem_name '_metrics.csv']);
writetable(metrics, csv_file);

out = struct('png', png_file, 'csv', csv_file, 'metrics', metrics);
fprintf('[eye_snr%g] Saved %s\n', opt.snr_db, png_file);
end

% =========================================================================
% Thin wrappers to call local helpers from run_final_extra_figures_v72
% without duplicating code — delegates to the same private functions via
% a helper that is on the path.
% =========================================================================

function d = local_pam4_data(cfg)
% PAM4 symbol sequence — cfg.A is the level set e.g. [-3 -1 1 3]
M    = cfg.M;
A    = cfg.A;
Nsym = cfg.Nsym;
d    = A(randi(M, Nsym, 1));
d    = d(:);
end

function v = local_v_base_wrap(vars, cfg)
% Mirror local_v_base() from run_final_extra_figures_v72
v = make_v_alg5(vars.theorem);
K = cfg.Nf; L = cfg.Nb;
main_idx = round((K+1)/2);
v.main_idx = main_idx;
ffe_min = -v.w2_max * ones(K, 1);
ffe_max =  v.w2_max * ones(K, 1);
ffe_min(main_idx) = -Inf;
ffe_max(main_idx) =  Inf;
v.theta_min = [ffe_min; -v.b_max * ones(L, 1)];
v.theta_max = [ffe_max;  v.b_max * ones(L, 1)];
end

function v_liu = local_resize_v_for_nb_wrap(v_base, cfg, nb_new)
% Mirror local_resize_v_for_nb() from run_final_extra_figures_v72
v_liu = v_base;
if numel(v_liu.theta_min) ~= cfg.Nf + nb_new
    v_liu.theta_min = [v_base.theta_min(1:cfg.Nf); -v_base.b_max * ones(nb_new, 1)];
    v_liu.theta_max = [v_base.theta_max(1:cfg.Nf);  v_base.b_max * ones(nb_new, 1)];
end
end

function [w_ffe, w_dfe] = local_pulse_inverse_ffedfe(h, Nf, Nb, D)
% Mirror local_pulse_inverse_ffedfe() from run_final_extra_figures_v72
h = h(:);
M = numel(h);
Lconv = Nf + M - 1;
H = zeros(Lconv, Nf);
for k = 1:Nf
    H(k:k+M-1, k) = h;
end
e = zeros(Lconv, 1);
e(min(D+1, Lconv)) = 1;
w_ffe = (H.' * H + 1e-4*eye(Nf)) \ (H.' * e);
g = conv(w_ffe, h);
w_dfe = g(D+2 : min(D+1+Nb, numel(g)));
if numel(w_dfe) < Nb
    w_dfe(end+1:Nb) = 0;
end
w_dfe = w_dfe(:);
end

function [dh, y_sum] = local_fixed_ffedfe_slicer_wrap(r, w_ffe, w_dfe, D, A_pam)
% Fixed FFE+DFE slicer (Chen pulse-ref baseline)
y_ffe = filter(w_ffe(:), 1, r(:));
Nb    = numel(w_dfe);
y_sum = zeros(size(y_ffe));
d_hat = zeros(size(y_ffe));
levels = sort(A_pam(:));
for n = D+1 : numel(y_ffe)
    fb = 0;
    for k = 1:Nb
        if n-k >= 1
            fb = fb + w_dfe(k) * d_hat(n-k);
        end
    end
    y_sum(n) = y_ffe(n) + fb;
    [~, ii]  = min(abs(y_sum(n) - levels));
    d_hat(n) = levels(ii);
end
dh = d_hat;
end

function y = local_diag_output(diag, r, cfg)
% Mirror local_diag_output() from run_final_extra_figures_v72
if isstruct(diag) && isfield(diag, 'y_hist') && ~isempty(diag.y_hist)
    y = diag.y_hist(:);
elseif isstruct(diag) && isfield(diag, 'z_hist') && ~isempty(diag.z_hist)
    y = diag.z_hist(:);
else
    y = r(:);
end
if numel(y) < cfg.Nsym
    y(end+1:cfg.Nsym) = 0;
end
y = y(1:cfg.Nsym);
end

function dh = local_slice_with_delay(r, cfg)
% Mirror local_slice_with_delay() from run_final_extra_figures_v72 — applies delay D
dh = zeros(cfg.Nsym, 1);
for n = 1:min(numel(r), cfg.Nsym)
    m = n - cfg.D;
    if m >= 1 && m <= cfg.Nsym
        dh(m) = pam_slice_scalar(r(n), cfg.A);
    end
end
end

function metrics = local_plot_eye_grid_standalone(ys, dhs, d, cfg, names, ttl, fname, fig_vis, ber_ck)
if nargin < 9, ber_ck = NaN(1, numel(ys)); end
sps = 16;
try
    g = rc_pulse(0.5, sps, 8);
catch
    g = ones(sps, 1) / sps;
end

% Upsample + RC-filter each signal to get proper eye waveform
waves    = cell(size(ys));
all_wave = [];
for k = 1:numel(ys)
    waves{k} = local_symbol_to_eye_waveform(ys{k}, g, sps);
    x = waves{k};
    x = x(isfinite(x));
    if numel(x) > 8000
        x = x(round(linspace(1, numel(x), 8000)));
    end
    all_wave = [all_wave; x]; %#ok<AGROW>
end

yl = local_common_ylim_standalone(all_wave);

% PAM4 decision thresholds (midpoints between adjacent levels)
A_sorted = sort(cfg.A(:));
thresholds = 0.5 * (A_sorted(1:end-1) + A_sorted(2:end));

% Fixed colors matching run_mb_ber_compare style
fixed_cols = {[0.15 0.15 0.15], [0 0.45 0.74], [0.85 0.33 0.10], ...
              [0.49 0.18 0.56], [0.30 0.75 0.93], [0.64 0.08 0.18], ...
              [0.25 0.25 0.25]};
n    = numel(ys);
nrow = ceil(sqrt(n));
ncol = ceil(n / nrow);

fig = figure('Color','w','Visible', fig_vis, 'Position',[60 60 1450 900]);
tiledlayout(nrow, ncol, 'Padding','compact', 'TileSpacing','compact');
metrics = table();

for k = 1:n
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    col = fixed_cols{min(k, numel(fixed_cols))};

    % Plot eye waveform traces via eye_plot_reshape_fixed
    if ~isempty(waves{k})
        eye_plot_reshape_fixed(waves{k}, sps, 'max_traces', 150, ...
            'color', col, 'line_width', 0.22);
    end

    % Draw PAM4 decision threshold lines
    for ti = 1:numel(thresholds)
        th = thresholds(ti);
        if isfinite(th) && th >= yl(1) && th <= yl(2)
            plot(ax, [0 2], [th th], ':', 'Color', [0.35 0.35 0.35], ...
                'LineWidth', 0.55, 'HandleVisibility','off');
        end
    end

    ylim(ax, yl); xlim(ax, [0 2]);

    eh = NaN; ew = NaN;
    try
        met = compute_eye_height_width_metrics(ys{k}, d, cfg);
        eh  = met.eye_height_5_95;
        ew  = met.eye_width_ui;
    catch
    end
    % Use checkpoint BER if available (Monte Carlo average), else compute from this run
    ber = NaN;
    if k <= numel(ber_ck) && ~isnan(ber_ck(k))
        ber = ber_ck(k);
    else
        try
            ber = ser_after_training_aligned(d, dhs{k}, cfg) / log2(cfg.M);
        catch
        end
    end
    if isnan(ber) || isnan(eh)
        title_str = names{k};
    else
        title_str = sprintf('%s\nBER=%.2e | EH=%.3f | EW=%.3fUI', names{k}, ber, eh, ew);
    end
    title(ax, title_str, 'FontSize',9,'FontWeight','bold','Interpreter','none');
    xlabel(ax,'Time (UI)'); ylabel(ax,'Amplitude');
    set(ax, 'FontSize', 9);
    metrics = [metrics; table(string(names{k}), ber, eh, ew, ...
        'VariableNames',{'Method','BER','EyeHeight','EyeWidth'})]; %#ok<AGROW>
end

sgtitle(ttl, 'FontWeight','bold');
try
    exportgraphics(fig, fname, 'Resolution', 300);
catch
    saveas(fig, fname);
end
try
    savefig(fig, strrep(fname, '.png', '.fig'));
catch
end
close(fig);
end

function xos = local_symbol_to_eye_waveform(x, g, sps)
% Upsample by sps (zero-insert), convolve with RC pulse, restore amplitude.
% rc_pulse normalizes by sum(|g|) ≈ sps, so multiply by sps to compensate.
x = x(:);
x = x(isfinite(x));
if numel(x) < 4
    xos = [];
    return;
end
y = zeros(numel(x) * sps, 1);
y(1:sps:end) = x;
xos = conv(y, g, 'same') * sps;
end

function yl = local_common_ylim_standalone(x)
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
