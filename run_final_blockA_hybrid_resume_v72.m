function out = run_final_blockA_hybrid_resume_v72(varargin)
%RUN_FINAL_BLOCKA_HYBRID_RESUME_V72  Two-tier Block A runner with per-SNR resume.
%
%  Tier LOW  (default SNR 15-22): samples=1e6, trials=10   — fast, enough stats
%  Tier HIGH (default SNR 23-30): samples=1e7, trials=100  — deep tail statistics
%
%  Checkpoints each SNR at: <save_dir>/chunks/snrXX/blockA_snrXX.mat
%  Checkpoint stores trials_used + samples_used so re-runs with a config change
%  will automatically re-compute that SNR.
%
%  Re-running the same command resumes from the last incomplete SNR.

p = inputParser;
addParameter(p, 'snr_low',      15:22,  @isnumeric);
addParameter(p, 'trials_low',   10,     @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, 'samples_low',  1e6,    @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, 'snr_high',     23:30,  @isnumeric);
addParameter(p, 'trials_high',  100,    @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, 'samples_high', 1e7,    @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, 'save_dir', 'paper_final_BlockA_hybrid_v72', @ischar);
addParameter(p, 'fig_visible', 'off', @ischar);
addParameter(p, 'force', false, @islogical);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));

if ~exist(opt.save_dir, 'dir'), mkdir(opt.save_dir); end
chunk_root = fullfile(opt.save_dir, 'chunks');
if ~exist(chunk_root, 'dir'), mkdir(chunk_root); end

run_log = fullfile(opt.save_dir, 'BlockA_hybrid_master_log.txt');
local_log(run_log, 'START BlockA-hybrid | low=[%s] %dt %gs | high=[%s] %dt %gs', ...
    num2str(opt.snr_low), opt.trials_low, opt.samples_low, ...
    num2str(opt.snr_high), opt.trials_high, opt.samples_high);

old_vis = get(0, 'DefaultFigureVisible');
set(0, 'DefaultFigureVisible', opt.fig_visible);
cleanup_vis = onCleanup(@() set(0, 'DefaultFigureVisible', old_vis)); %#ok<NASGU>

% Build unified per-SNR config vectors
snr_all     = [opt.snr_low(:)', opt.snr_high(:)'];
trials_all  = [repmat(opt.trials_low,  1, numel(opt.snr_low)), ...
               repmat(opt.trials_high, 1, numel(opt.snr_high))];
samples_all = [repmat(opt.samples_low,  1, numel(opt.snr_low)), ...
               repmat(opt.samples_high, 1, numel(opt.snr_high))];

manifest = table();

for ii = 1:numel(snr_all)
    snr_db  = snr_all(ii);
    trials  = trials_all(ii);
    samples = samples_all(ii);

    chunk_dir = fullfile(chunk_root, sprintf('snr%02d', snr_db));
    if ~exist(chunk_dir, 'dir'), mkdir(chunk_dir); end
    mat_file  = fullfile(chunk_dir, sprintf('blockA_snr%02d.mat', snr_db));
    chunk_log = fullfile(chunk_dir, sprintf('blockA_snr%02d_log.txt', snr_db));

    % Skip if checkpoint exists AND config matches
    if exist(mat_file, 'file') == 2 && ~opt.force
        ck = load(mat_file, 'trials_used', 'samples_used');
        config_matches = isfield(ck, 'trials_used') && isfield(ck, 'samples_used') && ...
                         ck.trials_used == trials && ck.samples_used == samples;
        if config_matches
            local_log(run_log, 'SKIP SNR=%g (trials=%d samples=%g)', snr_db, trials, samples);
            manifest = [manifest; local_manifest_row(snr_db, trials, samples, mat_file, 'skipped')]; %#ok<AGROW>
            continue;
        else
            local_log(run_log, 'RERUN SNR=%g (config changed: stored %d/%g → new %d/%g)', ...
                snr_db, ck.trials_used, ck.samples_used, trials, samples);
        end
    end

    local_log(run_log, 'RUN SNR=%g | trials=%d samples=%g', snr_db, trials, samples);
    diary(chunk_log); diary on;
    try
        out_snr = run_paper('ber_severe', ...
            'trials',      trials, ...
            'samples',     samples, ...
            'snr',         snr_db, ...
            'plot',        true, ...
            'fig_visible', opt.fig_visible, ...
            'save_dir',    chunk_dir);
        trials_used  = trials;
        samples_used = samples;
        save(mat_file, 'out_snr', 'opt', 'snr_db', 'trials_used', 'samples_used', '-v7.3');
        local_save_figure(chunk_dir, sprintf('BlockA_BER_SNR%02d', snr_db));
        manifest = [manifest; local_manifest_row(snr_db, trials, samples, mat_file, 'done')]; %#ok<AGROW>
        local_log(run_log, 'DONE SNR=%g', snr_db);
    catch ME
        diary off;
        local_log(run_log, 'FAIL SNR=%g: %s', snr_db, ME.message);
        rethrow(ME);
    end
    diary off;
end

writetable(manifest, fullfile(opt.save_dir, 'BlockA_hybrid_manifest.csv'));
out = struct('manifest', manifest, 'save_dir', opt.save_dir, 'options', opt);
save(fullfile(opt.save_dir, 'BlockA_hybrid_summary.mat'), 'out', '-v7.3');
local_log(run_log, 'COMPLETE BlockA-hybrid: %d/%d SNRs done', height(manifest), numel(snr_all));
end

% -------------------------------------------------------------------------
function row = local_manifest_row(snr_db, trials, samples, file, status)
row = table(snr_db, trials, samples, string(file), string(status), ...
    'VariableNames', {'SNRdB','Trials','Samples','Checkpoint','Status'});
end

function local_log(log_file, fmt, varargin)
msg  = sprintf(fmt, varargin{:});
line = sprintf('[%s] %s\n', datestr(now, 31), msg); %#ok<TNOW1,DATST>
fprintf('%s', line);
fid = fopen(log_file, 'a');
if fid > 0
    fprintf(fid, '%s', line);
    fclose(fid);
end
end

function local_save_figure(save_dir, stem)
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
