% Auto-split from NCKH_v53.m (original line 4068).
% Folder: utils/math

function xos = upsample_zeros(x, sps)
    xos = zeros(numel(x)*sps,1);
    xos(1:sps:end) = x(:);
end

