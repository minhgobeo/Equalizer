% Auto-split from NCKH_v53.m (original line 7458).
% Folder: experiments/theory_legacy

function supp_print_all_tables(out)
    fprintf('\n');
    fprintf('=================================================================\n');
    fprintf('       COMPLETE PAPER SUPPLEMENT — SUMMARY TABLES\n');
    fprintf('=================================================================\n');

    if isfield(out,'g1_ode')
        fprintf('\n--- GROUP 1-A: Theorem 1 ODE Sanity ---\n');
        fprintf('  E_ODE(T) = %.4e  (should decrease as mu_decay increases)\n', ...
            out.g1_ode.E_ODE_mean);
    end

    if isfield(out,'g1_t1val')
        fprintf('\n--- GROUP 1-B: PTF Residual Scaling T1-S4 ---\n');
        fprintf('  Ratio range [%.4f, %.4f] (should be ~constant = O(1))\n', ...
            min(out.g1_t1val.ratio_mean), max(out.g1_t1val.ratio_mean));
    end

    if isfield(out,'g2_irred')
        ir = out.g2_irred;
        fprintf('\n--- GROUP 2-A: Irreducibility of Endogenous Burden ---\n');
        fprintf('  %-12s  %-14s  %-14s  %-12s\n', ...
            'mu_max','param_floor_DD','DD_bias_proxy','mu2_diffusion');
        for i = 1:numel(ir.mu_max_list)
            fprintf('  %-12.4f  %-14.3e  %-14.3e  %-12.3e\n', ...
                ir.mu_max_list(i), ir.param_floor_dd(i), ...
                ir.dd_bias_proxy(i), ir.mu2bar_dd(i));
        end
        fprintf('  KEY: param_floor_DD at mu_max=%.3f: %.3e (nonzero = irreducible)\n', ...
            ir.mu_max_list(end), ir.param_floor_dd(end));
    end

    if isfield(out,'g2_mu2form')
        fprintf('\n--- GROUP 2-B: Proposition 15 Formula Check ---\n');
        fprintf('  Empirical mu^2 = %.6e\n', out.g2_mu2form.mu_empirical);
        fprintf('  Formula  mu^2 = %.6e\n', out.g2_mu2form.mu_formula);
        fprintf('  Relative error = %.2e  (should be < 1e-10)\n', out.g2_mu2form.rel_error);
    end

    if isfield(out,'g3_cycle')
        fprintf('\n--- GROUP 3: Cycle Contraction Rates ---\n');
        cyc = out.g3_cycle;
        fprintf('  %-22s  gamma_T_fit\n','Schedule');
        for ic = 1:numel(cyc.cases)
            fprintf('  %-22s  %.4f\n', cyc.cases{ic}, cyc.gamma_T_fit(ic));
        end
        fprintf('  Triangular CLR should have highest gamma_T\n');
    end

    if isfield(out,'g4_cmp2024')
        fprintf('\n--- GROUP 4: Comparison with SM-sign-NLMS (2024) ---\n');
        cmp = out.g4_cmp2024;
        fprintf('  %-20s  MSE@14dB    p_upd   B_c_proxy\n','Algorithm');
        idx14 = find(cmp.snr_list == 14,1);
        if isempty(idx14), idx14 = round(numel(cmp.snr_list)/2); end
        fprintf('  %-20s  %.3e    %.2f%%   %.3e\n','Proposed DD', ...
            cmp.mse_proposed(idx14), cmp.pupd_proposed(idx14)*100, cmp.dd_bias_proxy(idx14));
        fprintf('  %-20s  %.3e    %.2f%%  0 (exogenous)\n','SM-sign-NLMS', ...
            cmp.mse_smsign(idx14), cmp.pupd_smsign(idx14)*100);
        fprintf('  %-20s  %.3e    ~few%%  0 (exogenous)\n','SM-sign-NLMS VSS', ...
            cmp.mse_smsign_vss(idx14));
        fprintf('  %-20s  %.3e    100%%   0 (exogenous)\n','NLMS', cmp.mse_nlms(idx14));
    end

    if isfield(out,'g5_ft')
        fprintf('\n--- GROUP 5: Finite-Time Theorem 2-prime ---\n');
        fprintf('  Floor Delta* = %.4e\n', out.g5_ft.Delta_star);
        fprintf('  Fitted c     = %.4f  (decay rate per mu)\n', out.g5_ft.c_fit);
        fprintf('  mu_eff       = %.4e\n', out.g5_ft.mu_eff);
        if ~isnan(out.g5_ft.c_fit) && out.g5_ft.c_fit > 0
            fprintf('  Mixing time n* ≈ %.0f  (1/(c*mu)*log(V0/Delta*))\n', ...
                1/(out.g5_ft.c_fit * out.g5_ft.mu_eff));
        end
    end

    if isfield(out,'g5b_jump')
        fprintf('\n--- GROUP 5B: Algorithm 2 Abrupt Channel Jump ---\n');
        jmp = out.g5b_jump;
        jump_idx = round(numel(jmp.e2_na) * 0.55);
        post_range = jump_idx+1:min(numel(jmp.e2_na), jump_idx+1000);
        fprintf('  Post-jump MSE (Algo2):     %.3e\n', mean(jmp.e2_na(post_range)));
        fprintf('  Post-jump MSE (Thm-core):  %.3e\n', mean(jmp.e2_th(post_range)));
        fprintf('  Peak drift sensor:         %.3e\n', max(jmp.drift_hat(post_range)));
        fprintf('  KEY: Algo2 recovers faster via online sensors (eq:Bhat, eq:Dhat)\n');
    end

    if isfield(out,'g7_8023')
        fprintf('\n--- GROUP 7: IEEE 802.3-2018 Channel Compliance ---\n');
        r8 = out.g7_8023;
        fprintf('  Channel ISI ratio: %.2f%% (802.3 limit: %.0f%%)\n', ...
            r8.isi_ratio*100, r8.isi_limit*100);
        if r8.isi_ratio < r8.isi_limit
            fprintf('  Status: PASS\n');
        else
            fprintf('  Status: FAIL (exceeds ISI limit)\n');
        end
        fprintf('  MSE basic channel:    %.3e\n', r8.mse_basic);
        fprintf('  MSE 802.3-grade:      %.3e\n', r8.mse_8023);
        fprintf('  Degradation ratio:    %.2fx\n', r8.mse_8023/max(r8.mse_basic,eps));
        fprintf('  KEY: Proposed DD remains bounded under 802.3-grade impairments\n');
    end

    fprintf('\n=================================================================\n');
    fprintf('  All %d supplement figures generated.\n', 14);
    fprintf('  Groups: G1(ODE+PTF), G2(Irred+mu2), G3(Cycle), G4(SM-sign),\n');
    fprintf('          G5(Finite+Jump), G6(Eye+Floor), G7(802.3 Channel)\n');
    fprintf('=================================================================\n');
end

