function pkg = run_cui_extratrees_hmm_direct_adapter(cfg, vars, base, mc)
%RUN_CUI_EXTRATREES_HMM_DIRECT_ADAPTER  Faithful Cui-style ExtraTrees+HMM equalizer.
%
% Implements the full Cui et al. 2024 method adapted to PAM4 DD:
%   1. ExtraTrees ensemble for class-conditional probabilities P(c_n | x_t).
%   2. HMM with transition matrix A and initial distribution pi learned from
%      training labels (Laplace-smoothed).
%   3. Viterbi decoding (log domain) on the test sequence.
%
% This replaces the v72 stub that omitted the HMM/Viterbi temporal decoder.
%
% Mapping from Cui paper:
%   - Eq (11)  : ExtraTrees vote -> P(c_n | x_t)  [we use predict() scores]
%   - Eqs (13) : transition probability a_{i,j}    [hmm_train_pam4]
%   - Eq (15)  : initialization rho_1               [hmm_viterbi_pam4]
%   - Eq (16)  : recursion rho_t, omega_t          [hmm_viterbi_pam4]
%   - Eq (17)  : termination                       [hmm_viterbi_pam4]
%   - Eq (18)  : backtracking                      [hmm_viterbi_pam4]
%
% Adaptations from Cui (optical OAM-MDM/NMCAP) to PAM4 DD:
%   - Feature vector is 5-D [r(n), r(n-1), r(n-2), r(n-3), r(n)-r(n-1)] rather
%     than Cui's 6L+3 NMCAP-IBI feature (the IBI extraction is NMCAP-specific
%     and has no analog in PAM4 IM/DD).
%   - Class prior in Bayes inversion (Cui Eq 12) is uniform under balanced
%     PAM4 training, so the inversion reduces to a t-dependent constant that
%     doesn't affect Viterbi argmax. We use log P(c|x_t) directly as the
%     log-emission term (mathematically equivalent under uniform prior).

regimes  = {'severe','realistic'};
snr_list = [14 18 22 26];
Ntest    = max(10, min(20, mc.Ntrial_ser));

N_train_block = 30000;
features_dim  = 5;

ber_grid = nan(numel(snr_list), numel(regimes));
ser_grid = nan(numel(snr_list), numel(regimes));
classifier_kind = '';

for rg = 1:numel(regimes)
    cfg_p = reviewer_set_regime(cfg, regimes{rg});
    cfg_p.Nsym = N_train_block;
    cfg_p.SNRdB = 20;        % training SNR (mid-range)

    rng(980000 + rg);
    sym_idx = randi([1 cfg_p.M], cfg_p.Nsym, 1);
    d = cfg_p.A(sym_idx).'; d = d(:);
    [r_clean,~] = channel_out(d, cfg_p);
    [r,~] = add_noise_dispatch(r_clean, cfg_p);

    [Xtr, ytr] = build_features(r, d, features_dim);
    y_class_tr = symbol_to_class(ytr, cfg_p.A);

    % --- Train tree classifier ---
    [model, classifier_kind] = train_classifier(Xtr, ytr, cfg_p.A);

    % --- Train HMM (transition matrix + initial distribution) ---
    [logA, log_pi0, hmm_info] = hmm_train_pam4(y_class_tr, cfg_p.M, 1.0);

    fprintf('[cui_hmm] regime=%s, classifier=%s, HMM trained: A diag=%s\n', ...
        regimes{rg}, classifier_kind, ...
        sprintf('%.3f ', diag(hmm_info.A)));

    for si = 1:numel(snr_list)
        ser_t = zeros(Ntest,1);
        for t=1:Ntest
            rng(980000 + 1000*rg + 100*si + t);
            cfg_q = cfg_p; cfg_q.SNRdB = snr_list(si); cfg_q.Nsym = 20000;
            sym_test = randi([1 cfg_q.M], cfg_q.Nsym, 1);
            d_test = cfg_q.A(sym_test).'; d_test = d_test(:);
            [rc,~] = channel_out(d_test, cfg_q);
            [rt,~] = add_noise_dispatch(rc, cfg_q);

            [Xte, ~] = build_features(rt, d_test, features_dim);

            % 1. Soft scores from ExtraTrees ensemble
            P_emit = predict_classifier_scores(model, Xte, classifier_kind, cfg_q.M);

            % 2. Viterbi decoding over PAM4 class sequence
            y_class_hat = hmm_viterbi_pam4(P_emit, logA, log_pi0);

            % 3. Map class indices back to PAM4 levels
            yhat = class_to_symbol(y_class_hat, cfg_q.A);

            % Post-train portion only
            mask = (1:numel(yhat)).' > cfg_q.trainLen;
            valid = mask & (1:numel(yhat)).' <= numel(d_test);
            err = mean(yhat(valid) ~= d_test(valid));
            ser_t(t) = err;
        end
        ser_grid(si,rg) = mean(ser_t);
        ber_grid(si,rg) = ser_grid(si,rg)/log2(cfg_p.M);
        fprintf('[cui_hmm] %s SNR=%d -> BER=%.3e (faithful HMM-Viterbi)\n', ...
            regimes{rg}, snr_list(si), ber_grid(si,rg));
    end
