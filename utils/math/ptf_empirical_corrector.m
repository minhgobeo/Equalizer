% Auto-split from NCKH_v53.m (original line 4097).
% Folder: utils/math

function vhat = ptf_empirical_corrector(dtheta_hist, alpha, Kv)
    [P,N] = size(dtheta_hist);
    vhat = zeros(P,N);
    rho = max(0, 1 - alpha);
    for n = 1:N
        acc = zeros(P,1);
        w = 1.0;
        for k = 0:min(Kv-1, N-n)
            acc = acc + w * dtheta_hist(:, n+k);
            w = w * rho;
        end
        vhat(:,n) = acc;
    end
end

