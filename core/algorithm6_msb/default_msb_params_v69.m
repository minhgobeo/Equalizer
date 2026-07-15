% Folder: core/algorithm6_msb
%
% v57 patch:
%   * Added P_assumed (default empty -> falls back to cfg.markov.P).
%   * Added log_theory_proxy (default false; opt-in by experiments).

function p = default_msb_params_v69()
    p.B      = 128;
    p.K      = 8;

    p.T_min  = 4;
    p.delta  = 0.00;
    p.rho    = 0.80;

    p.train_all_prefix = 0;
    p.score_mode = 'channel_likelihood';

    % Confidence gate does not separate right/wrong states.
    p.use_update_conf_gate = false;
    p.update_conf_gap      = 0.90;

    % HMM state filter
    p.use_hmm_filter = true;
    p.hmm_temp       = 0.05;   % test 0.02, 0.05, 0.10 if needed

    % v57 NEW: HMM-assumed transition matrix override.
    %   [] -> use cfg.markov.P (legacy behaviour, perfectly matched).
    %   3x3 stochastic matrix -> use this as HMM prior, decoupled from channel P.
    p.P_assumed = [];

    % v57 NEW: theory-proxy heavy logging. Off by default.
    p.log_theory_proxy = false;
end
