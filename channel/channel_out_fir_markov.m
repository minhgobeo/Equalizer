function [r_clean, ch_state] = channel_out_fir_markov(d, h_bank, markov)
%CHANNEL_OUT_FIR_MARKOV  Symbol-rate FIR channel with Markov state switching.
%
% h_bank is a cell array of causal FIR taps, one per state. The channel
% state can remain fixed by setting markov.fixed_state, or switch according
% to markov.P using the same convention as simulate_markov_h2_sequence.

N = numel(d);
S = numel(h_bank);
if S < 1
    error('channel_out_fir_markov:emptyBank', 'h_bank must contain taps.');
end

if isfield(markov, 'fixed_state') && ~isempty(markov.fixed_state)
    state_seq = markov.fixed_state * ones(N,1);
else
    tmp = markov;
    tmp.h2_states = 1:S;
    [state_seq, ~] = simulate_markov_h2_sequence(N, tmp);
end

maxL = 0;
for s = 1:S
    h_bank{s} = h_bank{s}(:);
    maxL = max(maxL, numel(h_bank{s}));
end

r_clean = zeros(N,1);
d = d(:);
for n = 1:N
    s = state_seq(n);
    h = h_bank{s};
    acc = 0;
    for k = 1:numel(h)
        m = n - k + 1;
        if m >= 1
            acc = acc + h(k) * d(m);
        end
    end
    r_clean(n) = acc;
end

H = zeros(N, maxL);
for n = 1:N
    h = h_bank{state_seq(n)};
    H(n,1:numel(h)) = h(:).';
end

ch_state = struct();
ch_state.state = state_seq;
ch_state.h = H;
ch_state.h2 = H(:, min(2,maxL));
ch_state.h_bank = h_bank;
end
