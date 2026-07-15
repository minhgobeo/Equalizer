# Direct & Adapted Equalizer Benchmark Folder

This folder collects the recent-equalization benchmarks discussed in the v56
review document. They populate Section VII Table X of the paper.

## Important honesty disclaimer

Three of the four benchmarks are **system-adapted** baselines, not exact
reproductions of the original papers. We do not have the authors' code,
hyperparameters, or datasets. They run inside the SAME PAM4 Markov-DD testbed
used by the proposed Algorithm 6. This is the position recommended in the v56
review document and matches accepted practice in IEEE Access submissions.

The fourth (Souza SM-sign-NLMS) is a **direct numerical baseline** — it is
exactly the SM-sign-NLMS / VSS-SM-sign-NLMS recursion proposed in Souza et al.
(2024) implemented as an online adaptive filter and called inside our channel
chain.

## Files

| File | Purpose |
|------|---------|
| `run_souza_smsign_direct_baseline.m`              | Direct SM-sign-NLMS and VSS variant baselines |
| `run_cui_extratrees_hmm_direct_adapter.m`         | Adapted Cui-style ExtraTrees / HMM classifier |
| `run_dolatsara_scbo_tx_direct_adapter.m`          | Adapted SCBO-style Tx-FIR optimizer |
| `run_chen_single_pulse_direct_adapter.m`          | Adapted single-pulse FFE/DFE design |
| `run_direct_equalizer_benchmark_suite.m`          | Runs all four and prints Table X |

## Usage

```matlab
% Run everything and print Table X:
out = run_paper('direct_benchmarks');

% Or run individually:
out_souza     = run_paper('souza_smsign');
out_cui       = run_paper('cui_hmm');
out_dolatsara = run_paper('dolatsara_scbo');
out_chen      = run_paper('chen_pulse');
```

## Toolbox notes (Cui adapter)

The Cui adapter prefers (in order):

1. `fitcensemble(X, y, 'Method','Bag', 'NumLearningCycles', 50)`  — Statistics
    and Machine Learning Toolbox.
2. `TreeBagger(50, X, y, 'Method','classification')` — same toolbox.
3. **Fallback**: deterministic nearest-centroid in feature space.

If neither toolbox is available, the script will not crash; it will run the
nearest-centroid fallback and print which classifier was used. For a paper
submission, the toolbox versions should be preferred and reported in the
caption. The classifier kind actually used is returned in `pkg.classifier_kind`.

## What each benchmark answers

Each benchmark targets a likely reviewer question:

* **Souza**: "Why not just use a robust adaptive filter like SM-sign-NLMS?"
* **Cui**:      "An offline ML classifier handles non-linear distortion; why not here?"
* **Dolatsara**:"An offline Tx-FIR optimizer maximizes eye opening; isn't that enough?"
* **Chen**:     "A single-pulse-response FFE/DFE design is exact for static channels; why need an online adaptive equalizer?"

The expected answer in each case is the same: in finite-state Markov-ISI with
DD reference, none of these methods has a state-tracking mechanism, so they
cannot match the proposed Algorithm 6 in severe Markov regimes.
