% Auto-split from NCKH_v53.m (original line 6095).
% Folder: utils/math

function theta_star = estimate_pd_reference_frozen(cfg_f, v_theorem, seed)
% Estimate the frozen perfect-decision reference by a long PD run

    rng(seed);

    sym_idx = randi([1 cfg_f.M], cfg_f.Nsym, 1);
    d = cfg_f.A(sym_idx).'; d = d(:);

    [r_clean, ~] = channel_out(d, cfg_f);
    [r, ~] = add_noise_dispatch(r_clean, cfg_f);

    vv = make_constant_gain_version(v_theorem, 'global');
    vv.mu_const = min(max(2*v_theorem.mu_min, 5e-4), 0.25*v_theorem.mu_max);
    vv.mu_min   = vv.mu_const;
    vv.mu_max   = vv.mu_const;
    vv.force_no_clip = false;

    [~,~,~,diag_pd] = proposed_recursion_pd(r, d, cfg_f, vv);
    theta_star = diag_pd.theta_hist(:,end);
end

