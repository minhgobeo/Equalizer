function [logA, log_pi0, info] = hmm_train_pam4(y_class_train, M, alpha_smooth)
%HMM_TRAIN_PAM4  Estimate HMM transition matrix and initial distribution.
%
% Trains the HMM parameters from a labeled training sequence of PAM4 symbol
% classes. Uses Laplace (add-alpha) smoothing on transition counts to avoid
% zero-probability transitions that would break log-Viterbi.
%
% INPUTS
%   y_class_train : T x 1 integer vector in {1..M}, training class labels
%   M             : number of classes (PAM4 -> 4)
%   alpha_smooth  : Laplace smoothing constant (default 1.0)
%
% OUTPUTS
%   logA      : M x M matrix, logA(i,j) = log P(y_t=j | y_{t-1}=i)
%   log_pi0   : 1 x M vector, log of empirical initial distribution
%   info      : struct with raw counts, transition matrix A, prior

    if nargin < 3, alpha_smooth = 1.0; end

    y_class_train = y_class_train(:);
    T = numel(y_class_train);
    if T < 2
        error('hmm_train_pam4: need at least 2 samples');
    end

    % --- Transition counts with Laplace smoothing ---
    counts = alpha_smooth * ones(M, M);
    for t = 2:T
        i = y_class_train(t-1);
        j = y_class_train(t);
        if i >= 1 && i <= M && j >= 1 && j <= M
            counts(i,j) = counts(i,j) + 1;
        end
    end
    rowsum = sum(counts, 2);
    A = bsxfun(@rdivide, counts, rowsum);
    logA = log(A + 1e-300);

    % --- Initial distribution: use stationary distribution (empirical) ---
    prior = zeros(1, M);
    for m = 1:M
        prior(m) = sum(y_class_train == m);
    end
    prior = (prior + alpha_smooth) / (T + M * alpha_smooth);
    log_pi0 = log(prior);

    info = struct();
    info.A           = A;
    info.counts      = counts;
    info.prior       = prior;
    info.M           = M;
    info.T_train     = T;
    info.alpha_smooth = alpha_smooth;
end
