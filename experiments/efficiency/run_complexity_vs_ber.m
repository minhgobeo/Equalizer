function pkg = run_complexity_vs_ber(cfg, vars, base, mc)
%RUN_COMPLEXITY_VS_BER  Trade-off study: BER versus MAC count per symbol.
%
% v57 fix:
%   * S=1 path now skips Markov simulation and uses a frozen-channel mode
%     (chan_mode='baseline_2tap') because a 1-state Markov chain is
%     degenerate and previously caused a divide-by-zero in P-matrix
%     construction.
%   * h2_states and P are kept row-vector / square-matrix in shape; both
%     are also reset together so they are always size-consistent with S.

S_list   = [1 2 3 5];
snr_list = [18 22 26];
regimes  = {'severe','realistic'};
Ntrial   = max(10, min(20, mc.Ntrial_ser));

ber_grid = nan(numel(S_list), numel(snr_list), numel(regimes));
mac_per_sym = nan(numel(S_list),1);

% Reference Algorithm 5 / NLMS for the same SNR points.
ber_alg5_grid = nan(numel(snr_list), numel(regimes));
ber_nlms_grid = nan(numel(snr_list), numel(regimes));

msb_params = default_msb_params_v69();

for ki = 1:numel(S_list)
    S = S_list(ki);

    for rg = 1:numel(regimes)
        cfg_p0 = reviewer_set_regime(cfg, regimes{rg});

        if S == 1
            % Degenerate single-state case: use baseline_2tap with the
            % regime's centre h2.
            h2_centre = cfg_p0.markov.h2_states(2);
            cfg_p0.chan_mode = 'baseline_2tap';
            cfg_p0.h_isi = [1 h2_centre];
            cfg_p0 = rmfield(cfg_p0,'markov');
            % Re-add a placeholder markov.h2_states for the algorithm
            % to size its banks; algorithm 6 with 1 bank degenerates to
            % a single FFE+DFE filter.
            cfg_p0.markov.h2_states = h2_centre;
            cfg_p0.markov.P = 1;
            cfg_p0.markov.init_state = 1;
            cfg_p0.markov.fixed_state = 1;
        else
            % S>=2: build a P matrix and h2 library of size S that match.
            diag_val = mean(diag(cfg_p0.markov.P));
            cfg_p0.markov.P = build_uniform_diag_P(S, diag_val);
            cfg_p0.markov.h2_states = build_h2_lib_resize(S, cfg_p0.markov.h2_states);
            cfg_p0.markov.init_state = max(1, min(S, round(S/2)));
            cfg_p0.markov.fixed_state = cfg_p0.markov.init_state;
        end

        for si = 1:numel(snr_list)
            snr_db = snr_list(si);
            ser_t = zeros(Ntrial,1);
            for t=1:Ntrial
                rng(992000 + 100*ki + 10*rg + t);
                cfg_p = cfg_p0; cfg_p.SNRdB = snr_db;
                sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
                d = cfg_p.A(sym_idx).'; d = d(:);
                [rc,~] = channel_out(d, cfg_p);
                [r,~] = add_noise_dispatch(rc, cfg_p);

                v_base = make_v_alg5(vars.theorem);
                Kffe = cfg_p.Nf; L = cfg_p.Nb; main_idx = round((Kffe+1)/2);
                v_base.main_idx = main_idx;
                ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
                ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
                v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
                v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

                [dh, ~] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);
                ser_t(t) = ser_after_training_aligned(d, dh, cfg_p);
            end
            ber_grid(ki,si,rg) = mean(ser_t)/log2(cfg_p0.M);
            fprintf('[complexity] S=%d %s SNR=%d -> BER=%.3e\n', S, regimes{rg}, snr_db, ber_grid(ki,si,rg));
        end
    end

    % MAC estimate per symbol:
    %   Per step: S banks * (FFE+DFE filter Kffe+L MACs + same-size update)
    %             + S*S HMM transition + S likelihood scoring.
    Kffe = cfg.Nf; L = cfg.Nb;
    mac_per_sym(ki) = S * 2 * (Kffe + L) + S * S + S;
end

% Reference: NLMS and Alg5 at the same SNR points (with the unmodified
% per-regime cfg, so they are not affected by S sweep).
for rg = 1:numel(regimes)
    cfg_p0 = reviewer_set_regime(cfg, regimes{rg});
    for si = 1:numel(snr_list)
        snr_db = snr_list(si);
        ser_a5 = zeros(Ntrial,1);
        ser_nl = zeros(Ntrial,1);
        v_base = make_v_alg5(vars.theorem);
        Kffe = cfg_p0.Nf; L = cfg_p0.Nb; main_idx = round((Kffe+1)/2);
        v_base.main_idx = main_idx;
        ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
        ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
        v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
        v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];
        for t=1:Ntrial
            rng(993000 + 100*rg + 10*si + t);
            cfg_p = cfg_p0; cfg_p.SNRdB = snr_db;
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [rc,~] = channel_out(d, cfg_p);
            [r,~]  = add_noise_dispatch(rc, cfg_p);
            [dh_a5,~] = algorithm5_singlebank(r, d, cfg_p, v_base);
            [~, dh_nl] = dfe_nlms_unified_x(r, d, cfg_p, base);
            ser_a5(t) = ser_after_training_aligned(d, dh_a5, cfg_p);
            ser_nl(t) = ser_after_training_aligned(d, dh_nl, cfg_p);
        end
        ber_alg5_grid(si,rg) = mean(ser_a5)/log2(cfg_p0.M);
        ber_nlms_grid(si,rg) = mean(ser_nl)/log2(cfg_p0.M);
    end
end

pkg.S_list = S_list;
pkg.snr_list = snr_list;
pkg.regimes = regimes;
pkg.ber_grid = ber_grid;
pkg.ber_alg5_grid = ber_alg5_grid;
pkg.ber_nlms_grid = ber_nlms_grid;
pkg.mac_per_sym = mac_per_sym;

% Pretty-print table at central SNR.
si0 = ceil(numel(snr_list)/2);
fprintf('\nTABLE COMPLEXITY. BER vs MAC budget at SNR=%d dB.\n', snr_list(si0));
fprintf('%-6s %-12s %-12s %-12s\n', 'S', 'MACs/sym', 'BER severe', 'BER realistic');
for ki=1:numel(S_list)
    fprintf('%-6d %-12d %-12.3e %-12.3e\n', S_list(ki), mac_per_sym(ki), ...
        ber_grid(ki,si0,1), ber_grid(ki,si0,2));
end
fprintf('NLMS reference (same SNR): severe %.3e, realistic %.3e\n', ...
    ber_nlms_grid(si0,1), ber_nlms_grid(si0,2));
end

% =====================================================================
function lib = build_h2_lib_resize(S, ref_lib)
% Resize the regime's reference h2 library to S elements, preserving
% midpoint and total spread. Always returns a row vector.
ref_lib = ref_lib(:).';
if numel(ref_lib) == S
    lib = ref_lib;
    return;
end
mid = mean(ref_lib);
spread = max(ref_lib) - min(ref_lib);
if spread <= 0, spread = 0.20; end
lib = mid + (spread/2) * linspace(-1, 1, S);
end

% =====================================================================
function P = build_uniform_diag_P(S, diag_val)
% Markov P with uniform off-diagonal mass. S>=2 only.
if S < 2
    P = 1; return;
end
P = zeros(S);
for i=1:S
    off = ones(1,S); off(i) = 0;
    off = off / sum(off) * (1 - diag_val);
    P(i,:) = off; P(i,i) = diag_val;
end
end
