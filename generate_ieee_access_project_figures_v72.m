function out = generate_ieee_access_project_figures_v72(varargin)
%GENERATE_IEEE_ACCESS_PROJECT_FIGURES_V72
% Build a paper-facing figure pack for the PAM4 / HMM-routed MSB project.
%
% This script intentionally separates two jobs:
%   1) package the polished root-level figures that match the project; and
%   2) redraw the figures that need stricter code-faithful wording.
%
% The generated figures are explanatory architecture figures only.  They do
% not rerun BER simulations.
%
% Example:
%   out = generate_ieee_access_project_figures_v72();

p = inputParser;
addParameter(p, 'save_dir', 'paper_ieee_access_figure_pack_v72', @(x)ischar(x) || isstring(x));
addParameter(p, 'fig_visible', 'off', @(x)ischar(x) || isstring(x));
addParameter(p, 'copy_existing', true, @(x)islogical(x) || isnumeric(x));
parse(p, varargin{:});

save_dir = char(p.Results.save_dir);
fig_visible = char(p.Results.fig_visible);
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

manifest = {};
manifest{end+1} = '# IEEE Access / Q1 Figure Pack v72';
manifest{end+1} = '';
manifest{end+1} = 'This folder contains project-aligned explanatory figures for the PAM4 HMM-routed MSB receiver.';
manifest{end+1} = 'The pack distinguishes controlled Markov-ISI theory validation from 802.3ck COM-style S-parameter tracking stress.';
manifest{end+1} = '';
manifest{end+1} = 'Important wording: the 802.3ck channel experiments are COM-style simulations using public/contributed Touchstone S-parameter channels; they are not IEEE COM compliance/pass-fail tests.';
manifest{end+1} = '';
manifest{end+1} = '| File | Role | Project alignment note |';
manifest{end+1} = '|---|---|---|';

if p.Results.copy_existing
    manifest = local_copy_existing_figures(save_dir, manifest);
end

fname = fullfile(save_dir, 'fig08_codefaithful_hmm_fir_router.png');
local_fig_hmm_fir_router(fname, fig_visible);
manifest{end+1} = '| `fig08_codefaithful_hmm_fir_router.png` | HMM/FIR router mechanism | Replaces the generic ExtraTrees-like HMM drawing. Matches `algorithm6_msb_firbank.m`: FIR residual scores, EWMA costs, fixed/benchmark transition prior, posterior bank selection. |';

fname = fullfile(save_dir, 'fig09_codefaithful_endogenous_aware_smnlms_gate.png');
local_fig_eb_smnlms(fname, fig_visible);
manifest{end+1} = '| `fig09_codefaithful_endogenous_aware_smnlms_gate.png` | Endogenous-aware SMNLMS update gate | Matches EB-aware bank update: `gamma_eff` increases and `beta_eff` decreases when posterior entropy, cross-state memory, or confidence uncertainty increases. |';

fname = fullfile(save_dir, 'fig10_three_block_simulation_strategy.png');
local_fig_three_blocks(fname, fig_visible);
manifest{end+1} = '| `fig10_three_block_simulation_strategy.png` | Simulation strategy | Separates Block A severe Markov-ISI theory, Block B 802.3ck C2M tracking stress, and Block C endogenous-aware recursion bridge. |';

fname = fullfile(save_dir, 'fig11_reference_baseline_positioning.png');
local_fig_baseline_map(fname, fig_visible);
manifest{end+1} = '| `fig11_reference_baseline_positioning.png` | Baseline positioning | Shows why Souza SM-sign-NLMS, Liu SS-LMS, Chen pulse-ref, Cui HMM, Algorithm 1, and Proposed MSB are compared. |';

fname = fullfile(save_dir, 'fig12_channel_physics_and_impairment_stack.png');
local_fig_channel_physics(fname, fig_visible);
manifest{end+1} = '| `fig12_channel_physics_and_impairment_stack.png` | Channel physics / impairments | Summarizes Touchstone-to-FIR conversion, insertion loss, baud/Nyquist effect, AWGN, crosstalk, jitter, and combined COM-style stress. |';

fname = fullfile(save_dir, 'fig13_metrics_stack_for_results.png');
local_fig_metrics_stack(fname, fig_visible);
manifest{end+1} = '| `fig13_metrics_stack_for_results.png` | Metrics map | Shows the metrics reported across the blocks: BER/SER, eye, transition-window BER, recovery, state accuracy, bank usage, update rate. |';

manifest = local_copy_channel_physics_outputs(save_dir, manifest);

manifest{end+1} = '';
manifest{end+1} = 'Suggested use: keep Figures 1-7 as high-level architecture figures; use the code-faithful Fig. 8 and Fig. 9 replacements for final manuscript claims.';
manifest{end+1} = 'The older root `figure 8.png` and `figure 9.png` remain visually useful, but the replacements in this pack are safer for reviewer scrutiny.';
writecell(manifest(:), fullfile(save_dir, 'MANIFEST.md'), 'FileType', 'text', 'QuoteStrings', 'none');

out = struct();
out.save_dir = save_dir;
out.manifest = fullfile(save_dir, 'MANIFEST.md');
fprintf('[figure_pack_v72] wrote %s\n', out.manifest);
end

