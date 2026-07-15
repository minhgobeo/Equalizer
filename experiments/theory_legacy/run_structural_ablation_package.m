% Auto-split from NCKH_v53.m (original line 2621).
% Folder: experiments/theory_legacy

function ablt = run_structural_ablation_package(cfg, v_theorem, mc)
    mu_same_floor = calibrate_const_same_floor_mu(cfg, v_theorem, mc);
    cases = {'proposed','no_gate','no_clip','const_same_floor','const_global','const_same_energy'};
    Nc = numel(cases);
    Nsweep_trials = mc.Ntrial_theorem;

    dd_self_floor = zeros(Nc,1);
    oracle_floor  = zeros(Nc,1);
    param_floor   = zeros(Nc,1);
    p_gate        = zeros(Nc,1);
    p_conf        = zeros(Nc,1);
    p_upd_hard    = zeros(Nc,1);
    p_upd_eff     = zeros(Nc,1);
    p_clip        = zeros(Nc,1);
    dd_bias_proxy = zeros(Nc,1);
    mu2bar        = zeros(Nc,1);

    for ic = 1:Nc
        acc_dd = 0; acc_or = 0; acc_param = 0;
        acc_pg = 0; acc_pc = 0; acc_puh = 0; acc_pue = 0; acc_pclip = 0;
        acc_B = 0; acc_mu2 = 0;

        for t = 1:Nsweep_trials
            rng(7000 + 100*ic + t);

            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);

            [r_clean, ~] = channel_out(d, cfg);
            [r, ~] = add_noise_dispatch(r_clean, cfg);

            vv = v_theorem;
            switch cases{ic}
                case 'proposed'
                    % keep theorem baseline
                case 'no_gate'
                    vv.use_hard_confidence_dd = false;
                case 'no_clip'
                    vv.force_no_clip = true;
                case 'const_same_floor'
                    vv = make_constant_gain_version(v_theorem, 'global');
                    vv.mu_const = mu_same_floor;
                case 'const_global'
                    vv = make_constant_gain_version(v_theorem, 'global');
                case 'const_same_energy'
                    vv = make_constant_gain_version(v_theorem, 'same_energy');
                otherwise
                    error('Unknown ablation case');
            end

            st = proposed_shadow_metrics(r, d, cfg, vv);

            acc_dd    = acc_dd    + st.dd_self_error_floor;
            acc_or    = acc_or    + st.oracle_output_floor;
            acc_param = acc_param + st.param_floor;
            acc_pg    = acc_pg    + st.p_gate_dd;
            acc_pc    = acc_pc    + st.p_conf_dd;
            acc_puh   = acc_puh   + st.p_upd_hard_dd;
            acc_pue   = acc_pue   + st.p_upd_eff_dd;
            acc_pclip = acc_pclip + st.p_clip_dd;
            acc_B     = acc_B     + st.dd_bias_proxy;
            acc_mu2   = acc_mu2   + st.mu2bar;
        end

        dd_self_floor(ic) = acc_dd / Nsweep_trials;
        oracle_floor(ic)  = acc_or / Nsweep_trials;
        param_floor(ic)   = acc_param / Nsweep_trials;
        p_gate(ic)        = acc_pg / Nsweep_trials;
        p_conf(ic)        = acc_pc / Nsweep_trials;
        p_upd_hard(ic)    = acc_puh / Nsweep_trials;
        p_upd_eff(ic)     = acc_pue / Nsweep_trials;
        p_clip(ic)        = acc_pclip / Nsweep_trials;
        dd_bias_proxy(ic) = acc_B / Nsweep_trials;
        mu2bar(ic)        = acc_mu2 / Nsweep_trials;
    end

    ablt = struct();
    ablt.cases = cases;
    ablt.dd_self_floor = dd_self_floor;
    ablt.oracle_floor  = oracle_floor;
    ablt.param_floor   = param_floor;
    ablt.p_gate        = p_gate;
    ablt.p_conf        = p_conf;
    ablt.p_upd_hard    = p_upd_hard;
    ablt.p_upd_eff     = p_upd_eff;
    ablt.p_clip        = p_clip;
    ablt.dd_bias_proxy = dd_bias_proxy;
    ablt.mu2bar        = mu2bar;

    figure('Name',['Theorem: Structural Ablations - ' cfg.chan_mode]); clf;
    tiledlayout(3,2,'TileSpacing','compact','Padding','compact');

    nexttile; bar(dd_self_floor); grid on; title('DD self-error floor'); xtickangle(20);
    set(gca,'XTick',1:Nc,'XTickLabel',cases);

    nexttile; bar(param_floor); grid on; title('PD-reference tracking proxy'); xtickangle(20);
    set(gca,'XTick',1:Nc,'XTickLabel',cases);

    nexttile; bar(p_upd_hard); grid on; title('p_{upd}^{hard}'); xtickangle(20);
    set(gca,'XTick',1:Nc,'XTickLabel',cases);

    nexttile; bar(p_upd_eff); grid on; title('p_{upd}^{eff}'); xtickangle(20);
    set(gca,'XTick',1:Nc,'XTickLabel',cases);

    nexttile; bar(dd_bias_proxy); grid on; title('DD-bias proxy'); xtickangle(20);
    set(gca,'XTick',1:Nc,'XTickLabel',cases);

    nexttile; bar(mu2bar); grid on; title('\mu^2 energy proxy'); xtickangle(20);
    set(gca,'XTick',1:Nc,'XTickLabel',cases);

    disp(table(cases(:), dd_self_floor, oracle_floor, param_floor, p_gate, p_conf, p_upd_hard, p_upd_eff, p_clip, dd_bias_proxy, mu2bar, ...
        'VariableNames', {'Case','ddSelfFloor','oracleFloor','paramFloor','pGate','pConf','pUpdHard','pUpdEff','pClip','ddBiasProxy','mu2bar'}));
end

