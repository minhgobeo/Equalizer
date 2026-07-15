function fname = plot_p_mismatch(out, opts)
%PLOT_P_MISMATCH  HMM accuracy + BER vs assumed-P diagonal.

p = pal_ieee();
fig = figure('Name','P-mismatch sweep','Color','w','Position',[100 100 1300 540]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

cols = {p.alg5, p.proposed};
mks  = {'o','s'};

% --- (a) HMM accuracy ---
nexttile; hold on;
for rg = 1:numel(out.regimes)
    plot(out.assumed_diag_list, 100*out.acc_grid(:,rg), ['-' mks{rg}], ...
        'Color', cols{rg}, 'LineWidth', 1.8, ...
        'MarkerFaceColor', cols{rg}, 'MarkerSize', 9, ...
        'DisplayName', out.regimes{rg});
end
xline(0.95, ':', 'true (severe)', 'Color', cols{1}, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','right');
xline(0.99, ':', 'true (realistic)', 'Color', cols{2}, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','left');
xlabel('HMM-assumed diagonal of P');
ylabel('HMM state accuracy (%)');
title('(a) Routing accuracy under P-mismatch');
ylim([50 102]);
legend('Location','southeast');

% --- (b) BER ---
nexttile; hold on;
for rg = 1:numel(out.regimes)
    semilogy(out.assumed_diag_list, max(out.ber_grid(:,rg),1e-8), ['-' mks{rg}], ...
        'Color', cols{rg}, 'LineWidth', 1.8, ...
        'MarkerFaceColor', cols{rg}, 'MarkerSize', 9, ...
        'DisplayName', sprintf('Algorithm 2 - %s', out.regimes{rg}));
end
% Oracle reference is printed in the table only; it is not drawn.
yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','right');
set(gca,'YScale','log');
xlabel('HMM-assumed diagonal of P');
ylabel('pre-FEC BER');
title('(b) BER under P-mismatch');
legend('Location','northeast');

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'p_mismatch_sweep', opts);
end
