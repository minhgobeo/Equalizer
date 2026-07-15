function out = run_v72_sanity(varargin)
%RUN_V72_SANITY  Root-level sanity check for algorithm6_msb_v72_adaptive_tau.
%
% Verifies three properties:
%   (1) FALLBACK IDENTITY:  v72 with use_adaptive_tau=false  ==  v70_banklocal
%                           bit-identical on the same RNG seed.
%   (2) σ²_ν estimator hội tụ vào noise power thật ±25%.
%   (3) v72 with flag ON runs without error and produces sensible diagnostics
%       (SNR_state ∈ (0,1), tau_eff finite positive).
%
% Pattern mimics run_paper.m: path setup at root, then build the same
% (cfg, vars, base, mc) chain that run_mb_ber_severe_v68 uses.
%
% Usage from MATLAB at the package root:
%     >> run_v72_sanity
%     >> run_v72_sanity('snr', 22, 'trials', 1)
%     >> r = run_v72_sanity('snr', 22);  disp(r);

% ---- parse options ------------------------------------------------
p = inputParser;
addParameter(p, 'snr',      22,  @isnumeric);    % default SNR for sanity
addParameter(p, 'trials',   1,   @isnumeric);    % 1 trial is enough
addParameter(p, 'regime',   'severe', @ischar);  % severe | realistic
addParameter(p, 'tau_calib', 2.0, @isnumeric);
addParameter(p, 'verbose',  true, @islogical);
parse(p, varargin{:});
opt = p.Results;

% ---- path setup (same as run_paper.m) -----------------------------
root = fileparts(mfilename('fullpath'));
addpath(genpath(root));

% ---- build standard config chain ----------------------------------
cfg  = build_main_config();
vars = build_variants(cfg);
base = make_v_alg5(vars.theorem);
mc   = build_mc_config(cfg);

% ---- apply regime override (mirror run_mb_ber_severe_v68) ---------
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
    otherwise
        error('Unknown regime: %s', opt.regime);
end
if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end

% ---- v_base setup (mirror run_mb_ber_compare lines 7-14) ----------
v_base = make_v_alg5(vars.theorem);
K = cfg_p.Nf;  L = cfg_p.Nb;
main_idx = round((K+1)/2);
v_base.main_idx = main_idx;
ffe_min = -v_base.w2_max*ones(K,1);  ffe_max = v_base.w2_max*ones(K,1);
ffe_min(main_idx) = -Inf;            ffe_max(main_idx) = Inf;
v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

% ---- data generation (mirror run_mb_ber_compare lines 42-48) ------
rng(80000 + 100*1 + 1);   % same seed family as standard pipeline
sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
d = cfg_p.A(sym_idx).';   d = d(:);
[r_clean, ch_state] = channel_out(d, cfg_p);
cfg_run = cfg_p;  cfg_run.SNRdB = opt.snr;
[r, sigma2] = add_noise_dispatch(r_clean, cfg_run);

% ---- helper to print and capture ----------------------------------
function p = pf(fmt, varargin)
    s = sprintf(fmt, varargin{:});
    if opt.verbose, fprintf('%s', s); end
    p = s;
end

pf('============================================================\n');
pf('  v72 SANITY CHECK  (regime=%s, SNR=%.0f dB, σ²=%.4e)\n', ...
    opt.regime, opt.snr, sigma2);
pf('============================================================\n');

% ---- TEST 1: v70 baseline -----------------------------------------
p70 = default_msb_params_v69();
t1 = tic;
[dh70, ~] = algorithm6_msb_v70_banklocal(r, d, cfg_run, v_base, p70, []);
t70 = toc(t1);
ser70 = ser_after_training_aligned(d, dh70, cfg_run);
pf('[v70 baseline]                 SER = %.3e   (%.1f s)\n', ser70, t70);

