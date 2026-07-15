r"""Generate polished IEEE Access-style Figures 8-13 for the PAM4 MSB project.

This script uses the repo-local Python environment with matplotlib.  It is
kept separate from the MATLAB figure generator so the user can compare both
styles before choosing the final manuscript set.

Run from the project root:

    .\.uv-cache\archive-v0\7Vfg-B9IIYKx8A-HAIQu3\Scripts\python.exe \
        pam4_hmm_figures_full_python_code\generate_ieee_access_figures_8_13_python_v72.py

Outputs:
    paper_ieee_access_figure_pack_v72_python/
        fig08_*.png/.svg
        ...
        MANIFEST.md
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
OUT = ROOT / "paper_ieee_access_figure_pack_v72_python"
OUT.mkdir(parents=True, exist_ok=True)

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "figure.dpi": 180,
    "savefig.dpi": 360,
})


C = {
    "blue": "#174F8A", "blue2": "#EAF4FF",
    "green": "#2B6D2E", "green2": "#EAF8E8",
    "purple": "#6A44A0", "purple2": "#F3ECFF",
    "orange": "#9A6100", "orange2": "#FFF3D7",
    "red": "#A9342A", "red2": "#FFE9E6",
    "gray": "#404040", "gray2": "#F3F3F3",
    "ink": "#111111", "muted": "#4B4B4B",
}


def canvas(title: str):
    fig, ax = plt.subplots(figsize=(15.8, 10.2))
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")
    fig.patch.set_facecolor("white")
    # Subtle radial paper background.
    x = np.linspace(-1, 1, 400)
    y = np.linspace(-1, 1, 300)
    xx, yy = np.meshgrid(x, y)
    bg = 0.988 - 0.020 * np.exp(-1.8 * (xx**2 + yy**2))
    ax.imshow(np.dstack([bg, bg, bg]), extent=[0, 1, 0, 1], origin="lower", zorder=-20)
    ax.text(0.5, 0.93, title, ha="center", va="center",
            fontsize=17.5, weight="bold", color=C["ink"])
    return fig, ax


def save(fig, stem: str):
    png = OUT / f"{stem}.png"
    svg = OUT / f"{stem}.svg"
    fig.savefig(png, bbox_inches="tight", pad_inches=0.06, facecolor="white")
    fig.savefig(svg, bbox_inches="tight", pad_inches=0.06, facecolor="white")
    plt.close(fig)
    print(f"[py_figs] wrote {png}")
    print(f"[py_figs] wrote {svg}")


def dashed_group(ax, x, y, w, h, label: str, color: str):
    patch = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.006,rounding_size=0.018",
        fc=(1, 1, 1, 0.15), ec=color, lw=1.6, linestyle=(0, (4, 4)), zorder=1,
    )
    ax.add_patch(patch)
    ax.text(x + 0.018, y + h - 0.038, label, ha="left", va="center",
            fontsize=9.2, weight="bold", color=color, zorder=5)
    return patch


def card(ax, x, y, w, h, title: str, lines=(), fc="#FFFFFF", ec="#333333",
         icon: str | None = None, title_size=8.4, body_size=6.5):
    shadow = FancyBboxPatch((x + 0.006, y - 0.006), w, h,
                            boxstyle="round,pad=0.010,rounding_size=0.009",
                            fc="#C9D1D9", ec="none", alpha=0.42, zorder=2)
    ax.add_patch(shadow)
    patch = FancyBboxPatch((x, y), w, h,
                           boxstyle="round,pad=0.010,rounding_size=0.009",
                           fc=fc, ec=ec, lw=1.35, zorder=3)
    patch.set_path_effects([pe.Normal()])
    ax.add_patch(patch)

    if icon:
        draw_icon(ax, icon, x + 0.018, y + h * 0.28, min(0.055, w * 0.24), h * 0.46, ec)
        text_x = x + w * 0.63
        text_w = w * 0.62
    else:
        text_x = x + w * 0.50
        text_w = w * 0.90

    ax.text(text_x, y + h * 0.62, title, ha="center", va="center",
            fontsize=title_size, weight="bold", color=C["ink"], zorder=5)
    if isinstance(lines, str):
        lines = [lines]
    ax.text(text_x, y + h * 0.34, "\n".join(lines), ha="center", va="center",
            fontsize=body_size, weight="bold", color="#222222", linespacing=1.12, zorder=5)
    return patch


def arrow(ax, x1, y1, x2, y2, color="#202020", rad=0.0, lw=1.25, style="->"):
    arr = FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style, mutation_scale=14,
                          lw=lw, color=color, connectionstyle=f"arc3,rad={rad}", zorder=10)
    ax.add_patch(arr)
    return arr


def caption(ax, text: str):
    ax.text(0.5, 0.055, text, ha="center", va="center",
            fontsize=9.8, color="#222222", zorder=10)


def draw_icon(ax, name: str, x, y, w, h, color):
    name = name.lower()
    cx, cy = x + w/2, y + h/2
    if name in ("fir", "bank", "dfe"):
        base = y + h * 0.22
        ax.plot([x+w*.12, x+w*.88], [base, base], color=color, lw=1.0, zorder=6)
        vals = [0.30, 0.70, 0.50, 0.38, 0.26]
        for i, val in enumerate(vals):
            xx = x + w * (0.20 + 0.15*i)
            yy = y + h * (0.25 + 0.55*val)
            ax.plot([xx, xx], [base, yy], color=color, lw=1.0, zorder=6)
            ax.plot(xx, yy, "o", ms=3.2, mec=color, mfc="#4A85C5", zorder=7)
    elif name == "residual":
        t = np.linspace(0, 1, 80)
        ax.plot(x+w*(.12+.76*t), y+h*(.50+.22*np.sin(4*np.pi*t)),
                color=color, lw=1.15, zorder=6)
        ax.plot([x+w*.15, x+w*.86], [cy, cy], ":", color="#777777", lw=.8, zorder=6)
    elif name in ("ewma", "loss"):
        t = np.linspace(0, 1, 70)
        yy = .72 - .52*t + .04*np.sin(7*np.pi*t)
        ax.plot(x+w*(.12+.76*t), y+h*yy, color=color, lw=1.25, zorder=6)
        ax.plot(x+w*(.12+.76*t[::12]), y+h*yy[::12], "o", ms=2.8, mec=color, mfc="#4A85C5", zorder=7)
    elif name == "matrix":
        for i in range(3):
            for j in range(3):
                fc = "#C9E7BD" if i == j else "white"
                ax.add_patch(Rectangle((x+w*(.18+.17*j), y+h*(.20+.17*i)),
                                       w*.13, h*.13, fc=fc, ec=color, lw=.55, zorder=6))
    elif name == "posterior":
        vals = [0.25, 0.52, 0.38, 0.68]
        for i, val in enumerate(vals):
            ax.add_patch(Rectangle((x+w*(.22+.14*i), y+h*.18), w*.075, h*val*.60,
                                   fc="#4A85C5", ec=color, lw=.55, zorder=6))
    elif name in ("step", "gate", "threshold"):
        ax.plot([x+w*.12, x+w*.34, x+w*.34, x+w*.58, x+w*.58, x+w*.84],
                [y+h*.28, y+h*.28, y+h*.47, y+h*.47, y+h*.68, y+h*.68],
                color=color, lw=1.3, zorder=6)
        ax.plot([x+w*.12, x+w*.84], [y+h*.50, y+h*.50], ":", color="#B0B0B0", lw=.7, zorder=5)
    elif name == "sparam":
        ax.add_patch(Rectangle((x+w*.32, y+h*.24), w*.36, h*.52, fc="white", ec=color, lw=1.0, zorder=6))
        ax.text(cx, cy, ".s4p", ha="center", va="center", fontsize=7, weight="bold", color=color, zorder=7)
    elif name == "hmm":
        xs = [x+w*.25, x+w*.55, x+w*.75]
        ys = [y+h*.50, y+h*.70, y+h*.42]
        ax.plot(xs, ys, "-", color=color, lw=1.0, zorder=5)
        for i, (xx, yy) in enumerate(zip(xs, ys), 1):
            ax.add_patch(Circle((xx, yy), w*.09, fc="#F4F4FF", ec=color, lw=1.0, zorder=6))
            ax.text(xx, yy, str(i), ha="center", va="center", fontsize=6.5, weight="bold", color=color, zorder=7)
    elif name == "shield":
        pts = np.array([[.50,.84],[.78,.67],[.70,.34],[.50,.16],[.30,.34],[.22,.67]])
        ax.add_patch(Polygon(np.column_stack([x+w*pts[:,0], y+h*pts[:,1]]),
                             fc="#D9F0D3", ec=color, lw=1.1, zorder=6))
        ax.plot([x+w*.36, x+w*.47, x+w*.66], [y+h*.48, y+h*.35, y+h*.58],
                color=color, lw=1.6, zorder=7)
    elif name == "eye":
        t = np.linspace(0, 2, 120)
        ax.plot(x+w*(.08+.84*t/2), y+h*(.50+.23*np.sin(np.pi*t)), color=color, lw=1.1, zorder=6)
        ax.plot(x+w*(.08+.84*t/2), y+h*(.50-.23*np.sin(np.pi*t)), color=color, lw=1.1, zorder=6)
    elif name == "impair":
        t = np.linspace(0, 1, 70)
        ax.plot(x+w*(.13+.74*t), y+h*(.50+.16*np.sin(8*np.pi*t)+.05*np.sin(23*np.pi*t)),
                color=color, lw=1.0, zorder=6)
        ax.plot([x+w*.25, x+w*.75], [y+h*.30, y+h*.72], color="#C9452E", lw=1.0, zorder=6)
        ax.plot([x+w*.25, x+w*.75], [y+h*.72, y+h*.30], color="#2E6BC9", lw=1.0, zorder=6)
    elif name == "tree":
        ax.plot([cx, cx], [y+h*.76, y+h*.52], color=color, lw=1.0, zorder=6)
        ax.plot([cx, x+w*.30], [y+h*.52, y+h*.30], color=color, lw=1.0, zorder=6)
        ax.plot([cx, x+w*.70], [y+h*.52, y+h*.30], color=color, lw=1.0, zorder=6)
        ax.plot([cx, x+w*.30, x+w*.70], [y+h*.76, y+h*.30, y+h*.30], "o", ms=3.2,
                mec=color, mfc="#D9F0D3", zorder=7)
    else:
        ax.add_patch(Circle((cx, cy), min(w, h)*.22, fc="white", ec=color, lw=1.0, zorder=6))
        ax.text(cx, cy, "i", ha="center", va="center", fontsize=12, weight="bold", color=color, zorder=7)


def fig08():
    fig, ax = canvas("HMM/FIR Router for Algorithm 6")
    dashed_group(ax, .050, .220, .900, .625,
                 "Forward Bayesian routing recursion during decision-directed tracking", C["gray"])
    dashed_group(ax, .080, .315, .245, .455, "1. FIR evidence", C["blue"])
    card(ax, .105, .620, .195, .100, "State FIR bank", ["h_s[k] from Sdd21", "one hypothesis per bank"], C["blue2"], C["blue"], "fir")
    card(ax, .105, .480, .195, .100, "Bank-local memory", ["d_hat_per_bank(:,s)", "feedback history"], C["blue2"], C["blue"], "bank")
    card(ax, .105, .345, .195, .095, "Residual emission", ["score_s = (r(m)-pred_s)^2"], C["red2"], C["red"], "residual")

    dashed_group(ax, .385, .315, .250, .455, "2. HMM filtering", C["green"])
    card(ax, .410, .620, .200, .100, "Cost memory", ["J_s <- rho J_s", "+ (1-rho)score_s"], C["purple2"], C["purple"], "ewma")
    card(ax, .410, .480, .200, .100, "Markov prior", ["pi_pred = P_hmm^T pi"], C["green2"], C["green"], "matrix")
    card(ax, .410, .345, .200, .095, "Posterior", ["pi_s proportional", "pi_pred_s exp(-rel/tau)"], C["green2"], C["green"], "posterior")

    dashed_group(ax, .700, .315, .220, .455, "3. Route and update", C["orange"])
    card(ax, .725, .620, .170, .100, "MAP state", ["s_hat = argmax pi_s"], C["orange2"], C["orange"], "posterior")
    card(ax, .725, .480, .170, .100, "Selected output", ["d_hat(m)", "from bank s_hat"], C["orange2"], C["orange"], "threshold")
    card(ax, .725, .345, .170, .095, "Local update", ["theta_s_hat only", "plus local memory"], C["gray2"], C["gray"], "dfe")

    arrow(ax, .325, .535, .385, .535)
    arrow(ax, .635, .535, .700, .535)
    card(ax, .110, .125, .240, .072, "Code-faithful emission", ["FIR residual likelihood, not ExtraTrees emission"], C["blue2"], C["blue"], None)
    card(ax, .390, .125, .220, .072, "Transition prior", ["benchmark/state prior P_hmm"], C["green2"], C["green"], "matrix")
    card(ax, .650, .125, .240, .072, "Stored diagnostics", ["pi_hist, J_hist, s_hat_hist, bank usage"], C["orange2"], C["orange"], "posterior")
    caption(ax, "Figure 8. Code-faithful HMM/FIR router for channel-state classification and active-bank selection.")
    save(fig, "fig08_python_hmm_fir_router")


def fig09():
    fig, ax = canvas("Endogenous-Aware SMNLMS Gate")
    dashed_group(ax, .055, .205, .280, .620, "Reliability and burden signals", C["blue"])
    dashed_group(ax, .375, .205, .260, .620, "Adaptive set-membership gate", C["purple"])
    dashed_group(ax, .690, .205, .260, .620, "Selected bank update", C["orange"])
    card(ax, .085, .660, .105, .105, "H(pi)", ["posterior", "entropy"], C["blue2"], C["blue"], "loss", 7.4, 5.9)
    card(ax, .205, .660, .105, .105, "1-max(pi)", ["confidence", "uncertainty"], C["blue2"], C["blue"], "posterior", 7.4, 5.9)
    card(ax, .085, .465, .105, .105, "cross", ["state-memory", "burden"], C["blue2"], C["blue"], "hmm", 7.4, 5.9)
    card(ax, .205, .465, .105, .105, "DD load", ["slicer", "reliability"], C["blue2"], C["blue"], "threshold", 7.4, 5.9)
    card(ax, .410, .610, .205, .115, "Burden score",
         ["B = lambda_H H(pi)", "+ lambda_C cross", "+ lambda_U unc"],
         C["purple2"], C["purple"], None, 8.0, 5.8)
    card(ax, .410, .425, .205, .115, "Gate scaling",
         ["gamma_eff = gamma0(1+B)", "beta_eff = beta/(1+B)"],
         C["purple2"], C["purple"], "gate", 8.0, 5.8)
    card(ax, .410, .245, .205, .105, "SMNLMS condition",
         ["update only if", "|e| > gamma_eff"],
         C["green2"], C["green"], "threshold", 8.0, 5.8)
    card(ax, .725, .610, .195, .105, "Innovation", ["e = d_ref - y_s"], C["orange2"], C["orange"], "residual")
    card(ax, .725, .430, .195, .115, "Coefficient update", ["theta_s <- theta_s", "+ mu_SM e x / ||x||^2"], C["orange2"], C["orange"], "fir")
    card(ax, .725, .260, .195, .105, "Receiver effect", ["fewer unreliable updates", "cleaner bank-local memory"], C["red2"], C["red"], "shield")
    arrow(ax, .310, .712, .420, .667)
    arrow(ax, .310, .520, .420, .667)
    arrow(ax, .615, .485, .725, .665)
    arrow(ax, .615, .295, .725, .485)
    arrow(ax, .822, .610, .822, .545)
    arrow(ax, .822, .430, .822, .365)
    card(ax, .240, .105, .520, .078, "Bridge to the full Proposed MSB",
         ["single-bank endogenous-aware NLMS explains the gate",
          "MSB adds state-local memories and HMM/FIR routing"],
         C["gray2"], C["gray"], None, 8.2, 5.8)
    caption(ax, "Figure 9. Endogenous-aware SMNLMS gating used to suppress unreliable decision-directed updates.")
    save(fig, "fig09_python_endogenous_aware_smnlms_gate")


def fig10():
    fig, ax = canvas("Three-Block Simulation Strategy")
    blocks = [
        (.055, "A. Controlled Markov-ISI", C["blue"], C["blue2"],
         [("Model", ["h2 = {0.30, 0.50, 0.70}", "P from mean dwell"], "hmm"),
          ("Purpose", ["severe Markov stress", "theory-aligned validation"], "shield"),
          ("Outputs", ["BER/SER vs SNR", "eye diagrams", "floor gap"], "posterior")]),
        (.370, "B. 802.3ck C2M Tracking", C["green"], C["green2"],
         [("States", ["C2M_10dB | 14dB | 16dB", "Touchstone S-parameters"], "sparam"),
          ("Stress modes", ["slow | medium | fast", "piecewise constant states"], "step"),
          ("Outputs", ["BER/SER, transition BER", "recovery, state accuracy", "eye metrics"], "posterior")]),
        (.685, "C. Endogenous Bridge", C["purple"], C["purple2"],
         [("Ablation", ["SMNLMS | SM-sign", "endogenous-aware NLMS"], "threshold"),
          ("Purpose", ["explain the gate", "before full MSB"], "gate"),
          ("Outputs", ["BER/SER, tail MSE", "update rate", "burden proxy"], "posterior")]),
    ]
    for bx, label, edge, fill, cards in blocks:
        dashed_group(ax, bx, .230, .260, .585, label, edge)
        for i, (title, lines, icon) in enumerate(cards):
            card(ax, bx+.025, .615-i*.150, .210, .112, title, lines,
                 fill if i < 2 else C["gray2"], edge if i < 2 else C["gray"], icon)
    arrow(ax, .315, .525, .370, .525)
    arrow(ax, .630, .525, .685, .525)
    card(ax, .145, .105, .710, .070, "Safe interpretation",
         ["Block A isolates theory; Block B validates tracking stress on public 802.3ck-style channels; Block C explains the endogenous-aware update."],
         C["orange2"], C["orange"], None)
    caption(ax, "Figure 10. Final simulation protocol separating controlled theory, realistic channel tracking, and recursion ablation.")
    save(fig, "fig10_python_three_block_simulation_strategy")


def fig11():
    fig, ax = canvas("Reference Baselines and Proposed Contribution")
    dashed_group(ax, .045, .220, .450, .590, "Baseline families from the literature", C["blue"])
    entries = [
        (.075, .645, "Souza 2024", ["SM-sign-NLMS", "set-membership + signed robustness"], C["blue2"], C["blue"], "loss"),
        (.075, .455, "Gazor 2002", ["SMNLMS / ADFE", "set-membership adaptive filtering"], C["blue2"], C["blue"], "threshold"),
        (.075, .265, "Ours bridge", ["Endogenous-aware NLMS", "single-bank theory ablation"], C["green2"], C["green"], "gate"),
        (.290, .645, "Liu 2023", ["SS-LMS DFE", "PAM4 adaptive DFE style"], C["orange2"], C["orange"], "fir"),
        (.290, .455, "Chen", ["Pulse-ref FFE/CTLE/DFE", "offline optimized reference"], C["orange2"], C["orange"], "residual"),
        (.290, .265, "Cui 2024", ["ExtraTrees-HMM", "ML emission + Viterbi detector"], C["orange2"], C["orange"], "tree"),
    ]
    for e in entries:
        card(ax, e[0], e[1], .170, .120, e[2], e[3], e[4], e[5], e[6])
    card(ax, .585, .545, .145, .140, "Algorithm 1", ["single-bank", "same channel stream", "compromise memory"], C["purple2"], C["purple"], "fir")
    card(ax, .795, .545, .155, .140, "Proposed MSB", ["state-local banks", "HMM/FIR routing", "EB-aware SMNLMS"], C["red2"], C["red"], "shield")
    for y in [.705, .515, .325]:
        arrow(ax, .245, y, .585, .615)
        arrow(ax, .460, y, .585, .615)
    arrow(ax, .730, .615, .795, .615)
    card(ax, .570, .265, .390, .110, "Novelty focus",
         ["not only a new step-size rule", "routing + bank-local memory + endogenous-aware gate", "for recurring channel-state variation"],
         C["gray2"], C["gray"], "shield")
    caption(ax, "Figure 11. Baseline positioning: each reference tests a different part of the proposed receiver.")
    save(fig, "fig11_python_reference_baseline_positioning")


def fig12():
    fig, ax = canvas("802.3ck-Style Channel Physics and Impairment Stack")
    dashed_group(ax, .045, .445, .925, .390, "COM-style channel processing path used before equalization", C["gray"])
    steps = [
        (.060, "Touchstone assets", [".s4p channel files", "manifest-selected cases"], C["blue2"], C["blue"], "sparam"),
        (.220, "Differential response", ["extract Sdd21(f)", "relative to DC"], C["blue2"], C["blue"], "loss"),
        (.380, "Time response", ["PCHIP grid + IFFT", "main-cursor alignment"], C["green2"], C["green"], "residual"),
        (.540, "Symbol FIR", ["h_s[k] for PAM4", "used by channel + router"], C["green2"], C["green"], "fir"),
        (.700, "Baud/Nyquist", ["26.5625 / 53.125 GBd", "higher f_Nyq samples more loss"], C["purple2"], C["purple"], "step"),
        (.860, "Receiver stress", ["AWGN", "XTALK + jitter", "combined stress"], C["orange2"], C["orange"], "impair"),
    ]
    for i, st in enumerate(steps):
        card(ax, st[0], .515, .115, .250, st[1], st[2], st[3], st[4], st[5], title_size=7.5, body_size=5.7)
        if i < len(steps)-1:
            arrow(ax, st[0]+.115, .640, steps[i+1][0], .640)
    card(ax, .085, .230, .230, .105, "Channel severity figure", ["overlay |Sdd21| for C2M/C2C", "shows frequency-dependent loss"], C["blue2"], C["blue"], "loss")
    card(ax, .385, .230, .230, .105, "High-speed figure", ["baud changes Nyquist point", "and symbol-spaced taps"], C["purple2"], C["purple"], "step")
    card(ax, .685, .230, .230, .105, "Impairment figure", ["AWGN, NEXT/FEXT proxy, jitter proxy", "and combined stress"], C["orange2"], C["orange"], "impair")
    caption(ax, "Figure 12. Channel-processing and impairment stack used to justify the 802.3ck tracking benchmark.")
    save(fig, "fig12_python_channel_physics_impairment_stack")


def fig13():
    fig, ax = canvas("Metrics Produced by the Final Simulation Pack")
    dashed_group(ax, .055, .250, .890, .565, "Main paper metrics", C["gray"])
    top = [
        (.090, "BER / SER", ["waterfall vs SNR", "pre-FEC reference"], C["blue2"], C["blue"], "posterior"),
        (.315, "Eye metrics", ["eye height", "eye width / area"], C["green2"], C["green"], "eye"),
        (.540, "Tracking", ["transition-window BER", "recovery time"], C["purple2"], C["purple"], "step"),
        (.765, "Router", ["state accuracy", "bank usage"], C["orange2"], C["orange"], "posterior"),
    ]
    for st in top:
        card(ax, st[0], .585, .155, .140, st[1], st[2], st[3], st[4], st[5])
    card(ax, .190, .345, .220, .110, "Adaptation diagnostics", ["tail MSE, tap convergence", "set-membership update rate"], C["gray2"], C["gray"], "loss")
    card(ax, .590, .345, .220, .110, "Complexity diagnostics", ["multiplications/symbol", "memory and latency estimate"], C["gray2"], C["gray"], "matrix")
    arrow(ax, .168, .585, .255, .455)
    arrow(ax, .392, .585, .345, .455)
    arrow(ax, .618, .585, .645, .455)
    arrow(ax, .842, .585, .765, .455)
    card(ax, .300, .145, .400, .090, "Paper tables", ["Table I: channels | Table II: BER/SER/eye | Table III: tracking/recovery"], C["red2"], C["red"], "matrix")
    arrow(ax, .300, .345, .445, .235)
    arrow(ax, .700, .345, .555, .235)
    caption(ax, "Figure 13. Metric stack connecting Monte Carlo curves, eye diagrams, routing diagnostics, and paper tables.")
    save(fig, "fig13_python_metrics_stack")


def main():
    fig08(); fig09(); fig10(); fig11(); fig12(); fig13()
    manifest = [
        "# Python IEEE Access Figures 8-13 v72",
        "",
        "These figures are generated with matplotlib from a repo-local Python environment.",
        "They are intended as a visually polished alternative to the MATLAB schematic redraws.",
        "",
        "| Figure | File stem | Purpose |",
        "|---|---|---|",
        "| 8 | `fig08_python_hmm_fir_router` | Code-faithful HMM/FIR router. |",
        "| 9 | `fig09_python_endogenous_aware_smnlms_gate` | Endogenous-aware SMNLMS gate. |",
        "| 10 | `fig10_python_three_block_simulation_strategy` | Final simulation strategy. |",
        "| 11 | `fig11_python_reference_baseline_positioning` | Baseline positioning. |",
        "| 12 | `fig12_python_channel_physics_impairment_stack` | Channel physics and impairments. |",
        "| 13 | `fig13_python_metrics_stack` | Metrics map. |",
    ]
    (OUT / "MANIFEST.md").write_text("\n".join(manifest) + "\n", encoding="utf-8")
    print(f"[py_figs] wrote {OUT / 'MANIFEST.md'}")


if __name__ == "__main__":
    main()