% ======================================================================
function manifest = local_copy_existing_figures(save_dir, manifest)
src_names = { ...
    'figure 1.png', 'fig01_overall_8023ck_pam4_benchmark_architecture.png', ...
    'Overall benchmark architecture', ...
    'Matches the project pipeline: PAM4, Tx FFE, Touchstone/Sdd21, FIR, Markov switching, impairments, HMM router, bank FFE/DFE, metrics.'; ...
    'figure 2.png', 'fig02_practical_8023ck_channel_asset_handling.png', ...
    '802.3ck channel asset handling', ...
    'Matches `build_8023ck_channel_catalog.m` and `sparam_to_symbol_impulse.m`: manifest, Sdd21 extraction, interpolation, IFFT, main cursor alignment, symbol-spaced FIR.'; ...
    'figure 3.png', 'fig03_markov_sparameter_simulation_loop.png', ...
    'Markov S-parameter simulation loop', ...
    'Matches the benchmark structure: PAM4 source, Tx FFE, Markov state channel selection, AWGN, optional second-chain disturbance.'; ...
    'figure 4.png', 'fig04_algorithm6_msb_firbank_online_dataflow.png', ...
    'Algorithm 6 MSB-FIRBank dataflow', ...
    'Matches `algorithm6_msb_firbank.m`: shared r_buf, per-bank y_s, FIR residual scoring, HMM posterior, selected-bank DD update.'; ...
    'figure 5.png', 'fig05_state_local_ffe_dfe_bank_structure.png', ...
    'State-local FFE/DFE bank structure', ...
    'Matches state-local `theta_banks(:,s)` and `d_hat_per_bank(:,s)` in the code.'; ...
    'figure 6.png', 'fig06_training_and_dd_update_schedule.png', ...
    'Training and decision-directed update schedule', ...
    'Matches pilot warm start, pilot separation, and decision-directed HMM routed update phases.'; ...
    'figure 7.png', 'fig07_single_bank_vs_proposed_msb_receiver.png', ...
    'Single-bank receiver versus Proposed MSB', ...
    'Useful high-level comparison. The Proposed path uses bank-local memory and routing instead of a single compromise equalizer.' ...
};

for i = 1:size(src_names,1)
    src = src_names{i,1};
    dst = fullfile(save_dir, src_names{i,2});
    if exist(src, 'file')
        copyfile(src, dst);
        manifest{end+1} = sprintf('| `%s` | %s | %s |', src_names{i,2}, src_names{i,3}, src_names{i,4}); %#ok<AGROW>
        fprintf('[figure_pack_v72] copied %s -> %s\n', src, dst);
    else
        manifest{end+1} = sprintf('| `%s` | %s | Missing source `%s`; not copied. |', src_names{i,2}, src_names{i,3}, src); %#ok<AGROW>
    end
end
end

% ======================================================================
function local_fig_hmm_fir_router(fname, fig_visible)
[fig, ax] = local_canvas_styled(fig_visible);
C = local_colors();
local_paper_heading(ax, 'HMM/FIR Router for Algorithm 6');

local_dashed_container(ax, [0.045 0.225 0.910 0.625], 'Forward Bayesian routing recursion during decision-directed tracking', C.gray);

local_dashed_container(ax, [0.070 0.315 0.255 0.455], '1. FIR evidence', C.blue);
local_card(ax, 0.095, 0.615, 0.205, 0.105, 'State FIR bank', {'h_s[k] from Sdd21', 'one hypothesis per bank'}, C.blue2, C.blue, 'firbank');
local_card(ax, 0.095, 0.475, 0.205, 0.105, 'Bank-local memory', {'d_hat_per_bank(:,s)', 'feedback history'}, C.blue2, C.blue, 'bank');
local_card(ax, 0.095, 0.340, 0.205, 0.100, 'Residual emission', {'score_s = (r(m)-pred_s)^2'}, C.red2, C.red, 'residual');

local_dashed_container(ax, [0.385 0.315 0.255 0.455], '2. HMM filtering', C.green);
local_card(ax, 0.410, 0.615, 0.205, 0.105, 'Cost memory', {'J_s <- rho J_s', '+ (1-rho)score_s'}, C.purple2, C.purple, 'ewma');
local_card(ax, 0.410, 0.475, 0.205, 0.105, 'Markov prior', {'pi_pred = P_hmm^T pi'}, C.green2, C.green, 'matrix');
local_card(ax, 0.410, 0.340, 0.205, 0.100, 'Posterior', {'pi_s proportional', 'pi_pred_s exp(-rel/tau)'}, C.green2, C.green, 'posterior');

local_dashed_container(ax, [0.700 0.315 0.225 0.455], '3. Route and update', C.orange);
local_card(ax, 0.725, 0.615, 0.175, 0.105, 'MAP state', {'s_hat = argmax pi_s'}, C.orange2, C.orange, 'posterior');
local_card(ax, 0.725, 0.475, 0.175, 0.105, 'Selected output', {'d_hat(m)', 'from bank s_hat'}, C.orange2, C.orange, 'slicer');
local_card(ax, 0.725, 0.340, 0.175, 0.100, 'Local update', {'theta_s_hat only', 'plus local memory'}, C.gray2, C.gray, 'dfe');

local_arrow_between(0.325,0.535,0.385,0.535);
local_arrow_between(0.640,0.535,0.700,0.535);

local_card(ax, 0.110, 0.125, 0.240, 0.075, 'Code-faithful emission', ...
    {'FIR residual likelihood, not ExtraTrees emission'}, C.blue2, C.blue, 'note');
