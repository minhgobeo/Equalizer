function pkg = run_liu_ss_lms_direct_adapter(cfg, vars, base, mc)
%RUN_LIU_SS_LMS_DIRECT_ADAPTER  Liu et al. 2023 SS-LMS DFE baseline (algorithmic).
%
% Runs two Liu-style baselines under the same Markov-DD testbed used by
% Algorithm 2:
%
%   1. SS-LMS-DFE       : sign-sign LMS tap adaptation, fixed PAM4 thresholds.
%   2. TA-SS-LMS-DFE    : same SS-LMS tap update plus adaptive PAM4 thresholds
%                         via per-level running means (auxiliary-sampler proxy).
%
% Source (algorithmic reimplementation, NOT circuit-level):
%   X. Liu, Z. Li, H. Wen, M. Miao, Y. Wang, Z. Wang, "A PAM4 transceiver
%   design scheme with threshold adaptive and tap adaptive," EURASIP J. Adv.
%   Signal Process., vol. 2023, no. 70, 2023.
%
% IMPORTANT — what this runner does NOT reproduce from Liu et al.:
%   * 3-stage CTLE (mid / high / low frequency analog peaking)
%   * VGA, SatAmp, CDR
%   * Half-rate half-interleaved sampler architecture
%   * Auxiliary samplers as physical comparators
% Only the algorithmic adaptation rules are evaluated. The IEEE 802.3-inspired
% PAM4 testbed is the same as for the rest of this paper.

regimes  = {'severe','realistic'};
snr_list = [14 18 22 26];
Ntrial   = max(20, min(40, mc.Ntrial_ser));

BER_sslms   = nan(numel(snr_list), numel(regimes));
BER_tasslms = nan(numel(snr_list), numel(regimes));
BER_alg2    = nan(numel(snr_list), numel(regimes));

msb_params = default_msb_params_v69();

for rg = 1:numel(regimes)
    cfg_p0 = reviewer_set_regime(cfg, regimes{rg});
    % Liu et al. use a 4-tap DFE. For this Liu-style adapter, evaluate
    % all methods in this local runner with the same 4 feedback taps.
    cfg_p0.Nb = 4;

    v_base = make_v_alg5(vars.theorem);
    Kffe = cfg_p0.Nf; L = cfg_p0.Nb; main_idx = round((Kffe+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    for si = 1:numel(snr_list)
        ser_ss = zeros(Ntrial,1);
        ser_ta = zeros(Ntrial,1);
        ser_a2 = zeros(Ntrial,1);

        for t = 1:Ntrial
            rng(995000 + 1000*rg + 100*si + t);
            cfg_p = cfg_p0; cfg_p.SNRdB = snr_list(si);
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean,~] = channel_out(d, cfg_p);
            [r,~]       = add_noise_dispatch(r_clean, cfg_p);

            % SS-LMS DFE (no threshold adaptation)
            opts1 = struct('adaptive_threshold', false, 'update_ffe', false, ...
                           'update_dfe', true, 'mu_f', 2e-3, ...
                           'use_projection', true);
            [~, dh_ss, ~] = dfe_ss_lms_pam4(r, d, cfg_p, v_base, opts1);

            % TA-SS-LMS DFE (threshold adaptation enabled)
            opts2 = struct('adaptive_threshold', true, 'update_ffe', false, ...
                           'update_dfe', true, 'mu_f', 2e-3, ...
                           'mu_thr', 2e-3, 'use_projection', true);
            [~, dh_ta, ~] = dfe_ss_lms_pam4(r, d, cfg_p, v_base, opts2);

            % Algorithm 2 reference
            [dh_a2, ~] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);

            ser_ss(t) = ser_after_training_aligned(d, dh_ss, cfg_p);
            ser_ta(t) = ser_after_training_aligned(d, dh_ta, cfg_p);
            ser_a2(t) = ser_after_training_aligned(d, dh_a2, cfg_p);
        end

        BER_sslms(si,rg)   = mean(ser_ss) / log2(cfg_p0.M);
        BER_tasslms(si,rg) = mean(ser_ta) / log2(cfg_p0.M);
        BER_alg2(si,rg)    = mean(ser_a2) / log2(cfg_p0.M);

        fprintf('[liu_ss_lms] %s SNR=%2d -> SS-LMS=%.3e, TA-SS-LMS=%.3e, Alg2=%.3e\n', ...
            regimes{rg}, snr_list(si), ...
            BER_sslms(si,rg), BER_tasslms(si,rg), BER_alg2(si,rg));
    end
end

pkg = struct();
pkg.regimes     = regimes;
pkg.snr_list    = snr_list;
pkg.BER_sslms   = BER_sslms;
pkg.BER_tasslms = BER_tasslms;
pkg.BER_alg2    = BER_alg2;
pkg.tag         = 'Liu_SS_LMS_DFE_adapted';
pkg.note        = ['Algorithmic re-implementation of Liu et al. 2023 (EURASIP JASP) ' ...
                   'SS-LMS DFE and threshold-adaptive variant. NOT a circuit-level ' ...
                   'reproduction (no CTLE, VGA, SatAmp, CDR, half-rate samplers).'];
pkg.citation    = ['X. Liu et al., "A PAM4 transceiver design scheme with threshold ' ...
                   'adaptive and tap adaptive," EURASIP J. Adv. Signal Process., 2023:70.'];

fprintf('\nTABLE LIU. Liu-style SS-LMS DFE baselines vs Algorithm 2.\n');
fprintf('%-10s %-6s %-12s %-14s %-12s\n', 'Regime','SNR','SS-LMS','TA-SS-LMS','Alg2 (prop.)');
for rg = 1:numel(regimes)
    for si = 1:numel(snr_list)
        fprintf('%-10s %-6.0f %-12.3e %-14.3e %-12.3e\n', ...
            regimes{rg}, snr_list(si), ...
            BER_sslms(si,rg), BER_tasslms(si,rg), BER_alg2(si,rg));
    end
end
end
