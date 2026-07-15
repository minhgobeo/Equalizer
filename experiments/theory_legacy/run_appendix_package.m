% Auto-split from NCKH_v53.m (original line 2996).
% Folder: experiments/theory_legacy

function appendix = run_appendix_package(cfg, vars, base, rep, mc)
    appendix = struct();

    % A1: practical diagnostics already computed in practical package
    appendix.diag = [];

    % A2: structural ablation
    appendix.ablt = run_structural_ablation_package(cfg, vars.theorem, mc);

    % A3: keep both support packages
    appendix.ptf  = run_ptf_proxy_visualization(rep, vars.theorem);
    appendix.clip = run_clipping_stress(cfg, vars, base, mc);
end

