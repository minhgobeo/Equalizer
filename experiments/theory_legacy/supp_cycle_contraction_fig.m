% Auto-split from NCKH_v53.m (original line 6651).
% Folder: experiments/theory_legacy

function cyc = supp_cycle_contraction_fig(cfg, vars, mc)
% Validates Corollary 2: cycle-boundary contraction (1-gamma_T)^k
% Comparison: proposed triangular vs constant gain (same-floor, same-energy)

    cfg_c                      = cfg;
    cfg_c.chan_mode             = 'frozen_markov_state';
    cfg_c.markov.fixed_state   = cfg.markov.fixed_state;
    cfg_c.SNRdB                = 20;
    cfg_c.trainLen             = 800;

    v    = vars.theorem;
    Tcyc = v.Tclr;
    Kcyc = 10;
    cfg_c.Nsym = cfg_c.trainLen + (Kcyc + 2) * Tcyc;

    cases    = {'triangular\_CLR','same\_floor','same\_energy'};
    labels   = {'Triangular CLR (proposed)','Same-floor const','Same-energy const'};
    colors   = {'b','r','g'};
    markers  = {'o','^','s'};
    Nc       = numel(cases);
    Nsweep   = mc.Ntrial_theorem;

    cycle_err_mean = zeros(Kcyc, Nc);
    cycle_err_std  = zeros(Kcyc, Nc);
    ratio_mean     = zeros(Nc, 1);
    gamma_T_fit    = zeros(Nc, 1);  % fitted contraction rate

    for ic = 1:Nc
        err_bank = zeros(Kcyc, Nsweep);

        for t = 1:Nsweep
            rng(57000 + 100*ic + t);
            sym_idx = randi([1 cfg_c.M], cfg_c.Nsym, 1);
            d       = cfg_c.A(sym_idx).'; d = d(:);
            [r_clean,~] = channel_out(d, cfg_c);
            [r,~]       = add_noise_dispatch(r_clean, cfg_c);

            switch ic
                case 1, vv = v;
                case 2, vv = make_constant_gain_version(v, 'same_floor');
                case 3, vv = make_constant_gain_version(v, 'same_energy');
            end

            [~,~,~,di] = proposed_recursion(r, d, cfg_c, vv);
            [~,~,~,dp] = proposed_recursion_pd(r, d, cfg_c, vv);

            idx_cycle = cfg_c.trainLen + (1:Kcyc)*Tcyc;
            idx_cycle = idx_cycle(idx_cycle <= cfg_c.Nsym);

            for k = 1:numel(idx_cycle)
                ii = idx_cycle(k);
                err_bank(k,t) = sum((di.theta_hist(:,ii) - dp.theta_hist(:,ii)).^2);
            end
        end

        cycle_err_mean(:,ic) = mean(err_bank, 2);
        cycle_err_std(:,ic)  = std(err_bank,  0, 2);

        % Fit geometric decay: err(k) ~ A * (1-gamma_T)^k
        ek = cycle_err_mean(2:end, ic);
        ek_prev = cycle_err_mean(1:end-1, ic);
        valid = ek > 1e-14 & ek_prev > 1e-14;
        if any(valid)
            eps_cyc = 1e-8;
            ratios = (ek(valid) + eps_cyc) ./ (ek_prev(valid) + eps_cyc);
            ratios = ratios(isfinite(ratios));

        if numel(ratios) >= 2
            ratios = ratios(2:end);
        end

        if ~isempty(ratios)
            ratio_mean(ic)  = median(ratios);
            gamma_T_fit(ic) = 1 - median(ratios);
        end
        
        end
    end

    cyc = struct();
    cyc.cases          = cases;
    cyc.cycle_err_mean = cycle_err_mean;
    cyc.cycle_err_std  = cycle_err_std;
    cyc.ratio_mean     = ratio_mean;
    cyc.gamma_T_fit    = gamma_T_fit;

    % ---- Figure G3-A: cycle-boundary error curves ----------------------
    figure('Name','G3-A: Corollary 2 — Cycle-Boundary Contraction');
    clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    nexttile;
    hold on;
    k_ax = 1:Kcyc;
    for ic = 1:Nc
        mu_e = cycle_err_mean(:,ic);
        sd_e = cycle_err_std(:,ic);
        fill([k_ax fliplr(k_ax)], [max(mu_e-sd_e,1e-15)' fliplr((mu_e+sd_e)')], ...
            colors{ic}, 'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
        semilogy(k_ax, max(mu_e, 1e-15), [colors{ic} markers{ic} '-'], ...
            'LineWidth',1.6,'MarkerSize',6,'DisplayName', labels{ic});

        % overlay fitted geometric decay
        if gamma_T_fit(ic) > 0
            k_fit = 0:(Kcyc-1);
            fitted = cycle_err_mean(1,ic) * (1-gamma_T_fit(ic)).^k_fit;
            semilogy(k_ax, fitted, [colors{ic} ':'], 'LineWidth',1.0,...
                'HandleVisibility','off');
        end
    end
    grid on;
    xlabel('Cycle boundary index k');
    ylabel('cycle-boundary mismatch energy');
    title('(a) Cycle-boundary mismatch decay');
    legend('Location','northeast','FontSize',8);

    nexttile;
    bar(gamma_T_fit);
    set(gca,'XTick',1:Nc,'XTickLabel',labels,'XTickLabelRotation',20);
    grid on;
    ylabel('\gamma_T  (fitted contraction rate)');
    title({'(b) Fitted cycle mismatch-decay rate';
           'Larger values indicate faster empirical decay'});

    set(gcf,'Position',[100 100 720 320]);

    fprintf('[G3-A] Contraction rates: triangular=%.4f, SF=%.4f, SE=%.4f\n', ...
        gamma_T_fit(1), gamma_T_fit(2), gamma_T_fit(3));
end

% =========================================================================
%  GROUP 4  —  COMPARISON WITH 2024 SM-SIGN-NLMS (KEY FIGURE)
% =========================================================================
