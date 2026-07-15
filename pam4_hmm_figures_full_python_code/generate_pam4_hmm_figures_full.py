# generate_pam4_hmm_figures_full.py
# Generate a full set of PAM-4 / IEEE 802.3ck / HMM-routed MSB figures.
#
# Requirements:
#   pip install matplotlib numpy
#
# Run:
#   python generate_pam4_hmm_figures_full.py
#
# Output folder:
#   pam4_hmm_figures_output/
#
# Notes:
# - This is a Python/Matplotlib vector-drawing reconstruction of the figures.
# - It outputs PNG and SVG for each figure.
# - The generated diagrams are editable as SVG in Inkscape, Illustrator, Figma, or PowerPoint.

from pathlib import Path
import math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Rectangle, Polygon
import matplotlib.patheffects as pe

OUT_DIR = Path("pam4_hmm_figures_output")
OUT_DIR.mkdir(parents=True, exist_ok=True)

plt.rcParams["font.family"] = "DejaVu Sans"
plt.rcParams["figure.dpi"] = 220


# =============================================================================
# Common helpers
# =============================================================================

def setup_canvas(width=15.6, height=9.0):
    fig, ax = plt.subplots(figsize=(width, height))
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")
    fig.patch.set_facecolor("white")
    return fig, ax


def add_box(ax, x, y, w, h, text="", fc="#ffffff", ec="#333333",
            lw=1.1, fs=9, weight="normal", radius=0.012,
            linestyle="-", zorder=2, alpha=1.0):
    patch = FancyBboxPatch(
        (x, y), w, h,
        boxstyle=f"round,pad=0.008,rounding_size={radius}",
        fc=fc, ec=ec, lw=lw, linestyle=linestyle, alpha=alpha, zorder=zorder
    )
    patch.set_path_effects([pe.SimplePatchShadow(offset=(0.9, -0.9), alpha=0.12), pe.Normal()])
    ax.add_patch(patch)
    if text:
        ax.text(x+w/2, y+h/2, text, ha="center", va="center",
                fontsize=fs, weight=weight, linespacing=1.12, zorder=zorder+1)
    return patch


def add_arrow(ax, x1, y1, x2, y2, color="#111111", lw=1.15,
              ms=10, rad=0, linestyle="-", arrowstyle="->", zorder=8):
    arrow = FancyArrowPatch(
        (x1, y1), (x2, y2),
        arrowstyle=arrowstyle,
        mutation_scale=ms,
        linewidth=lw,
        color=color,
        linestyle=linestyle,
        connectionstyle=f"arc3,rad={rad}",
        zorder=zorder,
    )
    ax.add_patch(arrow)
    return arrow


def add_text(ax, x, y, text, fs=8, color="#111111",
             weight="normal", ha="center", va="center", style="normal", rotation=0):
    ax.text(x, y, text, fontsize=fs, color=color, weight=weight,
            ha=ha, va=va, style=style, rotation=rotation)


def save_figure(fig, name):
    png = OUT_DIR / f"{name}.png"
    svg = OUT_DIR / f"{name}.svg"
    fig.savefig(png, dpi=320, bbox_inches="tight", facecolor="white")
    fig.savefig(svg, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"Saved: {png}")
    print(f"Saved: {svg}")


# =============================================================================
# Icons
# =============================================================================

def icon_file(ax, x, y, w, h, label=".s4p"):
    # page outline
    px, py = x+w*0.28, y+h*0.35
    pw, ph = w*0.22, h*0.36
    ax.add_patch(Rectangle((px, py), pw, ph, fc="#ffffff", ec="#111111", lw=0.9, zorder=5))
    ax.add_patch(Polygon([[px+pw*0.68, py+ph], [px+pw, py+ph*0.72], [px+pw, py+ph]],
                         fc="#f2f2f2", ec="#111111", lw=0.7, zorder=6))
    add_text(ax, x+w*0.40, y+h*0.24, label, fs=6.5, color="#1f65c1", weight="bold")


def icon_table(ax, x, y, w, h):
    tx, ty, tw, th = x+w*0.28, y+h*0.36, w*0.34, h*0.30
    for i in range(4):
        for j in range(4):
            fc = "#a9d18e" if i == 3 else "#ffffff"
            ax.add_patch(Rectangle((tx+j*tw/4, ty+i*th/4), tw/4, th/4,
                                   fc=fc, ec="#222222", lw=0.5, zorder=5))
    for i in range(3):
        ax.plot([x+w*0.30, x+w*0.37], [y+h*(0.28+i*0.06), y+h*(0.28+i*0.06)],
                color="#4c9a2a", lw=1.5, zorder=5)


def icon_database(ax, x, y, w, h):
    cx, cy = x+w*0.42, y+h*0.47
    ww, hh = w*0.32, h*0.42
    t = np.linspace(0, 2*np.pi, 100)
    ax.plot(cx + ww/2*np.cos(t), cy+hh/2 + hh*0.12*np.sin(t), color="#111111", lw=1.0)
    ax.plot([cx-ww/2, cx-ww/2], [cy-hh/2, cy+hh/2], color="#111111", lw=1.0)
    ax.plot([cx+ww/2, cx+ww/2], [cy-hh/2, cy+hh/2], color="#111111", lw=1.0)
    for k in [0.15, -0.10, -0.35]:
        ax.plot(cx + ww/2*np.cos(t), cy+k*hh + hh*0.12*np.sin(t), color="#111111", lw=1.0)


def icon_terminal(ax, x, y, w, h):
    rx, ry, rw, rh = x+w*0.25, y+h*0.38, w*0.40, h*0.30
    ax.add_patch(Rectangle((rx, ry), rw, rh, fc="#f8f8f8", ec="#111111", lw=1.0, zorder=5))
    ax.add_patch(Rectangle((rx, ry+rh*0.80), rw, rh*0.20, fc="#333333", ec="#111111", lw=0.8, zorder=6))
    ax.plot([rx+rw*0.12, rx+rw*0.25, rx+rw*0.12], [ry+rh*0.55, ry+rh*0.42, ry+rh*0.28],
            color="#111111", lw=1.4, zorder=6)
    ax.plot([rx+rw*0.33, rx+rw*0.52], [ry+rh*0.28, ry+rh*0.28], color="#111111", lw=1.2, zorder=6)


def icon_target(ax, x, y, w, h):
    cx, cy = x+w*0.45, y+h*0.50
    for r in [0.22, 0.15, 0.08]:
        ax.add_patch(Circle((cx, cy), w*r, fc="none", ec="#1f65c1", lw=1.4, zorder=5))
    add_arrow(ax, cx+w*0.03, cy+w*0.03, cx+w*0.22, cy+w*0.22, color="#1f65c1", lw=1.0, ms=8)


def draw_pam4_icon(ax, x, y, w, h):
    for yy in [0.25, 0.43, 0.61, 0.79]:
        ax.plot([x+w*0.52, x+w*0.87], [y+h*yy, y+h*yy],
                color="#777777", lw=0.65, zorder=5)
        ax.scatter([x+w*0.60, x+w*0.78], [y+h*yy, y+h*yy],
                   s=8, color="#2166ac", zorder=6)


def draw_fir_icon(ax, x, y, w, h):
    base = y + h*0.26
    ax.plot([x+w*0.43, x+w*0.88], [base, base], color="#333333", lw=0.65, zorder=5)
    for i, val in enumerate([0.78, 0.62, 0.49, 0.39, 0.34]):
        xx = x + w*(0.50 + i*0.085)
        ax.plot([xx, xx], [base, y+h*val], color="#245c91", lw=0.9, zorder=5)
        ax.scatter([xx], [y+h*val], s=7, color="#245c91", zorder=6)


def draw_channel_icon(ax, x, y, w, h):
    pts = [(0.54, 0.55), (0.62, 0.70), (0.70, 0.56),
           (0.78, 0.62), (0.86, 0.47), (0.94, 0.43)]
    ax.plot([x+w*a for a, _ in pts], [y+h*b for _, b in pts],
            color="#333333", lw=1.0, zorder=5)


def draw_slicer_icon(ax, x, y, w, h):
    for level in [0.28, 0.50, 0.72]:
        ax.plot([x+w*0.17, x+w*0.82], [y+h*level, y+h*level],
                color="#777777", lw=0.70, ls=(0, (4, 4)), zorder=5)
    ax.plot([x+w*0.25, x+w*0.40, x+w*0.40, x+w*0.55,
             x+w*0.55, x+w*0.70, x+w*0.70, x+w*0.82],
            [y+h*0.28, y+h*0.28, y+h*0.43, y+h*0.43,
             y+h*0.58, y+h*0.58, y+h*0.73, y+h*0.73],
            color="#111111", lw=1.1, zorder=6)


