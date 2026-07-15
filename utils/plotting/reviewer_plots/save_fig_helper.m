function fname = save_fig_helper(fig, save_dir, base_name, opts)
%SAVE_FIG_HELPER  Save a figure with consistent options.
fname = fullfile(save_dir, [base_name '.' opts.save_format]);
switch lower(opts.save_format)
    case 'png'
        exportgraphics(fig, fname, 'Resolution', opts.dpi);
    case 'pdf'
        exportgraphics(fig, fname, 'ContentType', 'vector');
    case 'fig'
        savefig(fig, fname);
    otherwise
        exportgraphics(fig, fname, 'Resolution', opts.dpi);
end
fprintf('[plot_experiment] saved %s\n', fname);
end
