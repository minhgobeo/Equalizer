% Auto-split from NCKH_v53.m (original line 5314).
% Folder: utils/plotting

function print_summary(ode_rslt, practical_rslt, theorem_rslt, appendix_rslt, confirm_rslt)
    fprintf('\n=== Summary ===\n'); %#ok<NASGU>
    fprintf('ODE sanity package completed.\n');
    fprintf('Practical context branch: %s\n', practical_rslt.rep.variant_name);
    fprintf('Practical DD self-error floor: %.4e\n', practical_rslt.diag.dd_self_error_floor);
    fprintf('Practical p_gate = %.3f, p_conf = %.3f, p_upd_hard = %.3f, p_upd_eff = %.3f, p_clip = %.3f\n', ...
        practical_rslt.diag.p_gate, practical_rslt.diag.p_conf, practical_rslt.diag.p_upd_hard, practical_rslt.diag.p_upd_eff, practical_rslt.diag.p_clip);
    fprintf('Theorem package and appendix package completed.\n');
    if nargin >= 5 && ~isempty(confirm_rslt)
        fprintf('Confirmatory protocol completed.\n');
        disp(confirm_rslt);
    end
end

