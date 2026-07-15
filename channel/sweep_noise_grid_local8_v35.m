% Auto-split from NCKH_v53.m (original line 4293).
% Folder: channel

function T = sweep_noise_grid_local8_v35(cfg, vars, mc, tau_locked, gamma_locked, local_points, theorem_ref)
    rows = [];
    Np = size(local_points,1);

    for k = 1:Np
        alpha_sigma = local_points(k,1);
        alpha_b     = local_points(k,2);
        alpha_d     = local_points(k,3);

        v = vars.noise_aware;

        % Lock theorem-side thresholds
        v.tau_c0   = tau_locked;
        v.tau_c    = tau_locked;
        v.gamma_u0 = gamma_locked;
        v.gamma_u  = gamma_locked;

        % Force adaptive-mu-only
        v.use_adaptive_mu    = true;
        v.use_adaptive_tau   = true;
        v.use_adaptive_kappa = false;

        % Local coefficients
        v.alpha_sigma = alpha_sigma;
        v.alpha_b     = alpha_b;
        v.alpha_d     = alpha_d;

        st = evaluate_variant_bundle_muaware_v35(cfg, v, mc);

        row = struct();
        row.alpha_sigma         = alpha_sigma;
        row.alpha_b             = alpha_b;
        row.alpha_d             = alpha_d;
        row.paramFloor_markov   = st.paramFloor_markov;
        row.ddBias_markov       = st.ddBias_markov;
        row.pUpdEff_markov      = st.pUpdEff_markov;
        row.muScaleMean_markov  = st.muScaleMean_markov;
        row.muScaleStd_markov   = st.muScaleStd_markov;
        row.muSatMin_markov     = st.muSatMin_markov;
        row.muSatMax_markov     = st.muSatMax_markov;
        row.OvershootArea       = st.OvershootArea;
        row.PostJumpFloor       = st.PostJumpFloor;

        row.deltaParamVsTheorem    = st.paramFloor_markov - theorem_ref.paramFloor_markov;
        row.deltaBiasVsTheorem     = st.ddBias_markov    - theorem_ref.ddBias_markov;
        row.deltaJumpVsTheorem     = st.OvershootArea    - theorem_ref.OvershootArea;
        row.deltaPostJumpVsTheorem = st.PostJumpFloor    - theorem_ref.PostJumpFloor;

        rows = [rows; row]; %#ok<AGROW>
    end

    T = struct2table(rows);
end

