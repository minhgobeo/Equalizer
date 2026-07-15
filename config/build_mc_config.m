% Auto-split from NCKH_v53.m (original line 437).
% Folder: config

function mc = build_mc_config(cfg)
    mc = struct();

    mc.Ntrial_conv      = 12;
    mc.Ntrial_ser       = 100;          % 100 trials for smooth monotonic SER curves
    mc.Ntrial_theorem   = 10;
    mc.Ntrial_ode       = 48;
    mc.Ntrial_jump      = 12;
    mc.Ntrial_confirm   = 8;

    mc.ode_fixed_states = cfg.ode.fixed_states;
    mc.ode_show_state   = cfg.markov.fixed_state;

    % compatibility block for theorem-1 validation
    mc.ode = struct();
    mc.ode.main_init_idx  = cfg.ode.main_init_idx;
    mc.ode.plot_theta_idx = cfg.ode.plot_theta_idx;

    p = cfg.Nf + cfg.Nb;
    th0 = zeros(p,3);
    main_idx = cfg.D + 1;
    main_idx = min(max(main_idx,1),p);
    th0(main_idx,:) = 1.0;

    aux_idx = setdiff(1:p, main_idx, 'stable');
    if numel(aux_idx) >= 1
        th0(aux_idx(1),2) = 0.35;
        th0(aux_idx(1),3) = -0.35;
    end
    if numel(aux_idx) >= 2
        th0(aux_idx(2),2) = 0.15;
        th0(aux_idx(2),3) = -0.15;
    end
    mc.ode_init_bank = th0;

    mc.snr_list = 0:3:30;            % wider range for PAM-4 differentiation
end

