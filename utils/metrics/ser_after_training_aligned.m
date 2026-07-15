% Auto-split from NCKH_v53.m (original line 4061).
% Folder: utils/metrics

function ser = ser_after_training_aligned(d, d_hat, cfg)
    mm = (1:numel(d_hat)).' - cfg.D;
    mask = (mm >= (cfg.trainLen+1)) & (mm <= numel(d));
    idx = mm(mask);
    ser = mean(d_hat(idx) ~= d(idx));
end

