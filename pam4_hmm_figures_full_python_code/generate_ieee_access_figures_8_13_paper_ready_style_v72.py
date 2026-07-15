r"""Generate paper-ready styled Figures 8-13 for the PAM4/HMM/MSB paper.

This script deliberately follows the visual language of the polished
`figure 1.png ... figure 9.png` assets: white canvas, thin rounded pastel
panels, compact mathematical labels, causal arrows, and manuscript-style
captions.  Figures 8 and 9 are copied from the existing polished references;
Figures 10-13 are redrawn programmatically in the same style.

Run from the project root:

    .\.uv-cache\archive-v0\7Vfg-B9IIYKx8A-HAIQu3\Scripts\python.exe \
        pam4_hmm_figures_full_python_code\generate_ieee_access_figures_8_13_paper_ready_style_v72.py

Outputs:
    paper_ieee_access_figure_pack_v72_paperready_style/
"""

from __future__ import annotations

import base64
import html
import math
import shutil
import textwrap
from pathlib import Path

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Rectangle, Polygon
import matplotlib.patheffects as pe


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "paper_ieee_access_figure_pack_v72_paperready_style"
OUT.mkdir(parents=True, exist_ok=True)

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "mathtext.fontset": "dejavuserif",
        "figure.dpi": 180,
        "savefig.dpi": 360,
    }
)


C = {
    "ink": "#111827",
    "muted": "#374151",
    "grid": "#D1D5DB",
    "blue": "#1F5B99",
    "blue2": "#EAF4FF",
    "purple": "#6D56A6",
    "purple2": "#F2ECFF",
    "green": "#4C8B3B",
    "green2": "#EDF8E9",
    "orange": "#B16900",
    "orange2": "#FFF3D8",
    "teal": "#047C7C",
    "teal2": "#E8FAFA",
    "red": "#B13A32",
    "red2": "#FDE9E7",
    "gray": "#5A5A5A",
    "gray2": "#F7F7F7",
}


def canvas():
    fig, ax = plt.subplots(figsize=(15.36, 10.24))
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")
    fig.patch.set_facecolor("white")
    return fig, ax


def save(fig, stem: str):
    png = OUT / f"{stem}.png"
    svg = OUT / f"{stem}.svg"
    fig.savefig(png, bbox_inches="tight", pad_inches=0.02, facecolor="white")
    fig.savefig(svg, bbox_inches="tight", pad_inches=0.02, facecolor="white")
    plt.close(fig)
    print(f"[paperready_style] wrote {png}")
    print(f"[paperready_style] wrote {svg}")


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        header = f.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG file: {path}")
    return int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")


def write_svg_wrapper(src_png: Path, dst_svg: Path, title: str):
    width, height = png_size(src_png)
    encoded = base64.b64encode(src_png.read_bytes()).decode("ascii")
    safe_title = html.escape(title)
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <title>{safe_title}</title>
  <image width="{width}" height="{height}" href="data:image/png;base64,{encoded}"/>
