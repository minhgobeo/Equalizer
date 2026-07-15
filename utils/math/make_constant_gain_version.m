% Auto-split from NCKH_v53.m (original line 4140).
% Folder: utils/math

function vv = make_constant_gain_version(v, mode_name)
    vv = v;
    vv.Tclr = 2;
    vv.mu_mode = 'bounded';

    switch lower(mode_name)
        case 'same_floor'
            mu_const = v.mu_min;

        case 'same_energy'
            mu_seq = sample_periodic_mu(v.mu_min, v.mu_max, v.Tclr, 1:2000);
            mu2bar_target = mean(mu_seq.^2);
            mu_const = sqrt(mu2bar_target);

        case 'global'
            if isfield(v, 'mu_const_global')
                mu_const = v.mu_const_global;
            else
                mu_seq = sample_periodic_mu(v.mu_min, v.mu_max, v.Tclr, 1:2000);
                mu_const = mean(mu_seq);
            end

        otherwise
            error('Unknown constant gain version.');
    end

    vv.mu_const = mu_const;
    vv.mu_min   = mu_const;
    vv.mu_max   = mu_const;

    % keep theorem-like thresholds fixed for fair fixed-gain comparison
    if isfield(vv,'use_adaptive_mu')
        vv.use_adaptive_mu = false;
    end
    if isfield(vv,'use_adaptive_tau')
        vv.use_adaptive_tau = false;
    end
    if isfield(vv,'use_adaptive_kappa')
        vv.use_adaptive_kappa = false;
    end

    if isfield(vv,'kind')
        switch lower(mode_name)
            case 'same_floor'
                vv.kind = 'const_same_floor';
            case 'same_energy'
                vv.kind = 'const_same_energy';
            case 'global'
                vv.kind = 'const_global';
        end
    end
end

