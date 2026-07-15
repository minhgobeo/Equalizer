% Auto-split from NCKH_v53.m (original line 6311).
% Folder: experiments/theory_legacy

function ode = supp_ode_sanity(cfg, vars, mc)
% Validates Theorem 1: SA trajectory shadows ODE backbone
% Mirrors Experiment T1-S1 from paper

    cfg_ode              = cfg;
    cfg_ode.Nsym         = cfg.ode.Nsym;
    cfg_ode.chan_mode     = 'frozen_markov_state';
    cfg_ode.SNRdB        = cfg.ode.SNRdB_ode;
    cfg_ode.trainLen     = 0;
    cfg_ode.markov.fixed_state = cfg.markov.fixed_state;

    v          = vars.theorem;
    v.mu_mode  = 'diminishing';
    v.mu0      = cfg.ode.mu0;
    v.mu_decay = 5e-3;

    theta0 = mc.ode_init_bank(:, mc.ode.main_init_idx);
    theta_idx = cfg.ode.plot_theta_idx;

    Ntrial = min(mc.Ntrial_ode, 30);
    E_bank = zeros(Ntrial, 1);
    sa_store  = [];
    ode_store = [];
    t_ref     = [];

    for t = 1:Ntrial
        rs = run_single_ode_trial(cfg_ode, v, theta0, 50000 + t);

        y_sa  = rs.theta_sa(theta_idx, :).';
        y_ode = rs.theta_euler(theta_idx, :).';

        if isempty(sa_store)
            ng = numel(y_sa);
            sa_store  = zeros(ng, Ntrial);
            ode_store = zeros(ng, Ntrial);
            t_ref     = rs.t_grid(:);
        end
        sa_store(:, t)  = y_sa;
        ode_store(:, t) = y_ode;
        E_bank(t) = max(vecnorm(rs.theta_sa - rs.theta_euler, 2, 1));
    end

    sa_mean  = mean(sa_store,  2);
    ode_mean = mean(ode_store, 2);
    sa_sem   = std(sa_store, 0, 2) / sqrt(Ntrial);

    ode = struct();
    ode.E_ODE_mean = mean(E_bank);
    ode.t_ref      = t_ref;
    ode.sa_mean    = sa_mean;
    ode.ode_mean   = ode_mean;

    % ---- Figure G1-A: SA Path vs ODE Backbone -------------------------
    figure('Name','G1-A: Theorem 1 — SA trajectory vs ODE backbone');
    clf;
    xx = t_ref.';
    mu = sa_mean.';
    se = sa_sem.';
    hold on;
    fill([xx fliplr(xx)], [mu-se fliplr(mu+se)], ...
        [0.20 0.45 0.85], 'FaceAlpha', 0.15, 'EdgeColor','none', ...
        'DisplayName', '±1 SE band');
    plot(t_ref, sa_mean,  'b-',  'LineWidth', 1.6, 'DisplayName', 'SA mean (\mu_n\downarrow0)');
    plot(t_ref, ode_mean, 'r--', 'LineWidth', 1.6, 'DisplayName', 'ODE backbone (Theorem 1)');
    grid on;
    xlabel('Algorithmic time t_n');
    ylabel(sprintf('\\theta_%d', theta_idx));
    title({'Theorem 1 — Legitimacy Validation';
           sprintf('E_{ODE}(T) = %.3e  (should \\ to 0 as \\mu\\ \\downarrow\\ 0)', ode.E_ODE_mean)});
    legend('Location', 'best');
    set(gcf,'Position',[100 100 560 300]);

    fprintf('[G1-A] E_ODE = %.4e  |  N_trial = %d\n', ode.E_ODE_mean, Ntrial);
end

% =========================================================================
%  GROUP 1-B  —  PTF RESIDUAL SCALING  (Gap 2: T1-S4)
% =========================================================================
