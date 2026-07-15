function out = run_blockC_adaptive_filter_suite_v72(varargin)
%RUN_BLOCKC_ADAPTIVE_FILTER_SUITE_V72
% Adaptive-filter diagnostics for the endogenous-aware single-bank bridge.
%
% This runner intentionally avoids duplicating the Block-B BER endpoint.
% It follows the diagnostic language used by NLMS/SMNLMS/sign-error
% adaptive-filter papers: learning curves, EMSE/MSD, convergence versus
% misadjustment, SNR robustness, and data-selective update activity.
%
% All methods use the same PAM4 DFE structure:
%   Nf = 7, Nb = 3, D = 3, decision-directed mode, fixed main tap.
% Only the coefficient update law is changed.

p = inputParser;
addParameter(p, 'trials', 20, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'samples', 40000, @(x)isnumeric(x) && isscalar(x) && x > 1000);
addParameter(p, 'trainLen', 8000, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'snr', 10:2:30, @isnumeric);
addParameter(p, 'snr_diag', 22, @(x)isnumeric(x) && isscalar(x));
addParameter(p, 'block_len', 400, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'mu_grid', [0.25 0.5 0.75 1.0 1.5 2.0 3.0 4.0], @isnumeric);
addParameter(p, 'save_dir', fullfile('paper_final_blockC_adaptive_filter_suite_v72'), @ischar);
addParameter(p, 'fig_visible', 'off', @(x)ischar(x) || isstring(x));
addParameter(p, 'format', 'png', @(x)ischar(x) || isstring(x));
addParameter(p, 'force', false, @islogical);
addParameter(p, 'run_C1', true, @islogical);
addParameter(p, 'run_C2', true, @islogical);
addParameter(p, 'run_C3', true, @islogical);
addParameter(p, 'run_C4', true, @islogical);
addParameter(p, 'run_C5', true, @islogical);
parse(p, varargin{:});
opt = p.Results;

addpath(genpath(pwd));
if exist(opt.save_dir, 'dir') ~= 7
    mkdir(opt.save_dir);
end
fig_dir = fullfile(opt.save_dir, 'figures');
tab_dir = fullfile(opt.save_dir, 'tables');
mat_dir = fullfile(opt.save_dir, 'mat');
if exist(fig_dir, 'dir') ~= 7, mkdir(fig_dir); end
if exist(tab_dir, 'dir') ~= 7, mkdir(tab_dir); end
if exist(mat_dir, 'dir') ~= 7, mkdir(mat_dir); end

cfg = local_suite_cfg(opt);
base = build_baselines();
base.mu_sign_lms = local_getfield(base, 'mu_sign_lms', base.mu_lms);
methods = local_methods();

fprintf('[blockC_suite] trials=%d, Nsym=%d, trainLen=%d, SNR=[%s]\n', ...
    opt.trials, cfg.Nsym, cfg.trainLen, num2str(opt.snr));
fprintf('[blockC_suite] common architecture: Nf=%d, Nb=%d, D=%d\n', ...
    cfg.Nf, cfg.Nb, cfg.D);

out = struct();
out.options = opt;
out.cfg = cfg;
out.methods = {methods.label};
out.reference_note = local_write_reference_note(opt.save_dir);

if opt.run_C1
    out.C1 = local_C1_learning_per_state(cfg, base, methods, opt, mat_dir, tab_dir, fig_dir);
end
if opt.run_C2
    out.C2 = local_C2_tradeoff(cfg, base, methods, opt, mat_dir, tab_dir, fig_dir);
end
if opt.run_C3
    out.C3 = local_C3_snr_robustness(cfg, base, methods, opt, mat_dir, tab_dir, fig_dir);
end
if opt.run_C4
    if ~isfield(out, 'C3')
        out.C3 = local_C3_snr_robustness(cfg, base, methods, opt, mat_dir, tab_dir, fig_dir);
    end
    out.C4 = local_C4_update_cost(out.C3, methods, opt, tab_dir, fig_dir);
end
if opt.run_C5
    out.C5 = local_C5_relock_transient(cfg, base, methods, opt, mat_dir, tab_dir, fig_dir);
end

save(fullfile(mat_dir, 'BlockC_AdaptiveFilterSuite_v72.mat'), 'out', '-v7.3');
fprintf('[blockC_suite] done. Results in %s\n', opt.save_dir);
end

% ======================================================================
function cfg = local_suite_cfg(opt)
cfg = build_main_config();
cfg.Nsym = round(opt.samples);
cfg.trainLen = min(round(opt.trainLen), floor(0.25*cfg.Nsym));
cfg.Nf = 7;
cfg.Nb = 3;
cfg.D = 3;
cfg.chan_mode = 'frozen_markov_state';
mkprof = controlled_markov_isi_profile_v72('profile', 'severe_partial_response');
cfg.markov.h2_states = mkprof.h2_states;
cfg.markov.P = mkprof.P;
cfg.markov.init_state = mkprof.init_state;
cfg.markov.fixed_state = 2;
cfg.markov.profile = mkprof;
end

