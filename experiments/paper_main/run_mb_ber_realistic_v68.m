% Auto-split from NCKH_v53.m (original line 11959).
% Folder: experiments/paper_main

function pkg = run_mb_ber_realistic_v68(cfg, vars, base, mc)
    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    cfg_p.markov.h2_states = [0.45 0.50 0.55];
    cfg_p.markov.P = [0.99 0.01 0.00; 0.005 0.99 0.005; 0.00 0.01 0.99];
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
    cfg_p.Nsym = 80000;
    pkg = run_mb_ber_compare(cfg_p, vars, base, mc, 'mb_realistic', 10:2:30);
end


