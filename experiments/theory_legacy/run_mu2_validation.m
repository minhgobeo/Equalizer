% Auto-split from NCKH_v53.m (original line 5691).
% Folder: experiments/theory_legacy

function mu2 = run_mu2_validation(cfg, v_theorem, mc)
    mu_list = [0.010 0.020 0.030 0.040 0.055 0.070];
    Nsweep_trials = mc.Ntrial_theorem;

    param_floor = zeros(size(mu_list));
    mu2bar      = zeros(size(mu_list));

    for ii = 1:numel(mu_list)
        acc_param = 0;
        acc_mu2   = 0;

        for t = 1:Nsweep_trials
            rng(6400 + 100*ii + t);

            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);

            [r_clean, ~] = channel_out(d, cfg);
            [r, ~] = add_noise_dispatch(r_clean, cfg);

            vv = make_constant_gain_version(v_theorem, 'global');
            vv.mu_const = mu_list(ii);

            st = proposed_shadow_metrics(r, d, cfg, vv);
            acc_param = acc_param + st.param_floor;
            acc_mu2   = acc_mu2   + st.mu2bar;
        end

        param_floor(ii) = acc_param / Nsweep_trials;
        mu2bar(ii)      = acc_mu2   / Nsweep_trials;
    end

    mu2 = struct();
    mu2.mu_list     = mu_list;
    mu2.param_floor = param_floor;
    mu2.mu2bar      = mu2bar;

    figure('Name','Theorem: parameter floor vs gain-energy'); clf;
    loglog(max(mu2bar,1e-12), max(param_floor,1e-12), 'o-','LineWidth',1.2);
    grid on;
    xlabel('\mu^2-energy proxy');
    ylabel('PD-reference tracking proxy');
    title('Sweep in gain-energy');
end

