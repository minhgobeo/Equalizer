% Auto-split from NCKH_v53.m (original line 6216).
% Folder: experiments/theory_legacy

function out = run_complete_paper_supplement(cfg, vars, base, mc)
% =========================================================================
% COMPLETE PAPER SUPPLEMENT — NCKH_v40 PATCH
%
% PURPOSE:
%   1. Fix Gap 1: Re-enable ODE sanity (Theorem 1 backbone)
%   2. Fix Gap 2: Add PTF residual scaling T1-S4
%   3. Fix Gap 3: Add irreducibility experiment (main novelty)
%   4. Fix Gap 4: Ntrial bumped to 25 inside this supplement
%   5. Fix Gap 5: Add triangular gain-energy formula verification
%   6. Fix Gap 7: Add finite-time decay validation (Theorem 2')
%   7. ADD: SM-sign-NLMS comparison figures (vs bai 2024)
%   8. ADD: Full 6-figure-group paper package
%
% HOW TO CALL (from main demo_v44_...):
%   supp = run_complete_paper_supplement(cfg, vars, base, mc);
%
% =========================================================================

    mc_supp      = mc;
    mc_supp.Ntrial_theorem = 25;   % Gap 4 fix: was 10

    out = struct();

    fprintf('\n===== SUPPLEMENT: GROUP 1 — Theorem 1 Legitimacy =====\n');
    out.g1_ode     = supp_ode_sanity(cfg, vars, mc_supp);          % Gap 1
    out.g1_t1val   = supp_ptf_residual_scaling(cfg, vars, mc_supp);% Gap 2

    fprintf('\n===== SUPPLEMENT: GROUP 2 — Theorem 2 Burden Sweeps =====\n');
    out.g2_irred   = supp_irreducibility(cfg, vars, mc_supp);       % Gap 3
    out.g2_mu2form = supp_mu2_formula_verify(cfg, vars);            % Gap 5

    fprintf('\n===== SUPPLEMENT: GROUP 3 — CLR / Cycle Mechanism =====\n');
    out.g3_cycle   = supp_cycle_contraction_fig(cfg, vars, mc_supp);

    fprintf('\n===== SUPPLEMENT: GROUP 4 — SM-sign-NLMS Comparison =====\n');
    out.g4_cmp2024 = supp_vs_2024_smsign(cfg, vars, base, mc_supp);

    fprintf('\n===== SUPPLEMENT: GROUP 5 — Finite-Time Theorem 2 prime =====\n');
    out.g5_ft      = supp_finite_time_validation(cfg, vars, mc_supp);% Gap 7

    fprintf('\n===== SUPPLEMENT: GROUP 5B — Algorithm 2 Abrupt Jump Response =====\n');
    out.g5b_jump   = supp_abrupt_jump_algo2_visual(cfg, vars, mc_supp);

    fprintf('\n===== SUPPLEMENT: GROUP 6 — Paper Summary Figures =====\n');
    out.g6_eye     = supp_eye_and_floor_table(cfg, vars, base, mc_supp);

    fprintf('\n===== SUPPLEMENT: GROUP 7 — IEEE 802.3 Channel Compliance =====\n');
    out.g7_8023    = supp_ieee8023_channel_demo(cfg, vars, mc_supp);

    supp_print_all_tables(out);
end

% =========================================================================
%  SUPPLEMENT (FAST) — Skip Group 1 (ODE + PTF) for rapid iteration
% =========================================================================