def draw_noise_icons(ax, x, y, w, h):
    cx, cy = x+w*0.16, y+h*0.38
    ax.add_patch(Circle((cx, cy), h*0.17, fc="white", ec="#666666", lw=0.75, zorder=5))
    for i in range(18):
        angle = i*2.23
        rr = h*0.145*((i % 5) + 2)/6
        ax.scatter([cx + rr*math.cos(angle)], [cy + rr*math.sin(angle)],
                   s=2.2, color="#222222", zorder=6)
    add_text(ax, cx, y+h*0.76, "AWGN", fs=6.8)
    add_text(ax, x+w*0.50, y+h*0.76, "Crosstalk", fs=6.8)
    ax.plot([x+w*0.40, x+w*0.58], [y+h*0.35, y+h*0.60], color="#d7191c", lw=1.0, zorder=5)
    ax.plot([x+w*0.40, x+w*0.58], [y+h*0.60, y+h*0.35], color="#1f77b4", lw=1.0, zorder=5)
    add_arrow(ax, x+w*0.53, y+h*0.53, x+w*0.58, y+h*0.60,
              color="#d7191c", lw=0.8, ms=7)
    add_arrow(ax, x+w*0.53, y+h*0.42, x+w*0.58, y+h*0.35,
              color="#1f77b4", lw=0.8, ms=7)
    add_text(ax, x+w*0.82, y+h*0.76, "Jitter", fs=6.8)
    bx, by = x+w*0.73, y+h*0.32
    ax.plot([bx, bx, bx+w*0.07, bx+w*0.07, bx+w*0.14, bx+w*0.14],
            [by, by+h*0.20, by+h*0.20, by+h*0.05, by+h*0.05, by+h*0.20],
            color="#222222", lw=0.9, zorder=5)
    ax.plot([bx-w*0.02, bx-w*0.02], [by-h*0.05, by+h*0.28],
            color="#777777", ls="--", lw=0.7, zorder=5)
    ax.plot([bx+w*0.17, bx+w*0.17], [by-h*0.05, by+h*0.28],
            color="#777777", ls="--", lw=0.7, zorder=5)
    add_arrow(ax, bx-w*0.005, by-h*0.03, bx+w*0.16, by-h*0.03,
              color="#222222", lw=0.75, ms=7, arrowstyle="<->")


def draw_bar_icon(ax, x, y, w, h):
    for i, value in enumerate([0.25, 0.42, 0.65, 0.36, 0.78]):
        ax.add_patch(Rectangle((x+w*(0.10+i*0.15), y+h*0.15),
                               w*0.08, h*value*0.70,
                               fc="#4b5563", ec="#4b5563", lw=0.2, zorder=5))


def draw_eye_icon(ax, x, y, w, h):
    xs = np.linspace(0, 1, 80)
    for offset in [0.40, 0.60]:
        ax.plot(x+w*(0.08+0.84*xs), y+h*(offset+0.15*np.sin(np.pi*xs)),
                color="#2a6fba", lw=1.0, zorder=5)
        ax.plot(x+w*(0.08+0.84*xs), y+h*(offset-0.15*np.sin(np.pi*xs)),
                color="#2a6fba", lw=1.0, zorder=5)


# =============================================================================
# Figure 1
# =============================================================================

def draw_figure1():
    fig, ax = setup_canvas(15.6, 10.0)

    add_box(ax, 0.02, 0.70, 0.96, 0.24, "", fc="#f8fcff", ec="#111111", lw=1.1, linestyle=(0, (5, 4)), radius=0.015)
    add_box(ax, 0.02, 0.15, 0.96, 0.49, "", fc="#f8fcff", ec="#111111", lw=1.1, linestyle=(0, (5, 4)), radius=0.015)

    add_text(ax, 0.035, 0.915, "A. IEEE 802.3ck public channel asset / COM reference layer", fs=14, weight="bold", ha="left")
    add_text(ax, 0.035, 0.610, "B. COM-style adaptive receiver evaluation layer", fs=14, weight="bold", ha="left")

    # Top layer
    top = [
        ("8023ck_channels/*.s4p", "#eef7ff", "#2b5c90", icon_file),
        ("channel_manifest.csv", "#eef9e9", "#4f7d3a", icon_table),
        ("com_reference", "#fff7e4", "#8a651a", icon_database),
        ("Annex 93A scripts", "#f7eff9", "#6f4a7d", icon_terminal),
        ("802.3ck config sheets", "#eef9e9", "#4f7d3a", icon_table),
        ("COM / ERL /\nVEC reference\n(for context)", "#eef7ff", "#2b5c90", icon_target),
    ]
    xs = np.linspace(0.08, 0.86, len(top))
    for i, (lab, fc, ec, icon) in enumerate(top):
        x = xs[i]
        add_box(ax, x-0.06, 0.745, 0.12, 0.14, lab, fc=fc, ec=ec, fs=8, weight="bold")
        icon(ax, x-0.06, 0.745, 0.12, 0.14)
        if i < len(top)-1:
            add_arrow(ax, x+0.06, 0.815, xs[i+1]-0.06, 0.815, color="#111111", lw=1.2, ms=10)
            ax.add_patch(Circle(((x+xs[i+1])/2, 0.815), 0.006, fc="white", ec="#111111", lw=1.0, zorder=10))

    # Bottom evaluation flow
    blocks = [
        ("PAM-4\nSource", "#eef7ff", "#2b5c90"),
        ("Tx FFE", "#fff7e4", "#8a651a"),
        ("Touchstone\nLoader", "#eef9e9", "#4f7d3a"),
        (r"$S_{dd21}(f)$", "#eef7ff", "#2b5c90"),
        ("PCHIP + IFFT", "#fff7e4", "#8a651a"),
        ("Main-cursor\nalignment", "#f7eff9", "#6f4a7d"),
        ("Symbol-spaced\nFIR", "#fff7e4", "#8a651a"),
        ("C2M tracking-stress\nstate sequence", "#eef9e9", "#4f7d3a"),
    ]
    x0s = np.linspace(0.08, 0.88, len(blocks))
    for i, (lab, fc, ec) in enumerate(blocks):
        add_box(ax, x0s[i]-0.045, 0.515, 0.09, 0.13, lab, fc=fc, ec=ec, fs=8, weight="bold")
        if "PAM" in lab:
            draw_pam4_icon(ax, x0s[i]-0.045, 0.515, 0.09, 0.13)
        elif "Tx" in lab:
            draw_fir_icon(ax, x0s[i]-0.045, 0.515, 0.09, 0.13)
        elif "Loader" in lab:
            icon_file(ax, x0s[i]-0.045, 0.515, 0.09, 0.13, ".s4p")
        elif "S_" in lab:
            xs2 = np.linspace(0,1,30)
            ax.plot(x0s[i]-0.030+xs2*0.060, 0.555+0.030*np.exp(-2*xs2)*np.cos(3*xs2), color="#2a6fba", lw=1.0)
        elif "IFFT" in lab:
            draw_fir_icon(ax, x0s[i]-0.045, 0.515, 0.09, 0.13)
        elif "cursor" in lab:
            ax.plot([x0s[i]-0.025,x0s[i]-0.005,x0s[i]+0.005,x0s[i]+0.025],[0.55,0.55,0.60,0.55],color="#111",lw=1.0)
            ax.plot([x0s[i],x0s[i]],[0.535,0.615],ls="--",color="#111",lw=0.8)
        elif "FIR" in lab:
            draw_fir_icon(ax, x0s[i]-0.045, 0.515, 0.09, 0.13)
        elif "Markov" in lab:
            cx, cy = x0s[i], 0.575
            for ang, text in [(0,"1"),(2.1,"2"),(4.2,"M")]:
                ax.add_patch(Circle((cx+0.025*np.cos(ang), cy+0.025*np.sin(ang)), 0.012, fc="#fff", ec="#111", lw=0.7))
                add_text(ax,cx+0.025*np.cos(ang),cy+0.025*np.sin(ang),text,fs=6)
        if i < len(blocks)-1:
            add_arrow(ax, x0s[i]+0.045, 0.580, x0s[i+1]-0.045, 0.580, color="#111", lw=1.2, ms=10)

    # Lower receiver path
    add_arrow(ax, 0.925, 0.515, 0.925, 0.410, color="#111", lw=1.2, ms=10)
    add_arrow(ax, 0.925, 0.410, 0.055, 0.410, color="#111", lw=1.2, ms=10)
    lower = [
        ("AWGN /\nCrosstalk /\nJitter\noptional stress", "#fff0f0", "#a04444"),
        ("HMM\nRouter", "#eef7ff", "#2b5c90"),
        ("Bank 1\nFFE/DFE", "#eef7ff", "#2b5c90"),
        ("Bank 2\nFFE/DFE", "#eef7ff", "#2b5c90"),
        ("Bank S\nFFE/DFE", "#eef7ff", "#2b5c90"),
        ("PAM-4\nSlicer", "#fff7e4", "#8a651a"),
        ("BER / SER /\nEye / Routing /\nRecovery Metrics", "#eef9e9", "#4f7d3a"),
    ]
    xs3 = [0.095,0.245,0.390,0.500,0.610,0.760,0.890]
    ws = [0.10,0.085,0.095,0.095,0.095,0.11,0.12]
    for i, (lab, fc, ec) in enumerate(lower):
        add_box(ax, xs3[i]-ws[i]/2, 0.225, ws[i], 0.18, lab, fc=fc, ec=ec, fs=8, weight="bold")
        if i == 0:
            draw_noise_icons(ax, xs3[i]-ws[i]/2, 0.225, ws[i], 0.18)
        elif i == 1:
            # simple router icon
            for p in [(0.02,0.05),(0.02,0.13),(0.065,0.09),(0.11,0.05),(0.11,0.13)]:
                ax.add_patch(Circle((xs3[i]-ws[i]/2+p[0], 0.225+p[1]), 0.006, fc="#8bb6e8", ec="#1b4f8a", lw=0.7))
            ax.plot([xs3[i]-ws[i]/2+0.02,xs3[i]-ws[i]/2+0.065,xs3[i]-ws[i]/2+0.11],[0.275,0.315,0.275],color="#111",lw=0.7)
            ax.plot([xs3[i]-ws[i]/2+0.02,xs3[i]-ws[i]/2+0.065,xs3[i]-ws[i]/2+0.11],[0.355,0.315,0.355],color="#111",lw=0.7)
        elif i in [2,3,4]:
            draw_fir_icon(ax, xs3[i]-ws[i]/2, 0.225, ws[i], 0.18)
        elif i == 5:
            draw_slicer_icon(ax, xs3[i]-ws[i]/2, 0.225, ws[i], 0.18)
        elif i == 6:
            draw_eye_icon(ax,xs3[i]-ws[i]/2+0.01,0.30,0.05,0.06)
            draw_bar_icon(ax,xs3[i]-ws[i]/2+0.065,0.30,0.045,0.06)
        if i < len(lower)-1:
            add_arrow(ax, xs3[i]+ws[i]/2, 0.315, xs3[i+1]-ws[i+1]/2, 0.315, color="#111", lw=1.2, ms=10)

    # Dotted bank group
    add_box(ax, 0.315, 0.190, 0.36, 0.235, "", fc=(1,1,1,0), ec="#2b5c90", lw=1.0, linestyle=(0,(5,3)), radius=0.012)

    add_text(ax, 0.50, 0.075, "Figure 1. Overall 802.3ck PAM-4 benchmark architecture", fs=12, weight="bold")
    save_figure(fig, "figure1_overall_8023ck_pam4_benchmark_architecture")


