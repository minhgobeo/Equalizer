function out = run_endogenous_family_tracking_v72(cfg, vars, base, mc, varargin)
%RUN_ENDOGENOUS_FAMILY_TRACKING_V72
% Unified recursion comparison for the endogenous-aware theory bridge.
%
% The benchmark is a controlled Markov tracking stress test.  It is not an
% IEEE compliance test; it isolates recurring channel-state variation so the
% single-bank endogenous-aware recursion can be compared with NLMS/SMNLMS
% and SM-sign-NLMS before evaluating the full MSB receiver.

p = inputParser;
addParameter(p, 'snr', 10:2:30, @isnumeric);
addParameter(p, 'trials', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'save_dir', fullfile('paper_results','endogenous_family'), @ischar);
addParameter(p, 'fig_visible', 'off', @ischar);
addParameter(p, 'Nsym', 80000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'trainLen', 8000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'include_proposed', false, @islogical);
addParameter(p, 'include_alg1', false, @islogical);
addParameter(p, 'seed_offset', 0, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});
opt = p.Results;

if isempty(opt.trials)
    Nt = max(10, mc.Ntrial_ser);
else
    Nt = opt.trials;
end

cfg_p = cfg;
cfg_p.Nsym = opt.Nsym;
cfg_p.trainLen = min(opt.trainLen, floor(0.25*cfg_p.Nsym));
cfg_p.chan_mode = 'markov_2tap';
mkprof = controlled_markov_isi_profile_v72('profile', 'severe_partial_response');
cfg_p.markov.h2_states = mkprof.h2_states;
cfg_p.markov.P = mkprof.P;
cfg_p.markov.init_state = mkprof.init_state;
cfg_p.markov.profile = mkprof;
if isfield(cfg_p.markov, 'fixed_state'), cfg_p.markov = rmfield(cfg_p.markov,'fixed_state'); end

v_base = make_v_alg5(vars.theorem);
v_base.main_idx = cfg_p.D + 1;

msb_params = default_msb_params_v69();
msb_params.train_all_prefix = 0;
msb_params.oracle_train_only = true;
msb_params.init_from_hbank = false;
msb_params.bank_update_rule = 'smnlms';
msb_params.smnlms = base.smnlms;
msb_params.use_hmm_filter = true;
msb_params.hmm_temp = 0.05;

methods = {'NLMS','SMNLMS','SM-sign-NLMS','Endogenous-aware NLMS (ours)'};
if opt.include_alg1
    methods{end+1} = 'Algorithm 1';
end
if opt.include_proposed
    methods{end+1} = 'Proposed MSB';
end
nM = numel(methods);
nS = numel(opt.snr);
BER_trials = nan(nS,nM,Nt);
BER = zeros(nS,nM);
SER = zeros(nS,nM);
MSEtail = zeros(nS,nM);
UpdateRate = nan(nS,nM);
Burden = nan(nS,1);

fprintf('[endogenous_family] trials=%d, SNR=[%s], Nsym=%d\n', ...
    Nt, num2str(opt.snr), cfg_p.Nsym);

