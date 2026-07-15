function run_blockC_onebatch_v72(snr_db, batch_idx, varargin)
%RUN_BLOCKC_ONEBATCH_V72 Run one checkpointed Block-C Monte-Carlo batch.

p = inputParser;
addRequired(p, 'snr_db', @(x) isnumeric(x) && isscalar(x));
addRequired(p, 'batch_idx', @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'save_dir', 'paper_final_BlockC_100trials_v72_batched', @ischar);
addParameter(p, 'batch_trials', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'samples', 80000, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'trainLen', 8000, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'fig_visible', 'off', @ischar);
parse(p, snr_db, batch_idx, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
batch_dir = fullfile(opt.save_dir, sprintf('_batches_snr%02d', opt.snr_db), ...
    sprintf('batch%03d', opt.batch_idx));
csv_file = fullfile(batch_dir, 'Table_Endogenous_Aware_Family.csv');
mat_file = fullfile(batch_dir, sprintf('blockC_snr%02d_batch%03d.mat', opt.snr_db, opt.batch_idx));
if exist(csv_file, 'file') == 2 && exist(mat_file, 'file') == 2
    fprintf('[blockC_onebatch] resume %s\n', batch_dir);
    return;
end
if ~exist(batch_dir, 'dir'), mkdir(batch_dir); end

fprintf('[blockC_onebatch] SNR=%g batch=%d trials=%d samples=%d\n', ...
    opt.snr_db, opt.batch_idx, opt.batch_trials, opt.samples);
out_batch = run_paper('endogenous_family', ...
    'trials', opt.batch_trials, ...
    'snr', opt.snr_db, ...
    'samples', opt.samples, ...
    'trainLen', opt.trainLen, ...
    'save_dir', batch_dir, ...
    'fig_visible', opt.fig_visible, ...
    'seed_offset', 1000000*opt.batch_idx + 1000*round(opt.snr_db));
save(mat_file, 'out_batch', 'opt', '-v7.3');
end