# =============================================================================
# Figure 2
# =============================================================================

def draw_figure2():
    fig, ax = setup_canvas(15.6, 6.0)
    add_box(ax, 0.02, 0.27, 0.46, 0.42, "", fc="#fbfdff", ec="#111", lw=1.1, linestyle=(0,(5,4)), radius=0.015)
    add_box(ax, 0.50, 0.27, 0.48, 0.42, "", fc="#fbfdff", ec="#111", lw=1.1, linestyle=(0,(5,4)), radius=0.015)
    add_text(ax,0.04,0.65,"A. COM reference path",fs=13,weight="bold",ha="left")
    add_text(ax,0.52,0.65,"B. FIR-evaluation path used by Proposed MSB",fs=13,weight="bold",ha="left")

    top = [
        ("8023ck_channels/*.s4p","#eef7ff","#2b5c90",lambda a,x,y,w,h: icon_file(a,x,y,w,h,"")),
        ("channel_manifest.csv","#eef9e9","#4f7d3a",icon_table),
        ("com_reference","#fff7e4","#8a651a",icon_database),
        ("Annex 93A scripts","#f7eff9","#6f4a7d",icon_terminal),
        ("802.3ck config /\nVEC reference","#eef9e9","#4f7d3a",icon_table),
    ]
    xs = np.linspace(0.08,0.42,len(top))
    for i,(lab,fc,ec,icon) in enumerate(top):
        add_box(ax,xs[i]-0.045,0.36,0.09,0.23,lab,fc=fc,ec=ec,fs=6.7,weight="bold")
        icon(ax,xs[i]-0.045,0.36,0.09,0.23)
        if i < len(top)-1:
            add_arrow(ax,xs[i]+0.045,0.475,xs[i+1]-0.045,0.475,color="#111",lw=1.1,ms=9)
            ax.add_patch(Circle(((xs[i]+xs[i+1])/2,0.475),0.006,fc="white",ec="#111",lw=0.9,zorder=10))

    rhs = [
        ("load_touchstone_\nsparam()","#eef7ff","#2b5c90"),
        (r"$S_{dd21}(f)$","#eef7ff","#2b5c90"),
        ("PCHIP\ninterpolation","#fff7e4","#8a651a"),
        ("IFFT","#f7eff9","#6f4a7d"),
        ("Main-cursor\nalignment","#fff0f0","#a04444"),
        ("Symbol-spaced\nFIR h_s[k]","#fff7e4","#8a651a"),
    ]
    xs2 = np.linspace(0.56,0.92,len(rhs))
    for i,(lab,fc,ec) in enumerate(rhs):
        add_box(ax,xs2[i]-0.038,0.36,0.076,0.23,lab,fc=fc,ec=ec,fs=6.7,weight="bold")
        if i==0:
            icon_file(ax,xs2[i]-0.038,0.36,0.076,0.23,".s4p")
        elif i==1:
            x=np.linspace(0,1,30)
            ax.plot(xs2[i]-0.025+x*0.05,0.475+0.035*np.exp(-x)*np.cos(3*x),color="#2a6fba",lw=1.0)
            ax.plot([xs2[i]-0.025,xs2[i]-0.025],[0.405,0.555],color="#111",lw=0.7)
            ax.plot([xs2[i]-0.025,xs2[i]+0.030],[0.405,0.405],color="#111",lw=0.7)
        elif i==2:
            draw_fir_icon(ax,xs2[i]-0.038,0.36,0.076,0.23)
        elif i==3:
            draw_fir_icon(ax,xs2[i]-0.038,0.36,0.076,0.23)
        elif i==4:
            ax.plot([xs2[i]-0.02,xs2[i]-0.006,xs2[i]+0.006,xs2[i]+0.02],[0.44,0.44,0.52,0.44],color="#111",lw=1)
            ax.plot([xs2[i],xs2[i]],[0.415,0.545],ls="--",color="#111",lw=.8)
        elif i==5:
            draw_fir_icon(ax,xs2[i]-0.038,0.36,0.076,0.23)
        if i < len(rhs)-1:
            add_arrow(ax,xs2[i]+0.038,0.475,xs2[i+1]-0.038,0.475,color="#111",lw=1.1,ms=9)
            ax.add_patch(Circle(((xs2[i]+xs2[i+1])/2,0.475),0.006,fc="white",ec="#111",lw=0.9,zorder=10))
    add_text(ax,0.50,0.19,"Figure 2. Practical 802.3ck channel asset handling",fs=12,weight="bold")
    save_figure(fig,"figure2_practical_8023ck_channel_asset_handling")


# =============================================================================
# Figure 3
# =============================================================================

def small_stem(ax, x, y, w, h):
    base=y+h*0.22
    ax.plot([x+w*0.1,x+w*0.9],[base,base],color="#111",lw=.7)
    vals=[.35,.60,.80,.50,.42]
    for i,v in enumerate(vals):
        xx=x+w*(.18+i*.14)
        ax.plot([xx,xx],[base,y+h*v],color="#111",lw=.8)
        ax.scatter([xx],[y+h*v],s=10,fc="white",ec="#111",zorder=5)
    ax.text(x+w*0.5,y+h*0.06,r"$n\rightarrow$",fontsize=7,ha="center")

