# Benchmark-Relation Plan for Section I / Section VI

Use these works as **positioning benchmarks**, not direct runtime/BER baselines, because their problem settings differ.

## 1. Cui et al. 2024 ExtraTrees-HMM
- Problem: optical OAM-MDM / non-orthogonal MultiCAP equalization.
- HMM role: sequence classifier; hidden state is constellation/symbol class.
- Our role: HMM tracks physical ISI state `alpha_n` and routes coefficient updates.
- Add table column: HMM purpose = classification vs routing.

## 2. Dolatsara 2023 SCBO Tx equalization
- Problem: offline Tx FIR tap optimization for largest eye opening.
- Requires simulator/objective evaluations; constrained BO handles tap constraints.
- Our problem: online Rx DD adaptive FFE-DFE under Markov channel switching.
- Add table column: offline static optimizer vs online adaptive tracker.

## 3. Chen et al. 2025 pulse-response joint FFE/CTLE/DFE optimization
- Problem: joint static FFE/CTLE/DFE optimization using single pulse response.
- Avoids iterative channel simulations and is efficient for pre-deployment design.
- Our problem: streaming DD adaptation when channel state changes after deployment.

## Paper insertion
Add a new Table in Related Work or Section VI:
`TABLE X. Positioning against recent equalization methods.`
Columns: Work, Main objective, Channel model, Online?, DD feedback?, HMM role, Output, Difference from ours.
