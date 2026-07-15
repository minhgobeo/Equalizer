function out = run_paper(mode, varargin)
%RUN_PAPER  Paper-clean launcher (v73).
%
% v73 changes vs v65:
%   * Added reviewer-revision modes that wrap the reviewer_revision/ pack:
%       'reviewer_diag'        -> reviewer_diagnostics  (B_c, routing, A12)
%       'shared_vs_banklocal'  -> shared vs bank-local DFE buffer benchmark
%       'reviewer_revision'    -> runs both of the above
%   * Added name/value options 'regimes', 'snr', 'trials' that are passed
%     through to those reviewer-revision scripts.
%
% v65 changes vs v64:
%   * Added 'liu_ss_lms' mode for Liu et al. 2023 SS-LMS DFE algorithmic
%     re-implementation (receiver-side adaptive DFE baseline).
%   * The 'direct_benchmarks' suite now uses Liu in place of Dolatsara as
%     the receiver-adaptive baseline. Dolatsara remains accessible via
%     run_paper('dolatsara_scbo') for Tx-FIR optimization comparisons.
%
% Optional name/value:
%   'plot'     : true | false                  (default: true)
%   'save_dir' : where to put figures           (default: 'figs')
%   'format'   : 'png' | 'pdf' | 'fig'          (default: 'png')
%   'regimes'  : cell or char, subset of {'severe','realistic'}
%                                               (default: {'severe','realistic'})
%   'snr'      : vector of SNRs in dB            (default: [18 22 26 30])
%   'trials'   : Monte-Carlo trials per cell     (default: [] -> script default)
%   'channel_dir': public Touchstone channel root (default: data/8023ck_channels)
%   'max_cases': max S-parameter channel cases for 8023ck_sparam (default: 6)
%   'run_markov': run S-parameter Markov-switching diagnostic (default: true)
%   'run_markov_sweep': run C2M Markov dwell/severity sweep (default: false)
%   'markov_oracle_route': use true Markov state as an oracle routing upper bound
%   'fig_visible': 'on' | 'off' for auto-plots (default: 'on')
%
% Examples:
%   run_paper('reviewer_diag');
%   run_paper('reviewer_diag','regimes','severe','snr',[22 26],'trials',20);
%   run_paper('shared_vs_banklocal','trials',30);
%   run_paper('reviewer_revision');

if nargin < 1 || isempty(mode), mode = 'state_track'; end

p = inputParser;
addParameter(p,'plot',true,@islogical);
addParameter(p,'save_dir','figs',@ischar);
addParameter(p,'format','png',@ischar);
addParameter(p,'regimes',{'severe','realistic'},@(x)iscell(x)||ischar(x));
addParameter(p,'snr',[18 22 26 30],@isnumeric);
addParameter(p,'trials',[],@(x)isempty(x)||isnumeric(x));
addParameter(p,'samples',[],@(x)isempty(x)||(isnumeric(x)&&isscalar(x)));
addParameter(p,'trainLen',[],@(x)isempty(x)||(isnumeric(x)&&isscalar(x)));
addParameter(p,'channel_dir',fullfile('data','8023ck_channels'),@ischar);
addParameter(p,'max_cases',6,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'baud',26.5625e9,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'run_static',true,@islogical);
addParameter(p,'run_markov',true,@islogical);
addParameter(p,'run_markov_sweep',false,@islogical);
addParameter(p,'p_stay',[0.995 0.985 0.970 0.930],@isnumeric);
addParameter(p,'markov_oracle_route',false,@islogical);
addParameter(p,'markov_modes',{'slow','medium','fast','jump'},@(x)iscell(x)||ischar(x));
addParameter(p,'markov_nsym',[],@(x)isempty(x)||(isnumeric(x)&&isscalar(x)));
addParameter(p,'markov_trainLen',[],@(x)isempty(x)||(isnumeric(x)&&isscalar(x)));
addParameter(p,'markov_nb',[],@(x)isempty(x)||(isnumeric(x)&&isscalar(x)));
addParameter(p,'markov_smnlms_tau',[],@(x)isempty(x)||(isnumeric(x)&&isscalar(x)));
addParameter(p,'markov_smnlms_beta',[],@(x)isempty(x)||(isnumeric(x)&&isscalar(x)));
addParameter(p,'markov_use_smnlms_shadow_output',false,@islogical);
addParameter(p,'markov_use_adaptive_tau',false,@islogical);
addParameter(p,'markov_tau_calib',1.0,@(x)isnumeric(x)&&isscalar(x));
addParameter(p,'markov_use_transition_gate',false,@islogical);
addParameter(p,'markov_transition_gate_conf',0.50,@(x)isnumeric(x)&&isscalar(x));
addParameter(p,'markov_twochain',false,@islogical);
addParameter(p,'markov_twochain_noise_scale',[1.0 1.25],@isnumeric);
addParameter(p,'markov_twochain_imp_prob',[0.0 0.0005],@isnumeric);
addParameter(p,'markov_twochain_imp_alpha',10,@(x)isnumeric(x)&&isscalar(x));
addParameter(p,'noise_reference','clean',@(x)ischar(x)||isstring(x));
addParameter(p,'allow_synthetic',false,@islogical);
addParameter(p,'fig_visible','on',@ischar);
addParameter(p,'seed_offset',0,@(x)isnumeric(x)&&isscalar(x));
parse(p, varargin{:});
plot_opts = p.Results;