def draw_figure3():
    fig, ax = setup_canvas(15.6, 9.0)
    # left numbered inputs
    left = [
        ("local_pam4(cfg)\nPAM-4 symbols $t_x[n]$","#eef7ff","#2b5c90"),
        ("local_apply_tx_ffe(d)\nTx FFE output $t_{x\\_ffe}[n]$","#fff7e4","#8a651a"),
        ("local_balanced_markov_state_seq()\nMarkov state sequence\n$\\alpha[n]\\in\\{1,...,M\\}$","#eef9e9","#4f7d3a"),
        ("$h_{phys}=\\{h_1,h_2,h_3\\}$\nPhysical channel FIRs\n(per Markov state)","#fff0f0","#9a5965"),
    ]
    ys=[0.72,0.53,0.34,0.14]
    for i,(txt,fc,ec) in enumerate(left):
        add_box(ax,0.06,ys[i],0.24,0.16,txt,fc=fc,ec=ec,fs=8.8,weight="bold")
        ax.add_patch(Circle((0.035,ys[i]+0.08),0.018,fc="white",ec="#111",lw=1.0))
        add_text(ax,0.035,ys[i]+0.08,str(i+1),fs=11,weight="bold")
        if i in [0,1,3]:
            small_stem(ax,0.08,ys[i]+0.015,0.20,0.07)
        elif i==2:
            # Markov chain
            cx=0.14; cy=ys[i]+0.05
            for j,lab in enumerate(["1","2","M"]):
                ax.add_patch(Circle((cx+j*0.06,cy),0.017,fc="white",ec="#111",lw=.9))
                add_text(ax,cx+j*0.06,cy,lab,fs=8)
            add_arrow(ax,cx+0.017,cy,cx+0.06-0.017,cy,rad=.2,ms=8)
            add_arrow(ax,cx+0.06+0.017,cy,cx+0.12-0.017,cy,rad=.2,ms=8)
            add_text(ax,cx+0.09,cy+0.032,"...",fs=10)

    # central channel out box
    add_box(ax,0.35,0.18,0.38,0.62,"",fc="#f8fcff",ec="#2b5c90",lw=1.1,linestyle=(0,(5,4)),radius=.018)
    add_text(ax,0.54,0.765,"local_channel_out_fir_state_seq\n(tx, $h_{phys}$, state_seq)",fs=11,weight="bold")
    add_box(ax,0.375,0.42,0.10,0.25,"Input sequence\n$t_{x\\_ffe}[n]$",fc="#eef7ff",ec="#2b5c90",fs=8)
    small_stem(ax,0.385,0.43,0.08,0.09)
    add_box(ax,0.49,0.42,0.15,0.25,"State-based\nchannel selection\nselect $h_{\\alpha[n]}[k]$",fc="#fff7e4",ec="#8a651a",fs=8)
    ax.add_patch(Circle((0.565,0.55),0.022,fc="white",ec="#111",lw=.8))
    add_text(ax,0.565,0.55,r"$\alpha[n]$",fs=8)
    for j,x in enumerate([0.52,0.565,0.61]):
        add_box(ax,x-0.012,0.49,0.024,0.035,str(j+1 if j<2 else "M"),fc="#fff",ec="#111",fs=7,radius=.001,lw=.6)
        add_box(ax,x-0.018,0.43,0.036,0.035,fr"$h_{j+1 if j<2 else 'M'}[k]$",fc="#f8f8f8",ec="#111",fs=6,radius=.001,lw=.6)
        add_arrow(ax,0.565,0.53,x,0.525,linestyle="--",lw=.7,ms=7)
        add_arrow(ax,x,0.49,x,0.465,lw=.7,ms=7)
    add_box(ax,0.66,0.42,0.10,0.25,"Clean channel\noutput\n$r_{clean}[n]$",fc="#eef9e9",ec="#4f7d3a",fs=8)
    small_stem(ax,0.67,0.43,0.08,0.09)
    add_arrow(ax,0.475,0.545,0.49,0.545,lw=1.0,ms=9)
    add_arrow(ax,0.64,0.545,0.66,0.545,lw=1.0,ms=9)
    add_box(ax,0.42,0.23,0.25,0.07,r"$r_{clean}[n]=\sum_k h_{\alpha[n]}[k]\,t_{x\_ffe}[n-k]$",
            fc="#f7eff9",ec="#6f4a7d",fs=10)

    # arrows from left into central
    for y in [0.80,0.61,0.42,0.22]:
        add_arrow(ax,0.30,y,0.35,0.49,color="#111",lw=1.1,ms=10,rad=-.05)

    # right noise path
    add_box(ax,0.77,0.62,0.18,0.20,"local_add_receiver_noise()\n$w[n]$\nAWGN",fc="#fff7e4",ec="#8a651a",fs=9,weight="bold")
    small_stem(ax,0.79,0.64,0.06,0.08)
    add_text(ax,0.815,0.705,r"$r_{clean}[n]$",fs=8)
    add_text(ax,0.915,0.705,r"$r_{noisy}[n]$",fs=8)
    ax.add_patch(Circle((0.86,0.68),0.015,fc="white",ec="#111",lw=.8))
    add_text(ax,0.86,0.68,"+",fs=10)
    add_arrow(ax,0.73,0.66,0.77,0.70,lw=1.1,ms=10)
    add_arrow(ax,0.86,0.62,0.86,0.55,lw=1.1,ms=10)
    add_box(ax,0.76,0.40,0.22,0.15,"local_apply_markov_twochain_disturbance()\n(optional)\nTwo-state Markov burst / interference",fc="#f7eff9",ec="#7d5aa6",fs=8.2,linestyle=(0,(5,3)))
    add_box(ax,0.78,0.12,0.18,0.18,"receiver input $r[n]$\n(received sequence)",fc="#eef7ff",ec="#2b5c90",fs=9,weight="bold")
    small_stem(ax,0.79,0.14,0.16,0.09)
    add_arrow(ax,0.86,0.40,0.86,0.30,lw=1.1,ms=10)
    add_text(ax,0.50,0.04,"Figure 3. Markov S-parameter simulation loop before receiver equalization",fs=12,weight="bold")
    save_figure(fig,"figure3_markov_sparameter_simulation_loop")


# =============================================================================
# Figure 4
# =============================================================================

def draw_figure4():
    fig, ax = setup_canvas(15.6,8.7)
    groups=[(0.03,0.18,0.20,0.68,"1","Shared input state","#eef7ff","#2b5c90"),
            (0.27,0.18,0.20,0.68,"2","Per-bank equalization","#eef9e9","#4f7d3a"),
            (0.51,0.18,0.20,0.68,"3","FIR-likelihood routing","#f7eff9","#7d5aa6"),
            (0.75,0.18,0.20,0.68,"4","Selected output and update","#fff7e4","#8a651a")]
    for x,y,w,h,num,title,fc,ec in groups:
        add_box(ax,x,y,w,h,"",fc=fc,ec=ec,lw=1.0,linestyle=(0,(5,3)),radius=.014,alpha=.8)
        ax.add_patch(Circle((x+0.025,y+h-0.035),0.018,fc=fc,ec=ec,lw=1.2,zorder=5))
        add_text(ax,x+0.025,y+h-0.035,num,fs=12,weight="bold")
        add_text(ax,x+0.09,y+h-0.035,title,fs=9,weight="bold",ha="left")

    # shared input boxes
    btxt=["r_buf =\n[r(n) ... r(n-Lr+1)]","m = n - D","has_ref / is_dd","cfg, v_base,\nmsb_params"]
    for i,txt in enumerate(btxt):
        y=0.67-i*0.14
        add_box(ax,0.055,y,0.15,0.09,txt,fc="#f8fcff",ec="#2b5c90",fs=8)
    # per bank boxes
    ptxt=["for each bank s,\ns = 1...S",
          "a_fb,s =\nget_fb_vector(...,\nd_hat_per_bank(:,s))",
          "x_s =\n[r_buf;\ndfe_sign * a_fb,s]",
          "y_s = theta_s^T x_s\nthen PAM slice"]
    for i,txt in enumerate(ptxt):
        y=0.67-i*0.14
        add_box(ax,0.295,y,0.15,0.09,txt,fc="#fbfffb",ec="#4f7d3a",fs=8)
    # routing boxes
    rtxt=["score_s =\n(r(m) - FIR_pred_s)^2",
          "J_s = rho J_s +\n(1-rho) score_s",
          "pi_pred =\nP_hmm^T pi",
          "pi_state\nproportional to\npi_pred * exp(-rel_score/tau)",
          "s_hat =\nargmax_s pi"]
    for i,txt in enumerate(rtxt):
        y=0.67-i*0.112
        add_box(ax,0.535,y,0.15,0.075,txt,fc="#fffaff",ec="#7d5aa6",fs=7.5)
    # output boxes
    otxt=["d_hat_sym(m) =\nd_dec_s(s_out)",
          "DD phase:\nupdate theta_s_hat only",
          "Pilot prefix:\nupdate all banks",
          "diag outputs:\npi_hist, J_hist,\ns_hat_hist,\ntheta_dfe_hist"]
    for i,txt in enumerate(otxt):
        y=0.67-i*0.14
        add_box(ax,0.775,y,0.15,0.09,txt,fc="#fffdf8",ec="#8a651a",fs=8)
    # arrows across groups
    add_arrow(ax,0.23,0.51,0.27,0.51,lw=1.2,ms=11)
    add_arrow(ax,0.47,0.51,0.51,0.51,lw=1.2,ms=11)
    add_arrow(ax,0.71,0.51,0.75,0.51,lw=1.2,ms=11)
    # return update loop
    add_arrow(ax,0.85,0.18,0.85,0.12,lw=1.2,ms=10)
    add_arrow(ax,0.85,0.12,0.38,0.12,lw=1.2,ms=10)
    add_arrow(ax,0.38,0.12,0.38,0.18,lw=1.2,ms=10)
    add_text(ax,0.50,0.04,"Figure 4. Proposed MSB-FIRBank online dataflow",fs=12,weight="bold")
    save_figure(fig,"figure4_proposed_msb_firbank_online_dataflow")


# =============================================================================
# Figure 5
# =============================================================================

def draw_figure5():
    fig, ax = setup_canvas(15.6,9.2)
    add_box(ax,0.03,0.30,0.94,0.60,"",fc="#fbfdff",ec="#111",lw=1.1,linestyle=(0,(5,4)),radius=.015)
    add_text(ax,0.50,0.86,"One state-local bank $s$",fs=15,weight="bold")
    # top chain
    add_box(ax,0.07,0.62,0.16,0.20,"Shared input\n$r\\_buf$ / $K_{ffe}$ samples",fc="#eef7ff",ec="#2b5c90",fs=10)
    draw_fir_icon(ax,0.07,0.62,0.16,0.20)
    add_box(ax,0.28,0.62,0.16,0.20,"FFE section $w_s$ /\n$K_{ffe}$ taps",fc="#eef9e9",ec="#4f7d3a",fs=10)
    draw_fir_icon(ax,0.28,0.62,0.16,0.20)
    ax.add_patch(Circle((0.53,0.70),0.035,fc="#eef7ff",ec="#111",lw=1.0,zorder=4))
    add_text(ax,0.53,0.70,r"$\Sigma$",fs=20,weight="bold")
    add_text(ax,0.53,0.775,"FFE - DFE",fs=10)
    add_box(ax,0.62,0.62,0.15,0.20,"PAM-4 slicer cfg.A",fc="#fff7e4",ec="#8a651a",fs=10)
    draw_slicer_icon(ax,0.62,0.62,0.15,0.20)
    add_box(ax,0.82,0.62,0.14,0.20,"d_dec,s\n(decided symbol)",fc="#f7eff9",ec="#7d5aa6",fs=10)
    draw_pam4_icon(ax,0.82,0.62,0.14,0.20)
    add_arrow(ax,0.23,0.72,0.28,0.72,lw=1.2,ms=11)
    add_arrow(ax,0.44,0.72,0.495,0.72,lw=1.2,ms=11)
    add_arrow(ax,0.565,0.72,0.62,0.72,lw=1.2,ms=11)
    add_arrow(ax,0.77,0.72,0.82,0.72,lw=1.2,ms=11)
    # bottom feedback
    add_box(ax,0.24,0.36,0.22,0.18,"DFE section $b_s$ /\n$L$ taps",fc="#eef9e9",ec="#4f7d3a",fs=10)
    ax.add_patch(Rectangle((0.27,0.40),0.035,0.05,fc="#fff",ec="#111",lw=0.8))
    add_text(ax,0.287,0.425,r"$z^{-1}$",fs=8)
    draw_fir_icon(ax,0.31,0.37,0.14,0.10)
    add_box(ax,0.56,0.36,0.17,0.18,"get_fb_vector()\na_fb,s\n(feedback builder)",fc="#fff7e4",ec="#8a651a",fs=10)
    add_box(ax,0.79,0.36,0.18,0.18,"d_hat_per_bank(:,s)\nbank-local decision history\n(DFE feedback)",fc="#eef9e9",ec="#4f7d3a",fs=10)
    icon_database(ax,0.79,0.36,0.18,0.18)
    add_arrow(ax,0.89,0.62,0.89,0.54,lw=1.2,ms=11)
    add_arrow(ax,0.79,0.45,0.73,0.45,lw=1.2,ms=11)
    add_arrow(ax,0.56,0.45,0.46,0.45,lw=1.2,ms=11)
    add_arrow(ax,0.46,0.45,0.53,0.665,lw=1.2,ms=11)
    # update note
    add_box(ax,0.04,0.20,0.92,0.055,"Bank-local update: theta_s = [$w_s$; $b_s$], updated only when bank $s$ is selected by the HMM router",
            fc="#eef7ff",ec="#2b5c90",fs=10,weight="bold")
    add_box(ax,0.20,0.06,0.28,0.09,"theta_banks(:,s)\n[  w_s  |  b_s  ]",fc="#f8fcff",ec="#2b5c90",fs=10,linestyle=(0,(5,3)))
    add_box(ax,0.52,0.06,0.28,0.09,"d_hat_per_bank(:,s)\n[ bank-local symbol history ]",fc="#fbfffb",ec="#4f7d3a",fs=10,linestyle=(0,(5,3)))
    add_text(ax,0.50,0.02,"Figure 5. State-local FFE/DFE bank structure inside Proposed MSB",fs=12,weight="bold")
    save_figure(fig,"figure5_state_local_ffe_dfe_bank_structure")