local_card(ax, 0.390, 0.125, 0.220, 0.075, 'Transition prior', ...
    {'benchmark/state prior P_hmm'}, C.green2, C.green, 'matrix');
local_card(ax, 0.650, 0.125, 0.240, 0.075, 'Stored diagnostics', ...
    {'pi_hist, J_hist, s_hat_hist, bank usage'}, C.orange2, C.orange, 'bars');
local_caption(ax, 'Figure 8. Code-faithful HMM/FIR router for channel-state classification and active-bank selection.');
local_save(fig, fname);
end

% ======================================================================
function local_fig_eb_smnlms(fname, fig_visible)
[fig, ax] = local_canvas_styled(fig_visible);
C = local_colors();
local_paper_heading(ax, 'Endogenous-Aware SMNLMS Gate');

local_dashed_container(ax, [0.035 0.20 0.28 0.65], 'Reliability and burden signals', C.blue);
local_card(ax, 0.065, 0.665, 0.105, 0.115, 'H(pi)', {'posterior', 'entropy'}, C.blue2, C.blue, 'entropy');
local_card(ax, 0.185, 0.665, 0.105, 0.115, '1-max(pi)', {'confidence', 'uncertainty'}, C.blue2, C.blue, 'posterior');
local_card(ax, 0.065, 0.465, 0.105, 0.115, 'cross', {'state-memory', 'burden'}, C.blue2, C.blue, 'switch');
local_card(ax, 0.185, 0.465, 0.105, 0.115, 'DD load', {'slicer', 'reliability'}, C.blue2, C.blue, 'slicer');

local_dashed_container(ax, [0.365 0.20 0.27 0.65], 'Adaptive set-membership gate', C.purple);
local_card(ax, 0.405, 0.625, 0.19, 0.12, 'Burden score', ...
    {'B = lambda_H H(pi)', '+ lambda_C cross + lambda_U unc'}, C.purple2, C.purple, 'sum');
local_card(ax, 0.405, 0.430, 0.19, 0.12, 'Gate scaling', ...
    {'gamma_eff = gamma0(1+B)', 'beta_eff = beta/(1+B)'}, C.purple2, C.purple, 'gate');
local_card(ax, 0.405, 0.250, 0.19, 0.105, 'SMNLMS condition', ...
    {'update only if |e| > gamma_eff'}, C.green2, C.green, 'threshold');

local_dashed_container(ax, [0.685 0.20 0.28 0.65], 'Selected bank update', C.orange);
local_card(ax, 0.720, 0.625, 0.205, 0.11, 'Innovation', {'e = d_ref - y_s'}, C.orange2, C.orange, 'residual');
local_card(ax, 0.720, 0.435, 0.205, 0.12, 'Coefficient update', ...
    {'theta_s <- theta_s + mu_SM e x / ||x||^2'}, C.orange2, C.orange, 'firbank');
local_card(ax, 0.720, 0.255, 0.205, 0.105, 'Receiver effect', ...
    {'fewer unreliable updates', 'cleaner bank-local memory'}, C.red2, C.red, 'shield');

local_arrow_between(0.290,0.720,0.405,0.685);
local_arrow_between(0.290,0.520,0.405,0.685);
local_arrow_between(0.595,0.490,0.720,0.680);
local_arrow_between(0.595,0.300,0.720,0.495);
local_arrow_between(0.822,0.625,0.822,0.555);
local_arrow_between(0.822,0.435,0.822,0.360);

local_card(ax, 0.230, 0.105, 0.540, 0.065, 'Bridge to the full Proposed MSB', ...
    {'single-bank endogenous-aware NLMS explains the gate; MSB adds state-local memories and HMM/FIR routing'}, ...
    C.gray2, C.gray, 'note');
local_caption(ax, 'Figure 9. Endogenous-aware SMNLMS gating used to suppress unreliable decision-directed updates.');
local_save(fig, fname);
end

% ======================================================================
function local_fig_three_blocks(fname, fig_visible)
[fig, ax] = local_canvas_styled(fig_visible);
C = local_colors();
local_paper_heading(ax, 'Three-Block Simulation Strategy');

x = [0.055 0.370 0.685]; w = 0.260; y = 0.230; h = 0.585;
edges = {C.blue,C.green,C.purple};
fills = {C.blue2,C.green2,C.purple2};
labels = {'A. Controlled Markov-ISI', 'B. 802.3ck C2M Tracking', 'C. Endogenous Bridge'};
for k = 1:3
    local_dashed_container(ax, [x(k) y w h], labels{k}, edges{k});
end

local_card(ax, x(1)+0.025, y+0.370, 0.210, 0.120, 'Model', ...
    {'h2 = {0.30,0.50,0.70}', 'P from mean dwell'}, fills{1}, edges{1}, 'markovtap');
local_card(ax, x(1)+0.025, y+0.220, 0.210, 0.120, 'Purpose', ...
    {'severe Markov stress', 'theory-aligned validation'}, fills{1}, edges{1}, 'target');
local_card(ax, x(1)+0.025, y+0.070, 0.210, 0.120, 'Outputs', ...
    local_block_outputs(1), C.gray2, C.gray, 'bars');

local_card(ax, x(2)+0.025, y+0.370, 0.210, 0.120, 'States', ...
    {'C2M_10dB | 14dB | 16dB', 'Touchstone S-parameters'}, fills{2}, edges{2}, 'sparam');
