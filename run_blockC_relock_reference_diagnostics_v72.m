function out = run_blockC_relock_reference_diagnostics_v72(varargin)
%RUN_BLOCKC_RELOCK_REFERENCE_DIAGNOSTICS_V72
% Reference-aligned Block-C diagnostics for three single-bank update laws.
%
% Purpose:
%   Run 1: static C2M channel, SNR sweep, tail-EMSE/BER/update-rate.
%   Run 2: switched C2M Markov channel, single shared bank/buffer, re-lock.
%   Run 3: tap-bound/tap-norm diagnostics reused from Run 2 logs.
%
% Compared methods:
%   Algorithm 1: endogenous-aware projected leaky SM-NLMS.
%   Gazor 2002: SMNLMS-DFE.
%   de Souza 2024: SM-sign-NLMS.
%
% Guardrail:
%   Same Nf=7, Nb=3, D=3, same seeds, same channel/noise realizations.
%   Only the update law changes.

p = inputParser;
addParameter(p, 'trials', 20, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'samples', 40000, @(x)isnumeric(x) && isscalar(x) && x > 1000);
addParameter(p, 'trainLen', 8000, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'snr', 10:2:30, @isnumeric);
addParameter(p, 'snr_tune', 22, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'baud', 26.5625e9, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'p_stay', 0.95, @(x)isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'block_len', 300, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'mu_grid', [0.25 0.5 0.75 1 1.5 2 3 4], @isnumeric);
addParameter(p, 'tune_policy', 'best_emse', @(x)ischar(x) || isstring(x));
addParameter(p, 'save_dir', fullfile('paper_final_blockC_relock_reference_v72'), @ischar);
addParameter(p, 'fig_visible', 'off', @(x)ischar(x) || isstring(x));
addParameter(p, 'format', 'png', @(x)ischar(x) || isstring(x));
addParameter(p, 'force', false, @islogical);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
dirs = local_prepare_dirs(opt.save_dir);
cfg = local_cfg(opt);
base = build_baselines();
methods = local_methods();
channels = local_c2m_channels(opt.baud);

fprintf('[blockC_relock] trials=%d Nsym=%d trainLen=%d baud=%.4g SNR=[%s]\n', ...
    opt.trials, cfg.Nsym, cfg.trainLen, opt.baud, num2str(opt.snr));
fprintf('[blockC_relock] static=%s switched=%s|%s|%s p_stay=%.3f\n', ...
    channels.static.case_id, channels.states(1).case_id, ...
    channels.states(2).case_id, channels.states(3).case_id, opt.p_stay);

out = struct();
out.options = opt;
out.cfg = cfg;
out.methods = {methods.label};
out.channels = channels;
out.note = local_write_note(opt.save_dir, opt, channels);

out.tune = local_tune_mu(cfg, base, methods, channels, opt, dirs);
out.run1 = local_run1_static_sweep(cfg, base, methods, channels, out.tune, opt, dirs);
out.run2 = local_run2_switched_relock(cfg, base, methods, channels, out.tune, opt, dirs);
out.run3 = local_run3_tap_bound(out.run2, methods, opt, dirs);
local_write_summary(out, methods, opt, dirs);

save(fullfile(dirs.mat, 'BlockC_RelockReferenceDiagnostics_v72.mat'), 'out', '-v7.3');
fprintf('[blockC_relock] done: %s\n', opt.save_dir);
end

% ======================================================================
function dirs = local_prepare_dirs(save_dir)
dirs = struct();
dirs.root = save_dir;
dirs.fig = fullfile(save_dir, 'figures');
dirs.tab = fullfile(save_dir, 'tables');
dirs.mat = fullfile(save_dir, 'mat');
f = fieldnames(dirs);
for k = 1:numel(f)
    if exist(dirs.(f{k}), 'dir') ~= 7
        mkdir(dirs.(f{k}));
    end
end
end

function cfg = local_cfg(opt)
cfg = build_main_config();
cfg.Nsym = round(opt.samples);
cfg.trainLen = min(round(opt.trainLen), floor(0.25*cfg.Nsym));
cfg.Nf = 7;
cfg.Nb = 3;
cfg.D = 3;
cfg.M = 4;
cfg.A = [-3 -1 1 3];
end

function methods = local_methods()
methods = struct([]);
methods(1).key = 'alg1';
methods(1).label = 'Algorithm 1: endogenous-aware';
methods(1).short = 'Algorithm 1';
methods(1).color = [0.635 0.078 0.184];
methods(1).marker = 'd';
methods(1).mac_base = 18;
methods(1).mac_update = 42;

methods(2).key = 'smnlms';
methods(2).label = 'Gazor SMNLMS-DFE [30]';
methods(2).short = 'SMNLMS-DFE';
methods(2).color = [0.850 0.325 0.098];
methods(2).marker = 's';
methods(2).mac_base = 18;
methods(2).mac_update = 32;

methods(3).key = 'smsign';
methods(3).label = 'de Souza SM-sign-NLMS [20]';
methods(3).short = 'SM-sign-NLMS';
methods(3).color = [0.929 0.694 0.125];
methods(3).marker = '^';
methods(3).mac_base = 18;
methods(3).mac_update = 24;
end

function channels = local_c2m_channels(baud)
catalog = build_8023ck_channel_catalog('root_dir', fullfile('data','8023ck_channels'), ...
    'allow_synthetic', true, 'baud', baud, 'sps', 16, 'ntaps', 9, ...
    'override_manifest_baud', true);
ids = {'C2M_10dB','C2M_14dB','C2M_16dB'};
states = repmat(catalog(1), 1, 3);
for i = 1:3
    idx = find(strcmp({catalog.case_id}, ids{i}), 1);
    if isempty(idx)
        error('Missing C2M state channel %s in catalog.', ids{i});
    end
    states(i) = catalog(idx);