# =============================================================================
# Figure 6
# =============================================================================

def draw_figure6():
    fig, ax = setup_canvas(15.6,8.4)
    add_box(ax,0.03,0.12,0.94,0.76,"",fc="#ffffff",ec="#111",lw=1.1,linestyle=(0,(5,4)),radius=.018)
    # columns
    xs=[0.18,0.50,0.82]
    titles=[("Optional pilot warm start","train_all_prefix > 0\n\nupdate all banks if enabled","#eef7ff","#2b5c90"),
            ("Pilot separation","min(score_s)\n\nupdate selected pilot bank","#eef9e9","#4f7d3a"),
            ("Decision-directed tracking","HMM route -> active bank only","#f7eff9","#7d5aa6")]
    for i,(title,desc,fc,ec) in enumerate(titles):
        x=xs[i]
        ax.add_patch(Circle((x-0.11,0.73),0.018,fc=ec,ec="#111",lw=.8,zorder=4,alpha=.85))
        add_text(ax,x-0.11,0.73,str(i+1),fs=12,weight="bold",color="white")
        add_box(ax,x-0.13,0.58,0.26,0.18,f"{title}\n\n{desc}",fc=fc,ec=ec,fs=11,weight="bold")
    add_arrow(ax,0.31,0.67,0.37,0.67,lw=1.3,ms=12)
    add_arrow(ax,0.63,0.67,0.69,0.67,lw=1.3,ms=12)
    # rule boxes
    rules=[("Rule:\nd_ref = d(m),\nfor all banks\n(optional)","#eef7ff","#2b5c90"),
           ("Rule:\ns_upd = argmin score_s,\nerror = d(m) - y_s","#eef9e9","#4f7d3a"),
           ("Rule:\nd_ref = d_dec_s(s_hat),\nerror = d_dec - y_s","#f7eff9","#7d5aa6")]
    for i,(r,fc,ec) in enumerate(rules):
        x=xs[i]
        add_box(ax,x-0.13,0.36,0.26,0.16,r,fc=fc,ec=ec,fs=10,weight="bold")
    # timeline
    y=0.22
    ax.plot([0.08,0.93],[y,y],color="#111",lw=1.8)
    add_arrow(ax,0.90,y,0.94,y,color="#111",lw=1.8,ms=16)
    ticks=[(0.16,"n = 1"),(0.38,"optional warm start"),(0.58,"m <= trainLen"),(0.80,"DD phase")]
    for x,lab in ticks:
        ax.add_patch(Circle((x,y),0.015,fc="white",ec="#111",lw=1.2,zorder=5))
        ax.plot([x,x],[0.36,y+0.015],color="#111",lw=1.0,ls=(0,(5,4)))
        add_text(ax,x,y-0.045,lab,fs=11)
    add_text(ax,0.50,0.04,"Figure 6. Training and decision-directed update schedule in Proposed MSB",fs=12,weight="bold")
    save_figure(fig,"figure6_training_and_decision_directed_update_schedule")


# =============================================================================
# Figure 7
# =============================================================================

def draw_single_bank_panel(ax):
    lx, bw, bh = 0.07, 0.20, 0.065
    left_blocks = [
        (0.790, "Tx PAM-4\nSymbols", "#ffffff", "#777777", 8.4),
        (0.685, "Tx FFE Proxy", "#f3eefb", "#8066aa", 8.4),
        (0.580, "IEEE 802.3ck Channel\n(.s4p / Touchstone-to-symbol FIR)", "#fff8df", "#b8860b", 7.1),
        (0.455, "Markov Channel Stress", "#ffecec", "#e45745", 8.4),
        (0.305, "Adaptive\nFFE/DFE Equalizer", "#e9f4ff", "#2b6ca3", 8.3),
        (0.190, "Slicer", "#eff9ea", "#5d8a48", 8.4),
        (0.075, "BER / SER / Eye Metrics", "#f6f6f6", "#777777", 8.2),
    ]
    for idx, (yy, text, fc, ec, fs) in enumerate(left_blocks):
        h = 0.085 if idx == 3 else bh
        add_box(ax, lx, yy, bw, h, text, fc=fc, ec=ec, fs=fs,
                weight="bold" if idx in [3, 6] else "normal", zorder=3)
        if idx == 0: draw_pam4_icon(ax, lx, yy, bw, h)
        elif idx == 1: draw_fir_icon(ax, lx, yy, bw, h)
        elif idx == 2: draw_channel_icon(ax, lx, yy, bw, h)
        elif idx == 3: draw_noise_icons(ax, lx, yy, bw, h)
        elif idx == 4: draw_fir_icon(ax, lx, yy, bw, h)
        elif idx == 5: draw_slicer_icon(ax, lx, yy, bw, h)
        elif idx == 6:
            draw_bar_icon(ax, lx + 0.015, yy + 0.006, 0.05, 0.05)
            draw_eye_icon(ax, lx + 0.085, yy + 0.006, 0.07, 0.05)
    for y_top, y_bottom in [(0.790, 0.685), (0.685, 0.580), (0.580, 0.455),
                            (0.455, 0.305), (0.305, 0.190), (0.190, 0.075)]:
        add_arrow(ax, lx + bw/2, y_top, lx + bw/2, y_bottom + bh,
                  color="#111111", lw=1.1, ms=10)

    # Corrected single-bank feedback loop.
    blue = "#1f5fa8"
    x_slicer_out = lx + bw
    y_slicer_mid = 0.190 + bh * 0.55
    x_loop = 0.305
    y_eq_mid = 0.305 + bh * 0.55
    add_arrow(ax, x_slicer_out, y_slicer_mid, x_loop, y_slicer_mid, color=blue, lw=1.45, ms=9)
    add_arrow(ax, x_loop, y_slicer_mid, x_loop, y_eq_mid, color=blue, lw=1.45, ms=9)
    add_arrow(ax, x_loop, y_eq_mid, lx + bw, y_eq_mid, color=blue, lw=1.45, ms=12)
    ax.scatter([x_slicer_out], [y_slicer_mid], s=12, color=blue, zorder=9)
    add_text(ax, 0.306, 0.265, "Decisions /\nUpdate", fs=7.5, color=blue, ha="left", style="italic")


