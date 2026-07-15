% Auto-split from NCKH_v53.m (original line 8661).
% Folder: experiments/paper_main

function pkg = run_ber_prefec_v58(cfg, vars, base, mc)
    cfg_p = cfg;
    cfg_p.chan_mode = 'markov_2tap';
    cfg_p.markov.h2_states = [0.45 0.50 0.55];
    cfg_p.markov.P = [0.99  0.01  0.00; ...
                      0.005 0.99  0.005; ...
                      0.00  0.01  0.99];
    cfg_p.markov.init_state = 2;
    cfg_p.markov.fixed_state = 2;
 
    cfg_p.Nf = 11; cfg_p.Nb = 3; cfg_p.D = 5;
    cfg_p.trainLen = 10000;
    cfg_p.Nsym = 80000;
    if isfield(cfg_p,'std8023'), cfg_p.std8023.enable = false; end
 
    fprintf('[ber_prefec_v58] PAM4 high-order Nf=%d Nb=%d on realistic Markov\n', ...
            cfg_p.Nf, cfg_p.Nb);
 
    [pkg, names, BER, snr_list, bit_floor] = ber_sweep_standard(cfg_p, vars, base, mc, 'v58');
 
    % plot ----------------------------------------------------------------
    figure('Name','BER-Fig (v58): high-order equalizer baseline'); clf;
    tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    plot_ber_curves(snr_list, max(BER, bit_floor), names, bit_floor, ...
                    sprintf('PAM4 realistic Markov, Nf=%d Nb=%d', cfg_p.Nf, cfg_p.Nb), 'Standard');
end
 
 
% ============================================================================
% SECTION-C  —  PATCH B : MARKOV-STATE-BANK EQUALIZER (v59 - NEW CONTRIBUTION)
% ============================================================================
 
