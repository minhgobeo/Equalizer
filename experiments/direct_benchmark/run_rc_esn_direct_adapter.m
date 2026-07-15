function pkg = run_rc_esn_direct_adapter(cfg, vars, base, mc)
%RUN_RC_ESN_DIRECT_ADAPTER  Reservoir-computing (Echo State Network) equalizer
% baseline for PAM4 IM/DD on the same Markov-DD testbed as the other direct
% baselines. Aligned with the multi-symbol RC paper referenced in the manuscript.
%
% v2 fix (vs v1):
%   * Reservoir matrices W_in, W_res are built ONCE outside all loops
%     using a private RandStream. Inside esn_equalize, NO rng calls --
%     this is critical to avoid poisoning the rng state seen by
%     algorithm6_msb_v69 in the same trial.
%   * Algorithm 2 is invoked BEFORE the RC equalizer in the trial path,
%     so its rng-state context matches the Souza adapter pattern.
%   * Field name corrected: cfg.trainLen (not cfg.Ntrain).
%   * Seed offset family aligned with Souza adapter (970000 + ...).

snr_list = [10 14 18 22 26 28 30];
regimes  = {'severe','realistic'};
Ntrial   = max(20, min(100, mc.Ntrial_ser));

% RC hyperparameters
rc.N_res    = 80;      % reservoir size
rc.K_in     = 5;       % input window length (same as FFE order)
rc.alpha    = 0.6;     % leak rate
rc.rho      = 0.9;     % spectral radius
rc.density  = 0.10;    % reservoir connectivity sparsity
rc.lambda   = 1e-3;    % ridge regularization
rc.seed_res = 42;      % reservoir seed -- ISOLATED from main rng

% ---- Build reservoir ONCE using a private RandStream ----
% This does not touch the main rng stream, so algorithm6_msb_v69 sees an
% untainted rng state inside each trial.
s_res = RandStream('mt19937ar','Seed', rc.seed_res);
W_in  = (2*rand(s_res, rc.N_res, rc.K_in) - 1) * 0.3;

% Build sparse mask using private stream, then assign values from private stream
mask = rand(s_res, rc.N_res) < rc.density;
nz   = sum(mask(:));
vals = 2*rand(s_res, nz, 1) - 1;
W_res = zeros(rc.N_res);
W_res(mask) = vals;

% Spectral-radius rescale
ev = eig(W_res);
sr = max(abs(ev));
if ~isfinite(sr) || sr < 1e-12, sr = 1; end
W_res = W_res * (rc.rho / sr);

rc.W_in  = W_in;
rc.W_res = W_res;
clear W_in W_res s_res mask nz vals ev sr;

BER_rc   = nan(numel(snr_list), numel(regimes));
BER_alg2 = nan(numel(snr_list), numel(regimes));

msb_params = default_msb_params_v69();

