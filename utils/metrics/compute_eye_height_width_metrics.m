function met = compute_eye_height_width_metrics(y_hist, d, cfg, varargin)
%COMPUTE_EYE_HEIGHT_WIDTH_METRICS  PAM4 eye-height and eye-width audit metrics.
%
% This helper is designed for the CK-stress eye figures. It reports:
%   * EyeHeight_5_95 : minimum adjacent PAM4 vertical opening at the sampling instant.
%                      For each adjacent level pair, this is
%                      p05(upper level samples) - p95(lower level samples).
%   * EyeWidth_UI    : approximate minimum horizontal opening in UI. It is estimated
%                      from the same raised-cosine eye waveform used by the plotter,
%                      using threshold crossing spread around the centre of a 2-UI eye.
%   * MinQ           : minimum adjacent-level separation divided by adjacent std sum.
%
% The metric is an algorithmic/simulation audit. It is not an IEEE compliance eye
% measurement and does not replace COM/TDECQ/VEC-style procedures.
%
% Usage:
%   met = compute_eye_height_width_metrics(y_hist, d, cfg);
%   met = compute_eye_height_width_metrics(y_hist, d, cfg, 'sps', 16);

ip = inputParser;
addParameter(ip, 'sps', 16, @(v)isnumeric(v) && isscalar(v) && v > 1);
addParameter(ip, 'alpha', 0.5, @(v)isnumeric(v) && isscalar(v));
addParameter(ip, 'span_ui', 8, @(v)isnumeric(v) && isscalar(v) && v >= 2);
addParameter(ip, 'segment_offset', 1000, @(v)isnumeric(v) && isscalar(v) && v >= 0);
addParameter(ip, 'segment_len', 12000, @(v)isnumeric(v) && isscalar(v) && v > 100);
parse(ip, varargin{:});
opt = ip.Results;

A = sort(cfg.A(:));
M = numel(A);
y_hist = y_hist(:);
d = d(:);

met = struct();
met.A = A;
met.sps = opt.sps;
met.height_definition = 'min adjacent PAM4 vertical opening: p05(upper)-p95(lower), post-training, aligned by cfg.D';
met.width_definition = 'approximate min horizontal opening from 2-UI raised-cosine eye crossing spread, in UI';
met.is_compliance_metric = false;
met.level_mean = nan(M,1);
met.level_std = nan(M,1);
met.level_p05 = nan(M,1);
met.level_p95 = nan(M,1);
met.level_count = zeros(M,1);
met.eye_height_by_gap = nan(max(M-1,0),1);
met.eye_width_by_threshold_ui = nan(max(M-1,0),1);
met.thresholds_used = nan(max(M-1,0),1);
met.eye_height_5_95 = NaN;
met.min_eye_height_5_95 = NaN;
met.eye_width_ui = NaN;
met.min_eye_width_ui = NaN;
met.min_q = NaN;
met.symbol_error_with_measured_thresholds = NaN;
met.n_eval = 0;

if isempty(y_hist) || isempty(d) || M < 2
    return;
end

% Reuse the existing aligned vertical eye-quality function when available.
try
    qmet = compute_eye_quality_metrics(y_hist, d, cfg);
    met.level_mean = qmet.level_mean;
    met.level_std = qmet.level_std;
    met.level_p05 = qmet.level_p05;
    met.level_p95 = qmet.level_p95;
    met.level_count = qmet.level_count;
    met.n_eval = qmet.n_eval;
    met.eye_height_by_gap = qmet.eye_opening_5_95;
    met.eye_height_5_95 = qmet.min_eye_opening_5_95;
    met.min_eye_height_5_95 = qmet.min_eye_opening_5_95;
    met.min_q = qmet.min_q;
    met.symbol_error_with_measured_thresholds = qmet.symbol_error_with_measured_thresholds;
    if isfield(qmet,'measured_thresholds') && all(isfinite(qmet.measured_thresholds))
        met.thresholds_used = qmet.measured_thresholds(:);
    end
catch
    % Fallback: direct aligned percentile calculation.
    N = min(numel(y_hist), numel(d) + cfg.D);
    n = (1:N).';
    m = n - cfg.D;
    mask = (m >= cfg.trainLen+1) & (m <= numel(d));
    y = y_hist(n(mask));
    dref = d(m(mask));
    met.n_eval = numel(y);
    for k = 1:M
        kk = abs(dref - A(k)) < 1e-12;
        yy = y(kk);
        yy = yy(isfinite(yy));
        met.level_count(k) = numel(yy);
        if ~isempty(yy)
            met.level_mean(k) = mean(yy);
            met.level_std(k) = std(yy,0);
            met.level_p05(k) = prctile(yy,5);
            met.level_p95(k) = prctile(yy,95);
        end
    end
    met.eye_height_by_gap = met.level_p05(2:end) - met.level_p95(1:end-1);
    met.eye_height_5_95 = min(met.eye_height_by_gap, [], 'omitnan');
    met.min_eye_height_5_95 = met.eye_height_5_95;
    sep = diff(met.level_mean);
    qv = sep ./ (met.level_std(1:end-1) + met.level_std(2:end) + eps);
    met.min_q = min(qv, [], 'omitnan');
