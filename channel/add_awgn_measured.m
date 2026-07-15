% Auto-split from NCKH_v53.m (original line 3982).
% Folder: channel

function [r, sigma2] = add_awgn_measured(x, snr_db)
    Px = mean(x.^2);
    sigma2 = Px / (10^(snr_db/10));
    r = x + sqrt(sigma2) * randn(size(x));
end

