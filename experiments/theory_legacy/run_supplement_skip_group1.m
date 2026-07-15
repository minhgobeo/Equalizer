% Auto-split from NCKH_v53.m (original line 6272).
% Folder: experiments/theory_legacy

function out = run_supplement_skip_group1(cfg, vars, base, mc)
% Same as run_complete_paper_supplement but skips the slow Group 1.
% Use when you only need Groups 2–7 figures.

    mc_supp      = mc;
    mc_supp.Ntrial_theorem = 25;

    out = struct();

    fprintf('\n[supplement_fast] SKIPPING GROUP 1 (ODE + PTF) — use ''supplement'' for full run\n');

    fprintf('\n===== SUPPLEMENT: GROUP 2 — Theorem 2 Burden Sweeps =====\n');
    out.g2_irred   = supp_irreducibility(cfg, vars, mc_supp);
    out.g2_mu2form = supp_mu2_formula_verify(cfg, vars);

    fprintf('\n===== SUPPLEMENT: GROUP 3 — CLR / Cycle Mechanism =====\n');
    out.g3_cycle   = supp_cycle_contraction_fig(cfg, vars, mc_supp);

    fprintf('\n===== SUPPLEMENT: GROUP 4 — SM-sign-NLMS Comparison =====\n');
    out.g4_cmp2024 = supp_vs_2024_smsign(cfg, vars, base, mc_supp);

    fprintf('\n===== SUPPLEMENT: GROUP 5 — Finite-Time Theorem 2 prime =====\n');
    out.g5_ft      = supp_finite_time_validation(cfg, vars, mc_supp);

    fprintf('\n===== SUPPLEMENT: GROUP 5B — Algorithm 2 Abrupt Jump Response =====\n');
    out.g5b_jump   = supp_abrupt_jump_algo2_visual(cfg, vars, mc_supp);

    fprintf('\n===== SUPPLEMENT: GROUP 6 — Paper Summary Figures =====\n');
    out.g6_eye     = supp_eye_and_floor_table(cfg, vars, base, mc_supp);

    fprintf('\n===== SUPPLEMENT: GROUP 7 — IEEE 802.3 Channel Compliance =====\n');
    out.g7_8023    = supp_ieee8023_channel_demo(cfg, vars, mc_supp);

    supp_print_all_tables(out);
end

% =========================================================================
%  GROUP 1-A  —  ODE SANITY  (Gap 1: uncomment fix)
% =========================================================================
