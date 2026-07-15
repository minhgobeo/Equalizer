% Auto-split from NCKH_v53.m (original line 2456).
% Folder: experiments/theory_legacy

function theorem = run_theorem_package(cfg, vars, mc)
    theorem = struct();

    theorem.bias  = run_dd_bias_validation(cfg, vars.theorem, mc);
    theorem.drift = run_drift_validation(cfg, vars.theorem, mc);
    theorem.mu2   = run_mu2_validation(cfg, vars.theorem, mc);
    theorem.cycle = run_cycle_operator_validation(cfg, vars.theorem, mc);
    theorem.cycle_id = run_cycle_operator_identification(cfg, vars.theorem, mc);
    theorem.ablt_nominal = run_structural_ablation_package(cfg, vars.theorem, mc);
    theorem.noise_proxy = run_noise_aware_proxy_response(cfg, vars);
    
    cfg_drift = cfg;
    cfg_drift.chan_mode = 'drift_2tap';
    cfg_drift.drift_span = 0.08;
    cfg_drift.drift_shape = 'linear';
    theorem.ablt_drift = run_structural_ablation_package(cfg_drift, vars.theorem, mc);

    cfg_markov = cfg;
    cfg_markov.chan_mode = cfg.severe.chan_mode;
    cfg_markov.SNRdB     = cfg.severe.SNRdB;
    cfg_markov.trainLen  = cfg.severe.trainLen;
    cfg_markov.Nsym      = cfg.severe.Nsym;
    cfg_markov.h_isi     = cfg.severe.h_isi;
    cfg_markov.markov.P  = cfg.severe.markovP;

    % Main theorem-side fair comparison
    theorem.noise_aware_markov = run_noise_aware_comparison(cfg_markov, vars, mc);

    % External baseline comparison kept separate
    theorem.external_markov = run_external_baseline_ser_comparison(cfg_markov, vars, mc);

    % Main restoration comparison should also be internal-fair
    theorem.restoration = run_restoration_validation(cfg_markov, vars, mc);
end

