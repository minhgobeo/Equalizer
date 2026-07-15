% Auto-split from NCKH_v53.m (original line 2340).
% Folder: utils/plotting

function plot_enhanced_ser_comparison(ser_static, ser_markov, cfg)
% Enhanced 2x2 plot: static vs Markov channel + SER improvement ratio
    alg_names = {'Proposed','LMS','NLMS','RLS','SM-sign-NLMS VSS','SM-sign-NLMS'};
    markers   = {'o-','x-','s-','d-','v-','^-'};
    lw_prop = 2.0;
    lw_base = 1.2;
    lws = [lw_prop, lw_base, lw_base, lw_base, lw_base, lw_base];

    figure('Name','Enhanced SER Comparison','Position',[100 100 1100 850]); clf;
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    % --- Panel (a): SER vs SNR — static channel ---
    nexttile;
    fields_s = {ser_static.SER_prop, ser_static.SER_lms, ser_static.SER_nlms, ...
                ser_static.SER_rls, ser_static.SER_smsign_vss, ser_static.SER_smsign};
    for k=1:6
        semilogy(ser_static.snr_list, fields_s{k}, markers{k}, 'LineWidth', lws(k)); hold on;
    end
    grid on; xlabel('SNR (dB)'); ylabel('SER');
    title('(a) SER vs SNR — Static channel');
    legend(alg_names, 'Location','southwest','FontSize',8);

    % --- Panel (b): SER vs SNR — Markov channel ---
    if ~isempty(ser_markov)
        nexttile;
        fields_m = {ser_markov.SER_prop, ser_markov.SER_lms, ser_markov.SER_nlms, ...
                    ser_markov.SER_rls, ser_markov.SER_smsign_vss, ser_markov.SER_smsign};
        for k=1:6
            semilogy(ser_markov.snr_list, fields_m{k}, markers{k}, 'LineWidth', lws(k)); hold on;
        end
        grid on; xlabel('SNR (dB)'); ylabel('SER');
        title('(b) SER vs SNR — Markov channel');
        legend(alg_names, 'Location','southwest','FontSize',8);

        % --- Panel (c): SER improvement ratio (Markov) ---
        nexttile;
        % Plot SER_baseline / SER_proposed for each baseline
        ser_p = max(ser_markov.SER_prop, 1e-6);
        for k=2:6
            ratio = fields_m{k} ./ ser_p;
            plot(ser_markov.snr_list, ratio, markers{k}, 'LineWidth', lws(k)); hold on;
        end
        yline(1.0, 'k--', 'LineWidth', 1.0);
        grid on; xlabel('SNR (dB)'); ylabel('SER_{baseline} / SER_{proposed}');
        title('(c) Relative SER — Markov channel');
        legend(alg_names(2:end), 'Location','best','FontSize',8);
        ylim([0.5 max(3.0, max(ylim))]);

        % --- Panel (d): SER gap (static vs Markov) for proposed vs SM-sign-NLMS VSS ---
        nexttile;
        plot(ser_static.snr_list, ser_static.SER_prop, 'bo-', 'LineWidth', 1.8); hold on;
        plot(ser_markov.snr_list, ser_markov.SER_prop, 'rs--', 'LineWidth', 1.8);
        % Compare with SM-sign-NLMS VSS (2024 benchmark)
        plot(ser_static.snr_list, ser_static.SER_smsign_vss, 'b^:', 'LineWidth', 1.2);
        plot(ser_markov.snr_list, ser_markov.SER_smsign_vss, 'r^:', 'LineWidth', 1.2);
        grid on; xlabel('SNR (dB)'); ylabel('SER');
        title('(d) Static vs Markov — Proposed & SM-sign-NLMS VSS');
        legend({'Proposed (static)','Proposed (Markov)', ...
                'SM-sign-NLMS VSS (static)','SM-sign-NLMS VSS (Markov)'}, ...
            'Location','southwest','FontSize',8);
        set(gca,'YScale','log');
    else
        % No Markov data — just plot static with theoretical floor
        nexttile;
        text(0.5, 0.5, 'Markov SER not computed', 'HorizontalAlignment','center');
        nexttile;
        nexttile;
    end
end


