function out_all = run_final_all_blocks_v72()
%RUN_FINAL_ALL_BLOCKS_V72 Final paper simulation pack for v72.
%   Runs the three agreed blocks and saves tables/figures/logs under
%   paper_final_all_blocks_v72.

root_dir = pwd;
final_dir = fullfile(root_dir, 'paper_final_all_blocks_v72');
if ~exist(final_dir, 'dir')
    mkdir(final_dir);
end

log_file = fullfile(final_dir, 'run_final_all_blocks_v72.log');
diary(log_file);
diary on;

cleanupObj = onCleanup(@() diary('off'));

fprintf('\n[final_v72] Started %s\n', datestr(now));
fprintf('[final_v72] Root: %s\n', root_dir);
fprintf('[final_v72] Output: %s\n\n', final_dir);

out_all = struct();

try
    fprintf('\n[final_v72] Block A: controlled severe Markov-ISI validation.\n');
    out_all.blockA_severe = run_paper('ber_severe', ...
        'trials', 20, ...
        'snr', 15:1:30, ...
        'plot', true, ...
        'fig_visible', 'off', ...
        'save_dir', fullfile(final_dir, 'BlockA_mb_severe'));
    save(fullfile(final_dir, 'BlockA_mb_severe.mat'), 'out_all', '-v7.3');
    fprintf('[final_v72] Block A done.\n');
