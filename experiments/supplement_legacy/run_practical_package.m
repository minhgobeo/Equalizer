% Auto-split from NCKH_v53.m (original line 1042).
% Folder: experiments/supplement_legacy

function practical = run_practical_package(cfg, vars, base, mc)
    practical = struct();

    % ------------------------------------------------------
    % v50: Use baseline_2tap channel for ALL experiments
    % (consistent with paper Section V and theorem2 mode).
    % 802.3 channel is NOT used — see Remark 7 in paper.
    % ------------------------------------------------------
    cfg_p = cfg;
    cfg_p.chan_mode = 'baseline_2tap';
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end

    practical.conv = run_convergence_experiment(cfg_p, vars.context, base, mc);
    practical.eye  = run_eye_experiment(cfg_p, practical.conv.rep);
    practical.ser  = run_ser_experiment(cfg_p, vars.context, base, mc);

    % --- NEW: Markov-channel SER for Theorem 2 validation ---
    fprintf('[practical] Running Markov-channel SER experiment...\n');
    practical.ser_markov = run_ser_experiment_markov(cfg, vars.context, base, mc);

    % diagnostics are appendix-only now, but still compute and store
    practical.diag = run_practical_diagnostics(cfg_p, practical.conv.rep);

    practical.rep  = practical.conv.rep;

    plot_practical_receiver_behavior(practical.conv, practical.ser, cfg_p);

    % --- NEW: Enhanced multi-panel SER comparison ---
    plot_enhanced_ser_comparison(practical.ser, practical.ser_markov, cfg);
end

