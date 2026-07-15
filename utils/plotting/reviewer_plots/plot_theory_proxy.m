function fname = plot_theory_proxy(out, opts)
%PLOT_THEORY_PROXY  V_tr, B_c traces, and final-quartile bar.

p = pal_ieee();
fig = figure('Name','Theory-proxy diagnostics','Color','w','Position',[100 100 1400 520]);
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

cols = {p.alg5, p.proposed};

% --- (a) V_tr trace ---
nexttile; hold on;
for rg = 1:numel(out.regimes)
    v = out.Vtr_alg6{rg};
    if ~isempty(v)
        plot((1:numel(v))*out.block_M, v, '-', ...
            'Color', cols{rg}, 'LineWidth', 1.8, ...
            'DisplayName', out.regimes{rg});
    end
end
xlabel('symbol index n');
ylabel('$\hat{V}_{\mathrm{tr}}(n)$', 'Interpreter','latex');
title('(a) Parameter-tracking proxy V_{tr}');
set(gca,'YScale','log');
legend('Location','northeast');

% --- (b) B_c trace alg6 vs alg5 ---
nexttile; hold on;
for rg = 1:numel(out.regimes)
    b6 = out.Bc_alg6{rg};  b5 = out.Bc_alg5{rg};
    if ~isempty(b6)
        plot((1:numel(b6))*out.block_M, b6, '-', ...
            'Color', cols{rg}, 'LineWidth', 1.8, ...
            'DisplayName', sprintf('Algorithm 2 - %s', out.regimes{rg}));
    end
    if ~isempty(b5)
        plot((1:numel(b5))*out.block_M, b5, ':', ...
            'Color', cols{rg}, 'LineWidth', 1.4, ...
            'DisplayName', sprintf('Algorithm 1 - %s', out.regimes{rg}));
    end
end
xlabel('symbol index n');
ylabel('$\hat{B}_{c}(n)$', 'Interpreter','latex');
title('(b) Endogenous-bias proxy B_{c}');
set(gca,'YScale','log');
legend('Location','northeast');

% --- (c) Final-quartile bar ---
nexttile;
regimes = out.regimes;
Bc6 = zeros(1,numel(regimes)); Bc5 = zeros(1,numel(regimes));
for rg = 1:numel(regimes)
    Bc6(rg) = out.summary.Bc_alg6_finalQ.(regimes{rg});
    Bc5(rg) = out.summary.Bc_alg5_finalQ.(regimes{rg});
end
bd = [Bc5; Bc6].';
b = bar(bd, 'grouped');
b(1).FaceColor = p.alg5;     b(1).EdgeColor = 'none';
b(2).FaceColor = p.proposed; b(2).EdgeColor = 'none';
set(gca, 'XTickLabel', regimes, 'YScale', 'log');
ylabel('B_{c} (final-quartile mean)');
title('(c) Routing burden reduction');
legend({'Algorithm 1 single-bank','Algorithm 2 HMM (proposed)'}, 'Location','northeast', 'Interpreter','tex');

for rg = 1:numel(regimes)
    ratio = Bc5(rg)/max(Bc6(rg),eps);
    text(rg, max(Bc5(rg),Bc6(rg))*1.5, sprintf('%.1f\\times', ratio), ...
        'HorizontalAlignment','center', 'FontSize', 11, 'FontWeight','bold', ...
        'Color', p.proposed, 'Interpreter','tex');
end

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'theory_proxy_diagnostics', opts);
end
