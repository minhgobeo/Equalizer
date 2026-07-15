% Auto-split from NCKH_v53.m (original line 2247).
% Folder: utils/math

function rslt = t2_fig8_comparison_table(cfg, v, base, Nt)
    alg_names = {'Proposed (DD+CLR)', 'LMS', 'NLMS', 'RLS', 'SM-sign-NLMS VSS', 'SM-sign-NLMS'};
    Nalg = 6;

    dd_floor = zeros(Nalg, 1);
    ser_val  = zeros(Nalg, 1);
    mu2_val  = zeros(Nalg, 1);
    p_upd    = zeros(Nalg, 1);

    cfg_e = cfg; cfg_e.SNRdB = 20;

    for t = 1:Nt
        rng(15000 + t);
        sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
        d = cfg.A(sym_idx).'; d = d(:);
        [r_clean, ~] = channel_out(d, cfg_e);
        rng(15500 + t);
        [r, sigma2] = add_noise_dispatch(r_clean, cfg_e);
        r_a = apply_practical_agc(r, d, cfg_e);

        N = numel(r);
        mm = (1:N).' - cfg.D;
        dd_mask = (mm >= (cfg.trainLen+1)) & (mm <= cfg.Nsym);

        % Proposed
        [~, dh1, e1, di1] = proposed_recursion(r_a, d, cfg_e, v);
        dd_floor(1) = dd_floor(1) + mean(e1(dd_mask).^2);
        ser_val(1)  = ser_val(1) + ser_after_training_aligned(d, dh1, cfg_e);
        mu2_val(1)  = mu2_val(1) + mean(di1.mu_hist(dd_mask).^2);
        p_upd(1)    = p_upd(1) + mean(di1.accept_mass_hist(dd_mask));

        % LMS
        [~, dh2, e2] = dfe_lms_unified_x(r_a, d, cfg_e, base);
        dd_floor(2) = dd_floor(2) + mean(e2(dd_mask).^2);
        ser_val(2)  = ser_val(2) + ser_after_training_aligned(d, dh2, cfg_e);
        mu2_val(2)  = mu2_val(2) + base.mu_lms^2;
        p_upd(2)    = p_upd(2) + 1.0;

        % NLMS
        [~, dh3, e3] = dfe_nlms_unified_x(r_a, d, cfg_e, base);
        dd_floor(3) = dd_floor(3) + mean(e3(dd_mask).^2);
        ser_val(3)  = ser_val(3) + ser_after_training_aligned(d, dh3, cfg_e);
        mu2_val(3)  = mu2_val(3) + base.mu_nlms^2;
        p_upd(3)    = p_upd(3) + 1.0;

        % RLS
        [~, dh4, e4] = dfe_rls_unified_x(r_a, d, cfg_e, base);
        dd_floor(4) = dd_floor(4) + mean(e4(dd_mask).^2);
        ser_val(4)  = ser_val(4) + ser_after_training_aligned(d, dh4, cfg_e);

        % SM-sign-NLMS VSS
        [~, dh5, e5] = dfe_smsign_nlms_vss_unified_x(r_a, d, cfg_e, base, sigma2);
        dd_floor(5) = dd_floor(5) + mean(e5(dd_mask).^2);
        ser_val(5)  = ser_val(5) + ser_after_training_aligned(d, dh5, cfg_e);

        % SM-sign-NLMS
        [~, dh6, e6] = dfe_smsign_nlms_unified_x(r_a, d, cfg_e, base, sigma2);
        dd_floor(6) = dd_floor(6) + mean(e6(dd_mask).^2);
        ser_val(6)  = ser_val(6) + ser_after_training_aligned(d, dh6, cfg_e);
    end

    dd_floor = dd_floor / Nt;
    ser_val  = ser_val / Nt;
    mu2_val  = mu2_val / Nt;
    p_upd    = p_upd / Nt;

    % Print table
    fprintf('\n');
    fprintf('=======================================================================\n');
    fprintf('  TABLE 1: Numerical Comparison at SNR = %d dB (Theorem 2)\n', cfg_e.SNRdB);
    fprintf('=======================================================================\n');
    fprintf('%-24s | %10s | %8s | %10s | %6s\n', ...
        'Algorithm', 'DD Floor', 'SER', 'mu^2_avg', 'p_upd');
    fprintf('%-24s-+-%10s-+-%8s-+-%10s-+-%6s\n', ...
        repmat('-',1,24), repmat('-',1,10), repmat('-',1,8), repmat('-',1,10), repmat('-',1,6));
    for a = 1:Nalg
        fprintf('%-24s | %10.6f | %8.4f | %10.2e | %6.3f\n', ...
            alg_names{a}, dd_floor(a), ser_val(a), mu2_val(a), p_upd(a));
    end
    fprintf('=======================================================================\n');

    % Improvement summary
    fprintf('\nSER improvement of Proposed over baselines:\n');
    for a = 2:Nalg
        impr = (ser_val(a) - ser_val(1)) / ser_val(a) * 100;
        fprintf('  vs %-20s: %.1f%% lower SER\n', alg_names{a}, impr);
    end

    rslt.alg_names = alg_names;
    rslt.dd_floor = dd_floor; rslt.ser_val = ser_val;
    rslt.mu2_val = mu2_val; rslt.p_upd = p_upd;
end

