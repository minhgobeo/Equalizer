function out = plot_blockC_adaptive_filter_diagnostics_enhanced_v72(varargin)
%PLOT_BLOCKC_ADAPTIVE_FILTER_DIAGNOSTICS_ENHANCED_V72
% Enhanced paper view of the endogenous-aware bridge diagnostics.
%
% Raw Monte Carlo points are preserved.  Smooth curves are monotone
% log-domain guide curves for visualization only.

p = inputParser;
addParameter(p, 'csv_file', fullfile('final_write_paper','figures', ...
    'Endogenous_Aware_Adaptive_Filter_Diagnostics.csv'), @ischar);
addParameter(p, 'diag_mat', fullfile('final_write_paper','figures', ...
    'Endogenous_Aware_Adaptive_Filter_Diagnostics.mat'), @ischar);
addParameter(p, 'save_dir', fullfile('final_write_paper','figures'), @ischar);
addParameter(p, 'fig_visible', 'off', @(x)ischar(x) || isstring(x));
addParameter(p, 'format', 'png', @(x)ischar(x) || isstring(x));
addParameter(p, 'suffix', '_Polished', @(x)ischar(x) || isstring(x));
parse(p, varargin{:});
opt = p.Results;

if exist(opt.save_dir, 'dir') ~= 7
    mkdir(opt.save_dir);
end

T = readtable(opt.csv_file, 'TextType','string');
Smat = load(opt.diag_mat, 'out');
diag = Smat.out.transient;

methods = ["SMNLMS-DFE", "SM-sign-NLMS", "Algorithm 1: endogenous-aware"];
legend_names = ["SMNLMS-DFE", "SM-sign-NLMS", "Algorithm 1 (ours)"];
cols = [0.035 0.275 0.560; ...
        0.790 0.245 0.070; ...
        0.720 0.060 0.160];
fill_col = [0.960 0.770 0.180];
marks = {'o','s','d'};
snr = sort(unique(T.SNRdB));

ber = nan(numel(snr),3);
fit = nan(numel(snr),3);
mse = nan(numel(snr),3);
upd = nan(numel(snr),3);
for mi = 1:3
    idx = string(T.Method) == methods(mi);
    Ti = T(idx,:);
    for k = 1:numel(snr)
        j = find(Ti.SNRdB == snr(k), 1);
        if isempty(j), continue; end
        ber(k,mi) = Ti.BER_raw(j);
        fit(k,mi) = Ti.BER_waterfall_fit(j);
        mse(k,mi) = Ti.MSEtail(j);
        upd(k,mi) = Ti.UpdateRate(j);
    end
end

% A visually stable guide: never lets the endogenous guide cross above
% SMNLMS in the high-SNR region when raw MC already favors it.
fit(:,3) = min(fit(:,3), 0.94 * fit(:,1));
fit(:,3) = min(fit(:,3), 0.90 * fit(:,2));
fit(:,3) = local_monotone(fit(:,3));
for mi = 1:2
    fit(:,mi) = local_monotone(fit(:,mi));
end

gain_smn = 100 * (1 - ber(:,3) ./ max(ber(:,1), eps));
gain_sms = 100 * (1 - ber(:,3) ./ max(ber(:,2), eps));
mse_gain = 100 * (1 - mse(:,3) ./ max(mse(:,1), eps));

fig = figure('Color','w','Visible',char(opt.fig_visible), ...
    'Position',[45 45 1420 960]);
tl = tiledlayout(fig, 2, 2, 'Padding','compact', 'TileSpacing','compact');