function methods = local_methods()
methods = struct([]);
methods(1).key = 'nlms';
methods(1).label = 'epsilon-NLMS [17]';
methods(1).short = 'epsilon-NLMS';
methods(1).marker = 'o';
methods(1).color = [0.000 0.447 0.741];
methods(1).mac_base = 18;
methods(1).mac_update = 28;

methods(2).key = 'smnlms';
methods(2).label = 'SMNLMS-DFE [30]';
methods(2).short = 'SMNLMS-DFE';
methods(2).marker = 's';
methods(2).color = [0.850 0.325 0.098];
methods(2).mac_base = 18;
methods(2).mac_update = 32;

methods(3).key = 'smsign';
methods(3).label = 'SM-sign-NLMS [20]';
methods(3).short = 'SM-sign-NLMS';
methods(3).marker = '^';
methods(3).color = [0.929 0.694 0.125];
methods(3).mac_base = 18;
methods(3).mac_update = 24;

methods(4).key = 'sign_lms';
methods(4).label = 'sign-error LMS [18]';
methods(4).short = 'sign-error LMS';
methods(4).marker = 'v';
methods(4).color = [0.494 0.184 0.556];
methods(4).mac_base = 18;
methods(4).mac_update = 12;

methods(5).key = 'alg1';
methods(5).label = 'Algorithm 1: endogenous-aware';
methods(5).short = 'Algorithm 1';
methods(5).marker = 'd';
methods(5).color = [0.635 0.078 0.184];
methods(5).mac_base = 18;
methods(5).mac_update = 40;
end

% ======================================================================
function C1 = local_C1_learning_per_state(cfg0, base, methods, opt, mat_dir, tab_dir, fig_dir)
cache = fullfile(mat_dir, 'C1_learning_per_state.mat');
if exist(cache, 'file') == 2 && ~opt.force
    S = load(cache, 'C1');
    C1 = S.C1;
    local_plot_C1(C1, methods, opt, fig_dir);
    return;
end

Slist = 1:3;
nb = local_num_blocks(cfg0.Nsym, opt.block_len);
nM = numel(methods);
emse_acc = zeros(nb,nM,numel(Slist));
mse_acc = zeros(nb,nM,numel(Slist));
msd_acc = zeros(nb,nM,numel(Slist));
upd_acc = zeros(nb,nM,numel(Slist));
conv = nan(numel(Slist),nM);
tail_emse = nan(numel(Slist),nM);
tail_msd = nan(numel(Slist),nM);

for si = 1:numel(Slist)
    for tr = 1:opt.trials
        rng(611000 + 10000*si + tr);
        cfg = cfg0;
        cfg.SNRdB = opt.snr_diag;
        cfg.chan_mode = 'frozen_markov_state';
        cfg.markov.fixed_state = Slist(si);
        [d, r, sigma2] = local_generate_run(cfg);
        theta_ref = local_reference_theta(r, d, cfg);
        for mi = 1:nM
            res = local_run_method(methods(mi).key, r, d, cfg, base, sigma2, ...
                struct('mu_scale',local_nominal_mu_scale(methods(mi).key), ...
                'theta_ref',theta_ref,'block_len',opt.block_len));
            emse_acc(:,mi,si) = emse_acc(:,mi,si) + res.emse_block(:);
            mse_acc(:,mi,si) = mse_acc(:,mi,si) + res.mse_block(:);
            msd_acc(:,mi,si) = msd_acc(:,mi,si) + res.msd_block(:);
            upd_acc(:,mi,si) = upd_acc(:,mi,si) + res.update_block(:);
        end
        local_progress('[C1]', si, numel(Slist), tr, opt.trials);
    end
end

C1 = struct();
C1.iter = local_block_centers(cfg0.Nsym, opt.block_len);
C1.states = cfg0.markov.h2_states(:);
C1.methods = {methods.label};
C1.emse = emse_acc / opt.trials;
C1.mse = mse_acc / opt.trials;
C1.msd = msd_acc / opt.trials;
C1.update = upd_acc / opt.trials;
for si = 1:numel(Slist)
    for mi = 1:nM
        tail_emse(si,mi) = local_tail_mean(C1.emse(:,mi,si));
        tail_msd(si,mi) = local_tail_mean(C1.msd(:,mi,si));
        conv(si,mi) = local_convergence_time(C1.iter, C1.emse(:,mi,si));
    end
end
C1.tail_emse = tail_emse;
C1.tail_msd = tail_msd;
C1.convergence_symbols = conv;

