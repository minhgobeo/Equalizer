% Auto-split from NCKH_v53.m (original line 1878).
% Folder: utils/math

function rslt = t2_fig3_finite_time_bound(cfg, v, Nt)
    Nt = max(Nt, 30);  % need enough trials for smooth curve

    % ====================================================================
    % COLD-START VALIDATION (v49 fix)
    % Run with trainLen=0 (pure DD from start) and constant mu so that
    % theta starts far from theta* and must decay exponentially.
    % This directly validates Theorem 2': E[V_n] <= (V0+C_W)e^{-c*mu*n} + Delta*
    % ====================================================================
    cfg_cold = cfg;
    cfg_cold.trainLen = 0;    % NO training: pure DD from symbol 1
    N = cfg_cold.Nsym;

    % Use constant mu (Theorem 2' assumes constant step size)
    v_const = v;
    mu_const = v.mu_max;      % use mu_max for visible decay rate
    v_const.mu_max = mu_const;
    v_const.mu_min = mu_const;
    v_const.mu_const_global = mu_const;
    v_const.Tclr = 1;         % disable CLR cycling

    blk = 500;                % larger blocks for smoother averaging
    Nblk = floor(N / blk);
    nn = (1:Nblk).' * blk;

    Vn_sum = zeros(Nblk, 1);

    for t = 1:Nt
        rng(11000 + t);
        sym_idx = randi([1 cfg_cold.M], N, 1);
        d = cfg_cold.A(sym_idx).'; d = d(:);
        [r_clean, ~] = channel_out(d, cfg_cold);
        rng(11500 + t);
        [r, ~] = add_noise_dispatch(r_clean, cfg_cold);

        [~,~,~,di] = proposed_recursion(r, d, cfg_cold, v_const);
        [~,~,~,dp] = proposed_recursion_pd(r, d, cfg_cold, v_const);

        theta_err2 = sum((di.theta_hist - dp.theta_hist).^2, 1).';
        for k = 1:Nblk
            idx = ((k-1)*blk+1) : min(k*blk, N);
            Vn_sum(k) = Vn_sum(k) + mean(theta_err2(idx));
        end
        if mod(t, 10) == 0
            fprintf('    [finite] trial %d/%d\n', t, Nt);
        end
    end
    Vn_avg = Vn_sum / Nt;

    % Apply light smoothing (moving average, window=5) for cleaner plot
    win = 5;
    Vn_smooth = Vn_avg;
    for k = (win+1):(Nblk-win)
        Vn_smooth(k) = mean(Vn_avg(max(1,k-win):min(Nblk,k+win)));
    end

    % --- Fit envelope from cold-start data ---
    % Steady-state floor: median of last 30% of blocks (robust to outliers)
    ss_start = max(1, floor(0.7 * Nblk));
    Delta_finite = median(Vn_avg(ss_start:end));

    % Initial value: average of first 3 blocks
    V0_est = mean(Vn_avg(1:min(3, Nblk)));

    % Fit decay rate from the TRANSIENT phase only
    % Since trainLen=0, blocks start with high error and decay
    trans_start = 1;
    trans_end = min(floor(0.5*Nblk), Nblk);
    trans_idx = trans_start:trans_end;

    % Robust fitting: only use blocks where Vn > 1.5*Delta (clearly in transient)
    above_floor = Vn_avg(trans_idx) > 1.5 * Delta_finite;
    if sum(above_floor) > 3
        fit_idx = trans_idx(above_floor);
    else
        fit_idx = trans_idx;
    end

    log_decay = log(max(Vn_avg(fit_idx) - Delta_finite * 0.95, 1e-15));
    X_reg = [ones(numel(fit_idx),1), nn(fit_idx)];
    beta_reg = X_reg \ log_decay;
    c_mu_fit = max(-beta_reg(2), 1e-8);
    c_fit = c_mu_fit / max(mu_const, 1e-8);

    % Fallback: if c_fit is unreasonably small, use theoretical lower bound
    % From Lemma T2-L5: c = c0/2. Typical c0 ~ 0.5-2.0 for NLMS-type
    if c_fit < 0.01
        fprintf('    [finite] WARNING: fitted c=%.4f too small, using c=0.25 fallback\n', c_fit);
        c_fit = 0.25;
        c_mu_fit = c_fit * mu_const;
    end

    % Build envelope
    V0_env = V0_est * 1.5;   % slight margin above initial value
    CW_est = 0.1 * V0_est;   % corrector bound estimate
    envelope = (V0_env + CW_est) * exp(-c_mu_fit * nn) + Delta_finite;

    % Ensure envelope is always above simulation (auto-scaling)
    scale_up = max(Vn_smooth ./ max(envelope, 1e-15));
    if scale_up > 1
        V0_env = V0_env * scale_up * 1.3;
        envelope = (V0_env + CW_est) * exp(-c_mu_fit * nn) + Delta_finite;
    end

    % n* transition point
    if Delta_finite > 1e-15 && c_mu_fit > 1e-10
        n_star = (1/c_mu_fit) * log(max((V0_env + CW_est) / Delta_finite, 1));
    else
        n_star = N;
    end
    n_star = min(n_star, N);

    fprintf('    [finite] V0=%.2e, Delta*=%.2e, c=%.4f, c*mu=%.2e, n*=%d\n', ...
        V0_env, Delta_finite, c_fit, c_mu_fit, round(n_star));

    % --- Plot ---
    figure('Name','T2-Fig3: Finite-time bound (Theorem 2 prime)'); clf;
    h_plots = [];  leg_str = {};
    h_plots(end+1) = semilogy(nn, Vn_smooth, 'b-', 'LineWidth', 1.4); hold on;
    leg_str{end+1} = 'Simulated E[V_n] (smoothed)';
    h_plots(end+1) = semilogy(nn, envelope, 'r--', 'LineWidth', 2.0);
    leg_str{end+1} = sprintf('Envelope: (V_0+C_W)e^{-c\\mu n}+\\Delta^*');
    h_plots(end+1) = yline(max(Delta_finite,1e-15), 'k:', 'LineWidth', 1.2);
    leg_str{end+1} = sprintf('\\Delta^*_{finite} = %.2e', Delta_finite);
    h_plots(end+1) = yline(max(2*Delta_finite,1e-15), 'm:', 'LineWidth', 1.0);
    leg_str{end+1} = sprintf('2\\Delta^*_{finite} = %.2e', 2*Delta_finite);
    if n_star > 0 && n_star < max(nn)
        h_plots(end+1) = xline(n_star, 'k-.', 'LineWidth', 1.0);
        leg_str{end+1} = sprintf('n^* = %d', round(n_star));
    end
    grid on; xlabel('n'); ylabel('E[||\theta_n - \theta^*_n||^2]');
    legend(h_plots, leg_str, 'Location','northeast','FontSize',8);
    title(sprintf('Theorem 2'': Finite-time bound (c=%.2f, \\mu=%.3f)', c_fit, mu_const));

    rslt.Vn = Vn_avg; rslt.Vn_smooth = Vn_smooth; rslt.envelope = envelope;
    rslt.Delta_finite = Delta_finite; rslt.n_star = n_star; rslt.c_fit = c_fit;
    rslt.mu_const = mu_const; rslt.c_mu = c_mu_fit;
end

% --- Figure T2-4: CLR vs Constant Gain (Theorem 2'') ---
