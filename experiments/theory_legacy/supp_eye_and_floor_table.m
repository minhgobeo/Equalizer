% Auto-split from NCKH_v53.m (original line 7327).
% Folder: experiments/theory_legacy

function eye_r = supp_eye_and_floor_table(cfg, vars, base, mc)
% Paper summary: eye diagram + three-term floor decomposition table

    Nsweep = min(mc.Ntrial_theorem, 8);

    % --- Run one representative run for eye diagram -------------------
    rng(99001);
    sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
    d = cfg.A(sym_idx).'; d = d(:);
    [r_clean,~] = channel_out(d, cfg);
    [r,~]       = add_noise_dispatch(r_clean, cfg);
    [y_prop, ~, ~, diag_prop] = proposed_recursion(r, d, cfg, vars.theorem);

    % Eye diagram
    sps       = cfg.sps_eye;
    alpha_rc  = cfg.alpha_eye;
    span_ui   = cfg.spanUI_eye;
    g_rc      = rc_pulse(alpha_rc, sps, span_ui);
    r_os      = conv(upsample_zeros(r,     sps), g_rc, 'same');
    y_os      = conv(upsample_zeros(y_prop,sps), g_rc, 'same');

    % --- Three-term floor decomposition across SNR --------------------
    snr_list2 = [10, 14, 18, 22];
    Ns2       = numel(snr_list2);

    Delta_diff   = zeros(Ns2,1);
    Delta_burden = zeros(Ns2,1);
    Delta_drift  = zeros(Ns2,1);
    Delta_star   = zeros(Ns2,1);

    for is = 1:Ns2
        cfg_s       = cfg;
        cfg_s.SNRdB = snr_list2(is);

        acc_mu2=0; acc_bc=0; acc_drift=0;

        for t = 1:Nsweep
            rng(72000 + 100*is + t);
            sym_idx2 = randi([1 cfg_s.M], cfg_s.Nsym, 1);
            d2 = cfg_s.A(sym_idx2).'; d2 = d2(:);
            [r_clean2,ch_state] = channel_out(d2, cfg_s);
            [r2,~] = add_noise_dispatch(r_clean2, cfg_s);
            st = proposed_shadow_metrics(r2, d2, cfg_s, vars.theorem);
            acc_mu2   = acc_mu2   + st.mu2bar;
            acc_bc    = acc_bc    + st.dd_bias_proxy;
            acc_drift = acc_drift + channel_drift_proxy_from_state(ch_state);
        end
        mu2_avg   = acc_mu2   / Nsweep;
        bc_avg    = acc_bc    / Nsweep;
        drift_avg = acc_drift / Nsweep;

        % Theorem constants (Proposition synthesis + compactness-based drift bound)
        % c = c0/2, C_b = 4/c0, C_d = 4*C_H + Delta_bar (compactness bound)
        c0   = 1e-2;  % approximate dissipativity constant from model
        c    = c0/2;
        Cnu  = 4.0;
        Cb   = 4/c0;
        % C_H = radius of compact set H (from theta bounds)
        C_H_radius = sqrt(vars.theorem.w_main_value^2 + vars.theorem.w2_max^2 + vars.theorem.b_max^2);
        Cd   = 4*C_H_radius + drift_avg;   % compactness-based: 4*C_H + Delta_bar
        mmin = vars.theorem.mu_min;

        Delta_diff(is)   = Cnu * mu2_avg   / (c * mmin);
        Delta_burden(is) = Cb  * bc_avg    / (c * mmin);
        Delta_drift(is)  = Cd  * drift_avg / (c * mmin);
        Delta_star(is)   = Delta_diff(is) + Delta_burden(is) + Delta_drift(is);
    end

    eye_r = struct();
    eye_r.snr_list2    = snr_list2;
    eye_r.Delta_diff   = Delta_diff;
    eye_r.Delta_burden = Delta_burden;
    eye_r.Delta_drift  = Delta_drift;
    eye_r.Delta_star   = Delta_star;

    % ---- Figure G6-A: Eye Diagrams ------------------------------------
    figure('Name','G6-A: Eye Diagram PAM-4 Before and After Equalization');
    clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    nexttile;
    eye_plot_reshape_fixed(r_os, sps);
    title('Eye BEFORE (ISI + AWGN)');
    grid on;

    nexttile;
    eye_plot_reshape_fixed(y_os, sps);
    title('Eye AFTER (Proposed DD equalizer)');
    grid on;

    set(gcf,'Position',[100 100 700 280]);

    % ---- Figure G6-B: Three-term floor stacked bar -------------------
    figure('Name','G6-B: Tracking-Floor Decomposition \Delta^* = \Delta_{diff}+\Delta_{burden}+\Delta_{drift}');
    clf;
    bar_data = [Delta_diff, Delta_burden, Delta_drift];
    bar(bar_data, 'stacked');
    set(gca,'XTick',1:Ns2,'XTickLabel', ...
        arrayfun(@(x)sprintf('%ddB',x),snr_list2,'UniformOutput',false));
    grid on;
    xlabel('SNR (dB)');
    ylabel('\Delta^* (approximate)');
    title({'\bf G6-B: Tracking Floor \Delta^* = \Delta_{diffusion} + \Delta_{burden} + \Delta_{drift}';
           '\Delta_{burden} is irreducible — nonzero even at high SNR (endogenous DD)'});
    legend({'\Delta_{diffusion} (gain-energy)','\Delta_{burden} (endogenous B_c, irreducible)',...
            '\Delta_{drift} (channel drift)'},'Location','best','FontSize',8);
    set(gcf,'Position',[100 100 580 340]);

    % ---- Figure G6-C: Comparison summary radar/bar -------------------
    figure('Name','G6-C: Paper Summary — All Three Floor Components vs SNR');
    clf;
    semilogy(snr_list2, Delta_diff,   'b^-', 'LineWidth',1.5,'MarkerSize',7,...
        'DisplayName','\Delta_{diffusion}  \propto \bar\mu^2');
    hold on;
    semilogy(snr_list2, Delta_burden, 'rs-', 'LineWidth',1.8,'MarkerSize',8,...
        'DisplayName','\Delta_{burden}  \propto \bar{B}_c  (IRREDUCIBLE)');
    semilogy(snr_list2, Delta_drift,  'go-', 'LineWidth',1.4,'MarkerSize',6,...
        'DisplayName','\Delta_{drift}  \propto \bar\Delta');
    semilogy(snr_list2, Delta_star,   'k*--','LineWidth',1.6,'MarkerSize',9,...
        'DisplayName','\Delta^* total');
    grid on;
    xlabel('SNR (dB)');
    ylabel('\Delta floor component');
    title('Theorem 2 / Corollary 1 — Three-Term Floor Decomposition vs SNR');
    legend('Location','best','FontSize',9);
    set(gcf,'Position',[100 100 600 340]);
end

% =========================================================================
%  PRINT ALL TABLES (summary for paper)
% =========================================================================
