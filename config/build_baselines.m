% Auto-split from NCKH_v53.m (original line 475).
% Folder: config

function base = build_baselines()
    base = struct();

    base.mu_lms = 1e-3;               % tuned via auto-tuning

    base.mu_nlms  = 1e-2;             % tuned
    base.eps_nlms = 1e-3;

    % ---------------------------------------------------------
    % SM-NLMS (set-membership normalized LMS, non-signed)
    % ---------------------------------------------------------
    base.smnlms.beta    = 1e-2;
    base.smnlms.tau     = 5.0;
    base.smnlms.eps_pow = 1e-12;

    base.lambda_rls = 0.999;           % tuned
    base.delta_rls  = 1e-2;

    % ---------------------------------------------------------
    % SM-sign-NLMS (fixed-step) — tuned
    % ---------------------------------------------------------
    base.smsign.beta    = 1e-2;
    base.smsign.tau     = 5.0;
    base.smsign.eps_pow = 1e-12;

    % ---------------------------------------------------------
    % SM-sign-NLMS VSS — tuned
    % ---------------------------------------------------------
    base.smsign_vss.beta0      = 1e-2;
    base.smsign_vss.beta_min   = 1e-3;
    base.smsign_vss.beta_max   = 2.5e-2;
    base.smsign_vss.tau        = 1.5;
    base.smsign_vss.alpha_beta = 0.995;
    base.smsign_vss.eps_pow    = 1e-12;
end

