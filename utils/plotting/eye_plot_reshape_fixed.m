function eye_plot_reshape_fixed(x, sps, varargin)
%EYE_PLOT_RESHAPE_FIXED  Clean 2-UI eye diagram without automatic legend entries.
%
% Usage:
%   eye_plot_reshape_fixed(x, sps)
%   eye_plot_reshape_fixed(x, sps, 'max_traces', 180, 'color', [0.0 0.25 0.75])
%
% The plotted traces use HandleVisibility='off' so journal styling functions
% do not create enormous legends.

p = inputParser;
addParameter(p, 'max_traces', 180, @(v)isnumeric(v) && isscalar(v) && v > 0);
addParameter(p, 'color', [0.000 0.325 0.650], @(v)isnumeric(v) && (numel(v)==3 || numel(v)==4));
addParameter(p, 'line_width', 0.25, @(v)isnumeric(v) && isscalar(v) && v > 0);
parse(p, varargin{:});
opt = p.Results;

span = 2*sps;
N = floor(numel(x)/span);
if N < 1
    return;
end
xx = x(1:N*span);
xx = reshape(xx, span, N);

% Limit trace count for readability and deterministic output.
Nplot = min(N, opt.max_traces);
if N > Nplot
    idx = round(linspace(1, N, Nplot));
else
    idx = 1:N;
end
xx = xx(:, idx);

t = linspace(0, 2, span);
plot(t, xx, 'LineWidth', opt.line_width, 'Color', opt.color, 'HandleVisibility','off');
xlabel('Time (UI)'); ylabel('Amplitude');
xlim([0 2]);
end
