function out = run_final_blockC_resume_v72(varargin)
%RUN_FINAL_BLOCKC_RESUME_V72  Resume-safe endogenous-aware recursion bridge.
%
% Default final-paper setting:
%   trials = 100
%   snr    = 15:30
%
% The runner checkpoints every SNR separately and then merges all
% Table_Endogenous_Aware_Family.csv files into a final table/plot.

p = inputParser;
addParameter(p, 'snr', 15:30, @isnumeric);
addParameter(p, 'trials', 100, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'samples', 80000, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'trainLen', 8000, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'save_dir', 'paper_final_BlockC_endogenous_resume_v72', @ischar);
addParameter(p, 'fig_visible', 'off', @ischar);
addParameter(p, 'exclude_classical_nlms', true, @islogical);
addParameter(p, 'force', false, @islogical);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
if ~exist(opt.save_dir, 'dir'), mkdir(opt.save_dir); end
if ~exist(fullfile(opt.save_dir, 'chunks'), 'dir')
    mkdir(fullfile(opt.save_dir, 'chunks'));
end

run_log = fullfile(opt.save_dir, 'BlockC_master_log.txt');
local_log(run_log, 'START Block C: trials=%d samples=%d trainLen=%d snr=[%s]', ...
    opt.trials, opt.samples, opt.trainLen, num2str(opt.snr));

manifest = table();
for ii = 1:numel(opt.snr)
    snr_db = opt.snr(ii);
    chunk_dir = fullfile(opt.save_dir, 'chunks', sprintf('snr%02d', snr_db));
    mat_file = fullfile(chunk_dir, sprintf('blockC_snr%02d.mat', snr_db));
    csv_file = fullfile(chunk_dir, 'Table_Endogenous_Aware_Family.csv');
    if ~exist(chunk_dir, 'dir'), mkdir(chunk_dir); end

    if exist(csv_file, 'file') == 2 && ~opt.force
        if exist(mat_file, 'file') ~= 2
            checkpoint_table = readtable(csv_file); %#ok<NASGU>
            save(mat_file, 'checkpoint_table', 'opt', 'snr_db', '-v7.3');
            local_log(run_log, 'REPAIR Block C SNR=%g; CSV existed, wrote lightweight MAT checkpoint', snr_db);
        end
        local_log(run_log, 'SKIP Block C SNR=%g; checkpoint exists', snr_db);
        manifest = [manifest; local_manifest_row('BlockC', snr_db, opt.trials, opt.samples, mat_file, 'skipped')]; %#ok<AGROW>
        continue;
    end

    local_log(run_log, 'RUN Block C SNR=%g', snr_db);
    chunk_log = fullfile(chunk_dir, sprintf('blockC_snr%02d_log.txt', snr_db));
    diary(chunk_log); diary on;
    try
        out_snr = run_paper('endogenous_family', ...
            'trials', opt.trials, ...
            'snr', snr_db, ...
            'samples', opt.samples, ...
            'trainLen', opt.trainLen, ...
            'save_dir', chunk_dir, ...
            'fig_visible', opt.fig_visible);
        save(mat_file, 'out_snr', 'opt', 'snr_db', '-v7.3');
        manifest = [manifest; local_manifest_row('BlockC', snr_db, opt.trials, opt.samples, mat_file, 'done')]; %#ok<AGROW>
        local_log(run_log, 'DONE Block C SNR=%g', snr_db);
    catch ME
        diary off;
        local_log(run_log, 'FAIL Block C SNR=%g: %s', snr_db, ME.message);
        rethrow(ME);
    end
    diary off;
end

merged = local_merge_tables(opt);
writetable(manifest, fullfile(opt.save_dir, 'BlockC_manifest.csv'));
out = struct('manifest', manifest, 'table', merged, 'save_dir', opt.save_dir, 'options', opt);
save(fullfile(opt.save_dir, 'BlockC_resume_summary.mat'), 'out', '-v7.3');
local_write_description(opt.save_dir, opt);
local_log(run_log, 'COMPLETE Block C');
end

function T = local_merge_tables(opt)
T = table();
for ii = 1:numel(opt.snr)
    csv_file = fullfile(opt.save_dir, 'chunks', sprintf('snr%02d', opt.snr(ii)), ...
        'Table_Endogenous_Aware_Family.csv');
    if exist(csv_file, 'file') ~= 2
        continue;
    end
    Tc = readtable(csv_file);
    T = [T; Tc]; %#ok<AGROW>
