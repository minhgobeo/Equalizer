% Auto-split from NCKH_v53.m (original line 6483).
% Folder: experiments/theory_legacy

function irred = supp_irreducibility(cfg, vars, mc)
% CRITICAL: Shows Δ_burden is IRREDUCIBLE (nonzero as mu→0)
% This is the key novelty vs exogenous-noise papers (2024 SM-sign-NLMS)
% where the floor → 0 as mu → 0.

    mu_max_list = [0.070, 0.050, 0.030, 0.015, 0.007, 0.003, 0.001];
    Nsweep      = mc.Ntrial_theorem;

    param_floor_dd     = zeros(numel(mu_max_list), 1);  % proposed DD
    dd_bias_proxy      = zeros(numel(mu_max_list), 1);
    param_floor_oracle = zeros(numel(mu_max_list), 1);  % oracle (b_c=0)
    mu2bar_dd          = zeros(numel(mu_max_list), 1);

    for ii = 1:numel(mu_max_list)
        acc_param_dd  = 0;
        acc_bias      = 0;
        acc_param_or  = 0;
        acc_mu2       = 0;

        for t = 1:Nsweep
            rng(19000 + 100*ii + t);
            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);
            [r_clean,~] = channel_out(d, cfg);
            [r,~]       = add_noise_dispatch(r_clean, cfg);

            % DD version (endogenous contamination present)
            vv_dd         = vars.theorem;
            vv_dd.mu_max  = mu_max_list(ii);
            vv_dd.mu_min  = max(mu_max_list(ii) * 0.001, 1e-6);

            % Oracle version (perfect-decision, b_c ≡ 0)
            vv_or         = vars.theorem;
            vv_or.mu_max  = mu_max_list(ii);
            vv_or.mu_min  = max(mu_max_list(ii) * 0.001, 1e-6);

            st_dd = proposed_shadow_metrics(r, d, cfg, vv_dd);

            % Oracle = PD recursion floor
            [~,~,~,diag_pd] = proposed_recursion_pd(r, d, cfg, vv_or);
            N  = numel(r);
            nn = (1:N).';
            mm = nn - cfg.D;
            dd_mask = (mm >= (cfg.trainLen+1)) & (mm <= cfg.Nsym);
            % oracle floor: distance of PD recursion from itself (zero by def)
            % so use the oracle directly as convergence measure
            theta_pd_fin = diag_pd.theta_hist(:, find(dd_mask, 1, 'last'));
            param_or_t   = mean(sum((diag_pd.theta_hist(:,dd_mask) - ...
                               repmat(theta_pd_fin, 1, sum(dd_mask))).^2, 1));

            acc_param_dd = acc_param_dd + st_dd.param_floor;
            acc_bias     = acc_bias     + st_dd.dd_bias_proxy;
            acc_param_or = acc_param_or + param_or_t;
            acc_mu2      = acc_mu2      + st_dd.mu2bar;
        end

        param_floor_dd(ii)     = acc_param_dd / Nsweep;
        dd_bias_proxy(ii)      = acc_bias     / Nsweep;
        param_floor_oracle(ii) = acc_param_or / Nsweep;
        mu2bar_dd(ii)          = acc_mu2      / Nsweep;
    end

    irred = struct();
    irred.mu_max_list        = mu_max_list;
    irred.param_floor_dd     = param_floor_dd;
    irred.dd_bias_proxy      = dd_bias_proxy;
    irred.param_floor_oracle = param_floor_oracle;
    irred.mu2bar_dd          = mu2bar_dd;

    % ---- Figure G2-A: Irreducibility of Δ_burden ----------------------
    figure('Name','G2-A: Theorem 2 — Irreducibility of Endogenous Burden');
    clf;
    loglog(mu_max_list, param_floor_dd,     'bo-', 'LineWidth',1.6, ...
        'MarkerSize',7, 'DisplayName','DD floor  \Delta^* (proposed)');
    hold on;
    loglog(mu_max_list, dd_bias_proxy,      'rs--','LineWidth',1.4, ...
        'MarkerSize',6, 'DisplayName','DD-bias proxy \hat{B}_c');
    loglog(mu_max_list, mu2bar_dd,          'gd:','LineWidth',1.2, ...
        'MarkerSize',5, 'DisplayName','\mu^2 diffusion floor');
    loglog(mu_max_list, param_floor_oracle, 'k^-.','LineWidth',1.2, ...
        'MarkerSize',5, 'DisplayName','Oracle floor (b_c \equiv 0)');

    % draw horizontal asymptote to show floor leveling off
    bias_level = mean(dd_bias_proxy(end-2:end));
    yline(bias_level, 'm:', 'LineWidth',1.5, ...
        'DisplayName', sprintf('Irreducible floor \approx %.2e', bias_level));

    grid on;
    xlabel('\mu_{max}');
    ylabel('Floor metric');
    title({'\bf Irreducibility of Endogenous DD Burden \Delta_{burden}';
           'DD floor \to nonzero as \mu_{max}\to0  (unlike exogenous algorithms)'});
    legend('Location','best','FontSize',8);
    set(gcf,'Position',[100 100 620 360]);

    % ---- Figure G2-A inset: comparison bar at smallest mu --------------
    figure('Name','G2-A inset: Floor breakdown at smallest mu');
    clf;
    bar_data = [param_floor_dd(end), dd_bias_proxy(end), mu2bar_dd(end), param_floor_oracle(end)];
    bar(bar_data);
    set(gca,'XTickLabel',{'\Delta^* (DD)','B_c proxy','\mu^2 diffusion','Oracle'},...
        'XTickLabelRotation',15);
    ylabel('Floor value at \mu_{max} = 0.001');
    title('Burden breakdown: endogenous B_c dominates at low gain');
    grid on;
    set(gcf,'Position',[100 100 480 280]);

    fprintf('[G2-A] Irreducibility check at mu_max=%.3f: param_floor=%.3e, Bc=%.3e, mu2=%.3e\n', ...
        mu_max_list(end), param_floor_dd(end), dd_bias_proxy(end), mu2bar_dd(end));
end

% =========================================================================
%  GROUP 2-B  —  GAIN-ENERGY FORMULA VERIFICATION  (Gap 5)
% =========================================================================
