function fb_vec = get_fb_vector_pd(m, d, L)
% GET_FB_VECTOR_PD  Perfect-decision (oracle) DFE feedback vector.
%
% Extracted verbatim from NCKH_v53_original.m (original line 4018).
%
% Always returns the L true past symbols d(m-1), ..., d(m-L). Used by the
% B_c diagnostic to form the oracle-decision regressor.
%
% INPUTS
%   m : symbol index
%   d : true symbol stream
%   L : DFE length
%
% OUTPUT
%   fb_vec : L x 1 feedback vector of true symbols

    fb_vec = zeros(L,1);
    for ell = 1:L
        idx = m - ell;
        if idx >= 1 && idx <= numel(d)
            fb_vec(ell) = d(idx);
        end
    end
end
