"""Plot Block C advantage ratios from existing Monte Carlo data.

This is a presentation-only companion figure.  It does not modify the
simulation data.  Ratios are computed directly from the CSV:
baseline BER / Algorithm-1 BER and baseline MSE / Algorithm-1 MSE.
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


def get(df, method, metric):
    d = df[df["Method"] == method].sort_values("SNRdB")
    return d["SNRdB"].to_numpy(), d[metric].to_numpy()


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
    x, a_ber = get(df, "Algorithm 1: endogenous-aware", "BER_raw")
    _, sm_ber = get(df, "SMNLMS-DFE", "BER_raw")
    _, sg_ber = get(df, "SM-sign-NLMS", "BER_raw")
    _, a_mse = get(df, "Algorithm 1: endogenous-aware", "MSEtail")
    _, sm_mse = get(df, "SMNLMS-DFE", "MSEtail")
    _, sg_mse = get(df, "SM-sign-NLMS", "MSEtail")

    ber_ratio_sm = sm_ber / np.maximum(a_ber, np.finfo(float).tiny)
    ber_ratio_sg = sg_ber / np.maximum(a_ber, np.finfo(float).tiny)
    mse_ratio_sm = sm_mse / np.maximum(a_mse, np.finfo(float).tiny)
    mse_ratio_sg = sg_mse / np.maximum(a_mse, np.finfo(float).tiny)

    fig, axs = plt.subplots(1, 2, figsize=(12.8, 4.8), constrained_layout=True)
    fig.suptitle("Endogenous-aware Algorithm 1: measured advantage ratios", fontsize=17, fontweight="bold")

    colors = {"sm": "#1f77b4", "sg": "#d95319"}

    ax = axs[0]
    style(ax)
    ax.plot(x, ber_ratio_sm, "-o", color=colors["sm"], lw=2.0, ms=6, label="SMNLMS-DFE / Algorithm 1")
    ax.plot(x, ber_ratio_sg, "-s", color=colors["sg"], lw=2.2, ms=6, label="SM-sign-NLMS / Algorithm 1")
    ax.axhline(1.0, color="black", lw=0.9, ls="--", alpha=0.65)
    ax.axhline(3.0, color="#b5122b", lw=1.0, ls=(0, (5, 3)), alpha=0.8)
    ax.text(27.2, 3.12, "3x line", color="#b5122b", fontsize=10)
    ax.set_title("(a) BER advantage ratio")
    ax.set_xlabel("SNR (dB)")
    ax.set_ylabel("baseline BER / Algorithm-1 BER")
    ax.set_xlim(15, 30)
    ax.set_ylim(0.8, max(9.2, np.nanmax(ber_ratio_sg) * 1.08))
    ax.legend(loc="upper left", frameon=True, fancybox=False, edgecolor="#333333")

    ax = axs[1]
    style(ax)
    ax.plot(x, mse_ratio_sm, "-o", color=colors["sm"], lw=2.0, ms=6, label="SMNLMS-DFE / Algorithm 1")
    ax.plot(x, mse_ratio_sg, "-s", color=colors["sg"], lw=2.2, ms=6, label="SM-sign-NLMS / Algorithm 1")
    ax.axhline(1.0, color="black", lw=0.9, ls="--", alpha=0.65)
    ax.set_title("(b) Tail-MSE advantage ratio")
    ax.set_xlabel("SNR (dB)")
    ax.set_ylabel("baseline tail MSE / Algorithm-1 tail MSE")
    ax.set_xlim(15, 30)
    ax.set_ylim(0.98, max(1.22, np.nanmax([mse_ratio_sm, mse_ratio_sg]) * 1.08))
    ax.legend(loc="upper right", frameon=True, fancybox=False, edgecolor="#333333")

    note = (
        "Ratios are computed from raw Monte Carlo CSV values; "
        "no simulation values are changed."
    )
    fig.text(0.5, -0.02, note, ha="center", va="top", fontsize=10, color="#444444")

    out_png = FIG_DIR / "Endogenous_Aware_Advantage_Ratio_PaperClean.png"
    out_pdf = FIG_DIR / "Endogenous_Aware_Advantage_Ratio_PaperClean.pdf"
    fig.savefig(out_png, bbox_inches="tight")
    fig.savefig(out_pdf, bbox_inches="tight")
    plt.close(fig)
    print(out_png)


if __name__ == "__main__":
    main()
