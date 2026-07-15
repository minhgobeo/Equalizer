% Auto-split from NCKH_v53.m (original line 6389).
% Folder: experiments/theory_legacy

function ptf = supp_ptf_residual_scaling(cfg, vars, mc)
% Validates PTF identification step: |R_f(n)| = O(mu_n^2)
% Paper Experiment T1-S4 (Theorem 1, Stage 4)
%
% Proxy: ||dtheta_n||^2 / mu_n^2 should be O(1) across decay rates.
% Rationale: By eq:t1s1, ||dtheta_n|| <= C_H * mu_n, so ||dtheta||^2 <= C_H^2 * mu^2.
% If this ratio is approximately constant across mu_decay rates, it confirms
% that the PTF residual bound |r_f(n)| <= C_f * mu_n^2 holds with C_f ~ constant.
% The actual PTF residual r_f = f_tilde_{n+1} - f_tilde_n - mu_n<grad f, hbar>
% cannot be computed directly without knowing hbar(theta,s); this proxy validates
% the underlying bounded-increment property that drives the O(mu^2) bound.

    cfg_ode              = cfg;
    cfg_ode.Nsym         = cfg.ode.Nsym;
    cfg_ode.chan_mode     = 'frozen_markov_state';
    cfg_ode.SNRdB        = cfg.ode.SNRdB_ode;
    cfg_ode.trainLen     = 0;
    cfg_ode.markov.fixed_state = cfg.markov.fixed_state;

    decay_list = [1e-3, 2e-3, 5e-3, 1e-2, 2e-2];
    v          = vars.theorem;
    v.mu_mode  = 'diminishing';

    ratio_mean = zeros(numel(decay_list), 1);
    ratio_std  = zeros(numel(decay_list), 1);
    mu2_mean   = zeros(numel(decay_list), 1);

    Ntrial = min(mc.Ntrial_ode, 20);

    for id = 1:numel(decay_list)
        v.mu0      = cfg.ode.mu0;
        v.mu_decay = decay_list(id);

        ratio_bank = zeros(Ntrial, 1);
        mu2_bank   = zeros(Ntrial, 1);

        for t = 1:Ntrial
            rng(55000 + 100*id + t);
            sym_idx = randi([1 cfg_ode.M], cfg_ode.Nsym, 1);
            d = cfg_ode.A(sym_idx).'; d = d(:);
            [r_clean,~] = channel_out(d, cfg_ode);
            [r,~]       = add_noise_dispatch(r_clean, cfg_ode);

            % Perfect-decision recursion gives cleanest PTF signal
            [~,~,~,diag] = proposed_recursion_pd(r, d, cfg_ode, v);

            mu_vec   = diag.mu_hist(:);
            dth      = diag.dtheta_hist;
            dth_nrm2 = sum(dth.^2, 1).';     % ||theta_{n+1} - theta_n||^2
            mu2_vec  = mu_vec.^2;

            % PTF residual proxy: ||dtheta||^2 / mu_n^2 should be O(1)
            valid = mu2_vec > 1e-20;
            if any(valid)
                ratio_bank(t) = mean(dth_nrm2(valid) ./ mu2_vec(valid));
            end
            mu2_bank(t) = mean(mu2_vec);
        end

        ratio_mean(id) = mean(ratio_bank);
        ratio_std(id)  = std(ratio_bank);
        mu2_mean(id)   = mean(mu2_bank);
    end

    ptf = struct();
    ptf.decay_list  = decay_list;
    ptf.ratio_mean  = ratio_mean;
    ptf.ratio_std   = ratio_std;
    ptf.mu2_mean    = mu2_mean;

    % ---- Figure G1-B: PTF residual scaling ----------------------------
    figure('Name','G1-B: Theorem 1 — PTF residual O(mu^2) check');
    clf;
    errorbar(decay_list, ratio_mean, ratio_std, 'o-', 'LineWidth', 1.5, ...
        'CapSize', 6);
    hold on;
    yline(mean(ratio_mean), 'r--', 'LineWidth', 1.2, ...
        'DisplayName', 'Constant level (O(1) = O(\mu_n^2)/\mu_n^2)');
    grid on;
    set(gca, 'XScale', 'log');
    xlabel('\mu decay rate');
    ylabel('||\Delta\theta_n||^2 / \mu_n^2  (normalized PTF residual)');
    title({'T1-S4: PTF Residual Scaling';
           'Ratio \approx constant confirms |R_f(n)| = O(\mu_n^2)'});
    legend('Empirical ratio ±1SD', 'Grand mean', 'Location','best');
    set(gcf,'Position',[100 100 560 300]);

    fprintf('[G1-B] PTF ratio range: [%.3f, %.3f]  (should be ~constant)\n', ...
        min(ratio_mean), max(ratio_mean));
end

% =========================================================================
%  GROUP 2-A  —  IRREDUCIBILITY EXPERIMENT  (Gap 3: main novelty)
% =========================================================================
