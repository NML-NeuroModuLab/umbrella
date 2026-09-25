
#!/usr/bin/env python
"""
search_max_density.py

Given TWO MED Associates backup text files:

    1) One from the session with the highest lever-press rate
    2) One from the session with the highest magazine-check rate

this script:

    - Parses the MED txt files to extract the Y (event code) and Z (time) arrays.
    - Automatically detects which lever is active (left or right) from the MSN line:
        * 'L-GRN'  -> left-active, press code = 3
        * 'R-GRN'  -> right-active, press code = 4
    - Identifies:
        * Press events:  Y == press_code (3 or 4)
        * Magazine entries: Y == 7  (start events only)
    - Computes inter-event intervals (IPIs) for presses and magazine entries.
    - Builds return-map pairs: (IPI_n, IPI_{n+1}).
    - Computes 2D histograms of (IPI_n, IPI_{n+1}) in log space:
        * IPI range: 0.1 to 100 s on each axis
        * Bins: 100 x 100, log-spaced.
    - Reports:
        * Per-file max density (max count per bin) for:
            - Press return map
            - Magazine-check return map
        * Global max density across the two files for:
            - Presses
            - Magazine checks

You can reuse this script in future experiments:
    - Select the two "calibration" txt files that correspond to the highest
      press and highest mag-check rates for that experiment.
    - Run it with their paths as arguments.
    - Use the printed global max densities as the LUT vmax values for
      your return-map plotting script.

USAGE:

    python search_max_density.py \"highest_press_session.txt\" \
        \"highest_mag_session.txt\" --output-folder \"/path/to/outputs\"

Example:

    python search_max_density.py ^
        \"Backup of Box 03 2025-11-16 14.23 Subject CT7.txt\" ^
        \"Backup of Box 04 2025-11-16 13.50 Subject BP6.txt\"

"""

import argparse
import numpy as np
from pathlib import Path


# ---------------------------------------------------------------------
# OUTPUT txt with results
# ---------------------------------------------------------------------


def write_output_file(text, output_folder):
    """
    Write the script's output text into the selected output folder.

    Parameters
    ----------
    text : str
        Full text to save.
    output_folder : pathlib.Path
        Destination folder.
    """
    output_folder.mkdir(parents=True, exist_ok=True)
    outpath = output_folder / "search_max_density_output.txt"

    with open(outpath, "w", encoding="utf-8") as f:
        f.write(text)

    print(f"\nOutput also saved to: {outpath}")



# ---------------------------------------------------------------------
# MED txt parsing utilities
# ---------------------------------------------------------------------

def detect_active_lever_code(path):
    """
    Inspect the header of a MED txt file to infer which lever is active.

    Assumes the MSN line contains:
        - 'L-GRN' for left-active sessions  (press code = 3)
        - 'R-GRN' for right-active sessions (press code = 4)

    Returns
    -------
    press_code : int
        3 for left-active, 4 for right-active.

    Raises
    ------
    RuntimeError if it cannot determine the lever from the MSN line.
    """
    with open(path, 'r') as f:
        for line in f:
            if line.startswith("MSN:"):
                msn = line.strip()
                if "L-GRN" in msn:
                    return 3
                elif "R-GRN" in msn:
                    return 4
                else:
                    raise RuntimeError(
                        f"Could not infer lever side from MSN line in {path!r}: {msn}"
                    )
    raise RuntimeError(f"No MSN line found in file {path!r}")


def parse_YZ_arrays(path):
    """
    Parse the MED txt file and return Y and Z as numpy arrays.

    This function:
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
    with open(path, 'r') as f:
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

    array_names = {"Y", "Z"}  # we only need Y and Z

    for line in lines:
        s = line.strip()

        # Start of an array section: e.g. "Y:" or "Z:"
        if len(s) >= 2 and s[0] in array_names and s[1] == ":":
            flush_current()
            current = s[0]  # "Y" or "Z"
            values = []
            continue

        # If we are recording one of the arrays, collect numeric tokens
        if current is not None and s:
            # Lines look like " 0: 1.000 8.000 -8.000 ..."
            if ":" in s:
                _, rest = s.split(":", 1)
            else:
                rest = s
            for tok in rest.split():
                try:
                    values.append(float(tok))
                except ValueError:
                    # Skip non-numeric tokens
                    pass

    # Flush last array
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
    Extract timestamps for events where Y equals a given code.

    Parameters
    ----------
    Y : np.ndarray
        Event codes.
    Z : np.ndarray
        Timestamps (seconds).
    code : int
        Event code of interest (e.g. 3, 4 for presses; 7 for magazine entries).

    Returns
    -------
    times : np.ndarray
        1D array of timestamps for events with the requested code.
    """
    mask = (Y == code)
    return Z[mask]


