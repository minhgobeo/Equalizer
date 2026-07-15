function met = compute_eye_quality_metrics(y_hist, d, cfg)
%COMPUTE_EYE_QUALITY_METRICS Quantitative PAM4 eye/level metrics.
%
% The function evaluates samples at the same timing used by BER alignment:
%   sample index n corresponds to symbol index m = n - D.
% Only post-training samples are used. Metrics are based on actual equalizer
% output amplitude; no per-method normalization is applied.

A = sort(cfg.A(:));
M = numel(A);
N = min(numel(y_hist), numel(d) + cfg.D);
n = (1:N).';
m = n - cfg.D;
mask = (m >= cfg.trainLen+1) & (m <= numel(d));
idx_n = n(mask);
idx_m = m(mask);
y = y_hist(idx_n);
dref = d(idx_m);

met = struct();
met.A = A;
met.n_eval = numel(y);
met.level_mean = nan(M,1);
met.level_std  = nan(M,1);
met.level_p05  = nan(M,1);
met.level_p95  = nan(M,1);
met.level_count = zeros(M,1);

for k = 1:M
    kk = abs(dref - A(k)) < 1e-12;
    yy = y(kk);
    met.level_count(k) = numel(yy);
    if ~isempty(yy)
        met.level_mean(k) = mean(yy, 'omitnan');
        met.level_std(k)  = std(yy, 0, 'omitnan');
        met.level_p05(k)  = prctile(yy, 5);
        met.level_p95(k)  = prctile(yy, 95);
    end
end

met.adj_mean_sep = diff(met.level_mean);
met.adj_q = met.adj_mean_sep ./ (met.level_std(1:end-1) + met.level_std(2:end) + eps);
met.min_q = min(met.adj_q, [], 'omitnan');
met.min_mean_sep = min(met.adj_mean_sep, [], 'omitnan');

% Eye opening with percentile margins. Positive means the 5--95% bands do not overlap.
met.eye_opening_5_95 = met.level_p05(2:end) - met.level_p95(1:end-1);
met.min_eye_opening_5_95 = min(met.eye_opening_5_95, [], 'omitnan');

% Static optimum thresholds from the measured level means.
met.measured_thresholds = 0.5*(met.level_mean(1:end-1) + met.level_mean(2:end));

% BER-like decision estimate with measured thresholds, useful as a slicer-placement audit.
dhat = zeros(size(y));
for i = 1:numel(y)
    dhat(i) = local_slice_thr(y(i), A, met.measured_thresholds);
end
met.symbol_error_with_measured_thresholds = mean(dhat ~= dref);
end

function s = local_slice_thr(z, A, thr)
if z < thr(1), s = A(1); return; end
for k = 1:numel(thr)-1
    if z < thr(k+1), s = A(k+1); return; end
end
s = A(end);
end
