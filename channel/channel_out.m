% Auto-split from NCKH_v53.m (original line 3902).
% Folder: channel

function [r_clean, ch_state] = channel_out(d, cfg)
    if isfield(cfg,'std8023') && isfield(cfg.std8023,'enable') && cfg.std8023.enable
        [r_clean, ch_state] = channel_out_std8023_like(d, cfg);
        return;
    end
    N = numel(d);
    ch_state = struct();
    ch_state.h = []; ch_state.h2 = zeros(N,1); ch_state.state = ones(N,1);
    ch_state.dist_state = ones(N,1); ch_state.delay_state = ones(N,1);

    switch cfg.chan_mode
        case 'baseline_2tap'
            h = cfg.h_isi(:);
            r_clean = filter(h,1,d);
            ch_state.h = repmat(h(:).', N, 1);
            if numel(h)>=2, ch_state.h2(:)=h(2); end

        case 'drift_2tap'
            h0 = cfg.h_isi(2);
            switch lower(cfg.drift_shape)
                case 'linear'
                    drift = linspace(-cfg.drift_span, cfg.drift_span, N).';
                case 'sin'
                    drift = cfg.drift_span * sin(2*pi*(0:N-1)'/N);
                otherwise
                    error('Unknown cfg.drift_shape');
            end
            h2_trace = h0 + drift;
            r_clean = zeros(N,1);
            for n=1:N
                if n==1, r_clean(n)=d(n); else, r_clean(n)=d(n)+h2_trace(n)*d(n-1); end
            end
            ch_state.h2 = h2_trace;
            ch_state.h = [ones(N,1), h2_trace];

        case 'markov_2tap'
            [state_seq, h2_trace] = simulate_markov_h2_sequence(N, cfg.markov);
            r_clean = zeros(N,1);
            for n=1:N
                if n==1, r_clean(n)=d(n); else, r_clean(n)=d(n)+h2_trace(n)*d(n-1); end
            end
            ch_state.state = state_seq;
            ch_state.h2 = h2_trace;
            ch_state.h  = [ones(N,1), h2_trace];

        case 'markov_2chain_2tap'
            % Chain 1: Markov channel/plant mode. Chain 2: independent
            % disturbance/delay mode, inspired by two-chain MJS examples.
            [state_seq, h2_trace] = simulate_markov_h2_sequence(N, cfg.markov);
            [dist_seq, ~] = simulate_markov_h2_sequence(N, cfg.markov2);
            delay_vals = ones(1, numel(cfg.markov2.h2_states));
            if isfield(cfg.markov2, 'delay_states')
                delay_vals = cfg.markov2.delay_states(:).';
            end
            r_clean = zeros(N,1);
            for n=1:N
                q = max(1, min(numel(delay_vals), dist_seq(n)));
                dk = max(1, round(delay_vals(q)));
                if n <= dk
                    r_clean(n)=d(n);
                else
                    r_clean(n)=d(n)+h2_trace(n)*d(n-dk);
                end
            end
            ch_state.state = state_seq;
            ch_state.h2 = h2_trace;
            ch_state.h  = [ones(N,1), h2_trace];
            ch_state.dist_state = dist_seq;
            ch_state.delay_state = delay_vals(dist_seq(:)).';
            ch_state.delay_state = ch_state.delay_state(:);

        case 'frozen_markov_state'
            s = cfg.markov.fixed_state;
            h2 = cfg.markov.h2_states(s);
            r_clean = zeros(N,1);
            for n=1:N
                if n==1, r_clean(n)=d(n); else, r_clean(n)=d(n)+h2*d(n-1); end
            end
            ch_state.state = s*ones(N,1);
            ch_state.h2 = h2*ones(N,1);
            ch_state.h  = [ones(N,1), h2*ones(N,1)];

        otherwise
            error('Unknown cfg.chan_mode');
    end
end

