% Auto-split from NCKH_v53.m (original line 4049).
% Folder: utils/metrics

function m = pam4_confidence_margin(y)
    B = [-2 0 2];
    m = min(abs(y - B));
end

