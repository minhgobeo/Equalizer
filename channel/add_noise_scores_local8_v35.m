% Auto-split from NCKH_v53.m (original line 4347).
% Folder: channel

function T = add_noise_scores_local8_v35(T)
    T.eligible = (T.pUpdEff_markov >= 0.15) & (T.pUpdEff_markov <= 0.80);

    T.claim_ready = ...
        (T.deltaParamVsTheorem    <= 0) & ...
        (T.deltaJumpVsTheorem     <  0) & ...
        (T.deltaPostJumpVsTheorem <= 0) & ...
        T.eligible;

    % Score for adaptive-mu-only should mainly reflect what adaptive mu can change:
    %   1) paramFloor
    %   2) jump behavior
    %   3) post-jump floor
    % DD-bias is kept as a light tie-break.
    z1 = norm01_local_v35(max(T.deltaParamVsTheorem, 0));
    z2 = norm01_local_v35(max(T.deltaJumpVsTheorem,  0));
    z3 = norm01_local_v35(max(T.deltaPostJumpVsTheorem, 0));
    z4 = norm01_local_v35(T.ddBias_markov);

    T.score = ...
        1000*double(~T.claim_ready) + ...
         100*double(~T.eligible)    + ...
         0.50*z1 + 0.30*z2 + 0.15*z3 + 0.05*z4;
end


