% Auto-split from NCKH_v53.m (original line 6978).
% Folder: experiments/theory_legacy

function ft = supp_finite_time_validation(cfg, vars, mc)
% Validates Theorem 2': E[||θ̃_n||^2] ≤ (E[||θ̃_0||^2]+C_W)·exp(-cμn) + Δ*_finite
%
% Test: start from large ||θ̃_0|| and observe exponential decay to floor Δ*

    vv      = make_constant_gain_version(vars.theorem, 'global');
    Ntime   = cfg.Nsym;
    Nsweep  = mc.Ntrial_theorem;

    param_vs_n     = zeros(Ntime, 1);
    param_vs_n_pd  = zeros(Ntime, 1);  % oracle reference

    for t = 1:Nsweep
        rng(18000 + t);

        % Perturbed (large) initialization — far from equilibrium
        p = cfg.Nf + cfg.Nb;
        theta0 = zeros(p,1);
        theta0(1) = 1.0;
        theta0(2:end) = 0.8 * randn(p-1, 1);  % large perturbation

        sym_idx = randi([1 cfg.M], Ntime, 1);
        d = cfg.A(sym_idx).'; d = d(:);
        [r_clean,~] = channel_out(d, cfg);
        [r,~]       = add_noise_dispatch(r_clean, cfg);

        [~,~,~,di] = proposed_recursion(r,    d, cfg, vv, theta0);
        [~,~,~,dp] = proposed_recursion_pd(r, d, cfg, vv);

        err_sq = sum((di.theta_hist - dp.theta_hist).^2, 1).';
        param_vs_n = param_vs_n + err_sq;
    end
    param_vs_n = param_vs_n / Nsweep;

    % Estimate Δ*_finite from tail
    tail_len   = round(Ntime * 0.2);
    Delta_star = mean(param_vs_n(end - tail_len + 1 : end));

    % Fit exponential: param_vs_n(n) ≈ A·exp(-c·μ·n) + Δ*
    A0  = param_vs_n(cfg.trainLen + 1) - Delta_star;
    mu_eff = vv.mu_const;

    % least-squares fit of log(param - Delta*) vs n
    n_axis = (cfg.trainLen+1 : Ntime)';
    y_fit  = log(max(param_vs_n(n_axis) - Delta_star, 1e-20));
    X_fit  = [ones(numel(n_axis),1), -(n_axis - n_axis(1))];
    try
        coef   = X_fit \ y_fit;
        c_fit  = coef(2) / mu_eff;
        A_fit  = exp(coef(1));
    catch
        c_fit = NaN; A_fit = A0;
    end

    ft = struct();
    ft.param_vs_n  = param_vs_n;
    ft.Delta_star  = Delta_star;
    ft.c_fit       = c_fit;
    ft.mu_eff      = mu_eff;
    ft.n_axis      = (1:Ntime).';

    % ---- Figure G5-A: Finite-time decay ------------------------------
    figure('Name','G5-A: Theorem 2-prime — Finite-Time Exponential Decay');
    clf;

    n_plot = (cfg.trainLen+1 : Ntime);
    semilogy(n_plot, param_vs_n(n_plot), 'b-', 'LineWidth', 1.6, ...
        'DisplayName', 'E[||\tilde\theta_n||^2] (MC)');
    hold on;

    % overlay fitted curve
    if ~isnan(c_fit) && c_fit > 0
        n_fit_ax = (n_plot(1) : n_plot(end)).';
        fitted = A_fit * exp(-c_fit * mu_eff * (n_fit_ax - n_fit_ax(1))) + Delta_star;
        semilogy(n_fit_ax, fitted, 'r--', 'LineWidth', 1.5, ...
            'DisplayName', sprintf('Fitted: %.2e·exp(-%.2f·\\mu·n) + \\Delta^*', A_fit, c_fit));
    end

    yline(Delta_star, 'm:', 'LineWidth', 2, ...
        'DisplayName', sprintf('Floor \\Delta^* = %.3e', Delta_star));

    grid on;
    xlabel('Iteration n');
    ylabel('E[||\tilde\theta_n||^2]  (parameter tracking proxy)');
    title({'\bf Theorem 2'' — Non-Asymptotic Finite-Time Bound Validation';
           'Exponential transient decay from large \theta_0 to floor \Delta^*'});
    legend('Location','northeast','FontSize',9);
    set(gcf,'Position',[100 100 640 340]);

    fprintf('[G5] Finite-time: Delta* = %.4e, c_fit = %.4f, mu_eff = %.4e\n', ...
        Delta_star, c_fit, mu_eff);
end

% =========================================================================
%  GROUP 5B — ABRUPT CHANNEL JUMP: Algorithm 2 Self-Calibration Visual
% =========================================================================