local_card(ax, x(2)+0.025, y+0.220, 0.210, 0.120, 'Stress modes', ...
    {'slow | medium | fast', 'piecewise constant states'}, fills{2}, edges{2}, 'trajectory');
local_card(ax, x(2)+0.025, y+0.070, 0.210, 0.120, 'Outputs', ...
    local_block_outputs(2), C.gray2, C.gray, 'bars');

local_card(ax, x(3)+0.025, y+0.370, 0.210, 0.120, 'Ablation', ...
    {'SMNLMS | SM-sign', 'endogenous-aware NLMS'}, fills{3}, edges{3}, 'threshold');
local_card(ax, x(3)+0.025, y+0.220, 0.210, 0.120, 'Purpose', ...
    {'explain the gate', 'before full MSB'}, fills{3}, edges{3}, 'gate');
local_card(ax, x(3)+0.025, y+0.070, 0.210, 0.120, 'Outputs', ...
    local_block_outputs(3), C.gray2, C.gray, 'bars');

local_arrow_between(x(1)+w, 0.525, x(2), 0.525);
local_arrow_between(x(2)+w, 0.525, x(3), 0.525);
local_card(ax, 0.145, 0.105, 0.710, 0.070, 'Safe interpretation', ...
    {'Block A isolates theory; Block B validates tracking stress on public 802.3ck-style channels; Block C explains the endogenous-aware update.'}, ...
    C.orange2, C.orange, 'note');
local_caption(ax, 'Figure 10. Final simulation protocol separating controlled theory, realistic channel tracking, and recursion ablation.');
local_save(fig, fname);
end

% ======================================================================
function local_fig_baseline_map(fname, fig_visible)
[fig, ax] = local_canvas_styled(fig_visible);
C = local_colors();
local_paper_heading(ax, 'Reference Baselines and Proposed Contribution');

local_dashed_container(ax, [0.045 0.205 0.45 0.61], 'Baseline families from the literature', C.blue);
cards = { ...
    0.075,0.640,'Souza 2024','SM-sign-NLMS','set-membership + signed robustness',C.blue2,C.blue,'signed'; ...
    0.075,0.445,'Gazor 2002','SMNLMS / ADFE','set-membership adaptive filtering',C.blue2,C.blue,'threshold'; ...
    0.075,0.250,'Ours bridge','Endogenous-aware NLMS','single-bank theory ablation',C.green2,C.green,'gate'; ...
    0.290,0.640,'Liu 2023','SS-LMS DFE','PAM4 adaptive DFE style',C.orange2,C.orange,'dfe'; ...
    0.290,0.445,'Chen','Pulse-ref FFE/CTLE/DFE','offline optimized reference',C.orange2,C.orange,'pulse'; ...
    0.290,0.250,'Cui 2024','ExtraTrees-HMM','ML emission + Viterbi detector',C.orange2,C.orange,'tree'};
for i = 1:size(cards,1)
    local_card(ax, cards{i,1}, cards{i,2}, 0.170, 0.125, cards{i,3}, ...
        {cards{i,4}, cards{i,5}}, cards{i,6}, cards{i,7}, cards{i,8});
end

local_card(ax, 0.585, 0.545, 0.145, 0.145, 'Algorithm 1', ...
    {'single-bank', 'same channel stream', 'compromise memory'}, C.purple2, C.purple, 'bank');
local_card(ax, 0.795, 0.545, 0.155, 0.145, 'Proposed MSB', ...
    {'state-local banks', 'HMM/FIR routing', 'EB-aware SMNLMS'}, C.red2, C.red, 'shield');
for yy = [0.70 0.505 0.31]
    local_arrow_between(0.460, yy, 0.585, 0.615);
end
for yy = [0.70 0.505 0.31]
    local_arrow_between(0.245, yy, 0.585, 0.615);
end
local_arrow_between(0.730,0.618,0.795,0.618);
local_card(ax, 0.570, 0.250, 0.390, 0.125, 'Novelty focus', ...
    {'not only a new step-size rule', 'routing + bank-local memory + endogenous-aware gate', 'for recurring channel-state variation'}, C.gray2, C.gray, 'target');

local_caption(ax, 'Figure 11. Baseline positioning: each reference tests a different part of the proposed receiver.');
local_save(fig, fname);
end

% ======================================================================
function local_fig_channel_physics(fname, fig_visible)
[fig, ax] = local_canvas_styled(fig_visible);
C = local_colors();
local_paper_heading(ax, '802.3ck-Style Channel Physics and Impairment Stack');

steps = { ...
    0.060,'Touchstone assets',{'.s4p channel files','manifest-selected cases'},C.blue2,C.blue,'sparam'; ...
    0.220,'Differential response',{'extract Sdd21(f)','relative to DC'},C.blue2,C.blue,'freq'; ...
    0.380,'Time response',{'PCHIP grid + IFFT','main-cursor alignment'},C.green2,C.green,'pulse'; ...
    0.540,'Symbol FIR',{'h_s[k] for PAM4','used by channel + router'},C.green2,C.green,'firbank'; ...
    0.700,'Baud/Nyquist',{'26.5625 / 53.125 GBd','higher f_Nyq samples more loss'},C.purple2,C.purple,'nyquist'; ...
    0.860,'Receiver stress',{'AWGN', 'XTALK + jitter', 'combined stress'},C.orange2,C.orange,'impair'};
