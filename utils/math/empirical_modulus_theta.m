% Auto-split from NCKH_v53.m (original line 5831).
% Folder: utils/math

function om = empirical_modulus_theta(theta_path, t_grid, delta)
    om = 0;
    K = numel(t_grid);
    for i = 1:K
        for j = i+1:K
            if abs(t_grid(j) - t_grid(i)) <= delta
                om = max(om, norm(theta_path(:,j) - theta_path(:,i), 2));
            end
        end
    end
end

