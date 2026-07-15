% Auto-split from NCKH_v53.m (original line 11144).
% Folder: experiments/paper_main

function pkg = run_ber_v67_static(cfg, vars, base, mc)
% BER on static channel — verify Algorithm 4 doesn't break static performance.
 
    cfg_p = cfg;
    cfg_p.chan_mode = 'baseline_2tap';
    cfg_p.h_isi = [1 0.5];
    cfg_p.Nsym = 80000;
 
    pkg = run_ber_compare_alg134(cfg_p, vars, base, mc, 'v67_static', 8:2:26);
end
 
