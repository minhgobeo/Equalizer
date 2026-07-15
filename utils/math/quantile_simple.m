% Auto-split from NCKH_v53.m (original line 4112).
% Folder: utils/math

function q = quantile_simple(x, qlev)
    xs = sort(x(:));
    if isempty(xs), q = NaN; return; end
    idx = max(1, min(numel(xs), round(qlev*numel(xs))));
    q = xs(idx);
end

