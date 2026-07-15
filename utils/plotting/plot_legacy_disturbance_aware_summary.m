% Auto-split from NCKH_v53.m (original line 5530).
% Folder: utils/plotting

function legacy = plot_legacy_disturbance_aware_summary(cfg, vars, mc, theorem_rslt)
% Recreate the legacy 6-panel disturbance-aware summary figure inside v43,
% without bringing back the old v42 tuning/rerun flow.
%
% Preferred cases:
%   theorem, noise_aware, const_global, const_same_energy
%
% Metrics shown:
%   (1) PD-reference tracking proxy
%   (2) DD-bias proxy
%   (3) mu^2 energy proxy
%   (4) p_upd_eff
%   (5) DD self-error floor
%   (6) SER

    %#ok<INUSD>
    legacy = struct();

    % ------------------------------------------------------------
    % Severe Markov regime used in theorem package
    % ------------------------------------------------------------
    cfg_cmp = cfg;
    cfg_cmp.chan_mode = cfg.severe.chan_mode;
    cfg_cmp.SNRdB     = cfg.severe.SNRdB;
    cfg_cmp.trainLen  = cfg.severe.trainLen;
    cfg_cmp.Nsym      = cfg.severe.Nsym;
    cfg_cmp.h_isi     = cfg.severe.h_isi;
    cfg_cmp.markov.P  = cfg.severe.markovP;

    cases = {'theorem','noise_aware','const_global','const_same_energy'};
    labels = {'theorem','noise aware','const global','const same energy'};
    Nc = numel(cases);

    % same-floor calibration is not needed for this legacy figure,
    % but build_internal_case_variant expects an argument
    mu_same_floor_dummy = NaN;

    param_floor   = zeros(Nc,1);
    dd_bias_proxy = zeros(Nc,1);
    mu2bar        = zeros(Nc,1);
    p_upd_eff     = zeros(Nc,1);
    dd_self_floor = zeros(Nc,1);
    ser_dd        = zeros(Nc,1);

    Ntrial = mc.Ntrial_theorem;

    for ic = 1:Nc
        acc_param = 0;
        acc_bias  = 0;
        acc_mu2   = 0;
        acc_pupd  = 0;
        acc_dd    = 0;
        acc_ser   = 0;

        for t = 1:Ntrial
            rng(9700 + 100*ic + t);

            sym_idx = randi([1 cfg_cmp.M], cfg_cmp.Nsym, 1);
            d = cfg_cmp.A(sym_idx).';
            d = d(:);

            [r_clean, ~] = channel_out(d, cfg_cmp);
            [r, ~] = add_noise_dispatch(r_clean, cfg_cmp);

            vv = build_internal_case_variant(cases{ic}, vars, cfg_cmp, mc, mu_same_floor_dummy);

            st = proposed_shadow_metrics(r, d, cfg_cmp, vv);
            [~, d_hat] = proposed_recursion(r, d, cfg_cmp, vv);

            acc_param = acc_param + get_struct_field_flexible(st, {'param_floor','paramFloor'});
            acc_bias  = acc_bias  + get_struct_field_flexible(st, {'dd_bias_proxy','ddBiasProxy'});
            acc_mu2   = acc_mu2   + get_struct_field_flexible(st, {'mu2bar','mu2_bar','mu2Bar'});
            acc_pupd  = acc_pupd  + get_struct_field_flexible(st, {'p_upd_eff_dd','pUpdEffDD','p_upd_eff','pUpdEff'});
            acc_dd    = acc_dd    + get_struct_field_flexible(st, {'dd_self_error_floor','ddSelfErrorFloor','ddSelfFloor'});
            acc_ser   = acc_ser   + ser_after_training_aligned(d, d_hat, cfg_cmp);
        end

        param_floor(ic)   = acc_param / Ntrial;
        dd_bias_proxy(ic) = acc_bias  / Ntrial;
        mu2bar(ic)        = acc_mu2   / Ntrial;
        p_upd_eff(ic)     = acc_pupd  / Ntrial;
        dd_self_floor(ic) = acc_dd    / Ntrial;
        ser_dd(ic)        = acc_ser   / Ntrial;
    end

    legacy.cases         = cases;
    legacy.labels        = labels;
    legacy.param_floor   = param_floor;
    legacy.dd_bias_proxy = dd_bias_proxy;
    legacy.mu2bar        = mu2bar;
    legacy.p_upd_eff     = p_upd_eff;
    legacy.dd_self_floor = dd_self_floor;
    legacy.ser_dd        = ser_dd;

    legacy.summary = table(cases(:), param_floor, dd_bias_proxy, mu2bar, p_upd_eff, dd_self_floor, ser_dd, ...
        'VariableNames', {'Case','paramFloor','ddBiasProxy','mu2bar','pUpdEff','ddSelfFloor','SER'});

    figure('Name','Legacy: Disturbance-aware summary (v43)'); clf;
    tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

    nexttile;
    bar(param_floor); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',labels,'XTickLabelRotation',20);
    ylabel('value');
    title('PD-reference tracking proxy');

    nexttile;
    bar(dd_bias_proxy); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',labels,'XTickLabelRotation',20);
    ylabel('value');
    title('DD-bias proxy');

    nexttile;
    bar(mu2bar); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',labels,'XTickLabelRotation',20);
    ylabel('value');
    title('\mu^2 energy proxy');

    nexttile;
    bar(p_upd_eff); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',labels,'XTickLabelRotation',20);
    ylabel('value');
    title('p^{eff}_{upd}');

    nexttile;
    bar(dd_self_floor); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',labels,'XTickLabelRotation',20);
    ylabel('value');
    title('DD self-error floor');

    nexttile;
    bar(ser_dd); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',labels,'XTickLabelRotation',20);
    ylabel('SER');
    title('SER');

    disp('=== Legacy disturbance-aware summary (v43) ===');
    disp(legacy.summary);
end


