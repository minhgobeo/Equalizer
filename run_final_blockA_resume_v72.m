function out = run_final_blockA_resume_v72(varargin)
%RUN_FINAL_BLOCKA_RESUME_V72  Resume-safe Block A severe Markov-ISI benchmark.
%
% Default final-paper setting requested by the user:
%   trials  = 100
%   samples = 1e7 symbols per trial
%   snr     = 15:30
%
% The runner checkpoints after each SNR in:
%   <save_dir>/chunks/snrXX/blockA_snrXX.mat
%
% Re-running the same command skips completed SNRs.

p = inputParser;
addParameter(p, 'snr', 15:30, @isnumeric);
addParameter(p, 'trials', 100, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'samples', 1e7, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'trainLen', [], @(x)isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'save_dir', 'paper_final_BlockA_mb_severe_resume_v72', @ischar);
addParameter(p, 'fig_visible', 'off', @ischar);
addParameter(p, 'force', false, @islogical);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
if ~exist(opt.save_dir, 'dir'), mkdir(opt.save_dir); end
if ~exist(fullfile(opt.save_dir, 'chunks'), 'dir')
    mkdir(fullfile(opt.save_dir, 'chunks'));
end

run_log = fullfile(opt.save_dir, 'BlockA_master_log.txt');
local_log(run_log, 'START Block A: trials=%d samples=%g snr=[%s]', ...
    opt.trials, opt.samples, num2str(opt.snr));

old_vis = get(0, 'DefaultFigureVisible');
set(0, 'DefaultFigureVisible', opt.fig_visible);
cleanup = onCleanup(@() set(0, 'DefaultFigureVisible', old_vis));

manifest = table();
for ii = 1:numel(opt.snr)
    snr_db = opt.snr(ii);
    chunk_dir = fullfile(opt.save_dir, 'chunks', sprintf('snr%02d', snr_db));
    if ~exist(chunk_dir, 'dir'), mkdir(chunk_dir); end
    mat_file = fullfile(chunk_dir, sprintf('blockA_snr%02d.mat', snr_db));
    chunk_log = fullfile(chunk_dir, sprintf('blockA_snr%02d_log.txt', snr_db));

    if exist(mat_file, 'file') == 2 && ~opt.force
        local_log(run_log, 'SKIP Block A SNR=%g; checkpoint exists', snr_db);
        manifest = [manifest; local_manifest_row('BlockA', snr_db, opt.trials, opt.samples, NaN, mat_file, 'skipped')]; %#ok<AGROW>
        continue;
    end

    local_log(run_log, 'RUN Block A SNR=%g', snr_db);
    diary(chunk_log); diary on;
    try
        nv = {'trials', opt.trials, 'samples', opt.samples, ...
            'snr', snr_db, 'plot', true, 'fig_visible', opt.fig_visible, ...
            'save_dir', chunk_dir};
        if ~isempty(opt.trainLen)
            nv = [nv, {'trainLen', opt.trainLen}]; %#ok<AGROW>
        end
        out_snr = run_paper('ber_severe', nv{:});
        save(mat_file, 'out_snr', 'opt', 'snr_db', '-v7.3');
        local_save_current_figure(chunk_dir, sprintf('BlockA_BER_SNR%02d', snr_db));
        manifest = [manifest; local_manifest_row('BlockA', snr_db, opt.trials, opt.samples, NaN, mat_file, 'done')]; %#ok<AGROW>
        local_log(run_log, 'DONE Block A SNR=%g', snr_db);
    catch ME
        diary off;
        local_log(run_log, 'FAIL Block A SNR=%g: %s', snr_db, ME.message);
        rethrow(ME);
    end
    diary off;
end

writetable(manifest, fullfile(opt.save_dir, 'BlockA_manifest.csv'));
out = struct('manifest', manifest, 'save_dir', opt.save_dir, 'options', opt);
save(fullfile(opt.save_dir, 'BlockA_resume_summary.mat'), 'out', '-v7.3');
local_log(run_log, 'COMPLETE Block A');
end

function row = local_manifest_row(block, snr_db, trials, samples, baud, file, status)
row = table(string(block), snr_db, trials, samples, baud, string(file), string(status), ...
    'VariableNames', {'Block','SNRdB','Trials','Samples','BaudGBd','Checkpoint','Status'});
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

function local_save_current_figure(save_dir, stem)
figs = findall(0, 'Type', 'figure');
if isempty(figs), return; end
fig = figs(1);
try
    exportgraphics(fig, fullfile(save_dir, [stem '.png']), 'Resolution', 300);
catch
    saveas(fig, fullfile(save_dir, [stem '.png']));
end
try
    savefig(fig, fullfile(save_dir, [stem '.fig']));
catch
end
close(fig);
end
