function fname = plot_hero_ber(out, opts)
%PLOT_HERO_BER  Hero BER curve for severe/realistic regime (main paper figure).
%
% Expects out from run_mb_ber_severe_v68 / run_mb_ber_realistic_v68:
%   out.snr_list, out.BER (Nsnr x Nalg), out.names, out.bit_floor
%
% Optional opts.regime_label = 'severe' | 'realistic' for title.

p = pal_ieee();

if ~isfield(opts,'regime_label'), opts.regime_label = 'BER'; end
regime_label = lower(opts.regime_label);

snr  = out.snr_list;
BER  = out.BER;
names = out.names;
bit_floor = out.bit_floor;

% Map known names to colors+markers from palette
color_for = containers.Map();
color_for('Algorithm 2 (proposed HMM-MSB)') = p.proposed;
color_for('Algorithm 6 v69 (estimated state)') = p.proposed;
color_for('Alg 6 (MSB est state, NEW)')        = p.proposed;
color_for('Algorithm 6 (proposed)')            = p.proposed;
color_for('Proposed')                          = p.proposed;
color_for('MSB ORACLE state')                  = p.oracle;
color_for('Multi-bank ORACLE state')           = p.oracle;
color_for('Algorithm 1 (single-bank)')         = p.alg5;
color_for('Algorithm 5 (single-bank)')         = p.alg5;
color_for('Alg 5 (single-bank)')               = p.alg5;
color_for('NLMS')                              = p.nlms;
color_for('NLMS reference')                    = p.nlms;
color_for('SM-sign-NLMS')                      = p.smsign;
color_for('SM-sign-NLMS VSS')                  = p.smsign_vss;
color_for('SM-sign-NLMS-VSS')                  = p.smsign_vss;
color_for('SMNLMS')                            = [0.30 0.30 0.30];
color_for('Liu SS-LMS')                        = [0.92 0.62 0.05];
color_for('Chen pulse-ref')                    = [0.42 0.42 0.42];
color_for('Cui HMM adapted')                   = [0.15 0.55 0.75];
color_for('LMS')                               = p.cui;
color_for('RLS')                               = p.dolatsara;

marker_for = containers.Map();
marker_for('Algorithm 2 (proposed HMM-MSB)') = 'o';
marker_for('Algorithm 6 v69 (estimated state)') = 'o';
marker_for('Alg 6 (MSB est state, NEW)')        = 'o';
marker_for('Algorithm 6 (proposed)')            = 'o';
marker_for('Proposed')                          = 'o';
marker_for('MSB ORACLE state')                  = 'p';   % pentagram for upper bound
marker_for('Multi-bank ORACLE state')           = 'p';
marker_for('Algorithm 1 (single-bank)')         = 's';
marker_for('Algorithm 5 (single-bank)')         = 's';
marker_for('Alg 5 (single-bank)')               = 's';
marker_for('NLMS')                              = '^';
marker_for('NLMS reference')                    = '^';
marker_for('SM-sign-NLMS')                      = 'd';
marker_for('SM-sign-NLMS VSS')                  = 'v';
marker_for('SM-sign-NLMS-VSS')                  = 'v';
marker_for('SMNLMS')                            = '^';
marker_for('Liu SS-LMS')                        = 'h';
marker_for('Chen pulse-ref')                    = 'o';
marker_for('Cui HMM adapted')                   = '>';
marker_for('LMS')                               = 'x';
marker_for('RLS')                               = '+';

fig = figure('Name',['Hero BER: ' regime_label], ...
             'Color','w','Position',[100 100 980 600]);
hold on;

for a = 1:numel(names)
    nm = names{a};
    if any(strcmp(nm, {'NLMS','NLMS reference','SM-sign-NLMS VSS','SM-sign-NLMS-VSS'}))
        continue;
    end
    if isKey(color_for, nm), col = color_for(nm); else, col = [0.4 0.4 0.4]; end
    if isKey(marker_for, nm), mk = marker_for(nm); else, mk = 'o'; end

    is_proposed = any(strcmpi(nm, {'Algorithm 2 (proposed HMM-MSB)', ...
                                   'Algorithm 6 v69 (estimated state)','Alg 6 (MSB est state, NEW)', ...
                                   'Algorithm 6 (proposed)','Proposed'}));
    is_oracle   = contains(lower(nm), 'oracle');

    if is_oracle
        % Oracle is an upper bound printed in tables only; do not draw it.
        continue;
    end

    if is_proposed
        lw = 2.4; ms = 9.5; ls = '-';
    else
        lw = 1.4; ms = 7;   ls = '-';
    end

    y = max(BER(:,a), bit_floor);
    semilogy(snr, y, [ls mk], ...
        'Color', col, 'LineWidth', lw, ...
        'MarkerFaceColor', col, 'MarkerSize', ms, ...
        'DisplayName', nm);
end

% FEC reference lines
yline(2.4e-4, '--', 'KP4 FEC 2.4\times10^{-4}', 'Color', p.fec_line, ...
      'LineWidth', 1.0, 'FontSize', 9, 'Interpreter','tex', ...
      'LabelHorizontalAlignment','left', 'HandleVisibility','off');
yline(1e-3, ':', '10^{-3}', 'Color', p.fec_line, 'LineWidth', 0.7, 'FontSize', 9, ...
      'LabelHorizontalAlignment','left', 'HandleVisibility','off');
yline(1e-5, ':', '10^{-5}', 'Color', p.fec_line, 'LineWidth', 0.7, 'FontSize', 9, ...
      'LabelHorizontalAlignment','left', 'HandleVisibility','off');

set(gca,'YScale','log');
xlabel('SNR (dB)');
ylabel('pre-FEC BER');
title(sprintf('PAM4 Markov-DFE BER, %s regime', regime_label));
legend('Location','southwest','NumColumns',1);
ylim([bit_floor/2 1]);
xlim([min(snr) max(snr)]);

ieee_access_style(fig);

base_name = ['hero_ber_' regexprep(regime_label,'\W','_')];
fname = save_fig_helper(fig, opts.save_dir, base_name, opts);
end
