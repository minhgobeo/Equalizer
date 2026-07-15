% Auto-split from NCKH_v53.m (original line 319).
% Folder: config

function cfg = build_main_config()
    cfg = struct();

    cfg.mode = 'TF';
    cfg.context_variant = 'practical';

    cfg.M     = 4;
    cfg.A     = (-(cfg.M-1):2:(cfg.M-1));
    cfg.Nsym  = 50000;
    cfg.SNRdB = 28;

    % -------------------------------------------------
    % PRACTICAL OPEN-EYE CONFIG
    % Keep DFE = 1 tap, increase FFE only
    % -------------------------------------------------
    cfg.trainLen = 8000;
    cfg.D        = 2;      % practical fixed delay; can later sweep [0 1 2]
    cfg.Nf       = 5;      % increased FFE
    cfg.Nb       = 1;      % KEEP 1-TAP DFE

    cfg.sps_eye    = 16;
    cfg.alpha_eye  = 0.5;
    cfg.spanUI_eye = 8;

    cfg.chan_mode = 'baseline_2tap';
    cfg.h_isi = [1 0.5];

    cfg.drift_span  = 0.08;
    cfg.drift_shape = 'linear';

    cfg.markov.h2_states = [0.25 0.50 0.80];
    cfg.markov.P = [0.985 0.015 0.000; ...
                    0.010 0.980 0.010; ...
                    0.000 0.020 0.980];
    cfg.markov.init_state = 2;
    cfg.markov.fixed_state = 2;

    % ---------------- ODE sanity ----------------
    cfg.ode.Nsym         = 2500;
    cfg.ode.mu0          = 5e-3;
    cfg.ode.mu_decay     = 5e-3;
    cfg.ode.grid_stride  = 10;
    cfg.ode.fast_steps   = 40000;
    cfg.ode.burnin       = 4000;
    cfg.ode.ode_substeps = 8;
    cfg.ode.use_pd_drift = true;
    cfg.ode.SNRdB_ode    = 50;
    cfg.ode.fixed_states = 1:numel(cfg.markov.h2_states);

    cfg.ode.plot_theta_idx = 2;
    cfg.ode.main_init_idx  = 1;

    % ---------------- severe regime for Fig. 8 ----------------
    cfg.severe = struct();
    cfg.severe.chan_mode = 'markov_2tap';
    cfg.severe.SNRdB     = 14;
    cfg.severe.trainLen  = 800;
    cfg.severe.Nsym      = 60000;
    cfg.severe.h_isi     = [1 0.75];
    cfg.severe.markovP   = [0.94 0.06 0.00; ...
                            0.06 0.88 0.06; ...
                            0.00 0.08 0.92];

    % ---------------- jump config for Fig. 9 ----------------
    cfg.jump = struct();
    cfg.jump.at_symbol     = round(cfg.Nsym * 0.55);
    cfg.jump.win_pre       = 400;
    cfg.jump.win_post      = 1200;
    cfg.jump.recovery_eps  = 0.10;
    cfg.jump.recovery_hold = 40;
    cfg.jump.h_before      = [1 0.50];
    cfg.jump.h_after       = [1 0.90];

    % ---------------- paper cosmetics ----------------
    cfg.paper = struct();
    cfg.paper.fontSize  = 11;
    cfg.paper.lineWidth = 1.4;

    % =================================================
    % 802.3-inspired PRACTICAL channel path
    % OPEN-EYE FIRST: do NOT enable full-stress here
    % =================================================
    cfg.std8023 = struct();
    cfg.std8023.enable = false;
    cfg.std8023.profile = '100BASE_T4';

    cfg.std8023.baud    = 25e6;
    cfg.std8023.ac_fc   = 0;              % disable AC coupling in open-eye stage
    cfg.std8023.cable_len_m  = 100;
    cfg.std8023.use_external_ir = false;
    cfg.std8023.ir_file = 'channel_ir.csv';
    cfg.std8023.ir_norm_main = true;
    cfg.std8023.isi_limit = 0.09;

    % Jitter OFF in open-eye stage
    cfg.std8023.jitter_enable = false;
    cfg.std8023.jitter_std_ns = 0.05;

    % Crosstalk OFF in open-eye stage
    cfg.std8023.add_xtalk      = false;
    cfg.std8023.xtalk_mode     = 'MDFEXT';
    cfg.std8023.xtalk_scale    = 0.02;
    cfg.std8023.xtalk_delay    = 1;
    cfg.std8023.mdfext_peak_mV = 87;
    cfg.std8023.num_xtalk_aggressors = 1;

    % Noise model: AWGN only for opening eye first
    cfg.std8023.noise_model = 'awgn';
    cfg.std8023.p_imp       = 5e-4;
    cfg.std8023.alpha_imp   = 20;
    cfg.std8023.imp_thresh_mV = 264;

    % Transmit template ON
    cfg.std8023.tx_template_enable = true;
    cfg.std8023.tx_risetime_ns     = 5.0;
    cfg.std8023.tx_overshoot_pct   = 5.0;
end

