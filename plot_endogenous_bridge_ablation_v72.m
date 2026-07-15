function out = plot_endogenous_bridge_ablation_v72(varargin)
%PLOT_ENDOGENOUS_BRIDGE_ABLATION_V72
% Paper-ready ablation figure for the endogenous-aware recursion bridge.
%
% Unlike Block-B C2M tracking-stress plots, this figure is not an
% application benchmark.  It isolates the single-bank update mechanism on a
% controlled Markov-ISI channel and visualizes why the endogenous-aware
% recursion is useful before the full MSB architecture is introduced.

p = inputParser;
addParameter(p, 'csv_file', fullfile('paper_final_BlockC_100trials_v72', ...
    'BlockC_Endogenous_Aware_Merged.csv'), @ischar);
addParameter(p, 'save_dir', fullfile('final_write_paper','figures'), @ischar);
addParameter(p, 'fig_visible', 'off', @(x)ischar(x) || isstring(x));
addParameter(p, 'format', 'png', @(x)ischar(x) || isstring(x));
parse(p, varargin{:});
opt = p.Results;

if exist(opt.save_dir, 'dir') ~= 7
    mkdir(opt.save_dir);
end
T = readtable(opt.csv_file, 'TextType', 'string');
T = T(~strcmp(string(T.Method), "NLMS"), :);

snr = unique(T.SNRdB);
snr = sort(snr(:));
smn = local_series(T, "SMNLMS", snr);
sms = local_series(T, "SM-sign-NLMS", snr);
aware = local_series(T, "Endogenous-aware NLMS (ours)", snr);

gain_smn = 100 * (1 - aware.BER ./ max(smn.BER, eps));
gain_sms = 100 * (1 - aware.BER ./ max(sms.BER, eps));

fig = figure('Color','w','Visible',char(opt.fig_visible), ...
    'Position',[60 60 1250 760]);
tl = tiledlayout(fig, 2, 2, 'Padding','compact', 'TileSpacing','compact');

cols = struct();
cols.smn = [0.000 0.447 0.741];
cols.sms = [0.850 0.325 0.098];
cols.aware = [0.929 0.694 0.125];
cols.gray = [0.35 0.35 0.35];

