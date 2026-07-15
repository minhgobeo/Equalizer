% Auto-split from NCKH_v53.m (original line 2231).
% Folder: utils/math

function [y, dh, e] = deal_recursion_err(r, d, cfg, v, fn)
    [y, dh, e, ~] = fn(r, d, cfg, v);
end

% --- Figure T2-7: SER Comparison (delegates to existing) ---
