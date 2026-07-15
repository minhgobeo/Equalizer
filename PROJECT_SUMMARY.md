# Project Summary: HMM-Routed Multi-State-Bank PAM4 Equalization

**Date:** 2026-05-27 | **Version:** v72 | **Status:** Paper v3 in progress

---

## One-Sentence Pitch

A multi-state-bank adaptive DFE with Bayesian HMM routing that reduces endogenous decision-directed bias under Markov-switching channel states, achieving 59–95× BER improvement on severe Markov ISI and KP4 FEC pass on IEEE 802.3ck stress profiles.

---

## The Problem (Why This Matters)

### Classical Limitation
Standard adaptive equalizers (NLMS, RLS) assume either:
- Static channels, OR
- Channels + exogenous additive noise (not decision-directed feedback)

### Real-World Reality
- Receivers use **decision-directed (DD) mode**: slicer outputs become adaptation references → feedback loop
- Channels switch Markov-style: thermal drift, supply variation, connector aging
- When states change quickly: slicer error rate jumps → feedback corrupts coefficient updates
- **Result**: Single-bank NLMS hits an **irreducible error floor** that step-size tuning cannot fix

### Endogenous Bias Discovery
The core issue is **endogenous bias** — a systematic mismatch between what DD decisions tell the equalizer and what the true channel state requires. This is:
- **Not** reducible by tuning $\mu$ (step size)
- **Not** fixable by SM-NLMS gating
- **Rooted in architecture**: one coefficient bank trying to serve multiple channel states simultaneously

---

## The Solution (What We Did)

### Algorithm 2: Multi-State-Bank HMM-Routed Receiver

**Three key ideas:**

1. **Parallel Banks** — Maintain $S$ coefficient banks, one specialized per Markov state
   - Bank $s$ converges to state-specific Wiener optimum $\theta^*(s)$
   - Each bank has its own DFE decision buffer (prevents cross-state contamination)

2. **Bayesian HMM Routing** — Channel-likelihood scores + Markov prior
   - Score: $\text{score}_s = (r(n) - h_{\text{bank}}(s) \cdot \hat{d}_{\text{prev}})^2$ (not equalizer output error)
   - Forward filter: predicts $\pi_{\mathrm{pred}} = P^\top \pi_{\text{state}}$, updates via likelihood
   - MAP: $\hat{s}_n = \arg\max_s \pi_{\mathrm{state}}$
   - Routes output and updates to winning bank

3. **Architecture vs Tuning** — The solution is **structural**, not algorithmic
   - Replaces cross-state burden $\Delta_{\mathrm{burden}}^{\mathrm{cross}}$ with per-state residuals + routing error
   - Complexity: $O(S \cdot M + S^2) \approx 3\times$ single-bank (practical for $S \le 5$)

---

## Theory (Why It Works)

### Theorem 1: Frozen-State Weak-Limit ODE
- **What**: Weak convergence of DD recursion with vanishing step size to projected ODE
- **Proof method**: Kushner (1997) adapted to Markovian noise + frozen-state analysis
- **Key technical step**: Identify averaged drift $\bar{h}(\theta, s)$ as limit object (differs from exogenous-noise SA)

### Proposition 1: Tracking-Floor Decomposition
Single-bank floor decomposes as:
$$\Delta^* = \underbrace{\frac{C_\nu \mu}{c_0}}_{\text{diffusion}} + \underbrace{\frac{C_b B_c}{c_0}}_{\text{burden}} + \underbrace{\frac{C_d \bar{\Delta}}{c_0}}_{\text{drift}}$$

**Critical insight**: Burden $\Delta_{\mathrm{burden}} \propto B_c$ (endogenous bias) is **independent of** $\mu$ and cannot be eliminated by tuning.

### Why Multi-Bank Wins
- Per-bank analysis: each bank sees only its state-conditional drift
- Per-bank burden: $\Delta_{\mathrm{burden}}(s)$ much smaller than combined single-bank burden
- Routing cost: HMM accuracy ≈ 88% at high SNR, so routing error stays small
- Net result: architecture-driven improvement, not parameter-driven

---

## Experiments (What We Measured)

### Test Setup
- **Signal**: PAM4, 50k symbols, 8k pilot
- **Receiver**: FFE(5 taps) + DFE(1 tap), delay D=2
- **Noise**: AWGN, SNR 10–30 dB
- **Baselines**: NLMS, SM-NLMS, SM-sign-NLMS-VSS, Liu, Cui ExtraTrees+HMM, Chen pulse
- **Trials**: 100 independent Monte Carlo runs per SNR cell

