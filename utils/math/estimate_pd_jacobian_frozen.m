% Auto-split from NCKH_v53.m (original line 6116).
% Folder: utils/math

function Jhat = estimate_pd_jacobian_frozen(theta_star, cfg_f, v_theorem, eps_fd)
% Finite-difference Jacobian estimate for the frozen PD mean field

    p = numel(theta_star);
    Jhat = zeros(p,p);

    for j = 1:p
        ej = zeros(p,1);
        ej(j) = 1;

        drift_p = estimate_frozen_drift_mc(theta_star + eps_fd*ej, cfg_f, v_theorem, ...
                                           cfg_f.ode.fast_steps, true);
        drift_m = estimate_frozen_drift_mc(theta_star - eps_fd*ej, cfg_f, v_theorem, ...
                                           cfg_f.ode.fast_steps, true);

        Jhat(:,j) = (drift_p - drift_m) / (2*eps_fd);
    end
end

