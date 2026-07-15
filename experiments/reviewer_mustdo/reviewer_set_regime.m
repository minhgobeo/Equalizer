function cfg_p = reviewer_set_regime(cfg, regime)
%REVIEWER_SET_REGIME Shared configuration for reviewer-facing experiments.
cfg_p = cfg;
cfg_p.chan_mode = 'markov_2tap';
cfg_p.Nsym = 80000;
cfg_p.trainLen = 8000;
cfg_p.D = 2;
cfg_p.Nf = 5;
cfg_p.Nb = 1;
cfg_p.markov.init_state = 2;
cfg_p.markov.fixed_state = 2;
if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end
switch lower(regime)
    case 'severe'
        cfg_p.markov.h2_states = [0.30 0.50 0.70];
        cfg_p.markov.P = [0.95 0.05 0.00; 0.025 0.95 0.025; 0.00 0.05 0.95];
    case 'realistic'
        cfg_p.markov.h2_states = [0.45 0.50 0.55];
        cfg_p.markov.P = [0.99 0.01 0.00; 0.005 0.99 0.005; 0.00 0.01 0.99];
    case 'static'
        cfg_p.chan_mode = 'baseline_2tap';
        cfg_p.h_isi = [1 0.5];
    otherwise
        error('Unknown reviewer regime: %s', regime);
end
end
