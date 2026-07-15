% Auto-split from NCKH_v53.m (original line 10827).
% Folder: config

function v_new = make_v_with_sbc(v, alpha_corr, beta_B)
% Create variant with Algorithm 4 (Structural Bias Correction).
%   alpha_corr : correction strength, 0 <= alpha <= 1
%                alpha = 0 → Algorithm 3 only (no SBC)
%                alpha = 1 → full bias subtraction
%   beta_B     : EWMA factor for b_hat_c update (typical 1e-3..1e-2)
 
    v_new = v;
 
    % Inherit Algorithm 3 (lambda schedule)
    v_new.lambda_schedule = true;
    v_new.lambda_0     = v.lambda;
    v_new.lambda_alpha = 1e-4;
    v_new.lambda_beta  = 1.0;
    v_new.lambda_min   = v.lambda * 0.05;
 
    % Add SBC parameters
    v_new.sbc_enable = true;
    v_new.sbc_alpha  = alpha_corr;
    v_new.sbc_beta_B = beta_B;
end
 
 
