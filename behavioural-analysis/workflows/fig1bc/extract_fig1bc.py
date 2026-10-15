#!/usr/bin/env python3
"""Extract the NRR001 MED-PC files used for Fig. 1b-c into tidy CSV files.

Two tables are written because session summaries and timestamped events have
different natural units:

* ``fig1bc_sessions.csv``: one row per subject and training session.
* ``fig1bc_events.csv``: one row per valid paired Y/Z event.

The script accepts either the Fig. 1 ``behaviour`` folder or its
``01_raw-MEDPC-files`` child as input. By default, output is written to the
adjacent ``02_extracted-data`` folder.

``session_id`` uniquely links the two outputs. It has the form
``<experiment>_<subject>_day-<relative-training-day>``. For example,
``NRR001_1_10127_day-05`` identifies subject ``1_10127`` on relative training
day 5; it does not encode the calendar date. The historical date is retained
separately in ``session_date``.

The NRR001 programme conventions are interpreted here rather than in the
generic parser:

* ``Y=1``: lever response
* ``Y=3``: pellet delivery
* ``Y=4``: time-controlled magazine entry
* ``Z``: corresponding event timestamp in seconds
* ``W``: number of valid paired Y/Z entries before zero padding

Magazine-training files use different scalar assignments and contain no Y/Z
event arrays. The wrapper normalises their session-level pellet and magazine
counts but correctly creates no event rows for them.
"""

from __future__ import annotations

import argparse
import csv
from datetime import datetime
from pathlib import Path
import re
import sys
from typing import Any

# Running this file directly places only workflows/fig1bc on Python's import
# path. Add the behavioural-analysis root so shared functions can be imported
# without requiring users to install the repository as a Python package.
BEHAVIOURAL_ANALYSIS_ROOT = Path(__file__).resolve().parents[2]
if str(BEHAVIOURAL_ANALYSIS_ROOT) not in sys.path:
    sys.path.insert(0, str(BEHAVIOURAL_ANALYSIS_ROOT))

from functions.medpc_parser import MedPCRecording, parse_medpc_file


# Subject prefixes were assigned experimentally and are independent of the
# MED-PC home-cage ``Group`` header. This mapping supplies the group labels used
# in the manuscript analysis.
GROUPS = {
    "1": "aRR20",
    "2": "RR20",
    "3": "RR10",
    "4": "RR5",
    "5": "CRF",
    "6": "first_contingency",
    "YT1": "yoked",
    "YT6": "non_contingent",
}

# Event-code meanings are specific to the NRR001 programmes. They must not be
# applied to MED-PC files from another experiment without checking its source
# programme first.
EVENT_TYPES = {
    0: "padding",
    1: "lever_response",
    2: "reserved",
    3: "pellet_delivery",
    4: "magazine_entry",
}

# The leading session columns provide analysis-ready names. Original MED-PC
# scalars are appended later as medpc_A, medpc_B, ... so the normalised values
# can always be traced back to the source variables.
SESSION_FIELDS = [
    "session_id",
    "subject_id",
    "experimental_group",
    "experiment_label",
    "training_day",
    "training_stage",
    "stage_day",
    "session_date",
    "start_time",
    "end_time",
    "box",
    "home_cage_group",
    "medpc_program",
    "active_lever",
    "duration_s",
    "duration_min",
    "lever_responses",
    "press_rate_per_min",
    "pellets_delivered",
    "magazine_entries",
    "first_contingency_reached",
    "first_contingency_time_min",
    "post_contingency_time_s",
    "event_count",
    "source_file",
    "source_relative_path",
]

# Repeating the small amount of group/session context on each event makes the
# event CSV usable without a mandatory database join. ``session_id`` remains
# the authoritative key back to the full session record.
EVENT_FIELDS = [
    "session_id",
    "subject_id",
    "experimental_group",
    "training_day",
    "training_stage",
    "stage_day",
    "event_index",
    "event_code",
    "event_type",
    "time_s",
]

