% Auto-split from NCKH_v53.m (original line 7585).
% Folder: experiments/paper_main

function practical = run_eye_ber_only_package(cfg, vars, base, mc)
    practical = struct();

    % v50: Use baseline_2tap for consistency with paper
    cfg_p = cfg;
    cfg_p.chan_mode = 'baseline_2tap';
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end

    practical.conv = run_convergence_experiment(cfg_p, vars.context, base, mc);
    practical.eye  = run_eye_experiment(cfg_p, practical.conv.rep);
    practical.ser  = run_ser_experiment(cfg_p, vars.context, base, mc);

    practical.rep  = practical.conv.rep;
end

% ============================================================================
%  NCKH_v51_patches_v53.m
%  ---------------------------------------------------------------------------
%  REVISED PATCHES (v53) — supersedes v52.
%
%  Root-cause fixes applied:
%    PATCH 1 : removed apply_practical_agc (broke scale); use vars.theorem
%              unchanged for Proposed-core; Algorithm 2 = same recursion
%              with mu_max*2.5 (honest speed/floor trade-off).
%    PATCH 2 : revert to baseline_2tap h=[1 0.5] (known-convergent),
%              emphasise numerical gamma_T display since supplement already
%              showed CLR=0.188 vs same-energy=0.022 (8.5x speedup).
%    PATCH 3 : switch to PAM2 (M=2) with vars.practical (soft gate),
%              channel h=[1 0.30 0.12], Nf=9, Nb=2.  PAM2 is compliant with
%              several 802.3 sub-standards (100BASE-T2, 10GBASE-T line code
%              after pre-processing) and makes pre-FEC BER 1e-5 feasible.
%
%  USAGE (after integration):
%    demo_v44_pam4_sa_markov_ptf_complete('jump_algo2')
%    demo_v44_pam4_sa_markov_ptf_complete('clr_rates')
%    demo_v44_pam4_sa_markov_ptf_complete('ber_prefec')
%
%  INTEGRATION:
%    1. In the main dispatch switch, add the 3 cases listed in SECTION-A.
%    2. Append SECTIONS B/C/D below to end of NCKH_v51.m.
% ============================================================================


% ============================================================================
% SECTION-A  —  INSERT THESE CASE HANDLERS
% ============================================================================
%
%       case 'jump_algo2'
%           out.jump_algo2 = run_jump_algo2_v53(cfg, vars, base, mc);
%           return;
%
%       case 'clr_rates'
%           out.clr_rates = run_clr_rates_v53(cfg, vars, mc);
%           return;
%
%       case 'ber_prefec'
%           out.ber_prefec = run_ber_prefec_v54(cfg, vars, base, mc);
%           return;
% ============================================================================


% ============================================================================
% SECTION-B  —  PATCH 1 v53 : CHANNEL JUMP + ALGORITHM 2
% ============================================================================