catch ME
    out_all.blockA_error = ME;
    fprintf(2, '\n[final_v72] Block A failed: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(2, '  %s:%d\n', ME.stack(k).file, ME.stack(k).line);
    end
    save(fullfile(final_dir, 'BlockA_error.mat'), 'out_all', '-v7.3');
end

try
    fprintf('\n[final_v72] Block B: C2M S-parameter tracking stress benchmark.\n');
    out_all.blockB_c2m_tracking = run_paper('8023ck_sparam', ...
        'trials', 10, ...
        'snr', 15:1:30, ...
        'max_cases', 6, ...
        'run_static', false, ...
        'run_markov', true, ...
        'run_markov_sweep', false, ...
        'markov_modes', {'slow','medium','fast'}, ...
        'markov_twochain', false, ...
        'markov_use_adaptive_tau', false, ...
        'markov_use_transition_gate', false, ...
        'plot', true, ...
        'fig_visible', 'off', ...
        'save_dir', fullfile(final_dir, 'BlockB_c2m_tracking'));
    save(fullfile(final_dir, 'BlockB_c2m_tracking.mat'), 'out_all', '-v7.3');
    fprintf('[final_v72] Block B done.\n');
catch ME
    out_all.blockB_error = ME;
    fprintf(2, '\n[final_v72] Block B failed: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(2, '  %s:%d\n', ME.stack(k).file, ME.stack(k).line);
    end
    save(fullfile(final_dir, 'BlockB_error.mat'), 'out_all', '-v7.3');
end

try
    fprintf('\n[final_v72] Block B tuned: C2M two-chain tracking stress benchmark.\n');
    out_all.blockB_c2m_twochain_tracking_tuned = run_paper('8023ck_sparam', ...
        'trials', 10, ...
        'snr', 15:1:30, ...
        'max_cases', 6, ...
        'run_static', false, ...
        'run_markov', true, ...
        'run_markov_sweep', false, ...
        'markov_modes', {'slow','medium','fast'}, ...
        'markov_twochain', true, ...
        'markov_twochain_noise_scale', 1.25, ...
        'markov_twochain_imp_prob', 0, ...
        'markov_twochain_imp_alpha', 0, ...
        'markov_use_adaptive_tau', true, ...
        'markov_tau_calib', 0.5, ...
        'markov_use_transition_gate', false, ...
        'plot', true, ...
        'fig_visible', 'off', ...
        'save_dir', fullfile(final_dir, 'BlockB_c2m_twochain_tracking_tuned'));
    save(fullfile(final_dir, 'BlockB_c2m_twochain_tracking_tuned.mat'), 'out_all', '-v7.3');
    fprintf('[final_v72] Block B tuned done.\n');
catch ME
    out_all.blockB_tuned_error = ME;
    fprintf(2, '\n[final_v72] Block B tuned failed: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(2, '  %s:%d\n', ME.stack(k).file, ME.stack(k).line);
    end
    save(fullfile(final_dir, 'BlockB_tuned_error.mat'), 'out_all', '-v7.3');
end

try
    fprintf('\n[final_v72] Block B all recursions: C2M two-chain tracking-stress SNR sweep.\n');
    out_all.blockB_tracking_stress_all_recursions = run_blockB_tracking_stress_all_recursions_v72( ...
        'trials', 10, ...
        'snr', 22:1:30, ...
        'save_dir', fullfile(final_dir, 'BlockB_tracking_stress_all_recursions'), ...
        'fig_visible', 'off');
    save(fullfile(final_dir, 'BlockB_tracking_stress_all_recursions.mat'), 'out_all', '-v7.3');
    fprintf('[final_v72] Block B all-recursion SNR sweep done.\n');
catch ME
    out_all.blockB_allrec_error = ME;
    fprintf(2, '\n[final_v72] Block B all-recursion SNR sweep failed: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(2, '  %s:%d\n', ME.stack(k).file, ME.stack(k).line);
    end
    save(fullfile(final_dir, 'BlockB_allrec_error.mat'), 'out_all', '-v7.3');
end

try
    fprintf('\n[final_v72] Block C: endogenous-aware recursion bridge.\n');
    out_all.blockC_endogenous_family = run_paper('endogenous_family', ...
        'trials', 10, ...
        'snr', 15:1:29, ...
        'plot', true, ...
        'fig_visible', 'off', ...
        'save_dir', fullfile(final_dir, 'BlockC_endogenous_family'));
    save(fullfile(final_dir, 'BlockC_endogenous_family.mat'), 'out_all', '-v7.3');
    fprintf('[final_v72] Block C done.\n');
catch ME
    out_all.blockC_error = ME;
    fprintf(2, '\n[final_v72] Block C failed: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(2, '  %s:%d\n', ME.stack(k).file, ME.stack(k).line);
    end
    save(fullfile(final_dir, 'BlockC_error.mat'), 'out_all', '-v7.3');
end

try
    fprintf('\n[final_v72] Extra figures: Monte-Carlo, eye diagrams, and channel-impact visuals.\n');
    out_all.extra_figures = run_final_extra_figures_v72();
    % Keep common Monte-Carlo figures beside the extra visuals.
    srcA = fullfile(final_dir, 'BlockA_mb_severe', 'hero_ber_ber_severe.png');
    dstA = fullfile(final_dir, 'ExtraFigures', 'BlockA_MonteCarlo_BER_Severe.png');
    if exist(srcA, 'file'), copyfile(srcA, dstA); end
    srcB = fullfile(final_dir, 'BlockB_c2m_twochain_tracking_tuned', 'Fig_BlockB_BER_SER.png');
    dstB = fullfile(final_dir, 'ExtraFigures', 'BlockB_MonteCarlo_Tracking_BER_SER.png');
    if exist(srcB, 'file'), copyfile(srcB, dstB); end
    save(fullfile(final_dir, 'ExtraFigures.mat'), 'out_all', '-v7.3');
    fprintf('[final_v72] Extra figures done.\n');
catch ME
    out_all.extra_figures_error = ME;
    fprintf(2, '\n[final_v72] Extra figures failed: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(2, '  %s:%d\n', ME.stack(k).file, ME.stack(k).line);
    end
    save(fullfile(final_dir, 'ExtraFigures_error.mat'), 'out_all', '-v7.3');
end

save(fullfile(final_dir, 'final_all_blocks_v72.mat'), 'out_all', '-v7.3');

fprintf('\n[final_v72] Finished %s\n', datestr(now));
fprintf('[final_v72] Results saved to: %s\n', final_dir);
end