### Two Markov Regimes

**Regime 1: Severe** ($h_2 \in \{0.3, 0.5, 0.7\}$, $P_{\text{diag}}=0.95$)
- Mean dwell 20 symbols (fast switching)
- Tests cross-state burden under stress
- **Result @ 26 dB**: Alg2 = $1.35 \times 10^{-5}$, NLMS = $7.95 \times 10^{-4}$ → **59× better**

**Regime 2: Realistic** ($h_2 \in \{0.45, 0.5, 0.55\}$, $P_{\text{diag}}=0.99$)
- Mean dwell 100 symbols (slow drift)
- Tests nominal operating point
- **Result @ 22 dB**: Alg2 = $1.04 \times 10^{-6}$, NLMS = $2.22 \times 10^{-6}$ → **2.1× better**
- **Static channel**: Zero degradation (both at $4.17 \times 10^{-7}$)

### IEEE 802.3ck-Inspired Stress Profiles
- 4 channels: isi_awgn, isi_xtalk_awgn, isi_jitter_awgn, dirty_full
- 5-tap residual tail + CTLE proxy
- **KP4 FEC threshold**: $2.4 \times 10^{-4}$

| Profile | Alg2 @ 26dB | Alg1 @ 26dB | Pass KP4? |
|---------|-------------|------------|-----------|
| isi_awgn | ~0 | 6.2×10⁻⁴ | ✓ vs ✗ |
| isi_xtalk_awgn | 6.25×10⁻⁶ | 3.27×10⁻⁴ | ✓ vs ✗ |
| isi_jitter_awgn | 6.95×10⁻⁷ | 2.8×10⁻⁴ | ✓ vs ✗ |
| dirty_full | 1.67×10⁻⁵ | 4.82×10⁻⁴ | ✓ vs ✗ |

**Verdict**: Alg2 passes all 4; Alg1 fails 50%.

### Diagnostic Tests
- **HMM accuracy**: 49–88% (improves with SNR, better in realistic regime)
- **DD-bias isolation**: Alg2 reduces bias field 8.1× (severe), 2.8× (realistic)
- **P-mismatch robustness**: BER stays within 2× across Markov matrix variations
- **State-separation sweep**: Monotonic Alg2-to-Alg1 ratio growth as separation increases

---

## Code Structure

### Entry Points (In Priority Order)

```
run_final_all_blocks_v72.m
  ├─ Block A: severe_ber_v68 (20 trials, controlled Markov)
  ├─ Block B: 8023ck_sparam_benchmark (real S-parameters, Markov sweep)
  └─ Block C: endogenous_family_tracking_v72 (NLMS → MSB ablation)

run_paper.m (dispatcher)
  ├─ 'state_track': HMM accuracy + state history
  ├─ 'ber_severe': Regime 1 full sweep
  ├─ 'ber_realistic': Regime 2 full sweep
  ├─ 'endogenous_family': Ablation across algorithm family
  ├─ '8023ck_sparam': IEEE benchmark (no Markov)
  └─ 'direct_benchmarks': 5 baseline comparisons
```

### Core Algorithm Implementations

| File | Algorithm | Purpose |
|------|-----------|---------|
| `algorithm6_msb_firbank.m` | Algorithm 2 | Main proposed (FIR channel-likelihood routing) |
| `algorithm6_msb.m` | Algorithm 2 variant | Simplified 2-tap scalar version |
| `algorithm5_singlebank.m` | Algorithm 1 | Baseline for ablation |
| `dfe_smnlms_unified_x.m` | Baseline | Set-membership NLMS (comparative) |
| `dfe_nlms_unified_x.m` | Baseline | Standard NLMS |

### Configuration & Setup

| File | Purpose |
|------|---------|
| `build_main_config.m` | Master config (M, Nsym, SNR, Markov matrix P, etc.) |
| `build_baselines.m` | NLMS/SM-NLMS parameter sets |
| `controlled_markov_isi_profile_v72.m` | Markov profiles (severe, realistic) |
| `default_msb_params_v69.m` | Algorithm 2 hyperparameters (B=128, rho=0.8, etc.) |

### Utilities

| Folder | Purpose |
|--------|---------|
| `channel/` | Channel models, Touchstone loaders, ISI/jitter/crosstalk |
| `utils/math/` | SMNLMS update, projection, slicer, EMA filters |
| `utils/metrics/` | BER/SER, eye height/width, HMM diagnostics |
| `utils/plotting/` | Figure generation |

