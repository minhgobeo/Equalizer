% Auto-split from NCKH_v53.m (original line 5505).
% Folder: config

function vv = build_internal_case_variant(case_name, vars, cfg, mc, mu_same_floor)

    %#ok<INUSD>
    switch case_name
        case 'theorem'
            vv = vars.theorem;

        case 'noise_aware'
            vv = vars.noise_aware;

        case 'const_global'
            vv = make_constant_gain_version(vars.theorem, 'global');

        case 'const_same_floor'
            vv = make_constant_gain_version(vars.theorem, 'global');
            vv.mu_const = mu_same_floor;

        case 'const_same_energy'
            vv = make_constant_gain_version(vars.theorem, 'same_energy');

        otherwise
            error('Unknown internal case.');
    end
end

