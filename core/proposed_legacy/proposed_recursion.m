% Auto-split from NCKH_v53.m (original line 3238).
% Folder: core/proposed_legacy

function [y_samp, d_hat_sym, e_samp, diag] = proposed_recursion(r, d, cfg, v, varargin)
    theta0 = [];
    if ~isempty(varargin), theta0 = varargin{1}; end
    [y_samp, d_hat_sym, e_samp, diag] = proposed_recursion_core(r, d, cfg, v, false, theta0);
end

