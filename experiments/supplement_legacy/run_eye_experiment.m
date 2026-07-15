% Auto-split from NCKH_v53.m (original line 1145).
% Folder: experiments/supplement_legacy

function eye_rslt = run_eye_experiment(cfg, rep)
    g_rc = rc_pulse(cfg.alpha_eye, cfg.sps_eye, cfg.spanUI_eye);
    y_b_os = conv(upsample_zeros(rep.r_before, cfg.sps_eye), g_rc);
    y_a_os = conv(upsample_zeros(rep.y_after,  cfg.sps_eye), g_rc);

    eye_rslt = struct();
    eye_rslt.before = y_b_os;
    eye_rslt.after  = y_a_os;

    figure('Name',['Practical: Eye BEFORE vs AFTER (' rep.variant_name ')']); clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    nexttile; eye_plot_reshape_fixed(y_b_os, cfg.sps_eye); title('Eye BEFORE (practical input)'); grid on;
    nexttile; eye_plot_reshape_fixed(y_a_os, cfg.sps_eye); title(['Eye AFTER (' rep.variant_name ')']); grid on;

    % --------------------------------------------------
    % Additional figure: sample-domain clustering
    % --------------------------------------------------
    figure('Name',['Practical: Sample clusters (' rep.variant_name ')']); clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    nexttile;
    plot(rep.r_before(1:min(end,5000)), '.', 'MarkerSize',4); grid on;
    xlabel('n'); ylabel('r(n)');
    title('Input samples (first 5000)');

    nexttile;
    plot(rep.y_after(1:min(end,5000)), '.', 'MarkerSize',4); grid on;
    xlabel('n'); ylabel('y(n)');
    title('Equalized samples (first 5000)');
end