for k = 1:size(steps,1)
    local_card(ax, steps{k,1}, 0.515, 0.115, 0.255, steps{k,2}, steps{k,3}, steps{k,4}, steps{k,5}, steps{k,6});
    if k < size(steps,1)
        local_arrow_between(steps{k,1}+0.115,0.640,steps{k+1,1},0.640);
    end
end

local_dashed_container(ax, [0.045 0.445 0.925 0.395], 'COM-style channel processing path used before equalization', C.gray);
local_card(ax, 0.085, 0.225, 0.230, 0.110, 'Channel severity figure', ...
    {'overlay |Sdd21| for C2M/C2C', 'shows frequency-dependent loss'}, C.blue2, C.blue, 'freq');
local_card(ax, 0.385, 0.225, 0.230, 0.110, 'High-speed figure', ...
    {'baud changes Nyquist point', 'and symbol-spaced taps'}, C.purple2, C.purple, 'nyquist');
local_card(ax, 0.685, 0.225, 0.230, 0.110, 'Impairment figure', ...
    {'AWGN, NEXT/FEXT proxy, jitter proxy', 'and combined stress'}, C.orange2, C.orange, 'impair');

local_caption(ax, 'Figure 12. Channel-processing and impairment stack used to justify the 802.3ck tracking benchmark.');
local_save(fig, fname);
end

% ======================================================================
function local_fig_metrics_stack(fname, fig_visible)
[fig, ax] = local_canvas_styled(fig_visible);
C = local_colors();
local_paper_heading(ax, 'Metrics Produced by the Final Simulation Pack');

local_dashed_container(ax, [0.055 0.250 0.890 0.565], 'Main paper metrics', C.gray);
top = { ...
    0.090,0.585,'BER / SER',{'waterfall vs SNR','pre-FEC reference'},C.blue2,C.blue,'ber'; ...
    0.315,0.585,'Eye metrics',{'eye height','eye width / area'},C.green2,C.green,'eye'; ...
    0.540,0.585,'Tracking',{'transition-window BER','recovery time'},C.purple2,C.purple,'trajectory'; ...
    0.765,0.585,'Router',{'state accuracy','bank usage'},C.orange2,C.orange,'posterior'};
for i = 1:size(top,1)
    local_card(ax, top{i,1}, top{i,2}, 0.155, 0.145, top{i,3}, top{i,4}, top{i,5}, top{i,6}, top{i,7});
end

local_card(ax, 0.190, 0.335, 0.220, 0.115, 'Adaptation diagnostics', ...
    {'tail MSE, tap convergence', 'set-membership update rate'}, C.gray2, C.gray, 'ewma');
local_card(ax, 0.590, 0.335, 0.220, 0.115, 'Complexity diagnostics', ...
    {'multiplications/symbol', 'memory and latency estimate'}, C.gray2, C.gray, 'matrix');
local_arrow_between(0.168,0.585,0.255,0.450);
local_arrow_between(0.392,0.585,0.345,0.450);
local_arrow_between(0.618,0.585,0.645,0.450);
local_arrow_between(0.842,0.585,0.765,0.450);

local_card(ax, 0.300, 0.145, 0.400, 0.090, 'Paper tables', ...
    {'Table I: channels | Table II: BER/SER/eye | Table III: tracking/recovery'}, C.red2, C.red, 'table');
local_arrow_between(0.300,0.335,0.445,0.235);
local_arrow_between(0.700,0.335,0.555,0.235);

local_caption(ax, 'Figure 13. Metric stack connecting Monte Carlo curves, eye diagrams, routing diagnostics, and paper tables.');
local_save(fig, fname);
end

% ======================================================================
function manifest = local_copy_channel_physics_outputs(save_dir, manifest)
src_dir = 'paper_channel_physics_8023ck_v72';
items = { ...
    'ChannelFrequency_Sdd21Overlay_C2M_C2C.png', 'fig14_channel_frequency_sdd21_overlay_c2m_c2c.png', 'Sdd21 overlay for C2M/C2C channels'; ...
    'BaudImpact_SymbolTaps_C2M.png', 'fig15_baud_impact_symbol_taps_c2m.png', 'Baud-rate impact on symbol-spaced channel taps'; ...
    'BaudImpact_WaveformDistortion_C2M.png', 'fig16_baud_impact_waveform_distortion_c2m.png', 'Baud-rate waveform distortion visualization'; ...
    'COMStyle_ImpairmentImpact_53p125GBd.png', 'fig17_comstyle_impairment_impact.png', 'AWGN, crosstalk, jitter, and combined impairment impact' ...
};
for i = 1:size(items,1)
    src = fullfile(src_dir, items{i,1});
    dst = fullfile(save_dir, items{i,2});
    if exist(src, 'file')
        copyfile(src, dst);
        manifest{end+1} = sprintf('| `%s` | %s | Copied from `%s`; generated by `run_8023ck_channel_physics_analysis_v72.m`. |', items{i,2}, items{i,3}, src); %#ok<AGROW>
    end
end
end

% ======================================================================
function [fig, ax] = local_canvas_styled(fig_visible)
fig = figure('Color', 'w', 'Visible', fig_visible, 'Position', [80 60 1536 1024]);
ax = axes(fig, 'Position', [0 0 1 1]);
axis(ax, [0 1 0 1]);
axis(ax, 'off');
hold(ax, 'on');

