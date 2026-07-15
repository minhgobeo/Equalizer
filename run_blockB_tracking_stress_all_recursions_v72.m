function out = run_blockB_tracking_stress_all_recursions_v72(varargin)
%RUN_BLOCKB_TRACKING_STRESS_ALL_RECURSIONS_V72
%   Block B final Monte-Carlo/SNR sweep for the application benchmark.
%   Each switching profile is run as a C2M two-chain tracking stress:
%     run_static=false, run_markov=false, run_markov_sweep=true,
%     markov_twochain=true.
%
%   Output figures:
%     BlockB_TrackingStress_AllRecursions_slow.png
%     BlockB_TrackingStress_AllRecursions_medium.png
%     BlockB_TrackingStress_AllRecursions_fast.png

p = inputParser;
addParameter(p, 'trials', 10, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'snr', 15:1:30, @isnumeric);
addParameter(p, 'save_dir', fullfile('paper_final_all_blocks_v72','BlockB_tracking_stress_all_recursions'), @ischar);
addParameter(p, 'fig_visible', 'off', @ischar);
addParameter(p, 'format', 'png', @ischar);
addParameter(p, 'samples', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'trainLen', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'baud', 26.5625e9, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'profile_trials', [], @(x) isempty(x) || (isnumeric(x) && (isscalar(x) || numel(x)==3)));
addParameter(p, 'profile_nsym', [], @(x) isempty(x) || (isnumeric(x) && (isscalar(x) || numel(x)==3)));
addParameter(p, 'profile_trainLen', [], @(x) isempty(x) || (isnumeric(x) && (isscalar(x) || numel(x)==3)));
addParameter(p, 'profiles', {'slow','medium','fast'}, @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'resume', true, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'markov_nb', 4, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'markov_smnlms_tau', 0.35, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'markov_smnlms_beta', 0.015, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
if ~exist(opt.save_dir, 'dir'), mkdir(opt.save_dir); end

profiles = struct( ...
    'name', {'slow','medium','fast'}, ...
    'pstay', {0.985, 0.970, 0.955});
profile_names = string({profiles.name});
want_profiles = string(opt.profiles);
if ischar(opt.profiles), want_profiles = string({opt.profiles}); end
keep_profiles = ismember(profile_names, want_profiles);
if ~any(keep_profiles)
    error('No valid profiles selected. Use any of: slow, medium, fast.');
end
if ~isempty(opt.samples) && isempty(opt.profile_nsym)
    opt.profile_nsym = repmat(opt.samples, 1, 3);
end
if ~isempty(opt.trainLen) && isempty(opt.profile_trainLen)
    opt.profile_trainLen = repmat(opt.trainLen, 1, 3);
end
if isempty(opt.profile_trials)
    opt.profile_trials = repmat(opt.trials, 1, 3);
elseif isscalar(opt.profile_trials)
    opt.profile_trials = repmat(opt.profile_trials, 1, 3);
end
if isempty(opt.profile_nsym)
    opt.profile_nsym = [80000 40000 10000];  % slow, medium, fast
elseif isscalar(opt.profile_nsym)
    opt.profile_nsym = repmat(opt.profile_nsym, 1, 3);
end
if isempty(opt.profile_trainLen)
    opt.profile_trainLen = min(round(0.20 * opt.profile_nsym), [12000 8000 2000]);
elseif isscalar(opt.profile_trainLen)
    opt.profile_trainLen = repmat(opt.profile_trainLen, 1, 3);
end

rows = table();
raw = cell(numel(profiles), numel(opt.snr));
fprintf('[blockB_allrec] C2M two-chain tracking-stress, SNR=[%s]\n', num2str(opt.snr));
fprintf('[blockB_allrec] Profile config: slow N=%d/T=%d, medium N=%d/T=%d, fast N=%d/T=%d\n', ...
    opt.profile_nsym(1), opt.profile_trials(1), opt.profile_nsym(2), opt.profile_trials(2), ...
    opt.profile_nsym(3), opt.profile_trials(3));

for pi = 1:numel(profiles)
    if ~keep_profiles(pi)
        continue;
    end
    for si = 1:numel(opt.snr)
        save_i = fullfile(opt.save_dir, sprintf('tmp_%s_snr%02d', profiles(pi).name, opt.snr(si)));
        csv_i = fullfile(save_i, 'ieee8023ck_markov_sweep_summary.csv');
        if opt.resume && exist(csv_i, 'file')
            fprintf('[blockB_allrec] resume: reading %s\n', csv_i);
            T_i = readtable(csv_i);
            rows = [rows; local_rows_from_summary(T_i, profiles(pi), opt, si, pi)]; %#ok<AGROW>
            raw{pi,si} = struct('resumed_from', csv_i);
        else
            out_i = run_paper('8023ck_sparam', ...
                'trials', opt.profile_trials(pi), ...
                'snr', opt.snr(si), ...
                'max_cases', 6, ...
                'baud', opt.baud, ...
                'run_static', false, ...
                'run_markov', false, ...
                'run_markov_sweep', true, ...
                'p_stay', profiles(pi).pstay, ...
                'markov_nsym', opt.profile_nsym(pi), ...
                'markov_trainLen', opt.profile_trainLen(pi), ...
                'markov_twochain', true, ...
                'markov_twochain_noise_scale', 1.25, ...
                'markov_twochain_imp_prob', 0, ...
                'markov_twochain_imp_alpha', 0, ...
                'markov_nb', opt.markov_nb, ...
                'markov_smnlms_tau', opt.markov_smnlms_tau, ...
                'markov_smnlms_beta', opt.markov_smnlms_beta, ...
                'markov_use_adaptive_tau', true, ...
                'markov_tau_calib', 0.5, ...
                'markov_use_transition_gate', false, ...
                'plot', false, ...
                'fig_visible', opt.fig_visible, ...
                'save_dir', save_i);
            raw{pi,si} = out_i;
            rows = [rows; local_rows_from_markov_sweep(out_i.markov_sweep, profiles(pi), opt, si, pi)]; %#ok<AGROW>
        end
    end
end

csv_path = fullfile(opt.save_dir, 'BlockB_TrackingStress_AllRecursions_LongTable.csv');
writetable(rows, csv_path);
paper_rows = local_filter_paper_methods(rows);
paper_csv_path = fullfile(opt.save_dir, 'BlockB_TrackingStress_PaperMethods_LongTable.csv');
writetable(paper_rows, paper_csv_path);
fprintf('[blockB_allrec] Wrote %s\n', csv_path);

figs = cell(numel(profiles),1);
for pi = 1:numel(profiles)
    if ~any(strcmp(rows.Profile, profiles(pi).name))
        continue;
    end
    figs{pi} = local_plot_profile(rows, profiles(pi).name, opt);
end

out = struct('table', rows, 'raw', {raw}, 'figures', {figs}, ...
    'save_dir', opt.save_dir, 'csv', csv_path, 'paper_csv', paper_csv_path);
save(fullfile(opt.save_dir, 'BlockB_TrackingStress_AllRecursions.mat'), 'out', '-v7.3');
end

function rows = local_rows_from_markov_sweep(sw, profile, opt, si, pi)
if isempty(sw), error('No markov_sweep returned for %s SNR=%g.', profile.name, opt.snr(si)); end
methods = sw(1).methods;
rows = table();
for mi = 1:numel(methods)
    rows = [rows; table( ...
        string(profile.name), profile.pstay, sw(1).mean_dwell_symbols, ...
        opt.profile_nsym(pi), opt.profile_trials(pi), opt.profile_trainLen(pi), ...
        opt.snr(si), string(methods{mi}), sw(1).BER(mi), sw(1).SER(mi), ...
        sw(1).state_accuracy, sw(1).wrong_routing_rate, ...
        sw(1).transition_window_BER_proposed, sw(1).transition_window_BER_chen, ...
        sw(1).transition_window_BER_alg1, sw(1).recovery_time_proposed, ...
        sw(1).recovery_time_chen, sw(1).recovery_time_alg1, ...
        'VariableNames', {'Profile','Pstay','MeanDwellSymbols', ...
        'SamplesPerTrial','Trials','TrainLen','SNRdB','Method', ...
        'BER','SER','StateAccuracy','WrongRoutingRate', ...
        'TransitionBER_Proposed','TransitionBER_Chen','TransitionBER_Alg1', ...
        'Recovery_Proposed','Recovery_Chen','Recovery_Alg1'})]; %#ok<AGROW>
end
end

function rows = local_rows_from_summary(T_i, profile, opt, si, pi)
rows = table();
for mi = 1:height(T_i)
    rows = [rows; table( ...
        string(profile.name), profile.pstay, T_i.mean_dwell_symbols(mi), ...
        opt.profile_nsym(pi), opt.profile_trials(pi), opt.profile_trainLen(pi), ...
        opt.snr(si), string(T_i.method{mi}), T_i.BER(mi), T_i.SER(mi), ...
        T_i.state_accuracy(mi), T_i.wrong_routing_rate(mi), ...
        T_i.transition_window_BER_proposed(mi), T_i.transition_window_BER_chen(mi), ...
        T_i.transition_window_BER_alg1(mi), T_i.recovery_time_proposed(mi), ...
        T_i.recovery_time_chen(mi), T_i.recovery_time_alg1(mi), ...
        'VariableNames', {'Profile','Pstay','MeanDwellSymbols', ...
        'SamplesPerTrial','Trials','TrainLen','SNRdB','Method', ...
        'BER','SER','StateAccuracy','WrongRoutingRate', ...
        'TransitionBER_Proposed','TransitionBER_Chen','TransitionBER_Alg1', ...
        'Recovery_Proposed','Recovery_Chen','Recovery_Alg1'})]; %#ok<AGROW>
end
end

function T = local_filter_paper_methods(T)
drop = ismember(string(T.Method), ["NLMS-DFE", "SM-sign-NLMS VSS", "SM-sign-NLMS-VSS"]);
T = T(~drop,:);
end

function fname = local_plot_profile(rows, profile, opt)
idxp = strcmp(rows.Profile, profile);
T = local_filter_paper_methods(rows(idxp,:));
methods = unique(T.Method, 'stable');

% Minimum reliable error count: BER estimates with fewer errors are
% non-monotonic due to Poisson counting noise and create wiggly curves.
N_MIN_ERRORS = 20;
n_trials  = max(T.Trials);
n_eval    = max(T.SamplesPerTrial) - max(T.TrainLen);  % eval symbols per trial
n_bits    = n_trials * n_eval * 2;                      % PAM4: 2 bits/symbol
ber_floor = N_MIN_ERRORS / n_bits;                      % minimum trustworthy BER

% y-axis lower limit: one decade below the reliability floor (but >=1e-6).
ylim_low = max(1e-6, ber_floor / 5);

fig = figure('Color','w', 'Visible', opt.fig_visible, 'Position',[80 80 980 720]);
hold on; grid on; box on;
cols = lines(numel(methods));
marks = {'o','s','^','d','v','>','<','p','h','x'};
for mi = 1:numel(methods)
    idx = strcmp(T.Method, methods(mi));
    [x, ord] = sort(T.SNRdB(idx));
    y = T.BER(idx);
    y = y(ord);
    % Replace unreliable estimates (< N_MIN_ERRORS total errors) with NaN
    % so the curve terminates cleanly instead of showing quantization noise.
    y_plot = y;
    y_plot(y_plot < ber_floor) = NaN;
    lw = 1.35; ms = 5.5;
    if strcmp(methods(mi), 'Proposed MSB')
        lw = 2.8; ms = 8.5;
    elseif strcmp(methods(mi), 'Algorithm 1') || strcmp(methods(mi), 'Chen pulse-ref')
        lw = 1.9; ms = 6.5;
    end
    semilogy(x, y_plot, ['-' marks{min(mi,numel(marks))}], ...
        'Color', cols(mi,:), 'LineWidth', lw, 'MarkerSize', ms, ...
        'MarkerFaceColor', cols(mi,:));
end
yline(2.4e-4, 'k--', 'KP4 FEC 2.4e-4', 'LabelHorizontalAlignment','left');
xlabel('SNR (dB)');
ylabel('pre-FEC BER');
title(sprintf('Block B %s C2M two-chain tracking stress: all recursions', profile), ...
    'Interpreter','none');
legend(methods, 'Location','southwest', 'Interpreter','none');
set(gca, 'YScale','log');
ylim([ylim_low 1]);
fname = fullfile(opt.save_dir, sprintf('BlockB_TrackingStress_AllRecursions_%s.%s', profile, opt.format));
local_save(fig, fname);
fprintf('[blockB_allrec] saved %s\n', fname);
end

function local_save(fig, fname)
set(fig, 'PaperPositionMode', 'auto');
try
    exportgraphics(fig, fname, 'Resolution', 300);
catch
    saveas(fig, fname);
end
close(fig);
end
