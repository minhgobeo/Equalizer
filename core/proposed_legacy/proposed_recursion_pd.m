% Auto-split from NCKH_v53.m (original line 3244).
% Folder: core/proposed_legacy

function [y_samp, d_hat_sym, e_samp, diag] = proposed_recursion_pd(r, d, cfg, v, varargin)
    theta0 = [];
    if ~isempty(varargin), theta0 = varargin{1}; end
    [y_samp, d_hat_sym, e_samp, diag] = proposed_recursion_core(r, d, cfg, v, true, theta0);
end

