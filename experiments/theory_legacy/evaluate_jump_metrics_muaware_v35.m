% Auto-split from NCKH_v53.m (original line 4449).
% Folder: experiments/theory_legacy

function [oa_mean, pf_mean] = evaluate_jump_metrics_muaware_v35(cfg, v, mc)
    cfg_jump = cfg;
    cfg_jump.chan_mode = 'baseline_2tap';
    jump_idx = round(cfg_jump.Nsym * 0.55);

    acc_oa = 0; acc_pf = 0;
    for t = 1:mc.Ntrial_theorem
        rng(15000 + t);
        sym_idx = randi([1 cfg_jump.M], cfg_jump.Nsym, 1);
        d = cfg_jump.A(sym_idx).'; d = d(:);

        cfg1 = cfg_jump; cfg1.h_isi = [1 0.5];
        cfg2 = cfg_jump; cfg2.h_isi = [1 0.9];
        [r1_clean, ~] = channel_out(d(1:jump_idx), cfg1);
        [r2_clean, ~] = channel_out(d(jump_idx+1:end), cfg2);
        r_clean = [r1_clean; r2_clean];
        [r, ~] = add_awgn_measured(r_clean, cfg_jump.SNRdB);

        [~,~,e_samp] = proposed_recursion(r, d, cfg_jump, v);
        e2 = e_samp.^2;
        win_pre  = max(1, jump_idx-400):jump_idx-1;
        win_post = jump_idx+1:min(cfg_jump.Nsym, jump_idx+1200);
        ref_level = mean(e2(win_pre));
        e2_post = e2(win_post);

        acc_oa = acc_oa + sum(max(e2_post - ref_level, 0));
        acc_pf = acc_pf + mean(e2_post);
    end
    oa_mean = acc_oa / mc.Ntrial_theorem;
    pf_mean = acc_pf / mc.Ntrial_theorem;
end

