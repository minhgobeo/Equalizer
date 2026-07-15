% Auto-split from NCKH_v53.m (original line 2544).
% Folder: experiments/theory_legacy

function drift = run_drift_validation(cfg, v_theorem, mc)
    Nsweep_trials = mc.Ntrial_theorem;

    drift_span_list = [0.00 0.05 0.10 0.20 0.30 0.40];

    dd_self_floor = zeros(size(drift_span_list));
    oracle_floor  = zeros(size(drift_span_list));
    param_floor   = zeros(size(drift_span_list));
    drift_proxy   = zeros(size(drift_span_list));

    cfg_drift = cfg;
    cfg_drift.chan_mode   = 'drift_2tap';
    cfg_drift.drift_shape = 'sin';
    cfg_drift.SNRdB       = 14;      % harder
    cfg_drift.trainLen    = 800;     % shorter training
    cfg_drift.h_isi       = [1 0.75];
    cfg_drift.Nsym        = 60000;

    v_drift = v_theorem;
    v_drift.tau_c   = 0.35;
    v_drift.gamma_u = 5e-3;
    for ii = 1:numel(drift_span_list)
        cfg_drift.drift_span = drift_span_list(ii);

        acc_dd = 0; acc_or = 0; acc_param = 0; acc_D = 0;

        for t = 1:Nsweep_trials
            rng(6000 + 100*ii + t);

            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);

            [r_clean, ch_state] = channel_out(d, cfg_drift);
            [r, ~] = add_noise_dispatch(r_clean, cfg_drift);

            st = proposed_shadow_metrics(r, d, cfg_drift, v_drift);

            acc_dd    = acc_dd    + st.dd_self_error_floor;
            acc_or    = acc_or    + st.oracle_output_floor;
            acc_param = acc_param + st.param_floor;
            acc_D     = acc_D     + channel_drift_proxy_from_state(ch_state);
        end

        dd_self_floor(ii) = acc_dd / Nsweep_trials;
        oracle_floor(ii)  = acc_or / Nsweep_trials;
        param_floor(ii)   = acc_param / Nsweep_trials;
        drift_proxy(ii)   = acc_D / Nsweep_trials;
    end

    drift = struct();
    drift.drift_span = drift_span_list;
    drift.dd_self_floor = dd_self_floor;
    drift.oracle_floor  = oracle_floor;
    drift.param_floor   = param_floor;
    drift.drift_proxy   = drift_proxy;

    figure('Name','Theorem: parameter floor vs drift proxy'); clf;
    loglog(max(drift_proxy,1e-12), dd_self_floor, 'o-','LineWidth',1.2); hold on;
    loglog(max(drift_proxy,1e-12), param_floor,   's-','LineWidth',1.2);
    grid on;
    xlabel('$\hat{\Delta}$','Interpreter','latex');
    ylabel('tracking metric');
    legend('DD self-error floor','PD-reference tracking proxy','Location','best');
    title('Sweep in channel drift');

    figure('Name','Theorem: channel-drift proxy vs drift span'); clf;
    plot(drift_span_list, drift_proxy, 'o-','LineWidth',1.2);
    grid on;
    xlabel('drift span');
    ylabel('$\hat{\Delta}$','Interpreter','latex');
    title('Channel-drift proxy vs drift span');

    fprintf('Drift sweep:\n');
    disp(table(drift_span_list(:), dd_self_floor(:), oracle_floor(:), param_floor(:), drift_proxy(:), ...
        'VariableNames', {'driftSpan','ddSelfFloor','oracleFloor','paramFloor','driftProxy'}));
end

