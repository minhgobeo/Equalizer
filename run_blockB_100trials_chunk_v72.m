function out = run_blockB_100trials_chunk_v72(profile, snr_db, varargin)
%RUN_BLOCKB_100TRIALS_CHUNK_V72 Run one resumable Block-B 100-trial chunk.
%
% Example:
%   run_blockB_100trials_chunk_v72('slow', 15)

p = inputParser;
addRequired(p, 'profile', @(x) ischar(x) || isstring(x));
addRequired(p, 'snr_db', @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'save_dir', 'paper_final_blockB_100trials_v72', @ischar);
addParameter(p, 'trials', 100, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'samples', 80000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'trainLen', 12000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'batch_trials', 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'baud', 26.5625e9, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(p, profile, snr_db, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
fprintf('[blockB100_chunk] profile=%s snr=%g trials=%d samples=%d trainLen=%d save_dir=%s\n', ...
    char(opt.profile), opt.snr_db, opt.trials, opt.samples, opt.trainLen, opt.save_dir);

if opt.trials > opt.batch_trials
    out = local_run_batched_chunk(opt);
else
    out = local_refresh_profile_plot(opt);
end
end

function out = local_run_batched_chunk(opt)
profile = char(opt.profile);
snr_db = opt.snr_db;
final_dir = fullfile(opt.save_dir, sprintf('tmp_%s_snr%02d', profile, snr_db));
final_csv = fullfile(final_dir, 'ieee8023ck_markov_sweep_summary.csv');
if exist(final_csv, 'file') == 2
    fprintf('[blockB100_chunk] resume final CSV: %s\n', final_csv);
    out = local_refresh_profile_plot(opt);
    return;
end

if ~exist(final_dir, 'dir'), mkdir(final_dir); end
nb = ceil(opt.trials / opt.batch_trials);
Tall = table();
batch_weights = [];
batch_root = fullfile(opt.save_dir, sprintf('_batches_%s_snr%02d', profile, snr_db));
if ~exist(batch_root, 'dir'), mkdir(batch_root); end

for bi = 1:nb
    ntrial_i = min(opt.batch_trials, opt.trials - (bi-1)*opt.batch_trials);
    batch_dir = fullfile(batch_root, sprintf('batch%03d', bi));
    batch_csv = fullfile(batch_dir, 'ieee8023ck_markov_sweep_summary.csv');
    if exist(batch_csv, 'file') ~= 2
        fprintf('[blockB100_chunk] batch %d/%d profile=%s snr=%g trials=%d\n', ...
            bi, nb, profile, snr_db, ntrial_i);
        run_paper('8023ck_sparam', ...
            'trials', ntrial_i, ...
            'snr', snr_db, ...
            'max_cases', 6, ...
            'baud', opt.baud, ...
            'run_static', false, ...
            'run_markov', false, ...
            'run_markov_sweep', true, ...
            'p_stay', local_profile_pstay(profile), ...
            'markov_nsym', opt.samples, ...
            'markov_trainLen', opt.trainLen, ...
            'markov_twochain', true, ...
            'markov_twochain_noise_scale', 1.25, ...
            'markov_twochain_imp_prob', 0, ...
            'markov_twochain_imp_alpha', 0, ...
            'markov_nb', 4, ...
            'markov_smnlms_tau', 0.35, ...
            'markov_smnlms_beta', 0.015, ...
            'markov_use_adaptive_tau', true, ...
            'markov_tau_calib', 0.5, ...
            'markov_use_transition_gate', false, ...
            'seed_offset', 1000000*bi + 1000*round(snr_db), ...
            'plot', false, ...
            'fig_visible', 'off', ...
            'save_dir', batch_dir);
    else
        fprintf('[blockB100_chunk] resume batch %d/%d: %s\n', bi, nb, batch_csv);
    end
    Tb = readtable(batch_csv);
    Tb.BatchTrials = repmat(ntrial_i, height(Tb), 1);
    Tall = [Tall; Tb]; %#ok<AGROW>
    batch_weights(end+1) = ntrial_i; %#ok<AGROW>
end

Tout = local_weighted_summary(Tall);
writetable(Tout, final_csv);
copyfile(final_csv, fullfile(final_dir, 'ieee8023ck_sparam_benchmark_summary.csv'));
fprintf('[blockB100_chunk] wrote aggregated 100-trial CSV: %s\n', final_csv);
out = local_refresh_profile_plot(opt);
end

function out = local_refresh_profile_plot(opt)
out = run_blockB_tracking_stress_all_recursions_v72( ...
    'snr', opt.snr_db, ...
    'profiles', {char(opt.profile)}, ...
    'trials', opt.trials, ...
    'samples', opt.samples, ...
    'trainLen', opt.trainLen, ...
    'baud', opt.baud, ...
    'save_dir', opt.save_dir, ...
    'fig_visible', 'off', ...
    'resume', true);
end

function pstay = local_profile_pstay(profile)
switch lower(char(profile))
    case 'slow'
        pstay = 0.985;
    case 'medium'
        pstay = 0.970;
    case 'fast'
        pstay = 0.955;
    otherwise
        error('Unknown Block B profile: %s', char(profile));
end
end

function Tout = local_weighted_summary(Tall)
methods = unique(string(Tall.method), 'stable');
Tout = Tall([], :);
num_vars = Tall.Properties.VariableNames(varfun(@isnumeric, Tall, 'OutputFormat', 'uniform'));
for mi = 1:numel(methods)
    idx = string(Tall.method) == methods(mi);
    Ti = Tall(idx,:);
    row = Ti(1,:);
    w = Ti.BatchTrials;
    w = w / sum(w);
    for vi = 1:numel(num_vars)
        vn = num_vars{vi};
        if strcmp(vn, 'BatchTrials')
            row.(vn) = sum(Ti.BatchTrials);
        else
            x = Ti.(vn);
            row.(vn) = sum(x(:) .* w(:), 'omitnan');
        end
    end
    Tout = [Tout; row]; %#ok<AGROW>
end
if any(strcmp(Tout.Properties.VariableNames, 'best_method')) && any(strcmp(Tout.Properties.VariableNames, 'BER'))
    [~, ib] = min(Tout.BER);
    best = string(Tout.method(ib));
    if iscell(Tout.best_method)
        Tout.best_method(:) = {char(best)};
    else
        Tout.best_method(:) = best;
    end
end
end
