% Auto-split from NCKH_v53.m (original line 1073).
% Folder: experiments/supplement_legacy

function convrslt = run_convergence_experiment(cfg, v_context, base, mc)
    Sblk = 64;
    Nk   = floor(cfg.Nsym / Sblk);

    E_prop        = zeros(Nk,1);
    E_lms         = zeros(Nk,1);
    E_nlms        = zeros(Nk,1);
    E_rls         = zeros(Nk,1);
    E_smsign_vss  = zeros(Nk,1);
    E_smsign      = zeros(Nk,1);

    rep.saved = false;

    for t = 1:mc.Ntrial_conv
        rng(1000 + t);
        sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
        d = cfg.A(sym_idx).'; d = d(:);

        [r_clean, ~] = channel_out(d, cfg);
        [r, sigma2] = add_noise_dispatch(r_clean, cfg);

        % --------------------------
        % simple AGC for practical path
        % --------------------------
        r = apply_practical_agc(r, d, cfg);

        [y_prop, d_hat_prop, e_prop, diag_prop] = proposed_recursion(r, d, cfg, v_context); %#ok<ASGLU>
        [~,~,e_lms]         = dfe_lms_unified_x(r, d, cfg, base);
        [~,~,e_nlms]        = dfe_nlms_unified_x(r, d, cfg, base);
        [~,~,e_rls]         = dfe_rls_unified_x(r, d, cfg, base);
        [~,~,e_smsign_vss]  = dfe_smsign_nlms_vss_unified_x(r, d, cfg, base, sigma2);
        [~,~,e_smsign]      = dfe_smsign_nlms_unified_x(r, d, cfg, base, sigma2);

        E_prop        = E_prop       + block_mean(e_prop.^2, Sblk);
        E_lms         = E_lms        + block_mean(e_lms.^2, Sblk);
        E_nlms        = E_nlms       + block_mean(e_nlms.^2, Sblk);
        E_rls         = E_rls        + block_mean(e_rls.^2, Sblk);
        E_smsign_vss  = E_smsign_vss + block_mean(e_smsign_vss.^2, Sblk);
        E_smsign      = E_smsign     + block_mean(e_smsign.^2, Sblk);

        if ~rep.saved
            rep.saved = true;
            rep.r_before         = r;
            rep.y_after          = y_prop;
            rep.d_hat_after      = d_hat_prop;
            rep.mse_curve        = e_prop.^2;
            rep.e_trace          = e_prop(:);
            rep.theta_hist       = diag_prop.theta_hist;
            rep.dtheta_hist      = diag_prop.dtheta_hist;
            rep.mu_hist          = diag_prop.mu_hist;
            rep.raw_gate_hist    = diag_prop.raw_gate_hist;
            rep.conf_hist        = diag_prop.conf_hist;
            rep.accept_hard_hist = diag_prop.accept_hard_hist;
            rep.accept_mass_hist = diag_prop.accept_mass_hist;
            rep.clip_hist        = diag_prop.clip_hist;
            rep.margin_hist      = diag_prop.margin_hist;
            rep.gamma_hist       = diag_prop.gamma_hist;
            rep.kappa_hist       = diag_prop.kappa_hist;
            rep.variant_name     = v_context.kind;
        end
    end

    convrslt = struct();
    convrslt.E_prop        = E_prop        / mc.Ntrial_conv;
    convrslt.E_lms         = E_lms         / mc.Ntrial_conv;
    convrslt.E_nlms        = E_nlms        / mc.Ntrial_conv;
    convrslt.E_rls         = E_rls         / mc.Ntrial_conv;
    convrslt.E_smsign_vss  = E_smsign_vss  / mc.Ntrial_conv;
    convrslt.E_smsign      = E_smsign      / mc.Ntrial_conv;
    convrslt.rep           = rep;
end

