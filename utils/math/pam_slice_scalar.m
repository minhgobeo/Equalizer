% Auto-split from NCKH_v53.m (original line 4044).
% Folder: utils/math

function y = pam_slice_scalar(x, A)
    [~, idx] = min(abs(x - A(:).'));
    y = A(idx);
end

