% Auto-split from NCKH_v53.m (original line 1606).
% Folder: experiments/theory_legacy

function t2 = run_theorem2_showcase(cfg, vars, base, mc)
% Generate all 8 figures validating Theorem 2.
% Uses simple 2-tap channel for clean theoretical comparison.
    t2 = struct();
    v = vars.context;

    cfg_t = cfg;
    cfg_t.chan_mode = 'baseline_2tap';
    if isfield(cfg_t,'std8023'), cfg_t.std8023.enable = false; end
    cfg_t.SNRdB = 20;
    Nt = max(mc.Ntrial_theorem, 10);

    fprintf('  [T2] Fig 1: Corrected drift inequality...\n');
    t2.fig1 = t2_fig1_drift_inequality(cfg_t, v, Nt);

    fprintf('  [T2] Fig 2: Three-part floor decomposition...\n');
    t2.fig2 = t2_fig2_floor_decomposition(cfg_t, v, Nt);

    fprintf('  [T2] Fig 3: Finite-time bound (Theorem 2 prime)...\n');
    t2.fig3 = t2_fig3_finite_time_bound(cfg_t, v, Nt);

    fprintf('  [T2] Fig 4: CLR vs constant gain (Theorem 2 double-prime)...\n');
    t2.fig4 = t2_fig4_clr_vs_constant(cfg_t, v, Nt);

    fprintf('  [T2] Fig 5: Endogenous burden proxy sweep...\n');
    t2.fig5 = t2_fig5_burden_proxy(cfg_t, v, Nt);

    fprintf('  [T2] Fig 6: Jump tracking recovery...\n');
    t2.fig6 = t2_fig6_jump_tracking(cfg, v, base, Nt);

    fprintf('  [T2] Fig 7: SER comparison (static + Markov)...\n');
    t2.fig7 = t2_fig7_ser_comparison(cfg, v, base, mc);

    fprintf('  [T2] Fig 8: Numerical comparison table...\n');
    t2.fig8 = t2_fig8_comparison_table(cfg_t, v, base, Nt);
end

% --- Figure T2-1: Corrected Drift Inequality ---
