% Auto-split from NCKH_v53.m (original line 642).
% Folder: experiments/theory_legacy

function ode_rslt = run_ode_sanity_package(cfg, vars, mc)

    ode_rslt = struct();

    cfg_ode = cfg;
    cfg_ode.Nsym      = cfg.ode.Nsym;
    cfg_ode.chan_mode = 'frozen_markov_state';
    cfg_ode.SNRdB     = cfg.ode.SNRdB_ode;
    cfg_ode.trainLen  = 0;

    v = vars.theorem;
    v.mu_mode = 'diminishing';

    init_bank    = mc.ode_init_bank;
    fixed_states = mc.ode_fixed_states;
    theta_idx    = cfg.ode.plot_theta_idx;
    theta0_main  = init_bank(:, cfg.ode.main_init_idx);

    figure('Name','Fig2: Frozen-state SA vs ODE mean trajectory'); clf;
    tiledlayout(1, numel(fixed_states), 'TileSpacing','compact', 'Padding','compact');

    figure('Name','Appendix: ODE sanity weak-limit support'); clf;
    tiledlayout(numel(fixed_states),2,'TileSpacing','compact','Padding','compact');

    % v49: storage for multi-component figure
    norm_mismatch_all = cell(numel(fixed_states), 1);  % ||SA - ODE||_2 per state
    theta1_sa_all     = cell(numel(fixed_states), 1);  % theta_1 component
    theta1_ode_all    = cell(numel(fixed_states), 1);
    t_ref_all_states  = cell(numel(fixed_states), 1);

    all_rows = [];

    for is = 1:numel(fixed_states)
        cfg_ode.markov.fixed_state = fixed_states(is);

        % -------- main figure using one representative initialization -----
        y_sa_store  = [];
        y_ode_store = [];
        t_ref_main  = [];
        % v49: multi-component stores
        norm_store  = [];   % ||theta_SA - theta_ODE||_2 per trial
        th1_sa_store = [];  % theta_1 component
        th1_ode_store = [];

        for t = 1:mc.Ntrial_ode
            seed = 10000 + 1000*is + t;
            rs = run_single_ode_trial(cfg_ode, v, theta0_main, seed);

            y_sa  = rs.theta_sa(theta_idx,:).';
            y_ode = rs.theta_euler(theta_idx,:).';

            if isempty(y_sa_store)
                ngrid = numel(y_sa);
                y_sa_store  = zeros(ngrid, mc.Ntrial_ode);
                y_ode_store = zeros(ngrid, mc.Ntrial_ode);
                norm_store  = zeros(ngrid, mc.Ntrial_ode);
                th1_sa_store  = zeros(ngrid, mc.Ntrial_ode);
                th1_ode_store = zeros(ngrid, mc.Ntrial_ode);
                t_ref_main  = rs.t_grid(:);
            end

            y_sa_store(:,t)  = y_sa;
            y_ode_store(:,t) = y_ode;
            % v49: full-state norm and theta_1
            norm_store(:,t)    = vecnorm(rs.theta_sa - rs.theta_euler, 2, 1).';
            th1_sa_store(:,t)  = rs.theta_sa(1,:).';
            th1_ode_store(:,t) = rs.theta_euler(1,:).';
        end
        % v49: save for multi-component figure
        norm_mismatch_all{is} = mean(norm_store, 2);
        theta1_sa_all{is}     = mean(th1_sa_store, 2);
        theta1_ode_all{is}    = mean(th1_ode_store, 2);
        t_ref_all_states{is}  = t_ref_main;

       y_sa_mean = mean(y_sa_store, 2);
y_ode_mean = mean(y_ode_store, 2);
y_sa_sem = std(y_sa_store, 0, 2) / sqrt(size(y_sa_store,2));

figure(findobj('Name','Fig2: Frozen-state SA vs ODE mean trajectory'));
nexttile;
hold on;

xx = t_ref_main(:).';
mu = y_sa_mean(:).';
se = y_sa_sem(:).';

