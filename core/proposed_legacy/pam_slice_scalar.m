function y = pam_slice_scalar(x, A)
% PAM_SLICE_SCALAR  Nearest-constellation-point slicer.
%
% Extracted verbatim from NCKH_v53_original.m (original line 4044).
%
% Maps a soft equalizer output x to the closest PAM symbol in alphabet A.
%
% INPUTS
%   x : scalar (or array) of soft decisions
%   A : PAM alphabet, e.g. [-3 -1 +1 +3] for PAM4
%
% OUTPUT
%   y : sliced hard decision(s)

    [~, idx] = min(abs(x - A(:).'));
    y = A(idx);
end