def draw_proposed_msb_panel(ax):
    rx, rbw, rbh = 0.40, 0.20, 0.065
    right_blocks = [
        (0.790, "Tx PAM-4\nSymbols", "#ffffff", "#777777", 8.4),
        (0.685, "Tx FFE Proxy", "#f3eefb", "#8066aa", 8.4),
        (0.580, "IEEE 802.3ck Channel\n(.s4p / Touchstone-to-symbol FIR)", "#fff8df", "#b8860b", 7.1),
        (0.455, "Markov Channel Stress", "#ffecec", "#e45745", 8.4),
        (0.325, "FIR residual\nscoring", "#e9f4ff", "#2b6ca3", 8.4),
        (0.210, "HMM Router", "#f5eefb", "#7d5aa6", 9.0),
    ]
    for idx, (yy, text, fc, ec, fs) in enumerate(right_blocks):
        h = 0.085 if idx == 3 else rbh
        add_box(ax, rx, yy, rbw, h, text, fc=fc, ec=ec, fs=fs,
                weight="bold" if idx in [3, 5] else "normal", zorder=3)
        if idx == 0: draw_pam4_icon(ax, rx, yy, rbw, h)
        elif idx == 1: draw_fir_icon(ax, rx, yy, rbw, h)
        elif idx == 2: draw_channel_icon(ax, rx, yy, rbw, h)
        elif idx == 3: draw_noise_icons(ax, rx, yy, rbw, h)
        elif idx == 4:
            draw_bar_icon(ax, rx+0.02, yy+0.006, 0.055, 0.05)
            points = [(0.55, 0.38), (0.62, 0.62), (0.70, 0.42), (0.78, 0.67), (0.86, 0.50)]
            for px, py in points:
                ax.scatter([rx + rbw*px], [yy + rbh*py], s=5, color="#555555", zorder=6)
            add_text(ax, rx + rbw*0.92, yy + rbh*0.5, "...", fs=10)
        elif idx == 5:
            cx, cy = rx + rbw*0.19, yy + rbh*0.45
            for dx, label in [(0, "S1"), (0.06, "S2"), (0.13, "SN")]:
                ax.add_patch(Circle((cx + dx, cy), 0.014, fc="#f7f1ff", ec="#555555", lw=0.7, zorder=5))
                add_text(ax, cx + dx, cy, label, fs=6)
            add_arrow(ax, cx + 0.014, cy, cx + 0.046, cy, color="#555555", lw=0.65, ms=7, rad=0.25)
            add_arrow(ax, cx + 0.074, cy, cx + 0.116, cy, color="#555555", lw=0.65, ms=7, rad=0.25)
            mx, my = rx + rbw*0.75, yy + rbh*0.20
            for ii in range(4):
                for jj in range(4):
                    ax.add_patch(Rectangle((mx + jj*0.009, my + ii*0.009), 0.009, 0.009,
                                           fc="#ffffff", ec="#777777", lw=0.3, zorder=5))
            add_text(ax, mx + 0.018, my + 0.050, "P=[pij]", fs=6.5)
    for y_top, y_bottom in [(0.790, 0.685), (0.685, 0.580), (0.580, 0.455),
                            (0.455, 0.325), (0.325, 0.210)]:
        add_arrow(ax, rx + rbw/2, y_top, rx + rbw/2, y_bottom + rbh,
                  color="#111111", lw=1.1, ms=10)

    # Receiver bank group
    add_box(ax, 0.705, 0.355, 0.18, 0.36, "", fc=(1, 1, 1, 0), ec="#2a70b8",
            lw=1.0, linestyle="--", radius=0.012, zorder=2)
    add_text(ax, 0.795, 0.735, "Receiver Banks (S state banks)", fs=8.6, weight="bold", color="#1b55a5")
    for yy, label in [(0.635, "Bank 1\nFFE/DFE +\nEB-aware SMNLMS"),
                      (0.525, "Bank 2\nFFE/DFE +\nEB-aware SMNLMS"),
                      (0.395, "Bank S\nFFE/DFE +\nEB-aware SMNLMS")]:
        add_box(ax, 0.725, yy, 0.135, 0.074, label, fc="#eaf4ff", ec="#2a70b8",
                fs=6.7, weight="bold", zorder=3)
        draw_fir_icon(ax, 0.790, yy, 0.065, 0.065)
    add_text(ax, 0.795, 0.495, "...", fs=13, weight="bold")

    add_arrow(ax, rx + rbw, 0.240, 0.725, 0.672, color="#777777", lw=1.05, linestyle="--", rad=-0.07, ms=9)
    add_arrow(ax, rx + rbw, 0.240, 0.725, 0.562, color="#d7191c", lw=1.35, rad=0.03, ms=11)
    add_arrow(ax, rx + rbw, 0.240, 0.725, 0.432, color="#777777", lw=1.05, linestyle="--", rad=0.09, ms=9)
    add_text(ax, 0.868, 0.548, "Active Bank\n(Selected)", fs=7.5, color="#d7191c", weight="bold", ha="left")

    add_box(ax, 0.900, 0.330, 0.060, 0.090, "Slicer", fc="#eff9ea", ec="#5d8a48", fs=7.3, weight="bold", zorder=3)
    draw_slicer_icon(ax, 0.900, 0.330, 0.060, 0.090)
    add_box(ax, 0.840, 0.160, 0.120, 0.080, "BER / SER /\nEye Metrics",
            fc="#f6f6f6", ec="#777777", fs=7.7, weight="bold", zorder=3)
    draw_bar_icon(ax, 0.845, 0.168, 0.035, 0.050)
    draw_eye_icon(ax, 0.887, 0.168, 0.045, 0.050)
    add_arrow(ax, 0.860, 0.562, 0.925, 0.420, color="#d7191c", lw=1.35, rad=-0.08, ms=11)
    add_arrow(ax, 0.925, 0.330, 0.900, 0.240, color="#111111", lw=1.1, ms=10)

    blue = "#1f5fa8"
    add_arrow(ax, 0.900, 0.360, 0.795, 0.355, color=blue, lw=1.25, rad=-0.25, ms=10)
    add_arrow(ax, 0.795, 0.355, 0.795, 0.395, color=blue, lw=1.25, ms=10)
    add_text(ax, 0.805, 0.325, "Decisions /\nUpdate", fs=7, color=blue, style="italic")

    purple = "#7d3c98"
    add_arrow(ax, rx + rbw*0.5, 0.210, rx + rbw*0.5, 0.150,
              color=purple, lw=1.05, linestyle=(0, (2, 2)), ms=9)
    add_arrow(ax, rx + rbw*0.5, 0.150, 0.840, 0.200,
              color=purple, lw=1.05, linestyle=(0, (2, 2)), ms=9)
    add_text(ax, 0.720, 0.170, "State Statistics", fs=6.2, color=purple)

def draw_figure7():
    fig, ax = setup_canvas(15.6, 9.0)
    add_box(ax, 0.015, 0.10, 0.31, 0.80, "", fc="#f0f7ff", ec="#5b8cc5", lw=1.25, radius=0.018, zorder=1)
    add_box(ax, 0.350, 0.10, 0.635, 0.80, "", fc="#f5fbef", ec="#5a944a", lw=1.25, radius=0.018, zorder=1)
    add_text(ax, 0.170, 0.875, "(a) Single Bank", fs=12, weight="bold")
    add_text(ax, 0.665, 0.875, "(b) Proposed MSB", fs=12, weight="bold")
    draw_single_bank_panel(ax)
    draw_proposed_msb_panel(ax)
    # Legend
    red, gray, blue, purple = "#d7191c", "#777777", "#1f5fa8", "#7d3c98"
    add_box(ax, 0.825, 0.750, 0.135, 0.120, "", fc="#ffffff", ec="#777777", lw=0.8, linestyle="--", radius=0.006, zorder=3)
    legend_items = [(red, "-", "Signal Path (active)"),
                    (gray, "--", "Signal Path (inactive)"),
                    (blue, "-", "Feedback / Update"),
                    (purple, (0, (2, 2)), "Control / Statistics")]
    for i, (color, linestyle, label) in enumerate(legend_items):
        y = 0.845 - i * 0.026
        ax.plot([0.845, 0.877], [y, y], color=color, lw=1.15, ls=linestyle, zorder=5)
        add_arrow(ax, 0.866, y, 0.877, y, color=color, lw=1.15, ms=7)
        add_text(ax, 0.890, y, label, fs=6.5, ha="left")
    add_text(ax, 0.50, 0.035, "Figure 7.  Single-Bank Receiver versus Proposed MSB Receiver", fs=12.5, weight="bold")
    save_figure(fig, "figure7_single_bank_receiver_versus_proposed_msb")


# =============================================================================
# Figure 8
# =============================================================================