root = fileparts(mfilename('fullpath'));
addpath(genpath(root));

cfg  = build_main_config();
mc   = build_mc_config(cfg);
base = build_baselines();
vars = build_variants(cfg);

mode = lower(mode);
out  = [];

switch mode
    case {'state_track','hmm_state_track'}
        out = run_mb_state_track_v69(cfg, vars, base, mc);
    case {'ber_severe','severe'}
        if ~isempty(plot_opts.trials), mc.Ntrial_ser = plot_opts.trials; end
        nv = {};
        if ~isempty(plot_opts.samples), nv = [nv, {'Nsym', plot_opts.samples}]; end %#ok<AGROW>
        if ~isempty(plot_opts.trainLen), nv = [nv, {'trainLen', plot_opts.trainLen}]; end %#ok<AGROW>
        if ~isempty(plot_opts.trials), nv = [nv, {'force_trials', plot_opts.trials}]; end %#ok<AGROW>
        out = run_mb_ber_severe_v68(cfg, vars, base, mc, plot_opts.snr, nv{:});
    case {'ber_realistic','realistic'}
        out = run_mb_ber_realistic_v68(cfg, vars, base, mc);
    case {'endogenous_family','aware_family','endogenous_aware'}
        nv = {};
        if ~isempty(plot_opts.samples), nv = [nv, {'Nsym', plot_opts.samples}]; end %#ok<AGROW>
        if ~isempty(plot_opts.trainLen), nv = [nv, {'trainLen', plot_opts.trainLen}]; end %#ok<AGROW>
        out = run_endogenous_family_tracking_v72(cfg, vars, base, mc, ...
            'snr', plot_opts.snr, ...
            'trials', plot_opts.trials, ...
            'save_dir', plot_opts.save_dir, ...
            'fig_visible', plot_opts.fig_visible, ...
            'seed_offset', plot_opts.seed_offset, ...
            nv{:});

    case {'hmm_accuracy','table5'}
        out = run_hmm_accuracy_table(cfg, vars, base, mc);
    case {'static_sanity','table6'}
        out = run_static_channel_sanity(cfg, vars, base, mc);
    case {'burden_isolation','oracle_dd'}
        out = run_oracle_dd_burden_isolation(cfg, vars, base, mc);

    case {'p_mismatch','transition_mismatch'}
        out = run_p_mismatch_sweep(cfg, vars, base, mc);
    case {'state_separation','h2_separation'}
        out = run_state_separation_sweep(cfg, vars, base, mc);
    case {'theory_proxy','proxy'}
        out = run_theory_proxy_diagnostics(cfg, vars, base, mc);
    case {'markov_source_profile','mjs_source','source_markov'}
        out = run_markov_source_profile(cfg, vars, base, mc);

    case {'direct_benchmarks','direct_benchmark_suite','direct'}
        out = run_direct_equalizer_benchmark_suite(cfg, vars, base, mc);
    case {'souza_smsign','souza'}
        out = run_souza_smsign_direct_baseline(cfg, vars, base, mc);
    case {'cui_hmm','cui'}
        out = run_cui_extratrees_hmm_direct_adapter(cfg, vars, base, mc);
    case {'liu_ss_lms','liu','ss_lms'}     % v65 NEW
        out = run_liu_ss_lms_direct_adapter(cfg, vars, base, mc);
    case {'rc_esn','rc','esn'}
        out = run_rc_esn_direct_adapter(cfg, vars, base, mc);
    case {'liu_like_eye','liu_eye','liu_like'}   % v66 NEW
        out = run_liu_like_eye_benchmark(cfg, vars, base, mc);
    case {'liu_like_eye_mc','liu_eye_mc','liu_mc'}   % v68 NEW
        out = run_liu_like_eye_benchmark_mc(cfg, vars, base, mc);
    case {'dolatsara_scbo','dolatsara'}    % still callable individually
        out = run_dolatsara_scbo_tx_direct_adapter(cfg, vars, base, mc);
    case {'chen_pulse','chen'}
        out = run_chen_single_pulse_direct_adapter(cfg, vars, base, mc);

    case {'complexity','complexity_ber','efficiency'}
        out = run_complexity_vs_ber(cfg, vars, base, mc);

    case {'ck_stress','8023ck_stress','ieee8023ck','ck_dirty'}
        out = run_ck_stressed_channel_check(cfg, vars, base, mc);

    case {'8023ck_sparam','ck_sparam','sparam_benchmark','com_style'}
        out = run_8023ck_sparam_benchmark(cfg, vars, base, mc, ...
            'channel_dir', plot_opts.channel_dir, ...
            'snr', plot_opts.snr, ...
            'trials', plot_opts.trials, ...
            'max_cases', plot_opts.max_cases, ...
            'baud', plot_opts.baud, ...
            'run_static', plot_opts.run_static, ...
            'run_markov', plot_opts.run_markov, ...
            'run_markov_sweep', plot_opts.run_markov_sweep, ...
            'p_stay', plot_opts.p_stay, ...
            'markov_oracle_route', plot_opts.markov_oracle_route, ...
            'markov_modes', plot_opts.markov_modes, ...
            'markov_nsym', plot_opts.markov_nsym, ...
            'markov_trainLen', plot_opts.markov_trainLen, ...
            'markov_nb', plot_opts.markov_nb, ...
            'markov_smnlms_tau', plot_opts.markov_smnlms_tau, ...
            'markov_smnlms_beta', plot_opts.markov_smnlms_beta, ...
            'markov_use_smnlms_shadow_output', plot_opts.markov_use_smnlms_shadow_output, ...
            'markov_use_adaptive_tau', plot_opts.markov_use_adaptive_tau, ...
            'markov_tau_calib', plot_opts.markov_tau_calib, ...
            'markov_use_transition_gate', plot_opts.markov_use_transition_gate, ...
            'markov_transition_gate_conf', plot_opts.markov_transition_gate_conf, ...
            'markov_twochain', plot_opts.markov_twochain, ...
            'markov_twochain_noise_scale', plot_opts.markov_twochain_noise_scale, ...
            'markov_twochain_imp_prob', plot_opts.markov_twochain_imp_prob, ...
            'markov_twochain_imp_alpha', plot_opts.markov_twochain_imp_alpha, ...
            'noise_reference', char(plot_opts.noise_reference), ...
            'allow_synthetic', plot_opts.allow_synthetic, ...
            'seed_offset', plot_opts.seed_offset, ...
            'save_dir', plot_opts.save_dir);

    % ----------------------------------------------------------------
    % v73 NEW: reviewer-revision diagnostics (reviewer_revision/ pack)
    % ----------------------------------------------------------------
    case {'reviewer_diag','rev_diag','diagnostics'}
        out = local_run_reviewer_diag(plot_opts);
    case {'shared_vs_banklocal','buffer_bench','svb','banklocal'}
        out = local_run_shared_vs_banklocal(plot_opts);
    case {'reviewer_revision','rev_pack','revision'}
        out.diagnostics = local_run_reviewer_diag(plot_opts);
        out.buffer      = local_run_shared_vs_banklocal(plot_opts);

    case {'reviewer_mustdo','mustdo'}
        out.hmm_accuracy     = run_hmm_accuracy_table(cfg, vars, base, mc);
        out.static_sanity    = run_static_channel_sanity(cfg, vars, base, mc);
        out.burden_isolation = run_oracle_dd_burden_isolation(cfg, vars, base, mc);

    case {'all_light'}
        out.state_track      = run_mb_state_track_v69(cfg, vars, base, mc);
        out.severe           = run_mb_ber_severe_v68(cfg, vars, base, mc);
        out.realistic        = run_mb_ber_realistic_v68(cfg, vars, base, mc);
        out.hmm_accuracy     = run_hmm_accuracy_table(cfg, vars, base, mc);
        out.static_sanity    = run_static_channel_sanity(cfg, vars, base, mc);
        out.burden_isolation = run_oracle_dd_burden_isolation(cfg, vars, base, mc);

    case {'all_full','all_v65','all_v66','all_v67','all_v70','all_v71','all_v72','all_v73'}
        out.state_track      = run_mb_state_track_v69(cfg, vars, base, mc);
        out.severe           = run_mb_ber_severe_v68(cfg, vars, base, mc);
        out.realistic        = run_mb_ber_realistic_v68(cfg, vars, base, mc);
        out.hmm_accuracy     = run_hmm_accuracy_table(cfg, vars, base, mc);
        out.static_sanity    = run_static_channel_sanity(cfg, vars, base, mc);
        out.burden_isolation = run_oracle_dd_burden_isolation(cfg, vars, base, mc);
        out.p_mismatch       = run_p_mismatch_sweep(cfg, vars, base, mc);
        out.state_separation = run_state_separation_sweep(cfg, vars, base, mc);
        out.theory_proxy     = run_theory_proxy_diagnostics(cfg, vars, base, mc);
        out.markov_source    = run_markov_source_profile(cfg, vars, base, mc);
        out.direct           = run_direct_equalizer_benchmark_suite(cfg, vars, base, mc);
        out.liu_eye          = run_liu_like_eye_benchmark(cfg, vars, base, mc);
        out.complexity       = run_complexity_vs_ber(cfg, vars, base, mc);
        out.ck_stress        = run_ck_stressed_channel_check(cfg, vars, base, mc);
        out.ck_sparam        = run_8023ck_sparam_benchmark(cfg, vars, base, mc, ...
            'channel_dir', plot_opts.channel_dir, ...
            'snr', plot_opts.snr, ...
            'trials', plot_opts.trials, ...
            'max_cases', plot_opts.max_cases, ...
            'run_static', plot_opts.run_static, ...
            'run_markov', plot_opts.run_markov, ...
            'allow_synthetic', plot_opts.allow_synthetic, ...
            'save_dir', plot_opts.save_dir);

    % v73 NEW: full run including the reviewer-revision diagnostics
    case {'all_with_revision','all_v73_full'}
        out.state_track      = run_mb_state_track_v69(cfg, vars, base, mc);
        out.severe           = run_mb_ber_severe_v68(cfg, vars, base, mc);
        out.realistic        = run_mb_ber_realistic_v68(cfg, vars, base, mc);
        out.hmm_accuracy     = run_hmm_accuracy_table(cfg, vars, base, mc);
        out.static_sanity    = run_static_channel_sanity(cfg, vars, base, mc);
        out.burden_isolation = run_oracle_dd_burden_isolation(cfg, vars, base, mc);
        out.p_mismatch       = run_p_mismatch_sweep(cfg, vars, base, mc);
        out.state_separation = run_state_separation_sweep(cfg, vars, base, mc);
        out.theory_proxy     = run_theory_proxy_diagnostics(cfg, vars, base, mc);
        out.markov_source    = run_markov_source_profile(cfg, vars, base, mc);
        out.direct           = run_direct_equalizer_benchmark_suite(cfg, vars, base, mc);
        out.liu_eye          = run_liu_like_eye_benchmark(cfg, vars, base, mc);
        out.complexity       = run_complexity_vs_ber(cfg, vars, base, mc);
        out.ck_stress        = run_ck_stressed_channel_check(cfg, vars, base, mc);
        out.rev_diagnostics  = local_run_reviewer_diag(plot_opts);
        out.rev_buffer       = local_run_shared_vs_banklocal(plot_opts);
        out.ck_sparam        = run_8023ck_sparam_benchmark(cfg, vars, base, mc, ...
            'channel_dir', plot_opts.channel_dir, ...
            'snr', plot_opts.snr, ...
            'trials', plot_opts.trials, ...
            'max_cases', plot_opts.max_cases, ...
            'run_static', plot_opts.run_static, ...
            'run_markov', plot_opts.run_markov, ...
            'allow_synthetic', plot_opts.allow_synthetic, ...
            'save_dir', plot_opts.save_dir);

    otherwise
        error(['Unknown mode: %s. See run_paper.m header for full list.'], mode);
