# Paper code v57 — changelog

This release lifts the v55/v56 review TODOs to full implementations and
removes the remaining scaffolds.

## 1. Patches to core algorithm

`core/algorithm6_msb/algorithm6_msb_v69.m`
* **NEW** `msb_params.P_assumed` — when set, the HMM filter uses this matrix
  as its prior instead of `cfg.markov.P`. Channel generation still uses
  `cfg.markov.P`. This is the hook required by `run_p_mismatch_sweep`.
* **NEW** `msb_params.log_theory_proxy` — when true, the algorithm logs the
  full active-bank theta history (`theta_active_hist_full`), the active-bank
  innovation error (`e_active_hist`), and `||x||^2` per step
  (`x_norm2_hist`). These are consumed by
  `run_theory_proxy_diagnostics` to compute `V_tr_hat` and `B_c_hat`.
* Defaults are off; legacy callers see no behaviour change.

`core/algorithm6_msb/default_msb_params_v69.m`
* New default fields `P_assumed = []` and `log_theory_proxy = false`.

## 2. Robustness experiments — full implementations

`experiments/robustness/run_p_mismatch_sweep.m`
* Replaces the v56 scaffold. Sweeps `assumed_diag` over
  `[0.80, 0.90, 0.95, 0.99, 0.999]` while keeping `cfg.markov.P` (channel)
  fixed. Reports HMM accuracy and pre-FEC BER per (regime, assumed_diag).
* Includes an oracle-P reference run for absolute-floor comparison.

`experiments/robustness/run_state_separation_sweep.m`
* Replaces the v56 scaffold. For separation
  $d \in \{0.025, 0.05, 0.10, 0.15, 0.20\}$ uses the library
  $h_2 = [0.5-d, 0.5, 0.5+d]$ in the realistic-style transition regime,
  then sweeps SNR $\in \{18, 22, 26\}$ dB. Reports HMM accuracy and BER
  alongside oracle and Algorithm 5 references.

## 3. Theory-to-proxy diagnostic — full implementation

`experiments/theory_to_proxy/run_theory_proxy_diagnostics.m`
* Replaces the v56 scaffold. For each regime in $\{$severe, realistic$\}$:
  runs Algorithm 6 (HMM) and Algorithm 6 (oracle) and Algorithm 5
  (single-bank); extracts block-averaged
  $\widehat V_{\mathrm{tr}}(n) = \|\theta_{\mathrm{HMM}}(n) - \theta_{\mathrm{oracle}}(n)\|^2$
  and
  $\widehat B_c(n) = (e_{\mathrm{DD}}(n) - e_{\mathrm{oracle}}(n))^2 / (\delta + \|x_n\|^2)$.
* Returns final-quartile means as scalar summaries plus full block-averaged traces.

## 4. Direct-benchmark adapters — full implementations

`experiments/direct_benchmark/`  (folder was empty in v56; populated here)

* `run_souza_smsign_direct_baseline.m`         — direct SM-sign-NLMS / VSS
* `run_cui_extratrees_hmm_direct_adapter.m`    — adapted Cui-style ML
* `run_dolatsara_scbo_tx_direct_adapter.m`     — adapted Dolatsara Tx-FIR
* `run_chen_single_pulse_direct_adapter.m`     — adapted Chen FFE/DFE
* `run_direct_equalizer_benchmark_suite.m`     — runs all four; prints Table X
* `README_direct_benchmark.md`                 — usage and toolbox notes
* `PAPER_TEXT_direct_benchmark_section.md`     — drop-in text for Section VII

The Cui adapter detects `fitcensemble` and `TreeBagger` and gracefully falls
back to a deterministic nearest-centroid classifier if neither is available.

## 5. Efficiency study (NEW)

`experiments/efficiency/run_complexity_vs_ber.m`
* Sweeps the number of state banks $S \in \{1, 2, 3, 5\}$ at three SNRs and
  both regimes; reports BER and an analytical MACs/symbol estimate. Includes
  Algorithm 5 and NLMS reference rows.

## 6. Launcher

`run_paper.m`
* New modes: `p_mismatch`, `state_separation`, `theory_proxy`,
  `direct_benchmarks`, `souza_smsign`, `cui_hmm`, `dolatsara_scbo`,
  `chen_pulse`, `complexity`, `all_full`.
* Legacy modes preserved unchanged.

## 7. What is still NOT in this release (deferred)

The following were marked optional / appendix in the review documents and
are *not* implemented here:

* IMM mixing-vs-routing ablation experiment (left as conceptual table in
  Related Work as recommended).
* IEEE 802.3 Clause 23 9% peak-to-peak ISI compliance harness (recommended
  to soften the wording in the paper, not run a compliance test).

## 8. Mapping reviewer comments → files

| Reviewer point | Status in v57 | File |
|----|----|----|
| HMM accuracy vs SNR (Table 5)         | implemented (v55) | `experiments/reviewer_mustdo/run_hmm_accuracy_table.m` |
| Static-channel non-degradation (T6)   | implemented (v55) | `experiments/reviewer_mustdo/run_static_channel_sanity.m` |
| Burden isolation                      | implemented (v55) | `experiments/reviewer_mustdo/run_oracle_dd_burden_isolation.m` |
| Transition matrix mismatch            | **v57 full**      | `experiments/robustness/run_p_mismatch_sweep.m` |
| State separation sensitivity          | **v57 full**      | `experiments/robustness/run_state_separation_sweep.m` |
| $V_{\mathrm{tr}}$ / $B_c$ proxies     | **v57 full**      | `experiments/theory_to_proxy/run_theory_proxy_diagnostics.m` |
| Souza SM-sign baseline                | **v57 full**      | `experiments/direct_benchmark/run_souza_smsign_direct_baseline.m` |
| Cui ExtraTrees-HMM adapted            | **v57 full**      | `experiments/direct_benchmark/run_cui_extratrees_hmm_direct_adapter.m` |
| Dolatsara SCBO Tx-FIR adapted         | **v57 full**      | `experiments/direct_benchmark/run_dolatsara_scbo_tx_direct_adapter.m` |
| Chen single-pulse adapted             | **v57 full**      | `experiments/direct_benchmark/run_chen_single_pulse_direct_adapter.m` |
| Complexity vs BER                     | **v57 full**      | `experiments/efficiency/run_complexity_vs_ber.m` |
| IMM mixing ablation                   | deferred (optional)| (none) |
| IEEE 802.3 Clause 23 compliance       | deferred (wording change recommended)| (none) |