def draw_figure8():
    fig, ax = setup_canvas(15.6, 8.8)
    xs=[0.08,0.22,0.46,0.67,0.78,0.90]
    titles=["FIR residual\nfeatures","Emission\nLikelihood","Forward (Filtering) Recursion",
            "State\nPosterior","MAP\nDecision","Router Output /\nActive Bank\nSelection"]
    colors=[("#eef7ff","#2b5c90"),("#f7eff9","#7d5aa6"),("#eef9e9","#4f7d3a"),
            ("#fff7e4","#c99a00"),("#fff3e8","#d55e00"),("#eafafa","#008080")]
    widths=[0.12,0.13,0.30,0.12,0.12,0.12]
    for i,(x,t,(fc,ec),w) in enumerate(zip(xs,titles,colors,widths),start=1):
        add_box(ax,x-w/2,0.20,w,0.62,"",fc=fc,ec=ec,lw=1.0,radius=.012)
        ax.add_patch(Circle((x-w/2+0.06,0.86),0.018,fc="white",ec=ec,lw=1.4,zorder=5))
        add_text(ax,x-w/2+0.06,0.86,str(i),fs=12,weight="bold")
        add_text(ax,x,0.78,t,fs=10,weight="bold")
        if i < 6:
            add_arrow(ax,x+w/2,0.51,xs[i]-widths[i]/2,0.51,lw=1.2,ms=11)
    # observed vector
    x=xs[0]; w=widths[0]
    add_box(ax,x-w/2+0.01,0.62,w-0.02,0.10,"",fc="#f8fcff",ec="#2b5c90")
    ts=np.linspace(0,1,80); rng=np.random.default_rng(0)
    ax.plot(x-w/2+0.02+ts*(w-0.04),0.67+0.015*rng.normal(size=80),color="#2a6fba",lw=.8)
    for i in range(5):
        ax.add_patch(Rectangle((x-w/2+0.02+i*0.025,0.52),0.018,0.025,fc="#8bb6e8",ec="#2b5c90",lw=.5))
    add_text(ax,x,0.43,r"$q_s(k)=(r_k-\hat r_k^{(s)})^2$",fs=8)
    # emission likelihood
    x=xs[1]; w=widths[1]
    for j,lab in enumerate([r"$\Lambda_1(k)\propto e^{-q_1/\tau}$",
                            r"$\Lambda_2(k)\propto e^{-q_2/\tau}$",
                            "...",
                            r"$\Lambda_S(k)\propto e^{-q_S/\tau}$"]):
        add_box(ax,x-w/2+0.02,0.62-j*0.10,w-0.04,0.055,lab,fc="#f8f4ff",ec="#7d5aa6",fs=7)
    # forward recursion
    x=xs[2]; w=widths[2]
    add_text(ax,x-0.08,0.71,"Time $k-1$",fs=9)
    add_text(ax,x+0.08,0.71,"Time $k$",fs=9)
    yvals=[0.65,0.55,0.38]
    labs=["1","2","N"]
    for y,lab in zip(yvals,labs):
        ax.add_patch(Circle((x-0.08,y),0.018,fc="#eef9e9",ec="#4f7d3a",lw=1.0))
        ax.add_patch(Circle((x+0.08,y),0.018,fc="#eef9e9",ec="#4f7d3a",lw=1.0))
        add_text(ax,x-0.08,y,lab,fs=10)
        add_text(ax,x+0.08,y,lab,fs=10)
        add_arrow(ax,x-0.14,y,x-0.10,y,lw=.9,ms=8)
        add_arrow(ax,x+0.10,y,x+0.14,y,lw=.9,ms=8)
    for ya in yvals:
        for yb in yvals:
            add_arrow(ax,x-0.06,ya,x+0.06,yb,lw=.6,ms=5)
    add_box(ax,x-w/2+0.03,0.30,w-0.06,0.08,r"$\alpha_j(k)=\Lambda_j(k)\sum_{i=1}^{N}\alpha_i(k-1)p_{ij}$",
            fc="#f8fff8",ec="#4f7d3a",fs=10)
    add_box(ax,x-w/2+0.03,0.21,w-0.06,0.07,r"Normalization:  $\hat{\alpha}_j(k)=\frac{\alpha_j(k)}{\sum_{m=1}^{N}\alpha_m(k)}$",
            fc="#f8fff8",ec="#4f7d3a",fs=10)
    # posterior bars
    x=xs[3]; w=widths[3]
    vals=[.35,.25,.18,.28,.48]
    for i,v in enumerate(vals):
        ax.add_patch(Rectangle((x-0.04+i*0.015,0.48),0.010,v*0.18,fc="#e0b72b",ec="#8a651a",lw=.4))
    ax.plot([x-0.05,x+0.05],[0.48,0.48],color="#111",lw=.8)
    add_text(ax,x,0.35,r"$\hat{\alpha}_j(k)=P(s_k=j|r_{1:k})$",fs=9)
    # MAP
    x=xs[4]; w=widths[4]
    add_box(ax,x-w/2+0.02,0.42,w-0.04,0.14,r"$\hat{s}_k=\arg\max_j \hat{\alpha}_j(k)$",
            fc="#fff8ee",ec="#d55e00",fs=12)
    # output
    x=xs[5]; w=widths[5]
    ax.add_patch(Circle((x,0.58),0.045,fc="#eafafa",ec="#008080",lw=1.0))
    add_text(ax,x,0.58,r"$j^*=\hat{s}_k$",fs=11)
    add_text(ax,x,0.68,"Chosen State",fs=9,weight="bold",color="#006b6b")
    add_arrow(ax,x,0.535,x,0.49,color="#111",lw=1,ms=9)
    add_text(ax,x,0.46,"Route to",fs=9,weight="bold",color="#006b6b")
    add_box(ax,x-0.04,0.34,0.08,0.08,"Bank $j^*$",fc="#f8ffff",ec="#008080",fs=10,linestyle=(0,(5,3)))
    for i in range(4):
        ax.add_patch(Rectangle((x-0.035+i*0.015,0.355),0.012,0.025,fc="#9fc9c9",ec="#006b6b",lw=.4))
    # transition estimation
    add_box(ax,0.22,0.07,0.18,0.08,"Assumed transition prior\n$P_{ij}=P(s_k=j|s_{k-1}=i)$\nfixed for a stress profile",
            fc="#eef7ff",ec="#2b5c90",fs=7.5)
    add_arrow(ax,0.08,0.20,0.08,0.11,color="#111",lw=.9,linestyle="--",ms=8)
    add_arrow(ax,0.08,0.11,0.22,0.11,color="#111",lw=.9,linestyle="--",ms=8)
    add_arrow(ax,0.46,0.20,0.46,0.11,color="#111",lw=.9,linestyle="--",ms=8)
    add_arrow(ax,0.40,0.11,0.46,0.11,color="#111",lw=.9,linestyle="--",ms=8)
    add_text(ax,0.50,0.035,"Figure 8. Schematic Diagram of HMM Router for Channel State Classification",fs=12,weight="bold")
    save_figure(fig,"figure8_hmm_router_schematic")


# =============================================================================
# Figure 9
# =============================================================================

def numbered_block(ax, x, y, w, h, title, fc, ec, num):
    add_box(ax, x, y, w, h, "", fc=fc, ec=ec, lw=1.0, radius=0.010, zorder=3)
    add_text(ax, x+0.012, y+h-0.020, f"{num}) {title}", fs=8.7, weight="bold", color=ec, ha="left", va="top")

