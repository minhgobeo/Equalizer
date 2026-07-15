function p = default_msb_params_v72()
%DEFAULT_MSB_PARAMS_V72  Default msb_params for algorithm6_msb_v72_adaptive_tau.
%
% Returns the same parameter set as default_msb_params_v69() PLUS the
% adaptive-τ fields. With use_adaptive_tau=false (default), this is
% bit-identical to default_msb_params_v69() — so it is a safe drop-in
% replacement anywhere v69 is currently used.
%
% Recommended hyper-parameter sweep for v72 evaluation:
%   tau_calib ∈ {1.0, 2.0, 4.0}      (calibration constant c_τ)
%   sigma_nu2_ema_alpha ∈ {0.99, 0.999}   (slow vs fast σ_ν² tracking)
%
% Folder: core/algorithm6_msb

    % -------- legacy v69 fields (DO NOT CHANGE) --------
    p.B = 128;
    p.K = 8;
    p.T_min = 4;
    p.delta = 0.00;
    p.rho   = 0.80;
    p.train_all_prefix = 0;
    p.score_mode = 'channel_likelihood';
    p.use_update_conf_gate = false;
    p.update_conf_gap      = 0.90;
    p.use_hmm_filter = true;
    p.hmm_temp       = 0.05;
    p.P_assumed      = [];
    p.log_theory_proxy = false;

    % -------- v72 NEW: online-adaptive HMM temperature --------
    p.use_adaptive_tau     = false;    % MASTER SWITCH: false → behaves as v70
    p.tau_calib            = 2.0;      % c_τ in hmm_temp_n = c_τ·(σ̂²_ν + Δ²σ_d²)
    p.tau_min              = 1e-3;     % lower clip
    p.tau_max              = 1.0;      % upper clip
    p.sigma_nu2_ema_alpha  = 0.99;     % EMA factor (≈ 100-symbol effective window)
    p.sigma_nu2_init       = 0.01;     % initial estimate (overridden quickly)

    % -------- N_sep (used in v72; v69 may not have it) --------
    p.N_sep = 0;
end
