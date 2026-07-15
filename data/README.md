# Data Policy

This repository is intended to track the MATLAB code, experiment runners,
plotting utilities, and small metadata files needed to reproduce the paper
workflow.

The raw IEEE 802.3ck-style S-parameter / COM reference channel packages are
large third-party/public contributed assets. They are therefore not committed
to normal Git by default. To reproduce the full benchmark:

1. Download the public IEEE 802.3ck channel packages from the official IEEE
   802.3ck tools/channel public pages.
2. Unpack them locally under:

   ```text
   data/8023ck_channels/
   ```

3. Keep or regenerate `data/8023ck_channels/channel_manifest.csv` so the
   benchmark code can locate the local channel files.

If raw Touchstone files must be archived with the code, use Git LFS or a
separate data release (for example Zenodo/OSF) and verify that redistribution
is allowed by the source material.
