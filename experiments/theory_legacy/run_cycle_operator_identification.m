% Auto-split from NCKH_v53.m (original line 6012).
% Folder: experiments/theory_legacy

function cyc_id = run_cycle_operator_identification(cfg, v_theorem, mc)
% ============================================================
% THEOREM 2: EMPIRICAL CYCLE-OPERATOR IDENTIFICATION
%
% Purpose:
%   - estimate local PD Jacobian J_pd(s) at a frozen state
%   - build empirical one-cycle operator Phi_T(s)
%   - compare predicted cycle contraction against observed cycle-boundary mismatch decay
% ============================================================

    cfg_c = cfg;
    cfg_c.chan_mode = 'frozen_markov_state';
    cfg_c.markov.fixed_state = cfg.markov.fixed_state;
    cfg_c.SNRdB = max(cfg.ode.SNRdB_ode, 35);
    cfg_c.trainLen = 1000;
    cfg_c.Nsym = max(25000, cfg_c.trainLen + 12*v_theorem.Tclr);

    % 1) Estimate PD frozen reference
    theta_star = estimate_pd_reference_frozen(cfg_c, v_theorem, 31001);

    % 2) Estimate local Jacobian around theta_star
    eps_fd = 2e-3;
    Jhat = estimate_pd_jacobian_frozen(theta_star, cfg_c, v_theorem, eps_fd);

    % 3) Build theoretical schedules
    mu_tri = sample_periodic_mu(v_theorem.mu_min, v_theorem.mu_max, v_theorem.Tclr, 1:v_theorem.Tclr);
    mu_sf  = v_theorem.mu_min * ones(1, v_theorem.Tclr);
    mu_se  = sqrt(mean(mu_tri.^2)) * ones(1, v_theorem.Tclr);

    Phi_tri = build_one_cycle_operator(Jhat, mu_tri);
    Phi_sf  = build_one_cycle_operator(Jhat, mu_sf);
    Phi_se  = build_one_cycle_operator(Jhat, mu_se);

    pred_rho = [max(abs(eig(Phi_tri)));
                max(abs(eig(Phi_sf)));
                max(abs(eig(Phi_se)))];

    pred_nrm = [norm(Phi_tri,2);
                norm(Phi_sf,2);
                norm(Phi_se,2)];

    % 4) Observed cycle ratios from actual simulation
    obs_ratio = empirical_cycle_ratio_cases(cfg_c, v_theorem, mc);

    cyc_id = struct();
    cyc_id.theta_star = theta_star;
    cyc_id.Jhat       = Jhat;
    cyc_id.Phi_tri    = Phi_tri;
    cyc_id.Phi_sf     = Phi_sf;
    cyc_id.Phi_se     = Phi_se;
    cyc_id.pred_rho   = pred_rho;
    cyc_id.pred_nrm   = pred_nrm;
    cyc_id.obs_ratio  = obs_ratio;
    cyc_id.cases      = {'triangular','same_floor','same_energy'};

    figure('Name','Theorem 2: cycle operator identification'); clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    nexttile;
    bar([pred_rho pred_nrm]);
    grid on;
    set(gca,'XTick',1:3,'XTickLabel',cyc_id.cases,'XTickLabelRotation',20);
    ylabel('predicted contraction metric');
    legend({'$\rho(\Phi_T)$','$\|\Phi_T\|_2$'}, ...
       'Location','best', ...
       'Interpreter','latex');    
    title('(a) Predicted one-cycle contraction');

    nexttile;
    bar([pred_rho obs_ratio(:)]);
    grid on;
    set(gca,'XTick',1:3,'XTickLabel',cyc_id.cases,'XTickLabelRotation',20);
    ylabel('cycle metric');
    legend({'predicted $\rho(\Phi_T)$','observed mismatch ratio'}, ...
           'Location','best', ...
           'Interpreter','latex');
    title('(b) Predicted vs observed cycle mismatch decay');

    fprintf('\n=== Theorem 2 cycle-operator identification ===\n');
    disp(table(cyc_id.cases(:), pred_rho, pred_nrm, obs_ratio(:), ...
        'VariableNames', {'Case','PredRho','PredNorm2','ObservedRatio'}));
end

