% Auto-split from NCKH_v53.m (original line 4119).
% Folder: utils/math

function tm = tail_mean(x, frac)
    xs = sort(x(:), 'descend');
    K = max(1, round(frac * numel(xs)));
    tm = mean(xs(1:K));
end

