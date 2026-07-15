function out = run_v72_multitrial(varargin)
%RUN_V72_MULTITRIAL  Multi-seed multi-SNR comparison of v70 vs v72.
%
% Runs the bank-local equalizer with both fixed-temperature (v70) and
% adaptive-temperature (v72) variants across several independent seeds
% and SNR points, then reports mean ± std and paired-difference statistics.
%
% Usage:
%   >> run_v72_multitrial                        % default: severe, 5 trials, SNR={18,22,26}
%   >> run_v72_multitrial('trials',10, 'snrs',[18 20 22 24], 'tau_calib',0.4)
%   >> r = run_v72_multitrial(...);  disp(r);

% ---- parse options ------------------------------------------------
p = inputParser;
addParameter(p, 'trials',    5);
addParameter(p, 'snrs',      [18 22 26]);
addParameter(p, 'tau_calib', 0.4);
addParameter(p, 'regime',    'severe');
addParameter(p, 'seed_base', 80000);
parse(p, varargin{:});
opt = p.Results;

% ---- path setup ---------------------------------------------------
root = fileparts(mfilename('fullpath'));
addpath(genpath(root));

% ---- build standard config chain ---------------------------------
cfg  = build_main_config();
vars = build_variants(cfg);

% Apply regime override (mirror run_mb_ber_severe_v68)
cfg_p = cfg;
switch lower(opt.regime)
    case 'severe'
        cfg_p.chan_mode = 'markov_2tap';
        cfg_p.markov.h2_states = [0.30 0.50 0.70];
        cfg_p.markov.P = [0.95 0.05 0.00; 0.025 0.95 0.025; 0.00 0.05 0.95];
        cfg_p.markov.init_state = 2;
        cfg_p.markov.fixed_state = 2;
        cfg_p.Nsym = 80000;
    case 'realistic'
        cfg_p.chan_mode = 'markov_2tap';
        cfg_p.markov.h2_states = [0.45 0.50 0.55];
        cfg_p.markov.P = [0.99 0.01 0.00; 0.005 0.99 0.005; 0.00 0.01 0.99];
        cfg_p.markov.init_state = 2;
        cfg_p.markov.fixed_state = 2;
        cfg_p.Nsym = 80000;
    case 'moderate'
        cfg_p.chan_mode = 'markov_2tap';
        cfg_p.markov.h2_states = [0.40 0.50 0.60];   % Δ = 0.10
        cfg_p.markov.P = [0.97 0.03 0; 0.015 0.97 0.015; 0 0.03 0.97];  % dwell ~33
        cfg_p.markov.init_state = 2;
        cfg_p.markov.fixed_state = 2;
        cfg_p.Nsym = 80000;
end
if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end

% v_base setup
v_base = make_v_alg5(vars.theorem);
K = cfg_p.Nf;  L = cfg_p.Nb;
main_idx = round((K+1)/2);
v_base.main_idx = main_idx;
ffe_min = -v_base.w2_max*ones(K,1);  ffe_max = v_base.w2_max*ones(K,1);
ffe_min(main_idx) = -Inf;            ffe_max(main_idx) = Inf;
v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

% Result storage
nT   = opt.trials;
nS   = length(opt.snrs);
ber70 = zeros(nT, nS);
ber72 = zeros(nT, nS);
runtime_total = tic;

fprintf('\n==========================================================================\n');
fprintf('  v72 MULTI-TRIAL  (regime=%s, trials=%d, c_τ=%.2f)\n', ...
    opt.regime, nT, opt.tau_calib);
fprintf('==========================================================================\n');
fprintf('SNR(dB)  trial  v70 SER       v72 SER       Δ%%\n');
fprintf('--------------------------------------------------------------------------\n');

for j = 1:nS
    snr = opt.snrs(j);
    cfg_run = cfg_p;  cfg_run.SNRdB = snr;

    for t = 1:nT
        rng(opt.seed_base + 100*t + j);
        sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
        d = cfg_p.A(sym_idx).';  d = d(:);
        [r_clean, ~] = channel_out(d, cfg_p);
        [r, ~] = add_noise_dispatch(r_clean, cfg_run);

        % v70 baseline
        p70 = default_msb_params_v69();
        [dh70, ~] = algorithm6_msb_v70_banklocal(r, d, cfg_run, v_base, p70, []);
        ber70(t,j) = ser_after_training_aligned(d, dh70, cfg_run);

        % v72 adaptive
        p72 = default_msb_params_v72();
        p72.use_adaptive_tau = true;
        p72.tau_calib = opt.tau_calib;
        [dh72, ~] = algorithm6_msb_v72_adaptive_tau(r, d, cfg_run, v_base, p72, []);
        ber72(t,j) = ser_after_training_aligned(d, dh72, cfg_run);

        if ber70(t,j) > 0
            improv_pct = 100 * (1 - ber72(t,j)/ber70(t,j));
        else
            improv_pct = NaN;
        end
        fprintf('  %2d     %2d    %.3e    %.3e    %+6.1f%%\n', ...
            snr, t, ber70(t,j), ber72(t,j), improv_pct);
    end
    fprintf('--------------------------------------------------------------------------\n');
end

fprintf('\n==========================================================================\n');
fprintf('  SUMMARY (mean ± std across trials)\n');
fprintf('==========================================================================\n');
fprintf('SNR(dB)    v70 mean ± std        v72 mean ± std        Δ%% (paired)\n');
fprintf('--------------------------------------------------------------------------\n');

for j = 1:nS
    m70 = mean(ber70(:,j));     s70 = std(ber70(:,j));
    m72 = mean(ber72(:,j));     s72 = std(ber72(:,j));
    paired_diff = ber72(:,j) - ber70(:,j);
    mean_diff_pct = 100 * mean(paired_diff) / m70;
    std_diff_pct  = 100 * std(paired_diff)  / m70;
    fprintf('  %2d      %.2e ± %.2e   %.2e ± %.2e   %+6.1f%% ± %.1f%%\n', ...
        opt.snrs(j), m70, s70, m72, s72, -mean_diff_pct, std_diff_pct);
end
fprintf('--------------------------------------------------------------------------\n');
fprintf('Total runtime: %.1f s\n', toc(runtime_total));
fprintf('==========================================================================\n');

% Significance check (paired sign test)
fprintf('\nSignificance per SNR (v72 better than v70 in how many of %d trials):\n', nT);
for j = 1:nS
    n_better = sum(ber72(:,j) < ber70(:,j));
    n_equal  = sum(ber72(:,j) == ber70(:,j));
    n_worse  = sum(ber72(:,j) > ber70(:,j));
    verdict = '';
    if n_better >= nT - 1
        verdict = ' ← v72 consistently better';
    elseif n_worse >= nT - 1
        verdict = ' ← v72 consistently worse';
    elseif n_better > n_worse
        verdict = ' ← v72 trend better';
    elseif n_worse > n_better
        verdict = ' ← v72 trend worse';
    else
        verdict = ' ← inconclusive';
    end
    fprintf('  SNR %2d:  better=%d  equal=%d  worse=%d%s\n', ...
        opt.snrs(j), n_better, n_equal, n_worse, verdict);
end
fprintf('\n');

% Return struct
out = struct();
out.snrs       = opt.snrs;
out.trials     = nT;
out.tau_calib  = opt.tau_calib;
out.ber_v70    = ber70;     % [nT x nS]
out.ber_v72    = ber72;
out.ber70_mean = mean(ber70,1);
out.ber72_mean = mean(ber72,1);
out.improv_pct = 100*(1 - mean(ber72,1)./mean(ber70,1));

end