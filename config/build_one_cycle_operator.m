% Auto-split from NCKH_v53.m (original line 6135).
% Folder: config

function Phi = build_one_cycle_operator(Jhat, mu_vec)
% Build Phi_T = prod_i (I - mu_i Jhat)

    p = size(Jhat,1);
    Phi = eye(p);

    for i = 1:numel(mu_vec)
        Phi = (eye(p) - mu_vec(i)*Jhat) * Phi;
    end
end

