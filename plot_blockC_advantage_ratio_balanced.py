"""Balanced advantage-ratio figure for Block C.

Values are computed from the existing raw CSV.  The BER-ratio panel uses a
visual cap so the SM-sign curve does not dominate the composition; capped
points are marked explicitly as ">= cap" rather than altered in the data.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.ticker import AutoMinorLocator


ROOT = Path(__file__).resolve().parent
FIG_DIR = ROOT / "final_write_paper" / "figures"
CSV_FILE = FIG_DIR / "Endogenous_Aware_Adaptive_Filter_Diagnostics.csv"


def style(ax):
    ax.grid(True, which="major", color="#777777", alpha=0.28, linewidth=0.75)
    ax.grid(True, which="minor", color="#999999", alpha=0.16, linestyle=":", linewidth=0.55)
    ax.tick_params(axis="both", which="both", direction="in", top=True, right=True)
    ax.xaxis.set_minor_locator(AutoMinorLocator())
    ax.yaxis.set_minor_locator(AutoMinorLocator())
    for spine in ax.spines.values():
        spine.set_linewidth(1.1)
        spine.set_color("#222222")


def series(df, method, col):
    d = df[df["Method"] == method].sort_values("SNRdB")
    return d["SNRdB"].to_numpy(), d[col].to_numpy()


def plot_capped(ax, x, y, cap, color, marker, label, lw=2.2):
    yy = np.minimum(y, cap)
    ax.plot(x, yy, "-" + marker, color=color, lw=lw, ms=6.5, label=label)
    over = y > cap
    if np.any(over):
        ax.plot(x[over], np.full(np.sum(over), cap), marker="^", linestyle="none",
                color=color, ms=8.5, markeredgecolor="white", markeredgewidth=0.8)


def main():
    mpl.rcParams.update(
        {
            "font.family": "Times New Roman",
            "font.size": 12,
            "axes.titlesize": 13,
            "axes.labelsize": 12.5,
            "legend.fontsize": 10.5,
            "figure.dpi": 120,
            "savefig.dpi": 450,
        }
    )

    df = pd.read_csv(CSV_FILE)
    x, a_ber = series(df, "Algorithm 1: endogenous-aware", "BER_raw")
    _, sm_ber = series(df, "SMNLMS-DFE", "BER_raw")
    _, sg_ber = series(df, "SM-sign-NLMS", "BER_raw")
    _, a_mse = series(df, "Algorithm 1: endogenous-aware", "MSEtail")
    _, sm_mse = series(df, "SMNLMS-DFE", "MSEtail")
    _, sg_mse = series(df, "SM-sign-NLMS", "MSEtail")

    r_sm = sm_ber / np.maximum(a_ber, np.finfo(float).tiny)
    r_sg = sg_ber / np.maximum(a_ber, np.finfo(float).tiny)
    mse_sm = sm_mse / np.maximum(a_mse, np.finfo(float).tiny)
    mse_sg = sg_mse / np.maximum(a_mse, np.finfo(float).tiny)

    red_sm = 100 * (1 - a_ber / np.maximum(sm_ber, np.finfo(float).tiny))
    red_sg = 100 * (1 - a_ber / np.maximum(sg_ber, np.finfo(float).tiny))

    fig, axs = plt.subplots(1, 2, figsize=(12.8, 4.8), constrained_layout=True)
    fig.suptitle("Endogenous-aware Algorithm 1: relative gains from raw Monte Carlo data",
                 fontsize=16.5, fontweight="bold")

    blue = "#1f77b4"
    orange = "#d95319"
    red = "#b5122b"

    ax = axs[0]
    style(ax)
    cap = 4.0
    plot_capped(ax, x, r_sm, cap, blue, "o", "SMNLMS-DFE / Algorithm 1", lw=2.0)
    plot_capped(ax, x, r_sg, cap, orange, "s", "SM-sign-NLMS / Algorithm 1", lw=2.2)
    ax.axhline(1, color="black", lw=0.9, ls="--", alpha=0.65)
    ax.axhline(3, color=red, lw=1.0, ls=(0, (5, 3)), alpha=0.85)
    ax.text(15.25, 3.08, "3x target line", color=red, fontsize=10, va="bottom")
    ax.text(28.0, cap - 0.08, "triangles: >=4x", color=orange, fontsize=10, ha="left", va="top")
    ax.set_title("(a) BER advantage ratio, visually capped")
    ax.set_xlabel("SNR (dB)")
    ax.set_ylabel("baseline BER / Algorithm-1 BER")
    ax.set_xlim(15, 30)
    ax.set_ylim(0.82, 4.12)
    ax.legend(loc="upper left", frameon=True, fancybox=False, edgecolor="#333333")

    ax = axs[1]
    style(ax)
    ax.plot(x, red_sm, "-o", color=blue, lw=2.0, ms=6.5, label="vs SMNLMS-DFE")
    ax.plot(x, red_sg, "-s", color=orange, lw=2.2, ms=6.5, label="vs SM-sign-NLMS")
    ax.axhline(0, color="black", lw=0.9, ls="--", alpha=0.65)
    ax.fill_between(x, 0, np.maximum(red_sg, 0), color=orange, alpha=0.08, linewidth=0)
    ax.set_title("(b) BER reduction of Algorithm 1")
    ax.set_xlabel("SNR (dB)")
    ax.set_ylabel("BER reduction (%)")
    ax.set_xlim(15, 30)
    ax.set_ylim(-8, 92)
    ax.legend(loc="upper left", frameon=True, fancybox=False, edgecolor="#333333")

    fig.text(
        0.5,
        -0.02,
        "Computed from raw CSV. Panel (a) caps only the visual axis; capped points are explicitly marked.",
        ha="center",
        va="top",
        fontsize=10,
        color="#444444",
    )

    out_png = FIG_DIR / "Endogenous_Aware_Advantage_Ratio_Balanced.png"
    out_pdf = FIG_DIR / "Endogenous_Aware_Advantage_Ratio_Balanced.pdf"
    fig.savefig(out_png, bbox_inches="tight")
    fig.savefig(out_pdf, bbox_inches="tight")
    plt.close(fig)
    print(out_png)


if __name__ == "__main__":
    main()
