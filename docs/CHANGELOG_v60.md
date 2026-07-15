# CHANGELOG v60 — review-driven fixes for v59 ck_stress

This release addresses three issues that any signal-integrity / SerDes
reviewer of the IEEE-Access submission would catch.

## Issue 1: AWGN level drifted with stress profile

**v59 behaviour:** `sigma2 = mean(r_noiseless^2) / 10^(SNRdB/10)` —
the noise was scaled to the post-stress waveform power, so the AWGN
floor was different across `isi_awgn`, `isi_xtalk_awgn`, and `dirty_full`
even at the same `SNRdB`.

**v60 fix:** noise is now scaled to the clean Markov-ISI signal power
`r_base`. `SNRdB` now means "AWGN level relative to the desired
Markov-ISI signal", which is the conventional definition used elsewhere
in the codebase. Stress terms add their own deterministic disturbance
on top.

File: `experiments/practical_stress/run_ck_stressed_channel_check.m`

## Issue 2: KP4 FEC pre-FEC BER threshold not reported

**v59 behaviour:** BER printed but no comparison to the 802.3ck KP4 FEC
pre-FEC threshold.

**v60 fix:** added `pass_fec` field per profile, threshold 2.4e-4
(KP4 FEC, this is the pre-FEC BER target referenced by 802.3ck RX
interference-tolerance test). The summary table now prints PASS/FAIL.

## Issue 3: "Source-grounded" label without a citation

**v59 behaviour:** `run_markov_source_profile.m` documented the P
matrix as "source-grounded from a Markov-jump-system example" without
a citation. That phrasing implies a literature source the reader could
look up; it doesn't exist.

**v60 fix:** dropped the "source-grounded" label. The script now runs
**two** off-design transition matrices (`P_A_asym` and `P_B_dense`)
purely as P-shape sensitivity tests, with explicit comments saying these
are NOT measured SerDes channels and NOT from a cited MJS paper. If the
authors want to cite a specific MJS source for one of the matrices, the
citation must be added in the paper text and the matrix must match
that source's entries.

File: `experiments/robustness/run_markov_source_profile.m`

## Documentation rewrite

`docs/PAPER_TEXT_8023CK_INSPIRED.md` is rewritten with a complete
"things you SHOULD NOT write" table and an explicit list of what the
simulation IS NOT (no COM, no ERL, no measured S-param, no PRBS13Q,
no calibrated stressed eye, no 53 GBd line rate). This is for the
authors to copy-paste safely without overclaiming.

## Did NOT change

* The general stress stack architecture (residual ISI tail + jitter +
  crosstalk + tone + AWGN). This remains an engineering proxy.
* The first-order Taylor jitter model (`r' * delta_UI`). This is
  standard for symbol-rate jitter proxies; v60 documents it explicitly
  rather than leaving it implicit.
* SJ frequency continues to be expressed as cycles-per-packet, NOT
  absolute Hz. The 802.3ck SJ mask is in absolute Hz; this script does
  not reproduce it. Comment in code clarifies this.
