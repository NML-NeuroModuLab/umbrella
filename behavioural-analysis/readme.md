# Behavioural analysis

Reusable code is kept in `functions/`, while figure-specific entry points are
kept under `workflows/<figure-id>/`. No script contains a user-specific
filesystem path. Input files and output folders are supplied on the command
line, or the script uses the current working folder as described below.

The older `data-plotting/`, `raster-clouds/` and `return-maps/` folders have
not yet been assigned to figure-specific workflows and retain their existing
locations for now.

## Setup

Install Python 3 and the required packages:

```bash
python -m pip install -r requirements.txt
```

Paths containing spaces should be enclosed in quotation marks.

## MED-PC data extraction

### Figure 1b-c (NRR001)

The Fig. 1 extractor reads all numbered session folders recursively and writes
two linked CSV files: one row per session in `fig1bc_sessions.csv`, and one row
per timestamped event in `fig1bc_events.csv`. It accepts either the Fig. 1
`behaviour` folder or its `01_raw-MEDPC-files` child. By default, the files are
written to the adjacent `02_extracted-data` folder.

```bash
python workflows/fig1bc/extract_fig1bc.py "/path/to/fig1/behaviour"
python workflows/fig1bc/extract_fig1bc.py "/path/to/fig1/behaviour" --output-folder "/path/to/outputs"
```

This workflow uses the NRR001 event assignments: `1` is a lever response, `3`
is pellet delivery and `4` is a time-controlled magazine entry. The shared
parser in `functions/medpc_parser.py` can be reused by future
experiment-specific extraction wrappers.

### Figure 1b plot

The Fig. 1b wrapper reads `fig1bc_sessions.csv`, plots individual press-rate
traces and the pooled daily mean ± SEM, and recreates the group-duration bars
shown beneath the panel. It also exports the exact subject-level plot values,
daily summary, and subject-inclusion table. By default, outputs are written to
`03_analysis-output/fig1b/` beside the extracted-data folder.

```bash
python workflows/fig1bc/plot_fig1b.py "/path/to/fig1/behaviour" --annotate-significance
python workflows/fig1bc/plot_fig1b.py "/path/to/fig1/behaviour" --output-folder "/path/to/outputs"
```

The submitted Fig. 1b source-data table contains the five trained groups
(`CRF`, `RR5`, `RR10`, `RR20`, and `aRR20`) and does not contain subject
`4_10138`. The wrapper makes this exclusion explicit in
`fig1b_subject_selection.csv`. Use `--include-all-subjects` to inspect the
unfiltered extracted cohort. `--annotate-significance` reproduces the displayed
asterisk but does not rerun the inferential analysis.

## Legacy summary-data plots

These scripts belong to a separate BiPAC/control experiment and are not used
for Fig. 1b. Both expect an Excel workbook containing the `press-rate`,
`mag-rate`, and `session-time` sheets used by that analysis. SVG files are
written beside the workbook unless `--output-folder` is supplied.

```bash
python data-plotting/plot_summary-data.py "/path/to/summary-data.xlsx"
python data-plotting/plot_summary-individual-data.py "/path/to/summary-data.xlsx"
```

## Raster clouds

Place the MED-PC `.txt` files and `choice_mapping.csv` beside
`choice_raster_clouds.py`, then run one of:

```bash
python raster-clouds/choice_raster_clouds.py --devalued old
python raster-clouds/choice_raster_clouds.py --devalued new
```

## Return maps

The return-map workflow accepts input and output folders on the command line.
It requires an initial density calibration, followed by individual or pooled
group plotting. See `return-maps/readme.md` for the input assumptions and
complete processing order.
