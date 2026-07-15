function fname = plot_burden_isolation(out, opts)
%PLOT_BURDEN_ISOLATION  Bar chart of Algorithm 1 vs Algorithm 2 burden.
% Oracle is intentionally not plotted; it remains available in printed tables.

p = pal_ieee();

fn = fieldnames(out);
alg6 = []; single = []; regimes = {};
for i = 1:numel(fn)
    nm_l = lower(fn{i});
    v = out.(fn{i});
    if isnumeric(v) && isvector(v)
        if contains(nm_l,'alg6') || contains(nm_l,'alg2')
            alg6 = v(:);
        elseif contains(nm_l,'single') || contains(nm_l,'alg5') || contains(nm_l,'alg1')
            single = v(:);
        end
    end
    if iscell(v) && all(cellfun(@ischar,v))
        regimes = v(:).';
    end
end

if isempty(alg6) || isempty(single)
    warning('plot_burden_isolation: missing fields, skipping plot.');
    fname = ''; return;
end
if isempty(regimes)
    regimes = arrayfun(@(k) sprintf('regime%d',k), 1:numel(alg6), 'uni', false);
end

fig = figure('Name','Burden isolation','Color','w','Position',[100 100 900 520]);
bar_data = [single, alg6];
b = bar(bar_data, 'grouped');
b(1).FaceColor = p.alg5;       b(1).EdgeColor = 'none';
b(2).FaceColor = p.proposed;   b(2).EdgeColor = 'none';

set(gca, 'YScale','log', 'XTickLabel', regimes);
ylabel('pre-FEC BER (post-training, average)');
title('Theory-to-proxy burden isolation at SNR=22 dB');
legend({'Algorithm 1 (single-bank)', 'Algorithm 2 (proposed HMM-MSB)'}, ...
       'Location','northeast');
yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','left');

for k = 1:numel(regimes)
    if alg6(k) > eps
        ratio = single(k) / alg6(k);
        ymax  = max([single(k) alg6(k)]);
        text(k, ymax*2.2, sprintf('%.1f\times', ratio), ...
            'HorizontalAlignment','center', 'FontSize', 11, 'FontWeight','bold', ...
            'Color', p.proposed, 'Interpreter','tex');
    end
end

positive_vals = bar_data(bar_data > 0);
if isempty(positive_vals), positive_vals = 1e-8; end
ylim([min(positive_vals)/3, max(positive_vals)*5]);
ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'burden_isolation', opts);
end
