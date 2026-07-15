% Auto-split from NCKH_v53.m (original line 6597).
% Folder: experiments/theory_legacy

function mu2v = supp_mu2_formula_verify(cfg, vars)
% Verifies Proposition 15: mu_bar^2 = mu_min^2 + mu_min*Dmu + Dmu^2/3

    v   = vars.theorem;
    Tc  = v.Tclr;

    mu_tri = sample_periodic_mu(v.mu_min, v.mu_max, Tc, 1:Tc);
    mu_empirical = mean(mu_tri.^2);
    dmu          = v.mu_max - v.mu_min;
    mu_formula   = v.mu_min^2 + v.mu_min*dmu + dmu^2/3;

    mu2v = struct();
    mu2v.mu_empirical = mu_empirical;
    mu2v.mu_formula   = mu_formula;
    mu2v.rel_error    = abs(mu_empirical - mu_formula) / max(mu_formula, 1e-20);

    % Extended: sweep (mu_min, mu_max) pairs
    mu_min_list = [1e-4, 5e-4, 1e-3, 5e-3];
    mu_max_list = [1e-2, 3e-2, 5e-2, 7e-2, 1e-1];
    err_mat = zeros(numel(mu_min_list), numel(mu_max_list));

    for i = 1:numel(mu_min_list)
        for j = 1:numel(mu_max_list)
            if mu_max_list(j) <= mu_min_list(i), continue; end
            seq    = sample_periodic_mu(mu_min_list(i), mu_max_list(j), Tc, 1:Tc);
            emp    = mean(seq.^2);
            dmu_ij = mu_max_list(j) - mu_min_list(i);
            form   = mu_min_list(i)^2 + mu_min_list(i)*dmu_ij + dmu_ij^2/3;
            err_mat(i,j) = abs(emp - form) / max(form, 1e-20);
        end
    end

    % ---- Figure G2-B ---------------------------------------------------
    figure('Name','G2-B: Proposition 15 — Gain-Energy Formula Verification');
    clf;
    imagesc(1:numel(mu_max_list), 1:numel(mu_min_list), log10(err_mat + 1e-15));
    colorbar;
    set(gca,'XTick',1:numel(mu_max_list),'XTickLabel',arrayfun(@(x)sprintf('%.3f',x),...
        mu_max_list,'UniformOutput',false),'XTickLabelRotation',30);
    set(gca,'YTick',1:numel(mu_min_list),'YTickLabel',arrayfun(@(x)sprintf('%.4f',x),...
        mu_min_list,'UniformOutput',false));
    xlabel('\mu_{max}');
    ylabel('\mu_{min}');
    title({'Proposition 15 formula error  log_{10}(|empirical - formula| / formula)';
           sprintf('Current config: rel. error = %.2e', mu2v.rel_error)});
    set(gcf,'Position',[100 100 520 320]);

    fprintf('[G2-B] Prop 15 formula check: empirical=%.6e, formula=%.6e, rel_err=%.2e\n', ...
        mu_empirical, mu_formula, mu2v.rel_error);
end

% =========================================================================
%  GROUP 3  —  CLR CYCLE CONTRACTION FIGURE (enhanced)
% =========================================================================
