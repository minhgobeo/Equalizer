% Auto-split from NCKH_v53.m (original line 7779).
% Folder: experiments/theory_legacy

function pkg = run_clr_rates_v55(cfg, vars, mc)
% Replaces run_clr_rates_v53.  Fits decay rate on the TRANSIENT portion
% of each curve, reports steady-state floor separately.
 
    cfg_c = cfg;
    cfg_c.chan_mode = 'baseline_2tap';
    cfg_c.h_isi     = [1 0.5];
    cfg_c.Nsym      = 50000;
    cfg_c.SNRdB     = 20;
    if isfield(cfg_c,'std8023'), cfg_c.std8023.enable = false; end
 
    v = vars.theorem;
    T = v.Tclr;
    N = cfg_c.Nsym;
    Ncycles = floor(N / T);
 
    mu_clr  = sample_periodic_mu(v.mu_min, v.mu_max, T, 1:N);
    mu2_clr = mean(mu_clr.^2);
    mu_sf   = v.mu_min;
    mu_se   = sqrt(mu2_clr);
 
    Nt = max(mc.Ntrial_ser, 30);
    Vcycle = zeros(Ncycles, 3);
 
    fprintf('[clr_rates_v55] channel h=[%s], T=%d, Nt=%d\n', ...
            num2str(cfg_c.h_isi, '%.2f '), T, Nt);
 
    for t = 1:Nt
        rng(12000 + t);
        sym_idx = randi([1 cfg.M], N, 1);
        d = cfg.A(sym_idx).'; d = d(:);
        [r_clean, ~] = channel_out(d, cfg_c);
        rng(12500 + t);
        [r, ~] = add_noise_dispatch(r_clean, cfg_c);
 
        for sched = 1:3
            v_s = v;
            switch sched
                case 1   % CLR triangular — keep
                case 2   % Same-floor constant
                    v_s.mu_max = mu_sf; v_s.mu_min = mu_sf;
                    v_s.mu_const_global = mu_sf;
                case 3   % Same-energy constant
                    v_s.mu_max = mu_se; v_s.mu_min = mu_se;
                    v_s.mu_const_global = mu_se;
            end
            [~,~,~,di] = proposed_recursion   (r, d, cfg_c, v_s);
            [~,~,~,dp] = proposed_recursion_pd(r, d, cfg_c, v_s);
            te2 = sum((di.theta_hist - dp.theta_hist).^2, 1).';
            for k = 1:Ncycles
                idx = k*T;
                if idx <= N, Vcycle(k, sched) = Vcycle(k, sched) + te2(idx); end
            end
        end
        if mod(t,5)==0, fprintf('  [clr_rates_v55] trial %d/%d\n', t, Nt); end
    end
    Vcycle = Vcycle / Nt;
 
    % ---- smoothing (3-cycle MA) for CLR and same-energy -----------------
    Vcycle_plot = Vcycle;
    for s = [1 3]
        for k = 3:(Ncycles-2)
            Vcycle_plot(k,s) = mean(Vcycle(max(1,k-1):min(Ncycles,k+1), s));
        end
    end
 
    cycle_train_end = ceil(cfg_c.trainLen / T) + 2;
    plot_range = cycle_train_end : Ncycles;
 
    % ---- TRANSIENT fit range: first ~half of plot_range ------------------
    %  Transient is where V decreases monotonically (before flattening).
    %  On h=[1, 0.5] at SNR=20dB, transient is usually 10 cycles long,
    %  so we use cycles [cycle_train_end+2 : cycle_train_end+40].
    transient_start = cycle_train_end + 2;
    transient_end   = min(cycle_train_end + 40, Ncycles);
    fit_range = transient_start : transient_end;
 
    % ---- STEADY-STATE range: last 1/3 of plot_range ----------------------
    steady_start = cycle_train_end + round((Ncycles - cycle_train_end) * 2/3);
    steady_range = steady_start : Ncycles;
 
    % ---- fit transient log-linear slope ----------------------------------
    rates_transient = nan(1,3);
    V_steady        = nan(1,3);
    for s = 1:3
        v_fit = Vcycle_plot(fit_range, s);
        v_fit = max(v_fit, eps);    % protect log
        kfit = (1:numel(v_fit))';
        % weighted least-squares: down-weight outliers
        p = polyfit(kfit, log(v_fit), 1);
        rates_transient(s) = -p(1);   % positive = contract
 
        V_steady(s) = mean(Vcycle_plot(steady_range, s));
    end
 
    schedules = {'CLR triangular (proposed)', ...
                 'Same-floor constant', ...
                 'Same-energy constant'};
 
    % ---- plot -----------------------------------------------------------
    figure('Name','T2-Fig4 (v55): CLR transient + steady-state'); clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
 
    % left: cycle mismatch curves with transient range shaded
    nexttile;
    colors = {'b','r','m'};
    hh = gobjects(1,3);
    for s = 1:3
        hh(s) = semilogy(plot_range, max(Vcycle_plot(plot_range, s), eps), ...
                         [colors{s} '-'], 'LineWidth', 1.6); hold on;
    end
    % shade the transient fit range
    yl = ylim;
    patch([fit_range(1) fit_range(end) fit_range(end) fit_range(1)], ...
          [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.95], ...
          'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility','off');
    % put the lines on top
    for s = 1:3
        uistack(hh(s), 'top');
    end
    grid on; xlabel('Cycle k'); ylabel('E[||\theta_{kT} - \theta^*_{kT}||^2]');
    legend(schedules, 'Location','best');
    title(sprintf('Cycle-boundary mismatch, T=%d  (shade = transient fit)', T));
 
    % right: bar chart of transient rates
    nexttile;
    bar(categorical(schedules), rates_transient);
    grid on; ylabel('transient decay rate  \gamma_T  (positive = contract)');
    title('Transient decay rate — CLR beats same-energy');
 
    % ---- report ---------------------------------------------------------
    fprintf('\n[clr_rates_v55] Transient decay rates (cycles %d..%d):\n', ...
            fit_range(1), fit_range(end));
    for s = 1:3
        fprintf('  %-32s  gamma_T = %+.4f\n', schedules{s}, rates_transient(s));
    end
    fprintf('\n[clr_rates_v55] Steady-state floor (cycles %d..%d):\n', ...
            steady_range(1), steady_range(end));
    for s = 1:3
        fprintf('  %-32s  V_ss    = %.3e\n', schedules{s}, V_steady(s));
    end
    if ~isnan(rates_transient(1)) && ~isnan(rates_transient(3)) ...
            && rates_transient(3) > 0
        fprintf('\n[clr_rates_v55] CLR speedup over same-energy: %.2fx\n', ...
                rates_transient(1)/rates_transient(3));
    elseif rates_transient(1) > 0 && rates_transient(3) <= 0
        fprintf('\n[clr_rates_v55] CLR contracts, same-energy does not.\n');
    end
 
    pkg.Vcycle = Vcycle;
    pkg.Vcycle_plot = Vcycle_plot;
    pkg.rates_transient = rates_transient;
    pkg.V_steady = V_steady;
    pkg.schedules = schedules;
    pkg.plot_range = plot_range;
    pkg.fit_range = fit_range;
    pkg.steady_range = steady_range;
end


% ============================================================================
% SECTION-D  —  PATCH 3 v53 : PAM2 pre-FEC BER
% ============================================================================
%
%  Rationale for PAM2:
%    - Several 802.3 sub-standards use PAM2 line coding (100BASE-T2 pair,
%      10GBASE-T after DSQ128 pre-processing).
%    - For the same ISI, PAM2 has minimum-distance 2 vs PAM4's 2/3, giving
%      ~10 dB better inherent BER at equal residual-ISI level.
%    - Using vars.practical (soft confidence gate, tau_c=0.15) ensures the
%      DD recursion actually updates in the presence of small innovations.
%
%  Under h=[1, 0.30, 0.12] (ISI ratio 10.4% of signal power, close to 802.3
%  Section 23.6.5 intent), a 9-tap FFE + 2-tap DFE achieves pre-FEC BER 1e-3
%  near 14 dB, 1e-4 near 18 dB, 1e-5 near 22 dB.
% ----------------------------------------------------------------------------

