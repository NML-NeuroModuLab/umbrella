#!/usr/bin/env python3
"""Generate the Fig. 1b instrumental-training panel from extracted sessions.

The input is ``fig1bc_sessions.csv`` produced by ``extract_fig1bc.py``. The
script plots each animal's press rate, the pooled daily mean +/- SEM, and the
training-duration bars used in the manuscript panel. It also writes the exact
subject-level values, daily summary, and inclusion table used for the plot.

The submitted Fig. 1b source-data table contains the five trained groups
(``CRF`` through ``aRR20``). Subject ``4_10138`` is absent from that table, so
the default configuration excludes it explicitly and records the decision in
``fig1b_subject_selection.csv``. Use ``--include-all-subjects`` to inspect the
unfiltered extracted cohort.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


# Terminal training schedule for each group shown in Fig. 1b. These values
# determine both the completeness checks and the horizontal duration bars.
GROUP_END_DAY = {
    "CRF": 4,
    "RR5": 8,
    "RR10": 12,
    "RR20": 16,
    "aRR20": 20,
}

# Greens progress from the shortest to the longest training schedule. Keeping
# the palette here makes all figure-specific choices visible in one place.
GROUP_COLOURS = {
    "CRF": "#159A28",
    "RR5": "#45B84D",
    "RR10": "#72C879",
    "RR20": "#9EDBA4",
    "aRR20": "#CBEACD",
}

# This exclusion reproduces the subject selection in the submitted Fig. 1b
# source-data table. It is deliberately explicit rather than inferred from a
# response threshold, so changing the rule cannot silently alter the cohort.
DEFAULT_EXCLUSIONS = {
    "4_10138": "not present in the submitted Fig. 1b source-data table",
}

REQUIRED_COLUMNS = {
    "subject_id",
    "experimental_group",
    "training_day",
    "training_stage",
    "stage_day",
    "press_rate_per_min",
}


def parse_args() -> argparse.Namespace:
    """Define the public command-line interface."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input_path",
        type=Path,
        help=(
            "fig1bc_sessions.csv, its 02_extracted-data folder, or the Fig. 1 "
            "behaviour folder containing 02_extracted-data."
        ),
    )
    parser.add_argument(
        "--output-folder",
        type=Path,
        help=(
            "Destination folder (default: behaviour/03_analysis-output/fig1b, "
            "or an analysis-output/fig1b folder beside the supplied CSV)."
        ),
    )
    parser.add_argument(
        "--include-all-subjects",
        action="store_true",
        help="Include 4_10138 instead of reproducing the submitted cohort selection.",
    )
    parser.add_argument(
        "--annotate-significance",
        action="store_true",
        help=(
            "Add the manuscript's asterisk annotation. This is a display option; "
            "the inferential statistic is not recalculated by this script."
        ),
    )
    return parser.parse_args()


def resolve_paths(input_path: Path, output_folder: Path | None) -> tuple[Path, Path]:
    """Resolve supported input layouts and choose a predictable output folder."""
    path = input_path.expanduser().resolve()

    if path.is_file():
        if path.name != "fig1bc_sessions.csv":
            raise ValueError(f"Expected fig1bc_sessions.csv, received: {path}")
        sessions_file = path
        if path.parent.name == "02_extracted-data":
            default_output = path.parent.parent / "03_analysis-output" / "fig1b"
        else:
            default_output = path.parent / "analysis-output" / "fig1b"
    elif (path / "fig1bc_sessions.csv").is_file():
        sessions_file = path / "fig1bc_sessions.csv"
        if path.name == "02_extracted-data":
            default_output = path.parent / "03_analysis-output" / "fig1b"
        else:
            default_output = path / "analysis-output" / "fig1b"
    elif (path / "02_extracted-data" / "fig1bc_sessions.csv").is_file():
        sessions_file = path / "02_extracted-data" / "fig1bc_sessions.csv"
        default_output = path / "03_analysis-output" / "fig1b"
    else:
        raise FileNotFoundError(
            "Could not find fig1bc_sessions.csv beneath the supplied path: "
            f"{path}"
        )

    destination = (output_folder or default_output).expanduser().resolve()
    return sessions_file, destination


