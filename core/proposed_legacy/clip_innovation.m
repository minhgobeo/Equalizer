% Auto-split from NCKH_v53.m (original line 3556).
% Folder: core/proposed_legacy

function [u_tilde, clip_flag] = clip_innovation(u, kappa_use)
    if isfinite(kappa_use)
        u_tilde = sign(u) * min(abs(u), kappa_use);
        clip_flag = double(abs(u) > kappa_use);
    else
        u_tilde = u;
        clip_flag = 0;
    end
end

