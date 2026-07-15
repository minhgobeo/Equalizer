% Auto-split from NCKH_v53.m (original line 3195).
% Folder: utils/math

function y = top_percent_mean(x, p)
    x = x(:);
    x = sort(x, 'descend');
    k = max(1, round(numel(x) * p / 100));
    y = mean(x(1:k));
end
%% =====================================================================
% SHADOW METRICS / THEOREM-ALIGNED DIAGNOSTICS
%% =====================================================================
