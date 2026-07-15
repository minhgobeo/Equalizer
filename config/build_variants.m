% Auto-split from NCKH_v53.m (original line 504).
% Folder: config

function vars = build_variants(cfg)
    common = struct();
    common.fix_main_tap = true;
    common.main_idx     = 3;
    common.w_main_value = 1.0;
    common.dfe_sign     = -1;

    common.delta  = 1e-3;
    common.lambda = 1e-3;

    common.mu_max = 3.0e-2;         % tuned via auto-tuning at SNR=[9,18,27]
    common.mu_min = 3.0e-5;
    common.Tclr   = 400;
    common.mu_const_global = mean(sample_periodic_mu(common.mu_min, common.mu_max, common.Tclr, 1:2000));

    common.w2_max = 5.0;
    common.b_max  = 2.0;

    K = cfg.Nf;
    L = cfg.Nb;
    main_idx = common.main_idx;

    ffe_min = -common.w2_max * ones(K,1);
    ffe_max =  common.w2_max * ones(K,1);

    % main tap is projection-controlled, so leave it unbounded here
    ffe_min(main_idx) = -Inf;
    ffe_max(main_idx) =  Inf;

    common.theta_min = [ffe_min; -common.b_max * ones(L,1)];
    common.theta_max = [ffe_max;  common.b_max * ones(L,1)];

    % theorem-core
    v_theorem = common;
    v_theorem.kind = 'theorem';
    v_theorem.use_hard_confidence_dd = true;
    v_theorem.tau_c = 0.45;
    v_theorem.gamma_tr = 0.0;
    v_theorem.gamma_u  = 1.0e-2;
    v_theorem.kappa_u  = 0.10;
    v_theorem.force_no_clip = false;
    v_theorem.mu_mode = 'bounded';
    v_theorem.mu0      = cfg.ode.mu0;
    v_theorem.mu_decay = cfg.ode.mu_decay;

    % -------------------------------------------------
    % practical: loosen control so FFE can learn faster
    % -------------------------------------------------
    v_practical = common;
    v_practical.kind = 'practical';
    v_practical.lambda = common.lambda;
    v_practical.use_soft_confidence_dd = true;

    % loosen thresholds for open-eye stage
    v_practical.tau_c    = 0.15;        % tuned via auto-tuning
    v_practical.cmin     = 0.08;
    v_practical.gamma_tr = 0.0;

    v_practical.beta_e      = 5e-3;
    v_practical.c_gamma_e   = 1.5;
    v_practical.gamma_e_min = 2e-3;

    v_practical.beta_u      = 5e-3;
    v_practical.c_kappa_u   = 8.0;
    v_practical.kappa_u_min = 0.02;

    v_practical.force_no_clip = false;
    v_practical.mu_mode = 'bounded';
    v_practical.mu0      = cfg.ode.mu0;
    v_practical.mu_decay = cfg.ode.mu_decay;

    % locked noise-aware for final paper
    v_noise = common;
    v_noise.kind = 'noise_aware';
    v_noise.lambda = 1e-3;
    v_noise.use_hard_confidence_dd = true;
    v_noise.tau_c0 = 0.45;
    v_noise.tau_c  = 0.45;
    v_noise.gamma_tr = 0.0;
    v_noise.gamma_u0 = 1.25e-2;
    v_noise.gamma_u  = 1.25e-2;
    v_noise.kappa_u0 = 0.10;
    v_noise.kappa_u  = 0.10;
    v_noise.force_no_clip = false;
    v_noise.mu_mode = 'bounded';
    v_noise.mu0      = cfg.ode.mu0;
    v_noise.mu_decay = cfg.ode.mu_decay;

    v_noise.use_adaptive_mu    = true;
    v_noise.use_adaptive_tau   = true;
    v_noise.use_adaptive_kappa = false;

    v_noise.sigma_u2_ref = 1e-3;
    v_noise.bias_ref     = 1e-4;
    v_noise.drift_ref    = 5e-5;

    v_noise.alpha_sigma  = 0.05;
    v_noise.alpha_b      = 0.18;
    v_noise.alpha_d      = 0.40;
    v_noise.mu_scale_min = 0.70;
    v_noise.mu_scale_max = 2.20;

    v_noise.tau_min   = 0.30;
    v_noise.tau_max   = 0.55;
    v_noise.gamma_min = 4e-3;
    v_noise.gamma_max = 1.8e-2;
    v_noise.kappa_min = 0.04;
    v_noise.kappa_max = 0.15;
    v_noise.b_bias    = 0.015;
    v_noise.b_drift   = 0.005;
    v_noise.k_bias    = 0.15;

    v_noise.beta_b = 5e-4;
    v_noise.beta_d = 5e-4;
    v_noise.beta_u = 5e-4;
    v_noise.beta_e = 5e-4;

    v_noise.locked = true;

    vars = struct();
    vars.theorem     = v_theorem;
    vars.practical   = v_practical;
    vars.noise_aware = v_noise;

    switch lower(cfg.context_variant)
        case 'practical'
            vars.context = v_practical;
        case 'theorem'
            vars.context = v_theorem;
        case 'noise_aware'
            vars.context = v_noise;
        otherwise
            error('Unknown cfg.context_variant.');
    end

    fprintf('[const_global] fixed gain = %.6f\n', common.mu_const_global);
end

