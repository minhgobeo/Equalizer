"""Package the polished PAM4/HMM/MSB figures for paper use.

This script intentionally uses the polished root-level reference images:

    figure 1.png ... figure 9.png

Those images are the paper-ready infographic versions.  The older
`generate_pam4_hmm_figures_full.py` script is kept as a programmatic
Matplotlib reconstruction, but its aesthetics are not suitable for the
final manuscript without a larger redesign.

Outputs:
    pam4_hmm_figures_paper_ready/
        fig01_*.png
        fig01_*.svg   (SVG wrapper embedding the PNG)
        ...
        MANIFEST.md

The SVG wrapper is useful for tools that expect SVG import.  It is not a
fully editable vector reconstruction; it preserves the polished bitmap
exactly.
"""

from __future__ import annotations

import base64
import html
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "pam4_hmm_figures_paper_ready"


FIGURES = [
    (
        "figure 1.png",
        "fig01_overall_8023ck_pam4_benchmark_architecture",
        "Overall IEEE 802.3ck PAM-4 benchmark architecture",
    ),
    (
        "figure 2.png",
        "fig02_practical_8023ck_channel_asset_handling",
        "Practical IEEE 802.3ck channel asset handling",
    ),
    (
        "figure 3.png",
        "fig03_markov_sparameter_simulation_loop",
        "Markov S-parameter simulation loop",
    ),
    (
        "figure 4.png",
        "fig04_algorithm6_msb_firbank_online_dataflow",
        "Algorithm 6 MSB-FIRBank online dataflow",
    ),
    (
        "figure 5.png",
        "fig05_state_local_ffe_dfe_bank_structure",
        "State-local FFE/DFE bank structure inside Proposed MSB",
    ),
    (
        "figure 6.png",
        "fig06_training_and_decision_directed_update_schedule",
        "Training and decision-directed update schedule in Proposed MSB",
    ),
    (
        "figure 7.png",
        "fig07_single_bank_receiver_versus_proposed_msb",
        "Single-bank receiver versus Proposed MSB receiver",
    ),
    (
        "figure 8.png",
        "fig08_hmm_router_channel_state_classification",
        "HMM router for channel-state classification",
    ),
    (
        "figure 9.png",
        "fig09_endogenous_aware_noise_mechanism",
        "Endogenous-aware noise mechanism in the Proposed receiver",
    ),
]


def png_size(path: Path) -> tuple[int, int]:
    """Return PNG width/height without external dependencies."""
    with path.open("rb") as f:
        header = f.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG file: {path}")
    width = int.from_bytes(header[16:20], "big")
    height = int.from_bytes(header[20:24], "big")
    return width, height


def write_svg_wrapper(src_png: Path, dst_svg: Path, title: str) -> None:
    width, height = png_size(src_png)
    encoded = base64.b64encode(src_png.read_bytes()).decode("ascii")
    safe_title = html.escape(title)
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <title>{safe_title}</title>
  <image width="{width}" height="{height}" href="data:image/png;base64,{encoded}"/>
</svg>
"""
    dst_svg.write_text(svg, encoding="utf-8")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest_lines = [
        "# Paper-Ready PAM4/HMM/MSB Figures",
        "",
        "These figures are packaged from the polished root-level PNGs.",
        "They are intended for manuscript use.  The SVG files are wrappers",
        "that preserve the PNG exactly; they are not full vector redraws.",
        "",
        "| No. | File | Source | Size | Caption |",
        "|---:|---|---|---:|---|",
    ]

    for i, (src_name, stem, caption) in enumerate(FIGURES, start=1):
        src = ROOT / src_name
        if not src.exists():
            raise FileNotFoundError(f"Missing polished reference image: {src}")

        dst_png = OUT_DIR / f"{stem}.png"
        dst_svg = OUT_DIR / f"{stem}.svg"
        shutil.copy2(src, dst_png)
        write_svg_wrapper(dst_png, dst_svg, caption)
        width, height = png_size(dst_png)

        manifest_lines.append(
            f"| {i} | `{dst_png.name}` / `{dst_svg.name}` | `{src_name}` | "
            f"{width}x{height} | {caption} |"
        )
        print(f"[paper_ready] {src_name} -> {dst_png.name}, {dst_svg.name}")

    (OUT_DIR / "MANIFEST.md").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")
    print(f"[paper_ready] wrote {OUT_DIR / 'MANIFEST.md'}")


if __name__ == "__main__":
    main()