---

## Key Parameters (Final Configuration v72)

### Transmission
- **PAM4**: $\mathcal{A} = \{-3, -1, +1, +3\}$, Gray-coded
- **Packet**: 50k symbols, 8k pilot, SNR 15–30 dB

### Receiver
- **FFE**: 5 taps (K=5)
- **DFE**: 1 tap (L=1)
- **Delay**: D=2
- **Projection box**: per-tap magnitude bounds

### Algorithm 2
- **Banks**: S=3 (one per Markov state)
- **EMA window**: B=128 → $\alpha = 1/128$
- **Dwell minimum**: $T_{\min}=4$ symbols
- **Step size**: $\mu=0.01$ (constant)
- **Leakage**: $\lambda=10^{-3}$
- **HMM temperature**: $\tau_{\text{HMM}}=0.05$

### Endogenous Gate (v72 addition)
- **Entropy weight**: $\lambda_{\mathrm{ent}}=1.0$
- **Cross-state weight**: $\lambda_{\mathrm{cross}}=3.0$
- **Gate scaling bounds**: $[0.35, 3.0]$
- Detects DD bias via posterior entropy + margin confidence

---

## Novelty Assessment

### Real (✓)
- Bank-local DFE decision buffers (prevents cross-state contamination)
- Endogenous bias identification + theoretical decomposition
- Channel-likelihood scoring (not equalizer-output-based routing)
- Comprehensive application to PAM4 DD + Markov switching

### Inherited (✓ Acknowledged)
- HMM/IMM framework (Blom & Bar-Shalom 1988, but not applied to PAM4 DFE)
- NLMS/SMNLMS (Haykin, Souza et al.)
- Stochastic approximation theory (Kushner 1997)

### Engineering Quality
- Practical complexity: $O(SM + S^2)$ ≈ 3× single-bank
- Static-channel non-degradation: verified empirically
- Robustness to P-mismatch: empirically tested

---

## Future Work

1. **Online state-library learning** — Currently $h_2(s)$ is known; extend to joint learning
2. **Higher-order ISI** — Extend multi-tap Markov states beyond 3-tap model
3. **Hardware validation** — ASIC/FPGA layout estimates (area, power, latency)
4. **Adaptive temperature** — Auto-tune $\tau_{\text{HMM}}$ instead of empirical sweep
5. **Per-bank initialization** — Smarter warm-start from channel-likelihood scores

---

## For Future Prompts: Copy-Paste Context

When asking for modifications/analysis, include this section in your prompt:

```
**CONTEXT**: This is a project about PAM4 adaptive equalization under Markov-switching ISI.

- **Core contribution**: Multi-state-bank HMM-routed receiver (Algorithm 2) that architecturally sidesteps
  endogenous DD bias by maintaining S parallel banks + bank-local DFE buffers.
  
- **Theory**: Theorem 1 (weak-limit ODE), Proposition 1 (floor decomposition into diffusion+burden+drift).
  Burden is irreducible for single-bank; multi-bank architecture reduces it.
  
- **Experiments**: Two Markov regimes (severe: 59-95× BER gain; realistic: 2.1× gain) + IEEE 802.3ck
  profiles (KP4 FEC threshold pass on all 4 profiles).
  
- **Code**: Entry points are run_final_all_blocks_v72.m (Block A/B/C) and run_paper.m dispatcher.
  Core algorithm: algorithm6_msb_firbank.m (main) and algorithm5_singlebank.m (baseline).

- **Paper status**: v3 in progress, merging v2 (theory-focused) + v1 (experiment-heavy).
  v2 emphasizes Theorem 1 + Proposition 1 + proposed algorithm.
  v1 has full diagnostic test suite (Section VII A-K).
```

---

## Contact Points

- **Main algorithm file**: `core/algorithm6_msb/algorithm6_msb_firbank.m` (line 1–369)
- **Theory setup**: Section II–III (System Model + Theorems)
- **Experiments**: `run_final_all_blocks_v72.m` and result folders `paper_final_all_blocks_v72/`
- **Channel data**: `data/8023ck_channels/` (Touchstone .s2p files)
- **Paper**: `paper_FULL_REVISED_v2.md` (current focus, 747 lines)

---

**Last updated**: 2026-05-27 | **Next milestone**: Complete v3 merged paper + run final Block B experiments
