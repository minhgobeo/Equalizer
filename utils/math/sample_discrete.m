% Auto-split from NCKH_v53.m (original line 3975).
% Folder: utils/math

function idx = sample_discrete(p, nS)
    c = cumsum(p(:));
    u = rand;
    idx = find(u <= c, 1, 'first');
    if isempty(idx), idx = nS; end
end

