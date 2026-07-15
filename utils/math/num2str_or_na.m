% Auto-split from NCKH_v53.m (original line 9942).
% Folder: utils/math

function s = num2str_or_na(x)
    if isnan(x), s = 'N/A'; else, s = sprintf('%d', x); end
end

