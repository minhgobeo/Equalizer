% Auto-split from NCKH_v53.m (original line 5226).
% Folder: channel

function [y, sigma2] = add_noise_dispatch(x, cfg)
    if isfield(cfg,'std8023') && isfield(cfg.std8023,'enable') && cfg.std8023.enable
        switch lower(cfg.std8023.noise_model)
            case 'awgn'
                [y, sigma2] = add_awgn_measured(x, cfg.SNRdB);

            case 'awgn_impulsive'
                [y, sigma2, ~] = add_impulsive_noise_measured( ...
                    x, cfg.SNRdB, cfg.std8023.p_imp, cfg.std8023.alpha_imp);

            case 'office_env'
                % IEEE 802.3 Section 23.7: Office environment noise model
                % AWGN base + impulsive bursts >264 mV (telephone ringing etc.)
                [y, sigma2] = add_awgn_measured(x, cfg.SNRdB);
                % Add impulse noise per 802.3 spec
                N = numel(y);
                imp_mask = rand(N,1) < cfg.std8023.p_imp;
                sig_peak = max(abs(cfg.A));
                % Impulse amplitude: >264 mV in real units; scaled to signal level
                imp_amp  = cfg.std8023.imp_thresh_mV * 1e-3 / max(sig_peak,eps);
                imp_amp  = max(imp_amp, cfg.std8023.alpha_imp * sqrt(sigma2));
                y(imp_mask) = y(imp_mask) + imp_amp * (2*randi([0 1],sum(imp_mask),1)-1);

            otherwise
                error('Unknown std8023 noise model: %s', cfg.std8023.noise_model);
        end
    else
        if isfield(cfg,'noise_model') && strcmpi(cfg.noise_model,'impulsive')
            p_imp = 0.005; alpha_imp = 20;
            if isfield(cfg,'p_imp'), p_imp = cfg.p_imp; end
            if isfield(cfg,'alpha_imp'), alpha_imp = cfg.alpha_imp; end
            [y, sigma2, ~] = add_impulsive_noise_measured(x, cfg.SNRdB, p_imp, alpha_imp);
        else
            [y, sigma2] = add_awgn_measured(x, cfg.SNRdB);
        end
    end
end



%% ========================================================================
% 7) MINIMUM CALL-SITE CHANGES
%
% Search/replace:
%   [r, sigma2] = add_awgn_measured(r_clean, cfg.SNRdB);
% with:
%   [r, sigma2] = add_noise_dispatch(r_clean, cfg);
%
% Search/replace:
%   [r,~] = add_awgn_measured(r_clean, cfg.SNRdB);
% with:
%   [r,~] = add_noise_dispatch(r_clean, cfg);
%
% Recommended places:
%   - run_convergence_experiment
%   - run_ser_experiment
%   - run_dd_bias_validation
%   - run_drift_validation
%   - run_structural_ablation_package
%   - run_noise_aware_comparison
%   - run_restoration_validation
%   - run_confirmatory_markov_v39
%   - run_confirmatory_jump_v39 (if you want noise also there)
%% ========================================================================



%% ========================================================================
% 8) RECOMMENDED PRACTICAL SETTINGS
%
%   cfg.std8023.enable = true;
%   cfg.std8023.profile = '100GAUI2_53G';
%   cfg.std8023.baud = 25e6;
%   cfg.std8023.ac_fc = 5e4;
%   cfg.std8023.add_xtalk = true;
%   cfg.std8023.xtalk_scale = 0.08;
%   cfg.std8023.noise_model = 'awgn_impulsive';
%   cfg.std8023.p_imp = 0.005;
%   cfg.std8023.alpha_imp = 20;
%
% If you have a real impulse response:
%   cfg.std8023.use_external_ir = true;
%   cfg.std8023.ir_file = 'channel_ir.csv';
%% ========================================================================

%% =====================================================================
% SUMMARY
%% =====================================================================
