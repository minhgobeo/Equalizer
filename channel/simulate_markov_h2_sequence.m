% Auto-split from NCKH_v53.m (original line 3962).
% Folder: channel
%
% v57 patch: force h2_trace to be a column vector regardless of the orientation
% of mk.h2_states or state_seq. This prevents a horzcat dimension mismatch
% inside channel_out when h2_states is row-shaped on some MATLAB versions.

function [state_seq, h2_trace] = simulate_markov_h2_sequence(N, mk)
    P = mk.P;
    states = mk.h2_states(:).';   % row
    nS = numel(states);
    state_seq = zeros(N,1);
    state_seq(1) = mk.init_state;
    for n=2:N
        p = P(state_seq(n-1),:);
        state_seq(n) = sample_discrete(p, nS);
    end
    % v57: deterministic column output, no MATLAB-version-dependent
    % orientation rules.
    h2_trace = states(state_seq);
    h2_trace = h2_trace(:);
end
