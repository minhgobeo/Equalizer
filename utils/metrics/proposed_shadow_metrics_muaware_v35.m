% Auto-split from NCKH_v53.m (original line 4481).
% Folder: utils/metrics

function st = proposed_shadow_metrics_muaware_v35(r, d, cfg, v)
% Same as proposed_shadow_metrics(...) but also logs mu_scale diagnostics
% so adaptive-mu-only tuning can be diagnosed properly.

    [y_impl, ~, e_impl, diag_impl] = proposed_recursion(r, d, cfg, v); %#ok<ASGLU>
    [~,      ~, ~,      diag_pd]   = proposed_recursion_pd(r, d, cfg, v); %#ok<ASGLU>

    N = numel(r);
    nn = (1:N).';
    mm = nn - cfg.D;
    dd_mask = (mm >= (cfg.trainLen+1)) & (mm <= cfg.Nsym);

    theta_impl = diag_impl.theta_hist;
    theta_pd   = diag_pd.theta_hist;
    H_impl     = diag_impl.H_hist;
    H_pd       = diag_pd.H_hist;

    st = struct();
    st.dd_self_error_floor = mean(e_impl(dd_mask).^2);
    st.param_floor = mean(sum((theta_impl(:,dd_mask) - theta_pd(:,dd_mask)).^2, 1));
    st.dd_bias_proxy = mean(sqrt(sum((H_impl(:,dd_mask) - H_pd(:,dd_mask)).^2, 1)));
    st.p_upd_hard_dd = mean(diag_impl.accept_hard_hist(dd_mask));
    st.p_upd_eff_dd  = mean(diag_impl.accept_mass_hist(dd_mask));

    % mu-scale diagnostics: only meaningful for adaptive-mu-only tuning
    if isfield(diag_impl, 'mu_scale_hist')
        mu_sc = diag_impl.mu_scale_hist(dd_mask);
        st.mu_scale_mean    = mean(mu_sc);
        st.mu_scale_std     = std(mu_sc);
        if isfield(v, 'mu_scale_min')
            st.mu_scale_sat_min = mean(abs(mu_sc - v.mu_scale_min) < 1e-9);
        else
            st.mu_scale_sat_min = 0;
        end
        if isfield(v, 'mu_scale_max')
            st.mu_scale_sat_max = mean(abs(mu_sc - v.mu_scale_max) < 1e-9);
        else
            st.mu_scale_sat_max = 0;
        end
    else
        st.mu_scale_mean    = 1.0;
        st.mu_scale_std     = 0.0;
        st.mu_scale_sat_min = 0.0;
        st.mu_scale_sat_max = 0.0;
    end
end

