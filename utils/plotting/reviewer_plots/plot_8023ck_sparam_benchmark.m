function out_paths = plot_8023ck_sparam_benchmark(out, opts)
%PLOT_8023CK_SPARAM_BENCHMARK  Paper-facing figures for S-parameter benchmark.

if ~exist(opts.save_dir, 'dir'), mkdir(opts.save_dir); end
p = pal_ieee();
rows = out.table(:);
if isempty(rows)
    out_paths = {};
    if isfield(out, 'markov') && ~isempty(out.markov)
        mk_paths = local_plot_markov(out.markov, opts, p);
        out_paths = [out_paths, mk_paths]; %#ok<AGROW>
    end
    if isfield(out, 'markov_sweep') && ~isempty(out.markov_sweep)
        out_paths{end+1} = local_plot_markov_sweep(out.markov_sweep, opts, p);
    end
    return;
end

methods = rows(1).methods;
plot_methods = local_plot_methods(methods);
case_labels = local_case_labels(rows);
x = 1:numel(rows);

out_paths = {};
out_paths{end+1} = local_plot_metric(rows, methods, plot_methods, x, case_labels, ...
    'BER', 'Pre-FEC BER', 'ieee8023ck_sparam_ber', opts, p, true);
out_paths{end+1} = local_plot_metric(rows, methods, plot_methods, x, case_labels, ...
    'SER', 'SER', 'ieee8023ck_sparam_ser', opts, p, true);
out_paths{end+1} = local_plot_metric(rows, methods, plot_methods, x, case_labels, ...
    'EyeHeight', 'Eye height (5-95%)', 'ieee8023ck_sparam_eye_height', opts, p, false);
out_paths{end+1} = local_plot_metric(rows, methods, plot_methods, x, case_labels, ...
    'EyeWidth', 'Eye width (UI)', 'ieee8023ck_sparam_eye_width', opts, p, false);

out_paths{end+1} = local_plot_best_summary(rows, methods, x, case_labels, opts, p);

if isfield(out, 'markov') && ~isempty(out.markov)
    out_paths = [out_paths, local_plot_markov(out.markov, opts, p)]; %#ok<AGROW>
end
if isfield(out, 'markov_sweep') && ~isempty(out.markov_sweep)
    out_paths{end+1} = local_plot_markov_sweep(out.markov_sweep, opts, p);
end
end

function names = local_plot_methods(methods)
preferred = {'SMNLMS-DFE','SM-sign-NLMS','Liu SS-LMS', ...
             'Chen pulse-ref','ExtraTrees-HMM','Algorithm 1','Proposed MSB'};
names = preferred(ismember(preferred, methods));
end

function labels = local_case_labels(rows)
labels = cell(numel(rows),1);
for i = 1:numel(rows)
    labels{i} = strrep(rows(i).case_id, '_', '\_');
end
end

function path = local_plot_metric(rows, methods, plot_methods, x, labels, field, ylab, base_name, opts, p, is_log)
fig = figure('Name', base_name, 'Color', 'w', 'Visible', opts.fig_visible);
clf; hold on;

for mi = 1:numel(plot_methods)
    name = plot_methods{mi};
    idx = find(strcmp(methods, name), 1);
    y = arrayfun(@(r) r.(field)(idx), rows);
    style = local_method_style(name, p);
    if is_log
        semilogy(x, max(y, 1e-12), style.marker, ...
            'Color', style.color, 'LineWidth', style.lw, ...
            'MarkerSize', style.ms, 'MarkerFaceColor', style.color);
    else
        plot(x, y, style.marker, ...
            'Color', style.color, 'LineWidth', style.lw, ...
            'MarkerSize', style.ms, 'MarkerFaceColor', style.color);
    end
end

grid on;
xlim([0.75 numel(rows)+0.25]);
set(gca, 'XTick', x, 'XTickLabel', labels);
xtickangle(35);
ylabel(ylab);
xlabel('802.3ck S-parameter channel case');
title(strrep(ylab, '_', '\_'));
legend(plot_methods, 'Location', 'best', 'Interpreter', 'none');
if is_log
    ylim(local_log_ylim(rows, methods, plot_methods, field));
