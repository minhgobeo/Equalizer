% Auto-split from NCKH_v53.m (original line 2101).
% Folder: utils/math

function rslt = t2_fig5_burden_proxy(cfg, v, Nt)
    snr_list = 6:3:30;
    Nsnr = numel(snr_list);

    Bc_prop = zeros(Nsnr, 1);
    Bc_baseline = zeros(Nsnr, 1);
    param_floor = zeros(Nsnr, 1);
    dd_floor    = zeros(Nsnr, 1);

    for si = 1:Nsnr
        cfg_s = cfg; cfg_s.SNRdB = snr_list(si);
        acc_Bc = 0; acc_pf = 0; acc_dd = 0;
        for t = 1:Nt
            rng(13000 + 100*si + t);
            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg_s);
            rng(13500 + 100*si + t);
            [r, ~] = add_noise_dispatch(r_clean, cfg_s);
            st = proposed_shadow_metrics(r, d, cfg_s, v);
            acc_Bc = acc_Bc + st.dd_bias_proxy;
            acc_pf = acc_pf + st.param_floor;
            acc_dd = acc_dd + st.dd_self_error_floor;
        end
        Bc_prop(si) = acc_Bc / Nt;
        param_floor(si) = acc_pf / Nt;
        dd_floor(si) = acc_dd / Nt;
    end

    figure('Name','T2-Fig5: Endogenous burden proxy'); clf;
    tiledlayout(1,2,'TileSpacing','compact');
    nexttile;
    yyaxis left;
    semilogy(snr_list, Bc_prop, 'ro-', 'LineWidth', 1.5);
    ylabel('B_c (DD-bias proxy)');
    yyaxis right;
    semilogy(snr_list, dd_floor, 'bs-', 'LineWidth', 1.2);
    ylabel('DD self-error floor');
    grid on; xlabel('SNR (dB)');
    title('(a) Burden proxy vs SNR');
    legend({'B_c (endogenous, proposed)','DD self-error floor'},'Location','best');

    nexttile;
    loglog(Bc_prop, dd_floor, 'ko-', 'LineWidth', 1.5, 'MarkerSize', 8);
    grid on; xlabel('B_c (DD-bias proxy)'); ylabel('\Delta^* (tracking floor)');
    title('(b) Tracking floor vs burden proxy');
    for si = 1:Nsnr
        text(Bc_prop(si)*1.05, dd_floor(si), sprintf('%ddB', snr_list(si)), 'FontSize', 8);
    end

    rslt.snr_list = snr_list; rslt.Bc = Bc_prop;
    rslt.param_floor = param_floor; rslt.dd_floor = dd_floor;
end

% --- Figure T2-6: Jump Tracking Recovery ---