end
if isempty(T)
    return;
end
if opt.exclude_classical_nlms && any(strcmp(T.Properties.VariableNames, 'Method'))
    T = T(~strcmp(string(T.Method), "NLMS"), :);
end
writetable(T, fullfile(opt.save_dir, 'BlockC_Endogenous_Aware_Merged.csv'));
local_plot_blockC(T, opt);
end

function local_plot_blockC(T, opt)
if ~all(ismember({'Method','SNRdB','BER'}, T.Properties.VariableNames))
    return;
end
methods = unique(string(T.Method), 'stable');
fig = figure('Color','w','Visible',opt.fig_visible,'Position',[80 80 900 650]);
hold on; grid on; box on;
cols = lines(numel(methods));
marks = {'o','s','^','d','v','>','p','h'};
for mi = 1:numel(methods)
    idx = string(T.Method) == methods(mi);
    [x, order] = sort(T.SNRdB(idx));
    y = T.BER(idx);
    y = y(order);
    semilogy(x, max(y, realmin), ['-' marks{min(mi,numel(marks))}], ...
        'LineWidth', 1.8, 'MarkerSize', 6, 'Color', cols(mi,:), ...
        'MarkerFaceColor', cols(mi,:));
end
yline(2.4e-4, 'k--', 'KP4 FEC 2.4e-4');
xlabel('SNR (dB)');
ylabel('pre-FEC BER');
title('Endogenous-aware recursion bridge');
legend(methods, 'Location','southwest', 'Interpreter','none');
set(gca, 'YScale', 'log');
try
    exportgraphics(fig, fullfile(opt.save_dir, 'BlockC_Endogenous_Aware_Merged_BER.png'), 'Resolution', 300);
    exportgraphics(fig, fullfile(opt.save_dir, 'Endogenous_Aware_Recursion_Bridge_MonteCarlo_BER.png'), 'Resolution', 300);
catch
    saveas(fig, fullfile(opt.save_dir, 'BlockC_Endogenous_Aware_Merged_BER.png'));
    saveas(fig, fullfile(opt.save_dir, 'Endogenous_Aware_Recursion_Bridge_MonteCarlo_BER.png'));
end
try
    savefig(fig, fullfile(opt.save_dir, 'BlockC_Endogenous_Aware_Merged_BER.fig'));
catch
end
close(fig);
end

function local_write_description(save_dir, opt)
txt = sprintf(['Endogenous-aware recursion bridge\n\n' ...
    'Purpose: this Monte Carlo BER-vs-SNR experiment isolates the single-bank ' ...
    'endogenous-aware update before adding the full HMM-routed multi-state-bank ' ...
    'architecture. It compares prior SMNLMS/SM-sign-NLMS recursions against the ' ...
    'endogenous-aware NLMS/SMNLMS-style bridge recursion on the controlled Markov ' ...
    'tracking stress channel.\n\n' ...
    'Monte Carlo setting: %d trials, %d samples/trial, trainLen=%d, SNR=[%s] dB.\n\n' ...
    'Interpretation: the bridge recursion demonstrates that endogenous-aware ' ...
    'threshold/gating improves a single-bank adaptive receiver. The full Proposed ' ...
    'MSB receiver then adds state-local memory and HMM/FIR routing for the larger ' ...
    'tracking gain.\n'], ...
    opt.trials, opt.samples, opt.trainLen, num2str(opt.snr));
fid = fopen(fullfile(save_dir, 'Endogenous_Aware_Recursion_Bridge_README.txt'), 'w');
if fid > 0
    fprintf(fid, '%s', txt);
    fclose(fid);
end
end

function row = local_manifest_row(block, snr_db, trials, samples, file, status)
row = table(string(block), snr_db, trials, samples, string(file), string(status), ...
    'VariableNames', {'Block','SNRdB','Trials','Samples','Checkpoint','Status'});
end

function local_log(log_file, fmt, varargin)
msg = sprintf(fmt, varargin{:});
line = sprintf('[%s] %s\n', datestr(now, 31), msg);
fprintf('%s', line);
fid = fopen(log_file, 'a');
if fid > 0
    fprintf(fid, '%s', line);
    fclose(fid);
end
end
