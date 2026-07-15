% Auto-split from NCKH_v53.m (original line 11707).
% Folder: core/algorithm6_msb

function p = default_msb_params()
    p.B      = 128;
    p.K      = 8;
    p.T_min  = 64;
    p.delta  = 0.05;
    p.rho    = 0.95;
end


% ============================================================================
% SECTION-C  —  PATCH A : STATE TRACKING DIAGNOSTIC
% ============================================================================

