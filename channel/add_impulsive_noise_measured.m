% Auto-split from NCKH_v53.m (original line 3988).
% Folder: channel

function [r, sigma2_awgn, noise_diag] = add_impulsive_noise_measured(x, snr_db, p_imp, alpha_imp)
    Px = mean(x.^2);
    sigma2_awgn = Px / (10^(snr_db/10));
    w_awgn = sqrt(sigma2_awgn) * randn(size(x));
    sigma2_imp = alpha_imp * sigma2_awgn;
    imp_mask = rand(size(x)) < p_imp;
    w_imp = sqrt(sigma2_imp) * randn(size(x)) .* imp_mask;
    r = x + w_awgn + w_imp;
    noise_diag = struct('sigma2_awgn',sigma2_awgn,'sigma2_imp',sigma2_imp,'p_imp',p_imp,'alpha_imp',alpha_imp);
end

