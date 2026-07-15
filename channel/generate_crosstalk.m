% Auto-split from NCKH_v53.m (original line 5108).
% Folder: channel

function xt = generate_crosstalk(d, cfg)
% Generate crosstalk interference per 802.3 Section 23.5.1.3.
%
% MDFEXT (Multiple Disturber Far-End Crosstalk):
%   Peak ≤ 87 mVp for worst-case 100m Cat-3 cable.
%
% Model: sum of delayed, filtered copies of independent data streams
% from adjacent pairs (aggressors).

    s   = cfg.std8023;
    N   = numel(d);
    xt  = zeros(N, 1);

    switch lower(s.xtalk_mode)
        case 'simple'
            % Legacy simple crosstalk
            d2  = d(randperm(N));
            hxt = s.xtalk_scale * [0.0; 1.0; -0.5; 0.2];
            xt  = conv(circshift(d2, s.xtalk_delay), hxt, 'same');

        case {'mdfext','fext'}
            % MDFEXT model: N_agg independent aggressor streams
            % Each scaled by MDFEXT_peak / (signal_peak * sqrt(N_agg))
            Nagg = s.num_xtalk_aggressors;
            sig_peak = max(abs(cfg.A));  % PAM-4 peak level
            fext_scale = (s.mdfext_peak_mV * 1e-3) / (sig_peak * sqrt(max(Nagg,1)));

            for ia = 1:Nagg
                d_agg = cfg.A(randi([1 cfg.M], N, 1)).';
                d_agg = d_agg(:);
                % Each aggressor has a different delay and mild filtering
                delay_ia = randi([1 4]);
                h_agg = fext_scale * [0; 1; -0.3; 0.1] * (0.8 + 0.4*rand);
                xt = xt + conv(circshift(d_agg, delay_ia), h_agg, 'same');
            end

        case 'next'
            % Near-end crosstalk (stronger, shorter delay)
            Nagg = s.num_xtalk_aggressors;
            sig_peak = max(abs(cfg.A));
            next_scale = 2 * (s.mdfext_peak_mV * 1e-3) / (sig_peak * sqrt(max(Nagg,1)));
            for ia = 1:Nagg
                d_agg = cfg.A(randi([1 cfg.M], N, 1)).';
                d_agg = d_agg(:);
                h_agg = next_scale * [1; -0.5; 0.1];
                xt = xt + conv(d_agg, h_agg, 'same');
            end

        otherwise
            % Default: no crosstalk
    end
end