for rg = 1:numel(regimes)
    cfg_p0 = reviewer_set_regime(cfg, regimes{rg});

    % Build v_base FRESH per regime, exactly like the Souza adapter does
    v_base = make_v_alg5(vars.theorem);
    Kffe = cfg_p0.Nf; L = cfg_p0.Nb; main_idx = round((Kffe+1)/2);
    v_base.main_idx = main_idx;
    ffe_min = -v_base.w2_max*ones(Kffe,1); ffe_max = v_base.w2_max*ones(Kffe,1);
    ffe_min(main_idx) = -Inf; ffe_max(main_idx) = Inf;
    v_base.theta_min = [ffe_min; -v_base.b_max*ones(L,1)];
    v_base.theta_max = [ffe_max;  v_base.b_max*ones(L,1)];

    for si = 1:numel(snr_list)
        ber_rc_t = zeros(Ntrial,1);
        ber_a2_t = zeros(Ntrial,1);
        for t = 1:Ntrial
            % Same seed offset family as the Souza adapter
            rng(970000 + 1000*rg + 100*si + t);
            cfg_p = cfg_p0; cfg_p.SNRdB = snr_list(si);

            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [r_clean,~] = channel_out(d, cfg_p);
            [r, ~]      = add_noise_dispatch(r_clean, cfg_p);

            % Algorithm 2 FIRST (so its rng state context matches Souza)
            [dh_a2, ~] = algorithm6_msb_v69(r, d, cfg_p, v_base, msb_params, []);

            % RC equalizer SECOND, using pre-built reservoir, no rng touched
            dh_rc = esn_equalize(r, d, cfg_p, rc);

            % v72 API: ser_after_training_aligned returns SER (scalar),
            % convert to BER via /log2(M)
            ser_rc = ser_after_training_aligned(d, dh_rc, cfg_p);
            ser_a2 = ser_after_training_aligned(d, dh_a2, cfg_p);
            ber_rc_t(t) = ser_rc / log2(cfg_p.M);
            ber_a2_t(t) = ser_a2 / log2(cfg_p.M);
        end
        BER_rc(si,rg)   = mean(ber_rc_t);
        BER_alg2(si,rg) = mean(ber_a2_t);
        fprintf('[rc_esn] %s SNR=%2d -> RC=%.3e, Alg2=%.3e (Ntrial=%d)\n', ...
            regimes{rg}, snr_list(si), BER_rc(si,rg), BER_alg2(si,rg), Ntrial);
    end
end

pkg.snr_list = snr_list;
pkg.regimes  = regimes;
pkg.BER_rc   = BER_rc;
pkg.BER_alg2 = BER_alg2;
pkg.rc_hyper = rmfield(rc,{'W_in','W_res'});
pkg.Ntrial   = Ntrial;
pkg.tag      = 'RC_ESN_direct_baseline_v2';

% Console summary table
fprintf('\n=== RC-ESN baseline summary ===\n');
for rg = 1:numel(regimes)
    fprintf('Regime: %s\n', regimes{rg});
    fprintf('  SNR(dB)   RC-ESN        Alg2(MSB)     Ratio(RC/A2)\n');
    for si = 1:numel(snr_list)
        ratio = BER_rc(si,rg) / max(BER_alg2(si,rg), eps);
        fprintf('   %2d      %.3e     %.3e     %.2fx\n', ...
            snr_list(si), BER_rc(si,rg), BER_alg2(si,rg), ratio);
    end
end
end

% =================================================================
function dh = esn_equalize(r, d, cfg, rc)
% Train-then-test ESN equalizer for PAM4 IM/DD.
% NO rng calls inside -- reservoir matrices come pre-built in rc.W_in, rc.W_res.

Nsym   = numel(r);
Ntrain = cfg.trainLen;
Khalf  = floor(rc.K_in/2);

% Build input matrix U (K_in x Nsym), zero-padded at edges
U = zeros(rc.K_in, Nsym);
rpad = [zeros(Khalf,1); r(:); zeros(Khalf,1)];
for n = 1:Nsym
    U(:,n) = rpad(n : n+rc.K_in-1);
end

% Run reservoir state using PRE-BUILT matrices
X = zeros(rc.N_res, Nsym);
x = zeros(rc.N_res, 1);
for n = 1:Nsym
    x = (1-rc.alpha)*x + rc.alpha*tanh(rc.W_in*U(:,n) + rc.W_res*x);
    X(:,n) = x;
end

% Ridge regression on pilot
X_train = X(:, 1:Ntrain);
y_train = d(1:Ntrain);
RR = X_train * X_train' + rc.lambda * eye(rc.N_res);
W_out = (RR \ (X_train * y_train)).';   % 1 x N_res

% Predict and slice to PAM4 alphabet
y_hat = (W_out * X).';
dh = pam4_slice(y_hat, cfg.A);
end

% =================================================================
function dh = pam4_slice(y, A)
% Nearest-symbol slicer for PAM4 alphabet A = [-3 -1 +1 +3].
dh = zeros(size(y));
dh(y <= -2)            = A(1);
dh(y >  -2 & y <= 0)   = A(2);
dh(y >   0 & y <  2)   = A(3);
dh(y >=  2)            = A(4);
end