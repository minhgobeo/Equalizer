% Auto-split from NCKH_v53.m (original line 5946).
% Folder: channel

function na = run_noise_aware_proxy_response(cfg, vars)
% ============================================================
% DISTURBANCE-AWARE RESPONSE PACKAGE
%
% Purpose:
%   - show that online proxy estimates actually drive Algorithm 2
%   - validate bias/drift -> tau/mu_scale reaction
% ============================================================

    cfg_na = cfg;
    cfg_na.chan_mode   = 'drift_2tap';
    cfg_na.drift_shape = 'linear';
    cfg_na.drift_span  = 0.20;
    cfg_na.SNRdB       = 14;
    cfg_na.trainLen    = 800;
    cfg_na.Nsym        = 50000;
    cfg_na.h_isi       = [1 0.75];

    vv = vars.noise_aware;
    vv.use_adaptive_mu  = true;
    vv.use_adaptive_tau = true;

    rng(22222);
    sym_idx = randi([1 cfg_na.M], cfg_na.Nsym, 1);
    d = cfg_na.A(sym_idx).'; d = d(:);

    [r_clean, ~] = channel_out(d, cfg_na);
    [r, ~] = add_noise_dispatch(r_clean, cfg_na);

    [~,~,~,diag] = proposed_recursion(r, d, cfg_na, vv);

    na = struct();
    na.bias_hat_hist  = diag.bias_hat_hist;
    na.drift_hat_hist = diag.drift_hat_hist;
    na.tau_hist       = diag.tau_hist;
    na.mu_scale_hist  = diag.mu_scale_hist;
    na.p_upd_hist     = diag.accept_mass_hist;

    figure('Name','Algorithm 2: proxy-to-control response'); clf;
    tiledlayout(4,1,'TileSpacing','compact','Padding','compact');

    nexttile;
    plot(diag.bias_hat_hist,'LineWidth',1.1); hold on;
    plot(diag.drift_hat_hist,'LineWidth',1.1);
    grid on;
    xlabel('n'); ylabel('proxy');
    title('(a) Online disturbance proxies');
    legend({'$\hat{B}_{c,n}$','$\hat{\Delta}_n$'}, ...
       'Location','best', ...
       'Interpreter','latex');
    nexttile;
    plot(diag.tau_hist,'LineWidth',1.1); grid on;
    xlabel('n'); ylabel('\tau_c(n)');
    title('(b) Adaptive confidence threshold');

    nexttile;
    plot(diag.mu_scale_hist,'LineWidth',1.1); grid on;
    xlabel('n'); ylabel('\mu scale');
    title('(c) Adaptive gain scale');

    nexttile;
    plot(diag.accept_mass_hist,'LineWidth',1.1); grid on;
    xlabel('n'); ylabel('accepted mass');
    title('(d) Effective update activity');
end

