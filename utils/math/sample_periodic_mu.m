% Auto-split from NCKH_v53.m (original line 4193).
% Folder: utils/math

function mu = sample_periodic_mu(mu_min, mu_max, T, nvec)
    mu = zeros(size(nvec));
    for k = 1:numel(nvec)
        mu(k) = smith_tri_clr(nvec(k)-1, mu_min, mu_max, T);
    end
end

