function fname = plot_complexity(out, opts)
%PLOT_COMPLEXITY  BER vs S and BER vs MAC budget.

p = pal_ieee();
fig = figure('Name','Complexity vs BER','Color','w','Position',[100 100 1300 540]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

cols = {p.smsign, p.proposed, p.alg5};
mks  = {'o','s','^'};

% --- (a) BER vs S, several SNRs (severe regime) ---
nexttile; hold on;
for si = 1:numel(out.snr_list)
    semilogy(out.S_list, max(out.ber_grid(:,si,1), 1e-8), ['-' mks{si}], ...
        'Color', cols{si}, 'LineWidth', 1.8, ...
        'MarkerFaceColor', cols{si}, 'MarkerSize', 9, ...
        'DisplayName', sprintf('SNR=%d dB', out.snr_list(si)));
end
yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','right');
set(gca,'YScale','log');
xlabel('Number of state banks S');
ylabel('pre-FEC BER (severe)');
title('(a) BER vs number of banks');
legend('Location','northeast');

% --- (b) BER vs MAC budget at central SNR, with NLMS reference ---
nexttile; hold on;
si0 = ceil(numel(out.snr_list)/2);
for rg = 1:numel(out.regimes)
    if rg==1, col = p.alg5; mk='o'; else, col = p.proposed; mk='s'; end
    y = max(squeeze(out.ber_grid(:,si0,rg)), 1e-8);
    semilogy(out.mac_per_sym, y, ['-' mk], ...
        'Color', col, 'LineWidth', 2.0, ...
        'MarkerFaceColor', col, 'MarkerSize', 10, ...
        'DisplayName', sprintf('Algorithm 2 - %s', out.regimes{rg}));
end
for rg = 1:numel(out.regimes)
    if rg==1, col = p.alg5; else, col = p.proposed; end
    yline(out.ber_nlms_grid(si0,rg), ':', sprintf('NLMS %s', out.regimes{rg}), ...
        'Color', col, 'LineWidth', 1.0, 'FontSize', 9);
end
yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','left');
set(gca,'YScale','log');
xlabel('MACs / symbol');
ylabel('pre-FEC BER');
title(sprintf('(b) Tradeoff at SNR=%d dB', out.snr_list(si0)));
legend('Location','northeast');

% Annotate S values
for ki = 1:numel(out.S_list)
    text(out.mac_per_sym(ki), out.ber_grid(ki,si0,1)*1.4, ...
        sprintf(' S=%d', out.S_list(ki)), 'FontSize', 10);
end

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'complexity_vs_ber', opts);
end