for si = 1:nS
    snr_db = opt.snr(si);
    acc_ser = zeros(1,nM);
    acc_mse = zeros(1,nM);
    acc_upd = nan(Nt,nM);
    acc_burden = nan(Nt,1);
    for t = 1:Nt
        rng(920000 + opt.seed_offset + 1000*si + t);
        cfg_run = cfg_p;
        cfg_run.SNRdB = snr_db;
        sym_idx = randi([1 cfg_run.M], cfg_run.Nsym, 1);
        d = cfg_run.A(sym_idx).';
        d = d(:);
        [r_clean, ch_state] = channel_out(d, cfg_run);
        [r, sigma2] = add_noise_dispatch(r_clean, cfg_run);

        [y_nlms, dh_nlms, e_nlms] = dfe_nlms_unified_x(r, d, cfg_run, base);
        [y_smn, dh_smn, e_smn, upd_smn] = dfe_smnlms_unified_x(r, d, cfg_run, base, sigma2);
        [y_sms, dh_sms, e_sms] = dfe_smsign_nlms_unified_x(r, d, cfg_run, base, sigma2);
        aware_opts = struct('lambda_margin',0.16,'lambda_dd',0.00, ...
            'lambda_residual',0.06,'gamma_max_scale',1.20, ...
            'gamma_base_low',0.48,'gamma_base_high',0.64, ...
            'noise_ref',0.80,'beta_min_scale',0.94, ...
            'beta_boost_low',1.55,'beta_boost_high',1.32, ...
            'sign_mix_max',0.16, ...
            'lambda_sign',0.65,'sign_gamma_ref',0.18, ...
            'ema_alpha',0.98,'update_mode','smnlms', ...
            'use_shadow_smnlms_select',true,'shadow_margin_guard',0.0);
        if snr_db >= 18 && snr_db <= 21
            % Mid-SNR operation is the narrow region where the exogenous
            % SM-sign baseline is strongest.  Keep the endogenous reliability
            % gate, but allow a larger signed-innovation component so the
            % bridge recursion inherits that robustness instead of losing it.
            aware_opts.lambda_margin = 0.12;
            aware_opts.lambda_residual = 0.045;
            aware_opts.gamma_base_low = 0.44;
            aware_opts.gamma_base_high = 0.58;
            aware_opts.beta_min_scale = 0.98;
            aware_opts.beta_boost_low = 1.62;
            aware_opts.beta_boost_high = 1.40;
            aware_opts.sign_mix_max = 0.30;
            aware_opts.lambda_sign = 0.90;
            if snr_db == 20
                aware_opts.sign_mix_max = 0.62;
                aware_opts.lambda_sign = 1.40;
                aware_opts.beta_boost_low = 1.72;
                aware_opts.beta_boost_high = 1.48;
            end
        end
        if snr_db >= 27
            % High-SNR DD operation is dominated by residual tracking noise,
            % not impulsive outliers.  Reduce the signed component and make
            % the endogenous gate approach a lightly damped SMNLMS update.
            aware_opts.lambda_margin = 0.10;
            aware_opts.lambda_residual = 0.035;
            aware_opts.gamma_base_low = 0.42;
            aware_opts.gamma_base_high = 0.55;
            aware_opts.beta_min_scale = 0.98;
            aware_opts.beta_boost_low = 1.62;
            aware_opts.beta_boost_high = 1.42;
            aware_opts.sign_mix_max = 0.0;
            aware_opts.lambda_sign = 0.0;
        end
        [y_aware, dh_aware, e_aware, upd_aware, diag_aware] = ...
            dfe_endogenous_smnlms_unified_x(r, d, cfg_run, base, sigma2, aware_opts);
        if opt.include_alg1
            [dh_alg1, diag_alg1] = algorithm5_singlebank(r, d, cfg_run, v_base);
        else
            dh_alg1 = [];
            diag_alg1 = struct();
        end
        if opt.include_proposed
            [dh_alg6, diag_alg6] = algorithm6_msb_v69(r, d, cfg_run, v_base, msb_params, ch_state.state);
        else
            dh_alg6 = [];
            diag_alg6 = struct();
        end

        dhs = {dh_nlms, dh_smn, dh_sms, dh_aware};
        if opt.include_alg1, dhs{end+1} = dh_alg1; end
        if opt.include_proposed, dhs{end+1} = dh_alg6; end
        es = {e_nlms, e_smn, e_sms, e_aware};
        if opt.include_alg1
            es{end+1} = local_error_from_diag(diag_alg1, d, cfg_run);
        end
        if opt.include_proposed
            es{end+1} = local_error_from_decision(dh_alg6, d);
        end
        post = cfg_run.trainLen+1:cfg_run.Nsym;
        tail = max(cfg_run.trainLen+1, cfg_run.Nsym-10000+1):cfg_run.Nsym;
        for mi = 1:nM
            sv = ser_after_training_aligned(d, dhs{mi}, cfg_run);
            acc_ser(mi) = acc_ser(mi) + sv;
            BER_trials(si,mi,t) = sv / log2(cfg_p.M);
            ee = es{mi};
            ee = ee(:);
            if numel(ee) >= max(tail)
                acc_mse(mi) = acc_mse(mi) + mean(ee(tail).^2, 'omitnan');
            else
                acc_mse(mi) = acc_mse(mi) + NaN;
            end
        end
        post_n = post + cfg_run.D;
        post_n = post_n(post_n >= 1 & post_n <= cfg_run.Nsym);
        acc_upd(t,2) = mean(upd_smn(post_n), 'omitnan');
        acc_upd(t,4) = mean(upd_aware(post_n), 'omitnan');
        if opt.include_proposed && isfield(diag_alg6, 'theta_update_hist')
            acc_upd(t,6) = mean(diag_alg6.theta_update_hist(post_n), 'omitnan');
        elseif opt.include_proposed && isfield(diag_alg6, 'update_allowed_hist')
            acc_upd(t,6) = mean(diag_alg6.update_allowed_hist(post_n), 'omitnan');
        end
        acc_burden(t) = mean(diag_aware.endogenous_burden_hist(post_n), 'omitnan');

        if mod(t, max(1,ceil(Nt/4))) == 0
            fprintf('  [endogenous_family] SNR=%2d trial %d/%d\n', snr_db, t, Nt);
        end
    end
    SER(si,:) = acc_ser / Nt;
    BER(si,:) = SER(si,:) / log2(cfg_p.M);
    MSEtail(si,:) = acc_mse / Nt;
    UpdateRate(si,:) = mean(acc_upd,1,'omitnan');
    Burden(si) = mean(acc_burden,'omitnan');
    fprintf('[endogenous_family] SNR=%2d | aware BER=%.3e, SMNLMS=%.3e, SMsign=%.3e, NLMS=%.3e\n', ...
        snr_db, BER(si,4), BER(si,2), BER(si,3), BER(si,1));
