% Auto-split from NCKH_v53.m (original line 4028).
% Folder: utils/math

function fb = get_fb_symbol(m, d, d_hat_sym, cfg)
    fb_idx = m - 1;
    if fb_idx < 1 || fb_idx > numel(d_hat_sym)
        fb = 0;
        return;
    end
    switch upper(cfg.mode)
        case 'TF'
            if m<=cfg.trainLen, fb = d(fb_idx); else, fb = d_hat_sym(fb_idx); end
        case 'BLIND'
            fb = d_hat_sym(fb_idx);
        otherwise
            error('Unknown cfg.mode.');
    end
end

