# Paper Code v72 — Reviewer Package

This cleaned package keeps the final paper runners at the project root and
moves temporary tuning/smoke outputs into `_runs_archive/`.

For the current reviewer-facing structure, start with:

```text
docs/PROJECT_STRUCTURE_REVIEWER.md
```

Main final runners:

```matlab
out = run_final_all_blocks_v72();
out = run_blockB_tracking_stress_all_recursions_v72();
```

Primary final outputs:

```text
paper_final_all_blocks_v72/
paper_profiled_blockB_smoke/
```

Development-only scripts are kept in `tools/dev/`.  Old/original versions are
kept in `archive/`.  No cleanup step deleted files.

# Paper Code v59 — CK stress hotfix

This package includes a hotfix for `run_paper(''ck_stress'')`: missing `si_cycles` is fixed and the main stressed waveform uses causal filtering to preserve sample alignment.

# Paper Code v54 — Folderized MATLAB Project

This folder was generated from `NCKH_v53.m` and reorganized for the current paper direction.

## How to run

Open MATLAB in this folder and run:

```matlab
out = run_paper('state_track');
out = run_paper('ber_severe');
out = run_paper('ber_realistic');
```

## Folder map

| Folder | Purpose |
|---|---|
| `core/algorithm6_msb/` | Algorithm 6 HMM/MSB implementation and MSB helpers |
| `core/algorithm5_singlebank/` | Algorithm 5 single-bank baseline |
| `core/baselines/` | NLMS, RLS, VSS-NLMS, SM-sign baselines |
| `channel/` | Channel, Markov state, and noise generation |
| `experiments/paper_main/` | Severe/realistic Markov BER and paper-facing diagnostics |
| `experiments/theory_legacy/` | Older ODE/PTF/CLR/jump/theorem experiments retained for archive |
| `core/proposed_legacy/` | Older proposed/gate/clip/CLR recursions retained for archive |
| `utils/` | Metrics, plotting, and small math helpers |
| `archive/original/` | Original unsplit MATLAB file |

## Current-paper choices

- Final Algorithm 6 is HMM-only.
- `use_update_conf_gate = false` is the paper-facing default.
- `train_all_prefix` is retained as optional warm-start.
- Gate/clip/CLR/AGC code is preserved for legacy diagnostics but should not be part of the main Algorithm 6 claim.

Total functions split: 185.

## v55 reviewer-ready additions

New reviewer-facing modes:

```matlab
out = run_paper('hmm_accuracy');      % fills Table 5
out = run_paper('static_sanity');     % fills Table 6
out = run_paper('burden_isolation');  % Theorem 2 proxy bridge
out = run_paper('p_mismatch');        % transition-matrix mismatch scaffold
out = run_paper('state_separation');  % A12 state-separation scaffold
out = run_paper('theory_proxy');      % V_tr and B_c proxy scaffold
out = run_paper('reviewer_mustdo');   % first three must-do experiments
```

New folders:

| Folder | Purpose |
|---|---|
| `experiments/reviewer_mustdo/` | Table 5, Table 6, and burden-isolation diagnostics |
| `experiments/robustness/` | P-mismatch and state-separation robustness scaffolds |
| `experiments/theory_to_proxy/` | Theorem 2 proxy diagnostics scaffolds |
| `experiments/benchmark_relation/` | Notes for positioning vs Cui/Dolatsara/Chen |
| `docs/REVIEWER_READY_TODO.md` | Submission-readiness checklist |
```

## v58 additions

Additional reviewer-oriented modes:

```matlab
out_ck = run_paper('ck_stress');
```
Runs an **802.3ck-inspired dirty-PAM4 stressed-channel check**. This is a simulation-level robustness check, not a formal IEEE 802.3ck compliance test.

```matlab
out_ms = run_paper('markov_source_profile');
```
Runs a source-grounded Markov switching profile using a transition matrix from a Markov-jump-system example. The postcursor amplitudes remain controlled DFE-stress values.

## v71 note — CK-stress split eye plots

`run_paper('ck_stress', 'save_dir', 'paper_figs', 'format', 'png')` now also exports one 3x3 eye-diagram figure per CK stress profile. The split figures are named `ck_eye_<profile>_snr22_split_v71.png`.

## v72 CK eye metrics

Running

```matlab
out = run_paper('ck_stress', 'save_dir', 'paper_figs', 'format', 'png');
```

also exports split CK eye figures with EH/EW annotations and a CSV table:

```text
ck_eye_height_width_snr22_v72.csv
```

EH is the minimum adjacent PAM4 5--95% vertical eye height. EW is an approximate horizontal eye width in UI from the same eye waveform used in the figures. These are simulation audit metrics, not IEEE compliance measurements.

## v73 S-parameter benchmark scaffold

New mode:

```matlab
out = run_paper('8023ck_sparam', 'channel_dir', 'data/8023ck_channels', ...
                'trials', 10, 'snr', [18 22 26 30], 'save_dir', 'paper_figs');
```

This mode loads public/contributed Touchstone `.sNp` files, converts the through response to symbol-spaced FIR taps, runs a COM-style PAM4 simulation flow, and reports BER/SER/eye metrics plus a Markov channel-switching diagnostic. It is not an IEEE compliance test and does not run COM pass/fail procedures. See `docs/IEEE8023CK_SPARAM_BENCHMARK.md`.
