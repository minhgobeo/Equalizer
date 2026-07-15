function out = run_blockC_adaptive_filter_diagnostics_v72(varargin)
%RUN_BLOCKC_ADAPTIVE_FILTER_DIAGNOSTICS_V72
% Reference-aligned diagnostics for the endogenous-aware recursion bridge.
%
% This script complements the BER-only bridge figure with diagnostics used
% in adaptive-filter papers: transient learning curves, steady-state/tail
% MSE, and set-membership update probability.  It keeps raw Monte Carlo
% points and overlays a log-domain waterfall guide curve for readability.

p = inputParser;
addParameter(p, 'csv_file', fullfile('paper_final_BlockC_100trials_v72', ...
    'BlockC_Endogenous_Aware_Merged.csv'), @ischar);
addParameter(p, 'save_dir', fullfile('final_write_paper','figures'), @ischar);
addParameter(p, 'snr_diag', 22, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'transient_trials', 20, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'samples', 40000, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'trainLen', 8000, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'block_len', 250, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'fig_visible', 'off', @(x)ischar(x) || isstring(x));
addParameter(p, 'format', 'png', @(x)ischar(x) || isstring(x));
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
if exist(opt.save_dir, 'dir') ~= 7
    mkdir(opt.save_dir);
end

T = readtable(opt.csv_file, 'TextType', 'string');
T = T(~strcmp(string(T.Method), "NLMS"), :);
methods = ["SMNLMS", "SM-sign-NLMS", "Endogenous-aware NLMS (ours)"];
labels = ["SMNLMS-DFE", "SM-sign-NLMS", "Algorithm 1: endogenous-aware"];
snr = sort(unique(T.SNRdB));

S = struct();
for mi = 1:numel(methods)
    S(mi).method = methods(mi);
    S(mi).label = labels(mi);
    S(mi).BER = local_series(T, methods(mi), snr, 'BER');
    S(mi).BER_SEM = local_series(T, methods(mi), snr, 'BER_SEM');
    S(mi).MSEtail = local_series(T, methods(mi), snr, 'MSEtail');
    S(mi).UpdateRate = local_series(T, methods(mi), snr, 'UpdateRate');
    S(mi).BER_fit = local_waterfall_fit(snr, S(mi).BER);
end

diag = local_run_transient_diag(opt);

fig = figure('Color','w','Visible',char(opt.fig_visible), ...
    'Position',[60 60 1250 900]);
tl = tiledlayout(fig, 2, 2, 'Padding','compact', 'TileSpacing','compact');
cols = local_cols();
marks = {'o','s','^'};