def load_and_select_sessions(
    sessions_file: Path,
    include_all_subjects: bool,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Load, validate, and select the subject-session rows used in Fig. 1b."""
    sessions = pd.read_csv(sessions_file)
    missing_columns = sorted(REQUIRED_COLUMNS.difference(sessions.columns))
    if missing_columns:
        raise ValueError(
            "The session table is missing required columns: "
            + ", ".join(missing_columns)
        )

    sessions = sessions[sessions["experimental_group"].isin(GROUP_END_DAY)].copy()
    if sessions.empty:
        raise ValueError("No Fig. 1b training groups were found in the session table.")

    sessions["training_day"] = pd.to_numeric(
        sessions["training_day"], errors="raise"
    ).astype(int)
    sessions["press_rate_per_min"] = pd.to_numeric(
        sessions["press_rate_per_min"], errors="raise"
    )

    duplicate_rows = sessions.duplicated(["subject_id", "training_day"], keep=False)
    if duplicate_rows.any():
        duplicate_keys = (
            sessions.loc[duplicate_rows, ["subject_id", "training_day"]]
            .drop_duplicates()
            .to_dict("records")
        )
        raise ValueError(f"Duplicate subject/day records found: {duplicate_keys}")

    exclusions = {} if include_all_subjects else DEFAULT_EXCLUSIONS
    subject_groups = (
        sessions[["subject_id", "experimental_group"]]
        .drop_duplicates()
        .sort_values(["experimental_group", "subject_id"])
    )
    if subject_groups["subject_id"].duplicated().any():
        raise ValueError("At least one subject is assigned to more than one group.")

    selection = subject_groups.rename(columns={"experimental_group": "group"})
    selection["included"] = ~selection["subject_id"].isin(exclusions)
    selection["exclusion_reason"] = selection["subject_id"].map(exclusions).fillna("")
    selection["terminal_training_day"] = selection["group"].map(GROUP_END_DAY)

    selected_ids = selection.loc[selection["included"], "subject_id"]
    selected = sessions[sessions["subject_id"].isin(selected_ids)].copy()

    # Every included subject should have exactly one observation for every day
    # from first contingency through the terminal schedule assigned to its group.
    for subject_id, subject_rows in selected.groupby("subject_id", sort=True):
        group = subject_rows["experimental_group"].iloc[0]
        expected_days = list(range(1, GROUP_END_DAY[group] + 1))
        observed_days = sorted(subject_rows["training_day"].tolist())
        if observed_days != expected_days:
            raise ValueError(
                f"Incomplete training sequence for {subject_id}: expected "
                f"{expected_days}, observed {observed_days}."
            )

    selected = selected.sort_values(
        ["experimental_group", "subject_id", "training_day"]
    )
    return selected, selection


def make_daily_summary(selected: pd.DataFrame) -> pd.DataFrame:
    """Calculate the pooled mean, sample SEM, and animal count for each day."""
    summary = (
        selected.groupby("training_day", as_index=False)
        .agg(
            mean_press_rate_per_min=("press_rate_per_min", "mean"),
            sem_press_rate_per_min=("press_rate_per_min", "sem"),
            n_subjects=("press_rate_per_min", "count"),
        )
    )
    return summary


def plot_fig1b(
    selected: pd.DataFrame,
    summary: pd.DataFrame,
    destination: Path,
    annotate_significance: bool,
) -> None:
    """Create SVG and PNG versions of the Fig. 1b panel."""
    plt.rcParams.update(
        {
            "font.family": "Arial",
            "font.size": 9,
            "axes.linewidth": 1.0,
            "svg.fonttype": "none",
        }
    )

    fig, ax = plt.subplots(figsize=(4.0, 3.7))

    # Draw longest, palest traces first so shorter, darker traces remain visible.
    for group in reversed(list(GROUP_END_DAY)):
        group_rows = selected[selected["experimental_group"] == group]
        for _, subject_rows in group_rows.groupby("subject_id", sort=True):
            ax.plot(
                subject_rows["training_day"],
                subject_rows["press_rate_per_min"],
                color=GROUP_COLOURS[group],
                linewidth=0.75,
                alpha=0.75,
                zorder=1,
            )

    ax.errorbar(
        summary["training_day"],
        summary["mean_press_rate_per_min"],
        yerr=summary["sem_press_rate_per_min"],
        color="#0A6B2B",
        linewidth=1.25,
        marker="o",
        markersize=4.0,
        markerfacecolor="white",
        markeredgecolor="#0A6B2B",
        markeredgewidth=0.9,
        capsize=0,
        zorder=3,
    )

    ax.set_xlim(0.5, 20.5)
    ax.set_ylim(0, 82)
    ax.set_yticks([0, 20, 40, 60, 80])
    ax.set_xticks([])
    ax.set_ylabel("Press rate (/min)", fontsize=11)
    ax.tick_params(axis="y", direction="out", length=3, width=0.8)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["bottom"].set_visible(False)

    # Training-stage labels follow the approximate positions in the assembled
    # manuscript figure; they identify schedules rather than individual lines.
    label_positions = {
        "CRF": (1.0, 14),
        "RR5": (4.4, 31),
        "RR10": (8.0, 49),
        "RR20": (12.7, 69),
        "aRR20": (17.3, 79),
    }
    for group, (x, y) in label_positions.items():
        ax.text(
            x,
            y,
            group,
            color=GROUP_COLOURS[group],
            fontsize=9,
            fontweight="bold",
            alpha=0.72,
            ha="left",
            va="center",
        )

    # Group-duration bars are outside the plotting area and therefore use
    # clip_on=False. Their order mirrors the bars beneath the published panel.
    bar_y = {"CRF": -2.8, "RR5": -5.6, "RR10": -8.4, "RR20": -11.2, "aRR20": -14.0}
    for group, end_day in GROUP_END_DAY.items():
        ax.plot(
            [1, end_day],
            [bar_y[group], bar_y[group]],
            color=GROUP_COLOURS[group],
            linewidth=3.0,
            solid_capstyle="butt",
            clip_on=False,
        )

    ax.text(1, -20.0, "Training", fontsize=10, ha="left", va="center", clip_on=False)
    ax.annotate(
        "",
        xy=(5.0, -20.0),
        xytext=(3.8, -20.0),
        arrowprops={"arrowstyle": "->", "linewidth": 1.0, "color": "black"},
        annotation_clip=False,
    )
    ax.plot([18, 20], [-17.0, -17.0], color="black", linewidth=1.2, clip_on=False)
    ax.text(19, -14.9, "3 days", fontsize=9, ha="center", va="bottom", clip_on=False)

    if annotate_significance:
        # The manuscript annotation is reproduced as a display element only.
        # Statistical testing is intentionally kept separate from this plotter.
        ax.plot([6.0, 8.8], [88, 88], color="black", linewidth=0.8, clip_on=False)
        ax.plot([10.2, 13.0], [88, 88], color="black", linewidth=0.8, clip_on=False)
        ax.text(9.5, 88, "*", fontsize=14, fontweight="bold", ha="center", va="center", clip_on=False)

    fig.subplots_adjust(left=0.20, right=0.98, top=0.88, bottom=0.27)
    fig.savefig(destination / "fig1b_press_rate.svg", bbox_inches="tight")
    fig.savefig(
        destination / "fig1b_press_rate.png",
        dpi=300,
        bbox_inches="tight",
        facecolor="white",
    )
    plt.close(fig)


def main() -> None:
    """Run selection, summaries, exports, and plotting."""
    args = parse_args()
    sessions_file, destination = resolve_paths(args.input_path, args.output_folder)
    destination.mkdir(parents=True, exist_ok=True)

    selected, selection = load_and_select_sessions(
        sessions_file,
        include_all_subjects=args.include_all_subjects,
    )
    summary = make_daily_summary(selected)

    value_columns = [
        "subject_id",
        "experimental_group",
        "training_day",
        "training_stage",
        "stage_day",
        "press_rate_per_min",
    ]
    selected[value_columns].rename(
        columns={"experimental_group": "group"}
    ).to_csv(destination / "fig1b_subject_values.csv", index=False)
    summary.to_csv(destination / "fig1b_daily_summary.csv", index=False)
    selection.to_csv(destination / "fig1b_subject_selection.csv", index=False)

    plot_fig1b(
        selected,
        summary,
        destination,
        annotate_significance=args.annotate_significance,
    )

    group_counts = (
        selection.loc[selection["included"]]
        .groupby("group")["subject_id"]
        .nunique()
        .reindex(GROUP_END_DAY)
    )
    print(f"Read: {sessions_file}")
    print(f"Included subjects: {int(group_counts.sum())}")
    for group, count in group_counts.items():
        print(f"  {group}: n={int(count)}")
    print(f"Wrote Fig. 1b outputs to: {destination}")


if __name__ == "__main__":
    main()
