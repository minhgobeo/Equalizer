% Auto-split from NCKH_v53.m (original line 5328).
% Folder: config

function mu_best = calibrate_const_same_floor_mu(cfg, v_theorem, mc)
    % target from theorem baseline
    Ncal = min(3, mc.Ntrial_theorem);
    target_floor = 0;

    for t = 1:Ncal
        rng(91000 + t);
        sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
        d = cfg.A(sym_idx).'; d = d(:);
        [r_clean, ~] = channel_out(d, cfg);
        [r, ~] = add_noise_dispatch(r_clean, cfg);
        st = proposed_shadow_metrics(r, d, cfg, v_theorem);
        target_floor = target_floor + st.dd_self_error_floor;
    end
    target_floor = target_floor / Ncal;

    % search grid around const_global
    mu0 = v_theorem.mu_const_global;
    mu_grid = mu0 * [0.50 0.70 0.85 1.00 1.15 1.30 1.50];

    best_score = inf;
    mu_best = mu0;

    for ig = 1:numel(mu_grid)
        vv = make_constant_gain_version(v_theorem, 'global');
        vv.mu_const = mu_grid(ig);

        acc_floor = 0;
        acc_param = 0;

        for t = 1:Ncal
            rng(92000 + 100*ig + t);
            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg);
            [r, ~] = add_noise_dispatch(r_clean, cfg);
            st = proposed_shadow_metrics(r, d, cfg, vv);
            acc_floor = acc_floor + st.dd_self_error_floor;
            acc_param = acc_param + st.param_floor;
        end

        floor_hat = acc_floor / Ncal;
        param_hat = acc_param / Ncal;

        % floor match first, penalize tracking blow-up
        score = abs(log(max(floor_hat,1e-12)) - log(max(target_floor,1e-12))) ...
              + 50 * param_hat;

        if score < best_score
            best_score = score;
            mu_best = mu_grid(ig);
        end
    end

    fprintf('[const_same_floor recalibration] target floor = %.6e, chosen mu_const = %.6e\n', ...
        target_floor, mu_best);
end

