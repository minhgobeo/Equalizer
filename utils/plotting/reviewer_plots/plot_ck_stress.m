function fname = plot_ck_stress(out, opts)
%PLOT_CK_STRESS  IEEE 802.3ck-inspired stressed-channel summary + eye plots.

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

fig = figure('Name','CK stress summary','Color','w','Position',[100 100 1700 620]);
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

% --- (a) IL_max tail + pre-eq ---
nexttile; hold on;
yyaxis left;
bar(1:numel(out.ck_tail), out.ck_tail, 0.6, 'FaceColor', p.proposed, 'EdgeColor','none');
ylabel('IL_{max}-derived residual tap');
xlabel('post-cursor index');
if max(abs(out.ck_tail)) > 0
    ylim([min(out.ck_tail)*1.4, max(out.ck_tail)*1.4]);
end

yyaxis right;
preeq = out.preeq_taps;
stem(0:numel(preeq)-1, preeq, 'filled', ...
     'Color', p.alg5, 'MarkerFaceColor', p.alg5, 'LineWidth', 1.3);
ylabel('pre-equalizer FIR');
title(sprintf('(a) CK tail + pre-eq, IL@Nyq=%.1f dB', out.ck_tail_info.IL_dB_at_Nyquist));

% --- (b) BER per profile ---
nexttile; hold on;
cols = local_method_colors(p);
mks  = local_method_markers();
if isfield(out,'plot_methods')
    plot_methods = out.plot_methods;
else
    plot_methods = [1 3 4 5];
end
% Make sure Oracle is never plotted even if accidentally included.
is_oracle = ~cellfun(@isempty, strfind(methods(plot_methods), 'Oracle'));
plot_methods = plot_methods(~is_oracle);
si_ref = nsnr;
xx = 1:nprof;
for ii = 1:numel(plot_methods)
    m = plot_methods(ii);
    if m == 1, lw = 2.2; ms = 8.8; else, lw = 1.25; ms = 6.2; end
    y = max(squeeze(BER(:, si_ref, m)), 1e-8);
    semilogy(xx, y, ['-' mks{m}], ...
        'Color', cols{m}, 'LineWidth', lw, ...
        'MarkerFaceColor', cols{m}, 'MarkerSize', ms, ...
        'DisplayName', methods{m});
end
yline(out.ber_pre_fec_threshold, '--', 'KP4 FEC 2.4e-4', 'Color', p.fec_line, 'LineWidth', 1.0, ...
      'FontSize', 9, 'LabelHorizontalAlignment','left');
set(gca,'YScale','log','XTick', xx, 'XTickLabel', profiles, 'XTickLabelRotation', 18);
ylabel('pre-FEC BER');
ylim([1e-8 1]);
title(sprintf('(b) BER per CK profile @ SNR=%d dB', snrs(si_ref)));
legend('Location','southwest','FontSize',7);

% --- (c) HMM accuracy + PASS/FAIL ---
nexttile; hold on;
cols2 = {p.alg5, p.proposed};
b = bar(xx, ACC);
for si = 1:nsnr
    b(si).FaceColor = cols2{min(si,numel(cols2))}; b(si).EdgeColor = 'none';
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
title('(c) Algorithm 2 state accuracy and FEC status');
legend(arrayfun(@(s) sprintf('SNR=%d dB',s), snrs, 'uni', false), 'Location','southeast');
ylim([0 110]);

ieee_access_style(fig);
f_summary = save_fig_helper(fig, opts.save_dir, 'ck_stress_summary_v70', opts);

f_eye = '';
f_split = {};
if isfield(out,'eye_bank') && isfield(out.eye_bank,'signals')
    % Legacy compact all-profile eye figure.
    f_eye = local_plot_ck_eye(out.eye_bank, opts, p);

    % v71: also export one 3x3 eye figure per CK profile for paper readability.
    try
        f_split = plot_ck_stress_eye_split(out, opts);
    catch ME
        warning('plot_ck_stress:split_eye_failed', ...
                'Split CK eye figures failed: %s', ME.message);
        f_split = {};
    end
end