% Subtle paper background, close to the polished root figures.
[xx, yy] = meshgrid(linspace(-1,1,220), linspace(-1,1,160));
bg = 0.985 - 0.020*exp(-2.0*(xx.^2 + yy.^2));
image(ax, [0 1], [0 1], repmat(bg, 1, 1, 3));
set(ax, 'YDir', 'normal');
uistack(findobj(ax, 'Type', 'image'), 'bottom');
end

function local_paper_heading(ax, text_str)
text(ax, 0.5, 0.925, text_str, 'HorizontalAlignment', 'center', ...
    'FontWeight', 'bold', 'FontSize', 22, 'Interpreter', 'none', ...
    'Color', [0.07 0.07 0.07]);
end

function local_dashed_container(ax, pos, label, edge_color)
rectangle(ax, 'Position', pos, 'Curvature', [0.025 0.025], ...
    'FaceColor', 'none', 'EdgeColor', edge_color, 'LineWidth', 1.6, ...
    'LineStyle', '--');
text(ax, pos(1)+0.018, pos(2)+pos(4)-0.040, label, ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
    'FontWeight', 'bold', 'FontSize', 12, 'Interpreter', 'none', ...
    'Color', edge_color);
end

function local_card(ax, x, y, w, h, title_str, sub_lines, face_color, edge_color, icon_name)
% Shadow.
rectangle(ax, 'Position', [x+0.006 y-0.006 w h], 'Curvature', [0.045 0.045], ...
    'FaceColor', [0.86 0.88 0.90], 'EdgeColor', 'none');
rectangle(ax, 'Position', [x y w h], 'Curvature', [0.045 0.045], ...
    'FaceColor', face_color, 'EdgeColor', edge_color, 'LineWidth', 1.35);

% Icon panel.
iw = min(0.055, max(0.040, w*0.28));
ix = x + 0.014;
iy = y + h*0.21;
ih = h*0.58;
local_draw_icon(ax, icon_name, ix, iy, iw, ih, edge_color);

if ischar(sub_lines) || isstring(sub_lines)
    sub_lines = {char(sub_lines)};
end
tx = x + iw + 0.030;
tw = w - iw - 0.040;
text(ax, tx+tw/2, y+h*0.63, title_str, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 11.2, 'FontWeight', 'bold', 'Interpreter', 'none', ...
    'Color', [0.08 0.09 0.10]);
text(ax, tx+tw/2, y+h*0.34, strjoin(sub_lines, newline), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 9.2, 'FontWeight', 'bold', 'Interpreter', 'none', ...
    'Color', [0.12 0.13 0.14]);
end

function local_step(ax, x, y, n, color)
rectangle(ax, 'Position', [x-0.020 y-0.020 0.040 0.040], ...
    'Curvature', [1 1], 'FaceColor', [1 1 1], 'EdgeColor', color, ...
    'LineWidth', 1.5);
text(ax, x, y, sprintf('%d', n), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'FontWeight', 'bold', 'FontSize', 13, ...
    'Color', color);
end

function local_arrow_between(x1, y1, x2, y2)
annotation(gcf, 'arrow', [x1 x2], [y1 y2], ...
    'Color', [0.10 0.10 0.10], 'LineWidth', 1.25, ...
    'HeadLength', 9, 'HeadWidth', 9);
end

function local_caption(ax, text_str)
text(ax, 0.5, 0.055, text_str, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'FontSize', 13, 'Interpreter', 'none', ...
    'Color', [0.10 0.10 0.10]);
end

function lines = local_block_outputs(k)
switch k
    case 1
        lines = {'BER/SER vs SNR', 'eye diagrams', 'floor gap'};
    case 2
        lines = {'BER/SER, transition BER', 'recovery, state accuracy', 'eye metrics'};
    otherwise
        lines = {'BER/SER, tail MSE', 'update rate', 'burden proxy'};
end
end

