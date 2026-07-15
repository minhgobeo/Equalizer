% Auto-split from NCKH_v53.m (original line 3595).
% Folder: utils/math

function [x, r_buf, d_hat_sym, has_ref, d_des, e, y] = baseline_step_common(rn, n, r_buf, d, d_hat_sym, cfg, theta)
% Common baseline regressor builder with fair tap structure:
% x = [FFE taps; -DFE taps], where FFE/DFE lengths come from cfg.Nf/cfg.Nb

    D = cfg.D;
    K = cfg.Nf;
    L = cfg.Nb;

    r_buf = [rn; r_buf(1:end-1)];

    m = n - D;
    a_fb = get_fb_vector(m, d, d_hat_sym, cfg, L);

    x = [r_buf; -a_fb];
    y = theta.' * x;

    has_ref = (m >= 1 && m <= numel(d));

    if has_ref
        d_hat_sym(m) = pam_slice_scalar(y, cfg.A);
        if m <= cfg.trainLen
            d_des = d(m);
        else
            d_des = pam_slice_scalar(y, cfg.A);
        end
        e = d_des - y;
    else
        d_des = 0;
        e = 0;
    end
end

