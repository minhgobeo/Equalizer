% Auto-split from NCKH_v53.m (original line 1399).
% Folder: utils/math

function best_base = autotune_baselines(cfg_tune, Nt, tune_snrs)
% Grid search for each baseline algorithm independently.
% Evaluates across multiple SNR points.
    base0 = build_baselines();
    if nargin < 3, tune_snrs = 18; end

    % --- LMS ---
    fprintf('  [baselines] Tuning LMS...\n');
    mu_lms_grid = [1e-3 3e-3 5e-3 1e-2 2e-2 5e-2];
    best_lms = Inf; best_mu_lms = base0.mu_lms;
    for mu = mu_lms_grid
        b = base0; b.mu_lms = mu;
        s = eval_baseline_ser(cfg_tune, @dfe_lms_unified_x, b, Nt, false, tune_snrs);
        if s < best_lms, best_lms = s; best_mu_lms = mu; end
    end
    fprintf('    LMS best: mu=%.4f SER=%.4f\n', best_mu_lms, best_lms);

    % --- NLMS ---
    fprintf('  [baselines] Tuning NLMS...\n');
    mu_nlms_grid = [1e-2 3e-2 5e-2 8e-2 1.5e-1 3e-1];
    best_nlms = Inf; best_mu_nlms = base0.mu_nlms;
    for mu = mu_nlms_grid
        b = base0; b.mu_nlms = mu;
        s = eval_baseline_ser(cfg_tune, @dfe_nlms_unified_x, b, Nt, false, tune_snrs);
        if s < best_nlms, best_nlms = s; best_mu_nlms = mu; end
    end
    fprintf('    NLMS best: mu=%.4f SER=%.4f\n', best_mu_nlms, best_nlms);

    % --- RLS ---
    fprintf('  [baselines] Tuning RLS...\n');
    lam_rls_grid = [0.98 0.99 0.995 0.999];
    best_rls = Inf; best_lam_rls = base0.lambda_rls;
    for lam = lam_rls_grid
        b = base0; b.lambda_rls = lam;
        s = eval_baseline_ser(cfg_tune, @dfe_rls_unified_x, b, Nt, false, tune_snrs);
        if s < best_rls, best_rls = s; best_lam_rls = lam; end
    end
    fprintf('    RLS best: lambda=%.4f SER=%.4f\n', best_lam_rls, best_rls);

    % --- SM-sign-NLMS ---
    fprintf('  [baselines] Tuning SM-sign-NLMS...\n');
    beta_grid = [1e-2 3e-2 5e-2 8e-2 1.5e-1];
    tau_sm_grid = [1.5 2.0 3.0 4.0 5.0];
    best_sms = Inf; best_beta_sm = base0.smsign.beta; best_tau_sm = base0.smsign.tau;
    for beta = beta_grid
        for tau = tau_sm_grid
            b = base0; b.smsign.beta = beta; b.smsign.tau = tau;
            s = eval_baseline_ser(cfg_tune, @dfe_smsign_nlms_unified_x, b, Nt, true, tune_snrs);
            if s < best_sms, best_sms = s; best_beta_sm = beta; best_tau_sm = tau; end
        end
    end
    fprintf('    SM-sign best: beta=%.4f tau=%.2f SER=%.4f\n', best_beta_sm, best_tau_sm, best_sms);

    % --- SM-sign-NLMS VSS ---
    fprintf('  [baselines] Tuning SM-sign-NLMS VSS...\n');
    beta0_grid = [1e-2 3e-2 5e-2 8e-2 1.5e-1];
    best_svss = Inf; best_beta0_svss = base0.smsign_vss.beta0; best_tau_svss = base0.smsign_vss.tau;
    for beta0 = beta0_grid
        for tau = tau_sm_grid
            b = base0;
            b.smsign_vss.beta0 = beta0;
            b.smsign_vss.beta_min = 0.1 * beta0;
            b.smsign_vss.beta_max = 2.5 * beta0;
            b.smsign_vss.tau = tau;
            s = eval_baseline_ser(cfg_tune, @dfe_smsign_nlms_vss_unified_x, b, Nt, true, tune_snrs);
            if s < best_svss, best_svss = s; best_beta0_svss = beta0; best_tau_svss = tau; end
        end
    end
    fprintf('    SM-sign-VSS best: beta0=%.4f tau=%.2f SER=%.4f\n', best_beta0_svss, best_tau_svss, best_svss);

    best_base = base0;
    best_base.mu_lms    = best_mu_lms;
    best_base.mu_nlms   = best_mu_nlms;
    best_base.lambda_rls = best_lam_rls;
    best_base.smsign.beta = best_beta_sm;
    best_base.smsign.tau  = best_tau_sm;
    best_base.smsign_vss.beta0    = best_beta0_svss;
    best_base.smsign_vss.beta_min = 0.1 * best_beta0_svss;
    best_base.smsign_vss.beta_max = 2.5 * best_beta0_svss;
    best_base.smsign_vss.tau      = best_tau_svss;
end

