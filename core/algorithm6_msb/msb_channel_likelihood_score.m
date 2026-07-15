% Auto-split from NCKH_v53.m (original line 12444).
% Folder: core/algorithm6_msb

function score_s = msb_channel_likelihood_score(r, d, d_hat_sym, d_dec_s, cfg, m, h2_states)
% Channel-likelihood score for Markov 2-tap channel:
%   r(m) ≈ d(m) + h2_s*d(m-1) + noise
%
% Training:
%   use true d(m), d(m-1)
% DD:
%   use candidate d_dec_s for current symbol and shared previous decision.
%
% Returns Sx1 score vector. Lower is better.

    S = numel(h2_states);
    score_s = inf(S,1);

    if m < 2 || m > numel(r)
        return;
    end

    if m <= cfg.trainLen && m <= numel(d)
        d_cur_ref  = d(m);
        d_prev_ref = d(m-1);

        for s = 1:S
            pred = d_cur_ref + h2_states(s) * d_prev_ref;
            score_s(s) = (r(m) - pred)^2;
        end
    else
        % DD phase. Use shared previous decision and per-bank current candidate.
        if (m-1) < 1 || (m-1) > numel(d_hat_sym)
            return;
        end
        d_prev_hat = d_hat_sym(m-1);

        % If previous decision not available, use zero as neutral fallback.
        if d_prev_hat == 0
            d_prev_hat = 0;
        end

        for s = 1:S
            pred = d_dec_s(s) + h2_states(s) * d_prev_hat;
            score_s(s) = (r(m) - pred)^2;
        end
    end
end


