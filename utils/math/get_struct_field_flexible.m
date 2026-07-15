% Auto-split from NCKH_v53.m (original line 5671).
% Folder: utils/math

function val = get_struct_field_flexible(S, candidates)
    val = NaN;
    for k = 1:numel(candidates)
        if isfield(S, candidates{k})
            val = S.(candidates{k});
            return;
        end
    end
end
  