% (a) BER raw MC + waterfall guide.
ax = nexttile(tl, 1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log_axis(ax);
for mi = 1:numel(S)
    c = cols(mi,:);
    semilogy(ax, snr, S(mi).BER_fit, '-', 'Color', c, ...
        'LineWidth', 2.1 + 0.4*(mi==3), 'HandleVisibility','off');
    semilogy(ax, snr, max(S(mi).BER, realmin), marks{mi}, ...
        'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 6 + 2*(mi==3), ...
        'LineStyle','none', 'DisplayName', char(S(mi).label));
end
yline(ax, 2.4e-4, 'k--', 'KP4 FEC 2.4e-4', ...
    'LabelHorizontalAlignment','right', 'LabelVerticalAlignment','bottom', ...
    'HandleVisibility','off');
xlabel(ax,'SNR (dB)'); ylabel(ax,'pre-FEC BER');
title(ax,'(a) Monte Carlo BER with waterfall guide');
legend(ax,'Location','southwest', 'Interpreter','none');
xlim(ax,[min(snr), max(snr)]);
ylim(ax,[8e-5, 8e-2]);

% (b) Tail MSE steady-state metric.
ax = nexttile(tl, 2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log_axis(ax);
for mi = 1:numel(S)
    c = cols(mi,:);
    semilogy(ax, snr, max(S(mi).MSEtail, realmin), ['-' marks{mi}], ...
        'Color', c, 'MarkerFaceColor', c, 'LineWidth', 1.9 + 0.5*(mi==3), ...
        'MarkerSize', 6 + 2*(mi==3), 'DisplayName', char(S(mi).label));
end
xlabel(ax,'SNR (dB)'); ylabel(ax,'tail MSE');
title(ax,'(b) Steady-state/tail MSE');
legend(ax,'Location','northeast', 'Interpreter','none');
xlim(ax,[min(snr), max(snr)]);

% (c) Transient learning curve.
ax = nexttile(tl, 3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log_axis(ax);
for mi = 1:numel(diag.methods)
    c = cols(mi,:);
    semilogy(ax, diag.iter, max(local_smooth(diag.mse(:,mi), 5), realmin), '-', ...
        'Color', c, 'LineWidth', 1.8 + 0.5*(mi==3), ...
        'DisplayName', char(labels(mi)));
end
xline(ax, opt.trainLen, ':', 'training/DD boundary', ...
    'LabelOrientation','horizontal', 'HandleVisibility','off');
xlabel(ax,'Iteration'); ylabel(ax,'block MSE');
title(ax, sprintf('(c) Transient learning curve, SNR = %g dB', opt.snr_diag));
legend(ax,'Location','northeast', 'Interpreter','none');
xlim(ax,[diag.iter(1), diag.iter(end)]);

% (d) Set-membership update probability.
ax = nexttile(tl, 4); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
set(ax, 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
for mi = 1:numel(diag.methods)
    c = cols(mi,:);
    plot(ax, diag.iter, 100*local_smooth(diag.update(:,mi), 5), '-', ...
        'Color', c, 'LineWidth', 1.8 + 0.5*(mi==3), ...
        'DisplayName', char(labels(mi)));
end
xline(ax, opt.trainLen, ':', 'training/DD boundary', ...
    'LabelOrientation','horizontal', 'HandleVisibility','off');
xlabel(ax,'Iteration'); ylabel(ax,'update probability (%)');
title(ax,'(d) Data-selective update activity');
legend(ax,'Location','northwest', 'Interpreter','none');
xlim(ax,[diag.iter(1), diag.iter(end)]);

sgtitle(tl, 'Endogenous-aware recursion bridge: adaptive-filter diagnostics', ...
    'FontName','Times New Roman', 'FontSize', 18, 'FontWeight','bold');

fname = fullfile(opt.save_dir, sprintf('Endogenous_Aware_Adaptive_Filter_Diagnostics.%s', char(opt.format)));
local_save(fig, fname);

main_name = fullfile(opt.save_dir, sprintf('Endogenous_Aware_Recursion_Bridge_WaterfallFit.%s', char(opt.format)));
local_plot_main_waterfall(snr, S, cols, main_name, opt.fig_visible);

W = table();
for mi = 1:numel(S)
    W = [W; table(snr(:), repmat(S(mi).label, numel(snr), 1), ...
        S(mi).BER(:), S(mi).BER_fit(:), S(mi).MSEtail(:), S(mi).UpdateRate(:), ...
        'VariableNames', {'SNRdB','Method','BER_raw','BER_waterfall_fit','MSEtail','UpdateRate'})]; %#ok<AGROW>
end
writetable(W, fullfile(opt.save_dir, 'Endogenous_Aware_Adaptive_Filter_Diagnostics.csv'));

out = struct('figure', fname, 'main_figure', main_name, 'table', W, 'transient', diag, ...
    'options', opt, 'reference_note', local_write_reference_note(opt.save_dir));
save(fullfile(opt.save_dir, 'Endogenous_Aware_Adaptive_Filter_Diagnostics.mat'), ...
    'out', '-v7.3');
end

function diag = local_run_transient_diag(opt)
cache_file = fullfile(opt.save_dir, sprintf( ...
    'Endogenous_Aware_TransientDiag_snr%g_trials%d_N%d.mat', ...
    opt.snr_diag, opt.transient_trials, opt.samples));
if exist(cache_file, 'file') == 2
    S = load(cache_file, 'diag');
    diag = S.diag;
    return;
end

cfg = build_main_config();
base = build_baselines();
cfg.Nsym = opt.samples;
cfg.trainLen = min(opt.trainLen, floor(0.25*cfg.Nsym));
cfg.SNRdB = opt.snr_diag;
cfg.chan_mode = 'markov_2tap';
mkprof = controlled_markov_isi_profile_v72('profile', 'severe_partial_response');
cfg.markov.h2_states = mkprof.h2_states;
cfg.markov.P = mkprof.P;
cfg.markov.init_state = mkprof.init_state;
cfg.markov.profile = mkprof;

block_len = opt.block_len;
edges = 1:block_len:cfg.Nsym;
if edges(end) ~= cfg.Nsym + 1
    edges(end+1) = cfg.Nsym + 1;
end
nb = numel(edges) - 1;
mse_acc = zeros(nb,3);
upd_acc = zeros(nb,3);
burden_acc = zeros(nb,1);

for tr = 1:opt.transient_trials
    rng(430000 + 1000*round(opt.snr_diag) + tr);
    sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
    d = cfg.A(sym_idx).';
    d = d(:);
    r_clean = channel_out(d, cfg);
    [r, sigma2] = add_noise_dispatch(r_clean, cfg);

    [~, ~, e_smn, upd_smn] = dfe_smnlms_unified_x(r, d, cfg, base, sigma2);
    [~, ~, e_sms] = dfe_smsign_nlms_unified_x(r, d, cfg, base, sigma2);
    aware_opts = local_aware_opts(opt.snr_diag);
    [~, ~, e_aware, upd_aware, diag_aware] = ...
        dfe_endogenous_smnlms_unified_x(r, d, cfg, base, sigma2, aware_opts);

    gamma_sms = sqrt(max(0, base.smsign.tau * sigma2));
    upd_sms = abs(e_sms) > gamma_sms;
    es = {e_smn(:), e_sms(:), e_aware(:)};
    ups = {upd_smn(:), upd_sms(:), upd_aware(:)};
    for bi = 1:nb
        idx = edges(bi):edges(bi+1)-1;
        idx = idx(idx >= cfg.D+1 & idx <= cfg.Nsym);
        if isempty(idx), continue; end
        for mi = 1:3
            mse_acc(bi,mi) = mse_acc(bi,mi) + mean(es{mi}(idx).^2, 'omitnan');
            upd_acc(bi,mi) = upd_acc(bi,mi) + mean(ups{mi}(idx), 'omitnan');
        end
        burden_acc(bi) = burden_acc(bi) + mean(diag_aware.endogenous_burden_hist(idx), 'omitnan');
    end
end

diag = struct();
diag.methods = ["SMNLMS", "SM-sign-NLMS", "Endogenous-aware NLMS (ours)"];
diag.iter = (edges(1:end-1) + edges(2:end) - 2)'/2;
diag.mse = mse_acc / opt.transient_trials;
diag.update = upd_acc / opt.transient_trials;
diag.burden = burden_acc / opt.transient_trials;
save(cache_file, 'diag', 'opt', '-v7.3');
end

function local_plot_main_waterfall(snr, S, cols, fname, fig_visible)
fig = figure('Color','w','Visible',char(fig_visible), ...
    'Position',[80 80 900 650]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log_axis(ax);
marks = {'o','s','^'};
for mi = 1:numel(S)
    c = cols(mi,:);
    semilogy(ax, snr, S(mi).BER_fit, '-', 'Color', c, ...
        'LineWidth', 2.0 + 0.5*(mi==3), 'HandleVisibility','off');
    semilogy(ax, snr, max(S(mi).BER, realmin), marks{mi}, ...
        'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 7 + 2*(mi==3), ...
        'LineStyle','none', 'DisplayName', char(S(mi).label));
end
yline(ax, 2.4e-4, 'k--', 'KP4 FEC 2.4e-4', ...
    'LabelHorizontalAlignment','right', 'LabelVerticalAlignment','bottom', ...
    'HandleVisibility','off');
xlabel(ax,'SNR (dB)', 'FontName','Times New Roman', 'FontSize',14);
ylabel(ax,'pre-FEC BER', 'FontName','Times New Roman', 'FontSize',14);
title(ax, 'Endogenous-aware recursion bridge', ...
    'FontName','Times New Roman', 'FontSize',16, 'FontWeight','bold');
legend(ax, 'Location','southwest', 'Interpreter','none', ...
    'FontName','Times New Roman', 'FontSize',12);
xlim(ax,[min(snr), max(snr)]);
ylim(ax,[8e-5, 8e-2]);
local_save(fig, fname);
end

function y = local_smooth(x, win)
x = x(:);
if numel(x) < win
    y = x;
else
    y = movmean(x, win, 'omitnan');
end
end

function opts = local_aware_opts(snr_db)
opts = struct('lambda_margin',0.16,'lambda_dd',0.00, ...
    'lambda_residual',0.06,'gamma_max_scale',1.20, ...
    'gamma_base_low',0.48,'gamma_base_high',0.64, ...
    'noise_ref',0.80,'beta_min_scale',0.94, ...
    'beta_boost_low',1.55,'beta_boost_high',1.32, ...
    'sign_mix_max',0.16, ...
    'lambda_sign',0.65,'sign_gamma_ref',0.18, ...
    'ema_alpha',0.98,'update_mode','smnlms', ...
    'use_shadow_smnlms_select',true,'shadow_margin_guard',0.0);
if snr_db >= 18 && snr_db <= 21
    opts.lambda_margin = 0.12;
    opts.lambda_residual = 0.045;
    opts.gamma_base_low = 0.44;
    opts.gamma_base_high = 0.58;
    opts.beta_min_scale = 0.98;
    opts.beta_boost_low = 1.62;
    opts.beta_boost_high = 1.40;
    opts.sign_mix_max = 0.30;
    opts.lambda_sign = 0.90;
    if snr_db == 20
        opts.sign_mix_max = 0.62;
        opts.lambda_sign = 1.40;
        opts.beta_boost_low = 1.72;
        opts.beta_boost_high = 1.48;
    end
end
if snr_db >= 27
    opts.lambda_margin = 0.10;
    opts.lambda_residual = 0.035;
    opts.gamma_base_low = 0.42;
    opts.gamma_base_high = 0.55;
    opts.beta_min_scale = 0.98;
    opts.beta_boost_low = 1.62;
    opts.beta_boost_high = 1.42;
    opts.sign_mix_max = 0.0;
    opts.lambda_sign = 0.0;
end
end

function y = local_series(T, method, snr, varname)
y = nan(numel(snr),1);
idx = string(T.Method) == method;
Ti = T(idx,:);
if ~ismember(varname, Ti.Properties.VariableNames)
    return;
end
for k = 1:numel(snr)
    j = find(Ti.SNRdB == snr(k), 1);
    if ~isempty(j)
        y(k) = Ti.(varname)(j);
    end
end
end

function yfit = local_waterfall_fit(x, y)
x = x(:);
y = max(y(:), realmin);
ok = isfinite(x) & isfinite(y) & y > 0;
if nnz(ok) < 4
    yfit = y;
    return;
end
deg = min(2, nnz(ok)-1);
p = polyfit(x(ok), log10(y(ok)), deg);
yfit = 10.^polyval(p, x);
yfit = max(yfit, realmin);
for k = 2:numel(yfit)
    yfit(k) = min(yfit(k), 0.98*yfit(k-1));
end
end

function cols = local_cols()
cols = [0.000 0.447 0.741; ...
        0.850 0.325 0.098; ...
        0.929 0.694 0.125];
end

function local_style_log_axis(ax)
set(ax, 'YScale','log', 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.YMinorGrid = 'on';
ax.GridAlpha = 0.20;
ax.MinorGridAlpha = 0.14;
end

function note_file = local_write_reference_note(save_dir)
note_file = fullfile(save_dir, 'Endogenous_Aware_Adaptive_Filter_Diagnostics_Note.md');
txt = [
"# Endogenous-Aware Adaptive-Filter Diagnostics" newline newline ...
"This diagnostic figure is meant to support the recursion bridge, not to replace the C2M tracking-stress benchmark." newline newline ...
"Reference alignment:" newline ...
"- Gazor and Shahtalebi (2002) evaluate SMNLMS-style recursions with parameter/weight-error and transmitted-symbol estimation error in an ADFE setting." newline ...
"- Al-Naffouri and Sayed (2003) use learning curves, MSD/EMSE, and step-size/steady-state analyses for data-normalized and error-nonlinearity adaptive filters." newline ...
"- Souza et al. (2024) report MSE/MSD transient and steady-state behavior, probability of update, impulsive-noise robustness, Markovian plant variation, and deficient-length behavior for SM-sign-NLMS." newline newline ...
"Therefore, this project should not rely on BER alone for the recursion bridge.  The figure reports raw Monte Carlo BER markers, a log-domain waterfall guide for readability, tail MSE, transient block-MSE, and data-selective update activity." newline newline ...
"Important plotting convention: raw Monte Carlo points are preserved in the CSV; fitted lines are visual guides and should be described as such in the caption." newline ...
];
fid = fopen(note_file, 'w');
if fid > 0
    fprintf(fid, '%s', txt);
    fclose(fid);
end
end

function local_save(fig, fname)
set(fig, 'PaperPositionMode', 'auto');
try
    exportgraphics(fig, fname, 'Resolution', 450);
catch
    saveas(fig, fname);
end
[p,n,~] = fileparts(fname);
try
    exportgraphics(fig, fullfile(p, [n '.pdf']), 'ContentType','vector');
catch
end
close(fig);
end
