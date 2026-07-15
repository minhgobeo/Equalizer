% Auto-split from NCKH_v53.m (original line 5197).
% Folder: channel

function h = load_external_impulse_response(ir_file, ir_norm_main)
    x = readmatrix(ir_file);
    x = x(:);
    x = x(~isnan(x));

    if isempty(x)
        error('Impulse response file is empty or unreadable.');
    end

    h = x;
    if ir_norm_main
        [~, idx] = max(abs(h));
        if abs(h(idx)) > 0
            h = h / h(idx);
        end
    end
end



%% ========================================================================
% 6) NEW FUNCTION: add_noise_dispatch(...)
%
% Replace call sites like:
%   [r, sigma2] = add_awgn_measured(r_clean, cfg.SNRdB);
% with:
%   [r, sigma2] = add_noise_dispatch(r_clean, cfg);
%% ========================================================================

