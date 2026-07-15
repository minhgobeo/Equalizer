function pkg = run_chen_single_pulse_direct_adapter(cfg, vars, base, mc)
%RUN_CHEN_SINGLE_PULSE_DIRECT_ADAPTER  Adapted single-pulse FFE/DFE baseline.
%
% System-adapted (not exact reproduction). Inspired by:
%   Chen et al. 2025, "Optimizing equalizations of FFE/CTLE/DFE jointly
%   through a single pulse response."
%
% Pipeline:
%   1. Build a NOMINAL pulse response h_nom = [1, h2_bar] using the centre
%      Markov state h2_bar.
%   2. Solve a least-squares FFE that inverts h_nom for a chosen delay D_eq.
%   3. Compute trailing taps of conv(h_nom, w_FFE) -- those become DFE taps.
%   4. Test the FIXED FFE/DFE pair on severe and realistic Markov channels.
%
% Caveat in PAPER_TEXT_direct_benchmark_section.md:
%   We do NOT include CTLE shaping or their joint analytical optimization
%   over multi-tap channels. We test only the principle that a single,
%   pulse-response-derived FFE/DFE pair will not track Markov state changes.

regimes  = {'severe','realistic'};
snr_list = [14 18 22 26];
Ntrial   = max(20, min(40, mc.Ntrial_ser));

ber_grid = nan(numel(snr_list), numel(regimes));
ser_grid = nan(numel(snr_list), numel(regimes));

% Use centre Markov state as nominal pulse.
cfg_p_nom = reviewer_set_regime(cfg, 'realistic');
h2_bar = cfg_p_nom.markov.h2_states(2);    % centre state
h_nom = [1, h2_bar];

Kf = cfg_p_nom.Nf;     % FFE length
Lb = cfg_p_nom.Nb;     % DFE length
D_eq = round((Kf+1)/2);

% --- 1) Closed-form FFE/DFE from nominal pulse ---
[w_ffe, w_dfe] = pulse_inverse_ffedfe(h_nom, Kf, Lb, D_eq);
fprintf('[chen_pulse] nominal h2=%.2f, FFE = [%s], DFE = [%s], delay=%d\n', ...
    h2_bar, sprintf('%.3f ', w_ffe), sprintf('%.3f ', w_dfe), D_eq);

for rg = 1:numel(regimes)
    cfg_p0 = reviewer_set_regime(cfg, regimes{rg});
    for si = 1:numel(snr_list)
        ser_t = zeros(Ntrial,1);
        for t=1:Ntrial
            rng(991000 + 1000*rg + 100*si + t);
            cfg_p = cfg_p0; cfg_p.SNRdB = snr_list(si);
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            [rc,~] = channel_out(d, cfg_p);
            [rt,~] = add_noise_dispatch(rc, cfg_p);

            yhat = fixed_ffedfe_slicer(rt, w_ffe, w_dfe, D_eq, cfg_p.A);
            mask = (1:numel(yhat)).' > cfg_p.trainLen;
            valid = mask & (1:numel(yhat)).' <= numel(d);
            ser_t(t) = mean(yhat(valid) ~= d(valid));
        end
        ser_grid(si,rg) = mean(ser_t);
        ber_grid(si,rg) = ser_grid(si,rg)/log2(cfg_p0.M);
        fprintf('[chen_pulse] %s SNR=%d -> BER=%.3e\n', regimes{rg}, snr_list(si), ber_grid(si,rg));
    end
end

pkg.regimes = regimes;
pkg.snr_list = snr_list;
pkg.h_nom = h_nom;
pkg.w_ffe = w_ffe;
pkg.w_dfe = w_dfe;
pkg.D_eq = D_eq;
pkg.ber_grid = ber_grid;
pkg.ser_grid = ser_grid;
pkg.tag = 'Chen_single_pulse_adapted';
pkg.note = 'System-adapted Chen-style fixed FFE/DFE from nominal pulse, not joint CTLE+FFE+DFE.';
end

% =====================================================================
function [w_ffe, w_dfe] = pulse_inverse_ffedfe(h, Kf, Lb, D)
% PULSE_INVERSE_FFEDFE  LS FFE that inverts h at delay D, with DFE = trailing taps.
% Build convolution matrix and solve H_T H w = e_D where e_D selects the delay.
M = numel(h);
Lconv = Kf + M - 1;
H = zeros(Lconv, Kf);
for k=1:Kf
    H(k:k+M-1, k) = h(:);
end
e = zeros(Lconv,1);
e(D+1) = 1;
% Regularised LS for stability.
lambda = 1e-4;
w_ffe = (H.'*H + lambda*eye(Kf)) \ (H.'*e);
% DFE: trailing taps of conv(w_ffe, h) after main delay.
g = conv(w_ffe, h);
% main tap at index D+1 (1-based).
w_dfe = g(D+2 : min(D+1+Lb, numel(g)));
% pad if shorter than Lb
if numel(w_dfe) < Lb
    w_dfe(end+1:Lb) = 0;
end
w_dfe = w_dfe(:);
end

% =====================================================================
function yhat = fixed_ffedfe_slicer(r, w_ffe, w_dfe, D, A)
% Apply fixed FFE then DFE on received samples. Returns yhat indexed by symbol.
N = numel(r);
Nout = N + numel(w_ffe) - 1;
y_ffe = filter(w_ffe, 1, [r; zeros(numel(w_ffe)-1,1)]);
y_ffe = y_ffe(1:N);

% DFE: subtract feedback of past decisions.
Lb = numel(w_dfe);
yhat_sample = zeros(N,1);
dec_buf = zeros(Lb,1);
for n=1:N
    z = y_ffe(n) - w_dfe(:).' * dec_buf;
    s = pam_slice_scalar(z, A);
    yhat_sample(n) = s;
    dec_buf = [s; dec_buf(1:end-1)];
end
% Map sample to symbol index with delay D.
yhat = zeros(N,1);
for n=1:N
    m = n - D;
    if m>=1 && m<=N
        yhat(m) = yhat_sample(n);
    end
end
end
