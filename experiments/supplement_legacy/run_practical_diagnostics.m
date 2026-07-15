% Auto-split from NCKH_v53.m (original line 2411).
% Folder: experiments/supplement_legacy

function diagrslt = run_practical_diagnostics(cfg, rep)
    N = numel(rep.mse_curve);
    nn = (1:N).';
    mm = nn - cfg.D;
    dd_mask = (mm >= (cfg.trainLen+1)) & (mm <= cfg.Nsym);

    diagrslt = struct();
    diagrslt.dd_self_error_floor = mean(rep.mse_curve(dd_mask));
    diagrslt.p_gate      = mean(rep.raw_gate_hist(dd_mask));
    diagrslt.p_conf      = mean(rep.conf_hist(dd_mask));
    diagrslt.p_upd_hard  = mean(rep.accept_hard_hist(dd_mask));
    diagrslt.p_upd_eff   = mean(rep.accept_mass_hist(dd_mask));
    diagrslt.p_clip      = mean(rep.clip_hist(dd_mask));

    fprintf('[Practical] DD self-error floor = %.4e\n', diagrslt.dd_self_error_floor);
    fprintf('[Practical] p_gate = %.3f, p_conf = %.3f, p_upd_hard = %.3f, p_upd_eff = %.3f, p_clip = %.3f\n', ...
        diagrslt.p_gate, diagrslt.p_conf, diagrslt.p_upd_hard, diagrslt.p_upd_eff, diagrslt.p_clip);

    figure('Name',['Appendix A1: Practical diagnostics (' rep.variant_name ')']); clf;
    tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

    nexttile;
    plot(rep.mu_hist,'LineWidth',1.0); grid on;
    xlabel('n'); ylabel('\mu(n)');
    title('Adaptive gain');

    nexttile;
    plot(rep.raw_gate_hist,'LineWidth',1.0); hold on;
    plot(rep.conf_hist,'LineWidth',1.0);
    plot(rep.accept_hard_hist,'LineWidth',1.0);
    plot(rep.accept_mass_hist,'LineWidth',1.0);
    plot(rep.clip_hist,'LineWidth',1.0);
    grid on; xlabel('n'); ylabel('activity');
    legend('raw gate','confidence','accept hard','accept mass','clip','Location','best');
    title('Update structure diagnostics');

    nexttile;
    plot(rep.margin_hist,'LineWidth',1.0); grid on;
    xlabel('n'); ylabel('margin');
    title('Margin to nearest PAM-4 decision boundary');
end

%% =====================================================================
% THEOREM PACKAGE (Theorem 2 support)
%% =====================================================================
