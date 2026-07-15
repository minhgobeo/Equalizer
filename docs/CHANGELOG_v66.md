# CHANGELOG v66 — Liu baseline fix + eye benchmark + Algorithm 1/2 labels

## 1. Fixed Liu-style SS-LMS DFE baseline

Updated `core/baselines_liu/dfe_ss_lms_pam4.m`:

- Fixed DFE feedback update sign for the convention `z = h^T r - f^T d_hat_prev`.
- Fixed delayed-decision timing: tap update now uses the same delayed-decision buffer used in the equalizer output; current decision is shifted in after update.
- Added projection/clipping for FFE/DFE taps.
- Default Liu-style behavior updates DFE taps only (`update_ffe=false`), matching the receiver-side adaptive-DFE role in Liu et al.
- Added `diag.z_hist` so Liu-style equalizer outputs can be plotted as eye diagrams.

## 2. Added Liu-like eye-diagram benchmark

New experiment:

```matlab
out = run_paper('liu_like_eye', 'save_dir', 'paper_figs');
```

This runs a Liu-style adaptive PAM4 DFE comparison with 4 DFE feedback taps and produces:

- Receiver before equalization eye diagram.
- Algorithm 1 single-bank eye diagram.
- Algorithm 2 HMM-MSB eye diagram.
- Liu SS-LMS DFE eye diagram.
- Liu TA-SS-LMS DFE eye diagram.
- BER summary panel.

Oracle MSB is computed and printed for audit only; it is not plotted.

## 3. Renamed figure labels

Main plot labels now use:

- `Algorithm 1 (single-bank)` instead of `Algorithm 5`.
- `Algorithm 2 (proposed HMM-MSB)` instead of `Algorithm 6`.

The internal function names are unchanged to avoid breaking code paths.

## 4. Removed oracle from figures

Oracle remains in printed tables for audit/upper-bound reference, but the plotting functions no longer draw oracle curves/bars in the main figures.
