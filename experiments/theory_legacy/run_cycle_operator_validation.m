% Auto-split from NCKH_v53.m (original line 5843).
% Folder: experiments/theory_legacy

function cyc = run_cycle_operator_validation(cfg, v_theorem, mc)
% ============================================================
% THEOREM 2 CYCLE-LOCAL VALIDATION
%
% Purpose:
%   - validate cycle-boundary contraction under periodic triangular gain
%   - compare theorem / same-floor / same-energy at cycle boundaries
% ============================================================

    cfg_c = cfg;
    cfg_c.chan_mode = 'frozen_markov_state';
    cfg_c.markov.fixed_state = cfg.markov.fixed_state;
    cfg_c.SNRdB = 20;
    cfg_c.trainLen = 800;

    Tcyc = v_theorem.Tclr;
    Kcyc = 8;
    cfg_c.Nsym = cfg_c.trainLen + (Kcyc + 2) * Tcyc;

    cases = {'theorem','const_same_floor','const_same_energy'};
    Nc = numel(cases);

    cycle_err_mean = zeros(Kcyc, Nc);
    ratio_mean     = zeros(Nc,1);

    for ic = 1:Nc
        err_bank = zeros(Kcyc, mc.Ntrial_theorem);
        ratio_bank = zeros(Kcyc-1, mc.Ntrial_theorem);

        for t = 1:mc.Ntrial_theorem
            rng(17000 + 100*ic + t);

            sym_idx = randi([1 cfg_c.M], cfg_c.Nsym, 1);
            d = cfg_c.A(sym_idx).'; d = d(:);

            [r_clean, ~] = channel_out(d, cfg_c);
            [r, ~] = add_noise_dispatch(r_clean, cfg_c);

            switch cases{ic}
                case 'theorem'
                    vv = v_theorem;
                case 'const_same_floor'
                    vv = make_constant_gain_version(v_theorem, 'same_floor');
                case 'const_same_energy'
                    vv = make_constant_gain_version(v_theorem, 'same_energy');
                otherwise
                    error('Unknown cycle-validation case.');
            end

            [~,~,~,diag_impl] = proposed_recursion(r, d, cfg_c, vv);
            [~,~,~,diag_pd]   = proposed_recursion_pd(r, d, cfg_c, vv);

            idx_cycle = cfg_c.trainLen + (1:Kcyc)*Tcyc;
            idx_cycle = idx_cycle(idx_cycle <= cfg_c.Nsym);

            ecyc = zeros(numel(idx_cycle),1);
            for k = 1:numel(idx_cycle)
                ii = idx_cycle(k);
                ecyc(k) = sum((diag_impl.theta_hist(:,ii) - diag_pd.theta_hist(:,ii)).^2);
            end

            err_bank(1:numel(ecyc), t) = ecyc(:);

            if numel(ecyc) >= 2
                ratio_bank(1:numel(ecyc)-1, t) = ecyc(2:end) ./ max(ecyc(1:end-1), 1e-12);
            end
        end

        cycle_err_mean(:,ic) = mean(err_bank,2);
        ratio_mean(ic)       = mean(ratio_bank(:));
    end

    cyc = struct();
    cyc.cases = cases;
    cyc.cycle_err_mean = cycle_err_mean;
    cyc.ratio_mean = ratio_mean;

    figure('Name','Theorem 2: cycle-boundary contraction'); clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    nexttile;
    hold on;
    for ic = 1:Nc
        semilogy(1:Kcyc, max(cycle_err_mean(:,ic),1e-12), 'o-','LineWidth',1.4, ...
            'DisplayName', cases{ic});
    end
    grid on;
    xlabel('cycle index');
    ylabel('cycle-boundary tracking proxy');
    title('(a) Cycle-boundary error');
    legend('Location','best');

    nexttile;
    bar(ratio_mean);
    set(gca,'XTick',1:Nc,'XTickLabel',cases,'XTickLabelRotation',20);
    grid on;
    ylabel('mean cycle ratio');
    title('(b) Mean contraction ratio');

    fprintf('\n=== Theorem 2 cycle-local validation ===\n');
    disp(table(cases(:), ratio_mean, 'VariableNames', {'Case','MeanCycleRatio'}));
end

