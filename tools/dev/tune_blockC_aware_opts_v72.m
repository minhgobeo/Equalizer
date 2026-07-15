function R = tune_blockC_aware_opts_v72()
%TUNE_BLOCKC_AWARE_OPTS_V72 Small high-SNR sweep for endogenous-aware DFE.

addpath(genpath(pwd));
cfg = build_main_config();
base = build_baselines();
cfg.Nsym = 80000;
cfg.trainLen = 8000;
cfg.chan_mode = 'markov_2tap';
cfg.markov.h2_states = [0.30 0.50 0.70];
cfg.markov.P = [0.95 0.05 0; 0.025 0.95 0.025; 0 0.05 0.95];
cfg.markov.init_state = 2;
if isfield(cfg.markov,'fixed_state'), cfg.markov = rmfield(cfg.markov,'fixed_state'); end

opts = [ ...
    struct('gb_low',0.40,'gb_high',0.50,'b_low',1.80,'b_high',1.55,'bmin',1.00,'lmar',0.06,'lres',0.02,'mode',"smnlms"); ...
    struct('gb_low',0.36,'gb_high',0.48,'b_low',1.90,'b_high',1.65,'bmin',1.00,'lmar',0.04,'lres',0.01,'mode',"smnlms"); ...
    struct('gb_low',0.32,'gb_high',0.44,'b_low',2.00,'b_high',1.75,'bmin',1.00,'lmar',0.02,'lres',0.00,'mode',"smnlms"); ...
    struct('gb_low',0.40,'gb_high',0.50,'b_low',1.40,'b_high',1.25,'bmin',0.90,'lmar',0.08,'lres',0.02,'mode',"nlms"); ...
    struct('gb_low',0.35,'gb_high',0.45,'b_low',1.35,'b_high',1.20,'bmin',0.90,'lmar',0.06,'lres',0.01,'mode',"nlms") ...
];

Nt = 4;
R = repmat(struct('idx',0,'aware',NaN,'smnlms',NaN,'smsign',NaN,'nlms',NaN,'cfg',[]), numel(opts), 1);
for oi = 1:numel(opts)
    acc = zeros(Nt,4);
    for t = 1:Nt
        rng(990000 + 100*oi + t);
        cfg_run = cfg;
        cfg_run.SNRdB = 30;
        d = cfg_run.A(randi([1 cfg_run.M], cfg_run.Nsym, 1)).';
        d = d(:);
        [r_clean, ~] = channel_out(d, cfg_run);
        [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);
        [~, dh_nlms] = dfe_nlms_unified_x(r, d, cfg_run, base);
        [~, dh_smn] = dfe_smnlms_unified_x(r, d, cfg_run, base, sigma2);
        [~, dh_sms] = dfe_smsign_nlms_unified_x(r, d, cfg_run, base, sigma2);
        o = opts(oi);
        aware_opts = struct('lambda_margin',o.lmar,'lambda_dd',0.00, ...
            'lambda_residual',o.lres,'gamma_max_scale',1.05, ...
            'gamma_base_low',o.gb_low,'gamma_base_high',o.gb_high, ...
            'noise_ref',0.80,'beta_min_scale',o.bmin, ...
            'beta_boost_low',o.b_low,'beta_boost_high',o.b_high, ...
            'sign_mix_max',0.0,'lambda_sign',0.0,'sign_gamma_ref',0.18, ...
            'ema_alpha',0.98,'update_mode',char(o.mode));
        [~, dh_aw] = dfe_endogenous_smnlms_unified_x(r, d, cfg_run, base, sigma2, aware_opts);
        acc(t,1) = ser_after_training_aligned(d, dh_aw, cfg_run) / log2(cfg_run.M);
        acc(t,2) = ser_after_training_aligned(d, dh_smn, cfg_run) / log2(cfg_run.M);
        acc(t,3) = ser_after_training_aligned(d, dh_sms, cfg_run) / log2(cfg_run.M);
        acc(t,4) = ser_after_training_aligned(d, dh_nlms, cfg_run) / log2(cfg_run.M);
    end
    R(oi).idx = oi;
    R(oi).aware = mean(acc(:,1));
    R(oi).smnlms = mean(acc(:,2));
    R(oi).smsign = mean(acc(:,3));
    R(oi).nlms = mean(acc(:,4));
    R(oi).cfg = opts(oi);
    fprintf('cfg%d mode=%s aware=%.3e smnlms=%.3e smsign=%.3e nlms=%.3e\n', ...
        oi, opts(oi).mode, R(oi).aware, R(oi).smnlms, R(oi).smsign, R(oi).nlms);
end
save('tune_blockC_aware_opts_v72.mat','R');
end
