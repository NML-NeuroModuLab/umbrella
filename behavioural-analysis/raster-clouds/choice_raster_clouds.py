
#!/usr/bin/env python3
"""
Raster clouds of valued vs devalued presses for choice tests.

Usage (from the folder containing this script, choice_mapping.csv, and TXT files):

    # For OLD outcome devalued (grain-sated tests)
    python choice_raster_clouds.py --devalued old

    # For NEW outcome devalued (purified-sated tests)
    python choice_raster_clouds.py --devalued new

This script:
  - Parses MED-PC choice-extinction TXT files
  - Uses choice_mapping.csv to know which lever is OLD (A1) vs NEW (A2) for each subject
  - Maps lever -> valued vs devalued based on the --devalued argument
  - Builds a raster plot of valued vs devalued presses over time for BiPAC and Control
  - Adds density (KDE-like) curves below each group's raster
  - Saves an SVG figure.
"""

from pathlib import Path
import argparse
import re

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

BIN_WIDTH = 5.0   # seconds per bin for density
SMOOTH_WINDOW_RATE = 11  # for density curves
JITTER_WIDTH = 0.4       # y-jitter for raster


# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------

def smooth_1d(x, window_size=5):
    """
    Simple moving-average smoother for 1D arrays.
    window_size should be an odd integer.
    """
    if window_size < 2:
        return x
    window = np.ones(window_size) / window_size
    return np.convolve(x, window, mode="same")


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--devalued",
        choices=["old", "new"],
        required=True,
        help="Which outcome was devalued in this dataset ('old' or 'new').",
    )
    parser.add_argument(
        "--mapping",
        default="choice_mapping.csv",
        help="CSV file specifying mapping (default: choice_mapping.csv).",
    )
    return parser.parse_args()


# ---------------------------------------------------------------------
# MED-PC parsing
# ---------------------------------------------------------------------

def parse_med_header(lines):
    """
    Extract Subject, Start Date and MSN from MED-PC backup header.
    """
    meta = {"subject": None, "start_date": None, "msn": None}
    for line in lines:
        line = line.strip()
        if line.startswith("Start Date:"):
            meta["start_date"] = line.split(":", 1)[1].strip()
        elif line.startswith("Subject:"):
            meta["subject"] = line.split(":", 1)[1].strip()
        elif line.startswith("MSN:"):
            meta["msn"] = line.split(":", 1)[1].strip()
        if line.startswith("Y:"):
            break

    if meta["subject"] is None or meta["start_date"] is None or meta["msn"] is None:
        raise ValueError("Could not parse Subject / Start Date / MSN from header.")
    return meta


def parse_array_section(lines, array_label):
    """
    Parse an array section (Y: or Z:) from a MED-PC export.
    Returns a 1D numpy array of floats.
    """
    values = []
    in_array = False
    label_prefix = f"{array_label}:"

    for line in lines:
        stripped = line.strip()

        if not in_array:
            if stripped.startswith(label_prefix):
                in_array = True
            continue

        if stripped == "" or re.match(r"^[A-Z]:", stripped):
            break

        if ":" not in stripped:
            continue

        _, rest = stripped.split(":", 1)
        tokens = rest.strip().split()
        for tok in tokens:
            try:
                val = float(tok)
            except ValueError:
                continue
            values.append(val)

    return np.array(values, dtype=float)


def extract_press_times_choice(path):
    """
    For a choice-extinction MED-PC file, extract left and right press times.

    Returns:
        meta: dict with subject, start_date, msn, group
        left_times: np.ndarray of times (seconds) with Y == 3 (left presses)
        right_times: np.ndarray of times (seconds) with Y == 4 (right presses)
    """
    text = path.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()

    meta = parse_med_header(lines)
    subj = meta["subject"]

    # Infer group from subject prefix
    if subj.upper().startswith("BP"):
        meta["group"] = "BiPAC"
    elif subj.upper().startswith("CT"):
        meta["group"] = "Control"
    else:
        meta["group"] = "Unknown"

    y_arr = parse_array_section(lines, "Y")
    z_arr = parse_array_section(lines, "Z")

    if y_arr.size == 0 or z_arr.size == 0:
        raise ValueError(f"Empty Y or Z array in file: {path.name}")
    if y_arr.size != z_arr.size:
        n = min(y_arr.size, z_arr.size)
        y_arr = y_arr[:n]
        z_arr = z_arr[:n]

    mask_events = y_arr != 0.0
    y_events = y_arr[mask_events]
    z_events = z_arr[mask_events]

    left_times = z_events[y_events == 3.0]
    right_times = z_events[y_events == 4.0]

    return meta, left_times, right_times


