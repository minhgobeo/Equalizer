% Auto-split from NCKH_v53.m (original line 9727).
% Folder: utils/plotting

function print_thresholds_local(tag, snr_list, BER, names)
    fprintf('\n[%s] SNR thresholds:\n', tag);
    fprintf('  %-30s  %8s  %8s  %8s\n', 'Algorithm', '1e-3', '1e-4', '1e-5');
    for a = 1:numel(names)
        th = NaN(1,3); tgts = [1e-3 1e-4 1e-5];
        for k = 1:3
            idx = find(BER(:,a) <= tgts(k), 1, 'first');
            if ~isempty(idx), th(k) = snr_list(idx); end
        end
        fprintf('  %-30s  ', names{a});
        for k = 1:3
            if isnan(th(k)), fprintf('%8s  ', 'N/A');
            else,            fprintf('%8d  ', th(k));
            end
        end
        fprintf('\n');
    end
end
 
