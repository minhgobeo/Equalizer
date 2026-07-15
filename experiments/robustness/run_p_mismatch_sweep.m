function pkg = run_p_mismatch_sweep(cfg, vars, base, mc)
%RUN_P_MISMATCH_SWEEP Robustness of HMM routing to P-misspecification.
%
% v57 implementation (full):
%   The channel uses cfg.markov.P (true P).
%   The HMM filter inside Algorithm 6 uses msb_params.P_assumed.
%   We sweep msb_params.P_assumed over a list of diagonal values and
%   measure: (1) HMM state accuracy, (2) Algorithm-6 SER/BER.
%
% Reviewer answer: shows whether the receiver still tracks correctly when
% the diagonal of the assumed transition matrix differs from the truth.
%
% Default sweep:
%   regime: severe and realistic
%   true_diag    = 0.99 (realistic) and 0.95 (severe)   [taken from regime]
%   assumed_diag = [0.80 0.90 0.95 0.99 0.999]
% SNR fixed at a single representative point per regime.

regimes = {'severe','realistic'};
assumed_diag_list = [0.80 0.90 0.95 0.99 0.999];
snr_per_regime = struct('severe',22,'realistic',22);
Ntrial = max(10, min(30, mc.Ntrial_ser));

acc_grid = nan(numel(assumed_diag_list), numel(regimes));
ser_grid = nan(numel(assumed_diag_list), numel(regimes));
ber_grid = nan(numel(assumed_diag_list), numel(regimes));
ser_oracle_ref = nan(numel(regimes),1);

msb_params = default_msb_params_v69();

for rg = 1:numel(regimes)
    cfg_p = reviewer_set_regime(cfg, regimes{rg});
    cfg_p.SNRdB = snr_per_regime.(regimes{rg});

    v_base = make_v_alg5(vars.theorem);
    Kffe = cfg_p.Nf; L = cfg_p.Nb; main_idx = round((Kffe+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    P_true = cfg_p.markov.P;
    S = size(P_true,1);

    % Reference: oracle (perfect P).
    ser_orc_tmp = zeros(Ntrial,1);
    for t=1:Ntrial
        rng(940000 + 1000*rg + t);
        sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
        d = cfg_p.A(sym_idx).'; d = d(:);
        [r_clean, ch_state] = channel_out(d, cfg_p);
        [r,~] = add_noise_dispatch(r_clean, cfg_p);
        msb_orc = msb_params; msb_orc.P_assumed = [];     % match truth
        [dh_orc,~] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_orc, ch_state.state);
        ser_orc_tmp(t) = ser_after_training_aligned(d, dh_orc, cfg_p);
    end
    ser_oracle_ref(rg) = mean(ser_orc_tmp);

    for ki = 1:numel(assumed_diag_list)
        diag_val = assumed_diag_list(ki);
        % Build P_assumed by snapping each diagonal to diag_val and
        % redistributing the off-diagonal mass uniformly to its neighbours.
        P_assumed = build_P_with_diag(P_true, diag_val);

        msb_run = msb_params; msb_run.P_assumed = P_assumed;

        ser_tmp = zeros(Ntrial,1); acc_tmp = zeros(Ntrial,1);
        for t = 1:Ntrial
            rng(940000 + 1000*rg + 100*ki + t);
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ch_state] = channel_out(d, cfg_p);
            [r,~] = add_noise_dispatch(r_clean, cfg_p);

            [dh, diag_msb] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_run, []);
            post_idx = (cfg_p.trainLen + diag_msb.N_sep + 1):cfg_p.Nsym;
            [~, best_acc] = msb_state_accuracy(diag_msb.s_hat_hist, ch_state.state, post_idx);
            ser_tmp(t) = ser_after_training_aligned(d, dh, cfg_p);
            acc_tmp(t) = best_acc;
        end
        ser_grid(ki,rg) = mean(ser_tmp);
        ber_grid(ki,rg) = ser_grid(ki,rg)/log2(cfg_p.M);
        acc_grid(ki,rg) = mean(acc_tmp);

        fprintf('[p_mismatch] %s assumed_diag=%.3f -> acc(best)=%.2f%%, BER=%.3e\n', ...
            regimes{rg}, diag_val, 100*acc_grid(ki,rg), ber_grid(ki,rg));
    end
end

pkg.regimes = regimes;
pkg.assumed_diag_list = assumed_diag_list;
pkg.snr_per_regime = snr_per_regime;
pkg.acc_grid = acc_grid;
pkg.ser_grid = ser_grid;
pkg.ber_grid = ber_grid;
pkg.ser_oracle_ref = ser_oracle_ref;
pkg.Ntrial = Ntrial;

fprintf('\nTABLE P-MISMATCH. Algorithm 6 BER vs HMM-assumed diagonal.\n');
fprintf('Regime                ');
for ki=1:numel(assumed_diag_list)
    fprintf('|  diag=%.3f  ', assumed_diag_list(ki));
end
fprintf('| OracleP-BER\n');
for rg=1:numel(regimes)
    fprintf('%-10s SNR=%2d dB ', regimes{rg}, snr_per_regime.(regimes{rg}));
    for ki=1:numel(assumed_diag_list)
        fprintf('|  %.3e ', ber_grid(ki,rg));
    end
    fprintf('|  %.3e\n', ser_oracle_ref(rg)/log2(cfg.M));
end
end

% =====================================================================
function P_out = build_P_with_diag(P_in, diag_val)
%BUILD_P_WITH_DIAG Replace each diagonal entry of P_in with diag_val and
% rescale the corresponding off-diagonal row preserving relative structure.
S = size(P_in,1);
P_out = zeros(S);
for i=1:S
    row = P_in(i,:);
    off = row; off(i) = 0;
    s_off = sum(off);
    if s_off <= 0
        % fallback: spread uniformly to neighbours
        off = ones(1,S); off(i) = 0; s_off = sum(off);
    end
    new_off = (1 - diag_val) * (off / s_off);
    P_out(i,:) = new_off;
    P_out(i,i) = diag_val;
end
end
