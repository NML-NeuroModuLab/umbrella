
#!/usr/bin/env python
"""
build_group_return_maps.py

For all MED Associates backup txt files in a selected input folder:

    - Parse Y (event codes) and Z (time stamps, s).
    - Identify Subject and MSN from the header.
    - Infer which lever is active from MSN:
        * 'L-GRN' -> left-active, press code = 3
        * 'R-GRN' -> right-active, press code = 4
    - Extract:
        * Lever-press start events (Y == 3 or 4 depending on MSN).
        * Magazine entry start events (Y == 7).
    - Compute IPI(n) and IPI(n+1) for:
        * Presses
        * Magazine entries
    - Assign each subject to a GROUP based on Subject name:
        * 'BP...' -> group 'BP'
        * 'CT...' -> group 'CT'
        * others are currently ignored

    - POOL IPI pairs WITHIN each group (BP or CT) across all subjects
      in the folder (e.g. BP1–BP8 and CT1–CT8 for one training day).

    - Generate GROUP-LEVEL return maps (IPI(n) vs IPI(n+1)):

        1) SQUARE SVG page with PRESS SCATTER ONLY (2 subplots: BP, CT)
        2) SQUARE SVG page with PRESS DENSITY ONLY (2 subplots: BP, CT)
        3) SQUARE SVG page with MAG SCATTER ONLY (2 subplots: BP, CT)

Usage:

    python build_group_return_maps.py "/path/to/medpc-files" --output-folder "/path/to/outputs"

Optional arguments:

    --pattern "*.txt"      Glob pattern for input files (default: "*.txt")
    --output-prefix "Day06" Prefix for output SVGs (default: "group_maps")
    --ipi_min 0.1          Minimum IPI in seconds (default: 0.1)
    --ipi_max 100.0        Maximum IPI in seconds (default: 100.0)
    --nbins 40             Number of log-spaced bins per axis (default: 40)
    --smooth_sigma 1.0     Gaussian sigma for density smoothing (default: 1.0)

Output:

    <out_prefix>_group_press_scatter.svg
    <out_prefix>_group_press_density.svg
    <out_prefix>_group_mag_scatter.svg

----------------------------------------------------------------------
IMPORTANT: GLOBAL DENSITY VALUES
----------------------------------------------------------------------

Pass the global maximum press-bin density obtained from
'search_max_density.py' using --press-density-max, with the same number of
bins and IPI range.

For example, if search_max_density_output.txt said:

    Global max press density: 2.0

then run this script with:

    --press-density-max 2.0

We are not currently using a density LUT for mag checks (scatter only).
"""

import argparse
import math
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
from scipy.ndimage import gaussian_filter

# ---------------------------------------------------------------------
# ===== DEFAULT DENSITY VALUE (OVERRIDABLE ON THE COMMAND LINE) =====
# ---------------------------------------------------------------------

GLOBAL_PRESS_DENSITY_MAX = 4.0   # <- set from search_max_density output

# Default IPI range and binning (make sure matches calibration)
DEFAULT_IPI_MIN = 0.1
DEFAULT_IPI_MAX = 100.0
DEFAULT_NBINS   = 40   # coarser grid, clearer gradients


# ---------------------------------------------------------------------
# MED txt parsing utilities
# ---------------------------------------------------------------------

def parse_header(path):
    """Parse header to extract Subject and MSN."""
    subject = "Unknown"
    msn = ""
    with open(path, "r") as f:
        for line in f:
            if line.startswith("Subject:"):
                subject = line.split(":", 1)[1].strip()
            elif line.startswith("MSN:"):
                msn = line.split(":", 1)[1].strip()
                break
    return subject, msn


def detect_active_lever_code(msn_line):
    """Infer which lever is active from MSN."""
    msn = msn_line
    if "L-GRN" in msn:
        return 3
    elif "R-GRN" in msn:
        return 4
    else:
        raise RuntimeError(f"Could not infer lever side from MSN: {msn!r}")


