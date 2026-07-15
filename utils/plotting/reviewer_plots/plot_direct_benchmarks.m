function fname = plot_direct_benchmarks(out, opts)
%PLOT_DIRECT_BENCHMARKS  BER vs SNR for the v65 direct + adapted suite.
%
% Two panels (severe + realistic). Methods plotted:
%   Algorithm 2 (proposed), SM-sign-NLMS (Souza, direct),
%   ExtraTrees-HMM (Cui, adapted), SS-LMS DFE (Liu, alg.),
%   TA-SS-LMS DFE (Liu, alg.), Single-pulse FFE/DFE (Chen, adapted).

fig = figure('Name','Direct benchmark suite','Visible','on', ...
             'Color','w','Position',[100 100 1300 540]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

p = pal_ieee();
snr = out.souza.snr_list;

% Bit-floor estimate (one error in entire MC)
bit_floor = 1e-7;

regime_names = {'severe','realistic'};
panel_letter = {'a','b'};

for rg = 1:2
    nexttile;
    series = {
        out.souza.BER_alg6(:,rg),                'Algorithm 2 (proposed)',          p.proposed,   '-o',  2.0, 9
        out.souza.BER_smsign_fix(:,rg),          'SM-sign-NLMS (Souza)',         p.smsign,     '-s',  1.4, 7
        out.cui.ber_grid(:,rg),                  'ExtraTrees-HMM (Cui, ad.)',    p.cui,        '-d',  1.4, 7
        out.liu.BER_sslms(:,rg),                 'SS-LMS DFE (Liu, alg.)',       p.liu_ss,     '-^',  1.5, 7
        out.liu.BER_tasslms(:,rg),               'TA-SS-LMS DFE (Liu, alg.)',    p.liu_ta,     '-v',  1.5, 7
        out.chen.ber_grid(:,rg),                 'Single-pulse FFE/DFE (Chen)',  p.chen,       '-x',  1.4, 8
    };
    hold on;
    for k = 1:size(series,1)
        y = max(series{k,1}, bit_floor);
        semilogy(snr, y, series{k,4}, ...
            'Color', series{k,3}, 'LineWidth', series{k,5}, ...
            'MarkerFaceColor', series{k,3}, 'MarkerSize', series{k,6}, ...
            'DisplayName', series{k,2});
    end
    yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
          'LabelHorizontalAlignment','left', 'FontSize', 9);
    set(gca,'YScale','log');
    xlabel('SNR (dB)');
    ylabel('pre-FEC BER');
    title(sprintf('(%s) %s regime', panel_letter{rg}, regime_names{rg}));
    legend('Location','southwest','NumColumns',1);
    ylim([bit_floor 1]);
    xlim([min(snr)-0.5 max(snr)+0.5]);
end

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'direct_benchmarks_suite_v66', opts);
end
