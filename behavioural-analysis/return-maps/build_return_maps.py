
#!/usr/bin/env python
"""
build_return_maps.py

For all MED Associates backup txt files in a selected input folder:

    - Parse Y (event codes) and Z (time stamps, s).
    - Automatically detect which lever is active from the MSN line:
        * 'L-GRN' -> left-active, press code = 3
        * 'R-GRN' -> right-active, press code = 4
    - Extract:
        * Lever-press start events (Y == 3 or 4 depending on MSN).
        * Magazine entry start events (Y == 7).
    - Compute IPI(n) and IPI(n+1) for:
        * Presses
        * Magazine entries
    - Generate return maps (IPI(n) vs IPI(n+1)):

        1) One A4 SVG page with density + scatter for PRESS return maps,
           one subplot per subject.

        2) One A4 SVG page with SCATTER-ONLY return maps for MAGAZINE
           entries, one subplot per subject.

Usage:

    python build_return_maps.py "/path/to/medpc-files" --output-folder "/path/to/outputs"

Optional arguments:

    --pattern "*.txt"      Glob pattern for input files (default: "*.txt")
    --output-prefix "Day01" Prefix for output SVGs (default: "return_maps")
    --ipi_min 0.1          Minimum IPI in seconds (default: 0.1)
    --ipi_max 100.0        Maximum IPI in seconds (default: 100.0)
    --nbins 40             Number of log-spaced bins per axis (default: 40)

Output:

    <output-prefix>_press_scatter.svg
    <output-prefix>_press_density.svg
    <output-prefix>_mag.svg

----------------------------------------------------------------------
IMPORTANT: GLOBAL DENSITY VALUES
----------------------------------------------------------------------

Pass the global maximum press-bin density obtained from
'search_max_density.py' using --press-density-max. This controls the colour
LUT and makes density comparable across mice and days.

For example, if search_max_density_output.txt said:

    Global max press density: 2.0
    Global max mag   density: 6.0

then run this script with:

    --press-density-max 2.0

We are not currently using a density LUT for mag checks (scatter only),
but a placeholder is provided in case you want it later.
"""

import argparse
import math
from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

from scipy.ndimage import gaussian_filter

# ---------------------------------------------------------------------
# ===== DEFAULT DENSITY VALUES (OVERRIDABLE ON THE COMMAND LINE) =====
# ---------------------------------------------------------------------

GLOBAL_PRESS_DENSITY_MAX = 4.0   # <- set from search_max_density output
GLOBAL_MAG_DENSITY_MAX   = 11.0   # <- not used yet (mag plots are scatter only)

# Default IPI range and binning (match calibration script)
DEFAULT_IPI_MIN = 0.1
DEFAULT_IPI_MAX = 100.0
DEFAULT_NBINS   = 40 # Used to be 100 - 40 provides coarser grid → more counts/bin → clearer gradients


# ---------------------------------------------------------------------
# MED txt parsing utilities
# ---------------------------------------------------------------------

def parse_header(path):
    """
    Parse the header lines of a MED txt file to extract Subject and MSN.

    Returns
    -------
    subject : str
    msn : str
    """
    subject = "Unknown"
    msn = ""

    with open(path, "r") as f:
        for line in f:
            if line.startswith("Subject:"):
                subject = line.split(":", 1)[1].strip()
            elif line.startswith("MSN:"):
                msn = line.split(":", 1)[1].strip()
                break  # MSN is usually the last header field we need
    return subject, msn


def detect_active_lever_code(msn_line):
    """
    Infer which lever is active from the MSN string.

    Assumes:
        - 'L-GRN' -> left-active sessions (press code = 3)
        - 'R-GRN' -> right-active sessions (press code = 4)

    Returns
    -------
    press_code : int

    Raises
    ------
    RuntimeError if MSN does not contain 'L-GRN' or 'R-GRN'.
    """
    msn = msn_line
    if "L-GRN" in msn:
        return 3
    elif "R-GRN" in msn:
        return 4
    else:
        raise RuntimeError(f"Could not infer lever side from MSN: {msn!r}")


