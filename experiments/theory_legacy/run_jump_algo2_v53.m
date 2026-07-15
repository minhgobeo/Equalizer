% Auto-split from NCKH_v53.m (original line 7650).
% Folder: experiments/theory_legacy

function pkg = run_jump_algo2_v53(cfg, vars, base, mc)
% Algorithm 2 implemented honestly as "mu-boost version of theorem-core".
% Pre-jump, Algorithm 2 has slightly higher floor (cost of faster step).
% Post-jump, Algorithm 2 recovers faster than core and baselines.

    % ---- configuration (matches paper's Fig T2-7) ------------------------
    cfg_j = cfg;
    cfg_j.chan_mode = 'baseline_2tap';
    if isfield(cfg_j,'std8023'), cfg_j.std8023.enable = false; end
    cfg_j.SNRdB = 20;
    cfg_j.Nsym  = 60000;

    jump_at  = 30000;
    win_pre  = 8000;
    win_post = 15000;
    idx_range = max(1, jump_at - win_pre) : min(cfg_j.Nsym, jump_at + win_post);
    Nw   = numel(idx_range);
    blk  = 50;
    Nblk = floor(Nw / blk);

    Nt = max(mc.Ntrial_ser, 20);

    % ---- variants -------------------------------------------------------
    v_core  = vars.theorem;                  % UNCHANGED - matches paper's
                                             % Fig T2-7 pre-jump MSE 0.07
    v_algo2 = vars.theorem;                  % Algorithm 2 = theorem with
                                             % larger gain regime
    v_algo2.mu_max = v_core.mu_max * 2.5;
    v_algo2.mu_min = v_core.mu_min * 2.5;
    v_algo2.mu_const_global = ...
        mean(sample_periodic_mu(v_algo2.mu_min, v_algo2.mu_max, ...
                                 v_algo2.Tclr, 1:2000));

    Nalg = 5;
    err = zeros(Nblk, Nalg);

    fprintf('[jump_algo2_v53] running %d trials...\n', Nt);
    for t = 1:Nt
        rng(14000 + t);
        sym_idx = randi([1 cfg.M], cfg_j.Nsym, 1);
        d = cfg.A(sym_idx).'; d = d(:);

        h_before = cfg_j.h_isi;
        h_after  = [1 0.85];
        r_clean = zeros(cfg_j.Nsym, 1);
        for n = 1:cfg_j.Nsym
            h2 = h_before(2) * (n <= jump_at) + h_after(2) * (n > jump_at);
            if n==1, r_clean(n) = d(n);
            else,    r_clean(n) = d(n) + h2 * d(n-1);
            end
        end

        rng(14500 + t);
        [r, sigma2] = add_noise_dispatch(r_clean, cfg_j);
        % *** NO AGC *** (matches original t2_fig6_jump_tracking)

        [~, ~, e_core ] = deal_recursion_err(r, d, cfg_j, v_core,  @proposed_recursion);
        [~, ~, e_algo2] = deal_recursion_err(r, d, cfg_j, v_algo2, @proposed_recursion);
        [~, ~, e_nlms]  = dfe_nlms_unified_x(r, d, cfg_j, base);
        [~, ~, e_lms]   = dfe_lms_unified_x (r, d, cfg_j, base);
        [~, ~, e_svss]  = dfe_smsign_nlms_vss_unified_x(r, d, cfg_j, base, sigma2);

        for k = 1:Nblk
            bi = ((k-1)*blk + 1) : min(k*blk, Nw);
            gi = idx_range(bi);
            gi = gi(gi <= numel(e_core));
            if ~isempty(gi)
                err(k,1) = err(k,1) + mean(e_algo2(gi).^2);
                err(k,2) = err(k,2) + mean(e_core (gi).^2);
                err(k,3) = err(k,3) + mean(e_nlms (gi).^2);
                err(k,4) = err(k,4) + mean(e_lms  (gi).^2);
                err(k,5) = err(k,5) + mean(e_svss (gi).^2);
            end
        end
        if mod(t,5)==0, fprintf('  [jump_algo2_v53] trial %d/%d\n', t, Nt); end
    end
    err = err / Nt;

    nn_blk = (1:Nblk)*blk + idx_range(1) - 1;

    % ---- plot (log scale for clarity) -----------------------------------
    figure('Name','T2-Fig7 (v53): Channel jump + Algorithm 2'); clf;
    semilogy(nn_blk, err(:,1), '-',  'Color',[0 0.45 0.74], 'LineWidth', 2.0); hold on;
    semilogy(nn_blk, err(:,2), '--', 'Color',[0 0.45 0.74], 'LineWidth', 1.2);
    semilogy(nn_blk, err(:,3), '-',  'Color',[0.93 0.69 0.13], 'LineWidth', 1.4);
    semilogy(nn_blk, err(:,4), '-',  'Color',[0.85 0.33 0.10], 'LineWidth', 1.2);
    semilogy(nn_blk, err(:,5), '-',  'Color',[0.47 0.67 0.19], 'LineWidth', 1.4);
    xline(jump_at, 'k--', 'LineWidth', 1.5);
    grid on; xlabel('n'); ylabel('Block MSE (log scale)');
    legend({'Proposed + Algorithm 2 (mu-boosted)', 'Proposed (theorem-core)', ...
            'NLMS','LMS','SM-sign-NLMS VSS','Channel jump'}, ...
           'Location','southeast');
    title('Channel jump (h_2 = 0.50 \rightarrow 0.85) : Algorithm 2 recovers faster');

    % ---- split pre/post metrics -----------------------------------------
    pre_mask  = (nn_blk <= jump_at - 200);
    post_mask = (nn_blk > jump_at + 1500) & (nn_blk < jump_at + 8000);
    names = {'Proposed-Algo2','Proposed-core','NLMS','LMS','SM-sign-VSS'};

    fprintf('\n[jump_algo2_v53] Pre-jump / post-jump (recovered) MSE:\n');
    fprintf('  %-18s %12s %12s %10s\n', 'Algorithm', 'Pre-jump', 'Post-jump', 'Ratio');
    for a = 1:Nalg
        pre_val  = mean(err(pre_mask , a));
        post_val = mean(err(post_mask, a));
        fprintf('  %-18s %12.4e %12.4e %10.2f\n', ...
                names{a}, pre_val, post_val, post_val/max(pre_val,eps));
    end

    pkg.nn_blk = nn_blk;
    pkg.err    = err;
    pkg.names  = names;
    pkg.v_core = v_core;
    pkg.v_algo2 = v_algo2;
    pkg.jump_at = jump_at;
end


% ============================================================================
% SECTION-C  —  PATCH 2 v53 : CLR DECAY-RATE DISPLAY
% ============================================================================
%
%  Strategy: keep the original convergent channel (baseline_2tap h=[1 0.5]),
%  run the identical cycle-boundary test as t2_fig4_clr_vs_constant, but
%  explicitly fit and display the log-linear decay rates.  Supplement already
%  showed CLR=0.188 vs same-floor=-0.395 vs same-energy=0.022 on this channel,
%  so the 8.5x CLR-over-same-energy speedup is real; we just need to surface
%  the numbers clearly.
% ----------------------------------------------------------------------------

