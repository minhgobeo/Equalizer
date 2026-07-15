# Reviewer Package Structure

This project contains the MATLAB code used for the v72 paper experiments.
The repository is organized so that reviewers can reproduce the final plots
without navigating older tuning and smoke-test folders.

## Main Entry Points

Use these scripts from the project root:

```matlab
out = run_final_all_blocks_v72();
```

Runs the final Block A, Block B, Block C, and extra figure package.

```matlab
out = run_blockB_tracking_stress_all_recursions_v72();
```

Runs the profile-aware C2M tracking-stress benchmark with all paper-facing
recursions.  The default profile settings are:

| Profile | Samples/trial | Trials | Focus |
|---|---:|---:|---|
| slow | 80000 | 100 | low-BER tracking and convergence |
| medium | 40000 | 200 | dynamic tracking under moderate switching |
| fast | 10000 | 1000 | high-switching tracking statistics |

For a quick smoke check:

```matlab
out = run_blockB_tracking_stress_all_recursions_v72( ...
    'snr', [22 26 30], ...
    'profile_trials', [3 5 10], ...
    'profile_nsym', [80000 40000 10000], ...
    'profile_trainLen', [12000 8000 2000], ...
    'save_dir', 'paper_profiled_blockB_smoke', ...
    'fig_visible', 'off');
```

## Final Output Folders

| Folder | Purpose |
|---|---|
| `paper_final_all_blocks_v72/` | Final full paper output: Block A, Block B, Block C, and extra figures |
| `paper_profiled_blockB_smoke/` | Smoke validation for the profile-aware Block B runner |
| `paper_profiled_blockB_final/` | Reserved for full profile-aware Block B runs |

## Source Folders

| Folder | Purpose |
|---|---|
| `core/` | Proposed algorithms, baselines, and shared receiver logic |
| `channel/` | Channel models, S-parameter conversion, Markov state utilities |
| `experiments/` | Paper experiment drivers |
| `utils/` | Plotting, metrics, and helper functions |
| `config/` | Shared configuration and theorem parameter variants |
| `data/` | Channel data and generated input data |
| `docs/` | Paper notes, benchmark notes, and references |
| `reviewer_revision/` | Reviewer-response material |
| `archive/` | Old/original versions retained for traceability |
| `tools/dev/` | Development-only smoke and tuning scripts |

## Archived Temporary Runs

Temporary tuning and smoke-test outputs were moved to:

```text
_runs_archive/2026-05-25_pre_review_cleanup/
```

The archive includes two manifests:

```text
cleanup_manifest.csv
cleanup_dev_manifest.csv
```

These record which files and folders were moved during cleanup.  Nothing was
deleted.

## Reference Papers

Reference PDFs are in:

```text
docs/references/
```

One PDF, `s13634-023-01033-y.pdf`, may remain in the project root if it is
open in another application.  Close the PDF viewer and move it to
`docs/references/` when convenient.

## Reviewer-Facing Method Notes

The final paper-facing comparison focuses on modern recursions and proposed
variants rather than classical sanity baselines.  Classical NLMS and older
VSS-style development checks were retained in source/archive for traceability,
but they are not the main paper figures.

The C2M tracking-stress benchmark is not an IEEE COM compliance test.  It uses
public/contributed IEEE 802.3ck-style C2M S-parameter channels in a
COM-inspired PAM4 flow to stress online receiver adaptation under recurring
channel-state variation.
