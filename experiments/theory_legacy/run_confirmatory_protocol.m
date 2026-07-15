% Auto-split from NCKH_v53.m (original line 4684).
% Folder: experiments/theory_legacy

function confirm = run_confirmatory_protocol(cfg, vars, mc)
% ========================================================================
% CONFIRMATORY PROTOCOL
%
% FINAL GOAL:
%   Validate the paper candidate at longer sequence length and more trials.
%
% SETTINGS:
%   Nsym = 50000
%   trainLen = 1800
%   Ntrial_theorem = 10
%
% CASES:
%   theorem
%   noise_aware
%   const_global
%   const_same_energy
% ========================================================================

    fprintf('\n=== Confirmatory protocol (v39/final) ===\n');

    % --------------------------------
    % lock confirmatory configuration
    % --------------------------------
    cfg_c = cfg;
    cfg_c.Nsym     = 50000;
    cfg_c.trainLen = 1800;
    cfg_c.SNRdB    = 20;

    mc_c = mc;
    mc_c.Ntrial_theorem = 10;

    % --------------------------------
    % lock theorem baseline
    % --------------------------------
    vars_c = vars;
    vars_c.theorem.tau_c   = 0.45;
    vars_c.theorem.gamma_u = 0.01;
    vars_c.theorem.kappa_u = 0.10;

    % --------------------------------
    % lock paper candidate
    % --------------------------------
    vars_c.noise_aware.alpha_sigma = 0.09;
    vars_c.noise_aware.alpha_b     = 0.30;
    vars_c.noise_aware.alpha_d     = 0.50;

    vars_c.noise_aware.use_adaptive_mu    = true;
    vars_c.noise_aware.use_adaptive_tau   = false;
    vars_c.noise_aware.use_adaptive_kappa = false;

    vars_c.noise_aware.b_bias  = 0.015;
    vars_c.noise_aware.b_drift = 0.005;

    vars_c.noise_aware.tau_c0   = 0.45;
    vars_c.noise_aware.tau_c    = 0.45;
    vars_c.noise_aware.gamma_u0 = 0.01;
    vars_c.noise_aware.gamma_u  = 0.01;
    vars_c.noise_aware.kappa_u0 = 0.10;
    vars_c.noise_aware.kappa_u  = 0.10;

    % --------------------------------
    % Markov confirmatory
    % --------------------------------
    confirm_markov = run_confirmatory_markov_v39(cfg_c, vars_c, mc_c);

    % --------------------------------
    % Jump confirmatory
    % --------------------------------
    confirm_jump = run_confirmatory_jump_v39(cfg_c, vars_c, mc_c);

    % --------------------------------
    % merge tables
    % --------------------------------
    confirm = outerjoin(confirm_markov, confirm_jump, 'Keys', 'Case', 'MergeKeys', true);

    writetable(confirm, 'confirmatory_protocol_v42.csv');

    fprintf('\nConfirmatory results (v42/final):\n');
    disp(confirm);

    % --------------------------------
    % verdicts
    % --------------------------------
    th = confirm(strcmp(confirm.Case,'theorem'),:);
    na = confirm(strcmp(confirm.Case,'noise_aware'),:);

    delta_pf_th   = na.paramFloor_markov - th.paramFloor_markov;
    delta_oa_th   = na.OvershootArea     - th.OvershootArea;
    delta_post_th = na.PostJumpFloor     - th.PostJumpFloor;

    fprintf('\nDelta(noise_aware - theorem):\n');
    fprintf('  paramFloor_markov = %+0.6e\n', delta_pf_th);
    fprintf('  OvershootArea     = %+0.6e\n', delta_oa_th);
    fprintf('  PostJumpFloor     = %+0.6e\n', delta_post_th);

    if (delta_pf_th <= 0) && (delta_oa_th < 0) && (delta_post_th < 0)
        fprintf('Confirmatory verdict vs theorem: candidate PASSES.\n');
    elseif (delta_oa_th < 0) && (delta_post_th < 0) ...
            && ((delta_pf_th / max(th.paramFloor_markov,1e-12)) <= 0.02)
        fprintf('Confirmatory verdict vs theorem: candidate PASSES (practical tolerance on paramFloor).\n');
    else
        fprintf('Confirmatory verdict vs theorem: candidate NOT fully confirmed.\n');
    end

    % --------------------------------
    % practical fixed-gain comparison
    % --------------------------------
    idx_cg = strcmp(confirm.Case,'const_global');
    if any(idx_cg)
        cg = confirm(idx_cg,:);
        delta_pf_cg   = na.paramFloor_markov - cg.paramFloor_markov;
        delta_oa_cg   = na.OvershootArea     - cg.OvershootArea;
        delta_post_cg = na.PostJumpFloor     - cg.PostJumpFloor;

        fprintf('\nDelta(noise_aware - const_global):\n');
        fprintf('  paramFloor_markov = %+0.6e\n', delta_pf_cg);
        fprintf('  OvershootArea     = %+0.6e\n', delta_oa_cg);
        fprintf('  PostJumpFloor     = %+0.6e\n', delta_post_cg);
    end

    % --------------------------------
    % explanatory control comparison
    % --------------------------------
    idx_cse = strcmp(confirm.Case,'const_same_energy');
    if any(idx_cse)
        cse = confirm(idx_cse,:);
        delta_pf_cse   = na.paramFloor_markov - cse.paramFloor_markov;
        delta_oa_cse   = na.OvershootArea     - cse.OvershootArea;
        delta_post_cse = na.PostJumpFloor     - cse.PostJumpFloor;

        fprintf('\nDelta(noise_aware - const_same_energy):\n');
        fprintf('  paramFloor_markov = %+0.6e\n', delta_pf_cse);
        fprintf('  OvershootArea     = %+0.6e\n', delta_oa_cse);
        fprintf('  PostJumpFloor     = %+0.6e\n', delta_post_cse);
    end
end

