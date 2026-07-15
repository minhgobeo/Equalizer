% Auto-split from NCKH_v53.m (original line 922).
% Folder: experiments/supplement_legacy

function floor_rslt = run_floor_summary_package(theorem_rslt)

    eps0 = 1e-12;

    xB = log10(max(theorem_rslt.bias.dd_bias_proxy(:), eps0));
    yB = log10(max(theorem_rslt.bias.param_floor(:),   eps0));

    xD = log10(max(theorem_rslt.drift.drift_proxy(:),  eps0));
    yD = log10(max(theorem_rslt.drift.param_floor(:),  eps0));

    xM = log10(max(theorem_rslt.mu2.mu2bar(:),         eps0));
    yM = log10(max(theorem_rslt.mu2.param_floor(:),    eps0));

    beta_B = local_std_beta(xB, yB);
    beta_D = local_std_beta(xD, yD);
    beta_M = local_std_beta(xM, yM);

    beta_abs = abs([beta_B; beta_D; beta_M]);

    floor_rslt = struct();
    floor_rslt.beta     = [beta_B; beta_D; beta_M];
    floor_rslt.beta_abs = beta_abs;

    figure('Name','Fig7: Burden summary'); clf;
    bar(beta_abs);
    set(gca,'XTick',1:3,'XTickLabel',{'DD-bias','Drift','\mu^2-energy'});
    grid on;
    ylabel('Standardized sensitivity magnitude');
    title('Tracking-burden summary');

    fprintf('\n=== Tracking-floor summary ===\n');
    disp(table([beta_B; beta_D; beta_M], beta_abs, ...
        'VariableNames', {'beta','absBeta'}, ...
        'RowNames', {'DD_bias','Drift','mu2_energy'}));
end

