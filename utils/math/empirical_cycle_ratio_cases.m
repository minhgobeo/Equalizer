% Auto-split from NCKH_v53.m (original line 6146).
% Folder: utils/math

function obs_ratio = empirical_cycle_ratio_cases(cfg_c, v_theorem, mc)
% Observed cycle-boundary mismatch-decay ratio for
% triangular / same-floor / same-energy schedules

    Tcyc = v_theorem.Tclr;
    Kcyc = 8;
    cfg_run = cfg_c;
    cfg_run.Nsym = cfg_c.trainLen + (Kcyc + 2)*Tcyc;

    cases = {'triangular','same_floor','same_energy'};
    obs_ratio = zeros(numel(cases),1);

    for ic = 1:numel(cases)
        ratio_bank = nan(mc.Ntrial_theorem,1);

        for t = 1:mc.Ntrial_theorem
            rng(33000 + 100*ic + t);

            sym_idx = randi([1 cfg_run.M], cfg_run.Nsym, 1);
            d = cfg_run.A(sym_idx).'; d = d(:);

            [r_clean, ~] = channel_out(d, cfg_run);
            [r, ~] = add_noise_dispatch(r_clean, cfg_run);

            switch cases{ic}
                case 'triangular'
                    vv = v_theorem;

                case 'same_floor'
                     vv = make_constant_gain_version(v_theorem, 'same_floor');

                case 'same_energy'
                    vv = make_constant_gain_version(v_theorem, 'same_energy');

                otherwise
                    error('Unknown cycle-id case.');
            end

            [~,~,~,diag_impl] = proposed_recursion(r, d, cfg_run, vv);
            [~,~,~,diag_pd]   = proposed_recursion_pd(r, d, cfg_run, vv);

            idx_cycle = cfg_run.trainLen + (1:Kcyc)*Tcyc;
            idx_cycle = idx_cycle(idx_cycle <= cfg_run.Nsym);

            ecyc = zeros(numel(idx_cycle),1);
            for k = 1:numel(idx_cycle)
                ii = idx_cycle(k);
                ecyc(k) = sum((diag_impl.theta_hist(:,ii) - diag_pd.theta_hist(:,ii)).^2);
            end

            if numel(ecyc) >= 3
                eps_cyc = 1e-8;
                rr = (ecyc(2:end) + eps_cyc) ./ (ecyc(1:end-1) + eps_cyc);
                rr = rr(isfinite(rr));

                % bỏ cycle đầu để giảm warm-start distortion
                if numel(rr) >= 2
                    rr = rr(2:end);
                end

                if ~isempty(rr)
                    ratio_bank(t) = median(rr);
                end
            end
        end

        obs_ratio(ic) = median(ratio_bank,'omitnan');
    end
end