# ---------------------------------------------------------------------
# Load mapping (tailored to your choice_mapping.csv)
# ---------------------------------------------------------------------

def load_choice_mapping(csv_path):
    """
    Load choice_mapping.csv with columns:
        Label, ..., A1, A2, ...

    We map:
        Subject  <- Label
        OldLever <- A1
        NewLever <- A2
    and convert 'Left'/'Right' -> 'L'/'R'.
    """
    df = pd.read_csv(csv_path)
    required = {"Label", "A1", "A2"}
    missing = required.difference(df.columns)
    if missing:
        raise ValueError(f"Mapping file is missing columns: {missing}")

    df["Subject"] = df["Label"].astype(str).str.strip()

    def norm_lever(x):
        x = str(x).strip().lower()
        if x.startswith("l"):
            return "L"
        elif x.startswith("r"):
            return "R"
        else:
            raise ValueError(f"Unknown lever value '{x}' (expected 'Left'/'Right').")

    df["OldLever"] = df["A1"].apply(norm_lever)
    df["NewLever"] = df["A2"].apply(norm_lever)

    return df[["Subject", "OldLever", "NewLever"]]


# ---------------------------------------------------------------------
# Build long-form DataFrame of presses (valued vs devalued)
# ---------------------------------------------------------------------

def build_choice_dataframe(data_dir, mapping_df, devalued_outcome):
    """
    Scan all .txt files in data_dir, parse left/right press times and map them
    to 'valued' vs 'devalued' based on old/new lever mapping and which outcome
    was devalued in this dataset.

    Returns a DataFrame with columns:
        subject, group, condition ('valued'/'devalued'), time_sec
    """
    rows = []

    for path in sorted(data_dir.glob("*.txt")):
        if path.name.lower().endswith(".csv"):
            continue

        try:
            meta, left_times, right_times = extract_press_times_choice(path)
        except Exception as e:
            print(f"[WARNING] Skipping {path.name}: {e}")
            continue

        subj = meta["subject"]
        matches = mapping_df[mapping_df["Subject"] == subj]
        if matches.empty:
            print(f"[WARNING] No mapping row for Subject={subj}; skipping.")
            continue

        row_map = matches.iloc[0]
        old_lever = row_map["OldLever"]   # 'L' or 'R'
        new_lever = row_map["NewLever"]   # 'L' or 'R'

        if devalued_outcome == "old":
            devalued_lever = old_lever
            valued_lever = new_lever
        elif devalued_outcome == "new":
            devalued_lever = new_lever
            valued_lever = old_lever
        else:
            raise ValueError("devalued_outcome must be 'old' or 'new'.")

        lever_times = {
            "L": left_times,
            "R": right_times,
        }

        for condition, lever in (("valued", valued_lever), ("devalued", devalued_lever)):
            times = lever_times.get(lever, np.array([]))
            for t in times:
                rows.append({
                    "subject": subj,
                    "group": meta["group"],
                    "condition": condition,
                    "time_sec": float(t),
                })

    if not rows:
        raise RuntimeError("No press events found across files (after mapping).")

    df = pd.DataFrame(rows)
    return df


# ---------------------------------------------------------------------
# Subject ordering within groups
# ---------------------------------------------------------------------

def compute_subject_order(df):
    """
    For each group, compute an ordering of subjects
    based on mean valued-press time (centre of mass).

    Returns:
        dict: {group_name: [subject1, subject2, ...]}
    """
    subject_order = {}
    for group_name in sorted(df["group"].unique()):
        if group_name == "Unknown":
            continue

        df_g = df[df["group"] == group_name]
        df_val = df_g[df_g["condition"] == "valued"]
        if df_val.empty:
            df_val = df_g

        cm = df_val.groupby("subject")["time_sec"].mean().sort_values()
        subject_order[group_name] = list(cm.index)

    return subject_order


# ---------------------------------------------------------------------
# Plot raster + density
# ---------------------------------------------------------------------

