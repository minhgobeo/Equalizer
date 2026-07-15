% Auto-split from NCKH_v53.m (original line 11971).
% Folder: experiments/paper_main

function pkg = run_mb_ber_compare(cfg_p, vars, base, mc, tag, snr_list)
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end

    v_base = make_v_alg5(vars.theorem);
    K = cfg_p.Nf; L = cfg_p.Nb;
    main_idx = round((K+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(K,1); ffe_max = v_base.w2_max*ones(K,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    % v72 INTEGRATION — choose params source via env-like flag
    if isfield(cfg_p, 'use_v72_adaptive') && cfg_p.use_v72_adaptive
        msb_params = default_msb_params_v72();
        msb_params.use_adaptive_tau = true;
        if isfield(cfg_p, 'tau_calib_override')
            msb_params.tau_calib = cfg_p.tau_calib_override;
        end
    else
        msb_params = default_msb_params_v69();
    end 

    Nsnr = numel(snr_list);
    Nalg = 10;
    BER = zeros(Nsnr, Nalg);
    err_count = zeros(Nsnr, Nalg);

    Nt = max(mc.Ntrial_ser, 20);
    if isfield(cfg_p, 'force_trials') && ~isempty(cfg_p.force_trials)
        Nt = cfg_p.force_trials;
    end
    fprintf('[%s] Algorithm 2 vs baselines, %d trials, %d SNR pts\n', tag, Nt, Nsnr);

    N_postTrain = cfg_p.Nsym - cfg_p.trainLen;
    total_bits = N_postTrain * Nt * log2(cfg_p.M);
    bit_floor = 1 / total_bits;
    h2_nom = cfg_p.markov.h2_states(min(2, numel(cfg_p.markov.h2_states)));
    [chen_w_ffe, chen_w_dfe] = local_mb_pulse_inverse_ffedfe([1 h2_nom], cfg_p.Nf, cfg_p.Nb, cfg_p.D);

    for t = 1:Nt
        for si = 1:Nsnr
            snr_db = snr_list(si);
            rng(80000 + 100*si + t);

            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean, ch_state] = channel_out(d, cfg_p);
            cfg_run = cfg_p; cfg_run.SNRdB = snr_db;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
            if isfield(cfg_run, 'twochain') && isfield(cfg_run.twochain, 'enable') && cfg_run.twochain.enable
                [r, sigma2] = local_apply_twochain_disturbance(r, r_clean, ch_state, cfg_run, sigma2);
            end

            % v72 INTEGRATION — route to adaptive variant if flag is set
            if isfield(msb_params, 'use_adaptive_tau') && msb_params.use_adaptive_tau
                [dh1, ~] = algorithm6_msb_v72_adaptive_tau(r, d, cfg_run, v_base, msb_params, []);
                [dh2, ~] = algorithm6_msb_v72_adaptive_tau(r, d, cfg_run, v_base, msb_params, ch_state.state);
            else
                [dh1, ~] = algorithm6_msb_v69(r, d, cfg_run, v_base, msb_params, []);
                [dh2, ~] = algorithm6_msb_v69(r, d, cfg_run, v_base, msb_params, ch_state.state);
            end
            
            % Algorithm 1 single-bank
            [dh3, ~] = algorithm5_singlebank(r, d, cfg_run, v_base);
            % NLMS
            [~, dh4] = dfe_nlms_unified_x(r, d, cfg_run, base);
            % SM-sign-NLMS VSS
            [~, dh5] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_run, base, sigma2);
            % SM-sign-NLMS
            [~, dh6] = dfe_smsign_nlms_unified_x    (r, d, cfg_run, base, sigma2);
            % SMNLMS
            [~, dh7] = dfe_smnlms_unified_x(r, d, cfg_run, base, sigma2);
            % Liu-style SS-LMS DFE
            cfg_liu = cfg_run;
            v_liu = v_base;
            if numel(v_liu.theta_min) ~= cfg_liu.Nf + cfg_liu.Nb
                v_liu.theta_min = [v_base.theta_min(1:cfg_run.Nf); -v_base.b_max*ones(cfg_liu.Nb,1)];
                v_liu.theta_max = [v_base.theta_max(1:cfg_run.Nf);  v_base.b_max*ones(cfg_liu.Nb,1)];
            end
            opts_liu = struct('adaptive_threshold', true, 'update_ffe', false, ...
                              'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, ...
                              'use_projection', true);
            [~, dh8] = dfe_ss_lms_pam4(r, d, cfg_liu, v_liu, opts_liu);
            % Chen-style nominal pulse-reference FFE/DFE
            dh9 = local_mb_fixed_ffedfe_slicer(r, chen_w_ffe, chen_w_dfe, cfg_run.D, cfg_run.A);
            % Cui-style lightweight HMM classifier adapted to PAM4
            dh10 = local_mb_cui_centroid_hmm(r, d, cfg_run);

            dhs = {dh1, dh2, dh3, dh4, dh5, dh6, dh7, dh8, dh9, dh10};
            for a = 1:Nalg
                ser_val = ser_after_training_aligned(d, dhs{a}, cfg_run);
                BER(si, a) = BER(si, a) + ser_val / log2(cfg_p.M);
                err_count(si, a) = err_count(si, a) + ser_val * N_postTrain;
            end
        end
        if mod(t,4)==0, fprintf('  [%s] trial %d/%d\n', tag, t, Nt); end
    end
    BER = BER / Nt;

    names = {'Algorithm 2 (proposed HMM-MSB)', 'Oracle MSB (printed only)', ...
             'Algorithm 1 (single-bank)', 'NLMS', ...
             'SM-sign-NLMS VSS', 'SM-sign-NLMS', ...
             'SMNLMS', 'Liu SS-LMS', 'Chen pulse-ref', 'Cui HMM adapted'};

    fprintf('\n[%s] BER table:\n', tag);
    fprintf('  SNR ');
    for a = 1:Nalg, fprintf('%24s ', names{a}); end
    fprintf('\n');
    for si = 1:Nsnr
        fprintf('  %2d  ', snr_list(si));
        for a = 1:Nalg
            if err_count(si, a) < 0.5
                fprintf('%24s ', sprintf('<%.1e', bit_floor));
            else
                fprintf('%24.3e ', BER(si, a));
            end
        end
        fprintf('\n');
    end

    fprintf('\n[%s] Algorithm 2 vs key baselines (max ratio):\n', tag);
    for a = [3 4 7 8 9 10]   % vs key baselines
        max_r = 0;
        for si = 1:Nsnr
            if BER(si,1) > 0 && BER(si,a) > 0
                rr = BER(si,a) / BER(si,1);
                if rr > max_r, max_r = rr; end
            end
        end
        fprintf('  %s / Algorithm 2 max ratio: %.2fx\n', names{a}, max_r);
    end

    BER_disp = max(BER, bit_floor);

    figure('Name', sprintf('BER-Fig: %s — Algorithm 2 vs baselines', tag));
    clf;
    ccolors = {[0 0.45 0.74], [0.5 0.0 0.5], [0.85 0.33 0.10], ...
               [0.93 0.69 0.13], [0.47 0.67 0.19], [0.30 0.75 0.93], ...
               [0.49 0.18 0.56], [0.64 0.08 0.18], [0.25 0.25 0.25], [0.10 0.55 0.45]};
    marks = {'o','*','s','d','^','v','>','p','x','h'};
    plot_idx = [1 3 6 7 8 9 10];  % Do not draw oracle/NLMS/VSS in paper-facing figure.
    for ii = 1:numel(plot_idx)
        a = plot_idx(ii);
        lw = 1.4; if a == 1, lw = 2.6; end
        ms = 7;   if a == 1, ms = 10; end
        semilogy(snr_list, BER_disp(:,a), ['-' marks{a}], ...
                 'Color', ccolors{a}, 'LineWidth', lw, ...
                 'MarkerFaceColor', ccolors{a}, 'MarkerSize', ms);
        hold on;
    end
    yline(1e-3, 'k:', '10^{-3}', 'LineWidth', 1.2);
    yline(1e-4, 'k:', '10^{-4}', 'LineWidth', 1.2);
    yline(1e-5, 'k:', '10^{-5}', 'LineWidth', 1.2);
    grid on; xlabel('SNR (dB)'); ylabel('pre-FEC BER');
    title(sprintf('%s: Algorithm 2 (HMM-MSB) vs paper baselines', tag));
    legend(names(plot_idx), 'Location','best');
    ylim([bit_floor/3, 1]);

    pkg.snr_list = snr_list;
    pkg.BER = BER; pkg.err_count = err_count;
    pkg.names = names;
    pkg.bit_floor = bit_floor;
    pkg.cfg_p = cfg_p;
end

function [r, sigma2_eff] = local_apply_twochain_disturbance(r, r_clean, ch_state, cfg, sigma2)
if ~isfield(ch_state, 'dist_state') || isempty(ch_state.dist_state)
    sigma2_eff = sigma2;
    return;
end
tc = cfg.twochain;
q = ch_state.dist_state(:);
N = numel(r);
noise_scale = [1.0 1.7];
if isfield(tc, 'noise_scale'), noise_scale = tc.noise_scale(:).'; end
drop_prob = [0.0 0.0];
if isfield(tc, 'drop_prob'), drop_prob = tc.drop_prob(:).'; end
imp_prob = [0.0 0.0];
if isfield(tc, 'imp_prob'), imp_prob = tc.imp_prob(:).'; end
imp_alpha = 10;
if isfield(tc, 'imp_alpha'), imp_alpha = tc.imp_alpha; end
base_noise = r(:) - r_clean(:);
dist_noise = zeros(N,1);
sigma2_acc = 0;
for n = 1:N
    qq = max(1, min(numel(noise_scale), q(n)));
    dist_noise(n) = base_noise(n) * noise_scale(qq);
    sigma2_acc = sigma2_acc + sigma2 * noise_scale(qq)^2;
    if qq <= numel(imp_prob) && rand < imp_prob(qq)
        dist_noise(n) = dist_noise(n) + imp_alpha * sqrt(max(sigma2,eps)) * sign(randn);
    end
end
r = r_clean(:) + dist_noise;
for n = 1:N
    qq = max(1, min(numel(drop_prob), q(n)));
    if rand < drop_prob(qq)
        r(n) = 0.0;
    end
end
sigma2_eff = sigma2_acc / max(N,1);
end

function [w_ffe, w_dfe] = local_mb_pulse_inverse_ffedfe(h, Kf, Lb, D)
M = numel(h);
Lconv = Kf + M - 1;
H = zeros(Lconv, Kf);
for k = 1:Kf
    H(k:k+M-1, k) = h(:);
end
e = zeros(Lconv,1);
e(min(D+1, Lconv)) = 1;
lambda = 1e-4;
w_ffe = (H.'*H + lambda*eye(Kf)) \ (H.'*e);
g = conv(w_ffe, h);
w_dfe = g(D+2:min(D+1+Lb, numel(g)));
if numel(w_dfe) < Lb
    w_dfe(end+1:Lb) = 0;
end
w_dfe = w_dfe(:);
end

function yhat = local_mb_fixed_ffedfe_slicer(r, w_ffe, w_dfe, D, A)
N = numel(r);
y_ffe = filter(w_ffe, 1, r(:));
Lb = numel(w_dfe);
yhat_sample = zeros(N,1);
dec_buf = zeros(Lb,1);
for n = 1:N
    z = y_ffe(n) - w_dfe(:).' * dec_buf;
    s = pam_slice_scalar(z, A);
    yhat_sample(n) = s;
    if Lb > 0
        dec_buf = [s; dec_buf(1:end-1)];
    end
end
yhat = zeros(N,1);
for n = 1:N
    m = n - D;
    if m >= 1 && m <= N
        yhat(m) = yhat_sample(n);
    end
end
end

function dh = local_mb_cui_centroid_hmm(r, d, cfg)
X = local_mb_cui_features(r);
N = min([numel(r), numel(d), size(X,1)]);
cls = local_mb_symbol_to_class(d(1:N), cfg.A);
train_mask = false(N,1);
train_mask(1:min(cfg.trainLen,N)) = true;
M = cfg.M;
cent = zeros(M, size(X,2));
sig2 = zeros(M,1);
for c = 1:M
    idx = train_mask & cls == c;
    if ~any(idx), idx = train_mask; end
    cent(c,:) = mean(X(idx,:), 1, 'omitnan');
    dist = sum((X(idx,:) - cent(c,:)).^2, 2);
    sig2(c) = max(mean(dist, 'omitnan'), 1e-6);
end
score = zeros(N,M);
for c = 1:M
    score(:,c) = -sum((X(1:N,:) - cent(c,:)).^2, 2) / (2*sig2(c));
end
score = score - max(score, [], 2);
Pemit = exp(score);
Pemit = Pemit ./ max(sum(Pemit,2), eps);
[logA, log_pi0] = hmm_train_pam4(cls(train_mask), M, 1.0);
hat_cls = hmm_viterbi_pam4(Pemit, logA, log_pi0);
A = cfg.A(:);
sample_hat = A(max(1,min(M,hat_cls)));
dh = zeros(numel(d),1);
for n = 1:N
    m = n - cfg.D;
    if m >= 1 && m <= numel(d)
        dh(m) = sample_hat(n);
    end
end
end

function X = local_mb_cui_features(r)
r = r(:);
N = numel(r);
X = zeros(N,5);
for n = 1:N
    rn = r(n);
    rm1 = 0; if n >= 2, rm1 = r(n-1); end
    rm2 = 0; if n >= 3, rm2 = r(n-2); end
    rm3 = 0; if n >= 4, rm3 = r(n-3); end
    X(n,:) = [rn rm1 rm2 rm3 rn-rm1];
end
end

function cls = local_mb_symbol_to_class(y, A)
A = A(:);
y = y(:);
cls = zeros(numel(y),1);
for i = 1:numel(y)
    [~, cls(i)] = min(abs(A - y(i)));
end
end


% ============================================================================
%  EOF NCKH_v51_patches_v68.m
% ============================================================================

% ============================================================================
%  NCKH_v51_patches_v69.m
%  ---------------------------------------------------------------------------
%  PATCH v69 — Fix Algorithm 6 state estimator and bank specialization.
%
%  Why v68 failed:
%    v68 used J_s = (Q(y_s)-y_s)^2. This measures decision confidence, not
%    Markov-state likelihood. Result: state accuracy ~random and banks do not
%    specialize.
%
%  v69 fixes:
%    F1. Channel-likelihood score for Markov 2-tap channel:
%        E_s(m) = ( r(m) - d_cur - h2_s*d_prev )^2
%        Training uses true d(m), d(m-1).
%        DD uses candidate decision Q(y_s) and shared previous decision.
%
%    F2. State-conditional training after a short warm-start:
%        first train_all_prefix symbols: update all banks identically;
%        remaining training symbols: route update to estimated/known state.
%
%    F3. Full-operation estimated-state routing uses channel-likelihood EWMA
%        with dwell/margin hysteresis.
%
%    F4. Diagnostics:
%        raw and best-permutation state accuracy;
%        post-operation bank usage;
%        oracle alignment kept at symbol index m = n-D.
%
%  Replace the v68 algorithm6_msb with algorithm6_msb_v69, then update callers:
%       algorithm6_msb(...)  -> algorithm6_msb_v69(...)
%
%  Keep make_v_alg5, algorithm5_singlebank, and BER handlers from v68.
% ============================================================================
