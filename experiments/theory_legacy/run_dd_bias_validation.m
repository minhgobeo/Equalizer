% Auto-split from NCKH_v53.m (original line 2491).
% Folder: experiments/theory_legacy

function bias = run_dd_bias_validation(cfg, v_theorem, mc)
    Nsweep_trials = mc.Ntrial_theorem;
    snr_list_bias = 8:2:20;

    dd_self_floor = zeros(size(snr_list_bias));
    oracle_floor  = zeros(size(snr_list_bias));
    param_floor   = zeros(size(snr_list_bias));
    dd_bias_proxy = zeros(size(snr_list_bias));

for ii = 1:numel(snr_list_bias)
    acc_dd = 0; acc_or = 0; acc_param = 0; acc_B = 0;
    for t = 1:Nsweep_trials
        rng(5000 + 100*ii + t);
        sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
        d = cfg.A(sym_idx).'; d = d(:);

        [r_clean, ~] = channel_out(d, cfg);

        cfg_bias = cfg;
        cfg_bias.SNRdB = snr_list_bias(ii);
        [r,~] = add_noise_dispatch(r_clean, cfg_bias);

        st = proposed_shadow_metrics(r, d, cfg_bias, v_theorem);
        acc_dd    = acc_dd    + st.dd_self_error_floor;
        acc_or    = acc_or    + st.oracle_output_floor;
        acc_param = acc_param + st.param_floor;
        acc_B     = acc_B     + st.dd_bias_proxy;
    end
    dd_self_floor(ii) = acc_dd / Nsweep_trials;
    oracle_floor(ii)  = acc_or / Nsweep_trials;
    param_floor(ii)   = acc_param / Nsweep_trials;
    dd_bias_proxy(ii) = acc_B / Nsweep_trials;
end

    bias = struct();
    bias.snr = snr_list_bias;
    bias.dd_self_floor = dd_self_floor;
    bias.oracle_floor  = oracle_floor;
    bias.param_floor   = param_floor;
    bias.dd_bias_proxy = dd_bias_proxy;

    figure('Name','Theorem: tracking floor vs DD-bias proxy'); clf;
    loglog(max(dd_bias_proxy,1e-12), dd_self_floor, 'o-','LineWidth',1.2); hold on;
    loglog(max(dd_bias_proxy,1e-12), param_floor,   's-','LineWidth',1.2);
    grid on; xlabel('$\hat{B}_c$','Interpreter','latex'); ylabel('tracking metric');
    legend('DD self-error floor','PD-reference tracking proxy','Location','best');
    title('Sweep in DD severity / SNR');

    figure('Name','Theorem: DD-bias proxy vs SNR'); clf;
    semilogy(snr_list_bias, dd_bias_proxy, 'o-','LineWidth',1.2);
    grid on; xlabel('SNR (dB)'); ylabel('$\hat{B}_c$','Interpreter','latex'); title('DD-bias proxy vs SNR');
end

