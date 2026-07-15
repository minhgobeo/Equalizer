function out = run_final_blockC_batched_resume_v72(varargin)
%RUN_FINAL_BLOCKC_BATCHED_RESUME_V72  More robust Block C runner.
%
% Unlike run_final_blockC_resume_v72, this checkpoints every small batch
% inside each SNR.  If MATLAB crashes at trial 25/100, only the current
% small batch is lost.

p = inputParser;
addParameter(p, 'snr', 15:30, @isnumeric);
addParameter(p, 'trials', 100, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'batch_trials', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'samples', 80000, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'trainLen', 8000, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'save_dir', 'paper_final_BlockC_100trials_v72_batched', @ischar);
addParameter(p, 'fig_visible', 'off', @ischar);
addParameter(p, 'max_retries', 3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'exclude_classical_nlms', true, @islogical);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
if ~exist(opt.save_dir, 'dir'), mkdir(opt.save_dir); end
run_log = fullfile(opt.save_dir, 'BlockC_batched_master_log.txt');
local_log(run_log, 'START Block C batched: trials=%d batch_trials=%d samples=%d snr=[%s]', ...
    opt.trials, opt.batch_trials, opt.samples, num2str(opt.snr));

manifest = table();
for si = 1:numel(opt.snr)
    snr_db = opt.snr(si);
    chunk_csv = fullfile(opt.save_dir, 'chunks', sprintf('snr%02d', snr_db), ...
        'Table_Endogenous_Aware_Family.csv');
    if exist(chunk_csv, 'file') == 2
        local_log(run_log, 'SKIP SNR=%g; merged chunk exists', snr_db);
        manifest = [manifest; local_manifest_row(snr_db, opt.trials, opt.samples, chunk_csv, 'skipped')]; %#ok<AGROW>
        continue;
    end

    n_batches = ceil(opt.trials / opt.batch_trials);
    for bi = 1:n_batches
        batch_trials = min(opt.batch_trials, opt.trials - (bi-1)*opt.batch_trials);
        batch_dir = fullfile(opt.save_dir, sprintf('_batches_snr%02d', snr_db), sprintf('batch%03d', bi));
        batch_csv = fullfile(batch_dir, 'Table_Endogenous_Aware_Family.csv');
        batch_mat = fullfile(batch_dir, sprintf('blockC_snr%02d_batch%03d.mat', snr_db, bi));
        if exist(batch_csv, 'file') == 2 && exist(batch_mat, 'file') == 2
            local_log(run_log, '  resume SNR=%g batch=%d/%d', snr_db, bi, n_batches);
            continue;
        end

        ok = false;
        last_err = [];
        for attempt = 1:opt.max_retries
            try
                local_log(run_log, '  run SNR=%g batch=%d/%d attempt=%d/%d', ...
                    snr_db, bi, n_batches, attempt, opt.max_retries);
                run_blockC_onebatch_v72(snr_db, bi, ...
                    'save_dir', opt.save_dir, ...
                    'batch_trials', batch_trials, ...
                    'samples', opt.samples, ...
                    'trainLen', opt.trainLen, ...
                    'fig_visible', opt.fig_visible);
                ok = exist(batch_csv, 'file') == 2 && exist(batch_mat, 'file') == 2;
                if ok, break; end
                last_err = MException('BlockC:MissingBatchCsv', 'Missing batch output: %s', batch_csv);
            catch ME
                last_err = ME;
                local_log(run_log, '  warn SNR=%g batch=%d attempt=%d: %s', ...
                    snr_db, bi, attempt, ME.message);
            end
        end
        if ~ok
            local_log(run_log, 'FAIL SNR=%g batch=%d: %s', snr_db, bi, last_err.message);
            rethrow(last_err);
        end
    end

    merge_blockC_batches_v72(snr_db, ...
        'save_dir', opt.save_dir, ...
        'trials', opt.trials, ...
        'batch_trials', opt.batch_trials);
    manifest = [manifest; local_manifest_row(snr_db, opt.trials, opt.samples, chunk_csv, 'done')]; %#ok<AGROW>
end

T = local_merge_all(opt);
writetable(manifest, fullfile(opt.save_dir, 'BlockC_batched_manifest.csv'));
out = struct('manifest', manifest, 'table', T, 'save_dir', opt.save_dir, 'options', opt);
save(fullfile(opt.save_dir, 'BlockC_batched_resume_summary.mat'), 'out', '-v7.3');
local_write_description(opt.save_dir, opt);
local_log(run_log, 'COMPLETE Block C batched');
end

function T = local_merge_all(opt)
T = table();
for si = 1:numel(opt.snr)
    f = fullfile(opt.save_dir, 'chunks', sprintf('snr%02d', opt.snr(si)), ...
        'Table_Endogenous_Aware_Family.csv');
    if exist(f, 'file') == 2
        T = [T; readtable(f)]; %#ok<AGROW>
    end
end
if isempty(T), return; end
if opt.exclude_classical_nlms && any(strcmp(T.Properties.VariableNames, 'Method'))
    T = T(~strcmp(string(T.Method), "NLMS"), :);
end
writetable(T, fullfile(opt.save_dir, 'BlockC_Endogenous_Aware_Merged.csv'));
local_plot(T, opt);
end

function local_plot(T, opt)
if ~all(ismember({'Method','SNRdB','BER'}, T.Properties.VariableNames)), return; end
methods = unique(string(T.Method), 'stable');
fig = figure('Color','w','Visible',opt.fig_visible,'Position',[80 80 900 650]);
hold on; grid on; box on;
cols = lines(numel(methods));
marks = {'o','s','^','d','v','>','p','h'};
for mi = 1:numel(methods)
    idx = string(T.Method) == methods(mi);
    [x, order] = sort(T.SNRdB(idx));
    y = T.BER(idx); y = y(order);
    semilogy(x, max(y, realmin), ['-' marks{min(mi,numel(marks))}], ...
        'LineWidth', 1.8, 'MarkerSize', 6, 'Color', cols(mi,:), ...
        'MarkerFaceColor', cols(mi,:));
end
yline(2.4e-4, 'k--', 'KP4 FEC 2.4e-4');
xlabel('SNR (dB)'); ylabel('pre-FEC BER');
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

function row = local_manifest_row(snr_db, trials, samples, file, status)
row = table(snr_db, trials, samples, string(file), string(status), ...
    'VariableNames', {'SNRdB','Trials','Samples','Checkpoint','Status'});
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
