% Auto-split from NCKH_v53.m (original line 3034).
% Folder: experiments/supplement_legacy

function cliprslt = run_clipping_stress(cfg, vars, base, mc)
% Impulsive-stress appendix:
% compare proposed clipped / proposed no-clip / NLMS / SM-sign-NLMS VSS / SM-sign-NLMS

    p_list = [0 0.002 0.005 0.01 0.02];
    Np = numel(p_list);

    floor_prop_clip   = zeros(Np,1);
    floor_prop_noclip = zeros(Np,1);
    floor_nlms        = zeros(Np,1);
    floor_smsign_vss  = zeros(Np,1);
    floor_smsign      = zeros(Np,1);

    tail_prop_clip   = zeros(Np,1);
    tail_prop_noclip = zeros(Np,1);
    tail_nlms        = zeros(Np,1);
    tail_smsign_vss  = zeros(Np,1);
    tail_smsign      = zeros(Np,1);

    pclip_prop = zeros(Np,1);

    for ip = 1:Np
        p_imp = p_list(ip);

        acc_fc  = 0; acc_fnc = 0; acc_fn = 0; acc_fsv = 0; acc_fs = 0;
        acc_tc  = 0; acc_tnc = 0; acc_tn = 0; acc_tsv = 0; acc_ts = 0;
        acc_pc  = 0;

        for t = 1:mc.Ntrial_theorem
            rng(12000 + 100*ip + t);

            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);

            [r_clean, ~] = channel_out(d, cfg);

            cfg_imp = cfg;
            cfg_imp.std8023.enable      = true;
            cfg_imp.noise_model         = 'office_env';
            cfg_imp.p_imp               = p_imp;
            cfg_imp.alpha_imp           = 20;
            cfg_imp.trainLen            = cfg.trainLen;
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_imp);

            % proposed clipped
            vv_clip = vars.practical;
            vv_clip.force_no_clip = false;
            [~,~,e_pc,diag_pc] = proposed_recursion(r, d, cfg_imp, vv_clip);

            % proposed no-clip
            vv_noclip = vars.practical;
            vv_noclip.force_no_clip = true;
            [~,~,e_pn] = proposed_recursion(r, d, cfg_imp, vv_noclip);

            % NLMS
            [~,~,e_nlms] = dfe_nlms_unified_x(r, d, cfg_imp, base);

            % SM-sign-NLMS VSS
            [~,~,e_svss] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_imp, base, sigma2);

            % SM-sign-NLMS
            [~,~,e_sms]  = dfe_smsign_nlms_unified_x(r, d, cfg_imp, base, sigma2);

            % DD region
            N = numel(r);
            nn = (1:N).';
            mm = nn - cfg_imp.D;
            dd_mask = (mm >= (cfg_imp.trainLen+1)) & (mm <= cfg_imp.Nsym);

            % floor metrics
            acc_fc  = acc_fc  + mean(e_pc(dd_mask).^2);
            acc_fnc = acc_fnc + mean(e_pn(dd_mask).^2);
            acc_fn  = acc_fn  + mean(e_nlms(dd_mask).^2);
            acc_fsv = acc_fsv + mean(e_svss(dd_mask).^2);
            acc_fs  = acc_fs  + mean(e_sms(dd_mask).^2);

            % tail metric: top-1% mean(e^2)
            acc_tc  = acc_tc  + top_percent_mean(e_pc(dd_mask).^2,   1);
            acc_tnc = acc_tnc + top_percent_mean(e_pn(dd_mask).^2,   1);
            acc_tn  = acc_tn  + top_percent_mean(e_nlms(dd_mask).^2, 1);
            acc_tsv = acc_tsv + top_percent_mean(e_svss(dd_mask).^2, 1);
            acc_ts  = acc_ts  + top_percent_mean(e_sms(dd_mask).^2,  1);

            acc_pc = acc_pc + mean(diag_pc.clip_hist(dd_mask));
        end

        floor_prop_clip(ip)   = acc_fc  / mc.Ntrial_theorem;
        floor_prop_noclip(ip) = acc_fnc / mc.Ntrial_theorem;
        floor_nlms(ip)        = acc_fn  / mc.Ntrial_theorem;
        floor_smsign_vss(ip)  = acc_fsv / mc.Ntrial_theorem;
        floor_smsign(ip)      = acc_fs  / mc.Ntrial_theorem;

        tail_prop_clip(ip)   = acc_tc  / mc.Ntrial_theorem;
        tail_prop_noclip(ip) = acc_tnc / mc.Ntrial_theorem;
        tail_nlms(ip)        = acc_tn  / mc.Ntrial_theorem;
        tail_smsign_vss(ip)  = acc_tsv / mc.Ntrial_theorem;
        tail_smsign(ip)      = acc_ts  / mc.Ntrial_theorem;

        pclip_prop(ip) = acc_pc / mc.Ntrial_theorem;
    end

    cliprslt = struct();
    cliprslt.p_list            = p_list;
    cliprslt.floor_prop_clip   = floor_prop_clip;
    cliprslt.floor_prop_noclip = floor_prop_noclip;
    cliprslt.floor_nlms        = floor_nlms;
    cliprslt.floor_smsign_vss  = floor_smsign_vss;
    cliprslt.floor_smsign      = floor_smsign;
    cliprslt.tail_prop_clip    = tail_prop_clip;
    cliprslt.tail_prop_noclip  = tail_prop_noclip;
    cliprslt.tail_nlms         = tail_nlms;
    cliprslt.tail_smsign_vss   = tail_smsign_vss;
    cliprslt.tail_smsign       = tail_smsign;
    cliprslt.pclip_prop        = pclip_prop;

    figure('Name','Appendix: Impulsive stress (SM-sign-NLMS VSS)'); clf;
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    nexttile;
    plot(p_list, floor_prop_clip,   'o-','LineWidth',1.4); hold on;
    plot(p_list, floor_prop_noclip, 's-','LineWidth',1.2);
    plot(p_list, floor_nlms,        'x-','LineWidth',1.2);
    plot(p_list, floor_smsign_vss,  'd-','LineWidth',1.2);
    plot(p_list, floor_smsign,      '^-','LineWidth',1.2);
    grid on;
    xlabel('p_{imp}');
    ylabel('DD self-error floor');
    title('Floor vs impulsive probability');
    legend({'prop clip','prop noclip','NLMS','SM-sign-NLMS VSS','SM-sign-NLMS'}, ...
        'Location','best');

    nexttile;
    plot(p_list, tail_prop_clip,   'o-','LineWidth',1.4); hold on;
    plot(p_list, tail_prop_noclip, 's-','LineWidth',1.2);
    plot(p_list, tail_nlms,        'x-','LineWidth',1.2);
    plot(p_list, tail_smsign_vss,  'd-','LineWidth',1.2);
    plot(p_list, tail_smsign,      '^-','LineWidth',1.2);
    grid on;
    xlabel('p_{imp}');
    ylabel('top-1% mean(e^2)');
    title('Tail-sensitive metric');
    legend({'prop clip','prop noclip','NLMS','SM-sign-NLMS VSS','SM-sign-NLMS'}, ...
        'Location','best');

    nexttile;
    plot(p_list, pclip_prop, 'o-','LineWidth',1.4);
    grid on;
    xlabel('p_{imp}');
    ylabel('p_{clip}');
    title('Clip activity (proposed clipped only)');

    nexttile;
    bar([floor_prop_clip(end), floor_prop_noclip(end), floor_nlms(end), floor_smsign_vss(end), floor_smsign(end)]);
    grid on;
    set(gca,'XTick',1:5, ...
        'XTickLabel',{'prop clip','prop noclip','NLMS','SM-sign-NLMS VSS','SM-sign-NLMS'}, ...
        'XTickLabelRotation',20);
    ylabel('DD self-error floor');
    title(sprintf('Final stress point: p_{imp} = %.3f', p_list(end)));
end

