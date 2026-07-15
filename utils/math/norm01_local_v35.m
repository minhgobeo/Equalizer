% Auto-split from NCKH_v53.m (original line 4528).
% Folder: utils/math

function z = norm01_local_v35(x)
    xmin = min(x);
    xmax = max(x);
    if abs(xmax - xmin) < 1e-12
        z = zeros(size(x));
    else
        z = (x - xmin) ./ (xmax - xmin);
    end
end


% ========================================================================
% PATCH v37
%
% PURPOSE
%   Move to the NEXT stage after v36:
%     - lock best adaptive-mu-only point:
%           alpha_sigma = 0.10
%           alpha_b     = 0.30
%           alpha_d     = 0.50
%     - enable adaptive_tau
%     - keep adaptive_kappa OFF
%     - run a small 6-point sweep for:
%           (b_bias, b_drift)
%
% POLICY
%   (1) theorem baseline remains locked:
%           tau_c   = 0.45
%           gamma_u = 0.01
%   (2) adaptive-mu best point is fixed
%   (3) adaptive_tau is enabled
%   (4) adaptive_kappa remains OFF
%
% GOAL
%   Check whether a mild adaptive_tau can:
%     - preserve the adaptive-mu gain,
%     - reduce DD-bias further,
%     - and not destroy jump/transient improvement.
%
% HOW TO USE
%   A. In build_variants(cfg), replace ONLY the indicated noise-aware fields.
%   B. Replace run_tuning_protocol(...) with the version below.
%   C. Keep apply_best_noiseaware_from_tuning(...) from v35/v36.
% ========================================================================


% ========================================================================
% PATCH v39
%
% PURPOSE
%   Final confirmatory protocol for the paper candidate.
%
% WHAT THIS PATCH DOES
%   (1) Locks the current paper candidate directly in build_variants(cfg):
%         theorem:
%           tau_c   = 0.45
%           gamma_u = 0.01
%
%         noise_aware:
%           alpha_sigma = 0.10
%           alpha_b     = 0.30
%           alpha_d     = 0.50
%           b_bias      = 0.02
%           b_drift     = 0.02
%           use_adaptive_mu    = true
%           use_adaptive_tau   = true
%           use_adaptive_kappa = false
%
%   (2) Adds a confirmatory protocol with:
%         - Nsym = 50000
%         - trainLen = 1800
%         - Ntrial_theorem = 10
%
%   (3) Runs ONLY 3 cases:
%         - theorem
%         - noise_aware
%         - const_same_energy
%
%   (4) Reports ONLY the core metrics:
%         - paramFloor_markov
%         - ddBias_markov
%         - pUpdEff_markov
%         - muScaleMean
%         - muScaleStd
%         - muSatMax
%         - OvershootArea
%         - PostJumpFloor
%
% HOW TO USE
%   A. In build_variants(cfg), replace the indicated v_noise fields.
%   B. In main, add:
%        confirm_rslt = run_confirmatory_protocol(cfg, vars, mc);
%      before print_summary(...).
%   C. Append all helper functions in this patch to the end of your file.
%
% NOTE
%   This patch assumes your file already contains:
%     - proposed_shadow_metrics_muaware_v35(...)
%     - make_constant_gain_version(...)
%     - channel_out(...)
%     - add_awgn_measured(...)
%     - proposed_recursion(...)
% ========================================================================


%% ========================================================================
% A. PATCH FOR build_variants(cfg)
%    Replace ONLY the indicated noise-aware fields inside v_noise block.
%% ========================================================================

% OLD (current):
%   v_noise.alpha_sigma = 0.10;
%   v_noise.alpha_b     = 0.30;
%   v_noise.alpha_d     = 0.75;
%   v_noise.use_adaptive_mu    = true;
%   v_noise.use_adaptive_tau   = true;
%   v_noise.use_adaptive_kappa = false;
%   v_noise.b_bias    = 0.03;
%   v_noise.b_drift   = 0.01;

% NEW (paper candidate):
% ------------------------------------------------------------------------
% v_noise.alpha_sigma = 0.10;
% v_noise.alpha_b     = 0.30;
% v_noise.alpha_d     = 0.50;
%
% v_noise.use_adaptive_mu    = true;
% v_noise.use_adaptive_tau   = true;
% v_noise.use_adaptive_kappa = false;
%
% v_noise.b_bias    = 0.02;
% v_noise.b_drift   = 0.02;
% ------------------------------------------------------------------------



%% ========================================================================
% B. PATCH FOR MAIN
%
% Add this line before print_summary(...):
%
%   confirm_rslt = run_confirmatory_protocol(cfg, vars, mc);
%
% Example:
%
%   ode_rslt       = run_ode_sanity_package(cfg, vars, mc);
%   practical_rslt = run_practical_package(cfg, vars, base, mc);
%   theorem_rslt   = run_theorem_package(cfg, vars, mc);
%   tuning_rslt    = run_tuning_protocol(cfg, vars, mc);
%   vars           = apply_best_noiseaware_from_tuning(vars, tuning_rslt);
%   theorem_tuned  = rerun_refined_noiseaware_figures(cfg, vars, mc);
%   appendix_rslt  = run_appendix_package(cfg, vars, practical_rslt.rep, mc);
%   confirm_rslt   = run_confirmatory_protocol(cfg, vars, mc);
%   print_summary(ode_rslt, practical_rslt, theorem_rslt, appendix_rslt);
%% ========================================================================

