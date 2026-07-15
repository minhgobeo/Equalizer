% Auto-split from NCKH_v53.m (original line 3382).
% Folder: core/proposed_legacy

function mu = get_step_size(n, v)
    switch lower(v.mu_mode)
        case 'bounded'
            mu = smith_tri_clr(n-1, v.mu_min, v.mu_max, v.Tclr);

        case 'diminishing'
            mu = v.mu0 / (1 + v.mu_decay * (n-1));

        case 'constant'
            mu = v.mu_const;

        otherwise
            error('Unknown v.mu_mode: %s', v.mu_mode);
    end
end

