% Auto-split from NCKH_v53.m (original line 4200).
% Folder: experiments/theory_legacy

function tuning = run_tuning_protocol(cfg, vars, mc)
% ========================================================================
% LOCAL REFINEMENT TUNING PROTOCOL (v35)
%
% LOCKED THEOREM BASELINE
%   tau_c   = 0.45
%   gamma_u = 0.01
%
% LOCAL 8-POINT REFINEMENT
%   around the near-best region found so far
% ========================================================================

    fprintf('\n=== Local refinement tuning protocol (v35: 8-point adaptive-mu-only sweep) ===\n');

    % -----------------------------
    % LOCKED theorem baseline
    % -----------------------------
    tau_locked   = 0.45;
    gamma_locked = 0.01;

    theorem_ref = evaluate_locked_theorem_local_v35(cfg, vars, mc, tau_locked, gamma_locked);

    fprintf('\nLocked theorem baseline:\n');
    disp(struct2table(theorem_ref));

    % -----------------------------
    % 8-point local refinement
    % -----------------------------
local_points = [
    0.09000  0.30  0.50
    0.09500  0.30  0.50
    0.09700  0.30  0.50
    0.09875  0.30  0.50
    0.12500  0.30  0.50
    0.10000  0.30  0.50
    0.11250  0.30  0.50
  
];



    noise_tbl = sweep_noise_grid_local8_v35(cfg, vars, mc, tau_locked, gamma_locked, local_points, theorem_ref);
    noise_tbl = add_noise_scores_local8_v35(noise_tbl);
    noise_tbl = sortrows(noise_tbl, {'score','deltaParamVsTheorem','deltaJumpVsTheorem','deltaPostJumpVsTheorem'});

    fprintf('\nBest local adaptive-mu-only candidate (v35):\n');
    disp(noise_tbl(1,:));

    if any(noise_tbl.claim_ready)
        fprintf('\nAt least one local adaptive-mu-only point is claim-ready.\n');
        disp(noise_tbl(find(noise_tbl.claim_ready,1,'first'),:));
        fprintf('You may proceed to adaptive_tau in the NEXT stage.\n');
    else
        fprintf('\nNo local adaptive-mu-only point is claim-ready yet.\n');
        fprintf('Keep adaptive_tau OFF.\n');
    end

    writetable(struct2table(theorem_ref), 'tuning_locked_theorem_local_v35.csv');
    writetable(noise_tbl, 'tuning_noiseaware_local8_v35.csv');

    tuning = struct();
    tuning.theorem_ref = theorem_ref;
    tuning.noise_tbl   = noise_tbl;
    tuning.best_noise  = noise_tbl(1,:);
end

