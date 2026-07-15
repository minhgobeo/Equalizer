% Auto-split from NCKH_v53.m (original line 4018).
% Folder: utils/math

function fb_vec = get_fb_vector_pd(m, d, L)
    fb_vec = zeros(L,1);
    for ell = 1:L
        idx = m - ell;
        if idx >= 1 && idx <= numel(d)
            fb_vec(ell) = d(idx);
        end
    end
end