# Session folders begin with the relative training day used in the figure,
# followed by the schedule and, where applicable, the day within that stage.
# Example: 09_RR10-1 is overall training day 9 and RR10 stage day 1.
_SESSION_FOLDER_PATTERN = re.compile(
    r"^(?P<day>\d{2})_(?P<stage>1st-cont|CRF|RR5|RR10|RR20)(?:-(?P<stage_day>\d+))?$"
)


def parse_args() -> argparse.Namespace:
    """Define the command-line interface used by local and public workflows."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input_folder",
        type=Path,
        help=(
            "Fig. 1 behaviour folder, or its 01_raw-MEDPC-files child. "
            "Session folders are searched recursively."
        ),
    )
    parser.add_argument(
        "--output-folder",
        type=Path,
        help="Destination folder (default: adjacent 02_extracted-data).",
    )
    return parser.parse_args()


def resolve_paths(input_folder: Path, output_folder: Path | None) -> tuple[Path, Path]:
    """Resolve the raw-data root and output folder.

    Users may point the script at either the public ``behaviour`` folder or
    directly at ``01_raw-MEDPC-files``. Supporting both keeps the published
    command simple while allowing the extractor to be tested elsewhere.
    """
    input_folder = input_folder.expanduser().resolve()
    raw_child = input_folder / "01_raw-MEDPC-files"
    if raw_child.is_dir():
        raw_root = raw_child
        default_output = input_folder / "02_extracted-data"
    elif input_folder.name == "01_raw-MEDPC-files" and input_folder.is_dir():
        raw_root = input_folder
        default_output = input_folder.parent / "02_extracted-data"
    else:
        raise NotADirectoryError(
            "Input must be the Fig. 1 behaviour folder or its "
            f"01_raw-MEDPC-files child: {input_folder}"
        )

    destination = (output_folder or default_output).expanduser().resolve()
    return raw_root, destination


def parse_session_folder(path: Path) -> tuple[int, str, int]:
    """Return overall training day, stage name and within-stage day.

    The overall day is the number used in ``session_id``. It is a relative
    training day, not a date. ``01_1st-cont`` has no explicit stage-day suffix,
    so its within-stage day is defined as 1.
    """
    match = _SESSION_FOLDER_PATTERN.match(path.name)
    if not match:
        raise ValueError(f"Unexpected session-folder name: {path.name}")

    training_day = int(match.group("day"))
    stage = match.group("stage")
    stage_day_text = match.group("stage_day")
    stage_day = int(stage_day_text) if stage_day_text else 1
    stage_name = "first_contingency" if stage == "1st-cont" else stage
    return training_day, stage_name, stage_day


def subject_group(subject_id: str) -> str:
    """Map the prefix of an NRR001 subject identifier to its analysis group."""
    prefix = subject_id.split("_", 1)[0]
    try:
        return GROUPS[prefix]
    except KeyError as exc:
        raise ValueError(f"Unknown NRR001 subject prefix in {subject_id!r}.") from exc


def iso_date(value: str) -> str:
    """Convert MED-PC MM/DD/YY dates to ISO YYYY-MM-DD when possible."""
    if not value:
        return ""
    try:
        return datetime.strptime(value, "%m/%d/%y").date().isoformat()
    except ValueError:
        return value


def active_lever(program: str) -> str:
    """Infer the extended lever side from the MED-PC programme name.

    Left/right variants use several historical naming styles (for example,
    ``DIR L``, ``_L`` and ``GRN LEFT``), all of which are handled explicitly.
    Magazine-training programmes have no lever and therefore return blank.
    """
    upper = program.upper()
    if (
        "_L " in upper
        or upper.startswith("DIR L ")
        or upper.endswith(" LEFT")
        or " GRN LEFT" in upper
    ):
        return "left"
    if (
        "_R " in upper
        or upper.startswith("DIR R ")
        or upper.endswith(" RIGHT")
        or " GRN RIGHT" in upper
    ):
        return "right"
    return ""


def clean_number(value: float | None) -> float | int | str:
    """Write whole-valued floats as integers and missing values as blank CSV cells."""
    if value is None:
        return ""
    if value.is_integer():
        return int(value)
    return value


def divide(numerator: float | None, denominator: float | None) -> float | str:
    """Divide numeric values while representing missing or zero denominators as blank."""
    if numerator is None or denominator is None or denominator == 0:
        return ""
    return numerator / denominator


def session_metrics(recording: MedPCRecording) -> dict[str, Any]:
    """Create consistently named session measures from programme variables.

    Instrumental and yoked programmes use ``A`` for lever responses, ``P`` for
    pellets, ``M`` for time-controlled magazine entries and centiseconds in
    ``T``. The magazine-training programme instead uses ``R`` for pellets,
    ``I`` for time-controlled magazine entries and seconds in ``T``. Handling
    that exception here lets downstream analyses use the same descriptive
    columns without losing the original values, which are also exported as
    ``medpc_*`` columns.

    First-contingency fields are populated only for the corresponding
    programmes. A zero ``C`` means that the criterion was not reached; blank
    values in other programmes mean that the criterion was not applicable.
    """
    scalars = recording.scalars
    program = recording.metadata.get("MSN", "")
    is_magazine_training = program == "MagTrain 40 GRN pellet"

    if is_magazine_training:
        duration_s = scalars.get("T")
        lever_responses = None
        pellets = scalars.get("R")
        magazine_entries = scalars.get("I")
    else:
        duration_s = divide(scalars.get("T"), 100.0)
        lever_responses = scalars.get("A")
        pellets = scalars.get("P")
        magazine_entries = scalars.get("M")

    if duration_s == "":
        duration_s_value = None
    else:
        duration_s_value = float(duration_s)
    duration_min = divide(duration_s_value, 60.0)
    duration_min_value = None if duration_min == "" else float(duration_min)

    is_first_contingency = program.startswith("1stContingency_")
    criterion_time = scalars.get("C") if is_first_contingency else None
    criterion_reached = bool(criterion_time and criterion_time > 0) if is_first_contingency else ""
    post_contingency_s = (
        divide(scalars.get("E"), 100.0) if criterion_reached else ""
    )

    return {
        "duration_s": clean_number(duration_s_value),
        "duration_min": duration_min,
        "lever_responses": clean_number(lever_responses),
        "press_rate_per_min": divide(lever_responses, duration_min_value),
        "pellets_delivered": clean_number(pellets),
        "magazine_entries": clean_number(magazine_entries),
        "first_contingency_reached": criterion_reached,
        "first_contingency_time_min": (
            clean_number(criterion_time) if criterion_reached else ""
        ),
        "post_contingency_time_s": post_contingency_s,
    }


def extract_events(
    recording: MedPCRecording,
    session_context: dict[str, Any],
) -> list[dict[str, Any]]:
    """Convert valid paired Y/Z entries into event-table rows.

    ``W`` is preferred over trimming zeros because it is the programme's own
    count of valid events. If ``W`` is unavailable, non-zero event codes are
    used as a conservative fallback. Magazine-training files have neither Y
    nor Z arrays and therefore return an empty list.

    A missing member of a Y/Z pair, an event count longer than either array or
    an unknown event code raises an error. These checks prevent apparently
    valid CSVs from being produced when event codes and times are misaligned.
    """
    y_values = recording.arrays.get("Y")
    z_values = recording.arrays.get("Z")
    if y_values is None and z_values is None:
        return []
    if y_values is None or z_values is None:
        raise ValueError(f"Only one of Y/Z is present in {recording.path}.")

    event_count_value = recording.scalars.get("W")
    if event_count_value is not None:
        event_count = int(event_count_value)
        if event_count > len(y_values) or event_count > len(z_values):
            raise ValueError(
                f"W={event_count} exceeds Y/Z array length in {recording.path}."
            )
        pairs = zip(y_values[:event_count], z_values[:event_count])
    else:
        pairs = (
            (code, timestamp)
            for code, timestamp in zip(y_values, z_values)
            if int(code) != 0
        )

    rows: list[dict[str, Any]] = []
    for event_index, (code_value, timestamp) in enumerate(pairs):
        code = int(code_value)
        if code not in EVENT_TYPES:
            raise ValueError(f"Unknown event code {code} in {recording.path}.")
        rows.append(
            {
                **session_context,
                "event_index": event_index,
                "event_code": code,
                "event_type": EVENT_TYPES[code],
                "time_s": clean_number(timestamp),
            }
        )
    return rows


def write_csv(path: Path, fields: list[str], rows: list[dict[str, Any]]) -> None:
    """Write a UTF-8 CSV with stable column order and one header row."""
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    """Parse every session, validate identifiers and write the linked tables."""
    args = parse_args()
    raw_root, output_folder = resolve_paths(args.input_folder, args.output_folder)
    source_files = sorted(path for path in raw_root.rglob("*.txt") if not path.name.startswith("._"))
    if not source_files:
        raise FileNotFoundError(f"No MED-PC .txt files found beneath {raw_root}.")

    session_rows: list[dict[str, Any]] = []
    event_rows: list[dict[str, Any]] = []
    scalar_names: set[str] = set()
    session_ids: set[str] = set()

    # Build both outputs in memory so that every source file and identifier is
    # validated before either final CSV is replaced.
    for path in source_files:
        recording = parse_medpc_file(path)
        subject_id = recording.metadata.get("Subject", "")
        experiment = recording.metadata.get("Experiment", "")
        if not subject_id or not experiment:
            raise ValueError(f"Missing Subject or Experiment header in {path}.")

        training_day, training_stage, stage_day = parse_session_folder(path.parent)
        # The relative training day is zero-padded for lexical sorting. Calendar
        # dates remain separate because the two cohorts were run months apart.
        session_id = f"{experiment}_{subject_id}_day-{training_day:02d}"
        if session_id in session_ids:
            raise ValueError(f"Duplicate session identifier {session_id!r}.")
        session_ids.add(session_id)

        group = subject_group(subject_id)
        event_context = {
            "session_id": session_id,
            "subject_id": subject_id,
            "experimental_group": group,
            "training_day": training_day,
            "training_stage": training_stage,
            "stage_day": stage_day,
        }
        events = extract_events(recording, event_context)

        row: dict[str, Any] = {
            **event_context,
            "experiment_label": experiment,
            "session_date": iso_date(recording.metadata.get("Start Date", "")),
            "start_time": recording.metadata.get("Start Time", ""),
            "end_time": recording.metadata.get("End Time", ""),
            "box": recording.metadata.get("Box", ""),
            "home_cage_group": recording.metadata.get("Group", ""),
            "medpc_program": recording.metadata.get("MSN", ""),
            "active_lever": active_lever(recording.metadata.get("MSN", "")),
            **session_metrics(recording),
            "event_count": len(events),
            "source_file": path.name,
            "source_relative_path": path.relative_to(raw_root).as_posix(),
        }
        # Preserve every scalar under its original letter in addition to the
        # standardised columns above. This makes the derivative auditable and
        # avoids discarding variables not needed by the present figures.
        for name, value in recording.scalars.items():
            field = f"medpc_{name}"
            row[field] = clean_number(value)
            scalar_names.add(field)

        session_rows.append(row)
        event_rows.extend(events)

    output_folder.mkdir(parents=True, exist_ok=True)
    scalar_fields = sorted(scalar_names)
    sessions_path = output_folder / "fig1bc_sessions.csv"
    events_path = output_folder / "fig1bc_events.csv"
    write_csv(sessions_path, SESSION_FIELDS + scalar_fields, session_rows)
    write_csv(events_path, EVENT_FIELDS, event_rows)

    print(f"Read {len(source_files)} MED-PC files from {raw_root}")
    print(f"Wrote {len(session_rows)} session rows to {sessions_path}")
    print(f"Wrote {len(event_rows)} event rows to {events_path}")


if __name__ == "__main__":
    main()
