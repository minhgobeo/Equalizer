% Auto-split from NCKH_v53.m (original line 3398).
% Folder: core/proposed_legacy

function [weight, update_innov, ctrl] = proposed_update_components(v, has_ref, is_dd, y, e, g, u, state)
    weight = 0;
    update_innov = 0;

    ctrl = struct();
    ctrl.raw_gate    = 0;
    ctrl.conf_value  = 0;
    ctrl.accept_hard = 0;
    ctrl.accept_mass = 0;
    ctrl.clip_flag   = 0;
    ctrl.margin      = 0;
    ctrl.gamma_log   = 0;
    ctrl.kappa_log   = Inf;
    ctrl.mu_scale    = 1.0;
    ctrl.state_next  = state;

    if ~has_ref
        return;
    end

    margin = pam4_confidence_margin(y);
    ctrl.margin = margin;

    % ---- normalize kind for constant-gain ablations ----
    kind_use = lower(v.kind);
    if startsWith(kind_use, 'const_')
        kind_use = 'theorem';
    end

    switch kind_use
        case 'theorem'
            if is_dd
                conf_val = 1.0;
                if getfield_safe(v,'use_hard_confidence_dd',false)
                    conf_val = double(margin >= v.tau_c);
                end
                gamma_use = v.gamma_u;
                raw_gate  = double(abs(u) > gamma_use);
                kappa_use = v.kappa_u;
                if v.force_no_clip, kappa_use = Inf; end
                [u_tilde, clip_flag] = clip_innovation(u, kappa_use);
                weight = conf_val * raw_gate;
            else
                conf_val = 1.0;
                gamma_use = v.gamma_tr;
                raw_gate  = double(abs(e) > gamma_use);
                kappa_use = v.kappa_u;
                if v.force_no_clip, kappa_use = Inf; end
                [u_tilde, clip_flag] = clip_innovation(u, kappa_use);
                weight = raw_gate;
            end
            mu_scale = 1.0;

        case 'practical'
            if is_dd
                state.sigma_e2 = (1 - v.beta_e) * state.sigma_e2 + v.beta_e * (e^2);
                state.sigma_u2 = (1 - v.beta_u) * state.sigma_u2 + v.beta_u * (u^2);
                sigma_e = sqrt(max(0,state.sigma_e2));
                sigma_u = sqrt(max(0,state.sigma_u2));
                gamma_use = max(v.gamma_e_min, v.c_gamma_e * sigma_e);
                kappa_use = max(v.kappa_u_min, v.c_kappa_u * sigma_u);
                if v.force_no_clip, kappa_use = Inf; end
                conf_val = 1.0;
                if getfield_safe(v,'use_soft_confidence_dd',false)
                    conf_val = max(v.cmin, min(1.0, margin / max(v.tau_c, eps)));
                end
                raw_gate = double(abs(e) > gamma_use);
                [u_tilde, clip_flag] = clip_innovation(u, kappa_use);
                weight = conf_val * raw_gate;
            else
                gamma_use = v.gamma_tr;
                raw_gate  = double(abs(e) > gamma_use);
                if v.force_no_clip
                    kappa_use = Inf;
                else
                    state.sigma_u2 = (1 - v.beta_u) * state.sigma_u2 + v.beta_u * (u^2);
                    sigma_u = sqrt(max(0,state.sigma_u2));
                    kappa_use = max(v.kappa_u_min, v.c_kappa_u * sigma_u);
                end
                [u_tilde, clip_flag] = clip_innovation(u, kappa_use);
                conf_val = 1.0;
                weight = raw_gate;
            end
            mu_scale = 1.0;

        case 'noise_aware'
            if is_dd
                state.sigma_e2 = (1 - v.beta_e) * state.sigma_e2 + v.beta_e * (e^2);
                state.sigma_u2 = (1 - v.beta_u) * state.sigma_u2 + v.beta_u * (u^2);

                bias_proxy_inst  = abs(u) * double(margin < max(state.tau_c, v.tau_min));
                % Drift proxy: ||theta_n - theta_{n-1}|| approximates ||theta*_n - theta*_{n-1}||
                % (eq:Dhat in paper; theta change is a filtered version of reference drift)
                drift_proxy_inst = norm(state.dtheta_prev);
                state.bias_hat  = (1 - v.beta_b) * state.bias_hat  + v.beta_b * bias_proxy_inst;
                state.drift_hat = (1 - v.beta_d) * state.drift_hat + v.beta_d * drift_proxy_inst;
                state.prev_margin = margin;

                sig_t   = min(state.sigma_u2 / max(v.sigma_u2_ref, eps), 10);
                bias_t  = min(state.bias_hat  / max(v.bias_ref,     eps), 10);
                drift_t = min(state.drift_hat / max(v.drift_ref,    eps), 10);

                if v.use_adaptive_mu
                    mu_scale = (1 + v.alpha_d * drift_t) / (1 + v.alpha_sigma * sig_t + v.alpha_b * bias_t);
                    mu_scale = min(max(mu_scale, v.mu_scale_min), v.mu_scale_max);
                else
                    mu_scale = 1.0;
                end

                tau_use = v.tau_c0;
                if v.use_adaptive_tau
                    tau_use = v.tau_c0 + v.b_bias * bias_t - v.b_drift * drift_t;
                    tau_use = min(max(tau_use, v.tau_min), v.tau_max);
                end
                state.tau_c = tau_use;

                gamma_use = min(max(v.gamma_u0, v.gamma_min), v.gamma_max);
                state.gamma_u = gamma_use;

                kappa_use = v.kappa_u0;
                if v.use_adaptive_kappa
                    kappa_use = v.kappa_u0 / (1 + v.k_bias * bias_t);
                end
                kappa_use = min(max(kappa_use, v.kappa_min), v.kappa_max);
                if v.force_no_clip, kappa_use = Inf; end
                state.kappa_u = kappa_use;

                conf_val = double(margin >= tau_use);
                raw_gate = double(abs(u) > gamma_use);
                [u_tilde, clip_flag] = clip_innovation(u, kappa_use);
                weight = conf_val * raw_gate;
            else
                mu_scale = 1.0;
                conf_val = 1.0;
                gamma_use = v.gamma_tr;
                raw_gate  = double(abs(e) > gamma_use);
                kappa_use = v.kappa_u0;
                if v.force_no_clip, kappa_use = Inf; end
                [u_tilde, clip_flag] = clip_innovation(u, kappa_use);
                weight = raw_gate;
            end

        otherwise
            error('Unknown variant kind: %s', v.kind);
    end

    update_innov = u_tilde;
    ctrl.raw_gate    = raw_gate;
    ctrl.conf_value  = conf_val;
    ctrl.accept_hard = double(weight > 0);
    ctrl.accept_mass = weight;
    ctrl.clip_flag   = clip_flag;
    ctrl.gamma_log   = gamma_use;
    ctrl.kappa_log   = kappa_use;
    ctrl.mu_scale    = mu_scale;
    ctrl.state_next  = state;
end