end
idx = find(strcmp({catalog.case_id}, 'C2M_14dB'), 1);
channels = struct();
channels.static = catalog(idx);
channels.states = states;
channels.tx_ffe = [1; -0.08; 0.03];
end

% ======================================================================
function tune = local_tune_mu(cfg, base, methods, channels, opt, dirs)
cache = fullfile(dirs.mat, 'TuneMu_StaticC2M.mat');
if exist(cache, 'file') == 2 && ~opt.force
    S = load(cache, 'tune');
    tune = S.tune;
    local_plot_tune(tune, methods, opt, dirs);
    return;
end
nM = numel(methods);
nG = numel(opt.mu_grid);
tail = nan(nM,nG);
upd = nan(nM,nG);
cfg_t = cfg;
cfg_t.SNRdB = opt.snr_tune;
for gi = 1:nG
    for tr = 1:opt.trials
        rng(771000 + 10000*gi + tr);
        [d, r, sigma2] = local_generate_static(cfg_t, channels.static, channels.tx_ffe);
        theta_ref = local_reference_theta(r, d, cfg_t);
        for mi = 1:nM
            res = local_run_method(methods(mi).key, r, d, cfg_t, base, sigma2, ...
                opt.mu_grid(gi), theta_ref, opt.block_len, [], []);
            tail(mi,gi) = local_accum(tail(mi,gi), local_tail_mean(res.emse_block), tr);
            upd(mi,gi) = local_accum(upd(mi,gi), local_tail_mean(res.update_block), tr);
        end
        local_progress('[Tune]', gi, nG, tr, opt.trials);
    end
end
best = min(tail, [], 2);
target = max(best) * 1.03;
mu_sel = nan(nM,1);
sel_idx = nan(nM,1);
tune_policy = lower(string(opt.tune_policy));
for mi = 1:nM
    switch tune_policy
        case "common_target"
            [~, sel_idx(mi)] = min(abs(log(max(tail(mi,:),realmin) ./ target)));
        case "best_emse"
            [~, sel_idx(mi)] = min(tail(mi,:));
        otherwise
            error('Unknown tune_policy %s. Use best_emse or common_target.', opt.tune_policy);
    end
    mu_sel(mi) = opt.mu_grid(sel_idx(mi));
end
tune = struct();
tune.mu_grid = opt.mu_grid(:);
tune.tail_emse = tail;
tune.update_rate = upd;
tune.best_tail_emse = best;
tune.common_target_emse = target;
tune.mu_scale = mu_sel;
tune.selected_index = sel_idx;
tune.snr_tune = opt.snr_tune;
tune.methods = {methods.label};
tune.policy = char(tune_policy);
T = table();
for mi = 1:nM
    for gi = 1:nG
        T = [T; table(string(methods(mi).label), opt.mu_grid(gi), tail(mi,gi), ...
            upd(mi,gi), gi == sel_idx(mi), target, string(tune.policy), ...
            'VariableNames', {'Method','MuScale','TailEMSE','UpdateRate','Selected','CommonTargetEMSE','TunePolicy'})]; %#ok<AGROW>
    end
end
writetable(T, fullfile(dirs.tab, 'Run0_StaticC2M_MuTune.csv'));
save(cache, 'tune', '-v7.3');
local_plot_tune(tune, methods, opt, dirs);
end

