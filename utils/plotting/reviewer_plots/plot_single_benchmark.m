function fname = plot_single_benchmark(out, mode, opts)
%PLOT_SINGLE_BENCHMARK  BER vs SNR for one benchmark adapter.

p = pal_ieee();
mode = lower(mode);

fig = figure('Name',['Single benchmark: ' mode], ...
             'Color','w','Position',[100 100 920 520]);

bit_floor = 1e-7;

switch mode
    case {'souza_smsign','souza'}
        snr = out.snr_list;  regimes = out.regimes;
        % Series defined as: data, label, color, marker, linewidth, markersize
        series = {
            out.BER_smsign_fix,  'SM-sign-NLMS',          p.smsign,      '-s', 1.5, 8
            out.BER_smsign_vss,  'SM-sign-NLMS-VSS',      p.smsign_vss,  '-d', 1.5, 8
            out.BER_alg2,        'Algorithm 2 (proposed)',     p.proposed,    '-o', 2.0, 9
        };
        title_str = 'Souza et al.\ SM-sign-NLMS direct baseline';

    case {'cui_hmm','cui'}
        snr = out.snr_list;  regimes = out.regimes;
        series = {
            out.ber_grid, 'ExtraTrees-HMM (Cui, adapted)', p.cui, '-d', 1.5, 8
        };
        title_str = sprintf('Cui ExtraTrees-HMM (adapted, classifier=%s)', out.classifier_kind);

    case {'liu_ss_lms','liu','ss_lms'}
        snr = out.snr_list;  regimes = out.regimes;
        series = {
            out.BER_sslms,    'SS-LMS DFE (Liu, alg.)',      p.liu_ss,    '-^', 1.5, 8
            out.BER_tasslms,  'TA-SS-LMS DFE (Liu, alg.)',   p.liu_ta,    '-v', 1.5, 8
            out.BER_alg2,     'Algorithm 2 (proposed)',           p.proposed,  '-o', 2.0, 9
        };
        title_str = 'Liu et al.\ 2023 SS-LMS DFE (algorithmic re-implementation)';

    case {'dolatsara_scbo','dolatsara'}
        snr = out.snr_list;  regimes = out.regimes;
        series = {
            out.ber_grid, 'SCBO Tx-FIR (Dolatsara, adapted)', p.dolatsara, '-x', 1.5, 8
        };
        title_str = sprintf('Dolatsara SCBO Tx-FIR (adapted, w=[%s])', sprintf('%+.3f ', out.best_w));

    case {'chen_pulse','chen'}
        snr = out.snr_list;  regimes = out.regimes;
        series = {
            out.ber_grid, 'Single-pulse FFE/DFE (Chen, ad.)', p.chen, '-x', 1.5, 8
        };
        title_str = 'Chen single-pulse FFE/DFE (adapted)';

    otherwise
        error('plot_single_benchmark: unknown mode %s', mode);
end

reg_lstyle = {'-','--'};

hold on;
for k = 1:size(series,1)
    data    = series{k,1};
    lbl     = series{k,2};
    col     = series{k,3};
    mk      = series{k,4}(2);     % marker char
    lw      = series{k,5};
    ms      = series{k,6};
    for rg = 1:numel(regimes)
        ls = reg_lstyle{rg};
        y = max(data(:,rg), bit_floor);
        semilogy(snr, y, [ls mk], ...
            'Color', col, 'LineWidth', lw, ...
            'MarkerFaceColor', col, 'MarkerSize', ms, ...
            'DisplayName', sprintf('%s - %s', lbl, regimes{rg}));
    end
end

yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
      'LabelHorizontalAlignment','left', 'FontSize', 9);
set(gca,'YScale','log');
xlabel('SNR (dB)'); ylabel('pre-FEC BER');
title(title_str, 'Interpreter','tex');
legend('Location','southwest','NumColumns',1);
ylim([bit_floor 1]);
xlim([min(snr)-0.5 max(snr)+0.5]);

ieee_access_style(fig);

base_name = ['bench_' regexprep(mode,'\W','_')];
fname = save_fig_helper(fig, opts.save_dir, base_name, opts);
end
