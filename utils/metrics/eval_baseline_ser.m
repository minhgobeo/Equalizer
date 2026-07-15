% Auto-split from NCKH_v53.m (original line 1505).
% Folder: utils/metrics

function ser_avg = eval_baseline_ser(cfg, algo_fn, base, Nt, needs_sigma2, snr_list)
% Quick SER evaluation of a baseline algorithm across multiple SNR points.
    if nargin < 6, snr_list = cfg.SNRdB; end
    total_ser = 0;
    for snr = snr_list(:).'
        cfg_e = cfg;
        cfg_e.SNRdB = snr;
        acc = 0;
        for t = 1:Nt
            rng(7000 + t);
            sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
            d = cfg.A(sym_idx).'; d = d(:);
            [r_clean, ~] = channel_out(d, cfg_e);
            rng(8000 + round(snr)*100 + t);
            [r, sigma2] = add_noise_dispatch(r_clean, cfg_e);
            r = apply_practical_agc(r, d, cfg_e);
            if needs_sigma2
                [~, d_hat] = algo_fn(r, d, cfg_e, base, sigma2);
            else
                [~, d_hat] = algo_fn(r, d, cfg_e, base);
            end
            acc = acc + ser_after_training_aligned(d, d_hat, cfg_e);
        end
        total_ser = total_ser + acc / Nt;
    end
    ser_avg = total_ser / numel(snr_list);
end

