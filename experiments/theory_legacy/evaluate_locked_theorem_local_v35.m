% Auto-split from NCKH_v53.m (original line 4266).
% Folder: experiments/theory_legacy

function theorem_ref = evaluate_locked_theorem_local_v35(cfg, vars, mc, tau_locked, gamma_locked)
    vth = vars.theorem;
    vth.tau_c   = tau_locked;
    vth.gamma_u = gamma_locked;

    st = evaluate_variant_bundle_muaware_v35(cfg, vth, mc);

    theorem_ref = struct();
    theorem_ref.tau_c              = tau_locked;
    theorem_ref.gamma_u            = gamma_locked;
    theorem_ref.ddSelfFloor_nom    = st.ddSelfFloor_nom;
    theorem_ref.paramFloor_nom     = st.paramFloor_nom;
    theorem_ref.ddBias_nom         = st.ddBias_nom;
    theorem_ref.pUpdHard_nom       = st.pUpdHard_nom;
    theorem_ref.ddSelfFloor_drift  = st.ddSelfFloor_drift;
    theorem_ref.paramFloor_drift   = st.paramFloor_drift;
    theorem_ref.paramFloor_markov  = st.paramFloor_markov;
    theorem_ref.ddBias_markov      = st.ddBias_markov;
    theorem_ref.pUpdEff_markov     = st.pUpdEff_markov;
    theorem_ref.muScaleMean_markov = st.muScaleMean_markov;
    theorem_ref.muScaleStd_markov  = st.muScaleStd_markov;
    theorem_ref.muSatMin_markov    = st.muSatMin_markov;
    theorem_ref.muSatMax_markov    = st.muSatMax_markov;
    theorem_ref.OvershootArea      = st.OvershootArea;
    theorem_ref.PostJumpFloor      = st.PostJumpFloor;
end

