function out_all = run_final_overnight_v72(varargin)
%RUN_FINAL_OVERNIGHT_V72  Overnight final simulation pack for the paper.
%
% Default workload is intentionally heavy but still realistic for a single
% overnight run on a workstation:
%   Block A: controlled severe Markov-ISI, 1e7 samples/trial, 100 trials
%   Block B: C2M two-chain tracking stress, 80000 samples/trial, 10 trials
%   Block C: endogenous-aware bridge, 80000 samples/trial, 10 trials
%
% To force a much heavier Block A run, call for example:
%   run_final_overnight_v72('blockA_samples', 1e7)

p = inputParser;
addParameter(p, 'save_dir', 'paper_final_overnight_v72', @ischar);
addParameter(p, 'snr', 15:1:30, @isnumeric);
addParameter(p, 'blockA_trials', 100, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'blockA_samples', 1e7, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'blockA_trainLen', 12000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'blockB_trials', 10, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'blockB_samples', 80000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'blockB_trainLen', 12000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'blockC_trials', 10, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'blockC_samples', 80000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'blockC_trainLen', 8000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'run_extra_tracking_mc', false, @islogical);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));

root_dir = pwd;
final_dir = fullfile(root_dir, opt.save_dir);
if ~exist(final_dir, 'dir'), mkdir(final_dir); end

log_file = fullfile(final_dir, 'run_final_overnight_v72.log');
diary(log_file);
diary on;
cleanupObj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('\n[overnight_v72] Started %s\n', datestr(now));
fprintf('[overnight_v72] Root: %s\n', root_dir);
fprintf('[overnight_v72] Output: %s\n', final_dir);
fprintf('[overnight_v72] SNR = [%s]\n', num2str(opt.snr));
fprintf('[overnight_v72] Block A: N=%g, trials=%d, trainLen=%d\n', ...
    opt.blockA_samples, opt.blockA_trials, opt.blockA_trainLen);
fprintf('[overnight_v72] Block B: N=%g, trials=%d, trainLen=%d\n', ...
    opt.blockB_samples, opt.blockB_trials, opt.blockB_trainLen);
fprintf('[overnight_v72] Block C: N=%g, trials=%d, trainLen=%d\n\n', ...
    opt.blockC_samples, opt.blockC_trials, opt.blockC_trainLen);

out_all = struct();

try
    fprintf('\n[overnight_v72] Block A: controlled severe Markov-ISI.\n');
    out_all.blockA_severe = run_paper('ber_severe', ...
        'trials', opt.blockA_trials, ...
        'snr', opt.snr, ...
        'samples', opt.blockA_samples, ...
        'trainLen', opt.blockA_trainLen, ...
        'plot', true, ...
        'fig_visible', 'off', ...
        'save_dir', fullfile(final_dir, 'BlockA_mb_severe'));
    save(fullfile(final_dir, 'BlockA_mb_severe.mat'), 'out_all', '-v7.3');
    fprintf('[overnight_v72] Block A done.\n');
catch ME
    out_all.blockA_error = ME;
    local_print_error('Block A', ME);
    save(fullfile(final_dir, 'BlockA_error.mat'), 'out_all', '-v7.3');
end

try
    fprintf('\n[overnight_v72] Block B: C2M two-chain tracking stress, all recursions.\n');
    out_all.blockB_tracking_stress_all_recursions = run_blockB_tracking_stress_all_recursions_v72( ...
        'trials', opt.blockB_trials, ...
        'snr', opt.snr, ...
        'samples', opt.blockB_samples, ...
        'trainLen', opt.blockB_trainLen, ...
        'save_dir', fullfile(final_dir, 'BlockB_tracking_stress_all_recursions'), ...
        'fig_visible', 'off');
    save(fullfile(final_dir, 'BlockB_tracking_stress_all_recursions.mat'), 'out_all', '-v7.3');
    fprintf('[overnight_v72] Block B all-recursion tracking stress done.\n');
catch ME
    out_all.blockB_error = ME;
    local_print_error('Block B', ME);
    save(fullfile(final_dir, 'BlockB_error.mat'), 'out_all', '-v7.3');
end

try
    fprintf('\n[overnight_v72] Block C: endogenous-aware recursion bridge.\n');
    out_all.blockC_endogenous_family = run_paper('endogenous_family', ...
        'trials', opt.blockC_trials, ...
        'snr', opt.snr, ...
        'samples', opt.blockC_samples, ...
        'trainLen', opt.blockC_trainLen, ...
        'plot', true, ...
        'fig_visible', 'off', ...
        'save_dir', fullfile(final_dir, 'BlockC_endogenous_family'));
    save(fullfile(final_dir, 'BlockC_endogenous_family.mat'), 'out_all', '-v7.3');
    fprintf('[overnight_v72] Block C done.\n');
catch ME
    out_all.blockC_error = ME;
    local_print_error('Block C', ME);
    save(fullfile(final_dir, 'BlockC_error.mat'), 'out_all', '-v7.3');
end

try
    fprintf('\n[overnight_v72] Extra figures: eye, COM impairments, high-speed and channel-impact visuals.\n');
    old_pwd = pwd;
    cleanupPwd = onCleanup(@() cd(old_pwd)); %#ok<NASGU>
    extra = run_final_extra_figures_v72( ...
        'root_dir', final_dir, ...
        'run_tracking_mc', opt.run_extra_tracking_mc, ...
        'run_blockC', true);
    out_all.extra_figures = extra;
    srcA = fullfile(root_dir, opt.save_dir, 'BlockA_mb_severe', 'hero_ber_ber_severe.png');
    dstA = fullfile(root_dir, opt.save_dir, 'ExtraFigures', 'BlockA_MonteCarlo_BER_Severe.png');
    if exist(srcA, 'file')
        if ~exist(fileparts(dstA), 'dir'), mkdir(fileparts(dstA)); end
        copyfile(srcA, dstA);
    end
    save(fullfile(final_dir, 'ExtraFigures.mat'), 'out_all', '-v7.3');
    fprintf('[overnight_v72] Extra figures done.\n');
catch ME
    out_all.extra_figures_error = ME;
    local_print_error('Extra figures', ME);
    save(fullfile(final_dir, 'ExtraFigures_error.mat'), 'out_all', '-v7.3');
end

save(fullfile(final_dir, 'final_overnight_v72.mat'), 'out_all', '-v7.3');
fprintf('\n[overnight_v72] Finished %s\n', datestr(now));
fprintf('[overnight_v72] Results saved to: %s\n', final_dir);
end

function local_print_error(label, ME)
fprintf(2, '\n[overnight_v72] %s failed: %s\n', label, ME.message);
for k = 1:numel(ME.stack)
    fprintf(2, '  %s:%d\n', ME.stack(k).file, ME.stack(k).line);
end
end