% (a) BER Monte Carlo curves.
ax = nexttile(tl, 1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
set(ax, 'YScale','log', 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.YMinorGrid = 'on'; ax.GridAlpha = 0.20; ax.MinorGridAlpha = 0.12;
semilogy(ax, snr, smn.BER, '-o', 'Color', cols.smn, 'MarkerFaceColor', cols.smn, ...
    'LineWidth', 1.8, 'MarkerSize', 6, 'DisplayName','SMNLMS');
semilogy(ax, snr, sms.BER, '-s', 'Color', cols.sms, 'MarkerFaceColor', cols.sms, ...
    'LineWidth', 1.8, 'MarkerSize', 6, 'DisplayName','SM-sign-NLMS');
semilogy(ax, snr, aware.BER, '-^', 'Color', cols.aware, 'MarkerFaceColor', cols.aware, ...
    'LineWidth', 2.3, 'MarkerSize', 7, 'DisplayName','Endogenous-aware');
yline(ax, 2.4e-4, 'k--', 'KP4 FEC 2.4e-4', 'HandleVisibility','off');
xlabel(ax,'SNR (dB)'); ylabel(ax,'pre-FEC BER');
title(ax,'(a) Monte Carlo BER on controlled Markov-ISI');
legend(ax, 'Location','southwest');
ylim(ax,[1e-4 8e-2]); xlim(ax,[min(snr) max(snr)]);

% (b) Relative reduction: this is the key bridge panel.
ax = nexttile(tl, 2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
set(ax, 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in');
plot(ax, snr, gain_smn, '-o', 'Color', cols.smn, 'MarkerFaceColor', cols.smn, ...
    'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName','vs. SMNLMS');
plot(ax, snr, gain_sms, '-s', 'Color', cols.sms, 'MarkerFaceColor', cols.sms, ...
    'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName','vs. SM-sign-NLMS');
yline(ax, 0, 'k:', 'HandleVisibility','off');
xlabel(ax,'SNR (dB)'); ylabel(ax,'BER reduction (%)');
title(ax,'(b) Endogenous-aware single-bank gain');
legend(ax, 'Location','northwest');
xlim(ax,[min(snr) max(snr)]);
ylim(ax, [min(-5, floor(min([gain_smn; gain_sms])-3)), max(75, ceil(max([gain_smn; gain_sms])+5))]);

% (c) Update activity shows how the recursion differs from plain SMNLMS.
ax = nexttile(tl, 3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
set(ax, 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in');
plot(ax, snr, 100*smn.UpdateRate, '-o', 'Color', cols.smn, ...
    'MarkerFaceColor', cols.smn, 'LineWidth', 1.8, 'MarkerSize', 6, ...
    'DisplayName','SMNLMS update rate');
plot(ax, snr, 100*aware.UpdateRate, '-^', 'Color', cols.aware, ...
    'MarkerFaceColor', cols.aware, 'LineWidth', 2.3, 'MarkerSize', 7, ...
    'DisplayName','Endogenous-aware update rate');
xlabel(ax,'SNR (dB)'); ylabel('update rate (%)');
title(ax,'(c) Set-membership update activity');
legend(ax, 'Location','northwest');
xlim(ax,[min(snr) max(snr)]);

% (d) Burden proxy and experiment identity.
ax = nexttile(tl, 4); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
set(ax, 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in');
plot(ax, snr, aware.EndogenousBurden, '-d', 'Color', [0.494 0.184 0.556], ...
    'MarkerFaceColor', [0.494 0.184 0.556], 'LineWidth', 2.0, 'MarkerSize', 6);
xlabel(ax,'SNR (dB)'); ylabel('burden proxy');
title(ax,'(d) Endogenous burden indicator');
xlim(ax,[min(snr) max(snr)]);
yl = ylim(ax);
text(ax, min(snr)+0.3, yl(2)-0.18*(yl(2)-yl(1)), ...
    sprintf('Controlled Markov-ISI only\nh2 in {0.30, 0.50, 0.70}\nSingle-bank recursions; no S-parameters; no MSB routing'), ...
    'FontName','Times New Roman', 'FontSize', 10, ...
    'BackgroundColor','w', 'EdgeColor',[0.75 0.75 0.75], ...
    'Margin',6, 'Interpreter','none');

sgtitle(tl, 'Endogenous-aware recursion bridge', ...
    'FontName','Times New Roman', 'FontSize', 18, 'FontWeight','bold');

fname = fullfile(opt.save_dir, sprintf('Endogenous_Aware_Recursion_Bridge_Ablation.%s', char(opt.format)));
local_save(fig, fname);

clean_name = fullfile(opt.save_dir, sprintf('Endogenous_Aware_Recursion_Bridge_Clean.%s', char(opt.format)));
local_plot_clean_three_panel(snr, smn, sms, aware, gain_smn, gain_sms, cols, clean_name, opt.fig_visible);

main_name = fullfile(opt.save_dir, sprintf('Endogenous_Aware_Recursion_Bridge_PaperReady.%s', char(opt.format)));
local_plot_main_paperready(snr, smn, sms, aware, cols, main_name, opt.fig_visible);

out = struct('table', T, 'snr', snr, 'gain_vs_smnlms', gain_smn, ...
    'gain_vs_smsign', gain_sms, 'figure', fname, ...
    'clean_figure', clean_name, 'main_figure', main_name);
try
    save(fullfile(opt.save_dir, 'Endogenous_Aware_Recursion_Bridge_Ablation.mat'), ...
        'out', 'opt', '-v7.3');
catch
    save(fullfile(opt.save_dir, 'Endogenous_Aware_Recursion_Bridge_Ablation.mat'), ...
        'out', 'opt');
end
end

function local_plot_main_paperready(snr, smn, sms, aware, cols, fname, fig_visible)
fig = figure('Color','w','Visible',char(fig_visible), ...
    'Position',[80 80 900 650]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
set(ax, 'YScale','log', 'FontName','Times New Roman', 'FontSize',13, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.YMinorGrid = 'on';
ax.GridAlpha = 0.20;
ax.MinorGridAlpha = 0.14;

semilogy(ax, snr, smn.BER, '-o', 'Color', cols.smn, ...
    'MarkerFaceColor', cols.smn, 'LineWidth', 2.0, 'MarkerSize', 7, ...
    'DisplayName','SMNLMS-DFE');
semilogy(ax, snr, sms.BER, '-s', 'Color', cols.sms, ...
    'MarkerFaceColor', cols.sms, 'LineWidth', 2.0, 'MarkerSize', 7, ...
    'DisplayName','SM-sign-NLMS');
semilogy(ax, snr, aware.BER, '-^', 'Color', cols.aware, ...
    'MarkerFaceColor', cols.aware, 'LineWidth', 2.6, 'MarkerSize', 8, ...
    'DisplayName','Algorithm 1: endogenous-aware');

yline(ax, 2.4e-4, 'k--', 'KP4 FEC 2.4e-4', ...
    'LabelHorizontalAlignment','right', 'LabelVerticalAlignment','bottom', ...
    'HandleVisibility','off');

xlabel(ax,'SNR (dB)', 'FontName','Times New Roman', 'FontSize',14);
ylabel(ax,'pre-FEC BER', 'FontName','Times New Roman', 'FontSize',14);
title(ax, 'Endogenous-aware recursion bridge', ...
    'FontName','Times New Roman', 'FontSize',16, 'FontWeight','bold');
legend(ax, 'Location','southwest', 'FontName','Times New Roman', ...
    'FontSize',12, 'Box','on');
xlim(ax,[min(snr) max(snr)]);
ylim(ax,[8e-5 8e-2]);

txt = sprintf(['Controlled Markov-ISI ablation\n', ...
    'h_2 states: 0.30, 0.50, 0.70\n', ...
    'single-bank recursions only\n', ...
    'no S-parameters, no HMM/MSB routing']);
text(ax, min(snr)+0.35, 2.3e-3, txt, ...
    'FontName','Times New Roman', 'FontSize', 11, ...
    'BackgroundColor','w', 'EdgeColor',[0.70 0.70 0.70], ...
    'Margin',7, 'Interpreter','tex');

local_save(fig, fname);
end

function local_plot_clean_three_panel(snr, smn, sms, aware, gain_smn, gain_sms, cols, fname, fig_visible)
fig = figure('Color','w','Visible',char(fig_visible), ...
    'Position',[60 60 1450 520]);
tl = tiledlayout(fig, 1, 3, 'Padding','compact', 'TileSpacing','compact');

ax = nexttile(tl, 1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
set(ax, 'YScale','log', 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.YMinorGrid = 'on'; ax.GridAlpha = 0.20; ax.MinorGridAlpha = 0.12;
semilogy(ax, snr, smn.BER, '-o', 'Color', cols.smn, 'MarkerFaceColor', cols.smn, ...
    'LineWidth', 1.8, 'MarkerSize', 6, 'DisplayName','SMNLMS');
semilogy(ax, snr, sms.BER, '-s', 'Color', cols.sms, 'MarkerFaceColor', cols.sms, ...
    'LineWidth', 1.8, 'MarkerSize', 6, 'DisplayName','SM-sign-NLMS');
semilogy(ax, snr, aware.BER, '-^', 'Color', cols.aware, 'MarkerFaceColor', cols.aware, ...
    'LineWidth', 2.4, 'MarkerSize', 7, 'DisplayName','Endogenous-aware');
yline(ax, 2.4e-4, 'k--', 'KP4 FEC 2.4e-4', 'HandleVisibility','off');
xlabel(ax,'SNR (dB)'); ylabel(ax,'pre-FEC BER');
title(ax,'(a) Controlled Markov-ISI Monte Carlo');
legend(ax, 'Location','southwest');
ylim(ax,[1e-4 8e-2]); xlim(ax,[min(snr) max(snr)]);

ax = nexttile(tl, 2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
set(ax, 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in');
plot(ax, snr, gain_smn, '-o', 'Color', cols.smn, 'MarkerFaceColor', cols.smn, ...
    'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName','vs. SMNLMS');
plot(ax, snr, gain_sms, '-s', 'Color', cols.sms, 'MarkerFaceColor', cols.sms, ...
    'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName','vs. SM-sign-NLMS');
yline(ax, 0, 'k:', 'HandleVisibility','off');
xlabel(ax,'SNR (dB)'); ylabel(ax,'BER reduction (%)');
title(ax,'(b) Single-bank endogenous-aware gain');
legend(ax, 'Location','northwest');
xlim(ax,[min(snr) max(snr)]);
ylim(ax, [min(-5, floor(min([gain_smn; gain_sms])-3)), max(75, ceil(max([gain_smn; gain_sms])+5))]);

ax = nexttile(tl, 3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
set(ax, 'FontName','Times New Roman', 'FontSize',11, ...
    'LineWidth',1.0, 'TickDir','in');
plot(ax, snr, 100*smn.UpdateRate, '-o', 'Color', cols.smn, ...
    'MarkerFaceColor', cols.smn, 'LineWidth', 1.8, 'MarkerSize', 6, ...
    'DisplayName','SMNLMS');
plot(ax, snr, 100*aware.UpdateRate, '-^', 'Color', cols.aware, ...
    'MarkerFaceColor', cols.aware, 'LineWidth', 2.4, 'MarkerSize', 7, ...
    'DisplayName','Endogenous-aware');
xlabel(ax,'SNR (dB)'); ylabel(ax,'update rate (%)');
title(ax,'(c) Reliability-gated update activity');
legend(ax, 'Location','northwest');
xlim(ax,[min(snr) max(snr)]);

sgtitle(tl, 'Endogenous-aware recursion bridge', ...
    'FontName','Times New Roman', 'FontSize', 18, 'FontWeight','bold');
annotation(fig, 'textbox', [0.14 0.005 0.74 0.06], ...
    'String', 'Controlled Markov-ISI ablation: h2 states {0.30, 0.50, 0.70}; single-bank recursions only; no S-parameters, no HMM/MSB routing.', ...
    'HorizontalAlignment','center', 'EdgeColor','none', ...
    'FontName','Times New Roman', 'FontSize', 10);
local_save(fig, fname);
end

function S = local_series(T, method, snr)
idx = strcmp(string(T.Method), method);
Ti = T(idx,:);
S = table();
for k = 1:numel(snr)
    j = find(Ti.SNRdB == snr(k), 1);
    if isempty(j)
        S = [S; table(snr(k), nan, nan, nan, nan, nan, ...
            'VariableNames', {'SNRdB','BER','SER','MSEtail','UpdateRate','EndogenousBurden'})]; %#ok<AGROW>
    else
        S = [S; table(snr(k), Ti.BER(j), Ti.SER(j), Ti.MSEtail(j), ...
            Ti.UpdateRate(j), Ti.EndogenousBurden(j), ...
            'VariableNames', {'SNRdB','BER','SER','MSEtail','UpdateRate','EndogenousBurden'})]; %#ok<AGROW>
    end
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
