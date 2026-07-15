% Auto-split from NCKH_v53.m (original line 1).
% Folder: utils/math

function out = demo_v44_pam4_sa_markov_ptf_complete(mode)
% ========================================================================
% FINAL PAPER HARNESS (v50)
%
% mode = 'paper'            : ★ RECOMMENDED for committee — theorem2 + practical + appendix
% mode = 'theorem2'         : Theorem 2 showcase only (8 figures, ~2h)
% mode = 'theorem2_fix'     : re-run only fixed figures (~20min)
% mode = 'quick'            : practical + theorem + appendix + confirm (~1h)
% mode = 'final'            : everything including ODE/T1 validation (~4h)
% mode = 'ser_enhanced'     : auto-tune all algorithms + SER comparison
% mode = 'supplement'       : supplement Groups 1–7 (independent)
% mode = 'supplement_fast'  : Groups 2–7 only (skip slow ODE/PTF)
%
% ALL modes use baseline_2tap channel h=[1, h_2] — consistent with paper.
%
% Recommended workflow for committee review:
%   1. demo_v44_pam4_sa_markov_ptf_complete('paper')   — all paper figures
%   2. demo_v44_pam4_sa_markov_ptf_complete('final')   — full + Theorem 1
%
% default = 'paper'
% ========================================================================

    if nargin < 1 || isempty(mode)
        mode = 'mb_ber_realistic_v68';
    end

    cfg  = build_main_config();
    mc   = build_mc_config(cfg);
    base = build_baselines();
    vars = build_variants(cfg);

    out = struct();
    out.cfg = cfg;
    out.mc  = mc;


    switch lower(mode)
        
        case 'mb_state_track_v68'
            out.mb_track = run_mb_state_track_v69(cfg, vars, base, mc);
            return;

        case 'mb_alpha_sweep_v68'
            out.mb_sweep = run_mb_alpha_sweep_v68(cfg, vars, base, mc);
            return;

        case 'mb_ber_severe_v68'
            out.mb_ber_severe = run_mb_ber_severe_v68(cfg, vars, base, mc);
            return;

        case 'mb_ber_realistic_v68'
            out.mb_ber_realistic = run_mb_ber_realistic_v68(cfg, vars, base, mc);
            return;

        case 'theta_compare_v67'
            out.theta_compare_v67 = run_theta_compare_v67(cfg, vars, base, mc);
            return;

        case 'alpha_sweep_v67'
            out.alpha_sweep = run_alpha_sweep_v67(cfg, vars, base, mc);
            return;

        case 'ber_v67_static'
            out.ber_v67_static = run_ber_v67_static(cfg, vars, base, mc);
            return;

        case 'ber_v67_markov'
            out.ber_v67_markov = run_ber_v67_markov(cfg, vars, base, mc);
            return;

        case 'theta_compare_v66'
            out.theta_compare = run_theta_compare_v66(cfg, vars, base, mc);
            return;

        case 'ber_v66_static'
            out.ber_v66_static = run_ber_v66_static(cfg, vars, base, mc);
            return;

        case 'ber_v66_markov'
            out.ber_v66_markov = run_ber_v66_markov(cfg, vars, base, mc);
            return;

        case 'ber_prefec_severe'
            out.ber_severe = run_ber_realistic_v65(cfg, vars, base, mc);
            return;

        case 'ber_prefec_msbank'
            out.ber_msbank = run_ber_msbank_v62(cfg, vars, base, mc);
            return;

        case 'ber_prefec_compare'
            out.ber_compare = run_ber_compare_v62(cfg, vars, base, mc);
            return;

        case 'ber_prefec_noagc'
            out.ber_noagc = run_ber_noagc_v60(cfg, vars, base, mc);
            return;

        case 'ber_prefec_ho'
            out.ber_prefec_ho = run_ber_prefec_v58(cfg, vars, base, mc);
            return;

        case 'jump_algo2'
            out.jump_algo2 = run_jump_algo2_v53(cfg, vars, base, mc);
            return;

        case 'clr_rates'
            out.clr_rates = run_clr_rates_v55(cfg, vars, mc);
            return;

        case 'ber_prefec'
            out.ber_prefec = run_ber_prefec_v57(cfg, vars, base, mc);
            return;

        case 'ber_prefec_adversarial'
            out.ber_prefec = run_ber_prefec_v56(cfg, vars, base, mc);
            return;

        case 'ber_prefec_static'
            out.ber_prefec = run_ber_prefec_v54(cfg, vars, base, mc);
            return;

        case 'tune'
            out.tuning = run_tuning_protocol(cfg, vars, mc);
            return;
        case 'eye_ber_only'
            % Fast practical-only run:
            %   convergence -> eye -> BER
            % Skip theorem / appendix / confirm / supplement
            out.practical = run_eye_ber_only_package(cfg, vars, base, mc);

        case 'ser_enhanced'
            % ============================================================
            % AUTO-TUNED SER comparison: tunes ALL algorithms, then runs
            % full SER vs SNR on both static and Markov channels.
            % Uses simple 2-tap channel (NOT 802.3) for fair comparison.
            % ============================================================
            ref_snr = 18;   % reference SNR for tuning
            tune_snrs = [9 18 27];  % evaluate at multiple SNR points
            Nt_tune = 12;   % trials per tuning candidate
            Nt_eval = mc.Ntrial_ser;  % trials for final eval

            fprintf('[ser_tuned] Phase 1: Auto-tuning all algorithms at SNR=%s dB...\n', ...
                mat2str(tune_snrs));

            % --- Tune proposed algorithm ---
            cfg_tune = cfg;
            cfg_tune.chan_mode = 'baseline_2tap';
            if isfield(cfg_tune,'std8023'), cfg_tune.std8023.enable = false; end
            cfg_tune.Nsym  = 20000;   % reduced for tuning speed

            best_v = autotune_proposed(cfg_tune, vars, Nt_tune, tune_snrs);
            fprintf('[ser_tuned]   Proposed: mu_max=%.4f, lambda=%.1e, tau_c=%.3f, Tclr=%d\n', ...
                best_v.mu_max, best_v.lambda, best_v.tau_c, best_v.Tclr);

            % --- Tune baselines ---
            best_base = autotune_baselines(cfg_tune, Nt_tune, tune_snrs);
            fprintf('[ser_tuned]   LMS mu=%.4f, NLMS mu=%.4f, RLS lam=%.4f\n', ...
                best_base.mu_lms, best_base.mu_nlms, best_base.lambda_rls);
            fprintf('[ser_tuned]   SM-sign beta=%.4f tau=%.2f, VSS beta0=%.4f\n', ...
                best_base.smsign.beta, best_base.smsign.tau, best_base.smsign_vss.beta0);

            % --- Phase 2: Full SER evaluation ---
            fprintf('[ser_tuned] Phase 2: Running static-channel SER...\n');
            out.ser_static = run_ser_experiment_simple(cfg, best_v, best_base, mc, 'baseline_2tap');

            fprintf('[ser_tuned] Phase 3: Running Markov-channel SER...\n');
            out.ser_markov = run_ser_experiment_simple(cfg, best_v, best_base, mc, 'markov_2tap');

            plot_enhanced_ser_comparison(out.ser_static, out.ser_markov, cfg);
            fprintf('[ser_tuned] Done. Check figures.\n');
            out.tuned_v    = best_v;
            out.tuned_base = best_base;

            % --- Print tuned parameters for copy-paste into build_variants ---
            fprintf('\n=== TUNED PARAMETERS (copy into build_variants) ===\n');
            fprintf('common.mu_max = %.4e;\n', best_v.mu_max);
            fprintf('common.mu_min = %.4e;\n', best_v.mu_min);
            fprintf('common.lambda = %.4e;\n', best_v.lambda);
            fprintf('common.Tclr   = %d;\n', best_v.Tclr);
            if isfield(best_v,'tau_c')
                fprintf('v_practical.tau_c = %.4f;\n', best_v.tau_c);
            end
            fprintf('\nbase.mu_lms    = %.4e;\n', best_base.mu_lms);
            fprintf('base.mu_nlms   = %.4e;\n', best_base.mu_nlms);
            fprintf('base.lambda_rls = %.4f;\n', best_base.lambda_rls);
            fprintf('base.smsign.beta = %.4e;\n', best_base.smsign.beta);
            fprintf('base.smsign.tau  = %.2f;\n', best_base.smsign.tau);
            fprintf('base.smsign_vss.beta0 = %.4e;\n', best_base.smsign_vss.beta0);
            fprintf('base.smsign_vss.tau   = %.2f;\n', best_base.smsign_vss.tau);
            fprintf('=== END TUNED PARAMETERS ===\n');

        case 'theorem2'
            % ============================================================
            % COMPLETE THEOREM 2 SHOWCASE — 8 figures for IEEE Access
            % Uses tuned parameters. Run 'ser_enhanced' first to find them,
            % or uses defaults from build_variants/build_baselines.
            % v49: Increased trials for smoother results
            % ============================================================
            fprintf('[theorem2] Running complete Theorem 2 showcase (8 figures)...\n');
            mc.Ntrial_theorem = 30;  % v49: increased from 10
            out.t2 = run_theorem2_showcase(cfg, vars, base, mc);
            fprintf('[theorem2] All 8 figures generated.\n');

        case 'theorem2_fix'
            % ============================================================
            % RE-RUN ONLY FIXED FIGURES — saves ~90% time
            % Currently: T2-1 (drift) + T2-2 (floor decomposition)
            % Add/remove figures here as needed.
            % ============================================================
            fprintf('[theorem2_fix] Running only fixed figures...\n');
            mc.Ntrial_theorem = 30;

            v = vars.context;
            cfg_t = cfg;
            cfg_t.chan_mode = 'baseline_2tap';
            if isfield(cfg_t,'std8023'), cfg_t.std8023.enable = false; end
            cfg_t.SNRdB = 20;
            Nt = max(mc.Ntrial_theorem, 10);

            fprintf('  [FIX] Fig 1: Corrected drift inequality...\n');
            out.t2_fix.fig1 = t2_fig1_drift_inequality(cfg_t, v, Nt);

            fprintf('  [FIX] Fig 2: Three-part floor decomposition...\n');
            out.t2_fix.fig2 = t2_fig2_floor_decomposition(cfg_t, v, Nt);

            fprintf('[theorem2_fix] Done. Only 2 figures regenerated.\n');

        case 'paper'
            % ============================================================
            % PAPER-READY SUBMISSION MODE — for review committee
            %
            % Runs ALL figures needed for the paper on baseline_2tap:
            %   1. Theorem 2 showcase (8 figures)
            %   2. Practical package (convergence + eye + SER + diagnostics)
            %   3. Appendix (structural ablations, PTF proxy, stress test)
            %
            % ALL experiments use the same 2-tap channel h=[1, h_2].
            % Estimated runtime: ~3 hours (theorem2 ~2h + practical ~1h)
            % ============================================================
            fprintf('[paper] Running complete paper-ready package...\n');
            fprintf('[paper] Channel: baseline_2tap h=[1, h_2]\n');
            fprintf('[paper] All algorithms auto-tuned (params baked in)\n\n');

            % --- Part 1: Theorem 2 showcase (8 figures) ---
            fprintf('====== PART 1/3: Theorem 2 Showcase (8 figures) ======\n');
            mc.Ntrial_theorem = 30;
            out.t2 = run_theorem2_showcase(cfg, vars, base, mc);

            % --- Part 2: Practical package (convergence + eye + SER) ---
            fprintf('\n====== PART 2/3: Practical Package ======\n');
            out.practical = run_practical_package(cfg, vars, base, mc);

            % --- Part 3: Appendix (ablations + PTF + stress) ---
            fprintf('\n====== PART 3/3: Appendix Package ======\n');
            out.appendix  = run_appendix_package(cfg, vars, base, out.practical.rep, mc);

            fprintf('\n[paper] All done. %d figures generated.\n', ...
                8 + 6 + 4);  % approximate figure count

        case 'final'
            assert(isfield(vars,'noise_aware') && isfield(vars.noise_aware,'locked') && vars.noise_aware.locked, ...
                'Noise-aware parameters must be locked before running final mode.');

            out.t1val     = run_theorem1_validation_package(cfg, vars, mc);
            out.practical = run_practical_package(cfg, vars, base, mc);
            out.theorem   = run_theorem_package(cfg, vars, mc);

            out.legacy    = plot_legacy_disturbance_aware_summary(cfg, vars, mc, out.theorem);
            out.floor     = run_floor_summary_package(out.theorem);

            out.appendix  = run_appendix_package(cfg, vars, base, out.practical.rep, mc);
            out.confirm   = run_confirmatory_protocol(cfg, vars, mc);

            mc.Ntrial_theorem = 25;
            out.ode       = run_ode_sanity_package(cfg,vars,mc);
            out.supplement = run_complete_paper_supplement(cfg, vars, base, mc);

        case 'quick'
            % Same as 'final' but SKIPS slow ODE + T1-validation packages.
            % Use this for rapid iteration on practical/theorem results.
            assert(isfield(vars,'noise_aware') && isfield(vars.noise_aware,'locked') && vars.noise_aware.locked, ...
                'Noise-aware parameters must be locked before running quick mode.');

            fprintf('[quick] Skipping run_ode_sanity_package (slow)\n');
            fprintf('[quick] Skipping run_theorem1_validation_package (slow)\n');

            out.practical = run_practical_package(cfg, vars, base, mc);
            out.theorem   = run_theorem_package(cfg, vars, mc);

            out.legacy    = plot_legacy_disturbance_aware_summary(cfg, vars, mc, out.theorem);
            out.floor     = run_floor_summary_package(out.theorem);

            out.appendix  = run_appendix_package(cfg, vars, base, out.practical.rep, mc);
            out.confirm   = run_confirmatory_protocol(cfg, vars, mc);

        case 'supplement'
            % Run ONLY the complete paper supplement (Groups 1–7).
            % Independent of the main packages — no prior outputs needed.
            % Group 1 (ODE + PTF) is included; use 'supplement_fast' to skip.
            mc.Ntrial_theorem = 25;
            out.supplement = run_complete_paper_supplement(cfg, vars, base, mc);

        case 'supplement_fast'
            % Run supplement but SKIP Group 1 (ODE sanity + PTF scaling).
            % This is the fastest way to generate Groups 2–7 figures.
            mc.Ntrial_theorem = 25;
            out.supplement = run_supplement_skip_group1(cfg, vars, base, mc);
    end
            % robust summary call
            
            %print_summary(out.ode, out.practical, out.theorem, out.appendix, out.confirm);

end

%% =====================================================================
% CONFIGURATION
%% =====================================================================
