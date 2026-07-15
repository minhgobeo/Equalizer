function fname = plot_ck_stress(out, opts)
%PLOT_CK_STRESS  802.3ck-inspired stressed-channel summary.

p = pal_ieee();

methods  = out.methods;
profiles = out.profiles;
snrs     = out.snr_list;
T        = out.table;
nmeth    = numel(methods);
nprof    = numel(profiles);
nsnr     = numel(snrs);

BER  = nan(nprof, nsnr, nmeth);
ACC  = nan(nprof, nsnr);
PASS = false(nprof, nsnr);
for k = 1:numel(T)
    pi_ = find(strcmp(profiles, T(k).profile));
    si_ = find(snrs == T(k).SNRdB);
    BER(pi_, si_, :) = T(k).BER;
    ACC(pi_, si_)    = 100*T(k).hmm_accuracy;
    PASS(pi_, si_)   = T(k).pass_fec;
end

fig = figure('Name','CK stress summary','Color','w','Position',[100 100 1500 540]);
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

% --- (a) IL_max tail + pre-eq ---
nexttile; hold on;
yyaxis left;
bar(1:numel(out.ck_tail), out.ck_tail, 0.6, 'FaceColor', p.proposed, 'EdgeColor','none');
ylabel('IL_{max} residual tap');
xlabel('post-cursor index');
ylim([min(out.ck_tail)*1.4, max(out.ck_tail)*1.4]);

yyaxis right;
preeq = out.preeq_taps;
stem(0:numel(preeq)-1, preeq, 'filled', ...
     'Color', p.alg5, 'MarkerFaceColor', p.alg5, 'LineWidth', 1.3);
ylabel('pre-equalizer FIR');

title(sprintf('(a) Channel tail and pre-eq, IL@Nyq=%.1f dB', out.ck_tail_info.IL_dB_at_Nyquist));

% --- (b) BER per profile ---
nexttile; hold on;
cols = {p.proposed, p.oracle, p.alg5, p.nlms, p.smsign};
mks  = {'o','p','s','^','d'};
plot_methods = [1 3 4 5];  % Oracle is printed only, not drawn.
si_ref = nsnr;
xx = 1:nprof;
for ii = 1:numel(plot_methods)
    m = plot_methods(ii);
    if m == 1, lw = 2.2; ms = 9.5; else, lw = 1.4; ms = 7; end
    y = max(squeeze(BER(:, si_ref, m)), 1e-8);
    semilogy(xx, y, ['-' mks{m}], ...
        'Color', cols{m}, 'LineWidth', lw, ...
        'MarkerFaceColor', cols{m}, 'MarkerSize', ms, ...
        'DisplayName', methods{m});
end
yline(2.4e-4, '--', 'KP4 FEC', 'Color', p.fec_line, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','left');
set(gca,'YScale','log','XTick', xx, 'XTickLabel', profiles, 'XTickLabelRotation', 18);
ylabel('pre-FEC BER');
ylim([1e-8 1]);
title(sprintf('(b) BER per profile @ SNR=%d dB', snrs(si_ref)));
legend('Location','southwest');

% --- (c) HMM accuracy + PASS/FAIL ---
nexttile; hold on;
cols2 = {p.alg5, p.proposed};
b = bar(xx, ACC);
for si = 1:nsnr
    b(si).FaceColor = cols2{si}; b(si).EdgeColor = 'none';
end
for pi_ = 1:nprof
    for si = 1:nsnr
        if PASS(pi_,si)
            tstr = 'PASS'; tcol = [0 0.55 0];
        else
            tstr = 'FAIL'; tcol = [0.8 0 0];
        end
        x_pos = pi_ + (si - (nsnr+1)/2)*0.27;
        text(x_pos, ACC(pi_,si)+1.5, tstr, ...
            'HorizontalAlignment','center', ...
            'FontSize', 9, 'FontWeight','bold', 'Color', tcol);
    end
end
set(gca,'XTick', xx, 'XTickLabel', profiles, 'XTickLabelRotation', 18);
ylabel('HMM state accuracy (%)');
title('(c) HMM accuracy with FEC pass/fail');
legend(arrayfun(@(s) sprintf('SNR=%d dB',s), snrs, 'uni', false), 'Location','southeast');
ylim([0 110]);

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'ck_stress_summary', opts);
end
