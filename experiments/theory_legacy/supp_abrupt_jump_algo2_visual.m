% Auto-split from NCKH_v53.m (original line 7074).
% Folder: experiments/theory_legacy

function jmp = supp_abrupt_jump_algo2_visual(cfg, vars, mc)
% Shows that when the channel jumps abruptly:
%   (1) drift proxy Delta_hat spikes
%   (2) Algorithm 2 (noise_aware) automatically increases mu_max
%       and tightens tau_c in response
%   (3) Recovery is faster than the theorem-core (no self-calibration)
%
% This is the "visual impact" figure for Algorithm 2 (Section IV-D of paper)

    cfg_jmp = cfg;
    cfg_jmp.chan_mode = 'baseline_2tap';
    jump_idx = cfg.jump.at_symbol;
    Nsym     = cfg.Nsym;

    % Allocate accumulators for Monte Carlo averaging
    Ntrial = min(mc.Ntrial_theorem, 10);

    e2_na_acc      = zeros(Nsym,1);
    e2_th_acc      = zeros(Nsym,1);
    drift_hat_acc  = zeros(Nsym,1);
    bias_hat_acc   = zeros(Nsym,1);
    mu_scale_acc   = zeros(Nsym,1);
    tau_acc        = zeros(Nsym,1);

    for t = 1:Ntrial
        rng(80000 + t);
        sym_idx = randi([1 cfg_jmp.M], Nsym, 1);
        d = cfg_jmp.A(sym_idx).'; d = d(:);

        % Build abrupt channel jump
        cfg1 = cfg_jmp; cfg1.h_isi = cfg.jump.h_before;
        cfg2 = cfg_jmp; cfg2.h_isi = cfg.jump.h_after;
        [r1,~] = channel_out(d(1:jump_idx), cfg1);
        [r2,~] = channel_out(d(jump_idx+1:end), cfg2);
        r_clean = [r1; r2];
        [r,~] = add_noise_dispatch(r_clean, cfg_jmp);

        % Algorithm 2 (noise_aware) — self-calibrating
        [~,~,e_na,diag_na] = proposed_recursion(r, d, cfg_jmp, vars.noise_aware);

        % Theorem-core (no self-calibration)
        [~,~,e_th,~] = proposed_recursion(r, d, cfg_jmp, vars.theorem);

        e2_na_acc     = e2_na_acc     + e_na.^2;
        e2_th_acc     = e2_th_acc     + e_th.^2;
        drift_hat_acc = drift_hat_acc + diag_na.drift_hat_hist;
        bias_hat_acc  = bias_hat_acc  + diag_na.bias_hat_hist;
        mu_scale_acc  = mu_scale_acc  + diag_na.mu_scale_hist;
        tau_acc       = tau_acc       + diag_na.tau_hist;
    end

    e2_na     = e2_na_acc     / Ntrial;
    e2_th     = e2_th_acc     / Ntrial;
    drift_hat = drift_hat_acc / Ntrial;
    bias_hat  = bias_hat_acc  / Ntrial;
    mu_scale  = mu_scale_acc  / Ntrial;
    tau_trace = tau_acc       / Ntrial;

    % Smoothing for display
    smooth_len = 200;
    e2_na_s  = movmean(e2_na, smooth_len);
    e2_th_s  = movmean(e2_th, smooth_len);

    jmp = struct();
    jmp.e2_na = e2_na; jmp.e2_th = e2_th;
    jmp.drift_hat = drift_hat; jmp.bias_hat = bias_hat;
    jmp.mu_scale = mu_scale; jmp.tau_trace = tau_trace;

    % ---- Figure G5B: Algorithm 2 Abrupt Jump Response ----------------
    figure('Name','G5B: Algorithm 2 — Abrupt Channel Jump Self-Calibration');
    clf;
    tiledlayout(4,1,'TileSpacing','compact','Padding','compact');

    nn = 1:Nsym;

    % Panel 1: Error comparison
    nexttile;
    semilogy(nn, e2_th_s, 'Color',[0.6 0.6 0.6], 'LineWidth',1.0, ...
        'DisplayName','Theorem-core (no self-cal)');
    hold on;
    semilogy(nn, e2_na_s, 'b-', 'LineWidth',1.3, ...
        'DisplayName','Algorithm 2 (self-calibrating)');
    xline(jump_idx, 'r--', 'LineWidth',1.5, 'DisplayName','Channel jump');
    grid on; ylabel('MSE (smoothed)');
    title('\bf G5B: Abrupt Channel Jump — Algorithm 2 Self-Calibration');
    legend('Location','northeast','FontSize',7);

    % Panel 2: Drift proxy Delta_hat spikes at jump
    nexttile;
    plot(nn, drift_hat, 'Color',[0 0.6 0], 'LineWidth',1.2);
    hold on;
    xline(jump_idx, 'r--', 'LineWidth',1.5);
    grid on; ylabel('$\hat{\Delta}_n$','Interpreter','latex');
    title('Online drift sensor \Delta_n (eq:Dhat) — spikes at channel jump');

    % Panel 3: mu_scale responds to drift spike
    nexttile;
    plot(nn, mu_scale, 'Color',[0.8 0.4 0], 'LineWidth',1.2);
    hold on;
    xline(jump_idx, 'r--', 'LineWidth',1.5);
    grid on; ylabel('\mu_{scale}');
    title('\mu_{max} adaptation (eq:mumax) — increases to boost restoring authority');

    % Panel 4: tau_c responds to bias change
    nexttile;
    plot(nn, tau_trace, 'm-', 'LineWidth',1.2);
    hold on;
    xline(jump_idx, 'r--', 'LineWidth',1.5);
    grid on; ylabel('\tau_c');
    xlabel('Symbol index n');
    title('\tau_c adaptation (eq:tauc) — tightens when B_c rises');

    set(gcf,'Position',[100 50 680 620]);

    fprintf('[G5B] Jump at n=%d: post-jump MSE (Algo2)=%.3e vs (Thm-core)=%.3e\n', ...
        jump_idx, mean(e2_na(jump_idx+1:min(end,jump_idx+1000))), ...
        mean(e2_th(jump_idx+1:min(end,jump_idx+1000))));
end

% =========================================================================
%  GROUP 7 — IEEE 802.3-2018 Channel Compliance Demo
% =========================================================================
