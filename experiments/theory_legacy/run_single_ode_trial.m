% Auto-split from NCKH_v53.m (original line 858).
% Folder: experiments/theory_legacy

function rs = run_single_ode_trial(cfg_ode, v, theta0, seed)
    rng(seed);

    sym_idx = randi([1 cfg_ode.M], cfg_ode.Nsym, 1);
    d = cfg_ode.A(sym_idx).';
    d = d(:);

    [r_clean, ~] = channel_out(d, cfg_ode);
    [r, ~] = add_noise_dispatch(r_clean, cfg_ode);

    % SA trajectory
    if cfg_ode.ode.use_pd_drift
        [~, ~, ~, diag] = proposed_recursion_pd(r, d, cfg_ode, v, theta0);
    else
        [~, ~, ~, diag] = proposed_recursion(r, d, cfg_ode, v, theta0);
    end

    stride   = cfg_ode.ode.grid_stride;
    idx_grid = 1:stride:cfg_ode.Nsym;
    if idx_grid(end) ~= cfg_ode.Nsym
        idx_grid = [idx_grid cfg_ode.Nsym];
    end

    theta_sa = diag.theta_hist(:, idx_grid);

    % algorithmic time grid
    t_grid = zeros(numel(idx_grid),1);
    for k = 2:numel(idx_grid)
        n0 = idx_grid(k-1);
        n1 = idx_grid(k) - 1;
        t_grid(k) = t_grid(k-1) + sum(diag.mu_hist(n0:n1));
    end

    % ODE trajectory
    theta_ode = zeros(size(theta_sa));
    theta_ode(:,1) = Pi_H(theta0, v, cfg_ode.Nf);

    Nsub = cfg_ode.ode.ode_substeps;

    for k = 1:(numel(idx_grid)-1)
        n0 = idx_grid(k);
        n1 = idx_grid(k+1) - 1;

        Delta_t = sum(diag.mu_hist(n0:n1));
        dt = Delta_t / Nsub;

        th = theta_ode(:,k);

        for js = 1:Nsub
            drift_est = estimate_frozen_drift_mc( ...
                th, cfg_ode, v, cfg_ode.ode.fast_steps, cfg_ode.ode.use_pd_drift);
            th = Pi_H(th + dt * drift_est, v, cfg_ode.Nf);
        end

        theta_ode(:,k+1) = th;
    end

    rs = struct();
    rs.idx_grid    = idx_grid;
    rs.t_grid      = t_grid;
    rs.theta_sa    = theta_sa;
    rs.theta_euler = theta_ode;
end

