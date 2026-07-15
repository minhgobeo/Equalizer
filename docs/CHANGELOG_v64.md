# CHANGELOG v64 — Auto-plot module for reviewer experiments

This release adds a comprehensive plotting module that turns every
v57+ reviewer experiment into a publication-quality figure
automatically. Figures are saved under `figs/` (configurable) at
300 DPI PNG by default; PDF and FIG are also supported.

## What changed

### NEW: `utils/plotting/reviewer_plots/`

Master dispatcher and per-experiment plotting helpers:

| File | Purpose |
|---|---|
| `plot_experiment.m`         | Master dispatcher; routes to the per-mode plotter |
| `save_fig_helper.m`         | Consistent figure save (PNG/PDF/FIG, DPI control) |
| `plot_p_mismatch.m`         | (a) HMM accuracy vs assumed-P diagonal (b) BER vs assumed P |
| `plot_state_separation.m`   | (a) HMM accuracy vs h2 separation (b) BER + oracle reference |
| `plot_theory_proxy.m`       | V_tr trace, B_c trace, final-quartile bar chart |
| `plot_direct_benchmarks.m`  | BER vs SNR curves for Souza/Cui/Dolatsara/Chen + Alg6 |
| `plot_single_benchmark.m`   | BER vs SNR for one benchmark (souza/cui/dolatsara/chen alone) |
| `plot_complexity.m`         | (a) BER vs S, (b) BER vs MACs/symbol with NLMS reference |
| `plot_ck_stress.m`          | (a) IL_max tail + pre-eq, (b) BER per profile, (c) HMM accuracy with PASS/FAIL |
| `plot_markov_source.m`      | (a) BER under off-design P, (b) HMM accuracy |

### CHANGED: `run_paper.m`

* New optional name/value parameters:
  * `'plot'`     — auto-plot toggle (default `true`)
  * `'save_dir'` — output directory (default `'figs'`)
  * `'format'`   — `'png'` | `'pdf'` | `'fig'`
* When `mode = 'all_full'`, every sub-experiment in the bundled struct
  is auto-plotted.
* Plot failures are caught and logged but do not abort the run.

## Usage

```matlab
% Default: auto-plot enabled, saves to figs/
out = run_paper('ck_stress');
% -> figs/ck_stress_summary.png

% Disable plotting
out = run_paper('p_mismatch', 'plot', false);

% Custom directory and format
out = run_paper('complexity', 'save_dir', 'paper_figs', 'format', 'pdf');
% -> paper_figs/complexity_vs_ber.pdf

% Run all experiments and save every figure
out = run_paper('all_full', 'save_dir', 'paper_figs');
% -> paper_figs/p_mismatch_sweep.png
%    paper_figs/state_separation_sweep.png
%    paper_figs/theory_proxy_diagnostics.png
%    paper_figs/markov_source_profile.png
%    paper_figs/direct_benchmarks_suite.png
%    paper_figs/complexity_vs_ber.png
%    paper_figs/ck_stress_summary.png

% Re-plot from saved struct without re-running the experiment
plot_experiment(out, 'ck_stress', 'save_dir', 'paper_figs');
```

## Figures generated per experiment

### `p_mismatch`
Two-panel figure with HMM accuracy on the left and BER on the right,
both axes vs HMM-assumed P diagonal. Includes oracle BER reference and
KP4 FEC line.

### `state_separation`
Two-panel figure showing HMM accuracy and BER vs h2 separation, one
curve per SNR. Solid = Algorithm 6, dashed = oracle.

### `theory_proxy`
Three panels:
1. V_tr_hat block-averaged trace (parameter-tracking proxy)
2. B_c_hat block-averaged trace, Alg6 vs Alg5
3. Final-quartile bar chart of B_c with annotated alg5/alg6 ratio

### `direct_benchmarks`
Two panels (severe + realistic regimes), all six methods overlaid.

### `complexity`
Two panels:
1. BER vs S (state banks) at three SNRs
2. BER vs MACs/symbol at central SNR with NLMS reference horizontal lines

### `ck_stress`
Three panels:
1. IL_max-derived residual ISI tail (left axis) + pre-equalizer FIR
   taps (right axis), with IL @ Nyquist annotated
2. BER per profile at the higher SNR (all five methods) with KP4 FEC line
3. HMM accuracy bar chart per profile, annotated PASS/FAIL per cell

### `markov_source_profile`
Two panels:
1. BER vs SNR for both off-design P matrices (Alg6/oracle/Alg5 each)
2. HMM accuracy vs SNR

## Style consistency

All plots use:
* Same color palette as existing `plot_ber_curves.m` (blue/orange/yellow/purple/green/cyan)
* Marker conventions: `o s ^ d v x` matching method ordering
* `2.4 × 10⁻⁴` KP4 FEC threshold line wherever pre-FEC BER is plotted
* Solid = proposed/measured, dashed = oracle/reference, dotted = baseline
* `300 DPI` PNG default for paper figures

## Reproducibility

Each plot file is self-contained and depends only on the struct
returned by `run_paper`. To regenerate any figure from a saved
struct (e.g. after a long batch run):

```matlab
load('out_all_full.mat');
plot_experiment(out.ck_stress, 'ck_stress', 'save_dir', 'rebuild_figs');
```
