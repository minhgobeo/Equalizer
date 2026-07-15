% Auto-split from NCKH_v53.m (original line 958).
% Folder: utils/math

function b = local_std_beta(x, y)
    x = x(:); y = y(:);
    xs = (x - mean(x)) / max(std(x), 1e-12);
    ys = (y - mean(y)) / max(std(y), 1e-12);
    b = (xs' * ys) / max(xs' * xs, 1e-12);
end


