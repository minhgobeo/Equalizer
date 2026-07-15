% Auto-split from NCKH_v53.m (original line 9709).
% Folder: utils/plotting

function print_ber_table_local(tag, snr_list, BER, err_count, names, bit_floor)
    fprintf('\n[%s] BER table:\n', tag);
    fprintf('  SNR ');
    for a = 1:numel(names), fprintf('%22s ', names{a}); end
    fprintf('\n');
    for si = 1:numel(snr_list)
        fprintf('  %2d  ', snr_list(si));
        for a = 1:numel(names)
            if err_count(si, a) < 0.5
                fprintf('%22s ', sprintf('<%.1e', bit_floor));
            else
                fprintf('%22.3e ', BER(si, a));
            end
        end
        fprintf('\n');
    end
end
 