function local_plot_tune(tune, methods, opt, dirs)
fig = figure('Color','w','Visible',char(opt.fig_visible), 'Position',[80 80 920 650]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log(ax);
for mi = 1:numel(methods)
    semilogy(ax, tune.mu_grid, tune.tail_emse(mi,:), ['-' methods(mi).marker], ...
        'Color', methods(mi).color, 'MarkerFaceColor', methods(mi).color, ...
        'LineWidth', 1.9 + 0.5*(mi==1), 'MarkerSize', 7 + 2*(mi==1), ...
        'DisplayName', methods(mi).short);
    semilogy(ax, tune.mu_scale(mi), tune.tail_emse(mi,tune.selected_index(mi)), ...
        'p', 'Color', methods(mi).color, 'MarkerFaceColor', methods(mi).color, ...
        'MarkerSize', 12, 'HandleVisibility','off');
end
yline(ax, tune.common_target_emse, 'k--', 'common static tail-EMSE target', ...
    'HandleVisibility','off', 'LabelHorizontalAlignment','left');
xlabel(ax,'step-size scale'); ylabel(ax,'static C2M tail EMSE');
title(ax, sprintf('Run 0. Static C2M tune-\\mu at SNR = %g dB (%s)', ...
    tune.snr_tune, tune.policy), 'Interpreter','none');
legend(ax,'Location','best', 'Interpreter','none');
local_save(fig, fullfile(dirs.fig, ['Run0_StaticC2M_MuTune.' char(opt.format)]));
end

% ======================================================================
function run1 = local_run1_static_sweep(cfg, base, methods, channels, tune, opt, dirs)
cache = fullfile(dirs.mat, 'Run1_StaticSNR.mat');
if exist(cache, 'file') == 2 && ~opt.force
    S = load(cache, 'run1');
    run1 = S.run1;
    local_plot_run1(run1, methods, opt, dirs);
    return;
end
nM = numel(methods);
nS = numel(opt.snr);
tail_emse = nan(nS,nM);
tail_mse = nan(nS,nM);
ber = nan(nS,nM);
ser = nan(nS,nM);
upd = nan(nS,nM);
learn_acc = [];
learn_count = 0;
for si = 1:nS
    cfg_s = cfg;
    cfg_s.SNRdB = opt.snr(si);
    for tr = 1:opt.trials
        rng(772000 + 10000*si + tr);
        [d, r, sigma2] = local_generate_static(cfg_s, channels.static, channels.tx_ffe);
        theta_ref = local_reference_theta(r, d, cfg_s);
        for mi = 1:nM
            res = local_run_method(methods(mi).key, r, d, cfg_s, base, sigma2, ...
                tune.mu_scale(mi), theta_ref, opt.block_len, [], []);
            tail_emse(si,mi) = local_accum(tail_emse(si,mi), local_tail_mean(res.emse_block), tr);
            tail_mse(si,mi) = local_accum(tail_mse(si,mi), local_tail_mean(res.mse_block), tr);
            sv = ser_after_training_aligned(d, res.d_hat, cfg_s);
            ser(si,mi) = local_accum(ser(si,mi), sv, tr);
            ber(si,mi) = local_accum(ber(si,mi), sv/log2(cfg_s.M), tr);
            upd(si,mi) = local_accum(upd(si,mi), local_tail_mean(res.update_block), tr);
            if opt.snr(si) == opt.snr_tune
                if isempty(learn_acc)
                    learn_acc = zeros(numel(res.iter), nM);
                end
                learn_acc(:,mi) = learn_acc(:,mi) + res.emse_block(:);
            end
        end
        if opt.snr(si) == opt.snr_tune
            learn_count = learn_count + 1;
        end
        local_progress('[Run1]', si, nS, tr, opt.trials);
    end
end
run1 = struct();
run1.snr = opt.snr(:);
run1.methods = {methods.label};
run1.BER = ber;
run1.SER = ser;
run1.tail_emse = tail_emse;
run1.tail_mse = tail_mse;
run1.update_rate = upd;
run1.mu_scale = tune.mu_scale;
if learn_count > 0
    run1.learning_iter = res.iter;
    run1.learning_emse = learn_acc / learn_count;
else
    run1.learning_iter = [];
    run1.learning_emse = [];
end
T = table();
for si = 1:nS
    for mi = 1:nM
        T = [T; table(opt.snr(si), string(methods(mi).label), tune.mu_scale(mi), ...
            ber(si,mi), ser(si,mi), tail_emse(si,mi), tail_mse(si,mi), upd(si,mi), ...
            'VariableNames', {'SNRdB','Method','MuScale','BER','SER','TailEMSE','TailMSE','UpdateRate'})]; %#ok<AGROW>
    end
end
writetable(T, fullfile(dirs.tab, 'Run1_StaticC2M_SNR_EMSE_BER.csv'));
save(cache, 'run1', '-v7.3');
local_plot_run1(run1, methods, opt, dirs);
end

function local_plot_run1(run1, methods, opt, dirs)
fig = figure('Color','w','Visible',char(opt.fig_visible), 'Position',[60 60 1280 820]);
tl = tiledlayout(fig, 2, 2, 'Padding','compact', 'TileSpacing','compact');
ax = nexttile(tl,1); hold(ax,'on'); grid(ax,'on'); box(ax,'on'); local_style_log(ax);
emse_floor = local_plot_floor(run1.tail_emse);
for mi = 1:numel(methods)
    semilogy(ax, run1.snr, max(run1.tail_emse(:,mi), emse_floor), ['-' methods(mi).marker], ...
        'Color', methods(mi).color, 'MarkerFaceColor', methods(mi).color, ...
        'LineWidth', 1.9 + 0.6*(mi==1), 'MarkerSize', 7 + 2*(mi==1), ...
        'DisplayName', methods(mi).short);
end
xlabel(ax,'SNR (dB)'); ylabel(ax,'tail EMSE'); title(ax,'Run 1(a). Static C2M tail EMSE');
legend(ax,'Location','northeast', 'Interpreter','none');

ax = nexttile(tl,2); hold(ax,'on'); grid(ax,'on'); box(ax,'on'); local_style_log(ax);
for mi = 1:numel(methods)
    semilogy(ax, run1.snr, max(run1.BER(:,mi), 1e-6), ['-' methods(mi).marker], ...
        'Color', methods(mi).color, 'MarkerFaceColor', methods(mi).color, ...
        'LineWidth', 1.9 + 0.6*(mi==1), 'MarkerSize', 7 + 2*(mi==1), ...
        'DisplayName', methods(mi).short);
end
yline(ax, 2.4e-4, 'k--', 'KP4 FEC 2.4e-4', 'HandleVisibility','off');
xlabel(ax,'SNR (dB)'); ylabel(ax,'pre-FEC BER'); title(ax,'Run 1(b). Static BER, secondary metric');

ax = nexttile(tl,3); hold(ax,'on'); grid(ax,'on'); box(ax,'on'); local_style_log(ax);
if ~isempty(run1.learning_iter)
    for mi = 1:numel(methods)
        semilogy(ax, run1.learning_iter, max(local_smooth(run1.learning_emse(:,mi),5), realmin), ...
            'Color', methods(mi).color, 'LineWidth', 1.9 + 0.6*(mi==1), ...
            'DisplayName', methods(mi).short);
    end
end
xlabel(ax,'Iteration'); ylabel(ax,'EMSE'); title(ax, sprintf('Run 1(c). Learning curve at %g dB', opt.snr_tune));

ax = nexttile(tl,4); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_linear(ax);
for mi = 1:numel(methods)
    plot(ax, run1.snr, 100*run1.update_rate(:,mi), ['-' methods(mi).marker], ...
        'Color', methods(mi).color, 'MarkerFaceColor', methods(mi).color, ...
        'LineWidth', 1.9 + 0.6*(mi==1), 'MarkerSize', 7 + 2*(mi==1), ...
        'DisplayName', methods(mi).short);
end
xlabel(ax,'SNR (dB)'); ylabel('update activity (%)'); title(ax,'Run 1(d). Data-selective update activity');
sgtitle(tl, 'Endogenous-aware recursion bridge - Run 1: static C2M adaptive-filter diagnostics', ...
    'FontName','Times New Roman', 'FontSize', 16, 'FontWeight','bold');
local_save(fig, fullfile(dirs.fig, ['Run1_StaticC2M_Diagnostics.' char(opt.format)]));
end

% ======================================================================
function run2 = local_run2_switched_relock(cfg, base, methods, channels, tune, opt, dirs)
cache = fullfile(dirs.mat, 'Run2_SwitchedRelock.mat');
if exist(cache, 'file') == 2 && ~opt.force
    S = load(cache, 'run2');
    run2 = S.run2;
    local_plot_run2(run2, methods, opt, dirs);
    return;
end
nM = numel(methods);
win_pre = 900;
win_post = 2100;
offset_edges = (-win_pre:opt.block_len:win_post).';
nB = numel(offset_edges)-1;
rel_mse = zeros(nB,nM);
rel_msd = zeros(nB,nM);
rel_count = zeros(nB,1);
floor_emse = nan(opt.trials,nM);
floor_ber = nan(opt.trials,nM);
floor_ser = nan(opt.trials,nM);
upd_rate = nan(opt.trials,nM);
rep = struct();

P = [opt.p_stay, 1-opt.p_stay, 0; ...
     (1-opt.p_stay)/2, opt.p_stay, (1-opt.p_stay)/2; ...
     0, 1-opt.p_stay, opt.p_stay];

for tr = 1:opt.trials
    rng(773000 + tr);
    [d, r, sigma2, state_seq] = local_generate_switched(cfg, channels, P);
    theta_refs = local_state_references(cfg, channels, d, sigma2);
    for mi = 1:nM
        res = local_run_method(methods(mi).key, r, d, cfg, base, sigma2, ...
            tune.mu_scale(mi), theta_refs(:,2), opt.block_len, theta_refs, state_seq);
        floor_emse(tr,mi) = local_tail_mean(res.emse_block);
        sv = ser_after_training_aligned(d, res.d_hat, cfg);
        floor_ser(tr,mi) = sv;
        floor_ber(tr,mi) = sv/log2(cfg.M);
        upd_rate(tr,mi) = local_tail_mean(res.update_block);
        sw = find(diff(state_seq(:)) ~= 0) + 1;
        sw = sw(sw > cfg.trainLen + win_pre & sw < cfg.Nsym - win_post);
        if numel(sw) > 60
            sw = sw(round(linspace(1, numel(sw), 60)));
        end
        for sidx = 1:numel(sw)
            s0 = sw(sidx);
            for bi = 1:nB
                idx = s0 + offset_edges(bi):s0 + offset_edges(bi+1)-1;
                idx = idx(idx >= 1 & idx <= cfg.Nsym);
                if isempty(idx), continue; end
                rel_mse(bi,mi) = rel_mse(bi,mi) + mean(res.e(idx).^2, 'omitnan');
                rel_msd(bi,mi) = rel_msd(bi,mi) + mean(res.msd_active(idx), 'omitnan');
                if mi == 1
                    rel_count(bi) = rel_count(bi) + 1;
                end
            end
        end
        if tr == 1
            rep.(methods(mi).key) = local_representative_log(res, state_seq, cfg);
        end
    end
    local_progress('[Run2]', 1, 1, tr, opt.trials);
end
for mi = 1:nM
    rel_mse(:,mi) = rel_mse(:,mi) ./ max(rel_count,1);
    rel_msd(:,mi) = rel_msd(:,mi) ./ max(rel_count,1);
end
run2 = struct();
run2.offset = (offset_edges(1:end-1) + offset_edges(2:end) - 1)/2;
run2.methods = {methods.label};
run2.relock_mse = rel_mse;
run2.relock_msd = rel_msd;
run2.floor_emse = mean(floor_emse,1,'omitnan');
run2.floor_BER = mean(floor_ber,1,'omitnan');
run2.floor_SER = mean(floor_ser,1,'omitnan');
run2.update_rate = mean(upd_rate,1,'omitnan');
run2.transition_counts = rel_count;
run2.P = P;
run2.representative = rep;
T = table();
for mi = 1:nM
    T = [T; table(string(methods(mi).label), tune.mu_scale(mi), run2.floor_BER(mi), ...
        run2.floor_SER(mi), run2.floor_emse(mi), run2.update_rate(mi), ...
        'VariableNames', {'Method','MuScale','BER','SER','TailEMSE','UpdateRate'})]; %#ok<AGROW>
end
writetable(T, fullfile(dirs.tab, 'Run2_SwitchedC2M_SingleBank_Floor.csv'));
save(cache, 'run2', '-v7.3');
local_plot_run2(run2, methods, opt, dirs);
end

function local_plot_run2(run2, methods, opt, dirs)
fig = figure('Color','w','Visible',char(opt.fig_visible), 'Position',[60 60 1280 820]);
tl = tiledlayout(fig, 2, 2, 'Padding','compact', 'TileSpacing','compact');
ax = nexttile(tl,1); hold(ax,'on'); grid(ax,'on'); box(ax,'on'); local_style_log(ax);
for mi = 1:numel(methods)
    nr = size(run2.relock_mse,1);
    floor_i = mean(run2.relock_mse(max(1,nr-1):nr,mi), 'omitnan');
    yy = max(local_smooth(run2.relock_mse(:,mi) - floor_i, 3), 1e-6);
    semilogy(ax, run2.offset, yy, 'Color', methods(mi).color, ...
        'LineWidth', 2.4 + 0.5*(mi==1), 'DisplayName', methods(mi).short);
end
xline(ax, 0, 'k:', 'switch', 'HandleVisibility','off');
xlabel(ax,'Symbols relative to channel switch'); ylabel(ax,'excess block-MSE');
title(ax,'Run 2(a). Re-lock transient after C2M state switch');
legend(ax,'Location','northeast', 'Interpreter','none');

ax = nexttile(tl,2); hold(ax,'on'); grid(ax,'on'); box(ax,'on'); local_style_log(ax);
for mi = 1:numel(methods)
    yy = max(local_smooth(run2.relock_msd(:,mi), 3), 1e-8);
    semilogy(ax, run2.offset, yy, 'Color', methods(mi).color, ...
        'LineWidth', 2.1 + 0.5*(mi==1), 'DisplayName', methods(mi).short);
end
xline(ax, 0, 'k:', 'switch', 'HandleVisibility','off');
xlabel(ax,'Symbols relative to channel switch'); ylabel(ax,'active-state MSD');
title(ax,'Run 2(b). Weight-error relock relative to active C2M state');

ax = nexttile(tl,3); hold(ax,'on'); grid(ax,'on'); box(ax,'on'); local_style_log(ax);
for mi = 1:numel(methods)
    semilogy(ax, mi, max(run2.floor_emse(mi),1e-8), methods(mi).marker, ...
        'Color', methods(mi).color, 'MarkerFaceColor', methods(mi).color, ...
        'MarkerSize', 12 + 2*(mi==1), 'LineWidth', 2.0, 'DisplayName', methods(mi).short);
end
set(ax,'XTick',1:numel(methods),'XTickLabel',{methods.short});
xtickangle(ax, 18);
ylabel(ax,'single-bank tail EMSE'); title(ax,'Run 2(c). Residual floor remains single-bank');

ax = nexttile(tl,4); hold(ax,'on'); grid(ax,'on'); box(ax,'on'); local_style_linear(ax);
for mi = 1:numel(methods)
    bar(ax, mi, 100*run2.update_rate(mi), 'FaceColor', methods(mi).color, ...
        'EdgeColor', methods(mi).color, 'DisplayName', methods(mi).short);
end
set(ax,'XTick',1:numel(methods),'XTickLabel',{methods.short});
xtickangle(ax, 18);
ylabel(ax,'tail update activity (%)'); title(ax,'Run 2(d). Update activity under switching');
sgtitle(tl, 'Endogenous-aware recursion bridge - Run 2: switched C2M single-bank re-lock diagnostics', ...
    'FontName','Times New Roman', 'FontSize', 16, 'FontWeight','bold');
local_save(fig, fullfile(dirs.fig, ['Run2_SwitchedC2M_Relock_Diagnostics.' char(opt.format)]));
end

% ======================================================================
function run3 = local_run3_tap_bound(run2, methods, opt, dirs)
run3 = struct();
run3.methods = run2.methods;
run3.representative = run2.representative;
fig = figure('Color','w','Visible',char(opt.fig_visible), 'Position',[60 60 1280 620]);
tl = tiledlayout(fig, 1, 2, 'Padding','compact', 'TileSpacing','compact');
ax = nexttile(tl,1); hold(ax,'on'); grid(ax,'on'); box(ax,'on'); local_style_linear(ax);
for mi = 1:numel(methods)
    rep = run2.representative.(methods(mi).key);
    plot(ax, rep.iter, local_smooth(rep.theta_nonmain_max,5), 'Color', methods(mi).color, ...
        'LineWidth', 2.0 + 0.5*(mi==1), 'DisplayName', methods(mi).short);
end
xlabel(ax,'Iteration'); ylabel(ax,'max_i |theta_i|');
title(ax,'Run 3(a). Non-main tap activity through C2M switching');
legend(ax,'Location','best', 'Interpreter','none');
yl = ylim(ax);
ylim(ax, [0, max(0.12, min(0.5, yl(2)))]);

ax = nexttile(tl,2); hold(ax,'on'); grid(ax,'on'); box(ax,'on'); local_style_linear(ax);
for mi = 1:numel(methods)
    rep = run2.representative.(methods(mi).key);
    plot(ax, rep.iter, local_smooth(rep.theta_dfe_norm,5), 'Color', methods(mi).color, ...
        'LineWidth', 2.0 + 0.5*(mi==1), 'DisplayName', methods(mi).short);
end
xlabel(ax,'Iteration'); ylabel(ax,'||b_{DFE}||_2');
title(ax,'Run 3(b). Feedback-tap norm stability');
sgtitle(tl, 'Endogenous-aware recursion bridge - Run 3: projection and tap-norm diagnostics', ...
    'FontName','Times New Roman', 'FontSize', 16, 'FontWeight','bold');
local_save(fig, fullfile(dirs.fig, ['Run3_TapBound_TapNorm_Diagnostics.' char(opt.format)]));
end

% ======================================================================
function [d, r, sigma2, tx] = local_generate_static(cfg, ch, tx_ffe)
d = local_pam4(cfg.Nsym, cfg.A);
tx = local_apply_tx_ffe(d, tx_ffe);
r_clean = filter(ch.symbol_taps(:), 1, tx);
[r, sigma2] = local_add_awgn_agc(r_clean, tx, cfg.SNRdB);
end

function [d, r, sigma2, state_seq, tx] = local_generate_switched(cfg, channels, P)
d = local_pam4(cfg.Nsym, cfg.A);
tx = local_apply_tx_ffe(d, channels.tx_ffe);
state_seq = local_balanced_markov_state_seq(cfg.Nsym, cfg.trainLen, P);
h_bank = arrayfun(@(c)c.symbol_taps(:), channels.states, 'UniformOutput', false);
r_clean = local_fir_state_channel(tx, h_bank, state_seq);
[r, sigma2] = local_add_awgn_agc(r_clean, tx, cfg.SNRdB);
end

function refs = local_state_references(cfg, channels, d, sigma2)
refs = zeros(cfg.Nf+cfg.Nb, numel(channels.states));
tx = local_apply_tx_ffe(d, channels.tx_ffe);
for s = 1:numel(channels.states)
    r_clean = filter(channels.states(s).symbol_taps(:), 1, tx);
    gain = rms(tx) / max(rms(r_clean), eps);
    r_ref = r_clean * gain;
    refs(:,s) = local_reference_theta(r_ref, d, cfg);
end
end

function res = local_run_method(key, r, d, cfg, base, sigma2, mu_scale, theta_ref, block_len, theta_refs_by_state, state_seq)
P = cfg.Nf + cfg.Nb;
main_idx = cfg.D + 1;
theta = zeros(P,1);
theta(main_idx) = 1.0;
r_buf = zeros(cfg.Nf,1);
d_hat = zeros(numel(d),1);
d_fb = zeros(numel(d),1);
e = zeros(numel(r),1);
y = zeros(numel(r),1);
upd = false(numel(r),1);
theta_norm = zeros(numel(r),1);
theta_max = zeros(numel(r),1);
theta_nonmain_max = zeros(numel(r),1);
theta_dfe_norm = zeros(numel(r),1);
msd_active = nan(numel(r),1);

if isempty(theta_ref)
    theta_ref = zeros(P,1);
    theta_ref(main_idx) = 1;
end
if nargin < 10
    theta_refs_by_state = [];
end
if nargin < 11
    state_seq = [];
end

gamma_smn = sqrt(max(0, base.smnlms.tau * sigma2));
gamma_sms = sqrt(max(0, base.smsign.tau * sigma2));
res_ema = max(gamma_smn^2, eps);
ema_alpha = 0.982;

edges = 1:block_len:cfg.Nsym;
if edges(end) ~= cfg.Nsym + 1
    edges(end+1) = cfg.Nsym + 1;
end
nb = numel(edges)-1;
theta_blk = zeros(P,nb);

for n = 1:numel(r)
    r_buf = [r(n); r_buf(1:end-1)];
    m = n - cfg.D;
    if strcmpi(key, 'alg1')
        a_fb = get_fb_vector(m, d, d_fb, cfg, cfg.Nb);
    else
        a_fb = get_fb_vector(m, d, d_hat, cfg, cfg.Nb);
    end
    x = [r_buf; -a_fb];
    yn = theta.' * x;
    y(n) = yn;
    has_ref = (m >= 1 && m <= numel(d));
    if has_ref
        hard_dec = pam_slice_scalar(yn, cfg.A);
        if m <= cfg.trainLen
            d_hat(m) = d(m);
            d_fb(m) = d(m);
        else
            d_hat(m) = hard_dec;
            d_fb(m) = hard_dec;
        end
        if m <= cfg.trainLen
            d_des = d(m);
        else
            d_des = hard_dec;
        end
        en = d_des - yn;
        en_update = en;
        e(n) = en;
        p2 = (x.'*x) + 1e-12;
        switch lower(key)
            case 'smnlms'
                beta = base.smnlms.beta * mu_scale;
                if abs(en) > gamma_smn
                    mu_sm = beta * (1 - gamma_smn / max(abs(en), eps));
                    theta = theta + (mu_sm * en / (p2 + base.smnlms.eps_pow)) * x;
                    upd(n) = true;
                end
            case 'smsign'
                beta = base.smsign.beta * mu_scale;
                if abs(en) > gamma_sms
                    theta = theta + (beta * sign(en) / (p2 + base.smsign.eps_pow)) * x;
                    upd(n) = true;
                end
            case 'alg1'
                is_dd = m > cfg.trainLen;
                n_dd = max(0, m - cfg.trainLen);
                margin = local_pam_margin(yn, cfg.A);
                gamma0 = 0.75 * gamma_smn;
                [soft_fb, rel_w] = local_soft_feedback_symbol(yn, cfg.A, gamma0);
                if is_dd
                    soft_target = rel_w * hard_dec + (1 - rel_w) * soft_fb;
                    d_fb(m) = soft_target;
                    en_update = soft_target - yn;
                end
                res_ema = ema_alpha * res_ema + (1-ema_alpha) * en_update^2;
                uncertainty = 1 / (1 + margin / max(gamma0, eps));
                residual_load = sqrt(res_ema) / max(gamma0, eps);
                relock_load = max(0, residual_load - 1);
                burden = 0.10*uncertainty + 0.02*double(is_dd) + 0.012*relock_load;
                gamma_eff = gamma0 * min(1.28, 1 + 0.70*burden + 0.28*(1-rel_w)*double(is_dd));
                beta = base.smnlms.beta * mu_scale;
                dd_anneal = 0.22 + 0.78 * exp(-n_dd * log(2) / 5500);
                beta_eff = beta * (1.65*double(~is_dd) + 1.35*dd_anneal*double(is_dd));
                beta_eff = beta_eff * (1 + 0.45 * min(2.5, relock_load) * double(is_dd));
                beta_eff = beta_eff * max(0.93, 1/(1+0.08*burden));
                beta_eff = beta_eff * (double(~is_dd) + double(is_dd) * (0.35 + 1.15*rel_w));
                clip_lim = min(max(2.6 * gamma_eff, 0.72), 1.15);
                if ~is_dd
                    en_clip = sign(en_update) * min(abs(en_update), clip_lim);
                    theta = theta + (beta_eff * en_clip / (p2 + base.smnlms.eps_pow)) * x;
                    upd(n) = true;
                elseif abs(en_update) > gamma_eff
                    innov = (1 - gamma_eff / max(abs(en_update), eps)) * en_update;
                    innov = sign(innov) * min(abs(innov), clip_lim);
                    theta = theta + (beta_eff * innov / (p2 + base.smnlms.eps_pow)) * x;
                    upd(n) = true;
                end
                if upd(n)
                    leak_vec = theta;
                    leak_vec(main_idx) = 0;
                    theta = theta - 1.2e-5 * leak_vec;
                end
            otherwise
                error('Unknown method %s', key);
        end
        theta = local_project_theta(theta, cfg);
        theta(main_idx) = 1.0;
    end
    theta_norm(n) = norm(theta);
    theta_max(n) = max(abs(theta));
    nonmain = theta;
    nonmain(main_idx) = 0;
    theta_nonmain_max(n) = max(abs(nonmain));
    theta_dfe_norm(n) = norm(theta(cfg.Nf+1:end));
    if isempty(theta_refs_by_state)
        msd_active(n) = sum((theta - theta_ref(:)).^2);
    elseif ~isempty(state_seq) && n <= numel(state_seq)
        ss = max(1, min(size(theta_refs_by_state,2), state_seq(n)));
        msd_active(n) = sum((theta - theta_refs_by_state(:,ss)).^2);
    else
        msd_active(n) = sum((theta - theta_ref(:)).^2);
    end
    bi = floor((n-1)/block_len) + 1;
    if bi <= nb && (n == edges(bi+1)-1 || n == numel(r))
        theta_blk(:,bi) = theta;
    end
end

% If state references were provided without a state trajectory, approximate
% active-state MSD by the nearest state reference.  The switched C2M run
% passes state_seq, so its MSD is state-aligned sample by sample.
if ~isempty(theta_refs_by_state) && isempty(state_seq)
    for n = 1:numel(r)
        dif = sum((theta_blk(:,min(size(theta_blk,2),max(1,floor((n-1)/block_len)+1))) - theta_refs_by_state).^2, 1);
        msd_active(n) = min(dif);
    end
end

res = struct();
res.y = y;
res.d_hat = d_hat;
res.e = e;
res.update = upd;
res.theta_norm = theta_norm;
res.theta_max = theta_max;
res.theta_nonmain_max = theta_nonmain_max;
res.theta_dfe_norm = theta_dfe_norm;
res.msd_active = msd_active;
res.iter = local_block_centers(cfg.Nsym, block_len);
res.mse_block = local_block_mean(e.^2, block_len, cfg.Nsym);
res.emse_block = max(res.mse_block - sigma2, realmin);
res.update_block = local_block_mean(double(upd), block_len, cfg.Nsym);
res.theta_block = theta_blk.';
res.msd_block = sum((theta_blk - theta_ref(:)).^2, 1).';
end

function rep = local_representative_log(res, state_seq, cfg)
rep = struct();
step = max(1, floor(cfg.Nsym / 1200));
idx = (1:step:cfg.Nsym).';
rep.iter = idx;
rep.theta_norm = res.theta_norm(idx);
rep.theta_max = res.theta_max(idx);
rep.theta_nonmain_max = res.theta_nonmain_max(idx);
rep.theta_dfe_norm = res.theta_dfe_norm(idx);
rep.state = state_seq(idx);
end

function theta = local_reference_theta(r, d, cfg)
K = cfg.Nf;
L = cfg.Nb;
P = K + L;
main_idx = cfg.D + 1;
N = min(numel(r), numel(d)+cfg.D);
valid = (cfg.D+1):N;
X = zeros(numel(valid), P);
Y = zeros(numel(valid), 1);
row = 0;
for n = valid
    m = n - cfg.D;
    if m < 1 || m > numel(d), continue; end
    row = row + 1;
    rb = zeros(K,1);
    for k = 1:K
        if n-k+1 >= 1, rb(k) = r(n-k+1); end
    end
    fb = zeros(L,1);
    for k = 1:L
        if m-k >= 1, fb(k) = d(m-k); end
    end
    X(row,:) = [rb; -fb].';
    Y(row) = d(m);
end
X = X(1:row,:);
Y = Y(1:row);
theta = zeros(P,1);
theta(main_idx) = 1.0;
if isempty(X), return; end
cols = true(1,P);
cols(main_idx) = false;
y_adj = Y - X(:,main_idx);
lambda = 1e-4;
theta(cols) = (X(:,cols).'*X(:,cols) + lambda*eye(P-1)) \ (X(:,cols).'*y_adj);
theta = local_project_theta(theta, cfg);
end

function theta = local_project_theta(theta, cfg)
main_idx = cfg.D + 1;
w2_max = 5.0;
b_max = 2.0;
lo = [-w2_max*ones(cfg.Nf,1); -b_max*ones(cfg.Nb,1)];
hi = [ w2_max*ones(cfg.Nf,1);  b_max*ones(cfg.Nb,1)];
lo(main_idx) = -Inf;
hi(main_idx) = Inf;
theta = min(max(theta(:), lo), hi);
theta(main_idx) = 1.0;
end

% ======================================================================
function d = local_pam4(N, A)
idx = randi([1 numel(A)], N, 1);
d = A(idx).';
d = d(:);
end

function y = local_apply_tx_ffe(d, taps)
y = filter(taps(:), 1, d(:));
if rms(y) > eps
    y = y * (rms(d) / rms(y));
end
end

function [r, sigma2_eff] = local_add_awgn_agc(r_clean, tx_ref, snr_db)
sigma2 = mean(r_clean(:).^2) / (10^(snr_db/10));
r0 = r_clean(:) + sqrt(sigma2) * randn(size(r_clean(:)));
gain = rms(tx_ref(:)) / max(rms(r0), eps);
r = r0 * gain;
sigma2_eff = sigma2 * gain^2;
end

function state_seq = local_balanced_markov_state_seq(N, trainLen, P)
S = size(P,1);
state_seq = ones(N,1);
seg = max(1, floor(trainLen/S));
for s = 1:S
    a = (s-1)*seg + 1;
    b = min(trainLen, s*seg);
    state_seq(a:b) = s;
end
if S*seg < trainLen
    state_seq(S*seg+1:trainLen) = S;
end
state_seq(min(trainLen+1,N)) = min(2,S);
for n = trainLen+2:N
    prev = state_seq(n-1);
    cs = cumsum(P(prev,:));
    state_seq(n) = find(rand <= cs, 1, 'first');
end
end

function r_clean = local_fir_state_channel(tx, h_bank, state_seq)
N = numel(tx);
r_clean = zeros(N,1);
for n = 1:N
    h = h_bank{state_seq(n)}(:);
    acc = 0;
    for k = 1:numel(h)
        m = n-k+1;
        if m >= 1
            acc = acc + h(k) * tx(m);
        end
    end
    r_clean(n) = acc;
end
end

function y = local_block_mean(x, block_len, N)
edges = 1:block_len:N;
if edges(end) ~= N + 1, edges(end+1) = N + 1; end
y = nan(numel(edges)-1,1);
for bi = 1:numel(y)
    idx = edges(bi):edges(bi+1)-1;
    idx = idx(idx >= 1 & idx <= numel(x));
    if ~isempty(idx), y(bi) = mean(x(idx), 'omitnan'); end
end
end

function iter = local_block_centers(N, block_len)
edges = 1:block_len:N;
if edges(end) ~= N + 1, edges(end+1) = N + 1; end
iter = (edges(1:end-1) + edges(2:end) - 2)'/2;
end

function v = local_tail_mean(x)
x = x(:);
k0 = max(1, floor(0.80*numel(x)));
v = mean(x(k0:end), 'omitnan');
end

function y = local_accum(old, val, tr)
if tr == 1 || ~isfinite(old)
    y = val;
else
    y = old + (val - old) / tr;
end
end

function m = local_pam_margin(y, A)
A = sort(A(:));
thr = 0.5*(A(1:end-1)+A(2:end));
m = min(abs(y - thr));
end

function [soft_sym, rel_w] = local_soft_feedback_symbol(y, A, gamma0)
A = sort(A(:));
hard = pam_slice_scalar(y, A);
sigma_fb = max(0.30, 0.75*max(gamma0, eps));
ll = -((y - A).^2) / (2*sigma_fb^2);
ll = ll - max(ll);
p = exp(ll);
p = p / max(sum(p), eps);
soft_sym = sum(A .* p);
margin = local_pam_margin(y, A);
tau = max(0.28, 1.15*max(gamma0, eps));
u = min(1, max(0, margin / tau));
rel_w = u*u*(3 - 2*u);
% Keep soft feedback local: far from thresholds it is exactly hard-like.
if rel_w > 0.995
    soft_sym = hard;
end
end

function y = local_smooth(x, win)
x = x(:);
if numel(x) < win
    y = x;
else
    y = movmean(x, win, 'omitnan');
end
end

function f = local_plot_floor(x)
x = x(:);
x = x(isfinite(x) & x > 1e-12);
if isempty(x)
    f = 1e-8;
else
    f = max(1e-8, min(x)/3);
end
end

function local_progress(tag, outer, nOuter, tr, Nt)
if tr == Nt || mod(tr, max(1,ceil(Nt/4))) == 0
    fprintf('%s case %d/%d trial %d/%d\n', tag, outer, nOuter, tr, Nt);
end
end

function local_style_log(ax)
set(ax, 'YScale','log', 'FontName','Times New Roman', 'FontSize', 11, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.YMinorGrid = 'on';
ax.GridAlpha = 0.22;
ax.MinorGridAlpha = 0.12;
end

function local_style_linear(ax)
set(ax, 'FontName','Times New Roman', 'FontSize', 11, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.GridAlpha = 0.22;
ax.MinorGridAlpha = 0.12;
end

function local_save(fig, fname)
set(fig, 'PaperPositionMode', 'auto');
try
    exportgraphics(fig, fname, 'Resolution', 420);
catch
    saveas(fig, fname);
end
[p,n,~] = fileparts(fname);
try
    exportgraphics(fig, fullfile(p, [n '.pdf']), 'ContentType','vector');
catch
end
close(fig);
fprintf('[blockC_relock] saved %s\n', fname);
end

function local_write_summary(out, methods, opt, dirs)
fn = fullfile(dirs.tab, 'BlockC_RelockReference_Summary.txt');
fid = fopen(fn, 'w');
if fid < 0, return; end
fprintf(fid, 'Block C relock reference diagnostics v72\n\n');
fprintf(fid, 'Selected mu scales after static tune:\n');
for mi = 1:numel(methods)
    fprintf(fid, '  %s: %.4g\n', methods(mi).label, out.tune.mu_scale(mi));
end
fprintf(fid, '\nRun2 switched C2M floor:\n');
for mi = 1:numel(methods)
    fprintf(fid, '  %s: BER=%.4g, EMSE=%.4g, update=%.3f\n', ...
        methods(mi).label, out.run2.floor_BER(mi), out.run2.floor_emse(mi), out.run2.update_rate(mi));
end
fclose(fid);
end

function note_file = local_write_note(save_dir, opt, channels)
note_file = fullfile(save_dir, 'BlockC_RelockReference_Notes.md');
fid = fopen(note_file, 'w');
if fid < 0, return; end
fprintf(fid, '# Block C Re-lock Reference Diagnostics v72\n\n');
fprintf(fid, 'This run compares only three single-bank laws: Algorithm 1, Gazor-style SMNLMS-DFE, and de Souza-style SM-sign-NLMS.\n\n');
fprintf(fid, 'The channel is C2M S-parameter-derived: static %s for Run 1, and Markov switching among %s, %s, and %s for Run 2.\n\n', ...
    channels.static.case_id, channels.states(1).case_id, channels.states(2).case_id, channels.states(3).case_id);
fprintf(fid, 'The step-size scale is tuned once on static C2M at SNR %.3g dB using tune_policy=%s, then frozen for switched-channel diagnostics. This prevents detuning claims while allowing each method to use its own best operating point.\n\n', ...
    opt.snr_tune, char(opt.tune_policy));
fprintf(fid, 'Algorithm 1 uses an endogenous-aware projected leaky SM-NLMS update with reliability-clipped innovation. The clipping is an error-nonlinearity safeguard for low-SNR decision-directed samples, while the full-gradient component is retained when the innovation is reliable.\n\n');
fprintf(fid, 'Run 2 is not meant to prove that a single-bank law removes the Markov floor. It measures re-lock speed and residual floor. The full MSB/HMM receiver remains the mechanism that removes cross-state DFE-memory contamination.\n');
fclose(fid);
end
