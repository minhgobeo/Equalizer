% Auto-split from NCKH_v53.m (original line 4129).
% Folder: channel

function dd = channel_drift_proxy_from_state(ch_state)
    if isfield(ch_state,'h') && ~isempty(ch_state.h)
        dh = diff(ch_state.h,1,1);
        dd = mean(sqrt(sum(dh.^2,2)));
    elseif isfield(ch_state,'h2') && ~isempty(ch_state.h2)
        dd = mean(abs(diff(ch_state.h2)));
    else
        dd = 0;
    end
end