end

% --- Auto-plot dispatch ---
if plot_opts.plot
    try
        do_auto_plot(out, mode, plot_opts);
    catch ME
        fprintf('[run_paper] auto-plot failed: %s\n', ME.message);
    end
end
end

% =====================================================================
% v73 NEW: wrappers for the reviewer-revision pack.
% These scripts are self-contained (they build their own cfg via
% build_reviewer_inputs), so they do not take (cfg,vars,base,mc).
% =====================================================================
function o = local_run_reviewer_diag(R)
    if exist('reviewer_diagnostics','file') ~= 2
        error('run_paper:noReviewerPack', ...
            ['reviewer_diagnostics not found on path. Copy the ' ...
             'reviewer_revision/ folder into the repo root (see ' ...
             '10_PLACEMENT_GUIDE.md) and re-run.']);
    end
    regimes = R.regimes; if ischar(regimes), regimes = {regimes}; end
    nt = R.trials; if isempty(nt), nt = 5; end
    o = reviewer_diagnostics(regimes, R.snr, nt);
end

function o = local_run_shared_vs_banklocal(R)
    if exist('shared_vs_banklocal_benchmark','file') ~= 2
        error('run_paper:noReviewerPack', ...
            ['shared_vs_banklocal_benchmark not found on path. Copy the ' ...
             'reviewer_revision/ folder into the repo root (see ' ...
             '10_PLACEMENT_GUIDE.md) and re-run.']);
    end
    if exist('algorithm6_msb_v70_banklocal','file') ~= 2
        error('run_paper:noBankLocal', ...
            ['algorithm6_msb_v70_banklocal not found on path. Copy it ' ...
             'into core/algorithm6_msb/ (see 10_PLACEMENT_GUIDE.md).']);
    end
    regimes = R.regimes; if ischar(regimes), regimes = {regimes}; end
    nt = R.trials; if isempty(nt), nt = 10; end
    o = shared_vs_banklocal_benchmark(regimes, R.snr, nt);
