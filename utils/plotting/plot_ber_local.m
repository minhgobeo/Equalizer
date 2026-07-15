% Auto-split from NCKH_v53.m (original line 10803).
% Folder: utils/plotting

function plot_ber_local(title_text, snr_list, BER, names, bit_floor)
    Nalg = numel(names);
    BER_disp = max(BER, bit_floor);
 
    figure('Name', title_text); clf;
    ccolors = {[0 0.45 0.74], [0.85 0.33 0.10], [0.93 0.69 0.13], ...
               [0.49 0.18 0.56], [0.47 0.67 0.19], [0.30 0.75 0.93]};
    marks = {'o','x','s','d','^','v'};
    for a = 1:Nalg
        lw = 1.4; if a == 1, lw = 2.4; end
        ms = 7; if a == 1, ms = 10; end
        semilogy(snr_list, BER_disp(:,a), ['-' marks{a}], ...
                 'Color', ccolors{a}, 'LineWidth', lw, ...
                 'MarkerFaceColor', ccolors{a}, 'MarkerSize', ms);
        hold on;
    end
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2);
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2);
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2);
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title(title_text); legend(names, 'Location','best');
    ylim([bit_floor/3, 1]);
end

