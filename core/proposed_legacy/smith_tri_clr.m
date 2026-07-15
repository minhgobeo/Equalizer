% Auto-split from NCKH_v53.m (original line 3577).
% Folder: core/proposed_legacy

function mu = smith_tri_clr(k0, mu_min, mu_max, T)
    if T <= 1
        mu = mu_max;
        return;
    end
    mu_min = max(mu_min, 0);
    mu_max = max(mu_max, mu_min);
    s = T / 2;
    t = mod(k0, T);
    tau = t / s;
    rho_max = mu_max / max(mu_min, eps);
    rho = 1 + (rho_max - 1) * (1 - abs(tau - 1));
    mu = mu_min * rho;
end

%% =====================================================================
% BASELINES
%% =====================================================================
