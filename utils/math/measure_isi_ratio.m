% Auto-split from NCKH_v53.m (original line 5177).
% Folder: utils/math

function isi_ratio = measure_isi_ratio(h)
% Measure ISI ratio per 802.3 Section 23.6.5:
% ISI = sum(|postcursors|) / |main cursor|
% Must be < 9% for compliance.
    if numel(h) < 2
        isi_ratio = 0;
        return;
    end
    [~, main_idx] = max(abs(h));
    main_val = abs(h(main_idx));
    postcursor_sum = sum(abs(h)) - main_val;
    isi_ratio = postcursor_sum / max(main_val, eps);
end



%% ========================================================================
% 5) NEW FUNCTION: load_external_impulse_response(...)
%% ========================================================================

