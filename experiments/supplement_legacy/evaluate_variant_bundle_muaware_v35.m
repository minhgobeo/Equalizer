% Auto-split from NCKH_v53.m (original line 4373).
% Folder: experiments/supplement_legacy

function st = evaluate_variant_bundle_muaware_v35(cfg, v, mc)
    st = struct();

    % ---------- nominal ----------
    acc_dd = 0; acc_param = 0; acc_bias = 0; acc_upd = 0;
    for t = 1:mc.Ntrial_theorem
        rng(12000 + t);
        sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
        d = cfg.A(sym_idx).'; d = d(:);
        [r_clean, ~] = channel_out(d, cfg);
        [r, ~] = add_awgn_measured(r_clean, cfg.SNRdB);
        s = proposed_shadow_metrics_muaware_v35(r, d, cfg, v);
        acc_dd    = acc_dd    + s.dd_self_error_floor;
        acc_param = acc_param + s.param_floor;
        acc_bias  = acc_bias  + s.dd_bias_proxy;
        acc_upd   = acc_upd   + s.p_upd_hard_dd;
    end
    st.ddSelfFloor_nom = acc_dd / mc.Ntrial_theorem;
    st.paramFloor_nom  = acc_param / mc.Ntrial_theorem;
    st.ddBias_nom      = acc_bias / mc.Ntrial_theorem;
    st.pUpdHard_nom    = acc_upd / mc.Ntrial_theorem;

    % ---------- drift ----------
    cfg_d = cfg;
    cfg_d.chan_mode = 'drift_2tap';
    cfg_d.drift_span = 0.08;
    cfg_d.drift_shape = 'linear';

    acc_dd = 0; acc_param = 0;
    for t = 1:mc.Ntrial_theorem
        rng(13000 + t);
        sym_idx = randi([1 cfg_d.M], cfg_d.Nsym, 1);
        d = cfg_d.A(sym_idx).'; d = d(:);
        [r_clean, ~] = channel_out(d, cfg_d);
        [r, ~] = add_awgn_measured(r_clean, cfg_d.SNRdB);
        s = proposed_shadow_metrics_muaware_v35(r, d, cfg_d, v);
        acc_dd    = acc_dd    + s.dd_self_error_floor;
        acc_param = acc_param + s.param_floor;
    end
    st.ddSelfFloor_drift = acc_dd / mc.Ntrial_theorem;
    st.paramFloor_drift  = acc_param / mc.Ntrial_theorem;

    % ---------- markov ----------
    cfg_m = cfg;
    cfg_m.chan_mode = 'markov_2tap';

    acc_param = 0; acc_bias = 0; acc_eff = 0;
    acc_mu_mean = 0; acc_mu_std = 0; acc_sat_min = 0; acc_sat_max = 0;

    for t = 1:mc.Ntrial_theorem
        rng(14000 + t);
        sym_idx = randi([1 cfg_m.M], cfg_m.Nsym, 1);
        d = cfg_m.A(sym_idx).'; d = d(:);
        [r_clean, ~] = channel_out(d, cfg_m);
        [r, ~] = add_awgn_measured(r_clean, cfg_m.SNRdB);
        s = proposed_shadow_metrics_muaware_v35(r, d, cfg_m, v);
        acc_param   = acc_param   + s.param_floor;
        acc_bias    = acc_bias    + s.dd_bias_proxy;
        acc_eff     = acc_eff     + s.p_upd_eff_dd;
        acc_mu_mean = acc_mu_mean + s.mu_scale_mean;
        acc_mu_std  = acc_mu_std  + s.mu_scale_std;
        acc_sat_min = acc_sat_min + s.mu_scale_sat_min;
        acc_sat_max = acc_sat_max + s.mu_scale_sat_max;
    end
    st.paramFloor_markov = acc_param / mc.Ntrial_theorem;
    st.ddBias_markov     = acc_bias / mc.Ntrial_theorem;
    st.pUpdEff_markov    = acc_eff / mc.Ntrial_theorem;
    st.muScaleMean_markov= acc_mu_mean / mc.Ntrial_theorem;
    st.muScaleStd_markov = acc_mu_std  / mc.Ntrial_theorem;
    st.muSatMin_markov   = acc_sat_min / mc.Ntrial_theorem;
    st.muSatMax_markov   = acc_sat_max / mc.Ntrial_theorem;

    % ---------- jump ----------
    [st.OvershootArea, st.PostJumpFloor] = evaluate_jump_metrics_muaware_v35(cfg, v, mc);
end

