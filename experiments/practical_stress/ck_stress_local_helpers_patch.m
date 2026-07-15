% =====================================================================
% CK STRESS — Cui local helpers PATCH (faithful HMM-Viterbi)
% =====================================================================
%
% These functions REPLACE the existing local helpers in
% experiments/practical_stress/run_ck_stressed_channel_check.m.
%
% Specifically, replace:
%   - local_train_cui_ck_model   (lines ~385-396)
%   - local_predict_cui_ck       (lines ~460-485)
%   - local_train_cui_classifier (lines ~430-458)  -- minor edit for sigma
%
% Keep unchanged:
%   - local_cui_features_only
%   - local_cui_features_aligned
%   - local_sample_to_symbol_index
%   - local_symbol_to_class / local_class_to_symbol
%
% Make sure hmm_train_pam4.m and hmm_viterbi_pam4.m are on the MATLAB path
% (recommended location: core/utils/).
%
% After applying these patches, the CK stress Cui row in Table VI will be
% computed using the faithful Cui ExtraTrees + HMM-Viterbi method.
% =====================================================================


function model = local_train_cui_ck_model(cfg, profile, ck_tail, preeq_taps)
N_train = min(30000, cfg.Nsym);
rng(771000 + sum(double(profile)) + round(10*cfg.SNRdB));
cfg_t = cfg; cfg_t.Nsym = N_train;
sym_idx = randi([1 cfg_t.M], cfg_t.Nsym, 1);
d = cfg_t.A(sym_idx).'; d = d(:);
[r_dirty, ~, ~, ~] = local_ck_dirty_channel(d, cfg_t, profile, ck_tail);
r = filter(preeq_taps, 1, r_dirty);
[Xtr, ytr] = local_cui_features_aligned(r, d, 5, cfg_t.D);

% Train tree-ensemble classifier
[mdl, kind] = local_train_cui_classifier(Xtr, ytr, cfg_t.A);

% Train HMM on training labels (faithful Cui pipeline)
y_class_tr = local_symbol_to_class(ytr, cfg_t.A);
[logA, log_pi0, hmm_info] = hmm_train_pam4(y_class_tr, cfg_t.M, 1.0);

model = struct( ...
    'mdl', mdl, 'kind', kind, 'A', cfg_t.A, 'profile', profile, ...
    'N_train', N_train, 'M', cfg_t.M, ...
    'logA', logA, 'log_pi0', log_pi0, 'hmm_info', hmm_info);

fprintf('[ck_stress/cui] %-15s HMM trained, A diag = %s\n', ...
    profile, sprintf('%.3f ', diag(hmm_info.A)));
end


function yhat = local_predict_cui_ck(model, X, A)
% Faithful Cui prediction: ExtraTrees soft scores -> Viterbi decode -> symbols.
M = model.M;

% 1. Soft class probabilities from classifier
P_emit = local_classifier_scores(model, X, M);

% 2. Viterbi decoding
y_class = hmm_viterbi_pam4(P_emit, model.logA, model.log_pi0);

% 3. Map class -> PAM4 symbol
yhat = local_class_to_symbol(y_class, A);
yhat = yhat(:);
end


function P = local_classifier_scores(model, X, M)
% Return N x M emission-probability matrix from any of the 3 classifier kinds.
N = size(X,1);
P = zeros(N, M);

switch model.kind
    case 'fitcensemble_bag'
        [~, scores] = predict(model.mdl.mdl, X);
        cls = model.mdl.mdl.ClassNames;
        if iscell(cls), cls = str2double(cls); end
        for k = 1:numel(cls)
            mi = round(cls(k));
            if mi >= 1 && mi <= M
                P(:, mi) = scores(:, k);
            end
        end
        if any(P(:) < 0), P = exp(P); end
        P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);

    case 'TreeBagger'
        [~, scores] = predict(model.mdl.mdl, X);
        cls = model.mdl.mdl.ClassNames;
        if iscell(cls), cls = str2double(cls); end
        for k = 1:numel(cls)
            mi = round(cls(k));
            if mi >= 1 && mi <= M
                P(:, mi) = scores(:, k);
            end
        end
        P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);

    case 'nearest_centroid'
        C = size(model.mdl.centroids, 1);
        D = zeros(N, C);
        for c = 1:C
            d = X - model.mdl.centroids(c,:);
            D(:,c) = sum(d.*d, 2);
        end
        sig2 = max(mean(D(:)) / 4, 1e-6);
        for c = 1:C
            mi = round(model.mdl.classes(c));
            if mi >= 1 && mi <= M
                P(:, mi) = exp(-D(:,c) / (2*sig2));
            end
        end
        P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);

    otherwise
        error('Unknown classifier kind: %s', model.kind);
end

P = max(P, 1e-12);
P = bsxfun(@rdivide, P, sum(P,2));
end


function [model, kind] = local_train_cui_classifier(X, y, A)
% UNCHANGED from v72 — included only for self-containment of this patch.
y_class = local_symbol_to_class(y, A);
model = struct();
kind = 'nearest_centroid';
if exist('fitcensemble','file') == 2
    try
        model.mdl = fitcensemble(X, y_class, 'Method','Bag', 'NumLearningCycles',50);
        kind = 'fitcensemble_bag'; return;
    catch ME
        fprintf('[ck_stress/cui] fitcensemble unavailable (%s), trying TreeBagger.\n', ME.message);
    end
end
if exist('TreeBagger','file') == 2
    try
        model.mdl = TreeBagger(50, X, y_class, 'Method','classification');
        kind = 'TreeBagger'; return;
    catch ME
        fprintf('[ck_stress/cui] TreeBagger unavailable (%s), falling back.\n', ME.message);
    end
end
classes = unique(y_class);
C = numel(classes);
centroids = zeros(C, size(X,2));
for c = 1:C
    centroids(c,:) = mean(X(y_class == classes(c), :), 1);
end
model.centroids = centroids;
model.classes = classes;
end
