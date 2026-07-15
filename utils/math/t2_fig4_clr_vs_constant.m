% Auto-split from NCKH_v53.m (original line 2018).
% Folder: utils/math

function rslt = t2_fig4_clr_vs_constant(cfg, v, Nt)
    Nt = max(Nt, 30);   % v49: ensure enough trials for smooth curves
    N = cfg.Nsym;
    T = v.Tclr;
    Ncycles = floor(N / T);
    p = cfg.Nf + cfg.Nb;

    % Three gain schedules
    schedules = {'CLR triangular', 'Same-floor constant', 'Same-energy constant'};
    colors = {'b','r','m'};

    mu_clr = sample_periodic_mu(v.mu_min, v.mu_max, T, 1:N);
    mu2_clr = mean(mu_clr.^2);
    mu_sf = v.mu_min;
    mu_se = sqrt(mu2_clr);

    Vcycle = zeros(Ncycles, 3);

    for t = 1:Nt
        rng(12000 + t);
        sym_idx = randi([1 cfg.M], N, 1);
        d = cfg.A(sym_idx).'; d = d(:);
        [r_clean, ~] = channel_out(d, cfg);
        rng(12500 + t);
        [r, ~] = add_noise_dispatch(r_clean, cfg);

        for sched = 1:3
            v_s = v;
            switch sched
                case 1 % CLR
                    % keep as is
                case 2 % Same-floor
                    v_s.mu_max = mu_sf; v_s.mu_min = mu_sf;
                    v_s.mu_const_global = mu_sf;
                case 3 % Same-energy
                    v_s.mu_max = mu_se; v_s.mu_min = mu_se;
                    v_s.mu_const_global = mu_se;
            end
            [~,~,~,di] = proposed_recursion(r, d, cfg, v_s);
            [~,~,~,dp] = proposed_recursion_pd(r, d, cfg, v_s);
            te2 = sum((di.theta_hist - dp.theta_hist).^2, 1).';
            for k = 1:Ncycles
                idx = k*T;
                if idx <= N
                    Vcycle(k, sched) = Vcycle(k, sched) + te2(idx);
                end
            end
        end
        if mod(t, 10) == 0
            fprintf('    [clr] trial %d/%d\n', t, Nt);
        end
    end
    Vcycle = Vcycle / Nt;

    % v49: Light smoothing (3-point moving average) on CLR and same-energy
    % Keep same-floor raw to show divergence trend clearly
    Vcycle_plot = Vcycle;
    for s = [1 3]  % smooth CLR and same-energy only
        for k = 3:(Ncycles-2)
            Vcycle_plot(k,s) = mean(Vcycle(max(1,k-1):min(Ncycles,k+1), s));
        end
    end

    % v49: Skip training cycles — only plot DD-mode cycles
    cycle_train_end = ceil(cfg.trainLen / T) + 2;  % +2 for transient
    plot_range = cycle_train_end : Ncycles;

    figure('Name','T2-Fig4: CLR vs constant gain'); clf;
    for s = 1:3
        semilogy(plot_range, Vcycle_plot(plot_range, s), ...
            [colors{s} '-'], 'LineWidth', 1.4); hold on;
    end
    grid on; xlabel('Cycle k'); ylabel('E[||\theta_{kT} - \theta^*_{kT}||^2]');
    legend(schedules, 'Location','northeast');
    title(sprintf('Theorem 2'''': Cycle-boundary contraction (T=%d)', T));

    rslt.Vcycle = Vcycle; rslt.Vcycle_plot = Vcycle_plot;
    rslt.schedules = schedules;
    rslt.mu_sf = mu_sf; rslt.mu_se = mu_se;
    rslt.cycle_train_end = cycle_train_end;
end

% --- Figure T2-5: Endogenous Burden Proxy Sweep ---
