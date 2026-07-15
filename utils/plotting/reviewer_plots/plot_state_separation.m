function fname = plot_state_separation(out, opts)
%PLOT_STATE_SEPARATION  HMM accuracy + BER vs h2 separation.

p = pal_ieee();
fig = figure('Name','State separation','Color','w','Position',[100 100 1300 540]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

cols = {p.smsign, p.proposed, p.alg5};
mks  = {'o','s','^'};

% --- (a) HMM accuracy ---
nexttile; hold on;
for si = 1:numel(out.snr_list)
    plot(out.sep_list, 100*out.acc_grid(:,si), ['-' mks{si}], ...
        'Color', cols{si}, 'LineWidth', 1.8, ...
        'MarkerFaceColor', cols{si}, 'MarkerSize', 9, ...
        'DisplayName', sprintf('SNR=%d dB', out.snr_list(si)));
end
xlabel('h_{2} state separation d');
ylabel('HMM state accuracy (%)');
title('(a) Accuracy vs state separation');
ylim([0 102]);
legend('Location','southeast');

% --- (b) BER (proposed solid, oracle dashed) ---
nexttile; hold on;
for si = 1:numel(out.snr_list)
    semilogy(out.sep_list, max(out.ber_grid(:,si),1e-8), ['-' mks{si}], ...
        'Color', cols{si}, 'LineWidth', 1.8, ...
        'MarkerFaceColor', cols{si}, 'MarkerSize', 9, ...
        'DisplayName', sprintf('Algorithm 2 - SNR=%d', out.snr_list(si)));
    % Oracle curve is printed in tables only; it is not drawn.
end
yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','left');
set(gca,'YScale','log');
xlabel('h_{2} state separation d');
ylabel('pre-FEC BER');
title('(b) BER vs state separation');
legend('Location','northwest');

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'state_separation_sweep', opts);
end