def parse_YZ_arrays(path):
    """
    Parse the MED txt file and return Y and Z as numpy arrays.

    - Finds 'Y:' and 'Z:' sections.
    - Reads all numeric values on subsequent lines until the next array
      or end of file.
    - Trims trailing zeros (after the session ends).

    Returns
    -------
    Y : np.ndarray (float)
        Event codes.
    Z : np.ndarray (float)
        Event timestamps in seconds.
    """
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

        # Start of array section: e.g. "Y:" or "Z:"
        if len(s) >= 2 and s[0] in array_names and s[1] == ":":
            flush_current()
            current = s[0]  # "Y" or "Z"
            values = []
            continue

        if current is not None and s:
            # Lines like " 0: 1.000 8.000 -8.000 ..."
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
    """
    Return timestamps (seconds) for events where Y == code.
    """
    mask = (Y == code)
    return Z[mask]


def compute_ipi_pairs(times, min_isi=0.01):
    """
    Compute IPI(n) and IPI(n+1) from a sequence of event times.

    Parameters
    ----------
    times : array-like
        Sorted event times in seconds.
    min_isi : float
        Minimum IPI to keep (sec).

    Returns
    -------
    ipi_n : np.ndarray
    ipi_n1 : np.ndarray
    """
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

def plot_press_return_map(ax,
                          ipi_n,
                          ipi_n1,
                          ipi_min,
                          ipi_max,
                          nbins,
                          vmax,
                          smooth_sigma=1.0):
    """
    Plot a PRESS return map as a *density only* heatmap
    (no scatter). Uses log-log 2D histogram optionally smoothed
    with a Gaussian.
    """
    import numpy as np
    
    ipi_n = np.asarray(ipi_n)
    ipi_n1 = np.asarray(ipi_n1)

    mask = ((ipi_n >= ipi_min) & (ipi_n <= ipi_max) &
            (ipi_n1 >= ipi_min) & (ipi_n1 <= ipi_max))
    x = ipi_n[mask]
    y = ipi_n1[mask]

    if x.size == 0:
        ax.text(0.5, 0.5, "No press\ndata",
                ha="center", va="center", fontsize=8,
                transform=ax.transAxes)
        ax.set_xscale("log")
        ax.set_yscale("log")
        ax.set_xlim(ipi_min, ipi_max)
        ax.set_ylim(ipi_min, ipi_max)
        ax.set_aspect("equal", adjustable="box")
        return None

    edges = np.logspace(np.log10(ipi_min), np.log10(ipi_max), nbins + 1)
    H, xedges, yedges = np.histogram2d(x, y, bins=[edges, edges])
    
    # --- smooth the histogram a bit so density structure pops out ---
    if smooth_sigma is not None and smooth_sigma > 0:
        H = gaussian_filter(H, sigma=smooth_sigma)
    
    H = H.T # rows correspond to y

    pcm = ax.pcolormesh(xedges, yedges, H,
                        cmap="jet", shading="auto",
                        vmin=0, vmax=vmax)

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(ipi_min, ipi_max)
    ax.set_ylim(ipi_min, ipi_max)

    # Make the axes square (same length for x and y)
    ax.set_aspect("equal", adjustable="box")


    return pcm



def plot_press_scatter_only(ax,
                            ipi_n,
                            ipi_n1,
                            ipi_min,
                            ipi_max):
    """
    Plot a PRESS return map as scatter only (no density).
    """
    import numpy as np

    ipi_n = np.asarray(ipi_n)
    ipi_n1 = np.asarray(ipi_n1)

    mask = ((ipi_n >= ipi_min) & (ipi_n <= ipi_max) &
            (ipi_n1 >= ipi_min) & (ipi_n1 <= ipi_max))
    x = ipi_n[mask]
    y = ipi_n1[mask]

    if x.size == 0:
        ax.text(0.5, 0.5, "No press\ndata",
                ha="center", va="center", fontsize=8,
                transform=ax.transAxes)
        ax.set_xscale("log")
        ax.set_yscale("log")
        ax.set_xlim(ipi_min, ipi_max)
        ax.set_ylim(ipi_min, ipi_max)
        ax.set_aspect("equal", adjustable="box")
        return

    ax.scatter(x, y, s=4, c="black", alpha=0.6, edgecolors="none")

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(ipi_min, ipi_max)
    ax.set_ylim(ipi_min, ipi_max)
    ax.set_aspect("equal", adjustable="box")



