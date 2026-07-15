"""Paper-clean Block C adaptive-filter diagnostics figure.

This script redraws the existing MATLAB-generated data without rerunning
simulations.  Raw Monte Carlo markers are preserved; smoothed/monotone
curves are only visual guides.
"""

from __future__ import annotations

from pathlib import Path

import h5py
import numpy as np
import pandas as pd

import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.ticker import AutoMinorLocator, LogLocator, NullFormatter


ROOT = Path(__file__).resolve().parent
FIG_DIR = ROOT / "final_write_paper" / "figures"
CSV_FILE = FIG_DIR / "Endogenous_Aware_Adaptive_Filter_Diagnostics.csv"
MAT_FILE = FIG_DIR / "Endogenous_Aware_Adaptive_Filter_Diagnostics.mat"


METHODS = [
    "SMNLMS-DFE",
    "SM-sign-NLMS",
    "Algorithm 1: endogenous-aware",
]

LABELS = [
    "SMNLMS-DFE",
    "SM-sign-NLMS",
    "Algorithm 1 (ours)",
]

COLORS = {
    "SMNLMS-DFE": "#1f77b4",
    "SM-sign-NLMS": "#d95319",
    "Algorithm 1: endogenous-aware": "#b5122b",
}

MARKERS = {
    "SMNLMS-DFE": "o",
    "SM-sign-NLMS": "s",
    "Algorithm 1: endogenous-aware": "D",
}


def monotone_guide(y: np.ndarray, shrink: float = 0.985) -> np.ndarray:
    out = np.asarray(y, dtype=float).copy()
    for i in range(1, out.size):
        if np.isfinite(out[i - 1]) and np.isfinite(out[i]):
            out[i] = min(out[i], shrink * out[i - 1])
    return out


def moving_average(y: np.ndarray, win: int = 9) -> np.ndarray:
    y = np.asarray(y, dtype=float)
    if win <= 1 or y.size < win:
        return y.copy()
    pad = win // 2
    yy = np.pad(y, (pad, pad), mode="edge")
    ker = np.ones(win) / win
    return np.convolve(yy, ker, mode="valid")[: y.size]


def load_transient() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    with h5py.File(MAT_FILE, "r") as f:
        it = np.asarray(f["out/transient/iter"]).squeeze()
        mse = np.asarray(f["out/transient/mse"])
        upd = np.asarray(f["out/transient/update"])

    # MATLAB 120x3 matrices appear as 3x120 in h5py.
    if mse.shape[0] == 3:
        mse = mse.T
    if upd.shape[0] == 3:
        upd = upd.T
    return it, mse, upd


def style_axes(ax, logy: bool = False) -> None:
    ax.grid(True, which="major", color="#7f7f7f", alpha=0.28, linewidth=0.75)
    ax.grid(True, which="minor", color="#9a9a9a", alpha=0.16, linestyle=":", linewidth=0.55)
    ax.tick_params(axis="both", which="both", direction="in", top=True, right=True)
    ax.xaxis.set_minor_locator(AutoMinorLocator())
    if logy:
        ax.set_yscale("log")
        ax.yaxis.set_minor_locator(LogLocator(base=10.0, subs=np.arange(2, 10) * 0.1))
        ax.yaxis.set_minor_formatter(NullFormatter())
    else:
        ax.yaxis.set_minor_locator(AutoMinorLocator())
    for spine in ax.spines.values():
        spine.set_linewidth(1.1)
        spine.set_color("#222222")


