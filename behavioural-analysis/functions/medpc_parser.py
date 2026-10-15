"""Parse the text format exported by MED-PC.

MED-PC exports contain three kinds of information in one text file:

1. Descriptive headers such as ``Subject``, ``Experiment`` and ``MSN``.
2. Single-letter scalar variables such as ``A: 40.000``.
3. Indexed arrays such as ``Y`` and ``Z``, printed five values per row::

       Y:
            0:  4.000  1.000  3.000  4.000  0.000

This module deliberately does not assign biological meanings to the variables.
MED-PC variable letters and event codes are defined by the programme that made
the file, so interpretation belongs in an experiment-specific wrapper such as
``workflows/fig1bc/extract_fig1bc.py``.

Only the Python standard library is required.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re


# Header names expected in the MED-PC exports used in this repository. Their
# values are retained as strings so that identifiers and historical formatting
# are not altered by the generic parser.
HEADER_FIELDS = (
    "File",
    "Start Date",
    "End Date",
    "Subject",
    "Experiment",
    "Group",
    "Box",
    "Start Time",
    "End Time",
    "MSN",
)

# A scalar is accepted only when the whole line is a single capital letter,
# colon and numeric value. This prevents header values and indexed array rows
# from being mistaken for MED-PC scalar variables.
_HEADER_PATTERN = re.compile(
    rf"^({'|'.join(re.escape(field) for field in HEADER_FIELDS)}):\s*(.*)$"
)
_SCALAR_PATTERN = re.compile(
    r"^([A-Z]):\s*([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][-+]?\d+)?)\s*$"
)
_ARRAY_HEADER_PATTERN = re.compile(r"^([A-Z]):\s*$")
_ARRAY_ROW_PATTERN = re.compile(r"^\s*(\d+):\s*(.*)$")


@dataclass(frozen=True)
class MedPCRecording:
    """Structured representation of one MED-PC text export.

    Attributes
    ----------
    path
        Original text-file path. Retained for provenance and useful errors.
    metadata
        Named MED-PC headers, stored exactly as text.
    scalars
        Single-letter scalar variables converted to floating-point numbers.
    arrays
        Single-letter indexed arrays converted to ordered lists of numbers.
        Array padding is preserved here; the experiment wrapper decides which
        entries are valid (for NRR001, scalar ``W`` provides that count).
    """

    path: Path
    metadata: dict[str, str]
    scalars: dict[str, float]
    arrays: dict[str, list[float]]


def parse_medpc_file(path: str | Path) -> MedPCRecording:
    """Parse MED-PC headers, single-letter scalars and indexed arrays.

    Parameters
    ----------
    path
        Path to one MED-PC text export.

    Returns
    -------
    MedPCRecording
        Parsed headers, scalars and arrays without experiment-specific
        interpretation.

    Raises
    ------
    ValueError
        If an indexed array row does not begin where the preceding row ended.
        This check catches incomplete downloads and malformed exports instead
        of silently shifting event codes away from their timestamps.
    """

    path = Path(path)
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    metadata: dict[str, str] = {}
    scalars: dict[str, float] = {}
    arrays: dict[str, list[float]] = {}
    current_array: str | None = None

    # MED-PC files may use Windows CRLF line endings. Normalising them before
    # parsing avoids carrying carriage-return characters into header values.
    for raw_line in text.replace("\r", "").splitlines():
        line = raw_line.strip()

        header_match = _HEADER_PATTERN.match(line)
        if header_match:
            metadata[header_match.group(1)] = header_match.group(2).strip()
            current_array = None
            continue

        scalar_match = _SCALAR_PATTERN.match(line)
        if scalar_match:
            scalars[scalar_match.group(1)] = float(scalar_match.group(2))
            current_array = None
            continue

        array_header_match = _ARRAY_HEADER_PATTERN.match(line)
        if array_header_match:
            current_array = array_header_match.group(1)
            arrays[current_array] = []
            continue

        if current_array is None:
            continue

        # Indexed rows are appended in their printed order. The explicit index
        # check ensures that no row was skipped or duplicated in the source.
        array_row_match = _ARRAY_ROW_PATTERN.match(raw_line)
        if not array_row_match:
            continue

        expected_index = int(array_row_match.group(1))
        values = [float(value) for value in array_row_match.group(2).split()]
        if expected_index != len(arrays[current_array]):
            raise ValueError(
                f"Unexpected {current_array} array index {expected_index} in {path}; "
                f"expected {len(arrays[current_array])}."
            )
        arrays[current_array].extend(values)

    return MedPCRecording(
        path=path,
        metadata=metadata,
        scalars=scalars,
        arrays=arrays,
    )
