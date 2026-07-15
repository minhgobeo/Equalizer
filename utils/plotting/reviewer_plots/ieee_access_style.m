function ieee_access_style(fig_or_ax)
%IEEE_ACCESS_STYLE  Apply IEEE Access journal-quality styling without creating new legends.
%
% Important: this function must NOT call legend(ax) because that creates a
% legend for every plotted object. Eye diagrams may contain hundreds of line
% objects, so auto-legend creation makes unreadable figures and warnings.

if isa(fig_or_ax, 'matlab.ui.Figure')
    set(fig_or_ax, 'Color', 'w');
    axes_list = findall(fig_or_ax, 'Type', 'axes');
elseif isa(fig_or_ax, 'matlab.graphics.axis.Axes')
    axes_list = fig_or_ax;
    set(get(axes_list,'Parent'), 'Color', 'w');
else
    axes_list = gca;
    set(get(axes_list,'Parent'), 'Color', 'w');
end

for ax = axes_list(:).'
    set(ax, ...
        'FontName', 'Arial', ...
        'FontSize', 11, ...
        'LineWidth', 0.9, ...
        'TickDir', 'in', ...
        'TickLength', [0.012 0.012], ...
        'Box', 'on', ...
        'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.18, ...
        'MinorGridLineStyle', 'none', ...
        'XMinorTick', 'on', 'YMinorTick', 'on');

    xl = get(ax, 'XLabel');  if ~isempty(xl), set(xl, 'FontName','Arial', 'FontSize', 12); end
    yl = get(ax, 'YLabel');  if ~isempty(yl), set(yl, 'FontName','Arial', 'FontSize', 12); end
    tt = get(ax, 'Title');   if ~isempty(tt), set(tt, 'FontName','Arial', 'FontSize', 13, 'FontWeight','bold'); end
end

% Style only legends that already exist. Do not create new ones.
fig = ancestor(axes_list(1), 'figure');
if ~isempty(fig)
    legends = findall(fig, 'Type', 'Legend');
    for lg = legends(:).'
        if isvalid(lg)
            set(lg, 'FontName','Arial', 'FontSize', 10, 'Box', 'off', 'EdgeColor', 'none');
        end
    end
end
end
