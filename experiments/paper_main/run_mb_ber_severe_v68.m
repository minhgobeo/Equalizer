% Auto-split from NCKH_v53.m (original line 11948).
% Folder: experiments/paper_main

function pkg = run_mb_ber_severe_v68(cfg, vars, base, mc, snr_list, varargin)
    if nargin < 5 || isempty(snr_list)
        snr_list = 10:2:30;
    end
    p = inputParser;
    addParameter(p, 'Nsym', 80000, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'trainLen', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    addParameter(p, 'force_trials', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    parse(p, varargin{:});
    opt = p.Results;

    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    mkprof = controlled_markov_isi_profile_v72('profile', 'severe_partial_response');
    cfg_p.markov.h2_states = mkprof.h2_states;
    cfg_p.markov.P = mkprof.P;
    cfg_p.markov.init_state = mkprof.init_state;
    cfg_p.markov.profile = mkprof;
    cfg_p.markov.fixed_state = 2;
    if ~isempty(opt.force_trials)
        cfg_p.force_trials = opt.force_trials;
    end
    cfg_p.Nsym = opt.Nsym;
    if isempty(opt.trainLen)
        cfg_p.trainLen = min(max(cfg_p.trainLen, 8000), floor(0.25 * cfg_p.Nsym));
    else
        cfg_p.trainLen = min(opt.trainLen, floor(0.25 * cfg_p.Nsym));
    end
    pkg = run_mb_ber_compare(cfg_p, vars, base, mc, 'mb_severe', snr_list);
end

