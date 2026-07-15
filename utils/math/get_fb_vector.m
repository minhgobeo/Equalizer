% Auto-split from NCKH_v53.m (original line 3999).
% Folder: utils/math

function fb_vec = get_fb_vector(m, d, d_hat_sym, cfg, L)
    fb_vec = zeros(L,1);
    for ell = 1:L
        idx = m - ell;
        if idx < 1 || idx > numel(d_hat_sym)
            fb_vec(ell) = 0;
            continue;
        end
        switch upper(cfg.mode)
            case 'TF'
                if m <= cfg.trainLen, fb_vec(ell) = d(idx); else, fb_vec(ell) = d_hat_sym(idx); end
            case 'BLIND'
                fb_vec(ell) = d_hat_sym(idx);
            otherwise
                error('Unknown cfg.mode.');
        end
    end
end