end

% =====================================================================
function do_auto_plot(out, mode, plot_opts)
opts.save_dir = plot_opts.save_dir;
opts.fmt      = plot_opts.format;
opts.fig_visible = plot_opts.fig_visible;

switch mode
    case {'p_mismatch','transition_mismatch'}
        plot_experiment(out, 'p_mismatch', 'save_dir', opts.save_dir, 'save_format', opts.fmt, 'fig_visible', opts.fig_visible);
    case {'state_separation','h2_separation'}
        plot_experiment(out, 'state_separation', 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'theory_proxy','proxy'}
        plot_experiment(out, 'theory_proxy', 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'direct_benchmarks','direct_benchmark_suite','direct'}
        plot_experiment(out, 'direct_benchmarks', 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'liu_like_eye','liu_eye','liu_like'}
        plot_experiment(out, 'liu_like_eye', 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'liu_like_eye_mc','liu_eye_mc','liu_mc'}
        plot_experiment(out, 'liu_like_eye_mc', 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'souza_smsign','souza','cui_hmm','cui','liu_ss_lms','liu','ss_lms', ...
          'dolatsara_scbo','dolatsara','chen_pulse','chen'}
        plot_experiment(out, mode, 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'complexity','complexity_ber','efficiency'}
        plot_experiment(out, 'complexity', 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'ck_stress','8023ck_stress','ieee8023ck','ck_dirty'}
        plot_experiment(out, 'ck_stress', 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'8023ck_sparam','ck_sparam','sparam_benchmark','com_style'}
        plot_experiment(out, '8023ck_sparam', 'save_dir', opts.save_dir, ...
            'save_format', opts.fmt, 'fig_visible', opts.fig_visible);
    case {'markov_source_profile','mjs_source','source_markov'}
        plot_experiment(out, 'markov_source_profile', 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'ber_severe','severe','ber_realistic','realistic'}
        plot_experiment(out, 'hero_ber', 'save_dir', opts.save_dir, 'save_format', opts.fmt, ...
                        'regime_label', mode);
    case {'hmm_accuracy','table5'}
        plot_experiment(out, 'hmm_accuracy', 'save_dir', opts.save_dir, 'save_format', opts.fmt);
    case {'burden_isolation','oracle_dd'}
        plot_experiment(out, 'burden_isolation', 'save_dir', opts.save_dir, 'save_format', opts.fmt);

    % v73 NEW: reviewer-revision modes have no dedicated plotter; the
    % scripts print their own tables. Skip silently.
    case {'reviewer_diag','rev_diag','diagnostics', ...
          'shared_vs_banklocal','buffer_bench','svb','banklocal', ...
          'reviewer_revision','rev_pack','revision'}
        % no plotter -- tables are printed by the scripts themselves.

    case {'all_full','all_v65','all_v66','all_v67','all_v70','all_v71','all_v72','all_v73', ...
          'all_with_revision','all_v73_full'}
        % Plot every sub-experiment
        if isfield(out,'severe')
            plot_experiment(out.severe, 'hero_ber', 'save_dir', opts.save_dir, ...
                'save_format', opts.fmt, 'regime_label', 'severe');
        end
        if isfield(out,'realistic')
            plot_experiment(out.realistic, 'hero_ber', 'save_dir', opts.save_dir, ...
                'save_format', opts.fmt, 'regime_label', 'realistic');
        end
        if isfield(out,'hmm_accuracy'),     plot_experiment(out.hmm_accuracy, 'hmm_accuracy', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'burden_isolation'), plot_experiment(out.burden_isolation, 'burden_isolation', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'p_mismatch'),       plot_experiment(out.p_mismatch, 'p_mismatch', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'state_separation'), plot_experiment(out.state_separation, 'state_separation', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'theory_proxy'),     plot_experiment(out.theory_proxy, 'theory_proxy', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'markov_source'),    plot_experiment(out.markov_source, 'markov_source_profile', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'direct'),           plot_experiment(out.direct, 'direct_benchmarks', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'liu_eye'),          plot_experiment(out.liu_eye, 'liu_like_eye', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'liu_eye_mc'),       plot_experiment(out.liu_eye_mc, 'liu_like_eye_mc', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'complexity'),       plot_experiment(out.complexity, 'complexity', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end
        if isfield(out,'ck_stress'),        plot_experiment(out.ck_stress, 'ck_stress', 'save_dir', opts.save_dir, 'save_format', opts.fmt); end

    otherwise
        % no plotter
end
end
