% Auto-split from NCKH_v53.m (original line 4073).
% Folder: utils/math

function g = rc_pulse(alpha, sps, spanUI)
    t = (-spanUI/2 : 1/sps : spanUI/2).';
    g = zeros(size(t));
    for k = 1:numel(t)
        tau = t(k);
        if abs(1 - (2*alpha*tau)^2) < 1e-10
            g(k) = pi/4 * sinc(1/(2*alpha));
        else
            g(k) = sinc(tau) * cos(pi*alpha*tau) / (1 - (2*alpha*tau)^2);
        end
    end
    g = g / max(sum(abs(g)), eps);
end