end
ieee_access_style(fig);
path = save_fig_helper(fig, opts.save_dir, base_name, opts);
end

function yl = local_log_ylim(rows, methods, plot_methods, field)
vals = [];
for mi = 1:numel(plot_methods)
    idx = find(strcmp(methods, plot_methods{mi}), 1);
    vals = [vals; arrayfun(@(r) r.(field)(idx), rows).']; %#ok<AGROW>
end
vals = vals(isfinite(vals) & vals > 0);
if isempty(vals)
    yl = [1e-6 1];
else
    yl = [10^floor(log10(min(vals)/2)), min(1, 10^ceil(log10(max(vals)*2)))];
end
end

function path = local_plot_best_summary(rows, methods, x, labels, opts, p)
fig = figure('Name', 'ieee8023ck_sparam_best_summary', 'Color', 'w', 'Visible', opts.fig_visible);
clf;

idx_prop = find(strcmp(methods, 'Proposed MSB'), 1);
idx_alg1 = find(strcmp(methods, 'Algorithm 1'), 1);
idx_sm = find(strcmp(methods, 'SM-sign-NLMS'), 1);

Y = [arrayfun(@(r) r.BER(idx_prop), rows).', ...
     arrayfun(@(r) r.BER(idx_alg1), rows).', ...
     arrayfun(@(r) r.BER(idx_sm), rows).'];

bar(max(Y, 1e-12), 'grouped');
set(gca, 'YScale', 'log');
cols = [p.proposed; p.alg5; p.smsign];
b = findobj(gca, 'Type', 'Bar');
for k = 1:numel(b)
    set(b(k), 'FaceColor', cols(numel(b)-k+1,:));
end
set(gca, 'XTick', x, 'XTickLabel', labels);
xtickangle(35);
grid on;
xlabel('802.3ck S-parameter channel case');
ylabel('Pre-FEC BER');
title('Key receiver comparison');
legend({'Proposed MSB','Algorithm 1','SM-sign-NLMS'}, ...
    'Location','best', 'Interpreter','none');
ieee_access_style(fig);
path = save_fig_helper(fig, opts.save_dir, 'ieee8023ck_sparam_key_ber_bar', opts);
end

function paths = local_plot_markov(mk, opts, p)
paths = {};
labels = local_short_markov_labels({mk.case_id});
x = 1:numel(mk);
mnames = {'Proposed MSB','Algorithm 1','Chen pulse-ref'};
cols = [p.proposed; p.alg5; p.chen];

BER = [[mk.BER_algorithm6].', [mk.BER_algorithm1].', [mk.BER_chen_pulse_ref].'];
SER = [[mk.SER_algorithm6].', [mk.SER_algorithm1].', [mk.SER_chen_pulse_ref].'];
TBER = [[mk.transition_window_BER_algorithm6].', [mk.transition_window_BER_algorithm1].', [mk.transition_window_BER_chen_pulse_ref].'];
REC = [[mk.recovery_time_algorithm6].', [mk.recovery_time_algorithm1].', [mk.recovery_time_chen_pulse_ref].'];
EH = [[mk.EyeHeight_algorithm6].', [mk.EyeHeight_algorithm1].', [mk.EyeHeight_chen_pulse_ref].'];
EW = [[mk.EyeWidth_algorithm6].', [mk.EyeWidth_algorithm1].', [mk.EyeWidth_chen_pulse_ref].'];

fig = figure('Name', 'Fig_BlockB_BER_SER', 'Color', 'w', 'Visible', opts.fig_visible);
clf;
tiledlayout(1,2, 'Padding','compact', 'TileSpacing','compact');
nexttile;
local_grouped_bar(BER, labels, mnames, cols, true);
ylabel('Pre-FEC BER');
title('Tracking stress BER');
nexttile;
local_grouped_bar(SER, labels, mnames, cols, true);
ylabel('SER');
title('Tracking stress SER');
ieee_access_style(fig);
paths{end+1} = save_fig_helper(fig, opts.save_dir, 'Fig_BlockB_BER_SER', opts);

fig = figure('Name', 'Fig_BlockB_Transition_Recovery', 'Color', 'w', 'Visible', opts.fig_visible);
clf;
tiledlayout(1,2, 'Padding','compact', 'TileSpacing','compact');
nexttile;
local_grouped_bar(TBER, labels, mnames, cols, true);
ylabel('Transition-window BER');
title('Post-transition error');
nexttile;
local_grouped_bar(REC, labels, mnames, cols, false);
ylabel('Recovery time (symbols)');
title('Recovery after state change');
ieee_access_style(fig);
paths{end+1} = save_fig_helper(fig, opts.save_dir, 'Fig_BlockB_Transition_Recovery', opts);

fig = figure('Name', 'Fig_BlockB_State_Routing', 'Color', 'w', 'Visible', opts.fig_visible);
clf;
tiledlayout(1,2, 'Padding','compact', 'TileSpacing','compact');
nexttile;
bar(x, 100*[mk.state_accuracy], 'FaceColor', p.proposed);
grid on; set(gca, 'XTick', x, 'XTickLabel', labels);
ylabel('State accuracy (%)'); ylim([0 100]);
title('MSB routing accuracy');
nexttile;
bar(x, 100*[mk.wrong_routing_rate], 'FaceColor', p.alg5);
grid on; set(gca, 'XTick', x, 'XTickLabel', labels);
ylabel('Wrong-routing rate (%)'); ylim([0 100]);
title('Wrong routing');
ieee_access_style(fig);
paths{end+1} = save_fig_helper(fig, opts.save_dir, 'Fig_BlockB_State_Routing', opts);

fig = figure('Name', 'Fig_BlockB_Eye_Metrics', 'Color', 'w', 'Visible', opts.fig_visible);
clf;
tiledlayout(1,2, 'Padding','compact', 'TileSpacing','compact');
nexttile;
local_grouped_bar(EH, labels, mnames, cols, false);
ylabel('Eye height (5-95%)');
title('Eye height');
nexttile;
local_grouped_bar(EW, labels, mnames, cols, false);
ylabel('Eye width (UI)');
title('Eye width');
ieee_access_style(fig);
paths{end+1} = save_fig_helper(fig, opts.save_dir, 'Fig_BlockB_Eye_Metrics', opts);

if isfield(mk, 'smnlms_update_rate') && isfield(mk, 'cross_state_memory')
    fig = figure('Name', 'Fig_BlockB_Bank_Diagnostics', 'Color', 'w', 'Visible', opts.fig_visible);
    clf;
    tiledlayout(1,2, 'Padding','compact', 'TileSpacing','compact');
    nexttile;
    Y = [[mk.smnlms_update_rate].', [mk.hmm_posterior_entropy].', [mk.hmm_confidence_gap].'];
    local_grouped_bar(100*Y, labels, {'Update rate','HMM entropy','Confidence gap'}, ...
        [p.proposed; p.cui; p.nlms], false);
    ylabel('Rate / normalized score (%)');
    title('Routing/update diagnostics');
    nexttile;
    Y2 = [[mk.dd_bias_proxy].', [mk.dd_bias_dfe_proxy].', [mk.cross_state_memory].'];
    local_grouped_bar(Y2, labels, {'DD bias','DFE DD bias','Cross-state memory'}, ...
        [p.proposed; p.alg5; p.chen], false);
    ylabel('Proxy value');
    title('Endogenous/bank diagnostics');
    ieee_access_style(fig);
    paths{end+1} = save_fig_helper(fig, opts.save_dir, 'Fig_BlockB_Bank_Diagnostics', opts);
end

% Legacy compact summary retained for continuity.
path = local_plot_markov_legacy(mk, opts, p);
paths{end+1} = path;
end

function path = local_plot_markov_legacy(mk, opts, p)
fig = figure('Name', 'ieee8023ck_sparam_markov_summary', 'Color', 'w', 'Visible', opts.fig_visible);
clf;
if isfield(mk, 'transition_excess_BER_algorithm6')
    tiledlayout(1,3, 'Padding','compact', 'TileSpacing','compact');
else
    tiledlayout(1,2, 'Padding','compact', 'TileSpacing','compact');
end
labels = strrep({mk.case_id}, '_', '\_');
x = 1:numel(mk);

nexttile;
semilogy(x, max([mk.BER_algorithm6], 1e-12), '-o', ...
    'Color', p.proposed, 'LineWidth', 2.0, 'MarkerFaceColor', p.proposed);
hold on;
semilogy(x, max([mk.BER_algorithm1], 1e-12), '-s', ...
    'Color', p.alg5, 'LineWidth', 1.6, 'MarkerFaceColor', p.alg5);
grid on;
set(gca, 'XTick', x, 'XTickLabel', labels);
xtickangle(25);
ylabel('Pre-FEC BER');
title('Markov switching BER');
legend({'Proposed MSB','Algorithm 1'}, 'Location','best');

nexttile;
if isfield(mk, 'transition_excess_BER_algorithm6')
    semilogy(x, max([mk.transition_excess_BER_algorithm6], 1e-12), '-o', ...
        'Color', p.proposed, 'LineWidth', 2.0, 'MarkerFaceColor', p.proposed);
    hold on;
    semilogy(x, max([mk.transition_excess_BER_algorithm1], 1e-12), '-s', ...
        'Color', p.alg5, 'LineWidth', 1.6, 'MarkerFaceColor', p.alg5);
    grid on;
    set(gca, 'XTick', x, 'XTickLabel', labels);
    xtickangle(25);
    ylabel('Transition-induced excess BER');
    title('Post-jump burst penalty');
    legend({'Proposed MSB','Algorithm 1'}, 'Location','best');
    nexttile;
end

bar(x, 100*[mk.state_accuracy], 'FaceColor', p.proposed);
grid on;
set(gca, 'XTick', x, 'XTickLabel', labels);
xtickangle(25);
ylabel('State accuracy (%)');
ylim([0 100]);
title('MSB routing accuracy');

ieee_access_style(fig);
path = save_fig_helper(fig, opts.save_dir, 'ieee8023ck_sparam_markov_summary', opts);
end

function labels = local_short_markov_labels(case_ids)
labels = cell(size(case_ids));
for i = 1:numel(case_ids)
    s = regexprep(case_ids{i}, '^Markov_', '');
    labels{i} = strrep(s, '_', '\_');
end
end

function local_grouped_bar(Y, labels, legends, cols, use_log)
Yp = Y;
if use_log
    Yp = max(Yp, 1e-12);
end
b = bar(Yp, 'grouped');
for k = 1:min(numel(b), size(cols,1))
    b(k).FaceColor = cols(k,:);
end
if use_log
    set(gca, 'YScale', 'log');
end
grid on;
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
nleg = min(numel(legends), numel(b));
legend(legends(1:nleg), 'Location','best', 'Interpreter','none');
end

function path = local_plot_markov_sweep(sw, opts, p)
fig = figure('Name', 'ieee8023ck_markov_sweep', 'Color', 'w', 'Visible', opts.fig_visible);
clf;
tiledlayout(2,2, 'Padding','compact', 'TileSpacing','compact');

methods = sw(1).methods;
keep = {'Proposed MSB','Chen pulse-ref','Algorithm 1','SMNLMS-DFE', ...
        'SM-sign-NLMS','Liu SS-LMS','ExtraTrees-HMM'};
x = [sw.mean_dwell_symbols];
[x, ord] = sort(x, 'ascend');
sw = sw(ord);

nexttile;
hold on;
for k = 1:numel(keep)
    idx = find(strcmp(methods, keep{k}), 1);
    if isempty(idx), continue; end
    y = arrayfun(@(r) r.BER(idx), sw);
    st = local_method_style(keep{k}, p);
    semilogy(x, max(y, 1e-12), st.marker, 'Color', st.color, ...
        'LineWidth', st.lw, 'MarkerSize', st.ms, 'MarkerFaceColor', st.color);
end
grid on;
xlabel('Mean dwell length (symbols)');
ylabel('Pre-FEC BER');
title('Markov dwell/severity sweep');
legend(keep(ismember(keep, methods)), 'Location','best', 'Interpreter','none');

nexttile;
yyaxis left;
plot(x, 100*[sw.improvement_vs_chen_pct], '-o', 'Color', p.proposed, ...
    'LineWidth', 2.0, 'MarkerFaceColor', p.proposed);
ylabel('Improvement vs Chen (%)');
yyaxis right;
plot(x, 100*[sw.state_accuracy], '-s', 'Color', p.cui, ...
    'LineWidth', 1.8, 'MarkerFaceColor', p.cui);
ylabel('State accuracy (%)');
grid on;
xlabel('Mean dwell length (symbols)');
title('Proposed tracking gain');

nexttile;
if isfield(sw, 'smnlms_update_rate')
    plot(x, 100*[sw.smnlms_update_rate], '-o', 'Color', p.proposed, ...
        'LineWidth', 2.0, 'MarkerFaceColor', p.proposed);
    hold on;
    plot(x, 100*[sw.cross_state_memory], '-s', 'Color', p.alg5, ...
        'LineWidth', 1.6, 'MarkerFaceColor', p.alg5);
    ylabel('Rate (%)');
    legend({'Bank-local SMNLMS update','Cross-state DFE memory'}, ...
        'Location','best', 'Interpreter','none');
else
    text(0.5,0.5,'Endogenous diagnostics unavailable', ...
        'HorizontalAlignment','center');
end
grid on;
xlabel('Mean dwell length (symbols)');
title('Endogenous DD loop diagnostics');

nexttile;
if isfield(sw, 'dd_bias_dfe_proxy')
    yyaxis left;
    plot(x, [sw.dd_bias_dfe_proxy], '-o', 'Color', p.proposed, ...
        'LineWidth', 2.0, 'MarkerFaceColor', p.proposed);
    ylabel('DFE DD-bias proxy');
    yyaxis right;
    plot(x, [sw.hmm_posterior_entropy], '-s', 'Color', p.cui, ...
        'LineWidth', 1.8, 'MarkerFaceColor', p.cui);
    ylabel('Normalized HMM entropy');
else
    text(0.5,0.5,'Bias diagnostics unavailable', ...
        'HorizontalAlignment','center');
end
grid on;
xlabel('Mean dwell length (symbols)');
title('Bias proxy and routing uncertainty');

ieee_access_style(fig);
path = save_fig_helper(fig, opts.save_dir, 'ieee8023ck_markov_sweep', opts);
end

function s = local_method_style(name, p)
s = struct('color', [0 0 0], 'marker', '-o', 'lw', 1.4, 'ms', 6);
switch name
    case 'Proposed MSB'
        s.color = p.proposed; s.marker = '-o'; s.lw = 2.4; s.ms = 8;
    case 'Algorithm 1'
        s.color = p.alg5; s.marker = '-s'; s.lw = 1.8; s.ms = 7;
    case 'NLMS-DFE'
        s.color = p.nlms; s.marker = '-d';
    case 'SMNLMS-DFE'
        s.color = p.smsign_vss; s.marker = '-^';
    case 'SM-sign-NLMS'
        s.color = p.smsign; s.marker = '-v';
    case 'Liu SS-LMS'
        s.color = p.liu_ss; s.marker = '-p';
    case 'Chen pulse-ref'
        s.color = p.chen; s.marker = '-x';
    case 'ExtraTrees-HMM'
        s.color = p.cui; s.marker = '-h';
end
end
