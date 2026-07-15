# CHANGELOG v72 — CK eye-height/eye-width metrics

## Added

- Added `utils/metrics/compute_eye_height_width_metrics.m`.
- Added eye-height and eye-width audit metrics to `out.eye_bank.metrics` in `run_ck_stressed_channel_check.m`.
- Updated split CK eye figures to annotate each panel with:
  - `EH`: minimum adjacent PAM4 5–95% vertical eye height.
  - `EW`: approximate horizontal eye width in UI from the same 2-UI raised-cosine eye waveform used for plotting.
- Added CSV export:
  - `ck_eye_height_width_snr22_v72.csv`

## Notes

- These are simulation audit metrics for comparing equalizer behavior.
- They are not formal IEEE compliance eye measurements and do not replace COM/TDECQ/VEC procedures.