def draw_figure9():
    fig, ax = setup_canvas(15.6, 8.7)
    # left Markov chain
    add_box(ax, 0.025, 0.18, 0.13, 0.70, "Hidden Markov\nChannel State",
            fc="#f5efff", ec="#8e62c8", lw=1.1, fs=8.7, weight="bold")
    for x, y, s in [(0.09, 0.75, "$S_1$"), (0.09, 0.58, "$S_2$"), (0.09, 0.31, "$S_S$")]:
        ax.add_patch(Circle((x, y), 0.028, fc="#d8c4ff", ec="#6f43b7", lw=1.0, zorder=5))
        add_text(ax, x, y, s, fs=11, style="italic")
    add_arrow(ax, 0.09, 0.72, 0.09, 0.61, rad=0.25, ms=8)
    add_arrow(ax, 0.09, 0.61, 0.09, 0.72, rad=0.25, ms=8)
    add_text(ax, 0.06, 0.665, "$p_{12}$", fs=8)
    add_text(ax, 0.122, 0.665, "$p_{21}$", fs=8)
    add_text(ax, 0.09, 0.445, "...", fs=14)
    add_arrow(ax, 0.09, 0.34, 0.09, 0.55, rad=-0.25, ms=8)
    add_text(ax, 0.047, 0.435, "$p_{ij}=$\n$P(s_k=S_j|$\n$s_{k-1}=S_i)$", fs=7.5, ha="left")
    add_text(ax, 0.128, 0.22, "$p_{SS}$", fs=7.5)

    numbered_block(ax, 0.22, 0.74, 0.24, 0.12, "State-Dependent Channel FIR", "#eef7ff", "#2a78d2", 1)
    ax.plot([0.245, 0.410], [0.785, 0.785], color="#333333", lw=0.8)
    for xx in [0.245, 0.29, 0.34, 0.405]:
        ax.plot([xx, xx], [0.765, 0.815], color="#2a78d2", lw=1.0)
        ax.scatter([xx], [0.785], s=25, fc="#65a9ff", ec="#1f4e8c", zorder=6)
    add_text(ax, 0.245, 0.745, "0", fs=7)
    add_text(ax, 0.29, 0.745, "1", fs=7)
    add_text(ax, 0.405, 0.745, "L", fs=7)
    add_text(ax, 0.318, 0.832, "$h_l^{(s_k)}$", fs=11, style="italic")
    add_text(ax, 0.430, 0.790, "$h^{(s_k)}=[h_0,...,h_L]^T$", fs=9.5)

    numbered_block(ax, 0.22, 0.57, 0.28, 0.12, "ISI / Memory Effect", "#eefcf9", "#008080", 2)
    add_text(ax, 0.245, 0.625, "Past transmitted symbols", fs=6.5, ha="left")
    for i, lab in enumerate(["$a_{k-1}$", "$a_{k-2}$", "...", "$a_{k-L}$"]):
        add_box(ax, 0.245+i*0.055, 0.585, 0.045, 0.032, lab, fc="#e3f5dd",
                ec="#96ba8f", fs=6.4, radius=0.003, lw=0.7, zorder=4)
    add_arrow(ax, 0.440, 0.602, 0.465, 0.602, color="#5aa05a", lw=1.05, ms=11)
    add_text(ax, 0.462, 0.610, "$v_k^{ISI}=\\sum_{l=1}^{L}h_l^{(s_k)}a_{k-l}$", fs=8.5, ha="left")

    numbered_block(ax, 0.22, 0.39, 0.28, 0.13, "Decision-Directed / Nonlinear Disturbance", "#fff7df", "#c47b00", 3)
    add_text(ax, 0.245, 0.455, "Previous detected symbols", fs=6.5, ha="left")
    for i, lab in enumerate([r"$\hat{a}_{k-1}$", r"$\hat{a}_{k-2}$", "...", r"$\hat{a}_{k-M}$"]):
        add_box(ax, 0.245+i*0.055, 0.413, 0.045, 0.032, lab, fc="#fff1c7",
                ec="#c7a357", fs=5.8, radius=0.003, lw=0.7, zorder=4)
    add_arrow(ax, 0.440, 0.430, 0.465, 0.430, color="#c47b00", lw=1.05, ms=11)
    add_text(ax, 0.462, 0.452, "$v_k^{DD/NL}=$", fs=8.5, ha="left")
    add_text(ax, 0.462, 0.420, "$g_s(\\hat{a}_{k-1},...,\\hat{a}_{k-M})$", fs=7.5, ha="left")

    numbered_block(ax, 0.22, 0.21, 0.28, 0.13, "Optional Disturbance / Reliability Regime", "#fff0f0", "#d9534f", 4)
    add_text(ax, 0.265, 0.265, "$n_k\\sim\\mathcal{N}(0,\\sigma_v^2)$  plus optional bursts", fs=9.0, ha="left")
    gx = np.linspace(-2.5, 2.5, 100)
    gy = np.exp(-gx**2 / 2)
    gx2 = 0.405 + 0.07 * (gx - gx.min()) / (gx.max() - gx.min())
    gy2 = 0.235 + 0.07 * gy / gy.max()
    ax.plot(gx2, gy2, color="#d9534f", lw=1.1)
    ax.plot([0.405, 0.475], [0.235, 0.235], color="#777777", lw=0.7)
    add_text(ax, 0.414, 0.222, "AWGN / XTALK / jitter stress", fs=7.4, ha="left")

    for y in [0.80, 0.63, 0.455, 0.275]:
        add_arrow(ax, 0.155, 0.58, 0.22, y, color="#111111", lw=1.0, rad=0.08, ms=9)

    add_box(ax, 0.55, 0.47, 0.13, 0.27,
            "Composite\nReceived\nSample\n\n"
            "$r_k=$\n$\\sum_l h_l^{(s_k)}a_{k-l}$\n$+v_k^{DD/NL}$\n$+n_k$",
            fc="#eef7ff", ec="#2a78d2", fs=8.2, weight="bold")
    add_text(ax, 0.615, 0.485, "(Endogenous /\nrouting-dependent risk)", fs=6.8, color="#0a4d91")
    add_arrow(ax, 0.46, 0.80, 0.55, 0.70, color="#111111", lw=1.1, ms=9)
    add_arrow(ax, 0.50, 0.63, 0.55, 0.60, color="#111111", lw=1.1, ms=9)
    add_arrow(ax, 0.50, 0.455, 0.55, 0.55, color="#111111", lw=1.1, ms=9)
    add_arrow(ax, 0.50, 0.275, 0.55, 0.50, color="#111111", lw=1.1, ms=9)

    add_box(ax, 0.71, 0.35, 0.14, 0.38, "Burst-Error /\nState-Transition Region",
            fc="#f7f0ff", ec="#8e62c8", fs=8.2, weight="bold")
    add_text(ax, 0.78, 0.660, "Rapid state changes", fs=6.8)
    for cx, lab in [(0.742, "$S_i$"), (0.780, "$S_j$"), (0.822, "$S_k$")]:
        ax.add_patch(Circle((cx, 0.625), 0.014, fc="#e2d3ff", ec="#6f43b7", lw=0.8, zorder=5))
        add_text(ax, cx, 0.625, lab, fs=6)
    add_arrow(ax, 0.756, 0.625, 0.766, 0.625, lw=0.75, ms=7)
    add_arrow(ax, 0.795, 0.625, 0.808, 0.625, lw=0.75, ms=7)
    add_text(ax, 0.78, 0.555, "Enhanced disturbance", fs=6.8)
    xs = np.linspace(0, 1, 100)
    rng = np.random.default_rng(1)
    wave = 0.52 + 0.025*np.sin(12*np.pi*xs) + 0.012*rng.normal(size=100)
    ax.plot(0.728 + 0.105*xs, wave, color="#222222", lw=0.85)
    for cx in [0.765, 0.81]:
        ax.add_patch(Circle((cx, 0.525), 0.026, fc=(1, 1, 1, 0), ec="#d9534f", lw=1.0, ls="--"))
    add_text(ax, 0.78, 0.465, "Clustered errors", fs=6.8)
    for i, b in enumerate(["0", "0", "1", "1", "1", "0", "1", "0", "..."]):
        fc = "#ffb3b3" if b == "1" else "#f8f8f8"
        add_box(ax, 0.724+i*0.013, 0.405, 0.012, 0.025, b, fc=fc, ec="#aaaaaa",
                fs=5.6, radius=0.001, lw=0.4, zorder=4)

    add_box(ax, 0.88, 0.32, 0.10, 0.46, "Receiver Impact", fc="#fff5ea",
            ec="#e2761b", fs=8.8, weight="bold")
    add_box(ax, 0.895, 0.655, 0.070, 0.075, "", fc="#ffffff", ec="#e9b383",
            lw=0.7, radius=0.004, zorder=4)
    add_text(ax, 0.93, 0.718, "Eye closure", fs=6.3)
    draw_eye_icon(ax, 0.895, 0.655, 0.070, 0.075)
    ax.plot([0.900, 0.960], [0.704, 0.704], color="#e45745", lw=0.7, ls="--")
    add_box(ax, 0.895, 0.525, 0.070, 0.075, "", fc="#ffffff", ec="#e9b383",
            lw=0.7, radius=0.004, zorder=4)
    add_text(ax, 0.93, 0.588, "Threshold shift", fs=6.3)
    rng = np.random.default_rng(2)
    ax.scatter(0.91 + 0.015*rng.normal(size=55), 0.545 + 0.015*rng.normal(size=55),
               s=2, color="#1f77b4", alpha=0.8)
    ax.scatter(0.95 + 0.015*rng.normal(size=55), 0.545 + 0.015*rng.normal(size=55),
               s=2, color="#d62728", alpha=0.8)
    ax.plot([0.93, 0.93], [0.525, 0.585], color="#777777", ls="--", lw=0.7)
    add_arrow(ax, 0.918, 0.571, 0.948, 0.571, color="#5aa05a", lw=0.8, ms=7, arrowstyle="<->")
    add_box(ax, 0.895, 0.395, 0.070, 0.075, "", fc="#ffffff", ec="#e9b383",
            lw=0.7, radius=0.004, zorder=4)
    add_text(ax, 0.93, 0.458, "Burst errors", fs=6.3)
    for i, b in enumerate(["0", "1", "1", "1", "0", "1", "1", "0"]):
        fc = "#ffb3b3" if b == "1" else "#ffffff"
        add_box(ax, 0.902+i*0.007, 0.412, 0.0065, 0.025, b, fc=fc, ec="#aaaaaa",
                fs=5.0, radius=0.001, lw=0.3, zorder=5)
    add_text(ax, 0.93, 0.37, "...", fs=9)

    add_box(ax, 0.71, 0.17, 0.10, 0.075, "Detected symbol\n$\\hat{a}_k$",
            fc="#fbfbfb", ec="#777777", fs=8)
    add_arrow(ax, 0.68, 0.605, 0.71, 0.545, color="#111111", lw=1.15, ms=9)
    add_arrow(ax, 0.85, 0.545, 0.88, 0.545, color="#111111", lw=1.15, ms=9)
    add_arrow(ax, 0.93, 0.32, 0.76, 0.245, color="#111111", lw=1.1, rad=-0.10, ms=9)

    orange = "#e87511"
    add_arrow(ax, 0.76, 0.17, 0.76, 0.125, color=orange, lw=1.0, linestyle="--", ms=8)
    add_arrow(ax, 0.76, 0.125, 0.345, 0.125, color=orange, lw=1.0, linestyle="--", ms=8)
    add_arrow(ax, 0.345, 0.125, 0.345, 0.39, color=orange, lw=1.0, linestyle="--", ms=8)
    add_text(ax, 0.345, 0.095, "Decision-directed feedback\n(endogenous dependence)",
             fs=6.8, color=orange)
    add_arrow(ax, 0.445, 0.21, 0.445, 0.39, color=orange, lw=1.0, linestyle="--", ms=8)

    # Legend
    add_box(ax, 0.82, 0.10, 0.15, 0.075, "", fc="#ffffff", ec="#777777",
            lw=0.7, linestyle="--", radius=0.004, zorder=4)
    ax.plot([0.835, 0.865], [0.145, 0.145], color="#111111", lw=1.0)
    add_arrow(ax, 0.855, 0.145, 0.865, 0.145, color="#111111", lw=1.0, ms=7)
    add_text(ax, 0.875, 0.145, "Forward causal influence", fs=6.2, ha="left")
    ax.plot([0.835, 0.865], [0.117, 0.117], color=orange, lw=1.0, ls="--")
    add_arrow(ax, 0.855, 0.117, 0.865, 0.117, color=orange, lw=1.0, ms=7)
    add_text(ax, 0.875, 0.117, "Decision-directed endogenous feedback", fs=6.2, ha="left")
    add_text(ax, 0.50, 0.035, "Figure 9. Endogenous-Aware Noise Mechanism in the Proposed Receiver",
             fs=12.2, weight="bold")
    save_figure(fig, "figure9_endogenous_aware_noise_mechanism")


# =============================================================================
# Main
# =============================================================================

def main():
    draw_figure1()
    draw_figure2()
    draw_figure3()
    draw_figure4()
    draw_figure5()
    draw_figure6()
    draw_figure7()
    draw_figure8()
    draw_figure9()


if __name__ == "__main__":
    main()
