% Auto-split from NCKH_v53.m (original line 10635).
% Folder: config

function v_new = make_v_with_lambda_schedule(v, Nsym)
% Create variant with Algorithm 3 schedule.
% Schedule: lambda_n = lambda_0 / (1 + alpha*n)^beta
%
% Parameters chosen so that:
%   At n=0:        lambda = lambda_0 = 0.001 (initial stability)
%   At n=Nsym/2:   lambda ~ lambda_0 / 5
%   At n=Nsym:     lambda ~ lambda_0 / 10
% This gives 10x bias reduction at end of long packets.
 
    v_new = v;
    v_new.lambda_schedule = true;
    v_new.lambda_0     = v.lambda;        % initial value (= original lambda)
    v_new.lambda_alpha = 1e-4;            % decay rate parameter
    v_new.lambda_beta  = 1.0;             % decay exponent (Robbins-Monro)
    v_new.lambda_min   = v.lambda * 0.05; % floor at lambda_0/20
 
    % Keep original kind so proposed_update_components recognizes it.
    % Schedule is applied externally in proposed_recursion_lambda_schedule.
end
 
 