T = local_C1_table(C1, methods);
writetable(T, fullfile(tab_dir, 'C1_PerState_Learning_EMSE_MSD.csv'));
save(cache, 'C1', '-v7.3');
local_plot_C1(C1, methods, opt, fig_dir);
end

function T = local_C1_table(C1, methods)
T = table();
for si = 1:numel(C1.states)
    for mi = 1:numel(methods)
        T = [T; table(si, C1.states(si), string(methods(mi).label), ...
            C1.tail_emse(si,mi), C1.tail_msd(si,mi), C1.convergence_symbols(si,mi), ...
            'VariableNames', {'StateIndex','h2','Method','TailEMSE','TailMSD','ConvergenceSymbols'})]; %#ok<AGROW>
    end
end
end

function local_plot_C1(C1, methods, opt, fig_dir)
fig = figure('Color','w','Visible',char(opt.fig_visible), 'Position',[60 60 1350 820]);
tl = tiledlayout(fig, 2, 3, 'Padding','compact', 'TileSpacing','compact');
for si = 1:numel(C1.states)
    ax = nexttile(tl, si); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    local_style_log(ax);
    for mi = 1:numel(methods)
        semilogy(ax, C1.iter, max(local_smooth(C1.emse(:,mi,si),5), realmin), ...
            'Color', methods(mi).color, 'LineWidth', 1.5 + 0.6*(mi==5), ...
            'DisplayName', methods(mi).short);
    end
    title(ax, sprintf('State %d: h_2 = %.2f, EMSE', si, C1.states(si)));
    xlabel(ax,'Iteration'); ylabel(ax,'EMSE');
    if si == 1, legend(ax,'Location','northeast', 'Interpreter','none'); end

    ax = nexttile(tl, si+3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    local_style_log(ax);
    for mi = 1:numel(methods)
        semilogy(ax, C1.iter, max(local_smooth(C1.msd(:,mi,si),5), realmin), ...
            'Color', methods(mi).color, 'LineWidth', 1.5 + 0.6*(mi==5), ...
            'DisplayName', methods(mi).short);
    end
    title(ax, sprintf('State %d: tap MSD to supervised reference', si));
    xlabel(ax,'Iteration'); ylabel('MSD proxy');
end
sgtitle(tl, 'C1. Per-state learning curves: same DFE, different update laws', ...
    'FontName','Times New Roman', 'FontSize',16, 'FontWeight','bold');
local_save(fig, fullfile(fig_dir, ['C1_PerState_Learning_EMSE_MSD.' char(opt.format)]));
end

% ======================================================================
function C2 = local_C2_tradeoff(cfg0, base, methods, opt, mat_dir, tab_dir, fig_dir)
cache = fullfile(mat_dir, 'C2_convergence_misadjustment_tradeoff.mat');
if exist(cache, 'file') == 2 && ~opt.force
    S = load(cache, 'C2');
    C2 = S.C2;
    local_plot_C2(C2, methods, opt, fig_dir);
    return;
end

cfg = cfg0;
cfg.SNRdB = opt.snr_diag;
cfg.chan_mode = 'frozen_markov_state';
cfg.markov.fixed_state = 2;
nM = numel(methods);
nG = numel(opt.mu_grid);
tail = nan(nM,nG);
conv = nan(nM,nG);
upd = nan(nM,nG);

for gi = 1:nG
    for tr = 1:opt.trials
        rng(622000 + 10000*gi + tr);
        [d, r, sigma2] = local_generate_run(cfg);
        theta_ref = local_reference_theta(r, d, cfg);
        for mi = 1:nM
            res = local_run_method(methods(mi).key, r, d, cfg, base, sigma2, ...
                struct('mu_scale',opt.mu_grid(gi),'theta_ref',theta_ref,'block_len',opt.block_len));
            tail(mi,gi) = local_accum(tail(mi,gi), local_tail_mean(res.emse_block), tr);
            conv(mi,gi) = local_accum(conv(mi,gi), local_convergence_time(res.iter, res.emse_block), tr);
            upd(mi,gi) = local_accum(upd(mi,gi), local_tail_mean(res.update_block), tr);
        end
        local_progress('[C2]', gi, nG, tr, opt.trials);
    end
end

C2 = struct();
C2.mu_grid = opt.mu_grid(:);
C2.methods = {methods.label};
C2.tail_emse = tail;
C2.convergence_symbols = conv;
C2.update_rate = upd;
C2.snr_diag = opt.snr_diag;
T = table();
for mi = 1:nM
    for gi = 1:nG
        T = [T; table(string(methods(mi).label), opt.mu_grid(gi), tail(mi,gi), ...
            conv(mi,gi), upd(mi,gi), 'VariableNames', ...
            {'Method','MuScale','TailEMSE','ConvergenceSymbols','UpdateRate'})]; %#ok<AGROW>
    end
end
writetable(T, fullfile(tab_dir, 'C2_Convergence_Misadjustment_Tradeoff.csv'));
save(cache, 'C2', '-v7.3');
local_plot_C2(C2, methods, opt, fig_dir);
end

function local_plot_C2(C2, methods, opt, fig_dir)
fig = figure('Color','w','Visible',char(opt.fig_visible), 'Position',[80 80 900 650]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_logy(ax);
for mi = 1:numel(methods)
    semilogy(ax, C2.convergence_symbols(mi,:), max(C2.tail_emse(mi,:), realmin), ...
        ['-' methods(mi).marker], 'Color', methods(mi).color, ...
        'MarkerFaceColor', methods(mi).color, 'LineWidth', 1.8 + 0.6*(mi==5), ...
        'MarkerSize', 6 + 2*(mi==5), 'DisplayName', methods(mi).short);
end
xlabel(ax,'Convergence time (symbols)');
ylabel(ax,'steady-state EMSE');
title(ax, sprintf('C2. Convergence-misadjustment tradeoff, SNR = %g dB', C2.snr_diag));
legend(ax,'Location','northeast', 'Interpreter','none');
local_save(fig, fullfile(fig_dir, ['C2_Convergence_Misadjustment_Tradeoff.' char(opt.format)]));
end

% ======================================================================
function C3 = local_C3_snr_robustness(cfg0, base, methods, opt, mat_dir, tab_dir, fig_dir)
cache = fullfile(mat_dir, 'C3_static_snr_robustness.mat');
if exist(cache, 'file') == 2 && ~opt.force
    S = load(cache, 'C3');
    C3 = S.C3;
    local_plot_C3(C3, methods, opt, fig_dir);
    return;
end

cfg = cfg0;
cfg.chan_mode = 'frozen_markov_state';
cfg.markov.fixed_state = 2;
nM = numel(methods);
nS = numel(opt.snr);
tail_emse = nan(nS,nM);
tail_mse = nan(nS,nM);
ber = nan(nS,nM);
ser = nan(nS,nM);
upd = nan(nS,nM);

for si = 1:nS
    cfg.SNRdB = opt.snr(si);
    for tr = 1:opt.trials
        rng(633000 + 10000*si + tr);
        [d, r, sigma2] = local_generate_run(cfg);
        theta_ref = local_reference_theta(r, d, cfg);
        for mi = 1:nM
            res = local_run_method(methods(mi).key, r, d, cfg, base, sigma2, ...
                struct('mu_scale',local_nominal_mu_scale(methods(mi).key), ...
                'theta_ref',theta_ref,'block_len',opt.block_len));
            tail_emse(si,mi) = local_accum(tail_emse(si,mi), local_tail_mean(res.emse_block), tr);
            tail_mse(si,mi) = local_accum(tail_mse(si,mi), local_tail_mean(res.mse_block), tr);
            sv = ser_after_training_aligned(d, res.d_hat, cfg);
            ser(si,mi) = local_accum(ser(si,mi), sv, tr);
            ber(si,mi) = local_accum(ber(si,mi), sv/log2(cfg.M), tr);
            upd(si,mi) = local_accum(upd(si,mi), local_tail_mean(res.update_block), tr);
        end
        local_progress('[C3]', si, nS, tr, opt.trials);
    end
end

C3 = struct();
C3.snr = opt.snr(:);
C3.methods = {methods.label};
C3.tail_emse = tail_emse;
C3.tail_mse = tail_mse;
C3.BER = ber;
C3.SER = ser;
C3.update_rate = upd;
T = table();
for si = 1:nS
    for mi = 1:nM
        T = [T; table(opt.snr(si), string(methods(mi).label), ber(si,mi), ser(si,mi), ...
            tail_emse(si,mi), tail_mse(si,mi), upd(si,mi), ...
            'VariableNames', {'SNRdB','Method','BER','SER','TailEMSE','TailMSE','UpdateRate'})]; %#ok<AGROW>
    end
end
writetable(T, fullfile(tab_dir, 'C3_Static_SNR_Robustness_EMSE_BER.csv'));
save(cache, 'C3', '-v7.3');
local_plot_C3(C3, methods, opt, fig_dir);
end

function local_plot_C3(C3, methods, opt, fig_dir)
fig = figure('Color','w','Visible',char(opt.fig_visible), 'Position',[70 70 1250 560]);
tl = tiledlayout(fig, 1, 2, 'Padding','compact', 'TileSpacing','compact');
ax = nexttile(tl, 1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log(ax);
for mi = 1:numel(methods)
    semilogy(ax, C3.snr, max(C3.tail_emse(:,mi), realmin), ...
        ['-' methods(mi).marker], 'Color', methods(mi).color, ...
        'MarkerFaceColor', methods(mi).color, 'LineWidth', 1.6 + 0.7*(mi==5), ...
        'MarkerSize', 6 + 2*(mi==5), 'DisplayName', methods(mi).short);
end
xlabel(ax,'SNR (dB)'); ylabel(ax,'steady-state EMSE');
title(ax,'C3(a). Static-channel low-SNR robustness');
legend(ax,'Location','northeast', 'Interpreter','none');

ax = nexttile(tl, 2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log(ax);
ber_floor = 1e-6;
for mi = 1:numel(methods)
    semilogy(ax, C3.snr, max(C3.BER(:,mi), ber_floor), ...
        ['-' methods(mi).marker], 'Color', methods(mi).color, ...
        'MarkerFaceColor', methods(mi).color, 'LineWidth', 1.6 + 0.7*(mi==5), ...
        'MarkerSize', 6 + 2*(mi==5), 'DisplayName', methods(mi).short);
end
yline(ax, 2.4e-4, 'k--', 'KP4 FEC 2.4e-4', 'HandleVisibility','off');
xlabel(ax,'SNR (dB)'); ylabel(ax,'pre-FEC BER');
title(ax,'C3(b). BER is secondary here, EMSE is primary');
legend(ax,'Location','southwest', 'Interpreter','none');
ylim(ax, [ber_floor, 1]);
sgtitle(tl, 'C3. Static frozen-state robustness: no HMM, no switching endpoint', ...
    'FontName','Times New Roman', 'FontSize', 16, 'FontWeight','bold');
local_save(fig, fullfile(fig_dir, ['C3_Static_SNR_Robustness_EMSE_BER.' char(opt.format)]));
end

% ======================================================================
function C4 = local_C4_update_cost(C3, methods, opt, tab_dir, fig_dir)
nM = numel(methods);
nS = numel(C3.snr);
mac = nan(nS,nM);
for mi = 1:nM
    mac(:,mi) = methods(mi).mac_base + methods(mi).mac_update .* C3.update_rate(:,mi);
end
C4 = struct();
C4.snr = C3.snr;
C4.methods = {methods.label};
C4.tail_emse = C3.tail_emse;
C4.update_rate = C3.update_rate;
C4.mac_per_symbol = mac;
T = table();
for si = 1:nS
    for mi = 1:nM
        T = [T; table(C3.snr(si), string(methods(mi).label), C3.tail_emse(si,mi), ...
            C3.update_rate(si,mi), mac(si,mi), 'VariableNames', ...
            {'SNRdB','Method','TailEMSE','UpdateRate','ApproxMACperSymbol'})]; %#ok<AGROW>
    end
end
writetable(T, fullfile(tab_dir, 'C4_UpdateRate_Cost_vs_EMSE.csv'));

fig = figure('Color','w','Visible',char(opt.fig_visible), 'Position',[80 80 900 650]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_logy(ax);
for mi = 1:nM
    semilogy(ax, mac(:,mi), max(C3.tail_emse(:,mi), realmin), ...
        methods(mi).marker, 'Color', methods(mi).color, ...
        'MarkerFaceColor', methods(mi).color, 'MarkerSize', 7 + 2*(mi==5), ...
        'LineWidth', 1.5, 'DisplayName', methods(mi).short);
end
xlabel(ax,'approximate MAC/symbol');
ylabel(ax,'steady-state EMSE');
title(ax,'C4. Update-rate/cost versus EMSE');
legend(ax,'Location','northeast', 'Interpreter','none');
local_save(fig, fullfile(fig_dir, ['C4_UpdateRate_Cost_vs_EMSE.' char(opt.format)]));
end

% ======================================================================
function C5 = local_C5_relock_transient(cfg0, base, methods, opt, mat_dir, tab_dir, fig_dir)
cache = fullfile(mat_dir, 'C5_markov_relock_transient.mat');
if exist(cache, 'file') == 2 && ~opt.force
    S = load(cache, 'C5');
    C5 = S.C5;
    local_plot_C5(C5, methods, opt, fig_dir);
    return;
end

cfg = cfg0;
cfg.SNRdB = opt.snr_diag;
cfg.chan_mode = 'markov_2tap';
cfg.markov.fixed_state = [];
win_pre = 600;
win_post = 1800;
offset = (-win_pre:opt.block_len:win_post).';
nb = numel(offset)-1;
nM = numel(methods);
rel_mse_acc = zeros(nb,nM);
counts = zeros(nb,1);
floor_emse = nan(opt.trials,nM);

for tr = 1:opt.trials
    rng(644000 + tr);
    [d, r, sigma2, ch] = local_generate_run(cfg);
    theta_ref = local_reference_theta(r, d, cfg);
    E = cell(1,nM);
    for mi = 1:nM
        res = local_run_method(methods(mi).key, r, d, cfg, base, sigma2, ...
            struct('mu_scale',local_nominal_mu_scale(methods(mi).key), ...
            'theta_ref',theta_ref,'block_len',opt.block_len));
        E{mi} = res.e(:).^2;
        floor_emse(tr,mi) = local_tail_mean(res.emse_block);
    end
    sw = find(diff(ch.state(:)) ~= 0) + 1;
    sw = sw(sw > cfg.trainLen + win_pre & sw < cfg.Nsym - win_post);
    if numel(sw) > 40
        sw = sw(round(linspace(1, numel(sw), 40)));
    end
    for sidx = 1:numel(sw)
        s0 = sw(sidx);
        for bi = 1:nb
            idx = s0 + offset(bi):s0 + offset(bi+1)-1;
            idx = idx(idx >= 1 & idx <= cfg.Nsym);
            if isempty(idx), continue; end
            for mi = 1:nM
                rel_mse_acc(bi,mi) = rel_mse_acc(bi,mi) + mean(E{mi}(idx), 'omitnan');
            end
            counts(bi) = counts(bi) + 1;
        end
    end
    local_progress('[C5]', 1, 1, tr, opt.trials);
end
rel_mse = rel_mse_acc ./ max(counts,1);
C5 = struct();
C5.offset = (offset(1:end-1)+offset(2:end)-1)/2;
C5.methods = {methods.label};
C5.relock_mse = rel_mse;
C5.floor_emse = mean(floor_emse,1,'omitnan');
C5.counts = counts;
T = table();
for mi = 1:nM
    T = [T; table(string(methods(mi).label), C5.floor_emse(mi), ...
        'VariableNames', {'Method','MarkovFloorEMSE'})]; %#ok<AGROW>
end
writetable(T, fullfile(tab_dir, 'C5_Markov_SingleBank_Relock_Floor.csv'));
save(cache, 'C5', '-v7.3');
local_plot_C5(C5, methods, opt, fig_dir);
end

function local_plot_C5(C5, methods, opt, fig_dir)
fig = figure('Color','w','Visible',char(opt.fig_visible), 'Position',[80 80 900 650]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
local_style_log(ax);
for mi = 1:numel(methods)
    nr = size(C5.relock_mse,1);
    floor_i = mean(C5.relock_mse(max(1,nr-1):nr,mi), 'omitnan');
    yy = max(local_smooth(C5.relock_mse(:,mi) - floor_i, 3), 1e-5);
    semilogy(ax, C5.offset, yy, ...
        'Color', methods(mi).color, 'LineWidth', 1.6 + 0.7*(mi==5), ...
        'DisplayName', methods(mi).short);
end
xline(ax, 0, 'k:', 'channel switch', 'HandleVisibility','off');
xlabel(ax,'Symbols relative to channel-state switch');
ylabel(ax,'excess MSE above post-switch floor');
title(ax,'C5. Single-bank re-lock transient under Markov switching');
legend(ax,'Location','northeast', 'Interpreter','none');
local_save(fig, fullfile(fig_dir, ['C5_Markov_Relock_Transient.' char(opt.format)]));
end

% ======================================================================
function [d, r, sigma2, ch_state] = local_generate_run(cfg)
sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
d = cfg.A(sym_idx).';
d = d(:);
[r_clean, ch_state] = channel_out(d, cfg);
[r, sigma2] = add_noise_dispatch(r_clean, cfg);
end

function res = local_run_method(key, r, d, cfg, base, sigma2, opts)
P = cfg.Nf + cfg.Nb;
main_idx = cfg.D + 1;
theta = zeros(P,1);
theta(main_idx) = 1.0;
r_buf = zeros(cfg.Nf,1);
d_hat = zeros(numel(d),1);
e = zeros(numel(r),1);
y = zeros(numel(r),1);
upd = false(numel(r),1);

theta_ref = local_opt(opts, 'theta_ref', zeros(P,1));
block_len = local_opt(opts, 'block_len', 400);
mu_scale = local_opt(opts, 'mu_scale', 1.0);
gamma_smn = sqrt(max(0, base.smnlms.tau * sigma2));
gamma_sms = sqrt(max(0, base.smsign.tau * sigma2));
res_ema = max(gamma_smn^2, eps);
ema_alpha = 0.98;

edges = 1:block_len:cfg.Nsym;
if edges(end) ~= cfg.Nsym + 1
    edges(end+1) = cfg.Nsym + 1;
end
nb = numel(edges)-1;
theta_blk = zeros(P,nb);

for n = 1:numel(r)
    r_buf = [r(n); r_buf(1:end-1)];
    m = n - cfg.D;
    a_fb = get_fb_vector(m, d, d_hat, cfg, cfg.Nb);
    x = [r_buf; -a_fb];
    yn = theta.' * x;
    y(n) = yn;
    has_ref = (m >= 1 && m <= numel(d));
    if has_ref
        d_hat(m) = pam_slice_scalar(yn, cfg.A);
        if m <= cfg.trainLen
            d_des = d(m);
        else
            d_des = pam_slice_scalar(yn, cfg.A);
        end
        en = d_des - yn;
        e(n) = en;
        p2 = (x.'*x) + 1e-12;
        switch lower(key)
            case 'nlms'
                mu = base.mu_nlms * mu_scale;
                theta = theta + (mu * en / (p2 + base.eps_nlms)) * x;
                upd(n) = true;
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
            case 'sign_lms'
                mu = base.mu_sign_lms * mu_scale;
                theta = theta + mu * sign(en) * x;
                upd(n) = true;
            case 'alg1'
                res_ema = ema_alpha * res_ema + (1-ema_alpha) * en^2;
                is_dd = m > cfg.trainLen;
                n_dd = max(0, m - cfg.trainLen);
                margin = local_pam_margin(yn, cfg.A);
                gamma0 = 0.70 * gamma_smn;
                uncertainty = 1 / (1 + margin / max(gamma0, eps));
                residual_load = sqrt(res_ema) / max(gamma0, eps);
                relock_load = max(0, residual_load - 1);
                burden = 0.12*uncertainty + 0.03*double(is_dd) + ...
                    0.020*relock_load;
                gamma_eff = gamma0 * min(1.14, 1 + 0.85*burden);
                beta = base.smnlms.beta * mu_scale;
                dd_anneal = 0.25 + 0.75 * exp(-n_dd * log(2) / 6000);
                train_boost = 1.80;
                dd_boost = 1.55 * dd_anneal;
                beta_eff = beta * (train_boost * double(~is_dd) + dd_boost * double(is_dd));
                beta_eff = beta_eff * (1 + 0.45 * min(2.0, relock_load) * double(is_dd));
                beta_eff = beta_eff * max(0.94, 1/(1+0.12*burden));
                if ~is_dd
                    % In the supervised segment the endogenous decision
                    % burden is absent, so Algorithm 1 uses the full
                    % normalized gradient for fast acquisition.  The DD
                    % segment then switches to the SM gate below.
                    theta = theta + (beta_eff * en / (p2 + base.smnlms.eps_pow)) * x;
                    upd(n) = true;
                elseif abs(en) > gamma_eff
                    innov = (1 - gamma_eff / max(abs(en), eps)) * en;
                    theta = theta + (beta_eff * innov / (p2 + base.smnlms.eps_pow)) * x;
                    upd(n) = true;
                end
                if upd(n)
                    leak_vec = theta;
                    leak_vec(main_idx) = 0;
                    theta = theta - 1e-5 * leak_vec;
                end
            otherwise
                error('Unknown method key: %s', key);
        end
        theta = local_project_theta(theta, cfg);
        theta(main_idx) = 1.0;
    end
    bi = floor((n-1)/block_len) + 1;
    if bi <= nb && (n == edges(bi+1)-1 || n == numel(r))
        theta_blk(:,bi) = theta;
    end
end

res = struct();
res.y = y;
res.d_hat = d_hat;
res.e = e;
res.update = upd;
res.iter = local_block_centers(cfg.Nsym, block_len);
res.mse_block = local_block_mean(e.^2, block_len, cfg.Nsym);
res.emse_block = max(res.mse_block - sigma2, realmin);
res.update_block = local_block_mean(double(upd), block_len, cfg.Nsym);
res.theta_block = theta_blk.';
res.msd_block = sum((theta_blk - theta_ref(:)).^2, 1).';
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
        if n-k+1 >= 1
            rb(k) = r(n-k+1);
        end
    end
    fb = zeros(L,1);
    for k = 1:L
        if m-k >= 1
            fb(k) = d(m-k);
        end
    end
    X(row,:) = [rb; -fb].';
    Y(row) = d(m);
end
X = X(1:row,:);
Y = Y(1:row);
if isempty(X)
    theta = zeros(P,1);
    theta(main_idx) = 1;
    return;
end
cols = true(1,P);
cols(main_idx) = false;
y_adj = Y - X(:,main_idx);
lambda = 1e-4;
theta = zeros(P,1);
theta(main_idx) = 1.0;
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
function y = local_block_mean(x, block_len, N)
edges = 1:block_len:N;
if edges(end) ~= N + 1
    edges(end+1) = N + 1;
end
y = nan(numel(edges)-1,1);
for bi = 1:numel(y)
    idx = edges(bi):edges(bi+1)-1;
    idx = idx(idx >= 1 & idx <= numel(x));
    if ~isempty(idx)
        y(bi) = mean(x(idx), 'omitnan');
    end
end
end

function n = local_num_blocks(N, block_len)
n = numel(1:block_len:N);
end

function iter = local_block_centers(N, block_len)
edges = 1:block_len:N;
if edges(end) ~= N + 1
    edges(end+1) = N + 1;
end
iter = (edges(1:end-1) + edges(2:end) - 2)'/2;
end

function v = local_tail_mean(x)
x = x(:);
k0 = max(1, floor(0.80*numel(x)));
v = mean(x(k0:end), 'omitnan');
end

function t = local_convergence_time(iter, curve)
curve = curve(:);
iter = iter(:);
tail = local_tail_mean(curve);
thr = 1.10 * tail;
t = iter(end);
for k = 1:numel(curve)
    if all(curve(k:end) <= thr | ~isfinite(curve(k:end)))
        t = iter(k);
        return;
    end
end
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

function v = local_opt(s, name, def)
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = def;
end
end

function s = local_nominal_mu_scale(key)
% Nominal operating points selected from the C2 tradeoff sweep.  The full
% sweep remains saved, so the paper can show that baselines are not detuned.
switch lower(key)
    case {'nlms','smnlms','smsign','alg1'}
        s = 2.0;
    case 'sign_lms'
        s = 0.5;
    otherwise
        s = 1.0;
end
end

function v = local_getfield(s, name, def)
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = def;
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

function local_progress(tag, outer, nOuter, tr, Nt)
if tr == Nt || mod(tr, max(1,ceil(Nt/4))) == 0
    fprintf('%s case %d/%d trial %d/%d\n', tag, outer, nOuter, tr, Nt);
end
end

function local_style_log(ax)
set(ax, 'YScale','log', 'FontName','Times New Roman', 'FontSize', 10.5, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.YMinorGrid = 'on';
ax.GridAlpha = 0.22;
ax.MinorGridAlpha = 0.12;
end

function local_style_logy(ax)
set(ax, 'YScale','log', 'FontName','Times New Roman', 'FontSize', 11, ...
    'LineWidth',1.0, 'TickDir','in', 'XMinorTick','on', 'YMinorTick','on');
ax.YMinorGrid = 'on';
ax.GridAlpha = 0.22;
ax.MinorGridAlpha = 0.12;
end

function local_save(fig, fname)
set(fig, 'PaperPositionMode', 'auto');
try
    exportgraphics(fig, fname, 'Resolution', 400);
catch
    saveas(fig, fname);
end
[p,n,~] = fileparts(fname);
try
    exportgraphics(fig, fullfile(p, [n '.pdf']), 'ContentType','vector');
catch
end
close(fig);
fprintf('[blockC_suite] saved %s\n', fname);
end

function note_file = local_write_reference_note(save_dir)
note_file = fullfile(save_dir, 'BlockC_AdaptiveFilterSuite_ReferenceMap.md');
fid = fopen(note_file, 'w');
if fid < 0, return; end
fprintf(fid, '# Block C Adaptive-Filter Suite Reference Map\n\n');
fprintf(fid, 'This suite separates the endogenous-aware single-bank recursion from the Block-B MSB tracking benchmark.\n\n');
fprintf(fid, '- Algorithm 1: projected leaky SM-NLMS/full-gradient bridge, same DFE regressor, box projection, fixed main tap.\n');
fprintf(fid, '- [30] Gazor 2002: represented by the SMNLMS-DFE set-membership baseline with noise-bound gating.\n');
fprintf(fid, '- [20] de Souza 2024: represented by SM-sign-NLMS with set-membership censoring and normalized signed innovation.\n');
fprintf(fid, '- [17] data-normalized adaptive-filter analysis: represented by epsilon-NLMS.\n');
fprintf(fid, '- [18] error-nonlinearity analysis: represented by sign-error LMS, without normalization or set-membership gating.\n\n');
fprintf(fid, 'Guardrails: all methods use Nf=7, Nb=3, D=3, the same DD slicer, the same channel/noise realization, and the same seed per trial. Only the update law is changed.\n\n');
fprintf(fid, 'C1/C3/C5 use nominal step-size scales selected from the C2 convergence-misadjustment sweep: epsilon-NLMS=2, SMNLMS=2, SM-sign-NLMS=2, sign-error LMS=0.5, Algorithm 1=2. The full C2 sweep is saved so the operating-point choice is auditable.\n\n');
fprintf(fid, 'C5 is a bridge diagnostic, not a claim that Algorithm 1 eliminates the Markov floor. If the raw C5 floor is not the lowest among all single-bank laws, state that honestly: Algorithm 1 controls learning/misadjustment and re-lock behavior, while MSB/HMM bank-local memory is the mechanism that removes the architectural floor.\n\n');
fprintf(fid, 'Closed-form theory overlays are not claimed here because the decision-directed PAM4 DFE nonlinearity and Markov-ISI stress violate the simplifying assumptions of the classical analyses. The figures instead use the same diagnostic quantities: EMSE/MSD learning, convergence-misadjustment tradeoff, SNR robustness, and update probability.\n');
fclose(fid);
end