fname = {f_summary};
if ~isempty(f_eye)
    fname{end+1} = f_eye;
end
if ~isempty(f_split)
    fname = [fname, f_split];
end
if numel(fname) == 1
    fname = fname{1};
end
end

% =====================================================================
function f_eye = local_plot_ck_eye(eye_bank, opts, p)
profiles = eye_bank.profiles;
methods = eye_bank.methods;
nprof = numel(profiles);
nmeth = numel(methods);
cols = local_method_colors_for_eye(p, nmeth);

fig = figure('Name','CK eye diagrams all benchmark methods','Color','w', ...
             'Position',[50 50 1900 1050]);
tiledlayout(nprof, nmeth+1, 'TileSpacing','compact', 'Padding','compact');

% Common y-limits across all eye panels for visual comparability.
allx = [];
for pi = 1:nprof
    if ~isempty(eye_bank.rx_before{pi}), allx = [allx; eye_bank.rx_before{pi}(:)]; end %#ok<AGROW>
    for mi = 1:nmeth
        x = eye_bank.signals{pi,mi};
        if ~isempty(x), allx = [allx; x(:)]; end %#ok<AGROW>
    end
end
if isempty(allx)
    yl = [-4 4];
else
    allx = allx(isfinite(allx));
    if isempty(allx)
        yl = [-4 4];
    else
        q = prctile(allx, [0.5 99.5]);
        pad = 0.12*max(q(2)-q(1), eps);
        yl = [q(1)-pad, q(2)+pad];
    end
end

sps = 16;
g = rc_pulse(0.5, sps, 8);

for pi = 1:nprof
    % Column 1: received before adaptive EQ.
    nexttile; hold on;
    x = eye_bank.rx_before{pi};
    xos = local_symbol_to_eye_waveform(x, g, sps);
    eye_plot_reshape_fixed(xos, sps, 'max_traces', 130, 'color', [0.15 0.15 0.15], 'line_width', 0.20);
    ylim(yl); grid on;
    title(sprintf('%s\nBefore EQ', profiles{pi}), 'Interpreter','none', 'FontSize',8);
    if pi < nprof, xlabel(''); end

    for mi = 1:nmeth
        nexttile; hold on;
        x = eye_bank.signals{pi,mi};
        xos = local_symbol_to_eye_waveform(x, g, sps);
        eye_plot_reshape_fixed(xos, sps, 'max_traces', 130, 'color', cols{mi}, 'line_width', 0.20);
        ylim(yl); grid on;
        title(strrep(methods{mi},' ','\n'), 'Interpreter','tex', 'FontSize',8);
        if pi < nprof, xlabel(''); end
    end
end

sgtitle(sprintf('Eye diagrams under same CK-inspired benchmark traces, SNR=%d dB (Oracle omitted)', eye_bank.snr_ref), ...
        'FontWeight','bold');
ieee_access_style(fig);
f_eye = save_fig_helper(fig, opts.save_dir, 'ck_stress_eye_all_methods_snr22_v70', opts);
end

function xos = local_symbol_to_eye_waveform(x, g, sps)
if isempty(x)
    xos = zeros(2*sps,1); return;
end
x = x(:);
x = x - median(x,'omitnan');
% Keep the natural amplitude scale; only remove DC offset for eye centering.
xos = conv(local_upsample_zeros(x, sps), g, 'same');
end

function y = local_upsample_zeros(x, sps)
y = zeros(numel(x)*sps,1);
y(1:sps:end) = x(:);
end

function cols = local_method_colors(p)
cols = {p.proposed, p.oracle, p.alg5, p.nlms, p.smsign, p.liu_ss, p.liu_ta, p.cui, p.chen};
end

function cols = local_method_colors_for_eye(p, nmeth)
base = {p.proposed, p.alg5, p.nlms, p.smsign, p.liu_ss, p.liu_ta, p.cui, p.chen};
if nmeth <= numel(base)
    cols = base(1:nmeth);
else
    cols = repmat(base,1,ceil(nmeth/numel(base)));
    cols = cols(1:nmeth);
end
end

function mks = local_method_markers()
mks = {'o','p','s','^','d','v','>','<','h'};
end
