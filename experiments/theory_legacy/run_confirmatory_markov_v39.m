% Auto-split from NCKH_v53.m (original line 4822).
% Folder: experiments/theory_legacy

function T = run_confirmatory_markov_v39(cfg, vars, mc)
    cfg_m = cfg;
    cfg_m.chan_mode = 'markov_2tap';

    cases = {'theorem','noise_aware','const_global','const_same_energy'};
    Nc = numel(cases);

    paramFloor_markov = zeros(Nc,1);
    ddBias_markov     = zeros(Nc,1);
    pUpdEff_markov    = zeros(Nc,1);
    muScaleMean       = zeros(Nc,1);
    muScaleStd        = zeros(Nc,1);
    muSatMax          = zeros(Nc,1);

    for ic = 1:Nc
        acc_pf  = 0;
        acc_b   = 0;
        acc_pu  = 0;
        acc_mm  = 0;
        acc_ms  = 0;
        acc_sat = 0;

        for t = 1:mc.Ntrial_theorem
            rng(51000 + 100*ic + t);

            sym_idx = randi([1 cfg_m.M], cfg_m.Nsym, 1);
            d = cfg_m.A(sym_idx).'; d = d(:);

            [r_clean, ~] = channel_out(d, cfg_m);
            [r, ~] = add_noise_dispatch(r_clean, cfg_m);

            switch cases{ic}
                case 'theorem'
                    vv = vars.theorem;
                case 'noise_aware'
                    vv = vars.noise_aware;
                case 'const_global'
                    vv = make_constant_gain_version(vars.theorem, 'global');
                case 'const_same_energy'
                    vv = make_constant_gain_version(vars.theorem, 'same_energy');
                otherwise
                    error('Unknown confirmatory case in run_confirmatory_markov_v39.');
            end

            st = proposed_shadow_metrics_muaware_v35(r, d, cfg_m, vv);

            acc_pf  = acc_pf  + st.param_floor;
            acc_b   = acc_b   + st.dd_bias_proxy;
            acc_pu  = acc_pu  + st.p_upd_eff_dd;
            acc_mm  = acc_mm  + st.mu_scale_mean;
            acc_ms  = acc_ms  + st.mu_scale_std;
            acc_sat = acc_sat + st.mu_scale_sat_max;
        end

        paramFloor_markov(ic) = acc_pf  / mc.Ntrial_theorem;
        ddBias_markov(ic)     = acc_b   / mc.Ntrial_theorem;
        pUpdEff_markov(ic)    = acc_pu  / mc.Ntrial_theorem;
        muScaleMean(ic)       = acc_mm  / mc.Ntrial_theorem;
        muScaleStd(ic)        = acc_ms  / mc.Ntrial_theorem;
        muSatMax(ic)          = acc_sat / mc.Ntrial_theorem;
    end

    T = table(cases(:), paramFloor_markov, ddBias_markov, pUpdEff_markov, ...
              muScaleMean, muScaleStd, muSatMax, ...
        'VariableNames', {'Case','paramFloor_markov','ddBias_markov','pUpdEff_markov', ...
                          'muScaleMean','muScaleStd','muSatMax'});
end

