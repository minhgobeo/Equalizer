% Auto-split from NCKH_v53.m (original line 11155).
% Folder: experiments/paper_main

function pkg = run_ber_v67_markov(cfg, vars, base, mc)
% BER on severe Markov — show Algorithm 4 beats NLMS.
 
    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    cfg_p.markov.h2_states = [0.30 0.50 0.70];
    cfg_p.markov.P = [0.95 0.05 0.00; 0.025 0.95 0.025; 0.00 0.05 0.95];
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
    cfg_p.Nsym = 80000;
 
    pkg = run_ber_compare_alg134(cfg_p, vars, base, mc, 'v67_markov', 10:2:30);
end
 
 
