function out = run_mb_ber_twochain_2021_v72(cfg, vars, base, mc, snr_list)
% Controlled two-chain Markov-ISI benchmark inspired by discrete-time MJS
% examples with two independent Markov chains. Chain 1 switches the channel
% ISI state. Chain 2 switches disturbance/noise and effective feedback delay.

if nargin < 5 || isempty(snr_list)
    snr_list = 10:2:30;
end

cfg_p = cfg;
cfg_p.chan_mode = 'markov_2chain_2tap';
cfg_p.Nsym = max(cfg_p.Nsym, 80000);
cfg_p.trainLen = min(max(cfg_p.trainLen, 8000), floor(0.25 * cfg_p.Nsym));

% Chain 1: channel/plant mode r_k.
mkprof = controlled_markov_isi_profile_v72('profile', 'severe_partial_response');
cfg_p.markov.h2_states = mkprof.h2_states;
cfg_p.markov.P = mkprof.P;
cfg_p.markov.init_state = mkprof.init_state;
cfg_p.markov.profile = mkprof;
cfg_p.markov.fixed_state = 2;

% Chain 2: disturbance/communication mode sigma_k.
% h2_states is only used by the generic Markov sampler; delay_states carries
% the actual effective delayed symbol index used by channel_out.
cfg_p.markov2.h2_states = [1 2];
cfg_p.markov2.delay_states = [1 1];
cfg_p.markov2.P = [0.975 0.025; ...
                   0.100 0.900];
cfg_p.markov2.init_state = 1;

cfg_p.twochain.enable = true;
cfg_p.twochain.noise_scale = [1.0 1.25];
cfg_p.twochain.drop_prob = [0.0 0.0];
cfg_p.twochain.imp_prob = [0.0 0.0005];
cfg_p.twochain.imp_alpha = 10;

out = run_mb_ber_compare(cfg_p, vars, base, mc, ...
    'mb_twochain_2021_v72', snr_list);

out.protocol = struct();
out.protocol.description = 'Two-chain Markov-ISI benchmark: channel state plus disturbance/delay state.';
out.protocol.chain1 = cfg_p.markov;
out.protocol.chain2 = cfg_p.markov2;
out.protocol.twochain = cfg_p.twochain;
end
