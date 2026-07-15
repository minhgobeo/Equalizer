% Auto-split from NCKH_v53.m (original line 6784).
% Folder: experiments/theory_legacy

function cmp = supp_vs_2024_smsign(cfg, vars, base, mc)
% Systematic comparison with Souza et al. 2024 (SM-sign-NLMS)
%
% The 2024 paper:
%   - shows MSE floor vs beta (step size)  → Figure 3
%   - shows p_update vs iterations         → Figure 2
%   - tracks under Markovian random walk   → Section V.E
%   - exogenous noise ONLY (no b_c term)
%
% This supplement shows:
%   - MSE floor vs SNR for ALL algorithms
%   - p_update comparison (sparsity)
%   - Tracking under Markovian channel (our advantage)
%   - ENDOGENOUS BURDEN column: zero for SM-sign-NLMS, nonzero for DD

    % ---- setup --------------------------------------------------------
    cfg_cmp          = cfg;
    cfg_cmp.chan_mode = 'markov_2tap';
    cfg_cmp.SNRdB    = cfg.severe.SNRdB;
    cfg_cmp.trainLen = cfg.severe.trainLen;
    cfg_cmp.Nsym     = cfg.severe.Nsym;
    cfg_cmp.h_isi    = cfg.severe.h_isi;
    cfg_cmp.markov.P = cfg.severe.markovP;

    Nsweep = mc.Ntrial_theorem;

    % --- A: MSE floor vs SNR for all algorithms -----------------------
    snr_list = [8, 10, 12, 14, 16, 18, 20];
    Ns = numel(snr_list);

    mse_proposed = zeros(Ns,1);
    mse_smsign   = zeros(Ns,1);
    mse_smsign_v = zeros(Ns,1);
    mse_nlms     = zeros(Ns,1);
    pupd_proposed= zeros(Ns,1);
    pupd_smsign  = zeros(Ns,1);
    param_floor_dd = zeros(Ns,1);  % endogenous burden proxy
    dd_bias_proxy  = zeros(Ns,1);

    for is = 1:Ns
        cfg_s       = cfg_cmp;
        cfg_s.SNRdB = snr_list(is);

        acc_prop=0; acc_sm=0; acc_smv=0; acc_nl=0;
        acc_pu_p=0; acc_pu_sm=0;
        acc_pf=0;   acc_bc=0;

        for t = 1:Nsweep
            rng(61000 + 100*is + t);
            sym_idx = randi([1 cfg_s.M], cfg_s.Nsym, 1);
            d = cfg_s.A(sym_idx).'; d = d(:);
            [r_clean,~] = channel_out(d, cfg_s);
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_s);

            % --- proposed DD ----------------------------------------
            [~,~,e_prop,diag_prop] = proposed_recursion(r, d, cfg_s, vars.theorem);
            N = numel(r);
            nn = (1:N).'; mm = nn - cfg_s.D;
            dd_mask = (mm >= (cfg_s.trainLen+1)) & (mm <= cfg_s.Nsym);
            acc_prop  = acc_prop  + mean(e_prop(dd_mask).^2);
            acc_pu_p  = acc_pu_p  + mean(diag_prop.accept_mass_hist(dd_mask));

            % shadow metrics for endogenous burden
            st = proposed_shadow_metrics(r, d, cfg_s, vars.theorem);
            acc_pf = acc_pf + st.param_floor;
            acc_bc = acc_bc + st.dd_bias_proxy;

            % --- SM-sign-NLMS (fixed beta) ---------------------------
            [~,~,e_sm] = dfe_smsign_nlms_unified_x(r, d, cfg_s, base, sigma2);
            acc_sm    = acc_sm    + mean(e_sm(dd_mask).^2);
            % Compute actual p_update: fraction of DD samples where |e|>gamma
            gamma_sm  = sqrt(max(0, base.smsign.tau * sigma2));
            acc_pu_sm = acc_pu_sm + mean(abs(e_sm(dd_mask)) > gamma_sm);

            % --- SM-sign-NLMS VSS ------------------------------------
            [~,~,e_smv] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_s, base, sigma2);
            acc_smv = acc_smv + mean(e_smv(dd_mask).^2);

            % --- plain NLMS ------------------------------------------
            [~,~,e_nl] = dfe_nlms_unified_x(r, d, cfg_s, base);
            acc_nl  = acc_nl  + mean(e_nl(dd_mask).^2);
        end

        mse_proposed(is)  = acc_prop / Nsweep;
        mse_smsign(is)    = acc_sm   / Nsweep;
        mse_smsign_v(is)  = acc_smv  / Nsweep;
        mse_nlms(is)      = acc_nl   / Nsweep;
        pupd_proposed(is) = acc_pu_p / Nsweep;
        pupd_smsign(is)   = acc_pu_sm / Nsweep;
        param_floor_dd(is)= acc_pf   / Nsweep;
        dd_bias_proxy(is) = acc_bc   / Nsweep;
    end

    cmp = struct();
    cmp.snr_list       = snr_list;
    cmp.mse_proposed   = mse_proposed;
    cmp.mse_smsign     = mse_smsign;
    cmp.mse_smsign_vss = mse_smsign_v;
    cmp.mse_nlms       = mse_nlms;
    cmp.pupd_proposed  = pupd_proposed;
    cmp.pupd_smsign    = pupd_smsign;
    cmp.param_floor_dd = param_floor_dd;
    cmp.dd_bias_proxy  = dd_bias_proxy;

    % ---- Figure G4-A: MSE floor vs SNR comparison --------------------
    figure('Name','G4-A: MSE Floor vs SNR — Proposed vs SM-sign-NLMS (2024) vs NLMS');
    clf;
    semilogy(snr_list, mse_proposed,  'bo-','LineWidth',1.8,'MarkerSize',7,...
        'DisplayName','Proposed DD (endogenous Markov)');
    hold on;
    semilogy(snr_list, mse_smsign,    'rs-','LineWidth',1.5,'MarkerSize',6,...
        'DisplayName','SM-sign-NLMS [2024] (exogenous)');
    semilogy(snr_list, mse_smsign_v,  'rd--','LineWidth',1.4,'MarkerSize',5,...
        'DisplayName','SM-sign-NLMS VSS [2024]');
    semilogy(snr_list, mse_nlms,      'kx-','LineWidth',1.2,'MarkerSize',6,...
        'DisplayName','NLMS (baseline)');
    grid on;
    xlabel('SNR (dB)');
    ylabel('DD Self-Error Floor (MSE)');
    title({'G4-A: MSE Floor Comparison under Markovian Channel';
           'Proposed operates under endogenous disturbance; SM-sign-NLMS does not'});
    legend('Location','northeast','FontSize',8);
    set(gcf,'Position',[100 100 600 340]);

    % ---- Figure G4-B: Update sparsity (p_upd) ------------------------
    figure('Name','G4-B: Update Sparsity — Proposed Gating vs Algorithms');
    clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    nexttile;
    plot(snr_list, pupd_proposed*100, 'bo-','LineWidth',1.8,'MarkerSize',7);
    hold on;
    yline(100, 'k--','LineWidth',1.2,'DisplayName','NLMS (always update)');
    grid on;
    xlabel('SNR (dB)');
    ylabel('p_{upd} (%)');
    title('(a) Effective update rate: Proposed (DD gating)');
    ylim([0 110]);
    legend('Proposed','NLMS (100%)','Location','best');

    nexttile;
    % Bar at midpoint SNR showing sparsity advantage
    mid_snr = round(numel(snr_list)/2);
    bar_data = [pupd_proposed(mid_snr)*100, pupd_smsign(mid_snr)*100, ...
                pupd_smsign(mid_snr)*100, 100];  % VSS approx same gate rate as fixed
    b = bar(bar_data);
    b.FaceColor = 'flat';
    b.CData = [0.2 0.4 0.8; 0.8 0.2 0.2; 0.8 0.4 0.4; 0.6 0.6 0.6];
    set(gca,'XTick',1:4,'XTickLabel', ...
        {'Proposed DD','SM-sign-NLMS','SM-sign VSS','NLMS'},...
        'XTickLabelRotation',20);
    grid on;
    ylabel(sprintf('p_{upd} (%%) at SNR=%ddB', snr_list(mid_snr)));
    title('(b) Computational sparsity: gating advantage');
    ylim([0 120]);

    set(gcf,'Position',[100 100 700 300]);

    % ---- Figure G4-C: Endogenous burden — KEY DIFFERENTIATOR ----------
    figure('Name','G4-C: Endogenous Burden Fingerprint — NOT in SM-sign-NLMS');
    clf;
    yyaxis left;
    semilogy(snr_list, param_floor_dd, 'bo-','LineWidth',1.8,'MarkerSize',7);
    ylabel('\Delta_{burden} proxy (param floor)','Color','b');
    yyaxis right;
    semilogy(snr_list, dd_bias_proxy,  'rs--','LineWidth',1.5,'MarkerSize',6);
    ylabel('\hat{B}_c (DD-bias proxy)','Color','r');
    grid on;
    xlabel('SNR (dB)');
    title({'\bf G4-C: Endogenous Burden \Delta_{burden} — Irreducible Component';
           'This term is ZERO in SM-sign-NLMS [2024] (exogenous only)';
           'It is NONZERO here because DD feedback creates b_c \neq 0'});
    legend({'\Delta_{burden} (tracking proxy)','\hat{B}_c (bias proxy)'},...
        'Location','best');
    set(gcf,'Position',[100 100 600 320]);

    % ---- Print comparison table (mirrors Table 1 in paper) -----------
    fprintf('\n[G4] Comparison Table (at SNR=14dB, Markov regime):\n');
    mid = find(snr_list == 14, 1);
    if isempty(mid), mid = round(Ns/2); end
    fprintf('  %-20s  MSE_floor    p_upd    B_c_proxy\n','Algorithm');
    fprintf('  %-20s  %-10.3e  %-7.1f  %-10.3e\n', ...
        'Proposed DD', mse_proposed(mid), pupd_proposed(mid)*100, dd_bias_proxy(mid));
    fprintf('  %-20s  %-10.3e  %-7s  %-10s\n', ...
        'SM-sign-NLMS [2024]', mse_smsign(mid), '~few%', '0 (exogenous)');
    fprintf('  %-20s  %-10.3e  %-7s  %-10s\n', ...
        'SM-sign-NLMS VSS', mse_smsign_v(mid), '~few%', '0 (exogenous)');
    fprintf('  %-20s  %-10.3e  %-7.0f  %-10s\n', ...
        'NLMS', mse_nlms(mid), 100.0, '0 (exogenous)');
end

% =========================================================================
%  GROUP 5  —  FINITE-TIME BOUND VALIDATION  (Gap 7: Theorem 2')
% =========================================================================
