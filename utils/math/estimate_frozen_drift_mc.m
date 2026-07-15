% Auto-split from NCKH_v53.m (original line 966).
% Folder: utils/math

function drift_est = estimate_frozen_drift_mc(theta_fix, cfg, v, Nfast, use_pd)
    D = cfg.D; 
    K = cfg.Nf; 
    L = cfg.Nb;

    theta = theta_fix(:);
    r_buf = zeros(K,1);

    Nburn = cfg.ode.burnin;
    Ntot  = Nfast + Nburn;

    d_hat = zeros(Ntot,1);
    acc = zeros(size(theta));
    cnt = 0;

    sym_idx = randi([1 cfg.M], Ntot, 1);
    d = cfg.A(sym_idx).'; 
    d = d(:);

    [r_clean, ~] = channel_out(d, cfg);
    [r, ~] = add_noise_dispatch(r_clean, cfg);

    state = init_adaptation_state(v);

    for n = 1:Ntot
        r_buf = [r(n); r_buf(1:end-1)];
        m = n - D;

        if use_pd
            a_fb = get_fb_vector_pd(m, d, L);
        else
            a_fb = get_fb_vector(m, d, d_hat, cfg, L);
        end

        x = [r_buf; v.dfe_sign * a_fb];
        y = theta.' * x;

        if m >= 1 && m <= numel(d_hat)
            d_hat(m) = pam_slice_scalar(y, cfg.A);
        end

        has_ref = (m >= 1 && m <= numel(d));
        is_dd   = has_ref && (m > cfg.trainLen);

        if has_ref
            if use_pd
                d_ref = d(m);
            else
                if m <= cfg.trainLen
                    d_ref = d(m);
                else
                    d_ref = pam_slice_scalar(y, cfg.A);
                end
            end
            e = d_ref - y;
        else
            e = 0;
        end

        g = (x.'*x) + v.delta;
        u = e / g;

        [weight, update_innov, ctrl] = proposed_update_components(v, has_ref, is_dd, y, e, g, u, state); %#ok<ASGLU>
        state = ctrl.state_next;

        Hn = -v.lambda * theta + weight * x * update_innov;

        if n > Nburn
            acc = acc + Hn;
            cnt = cnt + 1;
        end
    end

    drift_est = acc / max(cnt,1);
end

