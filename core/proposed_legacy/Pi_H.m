% Auto-split from NCKH_v53.m (original line 3566).
% Folder: core/proposed_legacy

function theta_p = Pi_H(theta_u, v, K)
    theta_p = theta_u;
    theta_p = min(max(theta_p, v.theta_min), v.theta_max);
    if v.fix_main_tap
        idx = v.main_idx;
        if idx >= 1 && idx <= K
            theta_p(idx) = v.w_main_value;
        end
    end
end

