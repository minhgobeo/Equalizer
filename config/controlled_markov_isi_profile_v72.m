function prof = controlled_markov_isi_profile_v72(varargin)
%CONTROLLED_MARKOV_ISI_PROFILE_V72  Documented Markov-ISI stress profiles.
%
% This helper removes magic numbers such as [0.30 0.50 0.70] from the
% paper-facing controlled Markov-ISI simulations.
%
% The severe profile is a controlled two-tap/partial-response stress model:
%   h(D) = 1 + h2 D
% with h2 centred at 0.5.  The 0.5 centre is anchored to the widely used
% 1+0.5D partial-response / TX-DFE target reported for 112-Gb/s PAM4 SerDes
% transmitter work.  The outer states apply a +/-0.20 stress span around
% that centre, i.e. low/nominal/high postcursor burden.  These states are
% therefore not claimed as measured IEEE 802.3ck channels; they are a
% theory-aligned controlled tracking stress.  Measured/contributed channel
% validation is handled separately by the C2M S-parameter Block B.
%
% The transition matrix is generated from a specified mean dwell length:
%   p_stay = 1 - 1/mean_dwell
% so the default severe profile uses mean_dwell=20 symbols, giving p=0.95.

p = inputParser;
addParameter(p, 'profile', 'severe_partial_response', @ischar);
addParameter(p, 'mean_dwell', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 1));
parse(p, varargin{:});
opt = p.Results;

switch lower(opt.profile)
    case {'severe','severe_partial_response','blocka'}
        centre = 0.50;
        span = 0.20;
        default_dwell = 20;
        label = 'severe partial-response Markov-ISI';
    case {'realistic','mild_partial_response'}
        centre = 0.50;
        span = 0.05;
        default_dwell = 100;
        label = 'mild partial-response Markov-ISI';
    otherwise
        error('Unknown controlled Markov-ISI profile: %s', opt.profile);
end

if isempty(opt.mean_dwell)
    mean_dwell = default_dwell;
else
    mean_dwell = opt.mean_dwell;
end
pstay = 1 - 1/mean_dwell;

prof = struct();
prof.label = label;
prof.model = 'controlled two-tap partial-response Markov-ISI';
prof.h2_center = centre;
prof.h2_span = span;
prof.h2_states = centre + [-span 0 span];
prof.mean_dwell_symbols = mean_dwell;
prof.p_stay = pstay;
prof.P = [pstay, 1-pstay, 0; ...
          (1-pstay)/2, pstay, (1-pstay)/2; ...
          0, 1-pstay, pstay];
prof.init_state = 2;
prof.source_note = ['h2_center=0.5 follows the 1+0.5D partial-response/TX-DFE ' ...
    'target used in 112-Gb/s PAM4 SerDes literature; h2_span is a controlled ' ...
    'low/nominal/high stress span, not a measured 802.3ck channel.'];
prof.transition_note = sprintf(['P is generated from mean_dwell=%.3g symbols ' ...
    'using p_stay=1-1/mean_dwell.'], mean_dwell);
end