def parse_YZ_arrays(path):
    """Parse MED txt to Y, Z arrays."""
    with open(path, "r") as f:
        lines = f.readlines()

    arrays = {}
    current = None
    values = []

    def flush_current():
        nonlocal current, values, arrays
        if current is not None and values:
            arrays[current] = np.array(values, dtype=float)
        current = None
        values = []

    array_names = {"Y", "Z"}

    for line in lines:
        s = line.strip()
        if len(s) >= 2 and s[0] in array_names and s[1] == ":":
            flush_current()
            current = s[0]
            values = []
            continue

        if current is not None and s:
            if ":" in s:
                _, rest = s.split(":", 1)
            else:
                rest = s
            for tok in rest.split():
                try:
                    values.append(float(tok))
                except ValueError:
                    pass

    flush_current()

    def trim_trailing_zeros(arr):
        if arr is None or arr.size == 0:
            return np.array([], dtype=float)
        nz = np.nonzero(arr)[0]
        if nz.size == 0:
            return np.array([], dtype=float)
        return arr[: nz[-1] + 1]

    Y = trim_trailing_zeros(arrays.get("Y"))
    Z = trim_trailing_zeros(arrays.get("Z"))
    return Y, Z


# ---------------------------------------------------------------------
# Event extraction and IPI computation
# ---------------------------------------------------------------------

def extract_event_times(Y, Z, code):
    mask = (Y == code)
    return Z[mask]


def compute_ipi_pairs(times, min_isi=0.01):
    times = np.asarray(times, dtype=float)
    if times.size < 3:
        return np.array([]), np.array([])
    ipis = np.diff(times)
    ipis = ipis[ipis > min_isi]
    if ipis.size < 2:
        return np.array([]), np.array([])
    return ipis[:-1], ipis[1:]


# ---------------------------------------------------------------------
# Plotting helpers
# ---------------------------------------------------------------------

def set_log_square_axes(ax, ipi_min, ipi_max):
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(ipi_min, ipi_max)
    ax.set_ylim(ipi_min, ipi_max)
    ax.set_aspect("equal", adjustable="box")


def plot_press_scatter_only(ax, ipi_n, ipi_n1, ipi_min, ipi_max):
    """Scatter-only press map."""
    ipi_n = np.asarray(ipi_n)
    ipi_n1 = np.asarray(ipi_n1)

    mask = ((ipi_n >= ipi_min) & (ipi_n <= ipi_max) &
            (ipi_n1 >= ipi_min) & (ipi_n1 <= ipi_max))
    x = ipi_n[mask]
    y = ipi_n1[mask]

    if x.size == 0:
        ax.text(0.5, 0.5, "No press\ndata",
                ha="center", va="center", fontsize=9,
                transform=ax.transAxes)
        set_log_square_axes(ax, ipi_min, ipi_max)
        return

    ax.scatter(x, y, s=6, c="black", alpha=0.6, edgecolors="none")
    set_log_square_axes(ax, ipi_min, ipi_max)


def plot_press_density_only(ax,
                            ipi_n,
                            ipi_n1,
                            ipi_min,
                            ipi_max,
                            nbins,
                            vmax,
                            smooth_sigma=1.0):
    """Density-only press map (2D hist + Gaussian smoothing)."""
    ipi_n = np.asarray(ipi_n)
    ipi_n1 = np.asarray(ipi_n1)

    mask = ((ipi_n >= ipi_min) & (ipi_n <= ipi_max) &
            (ipi_n1 >= ipi_min) & (ipi_n1 <= ipi_max))
    x = ipi_n[mask]
    y = ipi_n1[mask]

    if x.size == 0:
        ax.text(0.5, 0.5, "No press\ndata",
                ha="center", va="center", fontsize=9,
                transform=ax.transAxes)
        set_log_square_axes(ax, ipi_min, ipi_max)
        return None

    edges = np.logspace(np.log10(ipi_min), np.log10(ipi_max), nbins + 1)
    H, xedges, yedges = np.histogram2d(x, y, bins=[edges, edges])

    if smooth_sigma is not None and smooth_sigma > 0:
        H = gaussian_filter(H, sigma=smooth_sigma)

    H = H.T  # rows = y
    pcm = ax.pcolormesh(xedges, yedges, H,
                        cmap="jet", shading="auto",
                        vmin=0, vmax=vmax)

    set_log_square_axes(ax, ipi_min, ipi_max)
    return pcm


