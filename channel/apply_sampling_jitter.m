% Auto-split from NCKH_v53.m (original line 5094).
% Folder: channel

function r_out = apply_sampling_jitter(r, jitter_std_ns, baud)
% Add Gaussian sampling jitter (Section 23.5.1.2.8).
% Maps to timing uncertainty at the receiver sampler.
% Effect: interpolation error ≈ dr/dt * delta_t
    N = numel(r);
    Tb = 1/baud;
    sigma_t = jitter_std_ns * 1e-9;
    delta_t = sigma_t * randn(N, 1);  % timing offset per sample

    % Approximate slope dr/dt via finite difference
    dr = [diff(r); 0] / Tb;
    r_out = r + dr .* delta_t;
end

