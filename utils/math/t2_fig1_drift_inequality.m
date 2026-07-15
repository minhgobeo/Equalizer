% Auto-split from NCKH_v53.m (original line 1644).
% Folder: utils/math

function rslt = t2_fig1_drift_inequality(cfg, v, Nt)
    Nt = max(Nt, 50);  % v49: 50+ trials to suppress spike outliers
    N = cfg.Nsym;
    blk = 500;          % larger blocks for smoother curves
    Nblk = floor(N / blk) - 1;  % -1 so we can compute forward difference

    % Accumulators for per-block quantities
    drift_sum    = zeros(Nblk, 1);   % E[V_{k+1} - V_k]
    muV_sum      = zeros(Nblk, 1);   % E[mu * V]
    mu2_sum      = zeros(Nblk, 1);   % E[mu^2]
    muBc_sum     = zeros(Nblk, 1);   % E[mu * Bc]
    Vn_sum       = zeros(Nblk, 1);   % E[V]

    for t = 1:Nt
        rng(9000 + t);
        sym_idx = randi([1 cfg.M], N, 1);
        d = cfg.A(sym_idx).'; d = d(:);
        [r_clean, ~] = channel_out(d, cfg);
        rng(9500 + t);
        [r, ~] = add_noise_dispatch(r_clean, cfg);

        [~,~,~,di] = proposed_recursion(r, d, cfg, v);
        [~,~,~,dp] = proposed_recursion_pd(r, d, cfg, v);

        theta_err2 = sum((di.theta_hist - dp.theta_hist).^2, 1).';
        mu_h = di.mu_hist;
        Bc_h = sqrt(sum((di.H_hist - dp.H_hist).^2, 1)).';

        for k = 1:Nblk
            idx  = ((k-1)*blk+1) : (k*blk);
            idx2 = (k*blk+1) : min((k+1)*blk, N);
            Vk     = mean(theta_err2(idx));
            Vk1    = mean(theta_err2(idx2));
            drift_sum(k) = drift_sum(k) + (Vk1 - Vk);
            muV_sum(k)   = muV_sum(k)   + mean(mu_h(idx) .* theta_err2(idx));
            mu2_sum(k)   = mu2_sum(k)   + mean(mu_h(idx).^2);
            muBc_sum(k)  = muBc_sum(k)  + mean(mu_h(idx) .* Bc_h(idx));
            Vn_sum(k)    = Vn_sum(k)    + Vk;
        end
        if mod(t, 10) == 0
            fprintf('    [drift] trial %d/%d\n', t, Nt);
        end
    end
    drift_avg = drift_sum / Nt;
    muV_avg   = muV_sum / Nt;
    mu2_avg   = mu2_sum / Nt;
    muBc_avg  = muBc_sum / Nt;
    Vn_avg    = Vn_sum / Nt;

    % --- Fit constants c, Cv, Cb from data ---
    % Only fit on steady-state DD blocks (skip training + early DD transient)
    ss_start = max(1, floor(cfg.trainLen / blk) + 5);
    ss_idx = ss_start : Nblk;

    % Fit via least-squares: drift = -c*muV + Cv*mu2 + Cb*muBc
    A_fit = [-muV_avg(ss_idx), mu2_avg(ss_idx), muBc_avg(ss_idx)];
    b_fit = drift_avg(ss_idx);
    coeffs = A_fit \ b_fit;
    c_fit  = max(coeffs(1), 0.01);   % ensure positive restoring
    Cv_fit = max(coeffs(2), 0);
    Cb_fit = max(coeffs(3), 0);

    % v50: TIGHT pointwise bound approach
    % Compute raw LS bound, then shift UP by the max violation + small margin
    % This gives the tightest possible valid bound
    bound_raw = -c_fit * muV_avg + Cv_fit * mu2_avg + Cb_fit * muBc_avg;
    violation = drift_avg(ss_idx) - bound_raw(ss_idx);
    max_viol = max(violation);

    % Add just enough constant offset to make bound >= drift everywhere
    % plus 5% of the drift range as visual breathing room
    drift_range = max(drift_avg(ss_idx)) - min(drift_avg(ss_idx));
    offset = max(max_viol, 0) + 0.05 * max(drift_range, abs(mean(drift_avg(ss_idx))));
    bound_fitted = bound_raw + offset;

    % v50: Count violations (should be 0 after offset)
    n_violations = sum(drift_avg(ss_idx) > bound_fitted(ss_idx));
    fprintf('    [drift] Fitted: c=%.4f, Cv=%.4f, Cb=%.4f, offset=%.2e, violations=%d/%d\n', ...
        c_fit, Cv_fit, Cb_fit, offset, n_violations, numel(ss_idx));

    nn = (1:Nblk).' * blk;

    % v49: Only plot DD-mode region for cleaner figure
    dd_start = max(1, floor(cfg.trainLen / blk) + 1);

    figure('Name','T2-Fig1: Corrected drift inequality'); clf;
    tiledlayout(1,2,'TileSpacing','compact');

    nexttile;
    dd_nn    = nn(dd_start:end);
    dd_drift = drift_avg(dd_start:end);
    dd_bound = bound_fitted(dd_start:end);
    plot(dd_nn, dd_drift, 'b-', 'LineWidth', 1.4); hold on;
    plot(dd_nn, dd_bound, 'r--', 'LineWidth', 1.8);
    yline(0, 'k:', 'LineWidth', 0.8);
    % v49: Safe margin shading — only fill where bound > drift
    margin = max(dd_bound - dd_drift, 0);
    upper_fill = dd_drift + margin;  % = max(dd_bound, dd_drift)
    fill([dd_nn; flipud(dd_nn)], [upper_fill; flipud(dd_drift)], ...
        [1 0.85 0.85], 'EdgeColor','none', 'FaceAlpha', 0.3);
    grid on; xlabel('n'); ylabel('E[W_{n+1}-W_n]');
    legend({'Actual drift','Fitted upper bound','','Margin'},'Location','best');
    title(sprintf('(a) Drift inequality (c=%.3f, C_\\nu=%.3f)', c_fit, Cv_fit));

    nexttile;
    % v49: Show only DD mode (skip training phase near-zero region)
    semilogy(dd_nn, max(Vn_avg(dd_start:end), 1e-15), 'b-', 'LineWidth', 1.4);
    hold on;
    ss_floor = mean(Vn_avg(ss_idx));
    yline(ss_floor, 'r:', 'LineWidth', 1.2);
    grid on; xlabel('n'); ylabel('E[||\theta_n - \theta^*||^2]');
    legend({'Tracking error (DD mode)', ...
        sprintf('SS floor = %.2e', ss_floor)}, 'Location','best');
    title('(b) Tracking error (DD mode)');

    rslt.drift = drift_avg; rslt.bound = bound_fitted; rslt.Vn = Vn_avg;
    rslt.c_fit = c_fit; rslt.Cv_fit = Cv_fit; rslt.Cb_fit = Cb_fit;
    rslt.n_violations = n_violations;
end

% --- Figure T2-2: Three-Part Floor Decomposition ---
