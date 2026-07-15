function out = run_final_blockB_multibaud_resume_v72(varargin)
%RUN_FINAL_BLOCKB_MULTIBAUD_RESUME_V72  Resume-safe Block B tracking stress.
%
% Final-paper default requested by the user:
%   trials   = 100
%   samples  = 80000 symbols per trial
%   profiles = slow, medium, fast
%   baudGBd  = [26.5625 53.125]
%   snr      = 15:30
%
% Checkpoint granularity:
%   <save_dir>/baudXX/tmp_<profile>_snrXX/ieee8023ck_markov_sweep_summary.csv
%
% It also checkpoints each small batch:
%   <save_dir>/baudXX/_batches_<profile>_snrXX/batchYYY/*.csv

p = inputParser;
addParameter(p, 'snr', 15:30, @isnumeric);
addParameter(p, 'trials', 100, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'samples', 80000, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'trainLen', 12000, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'profiles', {'slow','medium','fast'}, @(x)iscell(x) || isstring(x) || ischar(x));
addParameter(p, 'baudGBd', [26.5625 53.125], @isnumeric);
addParameter(p, 'batch_trials', 1, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'max_retries', 5, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'save_dir', 'paper_final_BlockB_multibaud_100trials_resume_v72', @ischar);
addParameter(p, 'force_merge', false, @islogical);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
profiles = local_cellstr(opt.profiles);
if ~exist(opt.save_dir, 'dir'), mkdir(opt.save_dir); end
run_log = fullfile(opt.save_dir, 'BlockB_multibaud_master_log.txt');
local_log(run_log, 'START Block B: trials=%d samples=%d trainLen=%d snr=[%s] baudGBd=[%s]', ...
    opt.trials, opt.samples, opt.trainLen, num2str(opt.snr), num2str(opt.baudGBd));

manifest = table();
for bi = 1:numel(opt.baudGBd)
    baud_gbd = opt.baudGBd(bi);
    baud_hz = baud_gbd * 1e9;
    baud_dir = fullfile(opt.save_dir, local_baud_dir(baud_gbd));
    if ~exist(baud_dir, 'dir'), mkdir(baud_dir); end
    local_log(run_log, 'BAUD %.6g GBd', baud_gbd);

    for pi = 1:numel(profiles)
        profile = profiles{pi};
        for si = 1:numel(opt.snr)
            snr_db = opt.snr(si);
            chunk_csv = fullfile(baud_dir, sprintf('tmp_%s_snr%02d', profile, snr_db), ...
                'ieee8023ck_markov_sweep_summary.csv');

            if exist(chunk_csv, 'file') == 2 && ~opt.force_merge
                local_log(run_log, 'SKIP baud=%.6g profile=%s SNR=%g; chunk exists', baud_gbd, profile, snr_db);
                manifest = [manifest; local_manifest_row('BlockB', snr_db, opt.trials, opt.samples, baud_gbd, chunk_csv, profile, 'skipped')]; %#ok<AGROW>
                continue;
            end

            local_log(run_log, 'RUN baud=%.6g profile=%s SNR=%g', baud_gbd, profile, snr_db);
            n_batches = ceil(opt.trials / opt.batch_trials);
            for batch_idx = 1:n_batches
                batch_csv = fullfile(baud_dir, sprintf('_batches_%s_snr%02d', profile, snr_db), ...
                    sprintf('batch%03d', batch_idx), 'ieee8023ck_markov_sweep_summary.csv');
                if exist(batch_csv, 'file') == 2
                    local_log(run_log, '  resume batch %s SNR=%g b=%d/%d', profile, snr_db, batch_idx, n_batches);
                    continue;
                end

                ok = false;
                last_err = [];
                for attempt = 1:opt.max_retries
                    local_log(run_log, '  run batch %s SNR=%g b=%d/%d attempt=%d/%d', ...
                        profile, snr_db, batch_idx, n_batches, attempt, opt.max_retries);
                    try
                        run_blockB_100trials_onebatch_v72(profile, snr_db, batch_idx, ...
                            'save_dir', baud_dir, ...
                            'batch_trials', opt.batch_trials, ...
                            'samples', opt.samples, ...
                            'trainLen', opt.trainLen, ...
                            'baud', baud_hz);
                        ok = exist(batch_csv, 'file') == 2;
                        if ok, break; end
                        last_err = MException('BlockB:MissingBatchCsv', 'Batch CSV was not created: %s', batch_csv);
                    catch ME
                        last_err = ME;
                    end
                end
                if ~ok
                    local_log(run_log, 'FAIL batch baud=%.6g profile=%s SNR=%g b=%d: %s', ...
                        baud_gbd, profile, snr_db, batch_idx, last_err.message);
                    rethrow(last_err);
                end
            end

            merge_blockB_100trials_chunk_v72(profile, snr_db, ...
                'save_dir', baud_dir, ...
                'trials', opt.trials, ...
                'batch_trials', opt.batch_trials, ...
                'samples', opt.samples, ...
                'trainLen', opt.trainLen, ...
                'baud', baud_hz);
            manifest = [manifest; local_manifest_row('BlockB', snr_db, opt.trials, opt.samples, baud_gbd, chunk_csv, profile, 'done')]; %#ok<AGROW>
            local_log(run_log, 'DONE baud=%.6g profile=%s SNR=%g', baud_gbd, profile, snr_db);
        end
    end

    try
        out_baud = run_blockB_tracking_stress_all_recursions_v72( ...
            'snr', opt.snr, ...
            'profiles', profiles, ...
            'trials', opt.trials, ...
            'samples', opt.samples, ...
            'trainLen', opt.trainLen, ...
            'baud', baud_hz, ...
            'save_dir', baud_dir, ...
            'fig_visible', 'off', ...
            'resume', true);
        save(fullfile(baud_dir, 'BlockB_FinalMerged.mat'), 'out_baud', 'opt', 'baud_gbd', '-v7.3');
    catch ME
        local_log(run_log, 'WARN final merge/plot failed at baud=%.6g: %s', baud_gbd, ME.message);
    end
end

writetable(manifest, fullfile(opt.save_dir, 'BlockB_multibaud_manifest.csv'));
out = struct('manifest', manifest, 'save_dir', opt.save_dir, 'options', opt);
save(fullfile(opt.save_dir, 'BlockB_multibaud_resume_summary.mat'), 'out', '-v7.3');
local_log(run_log, 'COMPLETE Block B');
end

function c = local_cellstr(x)
if ischar(x), c = {x}; return; end
if isstring(x), c = cellstr(x); return; end
c = x;
end

function d = local_baud_dir(baud_gbd)
txt = strrep(sprintf('baud%gGBd', baud_gbd), '.', 'p');
d = regexprep(txt, '[^\w]', '_');
end

function row = local_manifest_row(block, snr_db, trials, samples, baud, file, profile, status)
row = table(string(block), string(profile), snr_db, trials, samples, baud, string(file), string(status), ...
    'VariableNames', {'Block','Profile','SNRdB','Trials','Samples','BaudGBd','Checkpoint','Status'});
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
