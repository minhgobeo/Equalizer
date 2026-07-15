function out = run_blockA_ber_plot(varargin)
%RUN_BLOCKA_BER_PLOT  Load checkpoint .mat files and plot Monte Carlo BER curve.
%
%  Reads all blockA_snrXX.mat checkpoints, aggregates BER across SNRs 15-25,
%  and produces a publication-ready semilogy BER curve.
%
%  Usage:
%    run_blockA_ber_plot('save_dir', 'paper_final_BlockA_hybrid_v72', 'fig_visible', 'on')

p = inputParser;
addParameter(p, 'save_dir',    'paper_final_BlockA_hybrid_v72', @ischar);
addParameter(p, 'snr_range',   15:25, @isnumeric);
addParameter(p, 'fig_visible', 'on',  @ischar);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));

chunk_root = fullfile(opt.save_dir, 'chunks');

% ---- load all checkpoint mats ----
snr_list = sort(opt.snr_range(:)');
Nsnr = numel(snr_list);

Nalg = 10;
BER_all  = NaN(Nsnr, Nalg);
names    = {};
bit_floor = 1e-7;

for si = 1:Nsnr
    snr_db   = snr_list(si);
    mat_file = fullfile(chunk_root, sprintf('snr%02d', snr_db), ...
                        sprintf('blockA_snr%02d.mat', snr_db));
    if ~exist(mat_file, 'file')
        fprintf('[ber_plot] WARNING: checkpoint not found for SNR=%d, skipping\n', snr_db);
        continue;
    end
    ck = load(mat_file, 'out_snr');
    if ~isfield(ck, 'out_snr')
        fprintf('[ber_plot] WARNING: out_snr missing in %s\n', mat_file);
        continue;
    end
    pkg = ck.out_snr;
    if isfield(pkg, 'BER') && ~isempty(pkg.BER)
        row = pkg.BER(1, :);   % 1 SNR per checkpoint
        BER_all(si, 1:numel(row)) = row;
    end
    if isempty(names) && isfield(pkg, 'names')
        names = pkg.names;
    end
    if isfield(pkg, 'bit_floor')
        bit_floor = min(bit_floor, pkg.bit_floor);
    end
end

if isempty(names)
    names = {'Algorithm 2 (proposed HMM-MSB)', 'Oracle MSB', ...
             'Algorithm 1 (single-bank)', 'NLMS', ...
             'SM-sign-NLMS VSS', 'SM-sign-NLMS', ...
             'SMNLMS', 'Liu SS-LMS', 'Chen pulse-ref', 'Cui HMM adapted'};
end

BER_plot = max(BER_all, bit_floor);

% ---- plot ----
% Same indices and colors as run_mb_ber_compare
plot_idx = [1 3 6 7 8 9 10];
ccolors  = {[0 0.45 0.74],   [0.5 0.0 0.5],    [0.85 0.33 0.10], ...
            [0.93 0.69 0.13], [0.47 0.67 0.19], [0.30 0.75 0.93], ...
            [0.49 0.18 0.56], [0.64 0.08 0.18], [0.25 0.25 0.25], ...
            [0.10 0.55 0.45]};
marks    = {'o','*','s','d','^','v','>','p','x','h'};

fig = figure('Color','w','Visible', opt.fig_visible, 'Position',[80 80 760 560]);
hold on;
for ii = 1:numel(plot_idx)
    a  = plot_idx(ii);
    lw = 1.4; if a == 1, lw = 2.6; end
    ms = 7;   if a == 1, ms = 10; end
    semilogy(snr_list, BER_plot(:,a), ['-' marks{a}], ...
             'Color', ccolors{a}, 'LineWidth', lw, ...
             'MarkerFaceColor', ccolors{a}, 'MarkerSize', ms, ...
             'DisplayName', names{a});
end

yline(2.4e-4, '--', 'Color',[0.6 0 0], 'LineWidth', 1.6, ...
      'Label', 'KP4 FEC  2.4\times10^{-4}', ...
      'LabelHorizontalAlignment','left', 'LabelVerticalAlignment','bottom', ...
      'FontSize', 9, 'HandleVisibility','off');

grid on;
xlabel('SNR (dB)', 'FontSize', 11);
ylabel('Pre-FEC BER', 'FontSize', 11);
title('PAM4 Markov-ISI BER: Algorithm 2 (HMM-MSB) vs baselines, SNR 15–25 dB', ...
      'FontSize', 11, 'FontWeight', 'bold');
legend('Location','best','FontSize',9,'Interpreter','none');
xlim([snr_list(1)-0.5, snr_list(end)+0.5]);
ylim([bit_floor/3, 1]);
set(gca, 'YScale', 'log', 'FontSize', 10);

% ---- save ----
png_file = fullfile(opt.save_dir, 'BlockA_BER_MC_SNR15_25.png');
try
    exportgraphics(fig, png_file, 'Resolution', 300);
catch
    saveas(fig, png_file);
end
try
    savefig(fig, strrep(png_file, '.png', '.fig'));
catch
end

% Save CSV
csv_file = fullfile(opt.save_dir, 'BlockA_BER_MC_SNR15_25.csv');
valid_idx = plot_idx(plot_idx <= numel(names));
T = array2table(BER_all(:, valid_idx), ...
    'VariableNames', matlab.lang.makeValidName(names(valid_idx)));
T.SNRdB = snr_list(:);
T = movevars(T, 'SNRdB', 'Before', 1);
writetable(T, csv_file);

fprintf('[ber_plot] Saved %s\n', png_file);
fprintf('[ber_plot] Saved %s\n', csv_file);

if strcmp(opt.fig_visible, 'off')
    close(fig);
end

out = struct('BER', BER_all, 'snr_list', snr_list, 'names', {names}, ...
             'png', png_file, 'csv', csv_file);
end
