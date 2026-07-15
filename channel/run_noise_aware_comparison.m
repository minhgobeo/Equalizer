% Auto-split from NCKH_v53.m (original line 2735).
% Folder: channel

function rslt = run_noise_aware_comparison(cfg, vars, mc)

    cases = {'theorem','noise_aware','const_global','const_same_floor','const_same_energy'};
    Nc = numel(cases);
    Nsweep_trials = mc.Ntrial_theorem;

    mu_same_floor = calibrate_const_same_floor_mu(cfg, vars.theorem, mc);

    dd_self_floor = zeros(Nc,1);
    param_floor   = zeros(Nc,1);
    dd_bias_proxy = zeros(Nc,1);
    drift_proxy   = zeros(Nc,1);
    p_upd_eff     = zeros(Nc,1);
    ser_dd        = zeros(Nc,1);

    for ic = 1:Nc
        acc_dd = 0; acc_p = 0; acc_B = 0; acc_D = 0; acc_pue = 0; acc_ser = 0;

        for t = 1:Nsweep_trials
            rng(8200 + 100*ic + t);

            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);

            [r_clean, ch_state] = channel_out(d, cfg);
            [r, ~] = add_noise_dispatch(r_clean, cfg);

            vv = build_internal_case_variant(cases{ic}, vars, cfg, mc, mu_same_floor);

            st = proposed_shadow_metrics(r, d, cfg, vv);
            [~, d_hat] = proposed_recursion(r, d, cfg, vv);

            acc_dd  = acc_dd  + st.dd_self_error_floor;
            acc_p   = acc_p   + st.param_floor;
            acc_B   = acc_B   + st.dd_bias_proxy;
            acc_D   = acc_D   + channel_drift_proxy_from_state(ch_state);
            acc_pue = acc_pue + st.p_upd_eff_dd;
            acc_ser = acc_ser + ser_after_training_aligned(d, d_hat, cfg);
        end

        dd_self_floor(ic) = acc_dd  / Nsweep_trials;
        param_floor(ic)   = acc_p   / Nsweep_trials;
        dd_bias_proxy(ic) = acc_B   / Nsweep_trials;
        drift_proxy(ic)   = acc_D   / Nsweep_trials;
        p_upd_eff(ic)     = acc_pue / Nsweep_trials;
        ser_dd(ic)        = acc_ser / Nsweep_trials;
    end

    rslt = struct();
    rslt.cases = cases;
    rslt.dd_self_floor = dd_self_floor;
    rslt.param_floor   = param_floor;
    rslt.dd_bias_proxy = dd_bias_proxy;
    rslt.drift_proxy   = drift_proxy;
    rslt.p_upd_eff     = p_upd_eff;
    rslt.ser_dd        = ser_dd;

    rslt.summary = table(cases(:), dd_self_floor, param_floor, dd_bias_proxy, drift_proxy, p_upd_eff, ser_dd, ...
        'VariableNames', {'Case','ddSelfFloor','paramFloor','ddBiasProxy','driftProxy','pUpdEff','SER'});

    figure('Name','Fig8: Internal fair comparison under severe Markov regime'); clf;
    tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

    nexttile;
    bar(dd_self_floor); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',cases,'XTickLabelRotation',20);
    ylabel('DD self-error floor');
    title('(a) DD floor');

    nexttile;
    bar(ser_dd); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',cases,'XTickLabelRotation',20);
    ylabel('SER');
    title('(b) SER');

    nexttile;
    bar(p_upd_eff); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',cases,'XTickLabelRotation',20);
    ylabel('effective update rate');
    title('(c) Update efficiency');

    disp(rslt.summary);
end

