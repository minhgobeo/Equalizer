% Auto-split from NCKH_v53.m (original line 2236).
% Folder: utils/metrics

function rslt = t2_fig7_ser_comparison(cfg, v, base, mc)
    cfg_s = cfg;
    cfg_s.chan_mode = 'baseline_2tap';
    if isfield(cfg_s,'std8023'), cfg_s.std8023.enable = false; end

    rslt.ser_static = run_ser_experiment_simple(cfg, v, base, mc, 'baseline_2tap');
    rslt.ser_markov = run_ser_experiment_simple(cfg, v, base, mc, 'markov_2tap');
    plot_enhanced_ser_comparison(rslt.ser_static, rslt.ser_markov, cfg);
end

% --- Figure T2-8: Numerical Comparison Table ---
