% Auto-split from NCKH_v53.m (original line 2156).
% Folder: utils/math

function rslt = t2_fig6_jump_tracking(cfg, v, base, Nt)
    cfg_j = cfg;
    cfg_j.chan_mode = 'baseline_2tap';
    if isfield(cfg_j,'std8023'), cfg_j.std8023.enable = false; end
    cfg_j.SNRdB = 20;
    cfg_j.Nsym = 60000;
    jump_at = 30000;
    win = 8000;

    N = cfg_j.Nsym;
    idx_range = max(1,jump_at-win):min(N, jump_at+win);
    Nw = numel(idx_range);
    blk = 50;
    Nblk = floor(Nw / blk);

    err_prop = zeros(Nblk, 1);
    err_nlms = zeros(Nblk, 1);
    err_svss = zeros(Nblk, 1);
    err_lms  = zeros(Nblk, 1);

    for t = 1:Nt
        rng(14000 + t);
        sym_idx = randi([1 cfg.M], N, 1);
        d = cfg.A(sym_idx).'; d = d(:);

        h_before = cfg_j.h_isi;
        h_after  = [1 0.85];
        r_clean = zeros(N,1);
        for n = 1:N
            if n <= jump_at, h2 = h_before(2); else, h2 = h_after(2); end
            if n==1, r_clean(n)=d(n); else, r_clean(n)=d(n)+h2*d(n-1); end
        end

        rng(14500 + t);
        [r, sigma2] = add_noise_dispatch(r_clean, cfg_j);

        [~,dh1,e1] = deal_recursion_err(r, d, cfg_j, v, @proposed_recursion);
        [~,~,e2] = dfe_nlms_unified_x(r, d, cfg_j, base);
        [~,~,e3] = dfe_smsign_nlms_vss_unified_x(r, d, cfg_j, base, sigma2);
        [~,~,e4] = dfe_lms_unified_x(r, d, cfg_j, base);

        for k = 1:Nblk
            bi = ((k-1)*blk+1) : min(k*blk, Nw);
            gi = idx_range(bi);
            gi = gi(gi <= numel(e1));
            if ~isempty(gi)
                err_prop(k) = err_prop(k) + mean(e1(gi).^2);
                err_nlms(k) = err_nlms(k) + mean(e2(gi).^2);
                err_svss(k) = err_svss(k) + mean(e3(gi).^2);
                err_lms(k)  = err_lms(k)  + mean(e4(gi).^2);
            end
        end
    end
    err_prop = err_prop / Nt;
    err_nlms = err_nlms / Nt;
    err_svss = err_svss / Nt;
    err_lms  = err_lms / Nt;

    nn_blk = (1:Nblk)*blk + idx_range(1) - 1;

    figure('Name','T2-Fig6: Jump tracking recovery'); clf;
    semilogy(nn_blk, err_prop, 'b-', 'LineWidth', 1.8); hold on;
    semilogy(nn_blk, err_lms, '-', 'Color', [0.85 0.33 0.1], 'LineWidth', 1.0);
    semilogy(nn_blk, err_nlms, '-', 'Color', [0.93 0.69 0.13], 'LineWidth', 1.0);
    semilogy(nn_blk, err_svss, 'g-', 'LineWidth', 1.2);
    xline(jump_at, 'k--', 'LineWidth', 1.5);
    grid on; xlabel('n'); ylabel('Block MSE');
    legend({'Proposed','LMS','NLMS','SM-sign-NLMS VSS','Channel jump'}, 'Location','best');
    title('Channel jump recovery: h_2 = 0.50 \rightarrow 0.85');

    rslt.nn = nn_blk;
    rslt.err_prop = err_prop; rslt.err_nlms = err_nlms;
    rslt.err_svss = err_svss; rslt.err_lms = err_lms;
end

