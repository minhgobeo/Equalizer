% Auto-split from NCKH_v53.m (original line 9617).
% Folder: core/algorithm6_msb

function [d_hat_sym, state_est, theta_banks] = proposed_recursion_msbank(r, d, cfg, v)
% MSBank-EQ: parallel equalizer banks, one per Markov state.
 
    N = numel(r);
    K = cfg.Nf; L = cfg.Nb; D = cfg.D;
    main_idx = v.main_idx;
    S = numel(cfg.markov.h2_states);
 
    theta_init = zeros(K+L, 1);
    theta_init(main_idx) = v.w_main_value;
    theta_init = Pi_H(theta_init, v, K);
    theta_banks = repmat(theta_init, 1, S);
 
    r_buf = zeros(K, 1);
    d_hat_sym = zeros(numel(d), 1);
    state_est = ones(N, 1);
 
    s_hat = round(S/2);
 
    win_len = 50;
    err_window = zeros(win_len, S);
    win_ptr = 1;
 
    for n = 1:N
        r_buf = [r(n); r_buf(1:end-1)];
        m = n - D;
 
        a_fb = get_fb_vector(m, d, d_hat_sym, cfg, L);
        x = [r_buf; v.dfe_sign * a_fb];
 
        y_per_bank = zeros(S,1);
        for s = 1:S
            y_per_bank(s) = theta_banks(:,s).' * x;
        end
 
        has_ref = (m >= 1 && m <= numel(d));
        is_dd   = has_ref && (m > cfg.trainLen);
 
        if is_dd
            res_per_bank = zeros(S,1);
            for s = 1:S
                d_dec_s = pam_slice_scalar(y_per_bank(s), cfg.A);
                res_per_bank(s) = (d_dec_s - y_per_bank(s))^2;
            end
            err_window(win_ptr, :) = res_per_bank.';
            win_ptr = mod(win_ptr, win_len) + 1;
            mean_res = mean(err_window, 1).';
            [~, s_hat] = min(mean_res);
        else
            s_hat = round(S/2);
        end
 
        state_est(n) = s_hat;
 
        y = y_per_bank(s_hat);
        if m >= 1 && m <= numel(d_hat_sym)
            d_hat_sym(m) = pam_slice_scalar(y, cfg.A);
        end
 
        if has_ref
            if is_dd
                d_ref = pam_slice_scalar(y, cfg.A);
            else
                d_ref = d(m);
            end
            e = d_ref - y;
            g  = (x.'*x) + v.delta;
            u  = e / g;
            mu_base = get_step_size(n, v);
            mu = mu_base;
 
            Hn = -v.lambda * theta_banks(:,s_hat) + x * u;
 
            if is_dd
                theta_new = theta_banks(:, s_hat) + mu * Hn;
                theta_banks(:, s_hat) = Pi_H(theta_new, v, K);
            else
                for s = 1:S
                    Hn_s = -v.lambda * theta_banks(:,s) + x * u;
                    theta_new = theta_banks(:,s) + mu * Hn_s;
                    theta_banks(:,s) = Pi_H(theta_new, v, K);
                end
            end
        end
    end
end
 
 
% ============================================================================
% SECTION-F  —  HELPERS
% ============================================================================
 
