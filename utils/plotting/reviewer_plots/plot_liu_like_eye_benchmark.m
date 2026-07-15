function fname = plot_liu_like_eye_benchmark(out, opts)
%PLOT_LIU_LIKE_EYE_BENCHMARK  Common-scale eye diagrams and BER/eye metrics.
% v68: no per-method median/std normalization. Eye panels use a common y-axis.

p = pal_ieee();
cfg = out.cfg;
sps = cfg.sps_eye;
g_rc = rc_pulse(cfg.alpha_eye, sps, cfg.spanUI_eye);

signals = {out.eye_signals.rx_before, out.eye_signals.alg1, out.eye_signals.alg2, ...
           out.eye_signals.liu_ss, out.eye_signals.liu_ta};
titles = {'Rx before EQ', 'Algorithm 1 single-bank', 'Algorithm 2 proposed', ...
          'Liu SS-LMS DFE', 'Liu TA-SS-LMS DFE'};
cols = {p.gray, p.alg5, p.proposed, p.liu_ss, p.liu_ta};

% Build common-scale oversampled traces. No per-method normalization.
xos_all = cell(size(signals));
all_vals = [];
for k = 1:numel(signals)
    x = signals{k}(:);
    xos = conv(upsample_zeros(x, sps), g_rc, 'same');
    xos_all{k} = xos;
    q = prctile(xos(isfinite(xos)), [0.5 99.5]);
    all_vals = [all_vals; q(:)]; %#ok<AGROW>
end
if isempty(all_vals) || any(~isfinite(all_vals))
    ylims = [-1 1];
else
    lim = max(abs(all_vals));
    if lim <= 0, lim = 1; end
    ylims = 1.10*[-lim lim];
end

fig = figure('Name','Liu-style eye benchmark','Color','w','Position',[80 80 1650 760]);
tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

for k = 1:numel(signals)
    ax = nexttile; hold(ax, 'on');
    eye_plot_reshape_common(xos_all{k}, sps, 'max_traces', 180, 'color', cols{k}, 'line_width', 0.25);
    title(titles{k});
    ylim(ylims); xlim([0 2]); grid on;
    legend(ax, 'off');
    % Reference PAM4 levels if they lie within axis range.
    for a = cfg.A(:).'
        if a > ylims(1) && a < ylims(2)
            yline(a, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.6, 'HandleVisibility','off');
        end
    end
end

ax = nexttile; hold(ax, 'on');
method = out.ber_methods;
ber = max(out.ber_values(:), 1e-8);
plot_idx = [1 3 4 5 6];  % skip oracle in figure
short_labels = {'Algorithm 2','Algorithm 1','Liu SS-LMS','Liu TA-SS-LMS','SM-sign'};
cols2 = {p.proposed, p.alg5, p.liu_ss, p.liu_ta, p.smsign};
for ii = 1:numel(plot_idx)
    k = plot_idx(ii);
    semilogy(ii, ber(k), 'o', 'MarkerFaceColor', cols2{ii}, 'Color', cols2{ii}, ...
        'MarkerSize', 8, 'LineWidth', 1.1, 'HandleVisibility','off');
end
yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
    'LabelHorizontalAlignment','left', 'HandleVisibility','off');
set(ax,'YScale','log','XTick',1:numel(plot_idx), ...
    'XTickLabel', short_labels, 'XTickLabelRotation', 18);
ylabel('pre-FEC BER');
title(sprintf('BER summary @ SNR=%d dB', out.snr));
grid on;
min_y = min([ber(plot_idx); 2.4e-4]);
max_y = max([ber(plot_idx); 2.4e-4]);
ylim([max(1e-8, 10^floor(log10(min_y))), 10^ceil(log10(max_y))]);
xlim([0.5 numel(plot_idx)+0.5]);
legend(ax, 'off');

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'liu_like_eye_benchmark_v68_common_scale', opts);
end
