% Auto-split from NCKH_v53.m (original line 3204).
% Folder: utils/metrics

function st = proposed_shadow_metrics(r, d, cfg, v)
    [y_impl, d_hat_impl, e_impl, diag_impl] = proposed_recursion(r, d, cfg, v); %#ok<ASGLU>
    [y_pd,   ~,        e_pd,   diag_pd]   = proposed_recursion_pd(r, d, cfg, v); %#ok<ASGLU>

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
    st.oracle_output_floor = mean((d(mm(dd_mask)) - y_impl(dd_mask)).^2);
    st.param_floor = mean(sum((theta_impl(:,dd_mask) - theta_pd(:,dd_mask)).^2, 1));
    st.dd_bias_proxy = mean(sqrt(sum((H_impl(:,dd_mask) - H_pd(:,dd_mask)).^2, 1)));
    st.p_gate_dd     = mean(diag_impl.raw_gate_hist(dd_mask));
    st.p_conf_dd     = mean(diag_impl.conf_hist(dd_mask));
    st.p_upd_hard_dd = mean(diag_impl.accept_hard_hist(dd_mask));
    st.p_upd_eff_dd  = mean(diag_impl.accept_mass_hist(dd_mask));
    st.p_clip_dd     = mean(diag_impl.clip_hist(dd_mask));
    st.mu2bar        = mean(diag_impl.mu_hist(dd_mask).^2);

    e2dd = e_impl(dd_mask).^2;
    st.err_q99        = quantile_simple(e2dd, 0.99);
    st.tail1_mean_e2  = tail_mean(e2dd, 0.01);
end

%% =====================================================================
% CORE RECURSIONS
%% =====================================================================
