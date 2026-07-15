% Auto-split from NCKH_v53.m (original line 10755).
% Folder: utils/plotting

function print_ber_local(tag, snr_list, BER, err_count, names, bit_floor)
    Nsnr = numel(snr_list);
    Nalg = numel(names);
    fprintf('\n[%s] BER table:\n', tag);
    fprintf('  SNR ');
    for a = 1:Nalg, fprintf('%24s ', names{a}); end
    fprintf('\n');
    for si = 1:Nsnr
        fprintf('  %2d  ', snr_list(si));
        for a = 1:Nalg
            if err_count(si, a) < 0.5
                fprintf('%24s ', sprintf('<%.1e', bit_floor));
            else
                fprintf('%24.3e ', BER(si, a));
            end
        end
        fprintf('\n');
    end
 
    fprintf('\n[%s] BER ratio (baseline / Proposed, >1 means Proposed wins):\n', tag);
    for a = 2:Nalg
        max_ratio = 0;
        for si = 1:Nsnr
            if BER(si,1) > 0 && BER(si,a) > 0
                r = BER(si,a) / BER(si,1);
                if r > max_ratio, max_ratio = r; end
            end
        end
        fprintf('  %-26s  max ratio over SNR sweep: %.2fx\n', names{a}, max_ratio);
    end
 
    fprintf('\n[%s] SNR thresholds:\n', tag);
    fprintf('  %-26s  %8s  %8s  %8s\n', 'Algorithm', '1e-3', '1e-4', '1e-5');
    for a = 1:Nalg
        th = NaN(1,3); tgts = [1e-3 1e-4 1e-5];
        for k = 1:3
            idx = find(BER(:,a) <= tgts(k), 1, 'first');
            if ~isempty(idx), th(k) = snr_list(idx); end
        end
        fprintf('  %-26s  ', names{a});
        for k = 1:3
            if isnan(th(k)), fprintf('%8s  ', 'N/A');
            else,            fprintf('%8d  ', th(k)); end
        end
        fprintf('\n');
    end
end
 
