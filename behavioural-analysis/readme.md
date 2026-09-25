# Behavioural analysis

These Python workflows are organized by processing type. No script contains
a user-specific filesystem path. Input files and output folders are supplied
on the command line, or the script uses the current working folder as
described below.

## Setup

Install Python 3 and the required packages:

```bash
python -m pip install -r requirements.txt
```

Paths containing spaces should be enclosed in quotation marks.

## MED-PC data extraction

Extract every `.txt` file in a folder. Outputs are written beside the input
files unless `--output-folder` is supplied.

```bash
python data-extraction/extract_medpc.py "/path/to/medpc-files"
python data-extraction/extract_medpc.py "/path/to/medpc-files" --output-folder "/path/to/outputs"
```

## Summary-data plots

Both scripts expect an Excel workbook containing the `press-rate`, `mag-rate`,
and `session-time` sheets used by the original analysis. SVG files are written
beside the workbook unless `--output-folder` is supplied.

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

## Spatial ratio maps

Supply the folder containing paired `*_taSPNs_gfp.txt` and `*_STR.txt` files.
Outputs default to a `plots` folder inside the data folder.

```bash
python ratio-maps/mspatial_mesh_logratio_analysis.py "/path/to/ratio-map-data"
python ratio-maps/mspatial_mesh_logratio_analysis.py "/path/to/ratio-map-data" --output-folder "/path/to/plots"
```

## Return maps

The return-map workflow accepts input and output folders on the command line.
It requires an initial density calibration, followed by individual or pooled
group plotting. See `return-maps/readme.md` for the input assumptions and
complete processing order.
