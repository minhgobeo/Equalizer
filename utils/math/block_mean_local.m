% Auto-split from NCKH_v53.m (original line 2980).
% Folder: utils/math

function y = block_mean_local(x, B)
    x = x(:);
    N = numel(x);
    K = floor(N / B);
    if K < 1
        y = mean(x);
        return;
    end
    x = x(1:K*B);
    x = reshape(x, B, K);
    y = mean(x, 1).';
end

%% =====================================================================
% APPENDIX PACKAGE
%% =====================================================================
