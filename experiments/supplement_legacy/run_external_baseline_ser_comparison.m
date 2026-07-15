% Auto-split from NCKH_v53.m (original line 5420).
% Folder: experiments/supplement_legacy

function rslt = run_external_baseline_ser_comparison(cfg, vars, mc)

    base = build_baselines();

    cases = {'theorem','noise_aware','NLMS','SM-sign-NLMS','SM-sign-NLMS VSS'};
    Nc = numel(cases);
    Nsweep_trials = mc.Ntrial_theorem;

    sample_err_dd = zeros(Nc,1);
    ser_dd        = zeros(Nc,1);

    for ic = 1:Nc
        acc_err = 0;
        acc_ser = 0;

        for t = 1:Nsweep_trials
            rng(9100 + 100*ic + t);

            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);

            [r_clean, ~] = channel_out(d, cfg);
            [r, sigma2] = add_noise_dispatch(r_clean, cfg);

            N = numel(r);
            nn = (1:N).';
            mm = nn - cfg.D;
            dd_mask = (mm >= (cfg.trainLen+1)) & (mm <= cfg.Nsym);

            switch cases{ic}
                case 'theorem'
                    vv = vars.theorem;
                    [~, d_hat, e_samp] = proposed_recursion(r, d, cfg, vv);

                case 'noise_aware'
                    vv = vars.noise_aware;
                    [~, d_hat, e_samp] = proposed_recursion(r, d, cfg, vv);

                case 'NLMS'
                    [~, d_hat, e_samp] = dfe_nlms_unified_x(r, d, cfg, base);

                case 'SM-sign-NLMS'
                    [~, d_hat, e_samp] = dfe_smsign_nlms_unified_x(r, d, cfg, base, sigma2);

                case 'SM-sign-NLMS VSS'
                    [~, d_hat, e_samp] = dfe_smsign_nlms_vss_unified_x(r, d, cfg, base, sigma2);

                otherwise
                    error('Unknown external comparison case.');
            end

            acc_err = acc_err + mean(e_samp(dd_mask).^2);
            acc_ser = acc_ser + ser_after_training_aligned(d, d_hat, cfg);
        end

        sample_err_dd(ic) = acc_err / Nsweep_trials;
        ser_dd(ic)        = acc_ser / Nsweep_trials;
    end

    rslt = struct();
    rslt.cases = cases;
    rslt.sample_err_dd = sample_err_dd;
    rslt.ser_dd = ser_dd;

    rslt.summary = table(cases(:), sample_err_dd, ser_dd, ...
        'VariableNames', {'Case','sampleErrDD','SER'});

    figure('Name','Appendix: External baseline comparison under severe regime'); clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    nexttile;
    bar(sample_err_dd); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',cases,'XTickLabelRotation',20);
    ylabel('sample-domain DD error');
    title('(a) Sample-domain DD error');

    nexttile;
    bar(ser_dd); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',cases,'XTickLabelRotation',20);
    ylabel('SER');
    title('(b) SER');

    disp(rslt.summary);
end

