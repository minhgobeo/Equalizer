%% Wrapper script: run benchmark in no-display mode and save results
% Usage: matlab -r "run_test_wrapper; quit;" -nodisplay

clear all; close all;
try
    % Add paths
    addpath(genpath('core'));
    addpath(genpath('utils'));
    addpath(genpath('experiments'));
    addpath(genpath('channel'));
    addpath(genpath('config'));

    fprintf('\n[TEST] Adaptive Tau + Transition Gate (3 trials, quick test)\n');
    fprintf('[TEST] Running 802.3ck C2M Markov benchmark...\n\n');

    % Build configs
    cfg  = build_main_config();
    mc   = build_mc_config(cfg);
    vars = build_variants(cfg);
    base = build_baselines();

    % Run with limited trials
    pkg = run_8023ck_sparam_benchmark( ...
        cfg, vars, base, mc, ...
        'trials', 3, ...
        'p_stay', [0.970, 0.930], ...
        'save_dir', 'test_adaptive_tau_markov_t3');

    % Display key results
    if isfield(pkg, 'markov') && ~isempty(pkg.markov)
        fprintf('\n========== RESULTS ==========\n\n');

        markov = pkg.markov;

        % Slow case (Pstay=0.97)
        slow_prop = [];
        slow_chen = [];
        for k = 1:numel(markov)
            if contains(markov(k).case_id, 'slow')
                if contains(markov(k).case_id, 'Proposed')
                    slow_prop = markov(k);
                elseif contains(markov(k).case_id, 'Chen')
                    slow_chen = markov(k);
                end
            end
        end

        if ~isempty(slow_prop) && ~isempty(slow_chen)
            fprintf('SLOW (Pstay=0.97):\n');
            fprintf('  Proposed BER: %.6e (state acc: %.1f%%)\n', ...
                slow_prop.BER, slow_prop.state_accuracy*100);
            fprintf('  Chen BER:     %.6e\n', slow_chen.BER);
            imp = 100 * (1 - slow_prop.BER / max(slow_chen.BER, eps));
            fprintf('  Improvement:  %.1f%% [Target: +20%%]\n\n', imp);
        end

        % Medium case (Pstay=0.93)
        medium_prop = [];
        medium_chen = [];
        for k = 1:numel(markov)
            if contains(markov(k).case_id, 'medium')
                if contains(markov(k).case_id, 'Proposed')
                    medium_prop = markov(k);
                elseif contains(markov(k).case_id, 'Chen')
                    medium_chen = markov(k);
                end
            end
        end

        if ~isempty(medium_prop) && ~isempty(medium_chen)
            fprintf('MEDIUM (Pstay=0.93):\n');
            fprintf('  Proposed BER: %.6e (state acc: %.1f%%)\n', ...
                medium_prop.BER, medium_prop.state_accuracy*100);
            fprintf('  Chen BER:     %.6e\n', medium_chen.BER);
            imp = 100 * (1 - medium_prop.BER / max(medium_chen.BER, eps));
            fprintf('  Improvement:  %.1f%%\n\n', imp);
        end
    end

    fprintf('========== DONE ==========\n');
    fprintf('Results saved to: test_adaptive_tau_markov_t3/\n\n');

catch ME
    fprintf('ERROR: %s\n', ME.message);
    for k = 1:min(5, numel(ME.stack))
        fprintf('  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
end