def compute_ipi_pairs(times, min_isi=0.01):
    """
    Compute inter-event intervals and return-map pairs from event times.

    Parameters
    ----------
    times : array-like
        Sorted event times (seconds).
    min_isi : float, optional
        Minimum IPI (seconds). IPIs <= min_isi are discarded to remove artefacts.

    Returns
    -------
    ipi_n : np.ndarray
        IPI(n) values.
    ipi_n1 : np.ndarray
        IPI(n+1) values.
    """
    times = np.asarray(times, dtype=float)
    if times.size < 3:
        return np.array([]), np.array([])

    ipis = np.diff(times)
    # Drop ultra-short intervals if desired
    ipis = ipis[ipis > min_isi]

    if ipis.size < 2:
        return np.array([]), np.array([])

    ipi_n = ipis[:-1]
    ipi_n1 = ipis[1:]
    return ipi_n, ipi_n1


# ---------------------------------------------------------------------
# Density estimation in log–log IPI space
# ---------------------------------------------------------------------

def histogram_density(ipi_n,
                      ipi_n1,
                      ipi_min=0.1,
                      ipi_max=100.0,
                      nbins=40):
    """
    Compute a 2D histogram of (IPI_n, IPI_n1) in log space.

    Parameters
    ----------
    ipi_n, ipi_n1 : array-like
        IPI(n) and IPI(n+1) values (seconds).
    ipi_min, ipi_max : float
        IPI range to consider on each axis.
    nbins : int
        Number of log-spaced bins per axis.

    Returns
    -------
    H : np.ndarray or None
        2D histogram array of shape (nbins, nbins), or None if no points.
    xedges, yedges : np.ndarray or None
        Bin edges used for x (IPI_n) and y (IPI_n1).
    max_density : float
        Maximum count per bin; 0 if no points.
    """
    ipi_n = np.asarray(ipi_n)
    ipi_n1 = np.asarray(ipi_n1)

    mask = ((ipi_n >= ipi_min) & (ipi_n <= ipi_max) &
            (ipi_n1 >= ipi_min) & (ipi_n1 <= ipi_max))
    x = ipi_n[mask]
    y = ipi_n1[mask]

    if x.size == 0:
        return None, None, None, 0.0

    edges = np.logspace(np.log10(ipi_min), np.log10(ipi_max), nbins + 1)
    H, xedges, yedges = np.histogram2d(x, y, bins=[edges, edges])
    max_density = float(H.max())
    return H, xedges, yedges, max_density


# ---------------------------------------------------------------------
# Per-file analysis
# ---------------------------------------------------------------------

def analyse_file(path, ipi_min=0.1, ipi_max=100.0, nbins=40):
    """
    Analyse a single MED txt file to obtain max densities for
    presses and magazine entries.

    Parameters
    ----------
    path : str
        Path to MED txt file.
    ipi_min, ipi_max, nbins : as in `histogram_density`.

    Returns
    -------
    results : dict
        Contains:
            - 'path'
            - 'press_code'
            - 'n_press_pairs'
            - 'n_mag_pairs'
            - 'press_max_density'
            - 'mag_max_density'
    """
    # Detect which lever is active in this session
    press_code = detect_active_lever_code(path)

    # Parse arrays
    Y, Z = parse_YZ_arrays(path)

    # Extract event times
    press_times = extract_event_times(Y, Z, press_code)
    mag_times = extract_event_times(Y, Z, 7)  # 7 = mag entry start

    # Compute return-map IPI pairs
    ipi_n_press, ipi_n1_press = compute_ipi_pairs(press_times)
    ipi_n_mag, ipi_n1_mag = compute_ipi_pairs(mag_times)

    # Densities
    _, _, _, max_press = histogram_density(
        ipi_n_press, ipi_n1_press, ipi_min=ipi_min, ipi_max=ipi_max, nbins=nbins
    )
    _, _, _, max_mag = histogram_density(
        ipi_n_mag, ipi_n1_mag, ipi_min=ipi_min, ipi_max=ipi_max, nbins=nbins
    )

    return {
        "path": path,
        "press_code": press_code,
        "n_press_pairs": len(ipi_n_press),
        "n_mag_pairs": len(ipi_n_mag),
        "press_max_density": max_press,
        "mag_max_density": max_mag,
    }


