% Auto-split from NCKH_v53.m (original line 7567).
% Folder: utils/math

function r_agc = apply_practical_agc(r, d, cfg)
% Simple pilot-based AGC for practical open-eye stage.
% Uses only the training segment.

    L = min([numel(r), numel(d), max(cfg.trainLen, 100)]);
    if L < 20
        r_agc = r;
        return;
    end

    ridx = 1:L;
    num = median(abs(r(ridx)));
    den = max(median(abs(d(ridx))), 1e-12);

    g_agc = num / den;
    r_agc = r / max(g_agc, 1e-12);
end

