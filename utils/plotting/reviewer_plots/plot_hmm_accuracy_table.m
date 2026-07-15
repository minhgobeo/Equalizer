function fname = plot_hmm_accuracy_table(out, opts)
%PLOT_HMM_ACCURACY_TABLE  Visualize Table 5 (HMM state accuracy vs SNR).
%
% Expects out from run_hmm_accuracy_table with fields:
%   .snr_list, .acc_severe (raw), .acc_severe_best, .acc_realistic, .acc_realistic_best
% (or similar; we look up flexibly).

p = pal_ieee();

% Try to find the relevant fields in a way that's robust to small naming differences.
snr = [];
acc_sev = []; acc_real = [];
fnames = fieldnames(out);
for i = 1:numel(fnames)
    if isempty(snr) && contains(lower(fnames{i}), 'snr')
        v = out.(fnames{i});
        if isnumeric(v) && isvector(v), snr = v(:); end
    end
end
% Look for Severe / Realistic acc arrays
for i = 1:numel(fnames)
    nm_l = lower(fnames{i});
    v = out.(fnames{i});
    if isnumeric(v) && isvector(v) && numel(v) == numel(snr)
        if contains(nm_l,'sev') && contains(nm_l,'best')
            acc_sev = v(:);
        elseif contains(nm_l,'real') && contains(nm_l,'best')
            acc_real = v(:);
        end
    end
end

% Fallback: try matrix layouts
if isempty(acc_sev) && isfield(out,'acc_grid')
    acc_grid = out.acc_grid;
    if size(acc_grid,2) >= 2
        acc_sev = acc_grid(:,1); acc_real = acc_grid(:,2);
    end
end

if isempty(acc_sev) || isempty(snr)
    warning('plot_hmm_accuracy_table: could not extract data, skipping plot.');
    fname = ''; return;
end

fig = figure('Name','HMM accuracy table', ...
             'Color','w','Position',[100 100 920 520]);
hold on;
plot(snr, 100*acc_sev,  '-o', 'Color', p.alg5,      'LineWidth', 1.8, ...
     'MarkerFaceColor', p.alg5,      'MarkerSize', 9, 'DisplayName','severe');
plot(snr, 100*acc_real, '-s', 'Color', p.proposed,  'LineWidth', 1.8, ...
     'MarkerFaceColor', p.proposed,  'MarkerSize', 9, 'DisplayName','realistic');

yline(33.33, ':', 'random (1/3)', 'Color', p.fec_line, 'LineWidth', 0.8, ...
      'FontSize', 9, 'LabelHorizontalAlignment','right');
yline(80, '--', '80%', 'Color', p.fec_line, 'LineWidth', 0.8, ...
      'FontSize', 9, 'LabelHorizontalAlignment','right');

xlabel('SNR (dB)');
ylabel('HMM state accuracy (%)');
title('HMM state-tracking accuracy vs SNR (Table 5)');
legend('Location','southeast');
ylim([20 102]);
xlim([min(snr) max(snr)]);

ieee_access_style(fig);
fname = save_fig_helper(fig, opts.save_dir, 'hmm_accuracy_table', opts);
end
