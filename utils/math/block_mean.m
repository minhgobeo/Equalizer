% Auto-split from NCKH_v53.m (original line 4054).
% Folder: utils/math

function yblk = block_mean(x, Sblk)
    N = floor(numel(x)/Sblk);
    xx = x(1:N*Sblk);
    xx = reshape(xx, Sblk, N);
    yblk = mean(xx,1).';
end

