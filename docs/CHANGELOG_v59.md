# CHANGELOG v59

Fixes for `ck_stress` mode.

1. Added missing field `sp.si_cycles` used by the dirty-full sinusoidal-interference profile.
2. Replaced `conv(..., ''same'')` on the main received waveform with causal `filter(...)` to preserve symbol alignment. The old centered convolution could shift the signal and produced near-random BER for all equalizers.
3. Kept the 802.3ck-related wording as `802.3ck-inspired stressed-channel check`, not compliance.

Recommended rerun:

```matlab
out_ck = run_paper(''ck_stress'');
```
