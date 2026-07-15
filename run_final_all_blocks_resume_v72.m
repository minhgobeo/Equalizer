function out = run_final_all_blocks_resume_v72(varargin)
%RUN_FINAL_ALL_BLOCKS_RESUME_V72  One-command final simulation launcher.
%
% This calls the three resume-safe runners:
%   Block A: severe Markov-ISI, 100 trials, 1e7 symbols by default
%   Block B: C2M tracking stress, 100 trials, 3 modes, 2 802.3ck baud rates
%   Block C: endogenous-aware recursion bridge, 100 trials
%
% Example:
%   out = run_final_all_blocks_resume_v72();
%
% Smoke example:
%   out = run_final_all_blocks_resume_v72('snr',30,'trialsA',1, ...
%       'samplesA',2000,'trialsB',1,'samplesB',3000, ...
%       'trialsC',1,'samplesC',3000,'baudGBd',26.5625);

p = inputParser;
addParameter(p, 'root_dir', 'paper_final_all_blocks_resume_v72', @ischar);
addParameter(p, 'snr', 15:30, @isnumeric);
addParameter(p, 'runA', true, @islogical);
addParameter(p, 'runB', true, @islogical);
addParameter(p, 'runC', true, @islogical);
addParameter(p, 'trialsA', 100, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'samplesA', 1e7, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'trainLenA', [], @(x)isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'trialsB', 100, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'samplesB', 80000, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'trainLenB', 12000, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'profilesB', {'slow','medium','fast'}, @(x)iscell(x) || isstring(x) || ischar(x));
addParameter(p, 'baudGBd', [26.5625 53.125], @isnumeric);
addParameter(p, 'batchTrialsB', 1, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'trialsC', 100, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'samplesC', 80000, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'trainLenC', 8000, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'fig_visible', 'off', @ischar);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
if ~exist(opt.root_dir, 'dir'), mkdir(opt.root_dir); end
master_log = fullfile(opt.root_dir, 'final_all_blocks_master_log.txt');
local_log(master_log, 'START final all blocks');

out = struct();
if opt.runA
    local_log(master_log, 'CALL Block A');
    out.BlockA = run_final_blockA_resume_v72( ...
        'snr', opt.snr, ...
        'trials', opt.trialsA, ...
        'samples', opt.samplesA, ...
        'trainLen', opt.trainLenA, ...
        'save_dir', fullfile(opt.root_dir, 'BlockA_mb_severe'), ...
        'fig_visible', opt.fig_visible);
end

if opt.runB
    local_log(master_log, 'CALL Block B');
    out.BlockB = run_final_blockB_multibaud_resume_v72( ...
        'snr', opt.snr, ...
        'trials', opt.trialsB, ...
        'samples', opt.samplesB, ...
        'trainLen', opt.trainLenB, ...
        'profiles', opt.profilesB, ...
        'baudGBd', opt.baudGBd, ...
        'batch_trials', opt.batchTrialsB, ...
        'save_dir', fullfile(opt.root_dir, 'BlockB_tracking_stress_multibaud'));
end

if opt.runC
    local_log(master_log, 'CALL Block C');
    out.BlockC = run_final_blockC_resume_v72( ...
        'snr', opt.snr, ...
        'trials', opt.trialsC, ...
        'samples', opt.samplesC, ...
        'trainLen', opt.trainLenC, ...
        'save_dir', fullfile(opt.root_dir, 'BlockC_endogenous_bridge'), ...
        'fig_visible', opt.fig_visible);
end

save(fullfile(opt.root_dir, 'final_all_blocks_resume_summary.mat'), 'out', 'opt', '-v7.3');
local_log(master_log, 'COMPLETE final all blocks');
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
