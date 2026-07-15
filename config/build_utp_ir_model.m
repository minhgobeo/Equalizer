% Auto-split from NCKH_v53.m (original line 5046).
% Folder: config

function h = build_utp_ir_model(cfg)
% Worst-case UTP cable model (Section 23.5.1.3)
% Propagation: H(f,x) = -j(10) * f(x/10^3)/sqrt(f/10^6)
%                       + 0.70/sqrt(f/10^6) * (x/10^3)/305
%
% Simplified as frequency-dependent attenuation:
%   |H(f)| ≈ exp(-alpha * sqrt(f) * L)
% with alpha derived from Cat-3 100m worst-case parameters.
%
% For baseband PAM-4, we use a 4-tap FIR approximation of the
% resulting impulse response after Nyquist-rate sampling.

    switch lower(cfg.chan_mode)
        case 'baseline_2tap'
            h0 = cfg.h_isi(:);
            % Extend to 4-tap for 802.3 realism
            if numel(h0) < 4
                h = [h0; 0.18; 0.06];
                h = h(1:4);
            else
                h = h0(1:4);
            end
        case 'drift_2tap'
            s_d = cfg.drift_span;
            h = [1.0; 0.50+0.3*s_d; 0.18+0.1*s_d; 0.06];
        case 'markov_2tap'
            h2 = cfg.markov.h2_states(cfg.markov.init_state);
            h = [1.0; h2; 0.18; 0.06];
        otherwise
            h = [1.0; 0.50; 0.18; 0.06];
    end
    h = h / max(abs(h(1)), eps);
end

