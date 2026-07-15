%% Quick test: 802.3ck with adaptive tau + transition gate (3 trials)
% This script tests the new adaptive tau + transition gate improvements
% Expected result: +20% improvement vs Chen baseline

clear all; close all;
addpath(genpath('core'));
addpath(genpath('utils'));
addpath(genpath('experiments'));
addpath(genpath('channel'));
addpath(genpath('config'));

fprintf('=== Testing Adaptive Tau + Transition Gate (802.3ck C2M Markov) ===\n');
fprintf('Quick test: 3 trials, SNR=[18 22 26], Pstay=[0.97, 0.93]\n');
fprintf('New features: use_adaptive_tau=true, tau_calib=1.0, use_transition_gate=true\n\n');

try
    % Build configs
    cfg  = build_main_config();
    mc   = build_mc_config(cfg);
    vars = build_variants(cfg);
    base = build_baselines();

    % Run benchmark with new features
    % trials=3: quick test only
    pkg = run_8023ck_sparam_benchmark( ...
        cfg, vars, base, mc, ...
        'trials', 3, ...
        'p_stay', [0.970, 0.930], ...  % slow and medium only
        'save_dir', 'test_adaptive_tau_markov_t3');

    % Parse results
    if isfield(pkg, 'markov') && ~isempty(pkg.markov)
        markov = struct2table(pkg.markov);

        % Show Markov slow case
        slow = markov(ismember(markov.case_id, 'Markov_slow'), :);
        if ~isempty(slow)
            fprintf('\n=== SLOW (Pstay=0.97) ===\n');
            disp(slow(:, {'method', 'BER', 'improvement_vs_chen_pct', 'state_accuracy'}));

            proposed_ber = slow.BER(ismember(slow.method, 'Proposed MSB'));
            chen_ber = slow.BER(ismember(slow.method, 'Chen pulse-ref'));
            if ~isempty(proposed_ber) && ~isempty(chen_ber)
                imp = 100 * (1 - proposed_ber / max(chen_ber, eps));
                fprintf('Improvement: %.1f%% [Target: +20%%]\n', imp);
                if imp >= 20, fprintf('✓ TARGET ACHIEVED!\n'); end
            end
        end

        % Show Markov medium case
        medium = markov(ismember(markov.case_id, 'Markov_medium'), :);
        if ~isempty(medium)
            fprintf('\n=== MEDIUM (Pstay=0.93) ===\n');
            disp(medium(:, {'method', 'BER', 'improvement_vs_chen_pct', 'state_accuracy'}));
        end
    end

    fprintf('\n✓ Test completed. Results in: test_adaptive_tau_markov_t3/\n');

catch ME
    fprintf('\n✗ Error: %s\n', ME.message);
    for k = 1:min(3, numel(ME.stack))
        fprintf('  at %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
end


