% Auto-split from NCKH_v53.m (original line 3010).
% Folder: experiments/theory_legacy

function ptf = run_ptf_proxy_visualization(rep, v_theorem)
    alpha_ptf = max(v_theorem.mu_min, 1e-6);
    Kv_ptf    = 400;
    vhat   = ptf_empirical_corrector(rep.dtheta_hist, alpha_ptf, Kv_ptf);
    v_raw  = sum(rep.dtheta_hist.^2, 1);
    v_ptf  = sum(vhat.^2,            1);

    ptf = struct();
    ptf.v_raw = v_raw;
    ptf.v_ptf = v_ptf;

    figure('Name',['Appendix: PTF-inspired proxy (' rep.variant_name ')']); clf;
    tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
    nexttile;
    plot(10*log10(rep.mse_curve + eps)); grid on;
    xlabel('n'); ylabel('10log10(e^2+eps)'); title('Error energy');
    nexttile;
    plot(10*log10(v_raw + eps)); grid on;
    xlabel('n'); ylabel('10log10(||\Delta\theta||^2+eps)'); title('Raw increment energy');
    nexttile;
    plot(10*log10(v_ptf + eps)); grid on;
    xlabel('n'); ylabel('$10\log_{10}(\|\hat{v}_{\alpha}\|_2^2+\epsilon)$','Interpreter','latex'); title('PTF-inspired proxy energy');
end

