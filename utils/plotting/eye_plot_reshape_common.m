function eye_plot_reshape_common(xos, sps, varargin)
%EYE_PLOT_RESHAPE_COMMON Eye plot helper with no legend handles.
p = inputParser;
addParameter(p,'max_traces',160,@isnumeric);
addParameter(p,'color',[0 0.325 0.650]);
addParameter(p,'line_width',0.22,@isnumeric);
parse(p,varargin{:});
opts = p.Results;

xos = xos(:);
win = 2*sps;
Nseg = floor((numel(xos)-win)/sps);
Nseg = max(0, min(Nseg, opts.max_traces));
t = linspace(0, 2, win+1);
for k = 1:Nseg
    ii = (k-1)*sps + (1:win+1);
    plot(t, xos(ii), 'Color', opts.color, 'LineWidth', opts.line_width, 'HandleVisibility','off');
end
xlabel('Time (UI)'); ylabel('Amplitude');
end