def plot_mag_return_map(ax,
                        ipi_n,
                        ipi_n1,
                        ipi_min,
                        ipi_max):
    """
    Plot a magazine-check return map (scatter only) on a given Axes.
    """
    ipi_n = np.asarray(ipi_n)
    ipi_n1 = np.asarray(ipi_n1)

    mask = ((ipi_n >= ipi_min) & (ipi_n <= ipi_max) &
            (ipi_n1 >= ipi_min) & (ipi_n1 <= ipi_max))
    x = ipi_n[mask]
    y = ipi_n1[mask]

    if x.size == 0:
        ax.text(0.5, 0.5, "No mag\ndata",
                ha="center", va="center", fontsize=8,
                transform=ax.transAxes)
        ax.set_xscale("log")
        ax.set_yscale("log")
        ax.set_xlim(ipi_min, ipi_max)
        ax.set_ylim(ipi_min, ipi_max)
        ax.set_aspect("equal", adjustable="box")
        return

    ax.scatter(x, y, s=4, c="red", alpha=0.4, edgecolors="none")

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(ipi_min, ipi_max)
    ax.set_ylim(ipi_min, ipi_max)

    # Make the axes square
    ax.set_aspect("equal", adjustable="box")



# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Build A4 SVG pages with IPI return maps for presses and mag checks."
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
        default="return_maps",
        help="Prefix for output SVG filenames (default: return_maps)"
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
        help="Number of log-spaced bins per axis for density (default: 100)"
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

    # Collect per-file data
    records = []
    for path in files:
        subject, msn = parse_header(path)
        press_code = detect_active_lever_code(msn)
        Y, Z = parse_YZ_arrays(path)

        press_times = extract_event_times(Y, Z, press_code)
        mag_times = extract_event_times(Y, Z, 7)

        ipi_n_press, ipi_n1_press = compute_ipi_pairs(press_times)
        ipi_n_mag, ipi_n1_mag = compute_ipi_pairs(mag_times)

        records.append({
            "path": path,
            "subject": subject,
            "msn": msn,
            "press_code": press_code,
            "ipi_n_press": ipi_n_press,
            "ipi_n1_press": ipi_n1_press,
            "ipi_n_mag": ipi_n_mag,
            "ipi_n1_mag": ipi_n1_mag,
        })

    # Sort by subject name for a consistent layout
    records.sort(key=lambda r: r["subject"])

    n = len(records)
    ncols = 4
    nrows = math.ceil(n / ncols)

    
    # -----------------------------------------------------------------
    # Figure 1: PRESS return maps – SCATTER ONLY
    # -----------------------------------------------------------------
    fig_ps, axes_ps = plt.subplots(
        nrows, ncols,
        figsize=(11, 11),  # square figure
        squeeze=False
    )
    fig_ps.suptitle("Return maps of lever presses – scatter only - (IPI(n) vs IPI(n+1)",
                    fontsize=14)

    for idx, rec in enumerate(records):
        row = idx // ncols
        col = idx % ncols
        ax = axes_ps[row][col]

        plot_press_scatter_only(
            ax,
            rec["ipi_n_press"],
            rec["ipi_n1_press"],
            ipi_min=args.ipi_min,
            ipi_max=args.ipi_max,
        )

        ax.set_title(rec["subject"], fontsize=8)
        if row == nrows - 1:
            ax.set_xlabel("IPI(n) (s)", fontsize=8)
        else:
            ax.set_xlabel("")
        if col == 0:
            ax.set_ylabel("IPI(n+1) (s)", fontsize=8)
        else:
            ax.set_ylabel("")

    # turn off unused axes
    for idx in range(n, nrows * ncols):
        row = idx // ncols
        col = idx % ncols
        axes_ps[row][col].axis("off")

    fig_ps.tight_layout(rect=[0, 0, 1.0, 0.95])
    press_scatter_out = output_folder / f"{args.output_prefix}_press_scatter.svg"
    fig_ps.savefig(press_scatter_out, format="svg")
    plt.close(fig_ps)
    print(f"Saved press scatter return maps to: {press_scatter_out}")



    # -----------------------------------------------------------------
    # Figure 2: PRESS return maps - DENSITY ONLY
    # -----------------------------------------------------------------
    fig_p, axes_p = plt.subplots(
        nrows, ncols,
        figsize=(11, 11),  # A4 in inches, portrait
        squeeze=False
    )
    fig_p.suptitle("Return maps of lever presses - density)",
                   fontsize=14)

    color_meshes = []

    for idx, rec in enumerate(records):
        row = idx // ncols
        col = idx % ncols
        ax = axes_p[row][col]

        pcm = plot_press_return_map(
            ax,
            rec["ipi_n_press"],
            rec["ipi_n1_press"],
            ipi_min=args.ipi_min,
            ipi_max=args.ipi_max,
            nbins=args.nbins,
            vmax=args.press_density_max,
            smooth_sigma=1.0,   #smoothing strength
        )
        if pcm is not None:
            color_meshes.append(pcm)

        ax.set_title(rec["subject"], fontsize=8)

        # Label axes only on left/bottom-most plots to reduce clutter
        if row == nrows - 1:
            ax.set_xlabel("IPI(n) (s)", fontsize=8)
        else:
            ax.set_xlabel("")
        if col == 0:
            ax.set_ylabel("IPI(n+1) (s)", fontsize=8)
        else:
            ax.set_ylabel("")

    # Turn off any unused axes
    for idx in range(n, nrows * ncols):
        row = idx // ncols
        col = idx % ncols
        axes_p[row][col].axis("off")

    fig_p.tight_layout(rect=[0, 0, 0.92, 0.95])

    # Shared colourbar for press density
    if color_meshes:
        cax = fig_p.add_axes([0.93, 0.15, 0.015, 0.7])  # [left, bottom, width, height]
        cb = fig_p.colorbar(color_meshes[0], cax=cax)
        cb.set_label("Count per bin (press)", fontsize=8)

    press_density_out = output_folder / f"{args.output_prefix}_press_density.svg"
    fig_p.savefig(press_density_out, format="svg")
    plt.close(fig_p)
    print(f"Saved press density return maps to: {press_density_out}")


    # -----------------------------------------------------------------
    # Figure 3: MAG return maps (scatter only)
    # -----------------------------------------------------------------
    fig_m, axes_m = plt.subplots(
        nrows, ncols,
        figsize=(11, 11),
        squeeze=False
    )
    fig_m.suptitle("Return maps of magazine checks (IPI(n) vs IPI(n+1))",
                   fontsize=14)

    for idx, rec in enumerate(records):
        row = idx // ncols
        col = idx % ncols
        ax = axes_m[row][col]

        plot_mag_return_map(
            ax,
            rec["ipi_n_mag"],
            rec["ipi_n1_mag"],
            ipi_min=args.ipi_min,
            ipi_max=args.ipi_max,
        )

        ax.set_title(rec["subject"], fontsize=8)

        if row == nrows - 1:
            ax.set_xlabel("IPI(n) (s)", fontsize=8)
        else:
            ax.set_xlabel("")
        if col == 0:
            ax.set_ylabel("IPI(n+1) (s)", fontsize=8)
        else:
            ax.set_ylabel("")

    for idx in range(n, nrows * ncols):
        row = idx // ncols
        col = idx % ncols
        axes_m[row][col].axis("off")

    fig_m.tight_layout(rect=[0, 0, 1.0, 0.96])

    mag_out = output_folder / f"{args.output_prefix}_mag.svg"
    fig_m.savefig(mag_out, format="svg")
    plt.close(fig_m)
    print(f"Saved mag return maps to: {mag_out}")


if __name__ == "__main__":
    main()
