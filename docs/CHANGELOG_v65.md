# CHANGELOG v65 — Liu et al. 2023 baseline + IEEE Access plot quality

## What changed

### NEW: Liu et al. 2023 SS-LMS DFE baseline

`core/baselines_liu/dfe_ss_lms_pam4.m` — algorithmic re-implementation of
the receiver-side adaptive blocks from:

> X. Liu, Z. Li, H. Wen, M. Miao, Y. Wang, Z. Wang,
> "A PAM4 transceiver design scheme with threshold adaptive and tap
> adaptive," EURASIP J. Adv. Signal Process., vol. 2023, no. 70, 2023.

Two variants exposed via `dfe_ss_lms_pam4(r, d, cfg, v_base, opts)`:

* **SS-LMS-DFE** (`opts.adaptive_threshold = false`): sign-sign LMS tap
  update for the FFE/DFE coefficients with fixed PAM4 thresholds.
  Update rule:
  `h(n+1) = h(n) + μ_h sgn(e(n)) sgn(x(n))`
  `f(n+1) = f(n) + μ_f sgn(e(n)) sgn(d_buf(n))`

* **TA-SS-LMS-DFE** (`opts.adaptive_threshold = true`): same SS-LMS tap
  update plus adaptive PAM4 thresholds via per-level running means
  (proxy for Liu's auxiliary-sampler hardware loop).

### Honesty disclaimer (also in the runner header)

Liu's published transceiver includes a 3-stage CTLE (mid/high/low-frequency
peaking), VGA, SatAmp, CDR, half-rate half-interleaved feedback DFE, and
auxiliary samplers as physical comparators. We **do NOT reproduce** any
of those circuit-level blocks. We only reimplement the algorithmic
adaptation rules.

Recommended paper wording:

> "We include a Liu-style threshold- and tap-adaptive SS-LMS DFE as a
> practical PAM4 adaptive-receiver baseline. Only the algorithmic
> adaptation mechanism (sign-sign LMS taps and adaptive level thresholds)
> is re-implemented and evaluated under the same IEEE 802.3-inspired
> PAM4 testbed; circuit-level blocks such as CTLE, VGA, saturation
> amplifier, and CDR are not reproduced. This comparison is intended to
> evaluate adaptive-equalization behavior rather than transistor-level
> receiver implementation."

### Suite update: Liu replaces Dolatsara in main hero suite

`run_paper('direct_benchmarks')` now reports **Liu SS-LMS-DFE +
TA-SS-LMS-DFE** alongside Souza, Cui, Chen, and Algorithm 6. Dolatsara
SCBO Tx-FIR remains accessible via `run_paper('dolatsara_scbo')` for
readers interested in Tx-side optimization comparisons.

### NEW: `liu_ss_lms` mode

```matlab
out = run_paper('liu_ss_lms');           % standalone Liu baseline
out = run_paper('direct_benchmarks');    % includes Liu in main suite
out = run_paper('dolatsara_scbo');       % still callable individually
```

## Plotting upgraded to IEEE Access journal-print quality

### NEW shared style

`utils/plotting/reviewer_plots/ieee_access_style.m`
* Arial 11/12/13 typography
* Inward ticks, minor ticks on
* Box on, grid on with 18% alpha
* White background
* Minor grid off
* Legend without box
* Auto-applies to all axes when given a figure handle

`utils/plotting/reviewer_plots/pal_ieee.m`
* Colorblind-friendly palette (Wong-style points-of-view colors)
* Print-safe; distinguishable in greyscale
* Named entries: `proposed`, `oracle`, `alg5`, `nlms`, `smsign`,
  `smsign_vss`, `cui`, `liu_ss`, `liu_ta`, `chen`, `dolatsara`, `fec_line`

### NEW plotters

| Mode | Plotter | What it shows |
|---|---|---|
| `ber_severe`, `ber_realistic`, `severe`, `realistic` | `plot_hero_ber` | Hero BER curve, all 6 algorithms, FEC + 10⁻³ + 10⁻⁵ guides, oracle dashed |
| `hmm_accuracy`, `table5` | `plot_hmm_accuracy_table` | Pr(s_hat = α) vs SNR, severe vs realistic, with random-guess line |
| `burden_isolation`, `oracle_dd` | `plot_burden_isolation` | 3-bar grouped chart Single/Alg6/Oracle per regime + ratio annotation |

### Existing plotters re-styled

All upgraded to:
* Use `pal_ieee` palette
* Wider proposed-method line (LineWidth 2.0–2.4) for visual emphasis
* Oracle as dashed (visual hierarchy: solid = real-world, dashed = upper bound)
* `ieee_access_style(fig)` call before save
* Consistent FEC lines (KP4 2.4×10⁻⁴ dashed, others dotted)
* Sentence-case titles, no overcrowded legends

### Auto-plot for `all_full`

Now generates **9 figures** in one batch:

```matlab
out = run_paper('all_full', 'save_dir', 'paper_figs');
% paper_figs/hero_ber_severe.png
% paper_figs/hero_ber_realistic.png
% paper_figs/hmm_accuracy_table.png
% paper_figs/burden_isolation.png
% paper_figs/p_mismatch_sweep.png
% paper_figs/state_separation_sweep.png
% paper_figs/theory_proxy_diagnostics.png
% paper_figs/markov_source_profile.png
% paper_figs/direct_benchmarks_suite_v65.png
% paper_figs/complexity_vs_ber.png
% paper_figs/ck_stress_summary.png
```

## Mode summary table (v65)

| Mode | Description | Figure |
|---|---|---|
| `state_track` | Single-trial diagnostic dump | (none, text only) |
| `ber_severe` / `severe` | Hero severe regime | hero_ber_severe |
| `ber_realistic` / `realistic` | Hero realistic regime | hero_ber_realistic |
| `hmm_accuracy` / `table5` | HMM accuracy table | hmm_accuracy_table |
| `static_sanity` / `table6` | Static channel sanity | (none) |
| `burden_isolation` / `oracle_dd` | Burden isolation | burden_isolation |
| `p_mismatch` | HMM-assumed P sensitivity | p_mismatch_sweep |
| `state_separation` | h2 separation sensitivity | state_separation_sweep |
| `theory_proxy` | V_tr / B_c proxies | theory_proxy_diagnostics |
| `markov_source_profile` | Off-design Markov P | markov_source_profile |
| `direct_benchmarks` | Souza+Cui+**Liu**+Chen+Alg6 | direct_benchmarks_suite_v65 |
| `souza_smsign` | Souza standalone | bench_souza |
| `cui_hmm` | Cui standalone | bench_cui |
| **`liu_ss_lms`** | **Liu standalone (NEW)** | **bench_liu_ss_lms** |
| `dolatsara_scbo` | Dolatsara standalone | bench_dolatsara |
| `chen_pulse` | Chen standalone | bench_chen |
| `complexity` | BER vs MAC budget | complexity_vs_ber |
| `ck_stress` | 802.3ck stressed channel | ck_stress_summary |
| `all_full` | Everything | (all of the above) |

## How to verify quickly

```matlab
% Standalone Liu baseline
out_liu = run_paper('liu_ss_lms');

% Updated suite with Liu in place of Dolatsara
out_dir = run_paper('direct_benchmarks');

% Hero severe BER plot with new style
out_sev = run_paper('ber_severe');
% -> figs/hero_ber_severe.png

% Generate every figure in paper_figs/
out = run_paper('all_full', 'save_dir', 'paper_figs');
```
