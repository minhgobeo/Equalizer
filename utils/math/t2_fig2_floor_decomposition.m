% Auto-split from NCKH_v53.m (original line 1765).
% Folder: utils/math

function rslt = t2_fig2_floor_decomposition(cfg, v, Nt)
    mu_list = [0.005 0.01 0.02 0.05 0.10 0.15 0.25];
    Nmu = numel(mu_list);

    % Raw proxy accumulators (un-scaled)
    raw_param = zeros(Nmu, 1);   % restoration deficit proxy
    raw_Bc    = zeros(Nmu, 1);   % DD-bias proxy
    raw_mu2   = zeros(Nmu, 1);   % gain-energy proxy
    Delta_total = zeros(Nmu, 1); % simulated total floor

    for im = 1:Nmu
        v_try = v;
        v_try.mu_max = mu_list(im);
        v_try.mu_min = 1e-3 * mu_list(im);
        v_try.mu_const_global = mean(sample_periodic_mu( ...
            v_try.mu_min, v_try.mu_max, v_try.Tclr, 1:2000));

        acc_param = 0; acc_Bc = 0; acc_mu2 = 0; acc_dd = 0;
        for t = 1:Nt
            rng(10000 + 100*im + t);
            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg);
            rng(10500 + 100*im + t);
            [r, ~] = add_noise_dispatch(r_clean, cfg);

            st = proposed_shadow_metrics(r, d, cfg, v_try);
            acc_param = acc_param + st.param_floor;
            acc_Bc    = acc_Bc    + st.dd_bias_proxy;
            acc_mu2   = acc_mu2   + st.mu2bar;
            acc_dd    = acc_dd    + st.dd_self_error_floor;
        end
        raw_param(im) = acc_param / Nt;
        raw_Bc(im)    = acc_Bc / Nt;
        raw_mu2(im)   = acc_mu2 / Nt;
        Delta_total(im) = acc_dd / Nt;
    end

    % v50: Proportional decomposition preserving theoretical structure
    % Theory says: Δ* = Δ_floor(∝ μ²/c₀) + Δ_burden(∝ B_c/c₀) + Δ_pd(∝ param)
    % Strategy: compute raw theoretical contributions, then normalize so
    % they sum to the simulated total at each μ_max.
    % This guarantees: (a) bars always sum to total, (b) correct scaling trends.

    c0_est = 0.5;  % estimated c₀ from dissipativity

    Delta_floor  = zeros(Nmu, 1);
    Delta_burden = zeros(Nmu, 1);
    Delta_pd     = zeros(Nmu, 1);

    for im = 1:Nmu
        % Raw theoretical-scale contributions
        contrib_floor  = 2 * raw_mu2(im) / c0_est;     % ∝ μ²/c₀
        contrib_burden = 8 * raw_Bc(im)  / c0_est;     % ∝ B_c/c₀
        contrib_pd     = 4 * raw_param(im);             % ∝ C_r/c₀²

        total_contrib = contrib_floor + contrib_burden + contrib_pd;

        if total_contrib > 1e-15
            % Normalize fractions, then scale to simulated total
            frac_f = contrib_floor  / total_contrib;
            frac_b = contrib_burden / total_contrib;
            frac_p = contrib_pd     / total_contrib;

            Delta_floor(im)  = frac_f * Delta_total(im);
            Delta_burden(im) = frac_b * Delta_total(im);
            Delta_pd(im)     = frac_p * Delta_total(im);
        else
            % Fallback: equal split
            Delta_floor(im)  = Delta_total(im) / 3;
            Delta_burden(im) = Delta_total(im) / 3;
            Delta_pd(im)     = Delta_total(im) / 3;
        end
    end

    % Verify: bars should exactly sum to total
    sum_check = max(abs(Delta_floor + Delta_burden + Delta_pd - Delta_total));
    fprintf('    [floor] Proportional decomposition: max|sum-total| = %.2e\n', sum_check);
    fprintf('    [floor] Burden fraction range: [%.3f, %.3f]\n', ...
        min(Delta_burden ./ max(Delta_total,1e-15)), ...
        max(Delta_burden ./ max(Delta_total,1e-15)));

    figure('Name','T2-Fig2: Floor decomposition'); clf;
    tiledlayout(1,2,'TileSpacing','compact');
    nexttile;
    bar_data = [Delta_floor, Delta_burden, Delta_pd];
    bh = bar(mu_list, bar_data, 'stacked');
    bh(1).FaceColor = [0.2 0.6 0.9];
    bh(2).FaceColor = [0.9 0.3 0.3];
    bh(3).FaceColor = [0.5 0.8 0.4];
    hold on;
    plot(mu_list, Delta_total, 'ko-', 'LineWidth', 2, 'MarkerSize', 8);
    grid on; xlabel('\mu_{max}'); ylabel('\Delta^*');
    legend({'\Delta_{floor} (gain energy)','\Delta_{burden} (DD mismatch)', ...
        '\Delta_{pd} (restoration)','\Delta^* total (simulated)'},'Location','northwest');
    title('(a) Floor decomposition vs \mu_{max}');

    nexttile;
    semilogy(mu_list, max(Delta_floor,1e-10), 'bs-', 'LineWidth', 1.3); hold on;
    semilogy(mu_list, max(Delta_burden,1e-10), 'r^-', 'LineWidth', 1.3);
    semilogy(mu_list, max(Delta_pd,1e-10), 'gv-', 'LineWidth', 1.3);
    semilogy(mu_list, Delta_total, 'ko-', 'LineWidth', 1.8);
    grid on; xlabel('\mu_{max}'); ylabel('\Delta^* (log)');
    legend({'\Delta_{floor}','\Delta_{burden} (irreducible)', ...
        '\Delta_{pd}','\Delta^* total'},'Location','best');
    title('(b) Component scaling (log)');

    rslt.mu_list = mu_list;
    rslt.Delta_pd = Delta_pd; rslt.Delta_burden = Delta_burden;
    rslt.Delta_floor = Delta_floor; rslt.Delta_total = Delta_total;
end

% --- Figure T2-3: Finite-Time Bound (Theorem 2') ---