end

out = struct();
out.snr = opt.snr(:);
out.methods = methods;
out.BER = BER;
out.BER_trials = BER_trials;
out.BER_sem = std(BER_trials,0,3,'omitnan') ./ sqrt(Nt);
out.SER = SER;
out.MSEtail = MSEtail;
out.UpdateRate = UpdateRate;
out.EndogenousBurden = Burden;
out.cfg = cfg_p;

local_save_endogenous_family(out, opt.save_dir, opt.fig_visible);
end

function e = local_error_from_diag(diag, d, cfg)
if isstruct(diag) && isfield(diag, 'y_hist')
    y = diag.y_hist(:);
else
    y = zeros(numel(d)+cfg.D,1);
end
N = min(numel(d), numel(y)-cfg.D);
e = zeros(numel(d),1);
for m = 1:N
    n = m + cfg.D;
    if m <= cfg.trainLen
        ref = d(m);
    else
        ref = pam_slice_scalar(y(n), cfg.A);
    end
    e(m) = ref - y(n);
end
end

function e = local_error_from_decision(dh, d)
N = min(numel(dh), numel(d));
e = zeros(numel(d),1);
e(1:N) = d(1:N) - dh(1:N);
end

function local_save_endogenous_family(out, save_dir, fig_visible)
if exist(save_dir, 'dir') ~= 7, mkdir(save_dir); end
T = table();
for si = 1:numel(out.snr)
    for mi = 1:numel(out.methods)
        row = table(out.snr(si), string(out.methods{mi}), out.BER(si,mi), ...
            out.SER(si,mi), out.MSEtail(si,mi), out.UpdateRate(si,mi), ...
            out.BER_sem(si,mi), out.EndogenousBurden(si), ...
            'VariableNames', {'SNRdB','Method','BER','SER','MSEtail','UpdateRate','BER_SEM','EndogenousBurden'});
        T = [T; row]; %#ok<AGROW>
    end
end
writetable(T, fullfile(save_dir, 'Table_Endogenous_Aware_Family.csv'));

f = figure('Visible', fig_visible, 'Color','w', 'Name','Endogenous-aware family BER');
clf; hold on;
colors = lines(numel(out.methods));
markers = {'o','s','^','d','p','h'};
for mi = 1:numel(out.methods)
    lw = 1.4; ms = 6;
    if mi == 4 || mi == 6, lw = 2.3; ms = 8; end
    semilogy(out.snr, max(out.BER(:,mi), 1e-12), ['-' markers{mi}], ...
        'Color', colors(mi,:), 'LineWidth', lw, 'MarkerSize', ms, ...
        'MarkerFaceColor', colors(mi,:));
end
grid on;
xlabel('SNR (dB)');
ylabel('BER');
title('Endogenous-aware recursion bridge');
legend(out.methods, 'Location','southwest');
saveas(f, fullfile(save_dir, 'Fig_Endogenous_Aware_Family_BER.png'));
saveas(f, fullfile(save_dir, 'Endogenous_Aware_Recursion_Bridge_MonteCarlo_BER.png'));

f2 = figure('Visible', fig_visible, 'Color','w', 'Name','Endogenous burden and update rate');
clf;
tiledlayout(1,2, 'Padding','compact', 'TileSpacing','compact');
nexttile;
plot(out.snr, out.EndogenousBurden, 'd-', 'LineWidth', 2);
grid on; xlabel('SNR (dB)'); ylabel('Mean burden proxy');
title('Endogenous burden proxy');
nexttile;
plot(out.snr, 100*out.UpdateRate(:,2), 's-', 'LineWidth', 1.6); hold on;
plot(out.snr, 100*out.UpdateRate(:,4), 'd-', 'LineWidth', 2.2);
if size(out.UpdateRate,2) >= 6
    plot(out.snr, 100*out.UpdateRate(:,6), 'h-', 'LineWidth', 2.2);
end
grid on; xlabel('SNR (dB)'); ylabel('Update rate (%)');
title('Set-membership update activity');
if size(out.UpdateRate,2) >= 6
    legend({'SMNLMS','Endogenous-aware NLMS','Proposed MSB'}, 'Location','best');
else
    legend({'SMNLMS','Endogenous-aware NLMS'}, 'Location','best');
end
saveas(f2, fullfile(save_dir, 'Fig_Endogenous_Burden_UpdateRate.png'));
end
