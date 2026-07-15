% Auto-split from NCKH_v53.m (original line 7196).
% Folder: experiments/theory_legacy

function res = supp_ieee8023_channel_demo(cfg, vars, mc)
% Demonstrates IEEE 802.3-2018 inspired channel model quality:
%   Panel A: Channel impulse response and ISI ratio vs 9% limit
%   Panel B: Eye diagram comparison: ideal vs with jitter+xtalk
%   Panel C: Noise decomposition: AWGN + crosstalk + impulse contributions
%   Panel D: Proposed DD algorithm performance under 802.3-grade channel
%
% References: Sections 23.5.1.3, 23.6.5, 23.7 of IEEE Std 802.3-2018

    Nsym = min(cfg.Nsym, 30000);

    % ---- Setup 802.3 channel ----
    cfg_8023 = cfg;
    cfg_8023.std8023.enable = true;
    cfg_8023.std8023.noise_model = 'office_env';
    cfg_8023.Nsym = Nsym;

    % Build channel IR for display
    h_ir = build_utp_ir_model(cfg_8023);
    isi_ratio = measure_isi_ratio(h_ir);

    % ---- Run with 802.3 channel ----
    rng(99001);
    sym_idx = randi([1 cfg_8023.M], Nsym, 1);
    d = cfg_8023.A(sym_idx).'; d = d(:);

    [r_clean_8023, ch_st] = channel_out(d, cfg_8023);
    [r_8023, sigma2_8023] = add_noise_dispatch(r_clean_8023, cfg_8023);

    % ---- Run with basic channel for comparison ----
    cfg_basic = cfg;
    cfg_basic.std8023.enable = false;
    cfg_basic.Nsym = Nsym;
    [r_clean_basic, ~] = channel_out(d, cfg_basic);
    [r_basic, ~] = add_noise_dispatch(r_clean_basic, cfg_basic);

    % ---- Equalize both ----
    [~,~,e_8023,diag_8023]  = proposed_recursion(r_8023, d, cfg_8023, vars.theorem);
    [~,~,e_basic,diag_basic]= proposed_recursion(r_basic, d, cfg_basic, vars.theorem);

    N = numel(r_8023);
    nn = (1:N).'; mm = nn - cfg_8023.D;
    dd_mask = (mm >= cfg_8023.trainLen+1) & (mm <= Nsym);

    mse_8023  = mean(e_8023(dd_mask).^2);
    mse_basic = mean(e_basic(dd_mask).^2);

    res = struct();
    res.h_ir = h_ir;
    res.isi_ratio = isi_ratio;
    res.isi_limit = cfg_8023.std8023.isi_limit;
    res.mse_8023  = mse_8023;
    res.mse_basic = mse_basic;

    % ==== Figure G7: 4-panel IEEE 802.3 Channel Demo ====
    figure('Name','G7: IEEE 802.3-2018 Channel Model — Submission-Grade Demo');
    clf;
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    % Panel A: Impulse response + ISI bar
    nexttile;
    stem(0:numel(h_ir)-1, h_ir, 'filled', 'LineWidth',1.5);
    hold on;
    yline(0, 'k-');
    grid on;
    xlabel('Tap index');
    ylabel('h[k]');
    title(sprintf('(a) UTP Channel IR — ISI ratio = %.1f%% (limit: %.0f%%)', ...
        isi_ratio*100, cfg_8023.std8023.isi_limit*100));
    if isi_ratio < cfg_8023.std8023.isi_limit
        text(numel(h_ir)-1, max(h_ir)*0.8, 'PASS', 'Color','g', ...
            'FontWeight','bold','FontSize',12,'HorizontalAlignment','right');
    else
        text(numel(h_ir)-1, max(h_ir)*0.8, 'FAIL', 'Color','r', ...
            'FontWeight','bold','FontSize',12,'HorizontalAlignment','right');
    end

    % Panel B: MSE learning curves comparison
    nexttile;
    smooth_len = 200;
    semilogy(movmean(e_basic(1:N).^2, smooth_len), 'Color',[0.6 0.6 0.6], ...
        'LineWidth',1.0, 'DisplayName','Basic 2-tap channel');
    hold on;
    semilogy(movmean(e_8023(1:N).^2, smooth_len), 'b-', 'LineWidth',1.3, ...
        'DisplayName','802.3-grade (ISI+jitter+xtalk+impulse)');
    xline(cfg_8023.trainLen, 'r--', 'DD start', 'LineWidth',1.2);
    grid on;
    xlabel('Symbol index n');
    ylabel('Instantaneous MSE (smoothed)');
    title('(b) DD Convergence: Basic vs 802.3-Grade Channel');
    legend('Location','northeast','FontSize',7);

    % Panel C: Noise budget breakdown
    nexttile;
    % Estimate noise contributions
    isi_power    = var(r_clean_8023 - d);  % ISI + xtalk power
    awgn_power   = sigma2_8023;
    total_noise  = var(r_8023 - d);
    other_power  = max(0, total_noise - awgn_power - isi_power);

    bar_vals = [isi_power, awgn_power, other_power];
    b = bar(bar_vals);
    b.FaceColor = 'flat';
    b.CData = [0.85 0.33 0.10; 0.00 0.45 0.74; 0.47 0.67 0.19];
    set(gca,'XTick',1:3,'XTickLabel',{'ISI+Xtalk','AWGN','Impulse+Other'});
    grid on;
    ylabel('Power');
    title('(c) Noise Budget Decomposition (802.3-grade)');

    % Panel D: DD-bias comparison
    nexttile;
    bar_mse = [mse_basic, mse_8023];
    b2 = bar(bar_mse);
    b2.FaceColor = 'flat';
    b2.CData = [0.6 0.6 0.6; 0.20 0.45 0.85];
    set(gca,'XTick',1:2,'XTickLabel',{'Basic channel','802.3-grade'});
    grid on;
    ylabel('DD Steady-State MSE');
    title(sprintf('(d) Tracking Floor: Basic=%.2e vs 802.3=%.2e', mse_basic, mse_8023));

    set(gcf,'Position',[80 80 780 520]);

    fprintf('[G7] ISI ratio = %.2f%% (limit %.0f%%)\n', isi_ratio*100, ...
        cfg_8023.std8023.isi_limit*100);
    fprintf('[G7] MSE: basic=%.3e, 802.3-grade=%.3e (ratio=%.2fx)\n', ...
        mse_basic, mse_8023, mse_8023/max(mse_basic,eps));
end

% =========================================================================
%  GROUP 6  —  EYE DIAGRAM + FLOOR TABLE  (Paper summary figure)
% =========================================================================