function local_draw_icon(ax, name, x, y, w, h, color)
cx = x + w/2;
cy = y + h/2;
switch lower(char(name))
    case {'firbank','dfe','bank'}
        base = y + h*0.22;
        plot(ax, [x+w*0.12 x+w*0.88], [base base], 'Color', color, 'LineWidth', 1.0);
        vals = [0.25 0.68 0.45 0.32 0.20];
        for i = 1:numel(vals)
            xx = x + w*(0.20 + 0.15*(i-1));
            yy = y + h*(0.25 + vals(i)*0.55);
            plot(ax, [xx xx], [base yy], 'Color', color, 'LineWidth', 1.0);
            plot(ax, xx, yy, 'o', 'MarkerFaceColor', [0.25 0.50 0.78], ...
                'MarkerEdgeColor', color, 'MarkerSize', 4);
        end
    case {'residual'}
        t = linspace(0,1,80);
        plot(ax, x+w*(0.10+0.80*t), y+h*(0.50+0.25*sin(2*pi*2*t)), ...
            'Color', color, 'LineWidth', 1.0);
        plot(ax, [x+w*0.20 x+w*0.82], [cy cy], ':', 'Color', [0.4 0.4 0.4]);
    case {'ewma','freq'}
        t = linspace(0,1,50);
        plot(ax, x+w*(0.12+0.76*t), y+h*(0.75-0.55*t+0.04*sin(6*pi*t)), ...
            'Color', color, 'LineWidth', 1.4);
        plot(ax, x+w*(0.12+0.76*t(1:8:end)), y+h*(0.75-0.55*t(1:8:end)), ...
            'o', 'MarkerFaceColor', [0.25 0.50 0.78], 'MarkerEdgeColor', color, 'MarkerSize', 3);
    case {'hmm','markovtap'}
        xs = [x+w*0.25 x+w*0.55 x+w*0.75];
        ys = [y+h*0.55 y+h*0.70 y+h*0.45];
        for i = 1:3
            rectangle(ax, 'Position', [xs(i)-w*0.10 ys(i)-w*0.10 w*0.20 w*0.20], ...
                'Curvature', [1 1], 'FaceColor', [0.96 0.96 1.0], ...
                'EdgeColor', color, 'LineWidth', 1.0);
            text(ax, xs(i), ys(i), sprintf('%d', i), 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', 'FontSize', 7, 'FontWeight', 'bold', ...
                'Color', color);
        end
        plot(ax, xs([1 2 3]), ys([1 2 3]), '-', 'Color', color, 'LineWidth', 1.0);
    case {'posterior','bars','ber'}
        vals = [0.30 0.62 0.44 0.78];
        for i = 1:4
            rectangle(ax, 'Position', [x+w*(0.15+i*0.15) y+h*0.18 w*0.08 h*vals(i)*0.55], ...
                'FaceColor', [0.25 0.50 0.78], 'EdgeColor', color, 'LineWidth', 0.7);
        end
    case {'matrix','table'}
        for i = 1:3
            for j = 1:3
                fc = [1 1 1];
                if i == j, fc = [0.78 0.88 0.74]; end
                rectangle(ax, 'Position', [x+w*(0.20+0.16*j) y+h*(0.18+0.16*i) w*0.13 h*0.13], ...
                    'FaceColor', fc, 'EdgeColor', color, 'LineWidth', 0.6);
            end
        end
    case {'threshold','gate'}
        plot(ax, [x+w*0.15 x+w*0.35 x+w*0.35 x+w*0.58 x+w*0.58 x+w*0.82], ...
            [y+h*0.28 y+h*0.28 y+h*0.48 y+h*0.48 y+h*0.70 y+h*0.70], ...
            'Color', color, 'LineWidth', 1.4);
        plot(ax, [x+w*0.15 x+w*0.82], [y+h*0.50 y+h*0.50], ':', 'Color', [0.4 0.4 0.4]);
    case {'slicer'}
        plot(ax, [x+w*0.15 x+w*0.35 x+w*0.35 x+w*0.58 x+w*0.58 x+w*0.82], ...
            [y+h*0.25 y+h*0.25 y+h*0.45 y+h*0.45 y+h*0.68 y+h*0.68], ...
            'Color', color, 'LineWidth', 1.4);
    case {'entropy','signed'}
        t = linspace(-2.5,2.5,80);
        z = exp(-t.^2/2);
        plot(ax, x+w*(0.10+0.80*(t-min(t))/(max(t)-min(t))), y+h*(0.20+0.55*z), ...
            'Color', color, 'LineWidth', 1.2);
    case {'switch'}
        plot(ax, [x+w*0.15 x+w*0.45 x+w*0.75], [y+h*0.30 y+h*0.68 y+h*0.38], ...
            '-o', 'Color', color, 'MarkerFaceColor', [0.25 0.50 0.78], 'LineWidth', 1.1);
    case {'sum'}
        text(ax, cx, cy, '+', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontWeight', 'bold', 'FontSize', 24, 'Color', color);
    case {'shield','target'}
        patch(ax, x+w*[0.50 0.78 0.72 0.50 0.28 0.22], y+h*[0.82 0.68 0.32 0.15 0.32 0.68], ...
            [0.80 0.92 0.78], 'EdgeColor', color, 'LineWidth', 1.1);
        plot(ax, [x+w*0.37 x+w*0.47 x+w*0.66], [y+h*0.48 y+h*0.36 y+h*0.58], ...
            'Color', color, 'LineWidth', 1.6);
    case {'sparam'}
        rectangle(ax, 'Position', [x+w*0.28 y+h*0.30 w*0.40 h*0.48], ...
            'FaceColor', [1 1 1], 'EdgeColor', color, 'LineWidth', 1.0);
        text(ax, cx, cy, '.s4p', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
            'FontSize', 8, 'Color', color);
    case {'pulse'}
        t = linspace(-2,2,80);
        z = sinc(t);
        plot(ax, x+w*(0.10+0.80*(t-min(t))/(max(t)-min(t))), y+h*(0.50+0.30*z), ...
            'Color', color, 'LineWidth', 1.2);
    case {'nyquist'}
        plot(ax, [x+w*0.18 x+w*0.82], [y+h*0.25 y+h*0.25], 'Color', color, 'LineWidth', 1.0);
        plot(ax, [x+w*0.28 x+w*0.28], [y+h*0.25 y+h*0.70], '--', 'Color', color, 'LineWidth', 1.0);
        plot(ax, [x+w*0.65 x+w*0.65], [y+h*0.25 y+h*0.70], '--', 'Color', color, 'LineWidth', 1.0);
    case {'impair'}
        t = linspace(0,1,60);
        plot(ax, x+w*(0.15+0.70*t), y+h*(0.50+0.18*sin(2*pi*4*t)+0.07*sin(2*pi*13*t)), ...
            'Color', color, 'LineWidth', 1.0);
        plot(ax, [x+w*0.30 x+w*0.72], [y+h*0.32 y+h*0.70], 'Color', [0.75 0.15 0.15], 'LineWidth', 1.0);
        plot(ax, [x+w*0.30 x+w*0.72], [y+h*0.70 y+h*0.32], 'Color', [0.10 0.35 0.75], 'LineWidth', 1.0);
    case {'eye'}
        t = linspace(0,2,120);
        plot(ax, x+w*(0.08+0.84*t/2), y+h*(0.50+0.22*sin(pi*t)), 'Color', color, 'LineWidth', 1.1);
        plot(ax, x+w*(0.08+0.84*t/2), y+h*(0.50-0.22*sin(pi*t)), 'Color', color, 'LineWidth', 1.1);
    case {'trajectory'}
        stairs(ax, x+w*[0.12 0.25 0.40 0.58 0.72 0.86], y+h*[0.35 0.35 0.62 0.62 0.45 0.45], ...
            'Color', color, 'LineWidth', 1.2);
    case {'tree'}
        plot(ax, [cx cx], [y+h*0.72 y+h*0.50], 'Color', color, 'LineWidth', 1.1);
        plot(ax, [cx x+w*0.30], [y+h*0.50 y+h*0.30], 'Color', color, 'LineWidth', 1.1);
        plot(ax, [cx x+w*0.70], [y+h*0.50 y+h*0.30], 'Color', color, 'LineWidth', 1.1);
        plot(ax, [cx x+w*0.30 x+w*0.70], [y+h*0.72 y+h*0.30 y+h*0.30], 'o', ...
            'MarkerFaceColor', [0.80 0.92 0.78], 'MarkerEdgeColor', color, 'MarkerSize', 4);
    case {'note'}
        text(ax, cx, cy, 'i', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontWeight', 'bold', 'FontSize', 18, 'Color', color);
        rectangle(ax, 'Position', [cx-w*0.18 cy-w*0.18 w*0.36 w*0.36], ...
            'Curvature', [1 1], 'EdgeColor', color, 'LineWidth', 1.0);
    otherwise
        rectangle(ax, 'Position', [x+w*0.25 y+h*0.25 w*0.50 h*0.50], ...
            'Curvature', [0.2 0.2], 'FaceColor', [1 1 1], 'EdgeColor', color, 'LineWidth', 1.0);
end
end

% ======================================================================
function [fig, ax] = local_canvas(fig_visible, pos)
fig = figure('Color', 'w', 'Visible', fig_visible, 'Position', pos);
ax = axes(fig, 'Position', [0 0 1 1]);
axis(ax, [0 1 0 1]);
axis(ax, 'off');
hold(ax, 'on');
end

function c = local_colors()
c.blue = [0.07 0.27 0.52];      c.blue2 = [0.91 0.96 1.00];
c.green = [0.16 0.40 0.15];     c.green2 = [0.93 0.98 0.91];
c.purple = [0.36 0.22 0.55];    c.purple2 = [0.96 0.93 1.00];
c.orange = [0.55 0.35 0.04];    c.orange2 = [1.00 0.96 0.86];
c.red = [0.60 0.16 0.12];       c.red2 = [1.00 0.92 0.91];
c.gray = [0.25 0.25 0.25];      c.gray2 = [0.95 0.95 0.95];
end

function local_title(ax, s)
text(ax, 0.5, 0.94, s, 'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
    'FontSize', 20, 'Interpreter', 'none', 'Color', [0.08 0.08 0.08]);
end

function local_group(ax, pos, label, edge_color)
rectangle(ax, 'Position', pos, 'Curvature', [0.035 0.035], ...
    'FaceColor', [1 1 1 0.35], 'EdgeColor', edge_color, 'LineWidth', 1.5, ...
    'LineStyle', '--');
text(ax, pos(1)+pos(3)/2, pos(2)+pos(4)-0.035, label, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontWeight', 'bold', 'FontSize', 12, 'Interpreter', 'none', ...
    'Color', edge_color);
end

function local_box(ax, x, y, w, h, lines, face_color)
rectangle(ax, 'Position', [x y w h], 'Curvature', [0.06 0.06], ...
    'FaceColor', face_color, 'EdgeColor', [0.18 0.28 0.38], 'LineWidth', 1.1);
if ischar(lines) || isstring(lines)
    lines = {char(lines)};
end
txt = strjoin(lines, newline);
text(ax, x+w/2, y+h/2, txt, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'FontSize', 10.5, 'FontWeight', 'bold', ...
    'Interpreter', 'none', 'Color', [0.05 0.08 0.10]);
end

function local_arrow(x1, y1, x2, y2)
annotation(gcf, 'arrow', [x1 x2], [y1 y2], 'Color', [0.10 0.10 0.10], ...
    'LineWidth', 1.25, 'HeadLength', 8, 'HeadWidth', 8);
end

function local_note(ax, x, y, txt)
text(ax, x, y, txt, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
    'FontSize', 10.5, 'Interpreter', 'none', 'Color', [0.22 0.22 0.22], ...
    'FontAngle', 'italic');
end

function local_save(fig, fname)
set(fig, 'PaperPositionMode', 'auto');
try
    exportgraphics(fig, fname, 'Resolution', 300);
catch
    saveas(fig, fname);
end
[folder, stem] = fileparts(fname);
try
    saveas(fig, fullfile(folder, [stem '.fig']));
catch
end
try
    saveas(fig, fullfile(folder, [stem '.svg']));
catch
end
close(fig);
fprintf('[figure_pack_v72] saved %s\n', fname);
end