</svg>
"""
    dst_svg.write_text(svg, encoding="utf-8")


def copy_polished_reference(src_name: str, stem: str, caption: str):
    src = ROOT / src_name
    dst_png = OUT / f"{stem}.png"
    dst_svg = OUT / f"{stem}.svg"
    shutil.copy2(src, dst_png)
    write_svg_wrapper(dst_png, dst_svg, caption)
    print(f"[paperready_style] copied {src_name} -> {dst_png.name}")


def wrap_lines(lines, width=26):
    out: list[str] = []
    for line in lines:
        if line.startswith("$") or len(line) <= width:
            out.append(line)
        else:
            out.extend(textwrap.wrap(line, width=width))
    return out


def shadow_box(ax, x, y, w, h, fc, ec, lw=1.15, radius=0.014, linestyle="-", alpha=1.0):
    p = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle=f"round,pad=0.010,rounding_size={radius}",
        fc=fc,
        ec=ec,
        lw=lw,
        linestyle=linestyle,
        alpha=alpha,
        zorder=2,
    )
    p.set_path_effects([pe.SimplePatchShadow(offset=(1.0, -1.0), alpha=0.12), pe.Normal()])
    ax.add_patch(p)
    return p


def title(ax, text: str):
    ax.text(
        0.5,
        0.945,
        text,
        ha="center",
        va="center",
        fontsize=20,
        fontweight="bold",
        color=C["ink"],
    )


def caption(ax, fig_no: int, text: str):
    ax.text(
        0.5,
        0.045,
        rf"$\bf{{Figure\ {fig_no}.}}$ {text}",
        ha="center",
        va="center",
        fontsize=15,
        color=C["ink"],
        family="DejaVu Serif",
    )


def arrow(ax, x1, y1, x2, y2, color="#111111", lw=1.25, ms=13, rad=0.0, style="->", ls="-"):
    a = FancyArrowPatch(
        (x1, y1),
        (x2, y2),
        arrowstyle=style,
        mutation_scale=ms,
        lw=lw,
        color=color,
        linestyle=ls,
        connectionstyle=f"arc3,rad={rad}",
        zorder=10,
    )
    ax.add_patch(a)
    return a


def badge(ax, x, y, n, color):
    ax.add_patch(Circle((x, y), 0.023, fc="white", ec=color, lw=1.25, zorder=8))
    ax.text(x, y, str(n), ha="center", va="center", fontsize=13, fontweight="bold", zorder=9)


def card(
    ax,
    x,
    y,
    w,
    h,
    heading,
    lines,
    fc,
    ec,
    icon=None,
    heading_fs=10.5,
    body_fs=8.6,
    wrap=26,
):
    shadow_box(ax, x, y, w, h, fc, ec)
    ax.text(
        x + w / 2,
        y + h - 0.030,
        heading,
        ha="center",
        va="top",
        fontsize=heading_fs,
        fontweight="bold",
        color=C["ink"],
        linespacing=1.05,
    )
    if icon:
        draw_icon(ax, icon, x + 0.018, y + h * 0.43, min(w * 0.20, 0.065), min(h * 0.40, 0.075), ec)
        tx = x + w * 0.58
        ha = "center"
        max_width = wrap
    else:
        tx = x + w / 2
        ha = "center"
        max_width = wrap
    wrapped = wrap_lines(lines, max_width)
    ax.text(
        tx,
        y + h * 0.43,
        "\n".join(wrapped),
        ha=ha,
        va="center",
        fontsize=body_fs,
        fontweight="bold",
        color=C["ink"],
        linespacing=1.08,
    )


def draw_icon(ax, kind, x, y, w, h, color):
    if kind == "sparam":
        ax.add_patch(Rectangle((x + w * 0.28, y + h * 0.12), w * 0.33, h * 0.65, fc="white", ec=color, lw=1.0))
        ax.add_patch(Polygon(
            [[x + w * 0.50, y + h * 0.77], [x + w * 0.61, y + h * 0.64], [x + w * 0.61, y + h * 0.77]],
            fc="#EDF2F7",
            ec=color,
            lw=0.8,
        ))
        ax.text(x + w * 0.46, y + h * 0.02, ".s4p", ha="center", va="bottom", fontsize=7, color=color, fontweight="bold")
    elif kind == "freq":
        xs = np.linspace(0, 1, 80)
        for k, loss in enumerate([0.9, 1.25, 1.6]):
            yy = 0.82 - loss * (xs ** 1.35) * 0.45
            ax.plot(x + w * xs, y + h * yy, lw=1.2, color=[C["blue"], C["orange"], C["red"]][k])
        ax.plot([x, x + w], [y + h * 0.18, y + h * 0.18], color=C["gray"], lw=0.7)
        ax.plot([x, x], [y + h * 0.18, y + h * 0.88], color=C["gray"], lw=0.7)
    elif kind == "fir":
        base = y + h * 0.20
        vals = [0.82, 0.62, 0.48, 0.37, 0.29]
        ax.plot([x, x + w], [base, base], color=C["gray"], lw=0.7)
        for i, v in enumerate(vals):
            xx = x + w * (0.15 + i * 0.18)
            ax.plot([xx, xx], [base, y + h * v], color=color, lw=1.15)
            ax.scatter([xx], [y + h * v], s=16, color="#75AADB", edgecolor=color, zorder=8)
    elif kind == "bank":
        for i in range(3):
            yy = y + h * (0.18 + i * 0.24)
            ax.add_patch(Rectangle((x + w * 0.12, yy), w * 0.17, h * 0.12, fc="#BFD7EA", ec=color, lw=0.8))
            ax.plot([x + w * 0.34, x + w * 0.86], [yy + h * 0.06, yy + h * 0.06], color=color, lw=1.1)
    elif kind == "hmm":
        pts = [(0.22, 0.62), (0.50, 0.78), (0.78, 0.62), (0.50, 0.30)]
        for px, py in pts:
            ax.add_patch(Circle((x + w * px, y + h * py), min(w, h) * 0.09, fc="#F3E8FF", ec=color, lw=1.0))
        for a, b in [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2)]:
            arrow(ax, x + w * pts[a][0], y + h * pts[a][1], x + w * pts[b][0], y + h * pts[b][1], color=color, lw=0.7, ms=6)
    elif kind == "noise":
        xs = np.linspace(0, 1, 80)
        ax.plot(x + w * xs, y + h * (0.50 + 0.18 * np.sin(8 * np.pi * xs)), color=color, lw=1.1)
        rng = np.random.default_rng(7)
        ax.scatter(x + w * rng.random(32), y + h * (0.20 + 0.60 * rng.random(32)), s=4, color=color, alpha=0.65)
    elif kind == "eye":
        xs = np.linspace(0, 1, 120)
        for ph in [0, 0.5]:
            ax.plot(x + w * xs, y + h * (0.50 + 0.24 * np.sin(2 * np.pi * (xs + ph))), color=color, lw=1.0)
            ax.plot(x + w * xs, y + h * (0.50 - 0.24 * np.sin(2 * np.pi * (xs + ph))), color=color, lw=1.0, alpha=0.75)
        ax.plot([x, x + w], [y + h * 0.50, y + h * 0.50], color="#999999", lw=0.5, ls="--")
    elif kind == "waterfall":
        xs = np.linspace(0.05, 0.95, 9)
        ys = 0.80 * np.exp(-2.5 * xs) + 0.08
        ax.plot(x + w * xs, y + h * ys, "-o", color=color, lw=1.2, markersize=3)
    elif kind == "table":
        for i in range(4):
            for j in range(4):
                ax.add_patch(Rectangle((x + w * (0.10 + j * 0.18), y + h * (0.15 + i * 0.16)),
                                       w * 0.13, h * 0.11, fc="white", ec=color, lw=0.7))
    else:
        ax.add_patch(Circle((x + w / 2, y + h / 2), min(w, h) * 0.30, fc="white", ec=color, lw=1.0))


def mini_markov_chain(ax, x, y, w, h, color):
    states = [(0.22, 0.55, "10"), (0.50, 0.72, "14"), (0.78, 0.55, "16")]
    for px, py, label in states:
        ax.add_patch(Circle((x + w * px, y + h * py), min(w, h) * 0.10, fc="#F7FBFF", ec=color, lw=1.0, zorder=5))
        ax.text(x + w * px, y + h * py, label, ha="center", va="center", fontsize=8, fontweight="bold")
    for a, b in [(0, 1), (1, 2), (2, 1), (1, 0)]:
        arrow(ax, x + w * states[a][0], y + h * states[a][1], x + w * states[b][0], y + h * states[b][1],
              color=color, lw=0.7, ms=7, rad=0.1 if a < b else -0.1)


def fig10():
    fig, ax = canvas()
    title(ax, "Final Simulation Protocol and Evidence Chain")

    lane_y = [0.690, 0.440, 0.190]
    colors = [(C["blue"], C["blue2"]), (C["green"], C["green2"]), (C["purple"], C["purple2"])]
    labels = ["A", "B", "C"]
    headings = ["Controlled Markov-ISI", "802.3ck C2M Tracking Stress", "Endogenous-Aware Bridge"]
    sources = [
        [r"$h_2=\{0.30,0.50,0.70\}$", "mean-dwell matrix", "severe BER reference"],
        ["C2M 10/14/16 dB", "slow / medium / fast", "COM-style stress"],
        ["SMNLMS / SM-sign", "aware single-bank", "then full MSB"],
    ]
    mc = [
        ["SNR sweep", "full recursions", "BER / SER / eye"],
        ["state switching", "transition window", "recovery + routing"],
        ["update-rate sweep", "tail MSE", "burden proxy"],
    ]
    roles = [
        ["Theory stress: shows why state memories matter"],
        ["Application benchmark: realistic C2M tracking"],
        ["Mechanism bridge: explains the endogenous gate"],
    ]

    for i, y in enumerate(lane_y):
        ec, fc = colors[i]
        badge(ax, 0.055, y + 0.095, labels[i], ec)
        shadow_box(ax, 0.085, y, 0.855, 0.185, "#FFFFFF", ec, lw=1.0)
        ax.text(0.105, y + 0.155, headings[i], ha="left", va="center", fontsize=13, fontweight="bold", color=ec)
        card(ax, 0.105, y + 0.020, 0.215, 0.120, "Benchmark source",
             sources[i], fc, ec, None, 8.7, 6.8, 23)
        card(ax, 0.370, y + 0.020, 0.215, 0.120, "Monte Carlo run",
             mc[i], fc, ec, None, 8.7, 6.8, 23)
        card(ax, 0.635, y + 0.020, 0.250, 0.120, "Paper role",
             roles[i], fc, ec, None, 8.7, 6.8, 29)
        arrow(ax, 0.320, y + 0.080, 0.370, y + 0.080, color=ec, lw=1.0, ms=10)
        arrow(ax, 0.585, y + 0.080, 0.635, y + 0.080, color=ec, lw=1.0, ms=10)

    shadow_box(ax, 0.295, 0.088, 0.410, 0.060, "#FFF7ED", C["orange"], lw=1.0)
    ax.text(0.500, 0.118, "Unified output: BER/SER curves, eye tables, tracking diagnostics, and manuscript figures",
            ha="center", va="center", fontsize=10.5, fontweight="bold", color=C["ink"])
    caption(ax, 10, "Three-block simulation strategy connecting controlled theory, practical tracking stress, and the endogenous-aware ablation.")
    save(fig, "fig10_three_block_simulation_strategy_paperready")


def fig11():
    fig, ax = canvas()
    title(ax, "Role of Each Reference Baseline in the Final Comparison")

    center = (0.505, 0.515)
    shadow_box(ax, center[0] - 0.130, center[1] - 0.105, 0.260, 0.210, "#FFFFFF", C["red"], lw=1.5)
    ax.text(center[0], center[1] + 0.045, "Proposed MSB", ha="center", va="center", fontsize=17, fontweight="bold", color=C["red"])
    ax.text(center[0], center[1] - 0.010, "HMM/FIR routing\n+ state-local SMNLMS\n+ endogenous-aware gate",
            ha="center", va="center", fontsize=10.0, fontweight="bold", linespacing=1.15)
    draw_icon(ax, "bank", center[0] - 0.055, center[1] - 0.090, 0.110, 0.060, C["red"])

    items = [
        (0.075, 0.700, C["blue"], C["blue2"], "Gazor 2002", ["SMNLMS / ADFE", "set-membership update", "noise-bound motivation"], "gate"),
        (0.360, 0.730, C["purple"], C["purple2"], "Souza 2024", ["SM-sign-NLMS", "impulsive-noise robustness", "update probability"], "noise"),
        (0.645, 0.700, C["orange"], C["orange2"], "Liu 2023", ["PAM4 SS-LMS DFE", "tap adaptation", "lossy-channel eye"], "eye"),
        (0.075, 0.270, C["green"], C["green2"], "Chen pulse-ref", ["offline FFE/DFE reference", "pulse-response optimization", "eye-height benchmark"], "fir"),
        (0.360, 0.220, C["teal"], C["teal2"], "Cui ExtraTrees-HMM", ["sequence decoding baseline", "HMM-style temporal model", "not FIR-bank routing"], "hmm"),
        (0.645, 0.270, C["gray"], C["gray2"], "Algorithm 1", ["single-bank receiver", "same tap budget", "no state-local memory"], "bank"),
    ]
    for x, y, ec, fc, h, lines, icon in items:
        card(ax, x, y, 0.245, 0.145, h, lines, fc, ec, icon, 10.2, 7.5, 25)
        arrow(ax, x + 0.122, y + (0.020 if y > center[1] else 0.125), center[0], center[1] + (0.100 if y > center[1] else -0.100),
              color=ec, lw=0.9, ms=8, rad=0.05 if x < center[0] else -0.05)

    shadow_box(ax, 0.255, 0.090, 0.490, 0.070, "#F8FAFC", C["gray"], lw=0.95)
    ax.text(0.500, 0.125,
            "Interpretation: references are not replaced; each provides one fair baseline axis for the proposed architecture.",
            ha="center", va="center", fontsize=10.5, fontweight="bold", color=C["ink"])
    caption(ax, 11, "Positioning of literature baselines used to separate adaptive filtering, pulse-reference equalization, and sequence routing effects.")
    save(fig, "fig11_reference_baseline_positioning_paperready")


def fig12():
    fig, ax = canvas()
    title(ax, "802.3ck-Style Channel Processing and Impairment Stack")

    xs = [0.055, 0.205, 0.355, 0.505, 0.655, 0.805]
    w, h, y = 0.120, 0.245, 0.525
    steps = [
        ("Touchstone assets", [".s4p channel files", "C2M / C2C cases", "manifest-selected"], C["blue"], C["blue2"], "sparam"),
        ("Differential response", [r"$S_{dd21}(f)$", "relative insertion loss", "frequency grid"], C["blue"], C["blue2"], "freq"),
        ("Impulse response", ["PCHIP interpolation", "IFFT", "main cursor alignment"], C["green"], C["green2"], "fir"),
        ("Symbol FIR", [r"$h_s[k]$", "PAM4 symbol-spaced taps", "used by receiver banks"], C["green"], C["green2"], "fir"),
        ("Baud / Nyquist", ["26.5625 or 53.125 GBd", "higher f_Nyq", "more sampled loss"], C["purple"], C["purple2"], "waterfall"),
        ("Stress injection", ["AWGN", "NEXT/FEXT proxy", "jitter proxy"], C["orange"], C["orange2"], "noise"),
    ]
    for i, (heading, lines, ec, fc, icon) in enumerate(steps):
        card(ax, xs[i], y, w, h, heading, lines, fc, ec, icon, 7.9, 5.9, 17)
        badge(ax, xs[i] + w / 2, y + h + 0.055, i + 1, ec)
        if i < len(steps) - 1:
            arrow(ax, xs[i] + w + 0.012, y + h * 0.52, xs[i + 1] - 0.012, y + h * 0.52, color=C["ink"], lw=1.0, ms=10)

    # Frequency-loss overlay inset.
    shadow_box(ax, 0.075, 0.165, 0.355, 0.205, "#FFFFFF", C["blue"], lw=1.0)
    ax.text(0.253, 0.340, "|Sdd21| overlay for six C2M/C2C cases", ha="center", va="center",
            fontsize=10.5, fontweight="bold", color=C["blue"])
    px0, py0, pw, ph = 0.110, 0.195, 0.285, 0.105
    ax.plot([px0, px0 + pw], [py0, py0], color=C["gray"], lw=0.7)
    ax.plot([px0, px0], [py0, py0 + ph], color=C["gray"], lw=0.7)
    f = np.linspace(0, 1, 120)
    cols = [C["blue"], "#2CA25F", "#73A942", "#F59E0B", "#EF4444", "#7C3AED"]
    labels = ["C2M10", "C2M14", "C2M16", "C2C10", "C2C18", "C2C20"]
    losses = [0.28, 0.40, 0.48, 0.34, 0.58, 0.66]
    for k, loss in enumerate(losses):
        curve = 0.92 - loss * (f ** 1.35) - 0.035 * np.sin((k + 1) * np.pi * f)
        ax.plot(px0 + pw * f, py0 + ph * curve, lw=1.25, color=cols[k])
        ax.text(px0 + pw + 0.010, py0 + ph * curve[-1], labels[k], va="center", fontsize=6.7, color=cols[k])
    ax.text(px0 + pw * 0.50, py0 - 0.020, "Frequency", ha="center", fontsize=7.8)
    ax.text(px0 - 0.027, py0 + ph * 0.55, "Loss", ha="center", rotation=90, fontsize=7.8)

    # Impairment inset.
    shadow_box(ax, 0.535, 0.165, 0.355, 0.205, "#FFFFFF", C["orange"], lw=1.0)
    ax.text(0.713, 0.340, "COM-style receiver stress terms", ha="center", va="center",
            fontsize=10.5, fontweight="bold", color=C["orange"])
    cards = [
        (0.560, "AWGN", "thermal / receiver noise", C["blue"]),
        (0.675, "XTALK", "aggressor-lane coupling", C["red"]),
        (0.790, "Jitter", "timing uncertainty", C["purple"]),
    ]
    for x, name, desc, col in cards:
        shadow_box(ax, x, 0.205, 0.090, 0.085, "#FFFDF7", col, lw=0.8)
        draw_icon(ax, "noise" if name != "Jitter" else "waterfall", x + 0.018, 0.230, 0.052, 0.035, col)
        ax.text(x + 0.045, 0.224, name, ha="center", va="center", fontsize=8.0, fontweight="bold", color=col)
        ax.text(x + 0.045, 0.211, desc, ha="center", va="top", fontsize=5.7, color=C["ink"])

    caption(ax, 12, "Channel asset handling, frequency-dependent loss extraction, baud-rate sampling, and COM-style impairment injection.")
    save(fig, "fig12_channel_physics_impairment_stack_paperready")


def fig13():
    fig, ax = canvas()
    title(ax, "Metric Stack Produced by the Final Simulation Pack")

    top = [
        (0.080, C["blue"], C["blue2"], "BER / SER", ["waterfall vs SNR", "pre-FEC reference", "per recursion"], "waterfall"),
        (0.300, C["green"], C["green2"], "Eye metrics", ["eye height", "eye width", "eye area", "PAM4 top/mid/bot"], "eye"),
        (0.520, C["purple"], C["purple2"], "Tracking", ["transition-window BER", "recovery time", "error bursts"], "hmm"),
        (0.740, C["orange"], C["orange2"], "Router diagnostics", ["state accuracy", "wrong routing", "bank usage"], "bank"),
    ]
    for i, (x, ec, fc, h, lines, icon) in enumerate(top, 1):
        badge(ax, x + 0.090, 0.805, i, ec)
        card(ax, x, 0.630, 0.180, 0.145, h, lines, fc, ec, icon, 9.8, 7.1, 20)

    mid = [
        (0.170, C["gray"], C["gray2"], "Adaptation diagnostics", ["tail MSE", "tap convergence", "set-membership update rate"], "fir"),
        (0.505, C["gray"], C["gray2"], "Complexity diagnostics", ["multiplications / symbol", "memory and latency", "state-bank count"], "table"),
    ]
    for x, ec, fc, h, lines, icon in mid:
        card(ax, x, 0.390, 0.265, 0.140, h, lines, fc, ec, icon, 9.8, 7.2, 26)

    for x, *_ in top[:2]:
        arrow(ax, x + 0.090, 0.630, 0.302, 0.530, color=C["ink"], lw=1.0, ms=10)
    for x, *_ in top[2:]:
        arrow(ax, x + 0.090, 0.630, 0.637, 0.530, color=C["ink"], lw=1.0, ms=10)

    shadow_box(ax, 0.255, 0.185, 0.490, 0.110, C["red2"], C["red"], lw=1.15)
    draw_icon(ax, "table", 0.290, 0.210, 0.075, 0.055, C["red"])
    ax.text(0.520, 0.252, "Paper tables and final claims", ha="center", va="center",
            fontsize=12.5, fontweight="bold", color=C["ink"])
    ax.text(0.520, 0.218,
            "Table I: channel cases   |   Table II: BER/SER/eye   |   Table III: tracking/recovery",
            ha="center", va="center", fontsize=9.0, fontweight="bold", color=C["ink"])
    arrow(ax, 0.302, 0.390, 0.420, 0.295, color=C["ink"], lw=1.0, ms=10)
    arrow(ax, 0.637, 0.390, 0.580, 0.295, color=C["ink"], lw=1.0, ms=10)

    shadow_box(ax, 0.125, 0.095, 0.750, 0.050, "#FFFFFF", C["teal"], lw=0.9)
    ax.text(0.500, 0.120,
            "Main result narrative: controlled theory gain -> practical C2M tracking gain -> mechanism-level endogenous-aware ablation.",
            ha="center", va="center", fontsize=9.3, fontweight="bold", color=C["teal"])
    caption(ax, 13, "Metric stack connecting Monte Carlo curves, eye diagrams, routing diagnostics, adaptation traces, and paper tables.")
    save(fig, "fig13_metrics_stack_paperready")


def main():
    copy_polished_reference(
        "figure 8.png",
        "fig08_hmm_router_channel_state_classification_paperready",
        "HMM router for channel-state classification",
    )
    copy_polished_reference(
        "figure 9.png",
        "fig09_endogenous_aware_noise_mechanism_paperready",
        "Endogenous-aware noise mechanism in the Proposed receiver",
    )
    fig10()
    fig11()
    fig12()
    fig13()

    manifest = [
        "# Paper-Ready Style Figures 8-13 v72",
        "",
        "Figures 8 and 9 are copied from the polished root-level references.",
        "Figures 10-13 are generated in the same visual language.",
        "",
        "| No. | File stem | Purpose |",
        "|---:|---|---|",
        "| 8 | `fig08_hmm_router_channel_state_classification_paperready` | HMM router schematic. |",
        "| 9 | `fig09_endogenous_aware_noise_mechanism_paperready` | Endogenous-aware noise mechanism. |",
        "| 10 | `fig10_three_block_simulation_strategy_paperready` | Final three-block simulation protocol. |",
        "| 11 | `fig11_reference_baseline_positioning_paperready` | Literature baseline positioning. |",
        "| 12 | `fig12_channel_physics_impairment_stack_paperready` | Channel physics and impairment stack. |",
        "| 13 | `fig13_metrics_stack_paperready` | Result metrics stack. |",
        "",
    ]
    (OUT / "MANIFEST.md").write_text("\n".join(manifest), encoding="utf-8")
    print(f"[paperready_style] wrote {OUT / 'MANIFEST.md'}")


if __name__ == "__main__":
    main()
