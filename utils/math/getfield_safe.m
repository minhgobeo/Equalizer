% Auto-split from NCKH_v53.m (original line 4125).
% Folder: utils/math

function out = getfield_safe(s, fn, defaultVal)
    if isfield(s, fn), out = s.(fn); else, out = defaultVal; end
end

