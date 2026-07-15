% Auto-split from NCKH_v53.m (original line 12737).
% Folder: core/algorithm6_msb

function theta_new = msb_update_theta_scaled(theta, x, e, n, v_base, Kffe, mu_scale)
    g = (x.'*x) + v_base.delta;

    if isfield(v_base, 'lambda_schedule') && v_base.lambda_schedule
        lambda_n = v_base.lambda_0 / (1 + v_base.lambda_alpha * n)^v_base.lambda_beta;
        lambda_n = max(lambda_n, v_base.lambda_min);
    else
        lambda_n = v_base.lambda;
    end

    mu = mu_scale * get_step_size(n, v_base);
    Hn = -lambda_n * theta + x * (e / g);
    theta_new = theta + mu * Hn;
    theta_new = Pi_H(theta_new, v_base, Kffe);
end