fill([xx fliplr(xx)], [mu-se fliplr(mu+se)], ...
     [0.20 0.45 0.85], 'FaceAlpha',0.12, 'EdgeColor','none', ...
     'HandleVisibility','off');

        plot(t_ref_main, y_sa_mean,  'o-', 'LineWidth',1.3, ...
            'DisplayName','SA mean');
        plot(t_ref_main, y_ode_mean, 's--','LineWidth',1.3, ...
            'DisplayName','ODE mean');

        grid on;
        xlabel('algorithmic time $t_n$','Interpreter','latex');
        ylabel(sprintf('$\\theta_{%d}$', theta_idx),'Interpreter','latex');
        title(sprintf('Frozen state %d', fixed_states(is)));
        if is == 1
            legend('Location','best');
        end

        % -------- appendix over all initializations -----------------------
        mismatch_path = [];
        mismatch_term = [];
        y_sa_store_all  = [];
        y_ode_store_all = [];
        t_ref_all = [];

        for ii = 1:size(init_bank,2)
            theta0 = init_bank(:,ii);

            for t = 1:mc.Ntrial_ode
                seed = 20000 + 1000*is + 100*ii + t;
                rs = run_single_ode_trial(cfg_ode, v, theta0, seed);

                y_sa  = rs.theta_sa(theta_idx,:).';
                y_ode = rs.theta_euler(theta_idx,:).';

                if isempty(y_sa_store_all)
                    ngrid = numel(y_sa);
                    nrep  = mc.Ntrial_ode * size(init_bank,2);
                    y_sa_store_all  = zeros(ngrid, nrep);
                    y_ode_store_all = zeros(ngrid, nrep);
                    t_ref_all = rs.t_grid(:);
                end

                kcol = (ii-1)*mc.Ntrial_ode + t;
                y_sa_store_all(:,kcol)  = y_sa;
                y_ode_store_all(:,kcol) = y_ode;

                Ktot = numel(y_sa);
                k0   = max(2, round(0.30*Ktot));
                scale0 = max([range(y_sa), range(y_ode), 1e-8]);

                mismatch_path(end+1,1) = mean(abs(y_sa(k0:end) - y_ode(k0:end))) / scale0; %#ok<AGROW>
                mismatch_term(end+1,1) = abs(y_sa(end) - y_ode(end)) / scale0; %#ok<AGROW>
            end
        end

       y_sa_all_mean = mean(y_sa_store_all,2);
       y_ode_all_mean = mean(y_ode_store_all,2);
       y_sa_all_sem = std(y_sa_store_all,0,2) / sqrt(size(y_sa_store_all,2));

figure(findobj('Name','Appendix: ODE sanity weak-limit support'));

nexttile;
hold on;
xx2 = t_ref_all(:).';
mu2 = y_sa_all_mean(:).';
se2 = y_sa_all_sem(:).';

fill([xx2 fliplr(xx2)], [mu2-se2 fliplr(mu2+se2)], ...
     [0.20 0.45 0.85], 'FaceAlpha',0.12, 'EdgeColor','none', ...
     'HandleVisibility','off');

        plot(t_ref_all, y_sa_all_mean,  'o-', 'LineWidth',1.2, 'DisplayName','SA mean');
        plot(t_ref_all, y_ode_all_mean, 's--','LineWidth',1.2, 'DisplayName','ODE mean');
        grid on;
        xlabel('algorithmic time $t_n$','Interpreter','latex');
        ylabel(sprintf('$\\theta_{%d}$', theta_idx),'Interpreter','latex');
        title(sprintf('Frozen state %d: mean path', fixed_states(is)));
        legend('Location','best');

        nexttile;
        bar([mean(mismatch_path), mean(mismatch_term)]);
        set(gca,'XTick',1:2,'XTickLabel',{'late-path','terminal'});
        ylabel('normalized mismatch');
        title(sprintf('Frozen state %d: mismatch summary', fixed_states(is)));
        grid on;

        Ttmp = table( ...
            repmat(fixed_states(is), numel(mismatch_path), 1), ...
            mismatch_path, mismatch_term, ...
            'VariableNames', {'fixedState','pathMismatchLate','terminalMismatchNorm'});
        all_rows = [all_rows; Ttmp]; %#ok<AGROW>
    end

    ode_rslt.summary_table = all_rows;

    % v49: Figure 3 — Multi-component ODE validation
    % Shows theta_1, theta_2 (existing), and ||SA-ODE||_2 norm for all states
    Ns = numel(fixed_states);
    figure('Name','Fig2b: Multi-component SA vs ODE validation'); clf;
    tiledlayout(2, Ns, 'TileSpacing','compact', 'Padding','compact');

    % Row 1: theta_1 for each frozen state
    for is = 1:Ns
        nexttile;
        plot(t_ref_all_states{is}, theta1_sa_all{is}, 'b-', 'LineWidth', 1.3); hold on;
        plot(t_ref_all_states{is}, theta1_ode_all{is}, 'r--', 'LineWidth', 1.3);
        grid on;
        xlabel('algorithmic time $t_n$','Interpreter','latex');
        ylabel('$\theta_1$','Interpreter','latex');
        title(sprintf('State %d (h_2=%.2f): \\theta_1', ...
            fixed_states(is), cfg.markov.h2_states(fixed_states(is))));
        if is == 1, legend('SA mean','ODE mean','Location','best'); end
    end

    % Row 2: ||SA - ODE||_2 norm for each frozen state
    for is = 1:Ns
        nexttile;
        semilogy(t_ref_all_states{is}, max(norm_mismatch_all{is}, 1e-15), ...
            'b-', 'LineWidth', 1.3);
        grid on;
        xlabel('algorithmic time $t_n$','Interpreter','latex');
        ylabel('$\|\theta_{SA}-\theta_{ODE}\|_2$','Interpreter','latex');
        title(sprintf('State %d: full-state mismatch norm', fixed_states(is)));
    end

    fprintf('\n=== ODE sanity summary ===\n');
    disp(groupsummary(all_rows, 'fixedState', {'mean','std'}, {'pathMismatchLate','terminalMismatchNorm'}));
end


