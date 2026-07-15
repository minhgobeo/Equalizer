# CHANGELOG v71 — CK-stress split eye figures

## Main change

Added automatic split eye-diagram export for the CK-inspired benchmark.

When running:

```matlab
out = run_paper('ck_stress', 'save_dir', 'paper_figs', 'format', 'png');
```

the plotting stage now saves:

```text
ck_stress_summary_v70.png
ck_stress_eye_all_methods_snr22_v70.png
ck_eye_isi_awgn_snr22_split_v71.png
ck_eye_isi_xtalk_awgn_snr22_split_v71.png
ck_eye_isi_jitter_awgn_snr22_split_v71.png
ck_eye_dirty_full_snr22_split_v71.png
```

## New file

```text
utils/plotting/reviewer_plots/plot_ck_stress_eye_split.m
```

## Plot behavior

- One figure per CK profile.
- Each split figure uses a 3x3 layout:
  - Before EQ
  - Algorithm 2
  - Algorithm 1
  - NLMS
  - SM-sign
  - Liu SS-LMS
  - Liu TA-SS-LMS
  - Cui ExtraTrees
  - Chen single-pulse
- Oracle MSB is intentionally omitted from the plots.
- BER is printed in each method panel title.
- Common y-limits are used across all split eye figures.
- No per-method variance normalization is applied.

## Modified files

```text
utils/plotting/reviewer_plots/plot_ck_stress.m
utils/plotting/reviewer_plots/plot_experiment.m
run_paper.m
```

## Manual plotting call

If `out` already exists in the MATLAB workspace, run:

```matlab
plot_experiment(out, 'ck_stress_eye_split', 'save_dir', 'paper_figs', 'save_format', 'png');
```