% ---- TEST 2: v72 with flag OFF (must match v70) -------------------
p72 = default_msb_params_v72();
p72.use_adaptive_tau = false;
t2 = tic;
[dh72off, ~] = algorithm6_msb_v72_adaptive_tau(r, d, cfg_run, v_base, p72, []);
t72off = toc(t2);
ser72off = ser_after_training_aligned(d, dh72off, cfg_run);
% Count mismatches in the post-training region only
post = (cfg_run.trainLen + cfg_run.D + 1) : length(dh70);
n_mismatch = sum(dh70(post) ~= dh72off(post));
pf('[v72 flag=OFF]                 SER = %.3e   (%.1f s)\n', ser72off, t72off);
pf('   v70 vs v72(off) mismatches (post-train): %d   (expect 0)\n', n_mismatch);

% ---- TEST 3: v72 with flag ON ------------------------------------
p72.use_adaptive_tau = true;
p72.tau_calib = opt.tau_calib;
t3 = tic;
[dh72on, diag72] = algorithm6_msb_v72_adaptive_tau(r, d, cfg_run, v_base, p72, []);
t72on = toc(t3);
ser72on = ser_after_training_aligned(d, dh72on, cfg_run);
pf('[v72 flag=ON, c_τ=%.1f]        SER = %.3e   (%.1f s)\n', ...
    opt.tau_calib, ser72on, t72on);

% ---- TEST 4: diagnostic sanity ------------------------------------
last_half = round(numel(diag72.sigma_nu2_hist)/2):numel(diag72.sigma_nu2_hist);
sigma_est_steady   = mean(diag72.sigma_nu2_hist(last_half));
SNR_state_steady   = mean(diag72.SNR_state_hist(last_half));
ratio_sigma        = sigma_est_steady / sigma2;
tau_eff_final      = diag72.tau_eff_final;

pf('\n[Diagnostics @ steady-state]\n');
pf('   σ²_ν true  = %.4e\n', sigma2);
pf('   σ²_ν est   = %.4e   (ratio est/true = %.3f, expect 0.75–1.30)\n', ...
    sigma_est_steady, ratio_sigma);
pf('   SNR_state  = %.3f   (expect ∈ (0,1))\n', SNR_state_steady);
pf('   τ_eff      = %.2f   (expect finite > 0)\n', tau_eff_final);

% ---- Verdict -------------------------------------------------------
pf('\n============================================================\n');
pass_fallback = (n_mismatch == 0);
pass_sigma    = (ratio_sigma > 0.75 && ratio_sigma < 1.30);
pass_snr      = (SNR_state_steady > 0 && SNR_state_steady < 1);
pass_tau      = (tau_eff_final > 0 && isfinite(tau_eff_final));
all_pass      = pass_fallback && pass_sigma && pass_snr && pass_tau;

pf('  Fallback identity   : %s\n', tick(pass_fallback));
pf('  σ²_ν estimator OK   : %s\n', tick(pass_sigma));
pf('  SNR_state range OK  : %s\n', tick(pass_snr));
pf('  τ_eff finite > 0    : %s\n', tick(pass_tau));
pf('  --------------------------\n');
pf('  OVERALL             : %s\n', tick(all_pass));
pf('============================================================\n');

if ~pass_fallback
    pf('\nWARNING: %d post-training symbols differ between v70 and v72(off).\n', n_mismatch);
    pf('         v72 is NOT a clean drop-in. Common causes:\n');
    pf('         - r_buf init/shift ordering differs\n');
    pf('         - bank-local buffer write timing differs\n');
    pf('         - σ_ν² EMA causes path divergence even with flag off\n');
    pf('         (Inspect first divergence point: see returned out.first_diff_idx)\n');
end

% ---- Return struct ------------------------------------------------
out = struct();
out.regime           = opt.regime;
out.snr_db           = opt.snr;
out.sigma2_true      = sigma2;
out.ser_v70          = ser70;
out.ser_v72_off      = ser72off;
out.ser_v72_on       = ser72on;
out.n_mismatch       = n_mismatch;
out.sigma_est_steady = sigma_est_steady;
out.sigma_ratio      = ratio_sigma;
out.SNR_state_steady = SNR_state_steady;
out.tau_eff_final    = tau_eff_final;
out.all_pass         = all_pass;
out.first_diff_idx   = find(dh70(post) ~= dh72off(post), 1, 'first');
out.diag72           = diag72;

end


% ---- helper: tick or cross --------------------------------------
function s = tick(p)
    if p, s = 'PASS ✓'; else, s = 'FAIL ✗'; end
end
