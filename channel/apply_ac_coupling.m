% Auto-split from NCKH_v53.m (original line 5161).
% Folder: channel

function y = apply_ac_coupling(x, fc, baud)
% First-order AC-coupling high-pass filter.
% Removes DC wander; models transformer coupling in 802.3.
    Ts = 1 / baud;
    rc = 1 / (2*pi*fc);
    a  = rc / (rc + Ts);
    y  = zeros(size(x));
    x_prev = 0;
    y_prev = 0;
    for n = 1:numel(x)
        y(n) = a * (y_prev + x(n) - x_prev);
        x_prev = x(n);
        y_prev = y(n);
    end
end

