% Auto-split from NCKH_v53.m (original line 1307).
% Folder: utils/math

function best_v = autotune_proposed(cfg_tune, vars, Nt, tune_snrs)
% TWO-PHASE grid search for proposed algorithm.
% Phase 1: Coarse grid over (mu_max, lambda, tau_c, Tclr)
% Phase 2: Fine grid around Phase 1 best
% Evaluates across multiple SNR points for robust parameters.
    v0 = vars.context;
    if nargin < 4, tune_snrs = 18; end

    % === Phase 1: Coarse grid ===
    mu_grid  = [0.05 0.10 0.18 0.30];
    lam_grid = [0 1e-4 5e-4];
    tau_grid = [0.10 0.25 0.45];
    Tclr_grid = [200 400 800];

    Ntotal = numel(mu_grid)*numel(lam_grid)*numel(tau_grid)*numel(Tclr_grid);
    best_ser = Inf;
    best_v   = v0;
    best_params = [v0.mu_max, v0.lambda, v0.tau_c, v0.Tclr];
    cnt = 0;

    fprintf('  [Phase 1] Coarse grid: %d candidates\n', Ntotal);
    for im = 1:numel(mu_grid)
        for il = 1:numel(lam_grid)
            for it = 1:numel(tau_grid)
                for ic = 1:numel(Tclr_grid)
                    cnt = cnt + 1;
                    v_try = v0;
                    v_try.mu_max = mu_grid(im);
                    v_try.mu_min = 1e-3 * mu_grid(im);
                    v_try.lambda = lam_grid(il);
                    v_try.Tclr   = Tclr_grid(ic);
                    if isfield(v_try,'tau_c'),  v_try.tau_c  = tau_grid(it); end
                    if isfield(v_try,'tau_c0'), v_try.tau_c0 = tau_grid(it); end
                    v_try.mu_const_global = mean(sample_periodic_mu( ...
                        v_try.mu_min, v_try.mu_max, v_try.Tclr, 1:2000));

                    ser_avg = eval_ser_quick(cfg_tune, v_try, Nt, tune_snrs);
                    if ser_avg < best_ser
                        best_ser = ser_avg;
                        best_v   = v_try;
                        best_params = [mu_grid(im), lam_grid(il), tau_grid(it), Tclr_grid(ic)];
                        fprintf('  [%d/%d] NEW BEST SER=%.4f (mu=%.3f, lam=%.1e, tau=%.3f, T=%d)\n', ...
                            cnt, Ntotal, best_ser, best_params(1), best_params(2), best_params(3), best_params(4));
                    end
                end
            end
        end
    end

    % === Phase 2: Fine grid around Phase 1 best ===
    mu_best = best_params(1);
    lam_best = best_params(2);
    tau_best = best_params(3);
    Tclr_best = best_params(4);

    mu_fine  = unique(max(0.01, [mu_best*0.6 mu_best*0.8 mu_best mu_best*1.3 mu_best*1.6]));
    lam_fine = unique(max(0, [lam_best*0.5 lam_best lam_best*2]));
    tau_fine = unique(max(0.05, min(0.8, [tau_best-0.1 tau_best tau_best+0.1 tau_best+0.2])));

    Nfine = numel(mu_fine)*numel(lam_fine)*numel(tau_fine);
    fprintf('  [Phase 2] Fine grid: %d candidates around (mu=%.3f, lam=%.1e, tau=%.3f, T=%d)\n', ...
        Nfine, mu_best, lam_best, tau_best, Tclr_best);
    cnt = 0;

    for im = 1:numel(mu_fine)
        for il = 1:numel(lam_fine)
            for it = 1:numel(tau_fine)
                cnt = cnt + 1;
                v_try = v0;
                v_try.mu_max = mu_fine(im);
                v_try.mu_min = 1e-3 * mu_fine(im);
                v_try.lambda = lam_fine(il);
                v_try.Tclr   = Tclr_best;
                if isfield(v_try,'tau_c'),  v_try.tau_c  = tau_fine(it); end
                if isfield(v_try,'tau_c0'), v_try.tau_c0 = tau_fine(it); end
                v_try.mu_const_global = mean(sample_periodic_mu( ...
                    v_try.mu_min, v_try.mu_max, v_try.Tclr, 1:2000));

                ser_avg = eval_ser_quick(cfg_tune, v_try, Nt, tune_snrs);
                if ser_avg < best_ser
                    best_ser = ser_avg;
                    best_v   = v_try;
                    fprintf('  [Fine %d/%d] NEW BEST SER=%.4f (mu=%.3f, lam=%.1e, tau=%.3f)\n', ...
                        cnt, Nfine, best_ser, mu_fine(im), lam_fine(il), tau_fine(it));
                end
            end
        end
    end
    fprintf('  [autotune_proposed] FINAL best SER=%.4f (mu=%.3f, lam=%.1e, tau=%.3f, T=%d)\n', ...
        best_ser, best_v.mu_max, best_v.lambda, best_v.tau_c, best_v.Tclr);
end

