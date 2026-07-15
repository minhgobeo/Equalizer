function pkg = run_state_separation_sweep(cfg, vars, base, mc)
%RUN_STATE_SEPARATION_SWEEP Robustness sweep for Assumption A12.
%
% v57 implementation (full):
%   For each h2 state library [0.50-d, 0.50, 0.50+d] with d in sep_list, run
%   Algorithm 6 in Markov mode and measure HMM accuracy + BER. We use the
%   realistic transition matrix P (slow switching) so the sensitivity is
%   driven primarily by the state separation rather than dwell time.
%
% Reviewer answer: identifies the practical separation threshold above
% which HMM routing maintains high accuracy.

sep_list = [0.025 0.05 0.10 0.15 0.20];
snr_list = [18 22 26];
Ntrial = max(10, min(30, mc.Ntrial_ser));

acc_grid = nan(numel(sep_list), numel(snr_list));
ber_grid = nan(numel(sep_list), numel(snr_list));
ber_oracle_grid = nan(numel(sep_list), numel(snr_list));
ber_alg5_grid   = nan(numel(sep_list), numel(snr_list));

msb_params = default_msb_params_v69();

% Realistic-style transition matrix kept fixed across separations.
P_realistic = [0.99 0.01 0.00; 0.005 0.99 0.005; 0.00 0.01 0.99];

for ki = 1:numel(sep_list)
    d_sep = sep_list(ki);
    h2_lib = [0.50-d_sep, 0.50, 0.50+d_sep];

    cfg_p = reviewer_set_regime(cfg, 'realistic');
    cfg_p.markov.h2_states = h2_lib;
    cfg_p.markov.P = P_realistic;

    v_base = make_v_alg5(vars.theorem);
    Kffe = cfg_p.Nf; L = cfg_p.Nb; main_idx = round((Kffe+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    for si = 1:numel(snr_list)
        snr_db = snr_list(si);
        ser_tmp = zeros(Ntrial,1);
        ser_orc_tmp = zeros(Ntrial,1);
        ser_a5_tmp = zeros(Ntrial,1);
        acc_tmp = zeros(Ntrial,1);

        for t=1:Ntrial
            rng(950000 + 1000*ki + 100*si + t);
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r_clean, ch_state] = channel_out(d, cfg_run);
            [r,~] = add_noise_dispatch(r_clean, cfg_run);

            [dh, diag_msb] = algorithm6_msb_v69(r, d, cfg_run, v_base, msb_params, []);
            [dh_orc,~]     = algorithm6_msb_v69(r, d, cfg_run, v_base, msb_params, ch_state.state);
            [dh_a5,~]      = algorithm5_singlebank(r, d, cfg_run, v_base);

            post_idx = (cfg_run.trainLen + diag_msb.N_sep + 1):cfg_run.Nsym;
            [~, best_acc] = msb_state_accuracy(diag_msb.s_hat_hist, ch_state.state, post_idx);
            ser_tmp(t)     = ser_after_training_aligned(d, dh,     cfg_run);
            ser_orc_tmp(t) = ser_after_training_aligned(d, dh_orc, cfg_run);
            ser_a5_tmp(t)  = ser_after_training_aligned(d, dh_a5,  cfg_run);
            acc_tmp(t) = best_acc;
        end
        ber_grid(ki,si)        = mean(ser_tmp)/log2(cfg_p.M);
        ber_oracle_grid(ki,si) = mean(ser_orc_tmp)/log2(cfg_p.M);
        ber_alg5_grid(ki,si)   = mean(ser_a5_tmp)/log2(cfg_p.M);
        acc_grid(ki,si)        = mean(acc_tmp);
        fprintf('[state_sep] sep=%.3f SNR=%d -> acc=%.2f%%, BER alg6=%.3e oracle=%.3e alg5=%.3e\n', ...
            d_sep, snr_db, 100*acc_grid(ki,si), ber_grid(ki,si), ber_oracle_grid(ki,si), ber_alg5_grid(ki,si));
    end
end

pkg.sep_list        = sep_list;
pkg.snr_list        = snr_list;
pkg.acc_grid        = acc_grid;
pkg.ber_grid        = ber_grid;
pkg.ber_oracle_grid = ber_oracle_grid;
pkg.ber_alg5_grid   = ber_alg5_grid;
pkg.Ntrial          = Ntrial;
pkg.note = 'h2 library = [0.5-d, 0.5, 0.5+d]; P realistic; SNR sweep.';

fprintf('\nTABLE STATE-SEP. HMM accuracy and BER vs h2 separation.\n');
fprintf('sep\\SNR ');
for si=1:numel(snr_list); fprintf('%8d dB ', snr_list(si)); end
fprintf('\n');
for ki=1:numel(sep_list)
    fprintf('%4.3f   ', sep_list(ki));
    for si=1:numel(snr_list)
        fprintf('  acc=%.0f%% BER=%.1e ', 100*acc_grid(ki,si), ber_grid(ki,si));
    end
    fprintf('\n');
end
end
