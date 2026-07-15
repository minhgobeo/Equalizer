function fb_vec = get_fb_vector(m, d, d_hat_sym, cfg, L)
% GET_FB_VECTOR  DFE feedback vector for the equalizer regressor.
%
% Extracted verbatim from NCKH_v53_original.m (original line 3999) so that
% the auto-split modules (algorithm5_singlebank.m, algorithm6_msb_v69.m,
% algorithm6_msb_v70_banklocal.m) can run as standalone files.
%
% Returns the L past decisions feeding the DFE section of the regressor:
%   - during training (m <= cfg.trainLen) it returns the true pilot symbols;
%   - during decision-directed operation it returns past slicer decisions
%     drawn from d_hat_sym.
%
% INPUTS
%   m         : symbol index
%   d         : true symbol stream (used in TF mode during training)
%   d_hat_sym : decision stream (slicer outputs); for the bank-local
%               variant pass the bank's own decision history here.
%   cfg       : config struct; cfg.mode in {'TF','BLIND'}, cfg.trainLen
%   L         : DFE length
%
% OUTPUT
%   fb_vec    : L x 1 feedback vector

    fb_vec = zeros(L,1);
    for ell = 1:L
        idx = m - ell;
        if idx < 1 || idx > numel(d_hat_sym)
            fb_vec(ell) = 0;
            continue;
        end
        switch upper(cfg.mode)
            case 'TF'
                if m <= cfg.trainLen
                    fb_vec(ell) = d(idx);
                else
                    fb_vec(ell) = d_hat_sym(idx);
                end
            case 'BLIND'
                fb_vec(ell) = d_hat_sym(idx);
            otherwise
                error('get_fb_vector:mode', 'Unknown cfg.mode: %s', cfg.mode);
        end
    end
end
