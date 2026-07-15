function pkg = run_dolatsara_scbo_tx_direct_adapter(cfg, vars, base, mc)
%RUN_DOLATSARA_SCBO_TX_DIRECT_ADAPTER  Adapted Tx-FIR optimization baseline.
%
% System-adapted (not exact reproduction). Inspired by:
%   Dolatsara et al. 2023, "A simplified constrained Bayesian optimization
%   approach to optimize the Tx equalization in SerDes channels."
%
% Pipeline:
%   1. Define a fixed Tx-FIR bank with constraint sum_i |w_i| = 1.
%   2. Use a constrained random-search optimizer (SCBO-lite) on a small
%      training block from the realistic Markov regime to find the FIR
%      that maximizes the eye-opening proxy (mean min |y|/max |y|).
%        --- This is a deliberately simplified surrogate for SCBO.
%   3. Apply the chosen Tx-FIR as PRE-DISTORTION (convolve with d before
%      channel) and run a fixed (non-adaptive) Rx slicer.
%   4. Test on severe and realistic Markov channels.
%
% Caveat in PAPER_TEXT_direct_benchmark_section.md:
%   We do NOT reproduce SCBO acquisition functions, surrogate models, or
%   their full eye-diagram optimization metric. We optimize a constrained
%   Tx-FIR with a Bayesian-style random search using the same constraint
%   structure described in their paper.

regimes  = {'severe','realistic'};
snr_list = [14 18 22 26];
Ntrial   = max(10, min(20, mc.Ntrial_ser));
ntx      = 3;     % Tx-FIR length
n_iter   = 80;    % SCBO-lite iterations

% --- 1) Find best Tx-FIR on a realistic-regime training block.
cfg_train = reviewer_set_regime(cfg, 'realistic');
cfg_train.Nsym = 12000;
cfg_train.SNRdB = 22;
rng(990001);
sym_idx = randi([1 cfg_train.M], cfg_train.Nsym, 1);
d = cfg_train.A(sym_idx).'; d = d(:);

best_w = [1; 0; 0];
best_score = -inf;
rng(990002);
for it=1:n_iter
    w = randn(ntx,1);
    w = w / sum(abs(w));     % constrain sum |w| = 1
    d_pre = filter(w, 1, d);
    [r_clean,~] = channel_out(d_pre, cfg_train);
    [rt,~] = add_noise_dispatch(r_clean, cfg_train);
    score = eye_opening_proxy(rt, cfg_train.A);
    if score > best_score
        best_score = score;
        best_w = w;
    end
end
fprintf('[dolatsara_scbo] best Tx-FIR = [%s], eye-proxy = %.4f\n', ...
    sprintf('%.3f ', best_w), best_score);

% --- 2) Test on both regimes with this fixed Tx-FIR.
ber_grid = nan(numel(snr_list), numel(regimes));
ser_grid = nan(numel(snr_list), numel(regimes));
for rg = 1:numel(regimes)
    cfg_p0 = reviewer_set_regime(cfg, regimes{rg});
    for si = 1:numel(snr_list)
        ser_t = zeros(Ntrial,1);
        for t=1:Ntrial
            rng(990100 + 1000*rg + 100*si + t);
            cfg_p = cfg_p0; cfg_p.SNRdB = snr_list(si);
            sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
            d = cfg_p.A(sym_idx).'; d = d(:);
            d_pre = filter(best_w, 1, d);
            [rc,~] = channel_out(d_pre, cfg_p);
            [rt,~] = add_noise_dispatch(rc, cfg_p);

            % Fixed Rx slicer: align by best delay over a small grid.
            yhat = best_delay_slicer(rt, d, cfg_p.A, 0:3);
            mask = (1:numel(yhat)).' > cfg_p.trainLen;
            valid = mask & (1:numel(yhat)).' <= numel(d);
            ser_t(t) = mean(yhat(valid) ~= d(valid));
        end
        ser_grid(si,rg) = mean(ser_t);
        ber_grid(si,rg) = ser_grid(si,rg)/log2(cfg_p0.M);
        fprintf('[dolatsara_scbo] %s SNR=%d -> BER=%.3e\n', regimes{rg}, snr_list(si), ber_grid(si,rg));
    end
end

pkg.regimes = regimes;
pkg.snr_list = snr_list;
pkg.best_w = best_w;
pkg.best_score = best_score;
pkg.ber_grid = ber_grid;
pkg.ser_grid = ser_grid;
pkg.tag = 'Dolatsara_SCBO_Tx_adapted';
pkg.note = 'System-adapted Dolatsara-style Tx-FIR optimizer, not exact SCBO.';
end

% =====================================================================
function s = eye_opening_proxy(r, A)
% Eye-opening proxy: positive minimum-distance margin to nearest decision
% boundary, averaged over post-warmup samples. Larger is better.
% Decision thresholds for PAM with constellation A:
A = sort(A(:));
midpoints = (A(1:end-1) + A(2:end)) / 2;
margins = min(abs(r - midpoints.'), [], 2);
% Use median of margins as a robust eye-opening proxy.
s = median(margins);
end

% =====================================================================
function yhat = best_delay_slicer(r, d, A, delay_list)
% Try several delays and pick the one with lowest training-block error.
N = numel(r);
yhat_grid = zeros(N, numel(delay_list));
err_grid = zeros(numel(delay_list),1);
trainN = min(round(N*0.3), 4000);
for k = 1:numel(delay_list)
    D = delay_list(k);
    yhat_grid(:,k) = pam_slice_vec(r, A);
    % shift and align
    err_train = 0;
    for n = 1:trainN
        m = n - D;
        if m>=1 && m<=numel(d)
            err_train = err_train + (yhat_grid(n,k) ~= d(m));
        end
    end
    err_grid(k) = err_train;
end
[~, kbest] = min(err_grid);
D = delay_list(kbest);
yhat = zeros(numel(d),1);
for n = 1:N
    m = n - D;
    if m >= 1 && m <= numel(d)
        yhat(m) = yhat_grid(n,kbest);
    end
end
end

function y = pam_slice_vec(r, A)
A = A(:).';
y = zeros(numel(r),1);
for n=1:numel(r)
    [~,i] = min(abs(r(n) - A));
    y(n) = A(i);
end
end