def plot_raster_with_density(df, subject_order, devalued_outcome, out_path):
    """
    Create a 2x2 figure:
      row 0: raster (BiPAC, Control)
      row 1: density curves (BiPAC, Control)

    Colours:
      valued   = blue
      devalued = orange
    """
    groups = ["BiPAC", "Control"]
    colour_valued = "#3B8AD9"
    colour_devalued = "#F28E2B"  # orange-ish

    fig, axes = plt.subplots(
        nrows=2, ncols=2,
        sharex="col",
        figsize=(8, 6),
        constrained_layout=True
    )

    rng = np.random.default_rng(seed=42)

    # ---- Rasters (row 0) ----
    for col, group_name in enumerate(groups):
        ax = axes[0, col]

        if group_name not in subject_order:
            ax.set_visible(False)
            continue

        subjects = subject_order[group_name]
        n_subj = len(subjects)

        df_g = df[df["group"] == group_name]
        if df_g.empty:
            ax.set_visible(False)
            continue

        for idx, subj in enumerate(subjects):
            df_s = df_g[df_g["subject"] == subj]
            if df_s.empty:
                continue

            for condition, colour in (("valued", colour_valued),
                                      ("devalued", colour_devalued)):
                df_sc = df_s[df_s["condition"] == condition]
                if df_sc.empty:
                    continue

                times = df_sc["time_sec"].values
                y_base = idx
                y_jitter = rng.uniform(-JITTER_WIDTH, JITTER_WIDTH, size=times.size)
                y_vals = y_base + y_jitter

                ax.scatter(
                    times, y_vals,
                    s=6,
                    alpha=0.3,
                    edgecolor="none",
                    color=colour
                )

        ax.set_xlim(0, 600)
        ax.set_ylim(-1, n_subj)
        ax.set_yticks([])

        if col == 0:
            ax.set_ylabel("BiPAC" if group_name == "BiPAC" else "Control")

        ax.set_title(group_name)
        ax.grid(axis="x", color="0.9", linestyle="--", linewidth=0.5)

    # ---- Density curves (row 1) ----
    bins = np.arange(0, 600 + BIN_WIDTH, BIN_WIDTH)
    for col, group_name in enumerate(groups):
        ax = axes[1, col]
        df_g = df[df["group"] == group_name]
        if df_g.empty:
            ax.set_visible(False)
            continue

        max_y = 0.0

        for condition, colour, label in (
            ("valued", colour_valued, "Valued"),
            ("devalued", colour_devalued, "Devalued"),
        ):
            df_gc = df_g[df_g["condition"] == condition]
            times = df_gc["time_sec"].values
            if times.size == 0:
                continue

            # number of sessions = number of (subject, start_date) combos if you had that;
            # here we'll just treat each subject as one session
            n_sessions = df_gc["subject"].nunique()

            counts, edges = np.histogram(times, bins=bins)
            centers = (edges[:-1] + edges[1:]) / 2.0

            rate = counts.astype(float) / (BIN_WIDTH * max(n_sessions, 1))
            smooth_rate = smooth_1d(rate, window_size=SMOOTH_WINDOW_RATE)

            if smooth_rate.max() > max_y:
                max_y = smooth_rate.max()

            ax.plot(
                centers, smooth_rate,
                color=colour,
                linewidth=2,
                label=label
            )

        ax.set_xlim(0, 600)
        if max_y > 0:
            ax.set_ylim(0, max_y * 1.1)
        ax.set_yticks([])
        ax.set_xlabel("Time (s)")
        if col == 0:
            ax.set_ylabel("Press rate\n(presses/s per session)")

        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

        handles, labels = ax.get_legend_handles_labels()
        if handles:
            uniq = dict(zip(labels, handles))
            ax.legend(uniq.values(), uniq.keys(), frameon=False, loc="upper right")

    fig.suptitle(f"Choice raster – {devalued_outcome.upper()} outcome devalued", y=1.02)
    fig.savefig(out_path, format="svg", bbox_inches="tight")
    print(f"Saved raster+density figure to: {out_path}")


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():
    args = parse_args()
    devalued = args.devalued.lower()
    here = Path(__file__).resolve().parent

    mapping_path = here / args.mapping
    if not mapping_path.exists():
        raise FileNotFoundError(f"Mapping file not found: {mapping_path}")

    mapping_df = load_choice_mapping(mapping_path)
    print(f"Loaded mapping for {len(mapping_df)} subjects.")

    df_presses = build_choice_dataframe(here, mapping_df, devalued)
    print(f"Parsed {len(df_presses)} presses from {df_presses['subject'].nunique()} subjects.")

    subject_order = compute_subject_order(df_presses)
    print("Subject order per group:")
    for g, subs in subject_order.items():
        print(f"  {g}: {subs}")

    out_svg = here / f"choice_raster_{devalued}_devalued.svg"
    plot_raster_with_density(df_presses, subject_order, devalued, out_svg)


if __name__ == "__main__":
    main()
