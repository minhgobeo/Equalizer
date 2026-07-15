r"""Generate polished infographic-style Figures 10-13 for the PAM4/HMM/MSB paper.

This is a redesign of Figures 10-13 to visually match the polished
paper-ready Figures 8-9.  The figures use dense but readable infographic
layouts instead of sparse box diagrams.

Run from the project root:

    .\.uv-cache\archive-v0\7Vfg-B9IIYKx8A-HAIQu3\Scripts\python.exe \
        pam4_hmm_figures_full_python_code\generate_ieee_access_figures_10_13_infographic_v72.py

Outputs:
    paper_ieee_access_figure_pack_v72_infographic/
"""

from __future__ import annotations

from pathlib import Path
import math
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Rectangle, Polygon
import matplotlib.patheffects as pe


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "paper_ieee_access_figure_pack_v72_infographic"
OUT.mkdir(parents=True, exist_ok=True)

plt.rcParams.update({
    "font.family": "DejaVu Serif",
    "mathtext.fontset": "dejavuserif",
    "figure.dpi": 180,
    "savefig.dpi": 360,
})

C = {
    "ink": "#111827",
    "muted": "#4B5563",
    "line": "#1F2937",
    "blue": "#1F5B99",
    "blue2": "#EAF4FF",
    "blue3": "#BFD7EA",
    "purple": "#7057A8",
    "purple2": "#F1ECFF",
    "green": "#4C8B3B",
    "green2": "#EEF8EA",
    "orange": "#B16900",
    "orange2": "#FFF2D8",
    "teal": "#087F8C",
    "teal2": "#E7FAFB",
    "red": "#B13A32",
    "red2": "#FDE9E7",
    "gray": "#5B5B5B",
    "gray2": "#F6F6F6",
    "yellow": "#F2C94C",
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
    print(f"[infographic] wrote {png}")
    print(f"[infographic] wrote {svg}")


def shadow_box(ax, x, y, w, h, fc="white", ec="#333", lw=1.05, radius=0.010, ls="-", alpha=1.0, z=2):
    patch = FancyBboxPatch(
        (x, y), w, h,
        boxstyle=f"round,pad=0.008,rounding_size={radius}",
        fc=fc, ec=ec, lw=lw, linestyle=ls, alpha=alpha, zorder=z,
    )
    patch.set_path_effects([pe.SimplePatchShadow(offset=(0.9, -0.9), alpha=0.13), pe.Normal()])
    ax.add_patch(patch)
    return patch


def add_text(ax, x, y, text, fs=9, weight="normal", color=None, ha="center", va="center",
             style="normal", family=None, rotation=0):
    ax.text(
        x, y, text, fontsize=fs, fontweight=weight, color=color or C["ink"],
        ha=ha, va=va, linespacing=1.10, style=style, family=family or "DejaVu Serif",
        rotation=rotation, zorder=20,
    )


def caption(ax, no: int, text: str):
    add_text(ax, 0.5, 0.040, rf"$\bf{{Figure\ {no}.}}$ {text}", fs=15.0, family="DejaVu Serif")


def arrow(ax, x1, y1, x2, y2, color=None, lw=1.15, ms=12, rad=0.0, ls="-", style="->", z=12):
    a = FancyArrowPatch(
        (x1, y1), (x2, y2), arrowstyle=style, mutation_scale=ms,
        lw=lw, color=color or C["line"], linestyle=ls,
        connectionstyle=f"arc3,rad={rad}", zorder=z,
    )
    ax.add_patch(a)
    return a


def badge(ax, x, y, label, ec, fc="white", fs=13):
    ax.add_patch(Circle((x, y), 0.025, fc=fc, ec=ec, lw=1.25, zorder=14))
    add_text(ax, x, y, label, fs=fs, weight="bold")


def section_label(ax, x, y, text, color, fs=12.5):
    add_text(ax, x, y, text, fs=fs, weight="bold", color=color, ha="left")


def card(ax, x, y, w, h, title, body, fc, ec, fs_title=10.0, fs_body=7.8):
    shadow_box(ax, x, y, w, h, fc=fc, ec=ec, lw=1.05)
    add_text(ax, x + w/2, y + h - 0.026, title, fs=fs_title, weight="bold")
    add_text(ax, x + w/2, y + h*0.43, body, fs=fs_body, weight="bold")


def mini_ber(ax, x, y, w, h, color=C["blue"], second=C["gray"]):
    xs = np.linspace(0.08, 0.92, 11)
    y1 = 0.82 * np.exp(-3.7 * xs) + 0.08
    y2 = 0.70 * np.exp(-2.0 * xs) + 0.20
    ax.plot(x + w*xs, y + h*y2, "-o", color=second, lw=1.0, markersize=2.5, zorder=8)
    ax.plot(x + w*xs, y + h*y1, "-o", color=color, lw=1.4, markersize=3.0, zorder=9)
    ax.plot([x+w*0.08, x+w*0.92], [y+h*0.20, y+h*0.20], "--", color="#777", lw=0.65, zorder=7)
    add_text(ax, x+w*0.50, y+h*0.02, "SNR", fs=6.5)
    add_text(ax, x+w*0.02, y+h*0.50, "BER", fs=6.5, rotation=90)


def mini_eye(ax, x, y, w, h, color=C["blue"]):
    xs = np.linspace(0, 1, 160)
    for amp in [0.18, 0.30, 0.42]:
        ax.plot(x+w*xs, y+h*(0.50 + amp*np.sin(2*np.pi*xs)), color=color, lw=0.85, alpha=0.75)
        ax.plot(x+w*xs, y+h*(0.50 - amp*np.sin(2*np.pi*xs)), color=color, lw=0.85, alpha=0.75)
    ax.plot([x, x+w], [y+h*0.50, y+h*0.50], ":", color="#777", lw=0.6)


def mini_impulse(ax, x, y, w, h, color=C["green"]):
    base = y + h*0.22
    vals = [0.90, 0.60, 0.43, 0.33, 0.27]
    ax.plot([x+w*0.08, x+w*0.92], [base, base], color=C["muted"], lw=0.7)
    for i, v in enumerate(vals):
        xx = x + w*(0.16+i*0.16)
        yy = y + h*v
        ax.plot([xx, xx], [base, yy], color=color, lw=1.1)
        ax.scatter([xx], [yy], s=16, color="#9BD08D", edgecolor=color, zorder=8)


def mini_freq(ax, x, y, w, h):
    xs = np.linspace(0.02, 0.98, 120)
    cols = [C["blue"], "#2CA25F", "#73A942", "#F59E0B", "#EF4444", "#7C3AED"]
    losses = [0.25, 0.35, 0.45, 0.32, 0.58, 0.68]
    ax.plot([x+w*0.06, x+w*0.96], [y+h*0.15, y+h*0.15], color="#777", lw=0.6)
    ax.plot([x+w*0.06, x+w*0.06], [y+h*0.15, y+h*0.92], color="#777", lw=0.6)
    for k, loss in enumerate(losses):
        curve = 0.88 - loss*(xs**1.35) - 0.025*np.sin((k+1)*math.pi*xs)
        ax.plot(x+w*(0.06+0.88*xs), y+h*(0.15+0.75*curve), color=cols[k], lw=1.05)
    add_text(ax, x+w*0.50, y+h*0.01, "frequency", fs=6.4)
    add_text(ax, x+w*0.01, y+h*0.55, "loss", fs=6.4)


def mini_markov(ax, x, y, w, h, color=C["purple"]):
    pts = [(0.22, 0.50, "L"), (0.50, 0.72, "M"), (0.78, 0.50, "H")]
    for px, py, lab in pts:
        ax.add_patch(Circle((x+w*px, y+h*py), min(w, h)*0.090, fc="#F8F2FF", ec=color, lw=1.0, zorder=7))
        add_text(ax, x+w*px, y+h*py, lab, fs=7.5, weight="bold")
    for a, b, r in [(0, 1, 0.10), (1, 2, 0.10), (2, 1, -0.10), (1, 0, -0.10)]:
        arrow(ax, x+w*pts[a][0], y+h*pts[a][1], x+w*pts[b][0], y+h*pts[b][1], color=color, lw=0.75, ms=7, rad=r)


def mini_state_timeline(ax, x, y, w, h, color=C["purple"]):
    rng = np.random.default_rng(13)
    xx = np.linspace(0, 1, 55)
    st = np.ones_like(xx)
    p = 1
    for i in range(len(xx)):
        if rng.random() < 0.10:
            p = int(np.clip(p + rng.choice([-1, 1]), 0, 2))
        st[i] = p
    yy = 0.25 + 0.23*st
    ax.step(x+w*xx, y+h*yy, where="post", color=color, lw=1.2)
    for level in [0.25, 0.48, 0.71]:
        ax.plot([x, x+w], [y+h*level, y+h*level], ":", color="#999", lw=0.45)


def mini_noise(ax, x, y, w, h, color=None):
    xs = np.linspace(0, 1, 160)
    ax.plot(x+w*xs, y+h*(0.55 + 0.12*np.sin(10*np.pi*xs)), color=C["orange"], lw=1.0)
    ax.plot(x+w*xs, y+h*(0.50 + 0.16*np.sin(5*np.pi*xs+0.5)), color=C["red"], lw=0.9)
    rng = np.random.default_rng(5)
    ax.scatter(x+w*rng.random(35), y+h*(0.20+0.60*rng.random(35)), s=4, color=C["blue"], alpha=0.55)


def mini_bank(ax, x, y, w, h, color=C["red"]):
    for i, lab in enumerate(["B1", "B2", "B3"]):
        yy = y + h*(0.70 - i*0.25)
        ax.add_patch(Rectangle((x+w*0.12, yy), w*0.16, h*0.11, fc="#BFD7EA", ec=color, lw=0.8))
        ax.plot([x+w*0.34, x+w*0.88], [yy+h*0.055, yy+h*0.055], color=color, lw=1.0)
        add_text(ax, x+w*0.20, yy+h*0.055, lab, fs=5.5, weight="bold")


def mini_gate(ax, x, y, w, h, color=C["orange"]):
    xs = [0.08, 0.28, 0.28, 0.52, 0.52, 0.78, 0.78, 0.92]
    ys = [0.25, 0.25, 0.42, 0.42, 0.60, 0.60, 0.78, 0.78]
    ax.plot(x+w*np.array(xs), y+h*np.array(ys), color=color, lw=1.3)
    ax.plot([x+w*0.08, x+w*0.92], [y+h*0.50, y+h*0.50], ":", color="#777", lw=0.7)


def fig10():
    fig, ax = canvas()
    # Header ribbon
    add_text(ax, 0.50, 0.925, "Final Simulation Evidence Map", fs=22, weight="bold", family="DejaVu Sans")
    add_text(ax, 0.50, 0.892, "controlled theory -> realistic tracking stress -> endogenous-aware mechanism", fs=11.2, color=C["muted"], family="DejaVu Sans")

    blocks = [
        (0.045, 0.235, C["blue"], C["blue2"], "A", "Controlled Markov-ISI",
         [r"$h_2=\{0.30,0.50,0.70\}$", "mean-dwell transition matrix", "severe BER regime"],
         "Theory sanity check", mini_impulse),
        (0.365, 0.235, C["green"], C["green2"], "B", "802.3ck C2M Tracking",
         ["C2M 10 / 14 / 16 dB", "slow, medium, fast switching", "COM-style stress"],
         "Main application result", mini_state_timeline),
        (0.685, 0.235, C["purple"], C["purple2"], "C", "Endogenous-Aware Bridge",
         ["SMNLMS vs SM-sign", "aware single-bank gate", "then full MSB receiver"],
         "Mechanism ablation", mini_gate),
    ]
    for x, y, ec, fc, lab, head, bullets, role, icon_fn in blocks:
        shadow_box(ax, x, y, 0.270, 0.570, "#FFFFFF", ec, lw=1.2)
        badge(ax, x+0.030, y+0.530, lab, ec, fs=14)
        add_text(ax, x+0.150, y+0.530, head, fs=14, weight="bold", color=ec, family="DejaVu Sans")
        shadow_box(ax, x+0.030, y+0.365, 0.210, 0.120, fc, ec, lw=0.9)
        icon_fn(ax, x+0.050, y+0.388, 0.060, 0.065, ec) if icon_fn is mini_impulse else icon_fn(ax, x+0.050, y+0.388, 0.070, 0.065, ec)
        add_text(ax, x+0.155, y+0.425, "\n".join(bullets), fs=7.7, weight="bold", family="DejaVu Sans")
        shadow_box(ax, x+0.030, y+0.220, 0.210, 0.100, "#FFFFFF", ec, lw=0.8)
        mini_ber(ax, x+0.050, y+0.235, 0.060, 0.060, ec)
        add_text(ax, x+0.162, y+0.270, "Monte Carlo\nSNR sweep", fs=8.0, weight="bold", family="DejaVu Sans")
        shadow_box(ax, x+0.030, y+0.090, 0.210, 0.080, fc, ec, lw=0.8)
        add_text(ax, x+0.135, y+0.130, role, fs=8.8, weight="bold", family="DejaVu Sans")

    arrow(ax, 0.315, 0.520, 0.365, 0.520, color=C["line"], lw=1.1, ms=12)
    arrow(ax, 0.635, 0.520, 0.685, 0.520, color=C["line"], lw=1.1, ms=12)

    shadow_box(ax, 0.195, 0.110, 0.610, 0.070, "#FFF8EC", C["orange"], lw=1.0)
    add_text(ax, 0.500, 0.145, "Unified paper outputs: BER/SER curves, eye tables, recovery metrics, state-routing diagnostics", fs=10.8, weight="bold", family="DejaVu Sans")
    caption(ax, 10, "Final simulation evidence map used to connect controlled theory, realistic tracking stress, and the endogenous-aware ablation.")
    save(fig, "fig10_simulation_evidence_map_infographic")


def fig11():
    fig, ax = canvas()
    add_text(ax, 0.50, 0.925, "Reference Baselines and What They Test", fs=21, weight="bold", family="DejaVu Sans")
    add_text(ax, 0.50, 0.892, "each reference supplies one comparison axis; the proposed receiver combines the axes", fs=11.0, color=C["muted"], family="DejaVu Sans")

    shadow_box(ax, 0.372, 0.350, 0.256, 0.255, "#FFFFFF", C["red"], lw=1.45)
    add_text(ax, 0.500, 0.540, "Proposed MSB", fs=18, weight="bold", color=C["red"], family="DejaVu Sans")
    add_text(ax, 0.500, 0.485, "HMM/FIR routing\nstate-local SMNLMS\nendogenous-aware gate", fs=10.2, weight="bold", family="DejaVu Sans")
    mini_bank(ax, 0.455, 0.370, 0.090, 0.075, C["red"])

    nodes = [
        (0.065, 0.660, 0.245, 0.142, C["blue"], C["blue2"], "Gazor 2002", "SMNLMS / ADFE\nset-membership baseline\nnoise-bound adaptation", mini_gate),
        (0.378, 0.695, 0.245, 0.142, C["purple"], C["purple2"], "Souza 2024", "SM-sign-NLMS\nrobust signed update\nupdate probability", mini_noise),
        (0.690, 0.660, 0.245, 0.142, C["orange"], C["orange2"], "Liu 2023", "PAM4 SS-LMS DFE\ntap adaptation\nlossy-channel eye", mini_eye),
        (0.065, 0.205, 0.245, 0.142, C["green"], C["green2"], "Chen pulse-ref", "offline FFE/DFE reference\npulse-response optimization\neye-height target", mini_impulse),
        (0.378, 0.160, 0.245, 0.142, C["teal"], C["teal2"], "Cui ExtraTrees-HMM", "sequence decoder baseline\nHMM temporal model\nnot FIR-bank routing", mini_markov),
        (0.690, 0.205, 0.245, 0.142, C["gray"], C["gray2"], "Algorithm 1", "single-bank receiver\nsame tap budget\nno state-local memory", mini_bank),
    ]
    for x, y, w, h, ec, fc, name, desc, icon in nodes:
        shadow_box(ax, x, y, w, h, fc, ec, lw=1.05)
        icon(ax, x+0.020, y+0.042, 0.070, 0.065, ec)
        add_text(ax, x+0.155, y+0.094, name, fs=10.7, weight="bold", family="DejaVu Sans")
        add_text(ax, x+0.155, y+0.052, desc, fs=7.3, weight="bold", family="DejaVu Sans")
        arrow(ax, x+w/2, y+(0.010 if y > 0.5 else h-0.010), 0.500, 0.585 if y > 0.5 else 0.350,
              color=ec, lw=0.9, ms=8, rad=0.05 if x < 0.5 else -0.05)

    shadow_box(ax, 0.232, 0.080, 0.536, 0.072, "#F8FAFC", C["gray"], lw=0.9)
    add_text(ax, 0.500, 0.116, "Fairness rule: baselines use matched FFE/DFE tap budgets where applicable; oracle/reference curves are labeled separately.", fs=9.3, weight="bold", family="DejaVu Sans")
    caption(ax, 11, "Reference-baseline map separating adaptive filtering, robust set-membership updates, pulse-reference equalization, and sequence routing.")
    save(fig, "fig11_reference_baseline_map_infographic")


def fig12():
    fig, ax = canvas()
    add_text(ax, 0.50, 0.925, "802.3ck-Style Channel Physics and Receiver Stress", fs=21, weight="bold", family="DejaVu Sans")
    add_text(ax, 0.50, 0.892, "from public S-parameter assets to symbol-spaced PAM4 channel taps and impairment injection", fs=10.8, color=C["muted"], family="DejaVu Sans")

    # Top signal-processing path
    steps = [
        (0.055, C["blue"], C["blue2"], "Touchstone\nassets", ".s4p\nC2M/C2C cases"),
        (0.200, C["blue"], C["blue2"], "Differential\nresponse", r"$S_{dd21}(f)$"+"\nrelative loss"),
        (0.345, C["green"], C["green2"], "Time\nresponse", "PCHIP grid\nIFFT alignment"),
        (0.490, C["green"], C["green2"], "Symbol FIR", r"$h_s[k]$"+"\nPAM4 taps"),
        (0.635, C["purple"], C["purple2"], "Baud /\nNyquist", "26.5625 / 53.125\nGBd sampling"),
        (0.780, C["orange"], C["orange2"], "Receiver\nstress", "AWGN + XTALK\n+ jitter proxy"),
    ]
    for i, (x, ec, fc, head, body) in enumerate(steps):
        badge(ax, x+0.070, 0.805, str(i+1), ec)
        shadow_box(ax, x, 0.560, 0.118, 0.205, fc, ec, lw=1.05)
        add_text(ax, x+0.059, 0.720, head, fs=10.0, weight="bold", family="DejaVu Sans")
        if i == 1:
            mini_freq(ax, x+0.030, 0.610, 0.060, 0.055)
        elif i in [2, 3]:
            mini_impulse(ax, x+0.030, 0.610, 0.058, 0.055, ec)
        elif i == 4:
            mini_ber(ax, x+0.032, 0.610, 0.055, 0.052, ec)
        elif i == 5:
            mini_noise(ax, x+0.030, 0.610, 0.060, 0.055)
        else:
            add_text(ax, x+0.059, 0.635, ".s4p", fs=10, weight="bold", color=ec, family="DejaVu Sans")
        add_text(ax, x+0.059, 0.588, body, fs=6.5, weight="bold", family="DejaVu Sans")
        if i < len(steps)-1:
            arrow(ax, x+0.118, 0.663, steps[i+1][0], 0.663, color=C["line"], lw=1.0, ms=9)

    # Lower analytic panels
    shadow_box(ax, 0.070, 0.205, 0.395, 0.240, "#FFFFFF", C["blue"], lw=1.05)
    add_text(ax, 0.267, 0.410, "Frequency-domain severity check", fs=12.2, weight="bold", color=C["blue"], family="DejaVu Sans")
    mini_freq(ax, 0.112, 0.250, 0.265, 0.115)
    add_text(ax, 0.397, 0.306, "C2M/C2C overlay\nshows which links\ncarry heavier loss", fs=7.4, weight="bold", family="DejaVu Sans")

    shadow_box(ax, 0.535, 0.205, 0.395, 0.240, "#FFFFFF", C["orange"], lw=1.05)
    add_text(ax, 0.733, 0.410, "Impairment-stack interpretation", fs=12.2, weight="bold", color=C["orange"], family="DejaVu Sans")
    sub = [(0.565, "AWGN", C["blue"], "receiver noise"), (0.690, "XTALK", C["red"], "aggressor lanes"), (0.815, "Jitter", C["purple"], "timing error")]
    for x, name, col, desc in sub:
        shadow_box(ax, x, 0.270, 0.095, 0.085, "#FFFDF7", col, lw=0.85)
        if name == "Jitter":
            mini_ber(ax, x+0.020, 0.303, 0.055, 0.030, col)
        else:
            xs = np.linspace(0, 1, 60)
            ax.plot(x+0.020+0.055*xs, 0.315+0.015*np.sin(7*np.pi*xs), color=col, lw=1.2)
        add_text(ax, x+0.047, 0.290, name, fs=8.5, weight="bold", color=col, family="DejaVu Sans")
        add_text(ax, x+0.047, 0.255, desc, fs=6.3, family="DejaVu Sans")

    caption(ax, 12, "Channel-processing path and impairment stack used to justify the realistic C2M tracking-stress benchmark.")
    save(fig, "fig12_channel_physics_impairment_infographic")


def fig13():
    fig, ax = canvas()
    add_text(ax, 0.50, 0.925, "Final Results Dashboard and Paper Metrics", fs=21, weight="bold", family="DejaVu Sans")
    add_text(ax, 0.50, 0.892, "the simulation pack turns each run into curves, eye summaries, routing diagnostics, and final tables", fs=10.8, color=C["muted"], family="DejaVu Sans")

    panels = [
        (0.055, 0.575, C["blue"], C["blue2"], "BER / SER", "waterfall vs SNR\npre-FEC line\nper recursion", mini_ber),
        (0.285, 0.575, C["green"], C["green2"], "Eye opening", "height / width / area\nPAM4 top-mid-bottom\nreceiver-stage eye", mini_eye),
        (0.515, 0.575, C["purple"], C["purple2"], "Tracking", "transition-window BER\nrecovery time\nerror bursts", mini_state_timeline),
        (0.745, 0.575, C["orange"], C["orange2"], "Routing", "state accuracy\nwrong routing\nbank usage", mini_bank),
    ]
    for i, (x, y, ec, fc, head, body, icon) in enumerate(panels, 1):
        badge(ax, x+0.085, y+0.180, str(i), ec)
        shadow_box(ax, x, y, 0.180, 0.155, fc, ec, lw=1.05)
        icon(ax, x+0.020, y+0.055, 0.060, 0.060, ec) if icon not in [mini_ber, mini_eye, mini_state_timeline] else icon(ax, x+0.020, y+0.055, 0.060, 0.060, ec)
        add_text(ax, x+0.120, y+0.107, head, fs=10.8, weight="bold", family="DejaVu Sans")
        add_text(ax, x+0.120, y+0.060, body, fs=7.0, weight="bold", family="DejaVu Sans")

    shadow_box(ax, 0.185, 0.335, 0.270, 0.135, C["gray2"], C["gray"], lw=0.95)
    mini_impulse(ax, 0.215, 0.375, 0.065, 0.055, C["gray"])
    add_text(ax, 0.345, 0.405, "Adaptation diagnostics", fs=11.5, weight="bold", family="DejaVu Sans")
    add_text(ax, 0.345, 0.365, "tail MSE | tap convergence\nset-membership update rate", fs=7.4, weight="bold", family="DejaVu Sans")
    shadow_box(ax, 0.545, 0.335, 0.270, 0.135, C["gray2"], C["gray"], lw=0.95)
    add_text(ax, 0.590, 0.395, "×", fs=25, weight="bold", color=C["gray"], family="DejaVu Sans")
    add_text(ax, 0.695, 0.405, "Complexity diagnostics", fs=11.5, weight="bold", family="DejaVu Sans")
    add_text(ax, 0.695, 0.365, "multiplications/symbol\nmemory, latency, bank count", fs=7.4, weight="bold", family="DejaVu Sans")

    for x in [0.145, 0.375]:
        arrow(ax, x, 0.575, 0.320, 0.470, lw=1.0, ms=10)
    for x in [0.605, 0.835]:
        arrow(ax, x, 0.575, 0.680, 0.470, lw=1.0, ms=10)

    shadow_box(ax, 0.255, 0.155, 0.490, 0.105, C["red2"], C["red"], lw=1.1)
    add_text(ax, 0.500, 0.223, "Paper tables and final claims", fs=13.0, weight="bold", family="DejaVu Sans")
    add_text(ax, 0.500, 0.185, "Table I: channels   |   Table II: BER/SER/eye   |   Table III: tracking/recovery", fs=9.0, weight="bold", family="DejaVu Sans")
    arrow(ax, 0.320, 0.335, 0.430, 0.260, lw=1.0, ms=10)
    arrow(ax, 0.680, 0.335, 0.570, 0.260, lw=1.0, ms=10)

    caption(ax, 13, "Metric dashboard connecting Monte Carlo curves, eye diagrams, routing diagnostics, adaptation traces, complexity, and final paper tables.")
    save(fig, "fig13_results_dashboard_infographic")


def main():
    fig10()
    fig11()
    fig12()
    fig13()
    manifest = [
        "# Infographic Figures 10-13 v72",
        "",
        "These are redesigned to better match the polished Figures 8-9.",
        "",
        "| Figure | File stem |",
        "|---:|---|",
        "| 10 | `fig10_simulation_evidence_map_infographic` |",
        "| 11 | `fig11_reference_baseline_map_infographic` |",
        "| 12 | `fig12_channel_physics_impairment_infographic` |",
        "| 13 | `fig13_results_dashboard_infographic` |",
        "",
    ]
    (OUT / "MANIFEST.md").write_text("\n".join(manifest), encoding="utf-8")
    print(f"[infographic] wrote {OUT / 'MANIFEST.md'}")


if __name__ == "__main__":
    main()
