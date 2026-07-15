% Auto-split from NCKH_v53.m (original line 4979).
% Folder: channel

function [r_clean, ch_state] = channel_out_std8023_like(d, cfg)
% IEEE 802.3-2018 inspired channel model
% Incorporates: UTP propagation loss, jitter, crosstalk, AC coupling,
%               transmit pulse shaping per Section 23 specifications.
%
% Physical chain: d → Tx pulse shape → UTP cable → Crosstalk → AC coupling
%
% References:
%   - ISI limits: Section 23.6.5 (<9% for 100BASE-T4)
%   - Jitter: Section 23.5.1.2.8 (±5.0 ns per link segment)
%   - MDFEXT: Section 23.5.1.3 (≤87 mVp)
%   - Impulse noise: Section 23.7 (>264 mV office environment)
%   - Transmit template: Table 23-4

    N = numel(d);
    s = cfg.std8023;

    % ==== Step 1: Build channel impulse response ====
    if s.use_external_ir
        h = load_external_impulse_response(s.ir_file, s.ir_norm_main);
    else
        h = build_utp_ir_model(cfg);
    end

    % ==== Step 2: Transmit pulse shaping (Table 23-4) ====
    if isfield(s,'tx_template_enable') && s.tx_template_enable
        d_shaped = apply_tx_template(d, s);
    else
        d_shaped = d;
    end

    % ==== Step 3: ISI channel convolution ====
    r_isi = conv(d_shaped, h, 'same');

    % ==== Step 4: Jitter (Section 23.5.1.2.8) ====
    if isfield(s,'jitter_enable') && s.jitter_enable
        r_isi = apply_sampling_jitter(r_isi, s.jitter_std_ns, s.baud);
    end

    % ==== Step 5: Crosstalk (Section 23.5.1.3) ====
    xt = zeros(N, 1);
    if s.add_xtalk
        xt = generate_crosstalk(d, cfg);
    end

    r_clean = r_isi + xt;

    % ==== Step 6: AC-coupling high-pass filter ====
    if s.ac_fc > 0
        r_clean = apply_ac_coupling(r_clean, s.ac_fc, s.baud);
    end

    % ==== Output state ====
    ch_state = struct();
    ch_state.h      = h(:);
    ch_state.mode   = 'std8023_like';
    ch_state.h2     = zeros(N,1);
    ch_state.state  = ones(N,1);
    if numel(h) >= 2
        ch_state.h2(:) = h(2);
    end
    % ISI measurement at mid-eye (per Section 23.6.5, Figure 23-15)
    ch_state.isi_ratio = measure_isi_ratio(h);
end

% ---- 802.3 Sub-functions ------------------------------------------------

