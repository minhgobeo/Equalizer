# PAM-4 HMM figure generation code

This package contains one Python script to generate all nine figures as PNG and SVG.

## Install

```bash
pip install matplotlib numpy
```

## Run

```bash
python generate_pam4_hmm_figures_full.py
```

## Output

The script creates:

```text
pam4_hmm_figures_output/
  figure1_overall_8023ck_pam4_benchmark_architecture.png/.svg
  figure2_practical_8023ck_channel_asset_handling.png/.svg
  figure3_markov_sparameter_simulation_loop.png/.svg
  figure4_proposed_msb_firbank_online_dataflow.png/.svg
  figure5_state_local_ffe_dfe_bank_structure.png/.svg
  figure6_training_and_decision_directed_update_schedule.png/.svg
  figure7_single_bank_receiver_versus_proposed_msb.png/.svg
  figure8_hmm_router_schematic.png/.svg
  figure9_endogenous_aware_noise_mechanism.png/.svg
```