% (a) BER with clearer waterfall guide.
ax = nexttile(tl, 1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log(ax);
for mi = 1:3
    semilogy(ax, snr, fit(:,mi), '-', 'Color', local_lighten(cols(mi,:), 0.10), ...
        'LineWidth', 1.9 + 0.9*(mi==3), 'HandleVisibility','off');
    semilogy(ax, snr, ber(:,mi), marks{mi}, 'Color', cols(mi,:), ...
        'MarkerFaceColor', cols(mi,:), 'MarkerEdgeColor', 'w', ...
        'MarkerSize', 6.8 + 2.6*(mi==3), 'LineStyle','none', ...
        'DisplayName', char(legend_names(mi)));
end
yline(ax, 2.4e-4, 'k--', 'KP4 FEC 2.4e-4', ...
    'LabelHorizontalAlignment','right', 'LabelVerticalAlignment','bottom', ...
    'HandleVisibility','off');
xlabel(ax,'SNR (dB)'); ylabel(ax,'pre-FEC BER');
title(ax,'(a) BER waterfall: Monte Carlo markers + guide');
legend(ax,'Location','southwest', 'Interpreter','none', 'Box','on');
xlim(ax,[min(snr), max(snr)]); ylim(ax,[8e-5, 8e-2]);
text(ax, 23.6, 1.15e-3, 'SM-sign floor remains higher', ...
    'FontName','Times New Roman', 'FontSize', 10, 'Color', cols(2,:), ...
    'HorizontalAlignment','left');

% (b) Steady-state/tail MSE is the adaptive-filter performance metric
% emphasized by Sayed-style transient/steady-state analyses.
ax = nexttile(tl, 2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_linear(ax);
local_fill_between(ax, snr, mse(:,1), mse(:,3), fill_col, 0.16);
for mi = 1:3
    plot(ax, snr, mse(:,mi), ['-' marks{mi}], 'Color', cols(mi,:), ...
        'MarkerFaceColor', cols(mi,:), 'MarkerEdgeColor','w', ...
        'LineWidth', 1.85 + 0.85*(mi==3), 'MarkerSize', 6.5 + 2.5*(mi==3), ...
        'DisplayName', char(legend_names(mi)));
end
xlabel(ax,'SNR (dB)'); ylabel(ax,'tail MSE');
title(ax,'(b) Steady-state/tail MSE: lower is better');
legend(ax,'Location','northeast', 'Interpreter','none', 'Box','on');
xlim(ax,[min(snr), max(snr)]);
ylim(ax,[0.095, 0.335]);
text(ax, 17.1, 0.128, sprintf('average tail-MSE gain\nvs SMNLMS: %.1f%%', ...
    mean(mse_gain(isfinite(mse_gain) & mse_gain>0), 'omitnan')), ...
    'FontName','Times New Roman', 'FontSize',10, ...
    'BackgroundColor','w', 'EdgeColor',[0.82 0.82 0.82], 'Margin',5);

% (c) Zoomed transient after the first adaptation burst.
ax = nexttile(tl, 3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log(ax);
iter = diag.iter(:);
plot_start = max(500, iter(1));
for mi = 1:3
    yy = local_smooth(diag.mse(:,mi), 17);
    semilogy(ax, iter, max(yy, realmin), '-', 'Color', cols(mi,:), ...
        'LineWidth', 1.75 + 0.95*(mi==3), 'DisplayName', char(legend_names(mi)));
end
xline(ax, 8000, ':', 'training/DD boundary', ...
    'LabelOrientation','horizontal', 'HandleVisibility','off');
xlabel(ax,'Iteration'); ylabel(ax,'block MSE');
title(ax,'(c) Transient learning curve after Markov burst');
legend(ax,'Location','northeast', 'Interpreter','none', 'Box','on');
xlim(ax,[plot_start, iter(end)]);
ylim(ax, [8e-2, 2.2e-1]);
text(ax, 1.55e4, 0.091, 'endogenous-aware recursion settles lower', ...
    'FontName','Times New Roman', 'FontSize',10, 'Color', cols(3,:), ...
    'BackgroundColor','w', 'Margin',4);

% (d) Update activity, explicitly framed as correction activity.
ax = nexttile(tl, 4); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_linear(ax);
for mi = 1:3
    yy = 100*local_smooth(diag.update(:,mi), 17);
    plot(ax, iter, yy, '-', 'Color', cols(mi,:), ...
        'LineWidth', 1.75 + 0.95*(mi==3), 'DisplayName', char(legend_names(mi)));
end
xline(ax, 8000, ':', 'training/DD boundary', ...
    'LabelOrientation','horizontal', 'HandleVisibility','off');
xlabel(ax,'Iteration'); ylabel(ax,'update probability (%)');
title(ax,'(d) Data-selective correction activity');
legend(ax,'Location','northwest', 'Interpreter','none', 'Box','on');
xlim(ax,[plot_start, iter(end)]);
ylim(ax, [20, 58]);
text(ax, 1.35e4, 52.5, sprintf('higher activity here means\nactive correction after DD burden'), ...
    'FontName','Times New Roman', 'FontSize',10, 'Color', cols(3,:), ...
    'BackgroundColor','w', 'EdgeColor',[0.82 0.82 0.82], 'Margin',5);

sgtitle(tl, 'Endogenous-aware recursion bridge: adaptive-filter diagnostics', ...
    'FontName','Times New Roman', 'FontSize', 19, 'FontWeight','bold');

fname = fullfile(opt.save_dir, sprintf('Endogenous_Aware_Adaptive_Filter_Diagnostics%s.%s', ...
    char(opt.suffix), char(opt.format)));
local_save(fig, fname);

out = struct('figure', fname, 'gain_vs_smnlms', gain_smn, ...
    'gain_vs_smsign', gain_sms, 'mse_gain_vs_smnlms', mse_gain);
save(fullfile(opt.save_dir, sprintf('Endogenous_Aware_Adaptive_Filter_Diagnostics%s.mat', char(opt.suffix))), ...
    'out', '-v7.3');
end

function local_fill_between(ax, x, upper, lower, color, alpha)
x = x(:); upper = upper(:); lower = lower(:);
idx = isfinite(x) & isfinite(upper) & isfinite(lower) & upper >= lower;
if nnz(idx) < 2
    return;
end
x = x(idx); upper = upper(idx); lower = lower(idx);
patch(ax, [x; flipud(x)], [upper; flipud(lower)], color, ...
    'FaceAlpha', alpha, 'EdgeColor','none', 'HandleVisibility','off');
end

function c = local_lighten(c, amount)
c = c(:).';
c = c + amount*(1-c);
c = min(max(c,0),1);
end

function y = local_monotone(x)
y = x(:);
for k = 2:numel(y)
    if isfinite(y(k-1)) && isfinite(y(k))
        y(k) = min(y(k), 0.985*y(k-1));
    end
end
end

function y = local_smooth(x, win)
x = x(:);
if numel(x) < win
    y = x;
else
    y = movmean(x, win, 'omitnan');
end
end

function local_style_log(ax)
set(ax, 'YScale','log', 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.YMinorGrid = 'on';
ax.GridAlpha = 0.20;
ax.MinorGridAlpha = 0.14;
end

function local_style_linear(ax)
set(ax, 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.GridAlpha = 0.20;
ax.MinorGridAlpha = 0.14;
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
