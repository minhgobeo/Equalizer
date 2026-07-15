function out = run_8023ck_channel_physics_analysis_v72(varargin)
%RUN_8023CK_CHANNEL_PHYSICS_ANALYSIS_V72
%   Reviewer-facing channel-analysis package for the 802.3ck benchmark.
%
%   This script does not run equalizers.  It documents how the public
%   Touchstone/S-parameter channels affect PAM4 signals:
%     1) |Sdd21| frequency-response overlay for C2M/C2C cases.
%     2) Baud-dependent symbol-spaced pulse taps and postcursor ISI.
%     3) Tx/Rx waveform distortion for 26.5625 and 53.125 GBd.
%     4) COM-style impairment proxies: AWGN, NEXT/FEXT, jitter, combined.
%
%   The analysis is COM-style and paper-facing, not an IEEE compliance test.

p = inputParser;
addParameter(p, 'save_dir', 'paper_channel_physics_8023ck_v72', @ischar);
addParameter(p, 'channel_dir', fullfile('data','8023ck_channels'), @ischar);
addParameter(p, 'baudGBd', [26.5625 53.125], @isnumeric);
addParameter(p, 'snr', 24, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'samples', 20000, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'seed', 720808, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
if ~exist(opt.save_dir, 'dir'), mkdir(opt.save_dir); end

cases = {'C2M_10dB','C2M_14dB','C2M_16dB', ...
         'C2C_10dB','C2C_18dB','C2C_20dB'};

out = struct();
out.save_dir = opt.save_dir;
out.baudGBd = opt.baudGBd;
out.cases = cases;

out.frequency_table = local_plot_sdd21_overlay(opt, cases);
out.baud_table = local_plot_baud_pulse_and_waveform(opt, cases);
out.impairment_table = local_plot_impairment_impact(opt);

save(fullfile(opt.save_dir, 'channel_physics_analysis_v72.mat'), 'out', 'opt', '-v7.3');
fprintf('[channel_physics_v72] Done. Output: %s\n', opt.save_dir);
end

% =====================================================================
function summary = local_plot_sdd21_overlay(opt, cases)
cat0 = build_8023ck_channel_catalog('root_dir', opt.channel_dir, ...
    'allow_synthetic', true, 'baud', opt.baudGBd(1)*1e9, ...
    'sps', 16, 'ntaps', 9, 'override_manifest_baud', true);

nyq = opt.baudGBd(:) * 1e9 / 2;
summary = table();
fig = figure('Color','w','Visible','off','Position',[80 80 1080 680]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
cols = lines(numel(cases));
styles = {'-','--','-.',':','-','--'};

for k = 1:numel(cases)
    ch = local_pick_case(cat0, cases{k});
    if ~isfield(ch,'file') || isempty(ch.file) || exist(ch.file,'file') ~= 2
        continue;
    end
    sp = load_touchstone_sparam(ch.file);
    [f, H] = local_sdd21(sp, '12_34');
    Hdc = interp1(f, H, 0, 'pchip', 'extrap');
    mag_db = 20*log10(abs(H) / max(abs(Hdc), eps));

    plot(ax, f/1e9, mag_db, styles{k}, 'Color', cols(k,:), ...
        'LineWidth', 1.55, 'DisplayName', cases{k});

    row = table(string(cases{k}), string(ch.group), string(ch.file), max(f)/1e9, ...
        'VariableNames', {'CaseID','Group','File','MeasuredFmax_GHz'});
    for bi = 1:numel(opt.baudGBd)
        loss = -interp1(f, mag_db, min(nyq(bi), max(f)), 'pchip', 'extrap');
        row.(sprintf('IL_at_Nyq_%sGBd_dB', local_tag(opt.baudGBd(bi)))) = loss;
    end
    summary = [summary; row]; %#ok<AGROW>
end

for bi = 1:numel(opt.baudGBd)
    xline(ax, nyq(bi)/1e9, '--', ...
        sprintf('R_s/2 %.2f GHz (%.4g GBd)', nyq(bi)/1e9, opt.baudGBd(bi)), ...
        'HandleVisibility','off', 'LabelOrientation','horizontal');
end
yline(ax, -3, ':', '-3 dB', 'Color',[0.45 0.45 0.45], 'HandleVisibility','off');
xlabel(ax, 'Frequency (GHz)');
ylabel(ax, '|Sdd21| relative to DC (dB)');
title(ax, 'IEEE 802.3ck-style C2M/C2C channel loss versus frequency (symbol Nyquist = R_s/2)');
legend(ax, 'Location','southwest', 'Interpreter','none');
xlim(ax, [0 40]);
ylim(ax, [-35 3]);

fname = fullfile(opt.save_dir, 'ChannelFrequency_Sdd21Overlay_C2M_C2C.png');
local_save(fig, fname);
writetable(summary, fullfile(opt.save_dir, 'ChannelFrequency_Sdd21Overlay_C2M_C2C.csv'));
fprintf('[channel_physics_v72] saved %s\n', fname);
end

% =====================================================================
function summary = local_plot_baud_pulse_and_waveform(opt, cases)
cfg = build_main_config();
cfg.Nsym = opt.samples;
cfg.trainLen = min(3000, floor(0.20*cfg.Nsym));
cfg.SNRdB = opt.snr;
tx_ffe = [1; -0.08; 0.03];

rng(opt.seed);
d = local_pam4(cfg);
tx = local_apply_tx_ffe(d, tx_ffe);

target_cases = {'C2M_10dB','C2M_14dB','C2M_16dB'};
summary = table();

fig = figure('Color','w','Visible','off','Position',[70 70 1320 780]);
tiledlayout(numel(target_cases), numel(opt.baudGBd), ...
    'Padding','compact','TileSpacing','compact');

fig2 = figure('Color','w','Visible','off','Position',[70 70 1320 760]);
tiledlayout(numel(target_cases), numel(opt.baudGBd), ...
    'Padding','compact','TileSpacing','compact');

for bi = 1:numel(opt.baudGBd)
    baud = opt.baudGBd(bi) * 1e9;
    catalog = build_8023ck_channel_catalog('root_dir', opt.channel_dir, ...
        'allow_synthetic', true, 'baud', baud, 'sps', 16, 'ntaps', 9, ...
        'override_manifest_baud', true);
    for ci = 1:numel(target_cases)
        ch = local_pick_case(catalog, target_cases{ci});
        h0 = ch.symbol_taps(:);
        h_eff = conv(tx_ffe, h0);
        h = h_eff / max(abs(h_eff(1)), eps);
        isi = sum(h(2:end).^2) / max(h(1)^2, eps);
        post1 = local_get(h, 2);

        figure(fig);
        ax = nexttile((ci-1)*numel(opt.baudGBd)+bi); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        stem(ax, 0:numel(h)-1, h, 'filled', 'Color',[0.00 0.45 0.74], 'LineWidth',1.2);
        yline(ax, 0, 'k:');
        title(ax, sprintf('%s @ %.4g GBd\npost-ISI %.3g, h1 %.3g', ...
            target_cases{ci}, opt.baudGBd(bi), isi, post1), 'Interpreter','none');
        xlabel(ax,'Symbol-spaced tap index');
        ylabel(ax,'Normalized tap');

        [rx_clean, ~] = local_fir_channel(tx, h0);
        rx = rx_clean * (rms(tx) / max(rms(rx_clean), eps));
        sigma2 = mean(tx.^2) / (10^(cfg.SNRdB/10));
        rx = rx + sqrt(sigma2)*randn(size(rx));
        rx = rx * (rms(tx) / max(rms(rx), eps));
        met = local_simple_metrics(rx, d, cfg);

        figure(fig2);
        ax = nexttile((ci-1)*numel(opt.baudGBd)+bi); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        seg = cfg.trainLen + (1:260);
        plot(ax, seg, tx(seg), 'Color',[0.15 0.15 0.15], 'LineWidth',0.65);
        plot(ax, seg, rx(seg), 'Color',[0.85 0.33 0.10], 'LineWidth',0.9);
        title(ax, sprintf('%s @ %.4g GBd\nEVM %.3f, eye proxy %.3f', ...
            target_cases{ci}, opt.baudGBd(bi), met.evm, met.eye_proxy), 'Interpreter','none');
        xlabel(ax,'Symbol index');
        ylabel(ax,'Amplitude');
        if ci == 1 && bi == 1
            legend(ax, {'Tx PAM4 after FFE','Channel output + AWGN'}, 'Location','best');
        end

        row = table(string(target_cases{ci}), opt.baudGBd(bi), ch.insertion_loss_db, ...
            local_get(ch, 'measured_freq_max_hz')/1e9, h(1), post1, isi, met.evm, met.eye_proxy, ...
            'VariableNames', {'CaseID','BaudGBd','ManifestIL_dB','MeasuredFmax_GHz', ...
            'MainTap','FirstPostcursor','PostcursorISI','EVMProxy','EyeProxy'});
        summary = [summary; row]; %#ok<AGROW>
    end
end

sgtitle(fig, 'Baud-dependent symbol-spaced pulse response from 802.3ck Touchstone channels');
fname = fullfile(opt.save_dir, 'BaudImpact_SymbolTaps_C2M.png');
local_save(fig, fname);
fprintf('[channel_physics_v72] saved %s\n', fname);

sgtitle(fig2, sprintf('Baud-dependent PAM4 waveform distortion, SNR = %g dB', opt.snr));
fname2 = fullfile(opt.save_dir, 'BaudImpact_WaveformDistortion_C2M.png');
local_save(fig2, fname2);
fprintf('[channel_physics_v72] saved %s\n', fname2);

writetable(summary, fullfile(opt.save_dir, 'BaudImpact_ChannelMetrics_C2M.csv'));
end

% =====================================================================
function summary = local_plot_impairment_impact(opt)
cfg = build_main_config();
cfg.Nsym = opt.samples;
cfg.trainLen = min(3000, floor(0.20*cfg.Nsym));
cfg.SNRdB = opt.snr;
baud = 53.125e9;

catalog = build_8023ck_channel_catalog('root_dir', opt.channel_dir, ...
    'allow_synthetic', true, 'baud', baud, 'sps', 16, 'ntaps', 9, ...
    'override_manifest_baud', true);
ch = local_pick_case(catalog, 'C2M_16dB');

rng(opt.seed + 11);
d = local_pam4(cfg);
tx = local_apply_tx_ffe(d, [1; -0.08; 0.03]);
[rx_clean, ~] = local_fir_channel(tx, ch.symbol_taps(:));
rx_clean = rx_clean * (rms(tx) / max(rms(rx_clean), eps));

sigma2 = mean(tx.^2) / (10^(cfg.SNRdB/10));
awgn = sqrt(sigma2) * randn(size(rx_clean));

ag1 = local_apply_tx_ffe(local_pam4(cfg), [1; -0.05]);
ag2 = local_apply_tx_ffe(local_pam4(cfg), [1; 0.04]);
h = ch.symbol_taps(:);
fext = filter(0.055 * [0; h(1:min(5,end))], 1, ag1);
next = filter(0.035 * [h(1:min(5,end)); 0], 1, ag2);
xtalk = fext + next;

jittered = local_symbol_timing_jitter(rx_clean, 0.035);
jitter_delta = jittered - rx_clean;

signals = {rx_clean, rx_clean + awgn, rx_clean + xtalk, ...
           rx_clean + jitter_delta, rx_clean + awgn + xtalk + jitter_delta};
labels = {'Channel only','Channel + AWGN','Channel + NEXT/FEXT proxy', ...
          'Channel + timing jitter proxy','Combined AWGN + XTALK + jitter'};

fig = figure('Color','w','Visible','off','Position',[70 70 1420 820]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
summary = table();
for k = 1:numel(signals)
    y = signals{k};
    y = y * (rms(tx) / max(rms(y), eps));
    met = local_simple_metrics(y, d, cfg);
    summary = [summary; table(string(labels{k}), opt.snr, met.evm, met.eye_proxy, ...
        rms(y-rx_clean), 'VariableNames', {'Case','SNRdB','EVMProxy','EyeProxy','AddedDistortionRMS'})]; %#ok<AGROW>

    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    seg = cfg.trainLen + (1:360);
    plot(ax, seg, tx(seg), 'Color',[0.12 0.12 0.12], 'LineWidth',0.65);
    plot(ax, seg, y(seg), 'Color',[0.00 0.45 0.74], 'LineWidth',0.85);
    title(ax, sprintf('%s\nEVM %.3f | eye proxy %.3f', labels{k}, met.evm, met.eye_proxy), ...
        'Interpreter','none');
    xlabel(ax,'Symbol index');
    ylabel(ax,'Amplitude');
    if k == 1
        legend(ax, {'Tx PAM4','Impaired Rx'}, 'Location','best');
    end
end

ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
yyaxis(ax,'left');
bar(ax, summary.EVMProxy, 0.55, 'FaceColor',[0.00 0.45 0.74]);
ylabel(ax,'EVM proxy');
yyaxis(ax,'right');
plot(ax, 1:height(summary), summary.EyeProxy, '-o', 'Color',[0.85 0.33 0.10], ...
    'LineWidth',1.5, 'MarkerFaceColor',[0.85 0.33 0.10]);
ylabel(ax,'eye proxy');
set(ax,'XTick',1:height(summary),'XTickLabel',summary.Case,'XTickLabelRotation',25);
title(ax,'Impairment metric summary');

sgtitle('COM-style impairment impact at 53.125 GBd: AWGN, crosstalk, jitter, and combined stress');
fname = fullfile(opt.save_dir, 'COMStyle_ImpairmentImpact_53p125GBd.png');
local_save(fig, fname);
writetable(summary, fullfile(opt.save_dir, 'COMStyle_ImpairmentImpact_53p125GBd.csv'));
fprintf('[channel_physics_v72] saved %s\n', fname);
end

% =====================================================================
function [f, H] = local_sdd21(sp, port_order)
S = sp.S;
switch lower(port_order)
    case '12_34'
        H = 0.5 * squeeze(S(3,1,:) - S(3,2,:) - S(4,1,:) + S(4,2,:));
    case '13_24'
        H = 0.5 * squeeze(S(2,1,:) - S(2,3,:) - S(4,1,:) + S(4,3,:));
    otherwise
        error('Unsupported port order.');
end
f = sp.freq_hz(:);
H = H(:);
good = isfinite(f) & isfinite(real(H)) & isfinite(imag(H));
f = f(good);
H = H(good);
if min(f) > 0
    f = [0; f];
    H = [H(1); H];
end
[f, ia] = unique(f, 'stable');
H = H(ia);
end

function ch = local_pick_case(catalog, id)
idx = find(strcmp({catalog.case_id}, id), 1);
if isempty(idx), error('Missing channel case %s', id); end
ch = catalog(idx);
end

function d = local_pam4(cfg)
sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
d = cfg.A(sym_idx).';
d = d(:);
end

function y = local_apply_tx_ffe(d, taps)
y = filter(taps(:), 1, d(:));
if rms(y) > eps
    y = y * (rms(d) / rms(y));
end
end

function [r, st] = local_fir_channel(tx, h)
r = filter(h(:), 1, tx(:));
st = struct();
end

function met = local_simple_metrics(y, d, cfg)
y = y(:);
d = d(:);
N = min(numel(y), numel(d));
idx = (cfg.trainLen+1):N;
if isempty(idx), idx = 1:N; end
scale = (d(idx)'*y(idx)) / max(y(idx)'*y(idx), eps);
ys = scale * y(idx);
err = ys - d(idx);
met.evm = rms(err) / max(rms(d(idx)), eps);
q = zeros(4,2);
A = sort(cfg.A(:));
for k = 1:numel(A)
    z = ys(d(idx)==A(k));
    if isempty(z)
        q(k,:) = [NaN NaN];
    else
        q(k,:) = prctile(z, [5 95]);
    end
end
gaps = q(2:end,1) - q(1:end-1,2);
met.eye_proxy = min(gaps, [], 'omitnan');
end

function y = local_symbol_timing_jitter(x, jitter_ui)
x = x(:);
N = numel(x);
t = (1:N).';
dn = jitter_ui * randn(N,1);
y = interp1(t, x, t + dn, 'linear', 'extrap');
end

function val = local_get(x, field_or_idx)
if isstruct(x)
    if isfield(x, field_or_idx)
        val = x.(field_or_idx);
    else
        val = NaN;
    end
else
    idx = field_or_idx;
    if numel(x) >= idx
        val = x(idx);
    else
        val = 0;
    end
end
end

function s = local_tag(x)
s = strrep(sprintf('%.4g', x), '.', 'p');
end

function local_save(fig, fname)
set(fig, 'PaperPositionMode', 'auto');
try
    exportgraphics(fig, fname, 'Resolution', 300);
catch
    saveas(fig, fname);
end
close(fig);
end
