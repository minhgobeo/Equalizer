% Auto-split from NCKH_v53.m (original line 11454).
% Folder: core/algorithm5_singlebank

function v_alg5 = make_v_alg5(v)
% Algorithm 5: NLMS-like core + lambda schedule.
% Removes ALL of: gate, clip, CLR, AGC.
    v_alg5 = v;
    v_alg5.lambda_schedule = true;
    v_alg5.lambda_0     = v.lambda;
    v_alg5.lambda_alpha = 1e-4;
    v_alg5.lambda_beta  = 1.0;
    v_alg5.lambda_min   = v.lambda * 0.05;
    v_alg5.tau_c    = 0; v_alg5.tau_c0   = 0;
    v_alg5.gamma_u  = 0;
    v_alg5.force_no_clip = true;
    v_alg5.mu_max = 0.01; v_alg5.mu_min = 0.01;
    v_alg5.mu_const_global = 0.01;
end