end

% Thresholds: prefer measured level midpoints if finite; otherwise nominal PAM4 midpoints.
if any(~isfinite(met.thresholds_used))
    met.thresholds_used = 0.5*(A(1:end-1) + A(2:end));
end

% Horizontal width from the same eye-like waveform construction used by the plotter.
idx = (cfg.trainLen + opt.segment_offset):min(numel(y_hist), cfg.trainLen + opt.segment_len);
idx = idx(:);
idx = idx(idx >= 1 & idx <= numel(y_hist));
xseg = y_hist(idx);
xseg = xseg(isfinite(xseg));
if numel(xseg) >= 2*opt.sps
    try
        g = rc_pulse(opt.alpha, opt.span_ui, opt.sps);
    catch
        g = local_rc_pulse(opt.alpha, opt.span_ui, opt.sps);
    end
    xos = conv(local_upsample_zeros(xseg, opt.sps), g, 'same');
    met.eye_width_by_threshold_ui = local_eye_width_by_threshold(xos, opt.sps, met.thresholds_used);
    met.eye_width_ui = min(met.eye_width_by_threshold_ui, [], 'omitnan');
    met.min_eye_width_ui = met.eye_width_ui;
end
end

% =====================================================================
function widths = local_eye_width_by_threshold(xos, sps, thresholds)
thresholds = thresholds(:);
widths = nan(numel(thresholds),1);
xos = xos(:);
span = 2*sps;
N = floor(numel(xos)/span);
if N < 2
    return;
end
X = reshape(xos(1:N*span), span, N);
t = linspace(0, 2, span).';
center_idx = round((span+1)/2);

for kk = 1:numel(thresholds)
    thr = thresholds(kk);
    if ~isfinite(thr), continue; end
    left_cross = nan(N,1);
    right_cross = nan(N,1);
    for j = 1:N
        y = X(:,j);
        if ~any(isfinite(y)), continue; end
        left_cross(j) = local_last_crossing(t(1:center_idx), y(1:center_idx), thr, 0.0);
        right_cross(j) = local_first_crossing(t(center_idx:end), y(center_idx:end), thr, 2.0);
    end
    left_cross = left_cross(isfinite(left_cross));
    right_cross = right_cross(isfinite(right_cross));
    if isempty(left_cross) || isempty(right_cross)
        continue;
    end
    % Use conservative percentile spread: late left crossing to early right crossing.
    width = prctile(right_cross, 5) - prctile(left_cross, 95);
    widths(kk) = max(0, min(2, width));
end
end

% =====================================================================
function tc = local_last_crossing(t, y, thr, default_val)
tc = default_val;
y = y(:) - thr;
t = t(:);
if numel(y) < 2, return; end
hit = find(y(1:end-1).*y(2:end) <= 0 & isfinite(y(1:end-1)) & isfinite(y(2:end)), 1, 'last');
if isempty(hit), return; end
tc = local_interp_cross(t(hit), t(hit+1), y(hit), y(hit+1));
end

% =====================================================================
function tc = local_first_crossing(t, y, thr, default_val)
tc = default_val;
y = y(:) - thr;
t = t(:);
if numel(y) < 2, return; end
hit = find(y(1:end-1).*y(2:end) <= 0 & isfinite(y(1:end-1)) & isfinite(y(2:end)), 1, 'first');
if isempty(hit), return; end
tc = local_interp_cross(t(hit), t(hit+1), y(hit), y(hit+1));
end

% =====================================================================
function tc = local_interp_cross(t1, t2, y1, y2)
if ~isfinite(y1) || ~isfinite(y2) || abs(y2-y1) < eps
    tc = 0.5*(t1+t2);
else
    a = -y1/(y2-y1);
    a = max(0, min(1, a));
    tc = t1 + a*(t2-t1);
end
end

% =====================================================================
function y = local_upsample_zeros(x, sps)
y = zeros(numel(x)*sps,1);
y(1:sps:end) = x(:);
end

% =====================================================================
function g = local_rc_pulse(alpha, spanUI, sps)
% Fallback raised-cosine pulse if rc_pulse is unavailable.
t = (-spanUI/2:1/sps:spanUI/2).';
g = zeros(size(t));
for i = 1:numel(t)
    ti = t(i);
    den = 1 - (2*alpha*ti)^2;
    if abs(ti) < 1e-12
        g(i) = 1;
    elseif abs(den) < 1e-10
        g(i) = (pi/4)*sinc(1/(2*alpha));
    else
        g(i) = sinc(ti) * cos(pi*alpha*ti) / den;
    end
end
g = g / max(abs(g)+eps);
end
