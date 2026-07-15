% Auto-split from NCKH_v53.m (original line 5681).
% Folder: config

function cfg_eval = build_internal_eval_cfg(cfg)
    cfg_eval = cfg;
    cfg_eval.chan_mode = cfg.severe.chan_mode;
    cfg_eval.SNRdB     = cfg.severe.SNRdB;
    cfg_eval.trainLen  = cfg.severe.trainLen;
    cfg_eval.Nsym      = cfg.severe.Nsym;
    cfg_eval.h_isi     = cfg.severe.h_isi;
    cfg_eval.markov.P  = cfg.severe.markovP;
end

