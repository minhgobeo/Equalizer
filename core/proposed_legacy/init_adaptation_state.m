% Auto-split from NCKH_v53.m (original line 3369).
% Folder: core/proposed_legacy

function state = init_adaptation_state(v)
    state = struct();
    state.sigma_e2 = 0.0;
    state.sigma_u2 = 0.0;
    state.bias_hat = 0.0;
    state.drift_hat = 0.0;
    state.prev_margin = 0.0;
    state.dtheta_prev = 0;  % scalar init; first norm()=0; overwritten by theta_new-theta at step 1
    if isfield(v,'tau_c0'), state.tau_c = v.tau_c0; else, state.tau_c = getfield_safe(v,'tau_c',0.0); end %#ok<GFLD>
    if isfield(v,'gamma_u0'), state.gamma_u = v.gamma_u0; else, state.gamma_u = getfield_safe(v,'gamma_u',0.0); end %#ok<GFLD>
    if isfield(v,'kappa_u0'), state.kappa_u = v.kappa_u0; else, state.kappa_u = getfield_safe(v,'kappa_u',Inf); end %#ok<GFLD>
end

