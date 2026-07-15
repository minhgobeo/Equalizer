% Auto-split from NCKH_v53.m (original line 4890).
% Folder: experiments/theory_legacy

function T = run_confirmatory_jump_v39(cfg, vars, mc)
    cfg_jump = cfg;
    cfg_jump.chan_mode = 'baseline_2tap';
    jump_idx = round(cfg_jump.Nsym * 0.55);

    cases = {'theorem','noise_aware','const_global','const_same_energy'};
    Nc = numel(cases);

    OvershootArea = zeros(Nc,1);
    PostJumpFloor = zeros(Nc,1);

    for ic = 1:Nc
        acc_oa = 0;
        acc_pf = 0;

        for t = 1:mc.Ntrial_theorem
            rng(61000 + 100*ic + t);

            sym_idx = randi([1 cfg_jump.M], cfg_jump.Nsym, 1);
            d = cfg_jump.A(sym_idx).'; d = d(:);

            cfg1 = cfg_jump; cfg1.h_isi = [1 0.5];
            cfg2 = cfg_jump; cfg2.h_isi = [1 0.9];

            [r1_clean, ~] = channel_out(d(1:jump_idx), cfg1);
            [r2_clean, ~] = channel_out(d(jump_idx+1:end), cfg2);
            r_clean = [r1_clean; r2_clean];

            [r, ~] = add_noise_dispatch(r_clean, cfg_jump);

            switch cases{ic}
                case 'theorem'
                    vv = vars.theorem;
                case 'noise_aware'
                    vv = vars.noise_aware;
                case 'const_global'
                    vv = make_constant_gain_version(vars.theorem, 'global');
                case 'const_same_energy'
                    vv = make_constant_gain_version(vars.theorem, 'same_energy');
                otherwise
                    error('Unknown confirmatory case in run_confirmatory_jump_v39.');
            end

            [~,~,e_samp] = proposed_recursion(r, d, cfg_jump, vv);
            e2 = e_samp.^2;

            win_pre  = max(1, jump_idx-400):jump_idx-1;
            win_post = jump_idx+1:min(cfg_jump.Nsym, jump_idx+1200);

            ref_level = mean(e2(win_pre));
            e2_post   = e2(win_post);

            acc_oa = acc_oa + sum(max(e2_post - ref_level, 0));
            acc_pf = acc_pf + mean(e2_post);
        end

        OvershootArea(ic) = acc_oa / mc.Ntrial_theorem;
        PostJumpFloor(ic) = acc_pf / mc.Ntrial_theorem;
    end

    T = table(cases(:), OvershootArea, PostJumpFloor, ...
        'VariableNames', {'Case','OvershootArea','PostJumpFloor'});
end






%% ========================================================================
% 3) PATCH channel_out(...)
%
% At the TOP of channel_out(d, cfg), add:
%
%   if isfield(cfg,'std8023') && isfield(cfg.std8023,'enable') && cfg.std8023.enable
%       [r_clean, ch_state] = channel_out_std8023_like(d, cfg);
%       return;
%   end
%
% Leave the rest of channel_out(...) unchanged.
%% ========================================================================



%% ========================================================================
% 4) NEW FUNCTION: channel_out_std8023_like(...)
%    Append this whole function block to the END of your file.
%% ========================================================================