def plot() -> Path:
    df = pd.read_csv(CSV_FILE)
    it, mse_tr, upd_tr = load_transient()

    mpl.rcParams.update(
        {
            "font.family": "Times New Roman",
            "font.size": 12,
            "axes.titlesize": 13,
            "axes.labelsize": 12.5,
            "legend.fontsize": 10.5,
            "figure.dpi": 120,
            "savefig.dpi": 450,
            "mathtext.fontset": "stix",
        }
    )

    fig, axs = plt.subplots(2, 2, figsize=(13.4, 8.8), constrained_layout=True)
    fig.suptitle(
        "Endogenous-aware recursion bridge: adaptive-filter diagnostics",
        fontsize=18,
        fontweight="bold",
        y=1.02,
    )

    # (a) BER waterfall.
    ax = axs[0, 0]
    style_axes(ax, logy=True)
    for method, label in zip(METHODS, LABELS):
        sub = df[df["Method"] == method].sort_values("SNRdB")
        x = sub["SNRdB"].to_numpy()
        raw = np.maximum(sub["BER_raw"].to_numpy(), np.finfo(float).tiny)
        guide = monotone_guide(np.maximum(sub["BER_waterfall_fit"].to_numpy(), np.finfo(float).tiny))
        ax.semilogy(x, guide, color=COLORS[method], lw=2.0 if method != METHODS[2] else 2.6)
        ax.semilogy(
            x,
            raw,
            linestyle="none",
            marker=MARKERS[method],
            ms=5.8 if method != METHODS[2] else 7.2,
            color=COLORS[method],
            mec="white",
            mew=0.7,
            label=label,
        )
    ax.axhline(2.4e-4, color="black", lw=0.9, ls=(0, (4, 3)), alpha=0.75)
    ax.text(28.0, 2.6e-4, "KP4 FEC 2.4e-4", fontsize=10.5, va="bottom", ha="left")
    ax.set_title("(a) BER waterfall with Monte Carlo markers")
    ax.set_xlabel("SNR (dB)")
    ax.set_ylabel("pre-FEC BER")
    ax.set_xlim(15, 30)
    ax.set_ylim(8e-5, 8e-2)
    ax.legend(loc="lower left", frameon=True, fancybox=False, edgecolor="#333333")

    # (b) Tail MSE.
    ax = axs[0, 1]
    style_axes(ax, logy=False)
    for method, label in zip(METHODS, LABELS):
        sub = df[df["Method"] == method].sort_values("SNRdB")
        x = sub["SNRdB"].to_numpy()
        y = sub["MSEtail"].to_numpy()
        ax.plot(
            x,
            y,
            marker=MARKERS[method],
            ms=5.6 if method != METHODS[2] else 7.0,
            lw=2.0 if method != METHODS[2] else 2.8,
            color=COLORS[method],
            mec="white",
            mew=0.65,
            label=label,
        )
    ax.set_title("(b) Steady-state/tail MSE")
    ax.set_xlabel("SNR (dB)")
    ax.set_ylabel("tail MSE")
    ax.set_xlim(15, 30)
    ax.set_ylim(0.098, 0.333)
    ax.legend(loc="upper right", frameon=True, fancybox=False, edgecolor="#333333")

    # (c) Transient learning curve.
    ax = axs[1, 0]
    style_axes(ax, logy=False)
    for i, (method, label) in enumerate(zip(METHODS, LABELS)):
        y = moving_average(mse_tr[:, i], win=11)
        ax.plot(
            it,
            y,
            lw=2.0 if method != METHODS[2] else 2.9,
            color=COLORS[method],
            label=label,
        )
    ax.axvline(8000, color="#777777", lw=0.9, ls=":")
    ax.text(8120, 0.214, "training/DD boundary", fontsize=10, color="#333333")
    ax.set_title("(c) Transient learning curve after Markov burst")
    ax.set_xlabel("Iteration")
    ax.set_ylabel("block MSE")
    ax.set_xlim(0, np.nanmax(it))
    ax.set_ylim(0.126, 0.220)
    ax.legend(loc="upper right", frameon=True, fancybox=False, edgecolor="#333333")

    # (d) Update/correction activity.
    ax = axs[1, 1]
    style_axes(ax, logy=False)
    for i, (method, label) in enumerate(zip(METHODS, LABELS)):
        y = 100 * moving_average(upd_tr[:, i], win=11)
        ax.plot(
            it,
            y,
            lw=2.0 if method != METHODS[2] else 2.9,
            color=COLORS[method],
            label=label,
        )
    ax.axvline(8000, color="#777777", lw=0.9, ls=":")
    ax.text(8120, 56.0, "training/DD boundary", fontsize=10, color="#333333")
    ax.set_title("(d) Data-selective correction activity")
    ax.set_xlabel("Iteration")
    ax.set_ylabel("update probability (%)")
    ax.set_xlim(0, np.nanmax(it))
    ax.set_ylim(20, 58)
    ax.legend(loc="upper left", frameon=True, fancybox=False, edgecolor="#333333")

    out_png = FIG_DIR / "Endogenous_Aware_Adaptive_Filter_Diagnostics_PaperClean.png"
    out_pdf = FIG_DIR / "Endogenous_Aware_Adaptive_Filter_Diagnostics_PaperClean.pdf"
    fig.savefig(out_png, bbox_inches="tight")
    fig.savefig(out_pdf, bbox_inches="tight")
    plt.close(fig)
    return out_png


if __name__ == "__main__":
    print(plot())
