function pkg = run_markov_source_profile(cfg, vars, base, mc)
%RUN_MARKOV_SOURCE_PROFILE  Off-design Markov transition profile.
%
% v60 honesty fix:
%   The previous version called this "source-grounded" without citing the
%   source. That is academic misrepresentation and would be caught by any
%   careful reviewer. This rewrite:
%     1. Drops the unsupported "source-grounded" label.
%     2. Runs TWO additional transition matrices that are visibly
%        different from the symmetric tridiagonal P used in the hero
%        Markov regimes. The point is to show insensitivity of
%        Algorithm 6 to the exact P shape, NOT to claim a measured
%        SerDes channel.
%     3. The h2 amplitude library is the same controlled DFE-stress
%        levels used elsewhere in the paper.
%
% The user is expected to add a SPECIFIC citation in the paper text if
% they want to claim either matrix is from a particular MJS paper.

fprintf('\n[markov_source_profile] Off-design Markov transition matrices.\n');
fprintf('[markov_source_profile] NOT measured channels; not "source-grounded" without a citation in the paper.\n');

% Matrix A: asymmetric tridiagonal (state 1 sticks longer than state 3)
P_A = [0.5 0.4 0.1; ...
       0.2 0.5 0.3; ...
       0.3 0.3 0.4];

% Matrix B: dense, low-diagonal (frequent switching) -- stress test
P_B = [0.6 0.3 0.1; ...
       0.3 0.4 0.3; ...
       0.1 0.3 0.6];

P_set = {P_A, P_B};
P_labels = {'P_A_asym','P_B_dense'};

snr_list = [18 22 26];
Ntrial = max(10, min(20, mc.Ntrial_ser));

cfg_p0 = cfg;
cfg_p0.chan_mode = 'markov_2tap';
cfg_p0.Nsym = 80000;
cfg_p0.trainLen = 8000;
cfg_p0.Nf = 5;
cfg_p0.Nb = 1;
cfg_p0.D = 2;
cfg_p0.markov.h2_states = [0.30 0.50 0.70];
cfg_p0.markov.init_state = 2;

v_base = make_v_alg5(vars.theorem);
Kffe = cfg_p0.Nf; L = cfg_p0.Nb;
main_idx = round((Kffe+1)/2);
v_base.main_idx = main_idx;
ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];
msb_params = default_msb_params_v69();

ser_alg6 = zeros(numel(snr_list), numel(P_set));
ser_orc  = zeros(numel(snr_list), numel(P_set));
ser_alg5 = zeros(numel(snr_list), numel(P_set));
acc_alg6 = zeros(numel(snr_list), numel(P_set));

for pi = 1:numel(P_set)
    cfg_p0.markov.P = P_set{pi};
    fprintf('\n[markov_source_profile] === %s ===\n', P_labels{pi});
    disp(P_set{pi});

    for si = 1:numel(snr_list)
        cfg_p = cfg_p0;
        cfg_p.SNRdB = snr_list(si);
        tmp6 = zeros(Ntrial,1); tmpo = zeros(Ntrial,1);
        tmp5 = zeros(Ntrial,1); tmpa = zeros(Ntrial,1);

        for t = 1:Ntrial
            rng(990000 + 10000*pi + 100*si + t);
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ch_state] = channel_out(d, cfg_p);
            [r,~] = add_noise_dispatch(r_clean, cfg_p);

            [dh6, diag6] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);
            [dho, ~]     = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, ch_state.state);
            [dh5, ~]     = algorithm5_singlebank(r, d, cfg_p, v_base);

            tmp6(t) = ser_after_training_aligned(d, dh6, cfg_p);
            tmpo(t) = ser_after_training_aligned(d, dho, cfg_p);
            tmp5(t) = ser_after_training_aligned(d, dh5, cfg_p);
            post_idx = (cfg_p.trainLen + diag6.N_sep + 1):cfg_p.Nsym;
            tmpa(t) = msb_state_accuracy(diag6.s_hat_hist, ch_state.state, post_idx);
        end
        ser_alg6(si,pi) = mean(tmp6);
        ser_orc(si,pi)  = mean(tmpo);
        ser_alg5(si,pi) = mean(tmp5);
        acc_alg6(si,pi) = mean(tmpa);
        fprintf('[%s] SNR=%2d | acc=%5.2f%% | BER Alg6=%.3e, Oracle=%.3e, Alg5=%.3e\n', ...
            P_labels{pi}, cfg_p.SNRdB, 100*acc_alg6(si,pi), ...
            ser_alg6(si,pi)/log2(cfg_p.M), ser_orc(si,pi)/log2(cfg_p.M), ser_alg5(si,pi)/log2(cfg_p.M));
    end
end

pkg = struct();
pkg.snr_list = snr_list;
pkg.P_set = P_set;
pkg.P_labels = P_labels;
pkg.h2_states = cfg_p0.markov.h2_states;
pkg.SER_alg6 = ser_alg6;
pkg.SER_oracle = ser_orc;
pkg.SER_alg5 = ser_alg5;
pkg.BER_alg6 = ser_alg6/log2(cfg_p0.M);
pkg.BER_oracle = ser_orc/log2(cfg_p0.M);
pkg.BER_alg5 = ser_alg5/log2(cfg_p0.M);
pkg.hmm_accuracy = acc_alg6;
pkg.Ntrial = Ntrial;
pkg.note = ['Two off-design Markov P matrices for sensitivity testing. NOT claimed ' ...
            'as measured SerDes channels and NOT claimed as source-grounded ' ...
            'without an explicit citation in the paper. The h2 amplitude library ' ...
            'is the same controlled DFE-stress levels used elsewhere.'];

fprintf('\nTABLE MS. Off-design Markov P matrix sensitivity\n');
for pi = 1:numel(P_set)
    fprintf('\n--- %s ---\n', P_labels{pi});
    fprintf('%6s %10s %10s %10s %9s\n', 'SNR', 'Alg6 BER', 'Oracle', 'Alg5', 'Acc');
    for si = 1:numel(snr_list)
        fprintf('%6.0f %10.3e %10.3e %10.3e %8.2f%%\n', snr_list(si), ...
            pkg.BER_alg6(si,pi), pkg.BER_oracle(si,pi), pkg.BER_alg5(si,pi), 100*acc_alg6(si,pi));
    end
end
end
