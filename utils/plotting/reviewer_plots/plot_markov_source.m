function fname = plot_markov_source(out, opts)
%PLOT_MARKOV_SOURCE  Off-design Markov P matrix sensitivity.
% Oracle is intentionally not plotted; it remains available in printed tables.

p = pal_ieee();
fig = figure('Name','Markov source profile','Color','w','Position',[100 100 1300 540]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

cols = {p.alg5, p.proposed};
mks  = {'o','s'};

% --- (a) BER curves ---
nexttile; hold on;
for pi_ = 1:numel(out.P_set)
    semilogy(out.snr_list, max(out.BER_alg6(:,pi_),1e-8), ['-' mks{pi_}], ...
        'Color', cols{pi_}, 'LineWidth', 2.0, ...
        'MarkerFaceColor', cols{pi_}, 'MarkerSize', 9, ...
        'DisplayName', sprintf('Algorithm 2 - %s', out.P_labels{pi_}));
    semilogy(out.snr_list, max(out.BER_alg5(:,pi_),1e-8), [':' mks{pi_}], ...
        'Color', cols{pi_}, 'LineWidth', 1.2, 'MarkerSize', 6, ...
        'DisplayName', sprintf('Algorithm 1 - %s', out.P_labels{pi_}));
end
yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','left');
set(gca,'YScale','log');
xlabel('SNR (dB)'); ylabel('pre-FEC BER');
title('(a) BER under off-design Markov P');
legend('Location','southwest','NumColumns',1);

% --- (b) HMM accuracy ---
nexttile; hold on;
for pi_ = 1:numel(out.P_set)
    plot(out.snr_list, 100*out.hmm_accuracy(:,pi_), ['-' mks{pi_}], ...
        'Color', cols{pi_}, 'LineWidth', 1.8, ...
        'MarkerFaceColor', cols{pi_}, 'MarkerSize', 9, ...
        'DisplayName', out.P_labels{pi_});
end
xlabel('SNR (dB)'); ylabel('HMM state accuracy (%)');
title('(b) HMM accuracy vs SNR');
ylim([0 102]);
legend('Location','southeast');

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'markov_source_profile', opts);
end
