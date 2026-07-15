% Auto-split from NCKH_v53.m (original line 12490).
% Folder: core/algorithm6_msb

function [raw_acc, best_acc, best_perm] = msb_state_accuracy(s_hat_hist, true_state, idx)
% Compute raw and best-permutation accuracy for 3-state labels.
% best-permutation protects against bank-label swapping.
    idx = idx(:);
    s_hat = s_hat_hist(idx);
    s_true = true_state(idx);

    valid = isfinite(s_hat) & isfinite(s_true) & s_hat > 0 & s_true > 0;
    s_hat = s_hat(valid);
    s_true = s_true(valid);

    if isempty(s_hat)
        raw_acc = NaN; best_acc = NaN; best_perm = [];
        return;
    end

    raw_acc = mean(s_hat == s_true);

    states = unique(s_true(:).');
    if numel(states) ~= 3
        best_acc = raw_acc;
        best_perm = states;
        return;
    end

    perms3 = perms(1:3);
    best_acc = -inf;
    best_perm = 1:3;
    for k = 1:size(perms3,1)
        p = perms3(k,:);
        mapped = zeros(size(s_hat));
        for s = 1:3
            mapped(s_hat == s) = p(s);
        end
        acc = mean(mapped == s_true);
        if acc > best_acc
            best_acc = acc;
            best_perm = p;
        end
    end
end


% ============================================================================
% Optional replacement diagnostic: run_mb_state_track_v69
% ============================================================================