# ---------------------------------------------------------------------
# Main CLI
# ---------------------------------------------------------------------

def main():

    parser = argparse.ArgumentParser(
        description=(
            "Find maximum bin densities in IPI return maps for:\n"
            "  (1) the highest press-rate session, and\n"
            "  (2) the highest mag-check session.\n\n"
            "Use these maxima as LUT vmax values in your plotting script."
        )
    )
    parser.add_argument("press_file", type=Path, help="Highest press-rate txt file")
    parser.add_argument("mag_file", type=Path, help="Highest mag-check txt file")
    parser.add_argument(
        "--output-folder", type=Path,
        help="Destination folder (default: beside the press-rate file)."
    )
    parser.add_argument("--ipi_min", type=float, default=0.1)
    parser.add_argument("--ipi_max", type=float, default=100.0)
    parser.add_argument("--nbins", type=int, default=40)

    args = parser.parse_args()

    press_file = args.press_file.expanduser().resolve()
    mag_file = args.mag_file.expanduser().resolve()
    if not press_file.is_file():
        raise FileNotFoundError(f"Press-rate file not found: {press_file}")
    if not mag_file.is_file():
        raise FileNotFoundError(f"Magazine-check file not found: {mag_file}")
    output_folder = (
        args.output_folder.expanduser().resolve()
        if args.output_folder
        else press_file.parent
    )

    # Analyse files
    res_press = analyse_file(
        press_file, ipi_min=args.ipi_min, ipi_max=args.ipi_max, nbins=args.nbins
    )
    res_mag = analyse_file(
        mag_file, ipi_min=args.ipi_min, ipi_max=args.ipi_max, nbins=args.nbins
    )

    # Build text output
    out = []
    out.append("=== FILE 1: Highest Press-Rate Session ===")
    out.append(f"File: {res_press['path']}")
    out.append(f"Active lever press code: {res_press['press_code']}")
    out.append(f"Number of press return-map points: {res_press['n_press_pairs']}")
    out.append(f"Number of mag return-map points:   {res_press['n_mag_pairs']}")
    out.append(f"Max press-bin density: {res_press['press_max_density']:.1f}")
    out.append(f"Max mag-bin density:   {res_press['mag_max_density']:.1f}")
    out.append("")

    out.append("=== FILE 2: Highest Magazine-Check Session ===")
    out.append(f"File: {res_mag['path']}")
    out.append(f"Active lever press code: {res_mag['press_code']}")
    out.append(f"Number of press return-map points: {res_mag['n_press_pairs']}")
    out.append(f"Number of mag return-map points:   {res_mag['n_mag_pairs']}")
    out.append(f"Max press-bin density: {res_mag['press_max_density']:.1f}")
    out.append(f"Max mag-bin density:   {res_mag['mag_max_density']:.1f}")
    out.append("")

    global_press_max = max(res_press["press_max_density"], res_mag["press_max_density"])
    global_mag_max = max(res_press["mag_max_density"], res_mag["mag_max_density"])

    out.append("=== GLOBAL MAX DENSITIES ===")
    out.append(f"Global max press density: {global_press_max:.1f}")
    out.append(f"Global max mag   density: {global_mag_max:.1f}")
    out.append("Done.\n")

    # Join into full text
    output_text = "\n".join(out)

    # Print to terminal
    print(output_text)

    write_output_file(output_text, output_folder)


if __name__ == "__main__":
    main()
