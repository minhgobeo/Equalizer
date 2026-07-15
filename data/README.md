# Data Policy

This repository is intended to track the MATLAB code, experiment runners,
plotting utilities, and small metadata files needed to reproduce the paper
workflow.

The raw IEEE 802.3ck-style S-parameter / COM reference channel packages are
large third-party/public contributed assets. They are tracked with Git LFS
when included in this repository, not as ordinary Git blobs. To reproduce the
full benchmark:

1. Clone the repository with Git LFS enabled, or download the public IEEE
   802.3ck channel packages from the official IEEE 802.3ck tools/channel
   public pages.
2. If using an external download, unpack them locally under:

   ```text
   data/8023ck_channels/
   ```

3. Keep or regenerate `data/8023ck_channels/channel_manifest.csv` so the
   benchmark code can locate the local channel files.

The code-oriented benchmark uses the Touchstone `.s4p` files and
`channel_manifest.csv`. The optional COM-reference material additionally keeps
the COM MATLAB reference scripts and `.xlsx` configuration sheets. Reference
PDFs, generated figures, MATLAB result files, and zip archives are intentionally
excluded from Git.
