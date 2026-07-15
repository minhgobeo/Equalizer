% Auto-split from NCKH_v53.m (original line 5386).
% Folder: utils/plotting

function plot_practical_receiver_behavior(convrslt, ser_rslt, cfg)
    %#ok<INUSD>
    figure('Name','Practical: Receiver behavior'); clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

    nexttile;
    semilogy(convrslt.E_prop,       'LineWidth',1.5); hold on;
    semilogy(convrslt.E_lms,        'LineWidth',1.2);
    semilogy(convrslt.E_nlms,       'LineWidth',1.2);
    semilogy(convrslt.E_rls,        'LineWidth',1.2);
    semilogy(convrslt.E_smsign_vss, 'LineWidth',1.2);
    semilogy(convrslt.E_smsign,     'LineWidth',1.2);
    grid on;
    xlabel('Iteration (block k)');
    ylabel('Averaged squared error');
    title('(a) Averaged DD self-error');
    legend({'Proposed-practical','LMS','NLMS','RLS','SM-sign-NLMS VSS','SM-sign-NLMS'}, ...
        'Location','best');

    nexttile;
    semilogy(ser_rslt.snr_list, ser_rslt.SER_prop,       'o-','LineWidth',1.5); hold on;
    semilogy(ser_rslt.snr_list, ser_rslt.SER_lms,        'x-','LineWidth',1.2);
    semilogy(ser_rslt.snr_list, ser_rslt.SER_nlms,       's-','LineWidth',1.2);
    semilogy(ser_rslt.snr_list, ser_rslt.SER_rls,        'd-','LineWidth',1.2);
    semilogy(ser_rslt.snr_list, ser_rslt.SER_smsign_vss, 'v-','LineWidth',1.2);
    semilogy(ser_rslt.snr_list, ser_rslt.SER_smsign,     '^-','LineWidth',1.2);
    grid on;
    xlabel('SNR (dB)');
    ylabel('SER');
    title('(b) SER vs SNR');
    legend({'Proposed-practical','LMS','NLMS','RLS','SM-sign-NLMS VSS','SM-sign-NLMS'}, ...
        'Location','best');
end

