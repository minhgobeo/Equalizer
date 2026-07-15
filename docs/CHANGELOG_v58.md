# CHANGELOG v58

Added reviewer-oriented engineering validation modes.

## New modes

- `run_paper('ck_stress')`: 802.3ck-inspired dirty-PAM4 stressed-channel check.
  - Controlled Markov ISI.
  - Residual high-order ISI tail.
  - Receiver white Gaussian noise.
  - Crosstalk-like independent aggressor streams.
  - Sinusoidal interference.
  - RJ/SJ/BUJ timing-jitter proxies.
  - Compares Alg6-HMM, Oracle MSB, Alg5, NLMS, and SM-sign.
  - Explicitly labelled as **not** a formal IEEE 802.3ck compliance test.

- `run_paper('markov_source_profile')`: source-grounded Markov transition profile.
  - Uses transition matrix `P = [0.5 0.4 0.1; 0.2 0.5 0.3; 0.3 0.3 0.4]` from a Markov-jump-system example.
  - Keeps postcursor values as controlled DFE-stress levels.
  - Compares Alg6-HMM, Oracle MSB, and Alg5.

## New documentation

- `docs/PAPER_TEXT_8023CK_INSPIRED.md`: safe wording for the paper.