def plot_mag_scatter_only(ax, ipi_n, ipi_n1, ipi_min, ipi_max):
    """Scatter-only mag map."""
    ipi_n = np.asarray(ipi_n)
    ipi_n1 = np.asarray(ipi_n1)

    mask = ((ipi_n >= ipi_min) & (ipi_n <= ipi_max) &
            (ipi_n1 >= ipi_min) & (ipi_n1 <= ipi_max))
    x = ipi_n[mask]
    y = ipi_n1[mask]

    if x.size == 0:
        ax.text(0.5, 0.5, "No mag\ndata",
                ha="center", va="center", fontsize=9,
                transform=ax.transAxes)
        set_log_square_axes(ax, ipi_min, ipi_max)
        return

    ax.scatter(x, y, s=6, c="red", alpha=0.5, edgecolors="none")
    set_log_square_axes(ax, ipi_min, ipi_max)


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Build GROUP-LEVEL return maps (BP vs CT) from MED txt files."
    )
    parser.add_argument(
        "input_folder", type=Path,
        help="Folder containing the MED-PC text files."
    )
    parser.add_argument(
        "--pattern", default="*.txt",
        help="Glob pattern for input MED txt files (default: *.txt)"
    )
    parser.add_argument(
        "--output-prefix", "--out_prefix", dest="output_prefix",
        default="group_maps",
        help="Prefix for output SVG filenames (default: group_maps)"
    )
    parser.add_argument(
        "--output-folder", type=Path,
        help="Destination folder (default: the input folder)."
    )
    parser.add_argument(
        "--press-density-max", type=float, default=GLOBAL_PRESS_DENSITY_MAX,
        help="Shared maximum for the press-density colour scale (default: 4.0)."
    )
    parser.add_argument(
        "--ipi_min", type=float, default=DEFAULT_IPI_MIN,
        help="Minimum IPI (sec) (default: 0.1)"
    )
    parser.add_argument(
        "--ipi_max", type=float, default=DEFAULT_IPI_MAX,
        help="Maximum IPI (sec) (default: 100.0)"
    )
    parser.add_argument(
        "--nbins", type=int, default=DEFAULT_NBINS,
        help="Number of log-spaced bins per axis for density (default: 40)"
    )
    parser.add_argument(
        "--smooth_sigma", type=float, default=1.0,
        help="Gaussian sigma for density smoothing (default: 1.0)"
    )

    args = parser.parse_args()

    input_folder = args.input_folder.expanduser().resolve()
    if not input_folder.is_dir():
        raise NotADirectoryError(f"Input folder not found: {input_folder}")
    output_folder = (
        args.output_folder.expanduser().resolve()
        if args.output_folder
        else input_folder
    )
    output_folder.mkdir(parents=True, exist_ok=True)

    files = sorted(input_folder.glob(args.pattern))
    if not files:
        print(f"No files found matching {args.pattern!r} in {input_folder}")
        return

    # Pool IPIs by group
    groups = {
        "BP": {"press_n": [], "press_n1": [], "mag_n": [], "mag_n1": []},
        "CT": {"press_n": [], "press_n1": [], "mag_n": [], "mag_n1": []},
    }

    for path in files:
        subject, msn = parse_header(path)
        Y, Z = parse_YZ_arrays(path)
        press_code = detect_active_lever_code(msn)

        press_times = extract_event_times(Y, Z, press_code)
        mag_times   = extract_event_times(Y, Z, 7)

        ipi_n_press, ipi_n1_press = compute_ipi_pairs(press_times)
        ipi_n_mag,   ipi_n1_mag   = compute_ipi_pairs(mag_times)

        # Determine group from subject name
        if subject.startswith("BP"):
            g = "BP"
        elif subject.startswith("CT"):
            g = "CT"
        else:
            # skip other subjects for now
            continue

        groups[g]["press_n"].append(ipi_n_press)
        groups[g]["press_n1"].append(ipi_n1_press)
        groups[g]["mag_n"].append(ipi_n_mag)
        groups[g]["mag_n1"].append(ipi_n1_mag)

    # Concatenate IPIs per group
    pooled = {}
    for g, data in groups.items():
        if data["press_n"]:
            pooled[g] = {
                "press_n":  np.concatenate(data["press_n"]),
                "press_n1": np.concatenate(data["press_n1"]),
                "mag_n":    np.concatenate(data["mag_n"]),
                "mag_n1":   np.concatenate(data["mag_n1"]),
            }
        else:
            pooled[g] = {
                "press_n":  np.array([]),
                "press_n1": np.array([]),
                "mag_n":    np.array([]),
                "mag_n1":   np.array([]),
            }

    group_labels = ["BP", "CT"]

    # -----------------------------------------------------------------
    # Figure 1: PRESS SCATTER – 2 panels (BP, CT)
    # -----------------------------------------------------------------
    fig_ps, axes_ps = plt.subplots(
        1, 2, figsize=(8, 4), squeeze=False
    )
    fig_ps.suptitle("Group-level return maps of lever presses – scatter", fontsize=14)

    for i, g in enumerate(group_labels):
        ax = axes_ps[0][i]
        plot_press_scatter_only(
            ax,
            pooled[g]["press_n"],
            pooled[g]["press_n1"],
            ipi_min=args.ipi_min,
            ipi_max=args.ipi_max,
        )
        ax.set_title(g, fontsize=10)
        ax.set_xlabel("IPI(n) (s)", fontsize=8)
        if i == 0:
            ax.set_ylabel("IPI(n+1) (s)", fontsize=8)
        else:
            ax.set_ylabel("")

    fig_ps.tight_layout(rect=[0, 0, 1.0, 0.93])
    out_scatter = output_folder / f"{args.output_prefix}_group_press_scatter.svg"
    fig_ps.savefig(out_scatter, format="svg")
    plt.close(fig_ps)
    print(f"Saved group press scatter maps to: {out_scatter}")

    # -----------------------------------------------------------------
    # Figure 2: PRESS DENSITY – 2 panels (BP, CT)
    # -----------------------------------------------------------------
    fig_pd, axes_pd = plt.subplots(
        1, 2, figsize=(8, 4), squeeze=False
    )
    fig_pd.suptitle("Group-level return maps of lever presses – density", fontsize=14)

    color_meshes = []

    for i, g in enumerate(group_labels):
        ax = axes_pd[0][i]
        pcm = plot_press_density_only(
            ax,
            pooled[g]["press_n"],
            pooled[g]["press_n1"],
            ipi_min=args.ipi_min,
            ipi_max=args.ipi_max,
            nbins=args.nbins,
            vmax=args.press_density_max,
            smooth_sigma=args.smooth_sigma,
        )
        if pcm is not None:
            color_meshes.append(pcm)

        ax.set_title(g, fontsize=10)
        ax.set_xlabel("IPI(n) (s)", fontsize=8)
        if i == 0:
            ax.set_ylabel("IPI(n+1) (s)", fontsize=8)
        else:
            ax.set_ylabel("")

    fig_pd.tight_layout(rect=[0, 0, 0.92, 0.93])

    if color_meshes:
        cax = fig_pd.add_axes([0.93, 0.18, 0.015, 0.64])
        cb = fig_pd.colorbar(color_meshes[0], cax=cax)
        cb.set_label("Count per bin (press)", fontsize=8)

    out_density = output_folder / f"{args.output_prefix}_group_press_density.svg"
    fig_pd.savefig(out_density, format="svg")
    plt.close(fig_pd)
    print(f"Saved group press density maps to: {out_density}")

    # -----------------------------------------------------------------
    # Figure 3: MAG SCATTER – 2 panels (BP, CT)
    # -----------------------------------------------------------------
    fig_ms, axes_ms = plt.subplots(
        1, 2, figsize=(8, 4), squeeze=False
    )
    fig_ms.suptitle("Group-level return maps of magazine checks – scatter", fontsize=14)

    for i, g in enumerate(group_labels):
        ax = axes_ms[0][i]
        plot_mag_scatter_only(
            ax,
            pooled[g]["mag_n"],
            pooled[g]["mag_n1"],
            ipi_min=args.ipi_min,
            ipi_max=args.ipi_max,
        )
        ax.set_title(g, fontsize=10)
        ax.set_xlabel("IPI(n) (s)", fontsize=8)
        if i == 0:
            ax.set_ylabel("IPI(n+1) (s)", fontsize=8)
        else:
            ax.set_ylabel("")

    fig_ms.tight_layout(rect=[0, 0, 1.0, 0.93])
    out_mag = output_folder / f"{args.output_prefix}_group_mag_scatter.svg"
    fig_ms.savefig(out_mag, format="svg")
    plt.close(fig_ms)
    print(f"Saved group mag scatter maps to: {out_mag}")


if __name__ == "__main__":
    main()
