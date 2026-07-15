% Auto-split from NCKH_v53.m (original line 5080).
% Folder: channel

function d_out = apply_tx_template(d, s)
% Apply transmit pulse shaping per Table 23-4.
% Models finite rise-time and bounded overshoot.
    Tb = 1/s.baud;
    t_rise = s.tx_risetime_ns * 1e-9;
    % Number of samples for the rise-time filter
    Nfilt = max(3, round(t_rise / Tb));
    % Simple raised-cosine-like FIR for rise-time
    k = (0:Nfilt-1).' / max(Nfilt-1, 1);
    hfilt = 0.5 * (1 - cos(pi * k));
    hfilt = hfilt / sum(hfilt);
    d_out = conv(d, hfilt, 'same');
end

