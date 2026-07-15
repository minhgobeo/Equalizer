% Auto-split from NCKH_v53.m (original line 2819).
% Folder: experiments/theory_legacy

function rest = run_restoration_validation(cfg, vars, mc)

    fprintf('\n=== Restoration-after-jump test ===\n');

    cfg_jump = cfg;
    cfg_jump.chan_mode = 'baseline_2tap';

    Nsweep_trials = mc.Ntrial_jump;
    jump_idx = round(cfg_jump.Nsym * 0.55);

    cases = {'theorem','noise_aware','const_global','const_same_floor','const_same_energy'};
    Nc = numel(cases);

    mu_same_floor = calibrate_const_same_floor_mu(cfg, vars.theorem, mc);

    smooth_len = 25;
    block_len  = 10;
    Kpost_raw  = cfg.jump.win_post;
    Kpost_plot = floor(Kpost_raw / block_len);

    mean_post_curve = zeros(Kpost_plot, Nc);
    std_post_curve  = zeros(Kpost_plot, Nc);

    overshoot_area  = zeros(Nc,1);
    recovery_time   = zeros(Nc,1);
    post_jump_floor = zeros(Nc,1);

    for ic = 1:Nc
        post_bank  = zeros(Kpost_plot, Nsweep_trials);
        area_bank  = zeros(Nsweep_trials,1);
        floor_bank = zeros(Nsweep_trials,1);
        trec_bank  = zeros(Nsweep_trials,1);

        for t = 1:Nsweep_trials
            rng(9000 + 100*ic + t);

            sym_idx = randi([1 cfg_jump.M], cfg_jump.Nsym, 1);
            d = cfg_jump.A(sym_idx).'; d = d(:);

            cfg1 = cfg_jump; cfg1.h_isi = cfg.jump.h_before;
            cfg2 = cfg_jump; cfg2.h_isi = cfg.jump.h_after;

            [r1_clean, ~] = channel_out(d(1:jump_idx), cfg1);
            [r2_clean, ~] = channel_out(d(jump_idx+1:end), cfg2);
            r_clean = [r1_clean; r2_clean];

            [r, ~] = add_noise_dispatch(r_clean, cfg_jump);

            vv = build_internal_case_variant(cases{ic}, vars, cfg_jump, mc, mu_same_floor);
            [~,~,e_samp] = proposed_recursion(r, d, cfg_jump, vv);

            e2 = e_samp(:).^2;

            win_pre  = max(1, jump_idx-cfg.jump.win_pre):jump_idx-1;
            win_post = jump_idx+1:min(cfg_jump.Nsym, jump_idx+cfg.jump.win_post);

            ref_level = mean(e2(win_pre));

            e2_post = e2(win_post);
            if isempty(e2_post)
                e2_post = ref_level * ones(Kpost_raw,1);
            end
            if numel(e2_post) < Kpost_raw
                e2_post = [e2_post; repmat(e2_post(end), Kpost_raw-numel(e2_post), 1)];
            end
            e2_post = e2_post(1:Kpost_raw);

            e2_post_sm = movmean(e2_post, smooth_len);
            e2_post_blk = block_mean_local(e2_post_sm, block_len);

            if numel(e2_post_blk) < Kpost_plot
                e2_post_blk = [e2_post_blk; repmat(e2_post_blk(end), Kpost_plot-numel(e2_post_blk), 1)];
            end
            e2_post_blk = e2_post_blk(1:Kpost_plot);

            post_bank(:,t) = e2_post_blk;

            area_bank(t) = sum(max(e2_post_blk - ref_level, 0));

            tailL = max(5, round(0.20 * numel(e2_post_blk)));
            floor_bank(t) = mean(e2_post_blk(end-tailL+1:end));

            trec_bank(t) = compute_recovery_time_smoothed( ...
                e2_post_blk, ref_level, cfg.jump.recovery_eps, cfg.jump.recovery_hold, block_len);
        end

        mean_post_curve(:,ic) = mean(post_bank, 2);
        std_post_curve(:,ic)  = std(post_bank, 0, 2);

        overshoot_area(ic)  = mean(area_bank);
        recovery_time(ic)   = mean(trec_bank);
        post_jump_floor(ic) = mean(floor_bank);
    end

    rest = struct();
    rest.cases           = cases;
    rest.mean_post_curve = mean_post_curve;
    rest.std_post_curve  = std_post_curve;
    rest.overshoot_area  = overshoot_area;
    rest.recovery_time   = recovery_time;
    rest.post_jump_floor = post_jump_floor;

    figure('Name','Fig9: Internal restoration after abrupt channel jump'); clf;
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

    nexttile([1 2]);
    hold on;
    cc = lines(Nc);
    for ic = 1:Nc
        x = (1:Kpost_plot) * block_len;
        mu = mean_post_curve(:,ic);
        sd = std_post_curve(:,ic);

        fill([x fliplr(x)], [(mu-sd)' fliplr((mu+sd)')], cc(ic,:), ...
            'FaceAlpha',0.10, 'EdgeColor','none', 'HandleVisibility','off');
        plot(x, mu, 'LineWidth',1.4, 'Color',cc(ic,:), 'DisplayName',cases{ic});
    end
    grid on;
    xlabel('samples after jump');
    ylabel('smoothed mean post-jump e^2');
    title('(a) Mean transient after jump');
    legend('Location','best');

    nexttile;
    bar(overshoot_area); grid on;
    set(gca,'XTick',1:Nc,'XTickLabel',cases,'XTickLabelRotation',20);
    ylabel('overshoot area');
    title('(b) Overshoot');

    nexttile;
    yyaxis left
    bar(recovery_time); grid on;
    ylabel('recovery time');
    yyaxis right
    plot(1:Nc, post_jump_floor, 'o-','LineWidth',1.2);
    ylabel('post-jump floor');
    set(gca,'XTick',1:Nc,'XTickLabel',cases,'XTickLabelRotation',20);
    title('(c) Recovery time / post-jump floor');

    disp(table(cases(:), overshoot_area, recovery_time, post_jump_floor, ...
        'VariableNames', {'Case','OvershootArea','RecoveryTime','PostJumpFloor'}));
end

