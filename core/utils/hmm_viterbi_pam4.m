function [y_decoded, info] = hmm_viterbi_pam4(emission_prob, logA, log_pi0)
%HMM_VITERBI_PAM4  Viterbi decoding for PAM4 symbols given soft emission probs.
%
% Implements Cui et al. 2024 Eqs. (13)-(18) in log domain for numerical stability.
%
% INPUTS
%   emission_prob : T x M matrix, emission_prob(t,m) = P(class=m | x_t)
%                   obtained from ExtraTrees / TreeBagger / classifier ensemble.
%                   For PAM4: M = 4.
%   logA          : M x M matrix, logA(i,j) = log P(y_t=j | y_{t-1}=i)
%   log_pi0       : 1 x M vector, log_pi0(m) = log P(y_1 = m)
%
% OUTPUTS
%   y_decoded : T x 1 integer vector in {1..M}, the Viterbi-optimal class sequence
%   info      : struct with rho_final (log-likelihood of best path) and runtime
%
% NOTES
% - For balanced PAM4 training (uniform class prior), the Bayes inversion
%   b_n(x_t) = P(c_n|x_t)*P(x_t)/P(y_t=c_n) reduces to a t-dependent constant
%   that doesn't affect Viterbi argmax. We therefore use log P(class|x_t)
%   directly as the log-emission term, which is what Cui Eq (16) becomes
%   under uniform class prior.
% - Numerical safeguard: emission probs are clipped to [eps_p, 1] before log.

    t_start = tic;

    [T, M] = size(emission_prob);
    if size(logA,1) ~= M || size(logA,2) ~= M
        error('hmm_viterbi_pam4: logA must be %dx%d', M, M);
    end
    if numel(log_pi0) ~= M
        error('hmm_viterbi_pam4: log_pi0 must have length %d', M);
    end
    log_pi0 = log_pi0(:).';   % row vector

    eps_p = 1e-12;
    log_emit = log(max(emission_prob, eps_p));

    % Pre-allocate
    rho   = -inf(T, M);     % log of joint prob max
    omega = zeros(T, M, 'uint8');

    % --- Initialization (Cui Eq 15) ---
    rho(1,:) = log_pi0 + log_emit(1,:);

    % --- Recursion (Cui Eq 16), vectorized over destination state j ---
    % For each t, score(l,j) = rho(t-1,l) + logA(l,j), then
    %   rho(t,j) = max_l score(l,j) + log_emit(t,j)
    %   omega(t,j) = argmax_l score(l,j)
    for t = 2:T
        prev = rho(t-1,:).';                  % M x 1
        score = bsxfun(@plus, prev, logA);    % M x M, row=l, col=j
        [maxv, argv] = max(score, [], 1);     % 1 x M
        rho(t,:)   = maxv + log_emit(t,:);
        omega(t,:) = uint8(argv);
    end

    % --- Termination (Cui Eq 17) ---
    [rho_final, last_state] = max(rho(T,:));

    % --- Backtracking (Cui Eq 18) ---
    y_decoded = zeros(T,1);
    y_decoded(T) = last_state;
    for t = T-1:-1:1
        y_decoded(t) = double(omega(t+1, y_decoded(t+1)));
    end

    info = struct();
    info.rho_final  = rho_final;
    info.runtime_s  = toc(t_start);
    info.T          = T;
    info.M          = M;
end
