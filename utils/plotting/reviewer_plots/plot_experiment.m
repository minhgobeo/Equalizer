function out_path = plot_experiment(out, mode, varargin)
%PLOT_EXPERIMENT  Master plotting dispatcher (v65).

p = inputParser;
addParameter(p,'save_dir','figs',@ischar);
addParameter(p,'save_format','png',@ischar);
addParameter(p,'dpi',300,@isnumeric);
addParameter(p,'fig_visible','on',@ischar);
addParameter(p,'regime_label','',@ischar);
parse(p,varargin{:});
opts = p.Results;

if ~exist(opts.save_dir,'dir'); mkdir(opts.save_dir); end

mode = lower(mode);
switch mode
    case {'p_mismatch','transition_mismatch'}
        out_path = plot_p_mismatch(out, opts);
    case {'state_separation','h2_separation'}
        out_path = plot_state_separation(out, opts);
    case {'theory_proxy','proxy'}
        out_path = plot_theory_proxy(out, opts);
    case {'direct_benchmarks','direct_benchmark_suite','direct'}
        out_path = plot_direct_benchmarks(out, opts);
    case {'liu_like_eye','liu_eye','liu_like'}
        out_path = plot_liu_like_eye_benchmark(out, opts);
    case {'liu_like_eye_mc','liu_eye_mc','liu_mc'}
        out_path = plot_liu_like_eye_benchmark_mc(out, opts);
    case {'souza_smsign','souza','cui_hmm','cui','liu_ss_lms','liu','ss_lms', ...
          'dolatsara_scbo','dolatsara','chen_pulse','chen'}
        out_path = plot_single_benchmark(out, mode, opts);
    case {'complexity','complexity_ber','efficiency'}
        out_path = plot_complexity(out, opts);
    case {'ck_stress','8023ck_stress','ieee8023ck','ck_dirty'}
        out_path = plot_ck_stress(out, opts);
    case {'ck_stress_eye_split','ck_eye_split','8023ck_eye_split'}
        out_path = plot_ck_stress_eye_split(out, opts);
    case {'8023ck_sparam','ck_sparam','sparam_benchmark','com_style'}
        out_path = plot_8023ck_sparam_benchmark(out, opts);
    case {'markov_source_profile','mjs_source','source_markov'}
        out_path = plot_markov_source(out, opts);
    case {'hero_ber','severe','realistic','ber_severe','ber_realistic'}
        if isempty(opts.regime_label), opts.regime_label = mode; end
        out_path = plot_hero_ber(out, opts);
    case {'hmm_accuracy','table5'}
        out_path = plot_hmm_accuracy_table(out, opts);
    case {'burden_isolation','oracle_dd'}
        out_path = plot_burden_isolation(out, opts);
    otherwise
        warning('plot_experiment:unknown', 'No plotter for mode "%s"', mode);
        out_path = '';
end
end
