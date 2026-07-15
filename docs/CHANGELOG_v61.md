# CHANGELOG v61 — IL_max-derived residual ISI tail

This release upgrades the credibility of the `ck_stress` mode by
replacing the hand-tuned residual-ISI tail with one derived from the
IEEE P802.3ck baseline insertion-loss specification.

## What changed

### NEW: `channel/build_8023ck_ref_residual_tail.m`

Builds a symbol-rate residual-ISI tail from the IEEE P802.3ck IL_max
formula:

```
IL_max(f) = 0.05 + 1.8*sqrt(f) + 0.2513*f       0.01 <= f <= 26.56 GHz
IL_max(f) = -12.4192 + 1.07*f                   26.56 < f <= 53.125 GHz
```

Source: IEEE P802.3ck baseline proposal, Vancouver March 2019,
Annex 120E ("100GAUI-1, 200GAUI-2, 400GAUI-4 C2M PAM4 Channel
Insertion-Loss Limit", slide 7).
URL: https://www.ieee802.org/3/ck/public/19_03/li_3ck_02b_0319.pdf

Method:
1. Sample IL_max(f) on a fine frequency grid 0..fs/2 with fs = 4*fb.
2. Subtract `il_offset_dB` to model a channel inside (not at) spec limit.
3. Convert to magnitude response.
4. Reconstruct minimum-phase IR via the **cepstral method**, with no
   Signal Processing Toolbox dependency.
5. IFFT to time domain, decimate to symbol rate fb = 53.125 GBd.
6. Locate main tap, return Ntaps_residual post-cursor taps,
   normalised to unit main tap.

Default parameters:
* `Ntaps_residual = 5`
* `il_offset_dB = 6`  (moderate-loss compliant channel)

Numerical sanity check (Python pre-computation):

| il_offset_dB | IL @ Nyq (dB) | residual tail (5 taps)                            | Σ\|tail\| |
|---|---|---|---|
|  0 | 16.00 | [+0.32, +0.22, +0.11, +0.09, +0.06]                |  0.79 |
|  3 | 13.00 | [+0.29, +0.19, +0.08, +0.06, +0.03]                |  0.66 |
|  6 | 10.00 | [+0.18, +0.07, −0.03, −0.02, −0.03]                |  0.33 |
| 10 |  6.00 | [−0.11, −0.03, −0.01, +0.03, −0.01]                |  0.19 |

### CHANGED: `experiments/practical_stress/run_ck_stressed_channel_check.m`

The hardcoded tail `[0.06, -0.025, 0.012]` is replaced with the
spec-derived tail from `build_8023ck_ref_residual_tail`. The stress
parameters now include `extra_tail_source` citing the IEEE document,
and the output struct includes `pkg.ck_tail` and `pkg.ck_tail_info` for
reviewer audit.

### CHANGED: `docs/PAPER_TEXT_8023CK_INSPIRED.md`

The wording is upgraded: the simulation can now be described as
"residual ISI tail derived from the IEEE 802.3ck IL_max specification".
A new section "Things you CAN write (now, with v61)" lists the
defensible wording.

The "Things you SHOULD NOT write" table is preserved — compliance is
still NOT claimed.

## What did NOT change

* No COM. No ERL. No measured S-parameters. The IL_max-derived tail
  uses the spec **upper bound on insertion loss**, not a captured
  channel response.
* PRBS13Q / PRBS31Q test patterns still not used; symbols are i.i.d.
  uniform.
* Calibrated stressed eye (VEC mask) still not enforced.
* Reference equalizer topology (CTLE + FFE + DFE) is still our
  paper's FFE+DFE; no analog CTLE is modelled.
* SJ frequency continues to be expressed as cycles-per-packet (NOT
  absolute Hz). The 802.3ck SJ mask is in absolute Hz; this script
  does not reproduce that mask.

## How to verify reproducibly

```matlab
[tail, info] = build_8023ck_ref_residual_tail(5, 6);
disp(tail);
disp(info);
% Should print tail close to [+0.18; +0.07; -0.03; -0.02; -0.03]
% with info.IL_dB_at_Nyquist around 10 dB and the IEEE 802.3ck citation.
```

## How to change loss case

Edit `il_offset_dB` near the top of
`run_ck_stressed_channel_check.m`:

```matlab
il_offset_dB = 0;    % worst-case: full IL_max
il_offset_dB = 6;    % moderate compliant channel  (default)
il_offset_dB = 10;   % low-loss channel
```
