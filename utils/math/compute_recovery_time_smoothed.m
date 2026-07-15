% Auto-split from NCKH_v53.m (original line 2962).
% Folder: utils/math

function Trec = compute_recovery_time_smoothed(post_curve_blk, ref_level, eps_rel, hold_len_raw, block_len)

    % convert raw hold length to block-domain hold length
    hold_blk = max(3, ceil(hold_len_raw / block_len));
    thr = (1 + eps_rel) * ref_level;

    K = numel(post_curve_blk);
    Trec = K * block_len;

    for k = 1:max(1, K-hold_blk+1)
        seg = post_curve_blk(k:min(K, k+hold_blk-1));
        if all(seg <= thr)
            Trec = k * block_len;
            return;
        end
    end
end

