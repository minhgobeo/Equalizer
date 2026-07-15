% Auto-split from NCKH_v53.m (original line 5736).
% Folder: experiments/theory_legacy

function t1 = run_theorem1_validation_package(cfg, vars, mc)
% ============================================================
% THEOREM 1 VALIDATION PACKAGE
%
% Purpose:
%   - quantify E_ODE(T) under diminishing gains
%   - measure empirical modulus of continuity
%   - provide compactness/subsequence support via end-point spread
% ============================================================

    cfg_ode = cfg;
    cfg_ode.Nsym      = cfg.ode.Nsym;
    cfg_ode.chan_mode = 'frozen_markov_state';
    cfg_ode.SNRdB     = cfg.ode.SNRdB_ode;
    cfg_ode.trainLen  = 0;
    cfg_ode.markov.fixed_state = cfg.markov.fixed_state;

    v = vars.theorem;
    v.mu_mode = 'diminishing';

    decay_list = [2e-3 5e-3 1e-2 2e-2];
    delta_list = [0.02 0.05 0.10];

    E_ode_mean   = zeros(numel(decay_list),1);
    end_spread   = zeros(numel(decay_list),1);
    omega_mean   = zeros(numel(decay_list), numel(delta_list));

    theta0 = mc.ode_init_bank(:, mc.ode.main_init_idx);

    for id = 1:numel(decay_list)
        v.mu0      = cfg.ode.mu0;
        v.mu_decay = decay_list(id);

        E_bank = zeros(mc.Ntrial_ode,1);
        O_bank = zeros(mc.Ntrial_ode, numel(delta_list));
        theta_end_bank = zeros(numel(theta0), mc.Ntrial_ode);

        for t = 1:mc.Ntrial_ode
            seed = 15000 + 100*id + t;
            rs = run_single_ode_trial(cfg_ode, v, theta0, seed);

            % full-state compact-window ODE defect
            E_bank(t) = max(vecnorm(rs.theta_sa - rs.theta_euler, 2, 1));

            % empirical modulus of continuity
            for jd = 1:numel(delta_list)
                O_bank(t,jd) = empirical_modulus_theta(rs.theta_sa, rs.t_grid, delta_list(jd));
            end

            theta_end_bank(:,t) = rs.theta_sa(:,end);
        end

        E_ode_mean(id) = mean(E_bank);
        omega_mean(id,:) = mean(O_bank,1);
        end_spread(id) = mean(std(theta_end_bank, 0, 2));
    end

    t1 = struct();
    t1.decay_list  = decay_list;
    t1.delta_list  = delta_list;
    t1.E_ode_mean  = E_ode_mean;
    t1.omega_mean  = omega_mean;
    t1.end_spread  = end_spread;

    figure('Name','Theorem 1: E_ODE(T) vs annealing rate'); clf;
    semilogy(decay_list, E_ode_mean, 'o-','LineWidth',1.4);
    grid on;
    xlabel('\mu decay');
    ylabel('E_{ODE}(T)');
    title('Theorem 1: compact-window ODE defect');

    figure('Name','Theorem 1: empirical modulus of continuity'); clf;
    hold on;
    for jd = 1:numel(delta_list)
        plot(decay_list, omega_mean(:,jd), 'o-','LineWidth',1.3, ...
            'DisplayName', sprintf('\\delta = %.3f', delta_list(jd)));
    end
    grid on;
    xlabel('\mu decay');
    ylabel('\omega(\delta;T)');
    title('Theorem 1: empirical equicontinuity support');
    legend('Location','best');

    figure('Name','Theorem 1: end-point spread across trials'); clf;
    plot(decay_list, end_spread, 's-','LineWidth',1.4);
    grid on;
    xlabel('\mu decay');
    ylabel('mean std of terminal \theta');
    title('Theorem 1: subsequence/compactness support');

    fprintf('\n=== Theorem 1 validation package ===\n');
    disp(table(decay_list(:), E_ode_mean(:), end_spread(:), ...
        'VariableNames', {'muDecay','E_ODE','terminalSpread'}));
end