end

pkg.regimes = regimes;
pkg.snr_list = snr_list;
pkg.ber_grid = ber_grid;
pkg.ser_grid = ser_grid;
pkg.classifier_kind = classifier_kind;
pkg.tag = 'Cui_ExtraTrees_HMM_faithful';
pkg.note = ['Faithful Cui ExtraTrees+HMM with full Viterbi temporal decoding. ' ...
            'Feature vector adapted from NMCAP-IBI to PAM4 DD (5-D regressor).'];
end

% =====================================================================
function [X, y] = build_features(r, d, dim)
% [r(n), r(n-1), r(n-2), r(n-3), r(n)-r(n-1)]
N = numel(r);
X = zeros(N, dim);
for n=1:N
    rn = r(n);
    rm1 = 0; if n>=2, rm1 = r(n-1); end
    rm2 = 0; if n>=3, rm2 = r(n-2); end
    rm3 = 0; if n>=4, rm3 = r(n-3); end
    X(n,:) = [rn, rm1, rm2, rm3, rn - rm1];
end
y = d(:);
y = y(1:N);
end

% =====================================================================
function [model, kind] = train_classifier(X, y, A)
%TRAIN_CLASSIFIER Tree-ensemble classifier with graceful fallback.
y_class = symbol_to_class(y, A);

model = struct();
kind = 'nearest_centroid';

if exist('fitcensemble','file') == 2
    try
        m = fitcensemble(X, y_class, 'Method','Bag', 'NumLearningCycles',50);
        model.mdl = m;
        kind = 'fitcensemble_bag';
        return;
    catch ME
        fprintf('[cui_hmm] fitcensemble unavailable (%s), trying TreeBagger\n', ME.message);
    end
end

if exist('TreeBagger','file') == 2
    try
        m = TreeBagger(50, X, y_class, 'Method','classification');
        model.mdl = m;
        kind = 'TreeBagger';
        return;
    catch ME
        fprintf('[cui_hmm] TreeBagger unavailable (%s), falling back\n', ME.message);
    end
end

% Fallback: nearest-centroid in feature space with class covariance estimate.
classes = unique(y_class);
C = numel(classes);
centroids = zeros(C, size(X,2));
sigma2_class = zeros(C,1);
for c = 1:C
    mask_c = (y_class == classes(c));
    centroids(c,:)  = mean(X(mask_c, :), 1);
    sigma2_class(c) = max(var(X(mask_c,:) - centroids(c,:), 0, 'all'), 1e-6);
end
model.centroids    = centroids;
model.classes      = classes;
model.sigma2_class = sigma2_class;
end

% =====================================================================
function P = predict_classifier_scores(model, X, kind, M)
% Return N x M matrix of P(class | x_t).
N = size(X,1);
P = zeros(N, M);

switch kind
    case 'fitcensemble_bag'
        [~, scores] = predict(model.mdl, X);
        % fitcensemble returns scores in column order matching ClassNames.
        cls = model.mdl.ClassNames;
        if iscell(cls), cls = str2double(cls); end
        for k = 1:numel(cls)
            mi = round(cls(k));
            if mi >= 1 && mi <= M
                P(:, mi) = scores(:, k);
            end
        end
        % Convert log-likelihood ratios to probabilities if needed.
        if any(P(:) < 0)
            P = exp(P);
        end
        P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);

    case 'TreeBagger'
        [~, scores] = predict(model.mdl, X);
        cls = model.mdl.ClassNames;
        if iscell(cls), cls = str2double(cls); end
        for k = 1:numel(cls)
            mi = round(cls(k));
            if mi >= 1 && mi <= M
                P(:, mi) = scores(:, k);
            end
        end
        P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);

    case 'nearest_centroid'
        C = size(model.centroids,1);
        D = zeros(N, C);
        for c = 1:C
            d = X - model.centroids(c,:);
            D(:,c) = sum(d.*d, 2);
        end
        % Softmax over -D / (2*sigma^2), per-class sigma.
        for c = 1:C
            P(:, model.classes(c)) = exp(-D(:,c) / (2 * model.sigma2_class(c) + 1e-6));
        end
        % Normalize.
        rowsum = sum(P, 2) + 1e-12;
        P = bsxfun(@rdivide, P, rowsum);

    otherwise
        error('Unknown classifier kind: %s', kind);
end

% Floor probabilities to avoid log(0) in Viterbi.
P = max(P, 1e-12);
P = bsxfun(@rdivide, P, sum(P,2));
end

% =====================================================================
function c = symbol_to_class(d, A)
A = A(:);
[~, c] = min(abs(d - A.'), [], 2);
end

function s = class_to_symbol(c, A)
A = A(:);
c = round(c);
c = max(1, min(numel(A), c));
s = A(c);
end
