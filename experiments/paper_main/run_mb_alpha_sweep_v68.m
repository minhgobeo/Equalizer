% Auto-split from NCKH_v53.m (original line 11873).
% Folder: experiments/paper_main

function pkg = run_mb_alpha_sweep_v68(cfg, vars, base, mc)
% Sweep T_min and delta to find optimal hysteresis settings.

    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    cfg_p.markov.h2_states = [0.30 0.50 0.70];
    cfg_p.markov.P = [0.95 0.05 0.00; 0.025 0.95 0.025; 0.00 0.05 0.95];
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
    cfg_p.SNRdB = 30;
    cfg_p.Nsym = 80000;

    v_base = make_v_alg5(vars.theorem);
    K = cfg_p.Nf; L = cfg_p.Nb;
    main_idx = round((K+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(K,1); ffe_max = v_base.w2_max*ones(K,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    Tmin_list  = [16, 32, 64, 128, 256];
    delta_list = [0.02, 0.05, 0.10];

    Nt = max(mc.Ntrial_ser, 10);
    SER_grid = zeros(numel(Tmin_list), numel(delta_list));

    fprintf('[mb_alpha_sweep_v68] Sweeping T_min x delta on Markov SNR=30\n');

    for it = 1:numel(Tmin_list)
        for id = 1:numel(delta_list)
            ser_acc = 0;
            for t = 1:Nt
                rng(70000 + 100*it + 10*id + t);
                sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
                d = cfg_p.A(sym_idx).'; d = d(:);
                [r_clean,~] = channel_out(d, cfg_p);
                rng(70500 + 100*it + 10*id + t);
                [r,~] = add_noise_dispatch(r_clean, cfg_p);

                p = default_msb_params();
                p.T_min = Tmin_list(it);
                p.delta = delta_list(id);
                [dh, ~] = algorithm6_msb(r, d, cfg_p, v_base, p, []);
                ser_acc = ser_acc + ser_after_training_aligned(d, dh, cfg_p);
            end
            SER_grid(it, id) = ser_acc / Nt;
            fprintf('  T_min=%3d, delta=%.2f:  SER = %.3e\n', ...
                    Tmin_list(it), delta_list(id), SER_grid(it, id));
        end
    end

    [best_ser, idx] = min(SER_grid(:));
    [best_it, best_id] = ind2sub(size(SER_grid), idx);
    fprintf('\n[mb_alpha_sweep_v68] Best: T_min=%d, delta=%.2f (SER = %.3e)\n', ...
            Tmin_list(best_it), delta_list(best_id), best_ser);

    figure('Name','mb_alpha_sweep_v68: hysteresis tuning'); clf;
    [TT, DD] = meshgrid(delta_list, Tmin_list);
    surf(TT, DD, log10(SER_grid)); shading flat; colorbar;
    xlabel('\delta (margin)'); ylabel('T_{min} (dwell)'); zlabel('log_{10}(SER)');
    title('Algorithm 6: SER vs hysteresis (Markov SNR=30)');

    pkg.Tmin_list = Tmin_list;
    pkg.delta_list = delta_list;
    pkg.SER_grid = SER_grid;
    pkg.best_Tmin = Tmin_list(best_it);
    pkg.best_delta = delta_list(best_id);
end


% ============================================================================
% SECTION-E  —  PATCH C/D : BER COMPARISON (severe/realistic Markov)
% ============================================================================

