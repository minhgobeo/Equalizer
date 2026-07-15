# Reviewer-Ready TODO Plan

## Must-do before submission
1. Fill Table 5: HMM accuracy vs SNR.
   - Run: `out = run_paper('hmm_accuracy');`
2. Fill Table 6: static-channel non-degradation.
   - Run: `out = run_paper('static_sanity');`
3. Add burden-isolation proxy table.
   - Run: `out = run_paper('burden_isolation');`
4. Fix Theorem 2 proof Step 7: remove the c=0 intermediate line.
5. Soften Theorem 4 wording: global cross-state burden is removed, not all DD burden.
6. Add a positioning table vs Cui 2024, Dolatsara 2023, Chen 2025.

## Strongly recommended
7. P-mismatch sweep: true P vs assumed HMM P.
8. State-separation sweep for Assumption A12.
9. Theory proxy figure: V_tr_hat and B_c_hat.
10. Complexity-vs-BER table for S = 1,2,3,5.

## Not recommended for main text
- IEEE 802.3 9% ISI claim unless you precisely verify the clause/context and define the measurement procedure.
- IMM mixing ablation as a main result; keep it optional or conceptual unless implemented carefully.
