function fname = plot_liu_like_eye_benchmark_mc(out, opts)
%PLOT_LIU_LIKE_EYE_BENCHMARK_MC  BER confidence intervals + quantitative eye metrics.

p = pal_ieee();
fig = figure('Name','Liu-style MC eye/BER benchmark','Color','w','Position',[80 80 1500 720]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

plot_idx = [1 3 4 5 6]; % skip oracle
labels = {'Algorithm 2','Algorithm 1','Liu SS-LMS','Liu TA-SS-LMS','SM-sign'};
cols = {p.proposed, p.alg5, p.liu_ss, p.liu_ta, p.smsign};

ax = nexttile; hold(ax,'on');
for ii = 1:numel(plot_idx)
    k = plot_idx(ii);
    errorbar(ii, out.ber_mean(k), out.ber_ci95(k), 'o', ...
        'Color', cols{ii}, 'MarkerFaceColor', cols{ii}, 'LineWidth', 1.1, ...
        'MarkerSize', 7, 'HandleVisibility','off');
end
yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
    'LabelHorizontalAlignment','left', 'HandleVisibility','off');
set(ax, 'YScale','log', 'XTick', 1:numel(plot_idx), 'XTickLabel', labels, 'XTickLabelRotation', 18);
ylabel('pre-FEC BER, mean \pm 95% CI');
title(sprintf('(a) BER over %d trials @ SNR=%d dB', out.Ntrial, out.snr));
grid on; xlim([0.5 numel(plot_idx)+0.5]);

ax = nexttile; hold(ax,'on');
metric_idx = 1:5;
metric_labels = {'Rx','Alg.1','Alg.2','Liu SS','Liu TA'};
q_mean = mean(out.eye_q_min,1,'omitnan');
q_ci = 1.96*std(out.eye_q_min,0,1,'omitnan')/sqrt(out.Ntrial);
bar(metric_idx, q_mean, 'FaceColor', [0.75 0.75 0.75], 'HandleVisibility','off');
errorbar(metric_idx, q_mean, q_ci, 'k.', 'LineWidth', 1.0, 'HandleVisibility','off');
set(ax, 'XTick', metric_idx, 'XTickLabel', metric_labels, 'XTickLabelRotation', 15);
ylabel('minimum adjacent-level Q');
title('(b) Quantitative level separation');
grid on;

ax = nexttile; hold(ax,'on');
op_mean = mean(out.eye_opening_5_95,1,'omitnan');
op_ci = 1.96*std(out.eye_opening_5_95,0,1,'omitnan')/sqrt(out.Ntrial);
bar(metric_idx, op_mean, 'FaceColor', [0.75 0.75 0.75], 'HandleVisibility','off');
errorbar(metric_idx, op_mean, op_ci, 'k.', 'LineWidth', 1.0, 'HandleVisibility','off');
yline(0, '--', 'closed/open boundary', 'Color', p.fec_line, 'HandleVisibility','off');
set(ax, 'XTick', metric_idx, 'XTickLabel', metric_labels, 'XTickLabelRotation', 15);
ylabel('min 5--95% eye opening');
title('(c) Percentile eye opening');
grid on;

ax = nexttile; hold(ax,'on');
% show common-scale eye for Algorithm 2 and best Liu TA from final packet.
if isfield(out,'eye_signals') && ~isempty(out.eye_signals)
    cfg = out.cfg; sps = cfg.sps_eye; g_rc = rc_pulse(cfg.alpha_eye, sps, cfg.spanUI_eye);
    x1 = conv(upsample_zeros(out.eye_signals.alg2(:), sps), g_rc, 'same');
    x2 = conv(upsample_zeros(out.eye_signals.liu_ta(:), sps), g_rc, 'same');
    lim = max(abs(prctile([x1(:);x2(:)], [0.5 99.5]))); if lim <= 0, lim = 1; end
    eye_plot_reshape_common(x1, sps, 'max_traces', 120, 'color', p.proposed, 'line_width', 0.25);
    eye_plot_reshape_common(x2, sps, 'max_traces', 120, 'color', p.liu_ta, 'line_width', 0.25);
    ylim(1.1*[-lim lim]); xlim([0 2]);
    text(0.05, 0.90, 'Algorithm 2 and Liu TA overlaid', 'Units','normalized', 'FontWeight','bold');
end
title('(d) Common-scale overlay, final trial');
grid on; legend(ax,'off');

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'liu_like_eye_mc_v68', opts);
end
