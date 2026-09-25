# Return-map analysis

These scripts calculate individual and group-level return maps from MED-PC
event data. They accept input and output locations on the command line and
contain no personal filesystem paths.

## Input format and assumptions

The input folder should contain MED-PC `.txt` files with:

- `Subject:` and `MSN:` header fields;
- `Y:` event-code and `Z:` timestamp arrays;
- `L-GRN` or `R-GRN` in the MSN field to identify the active lever.

Lever presses use event code 3 or 4, depending on the active lever. Magazine
entries use event code 7. The group-level script assigns subjects beginning
with `BP` to the BP group and subjects beginning with `CT` to the CT group;
other subject names are ignored by that script.

## Recommended processing order

### 1. Calibrate the shared density scale

Select the session with the highest lever-press rate and the session with the
highest magazine-entry rate, then run:

```bash
python search_max_density.py "/path/to/highest_press_session.txt" "/path/to/highest_magazine_session.txt" --output-folder "/path/to/outputs"
```

This creates `search_max_density_output.txt`. Record the reported global
maximum press density and pass it to the plotting scripts with
`--press-density-max`. The same IPI range and number of bins should be used
for calibration and plotting.

### 2. Create individual return maps

```bash
python build_return_maps.py "/path/to/medpc-files" --output-folder "/path/to/outputs" --output-prefix "dayXX" --press-density-max 4
```

Outputs:

- `dayXX_press_scatter.svg`
- `dayXX_press_density.svg`
- `dayXX_mag.svg`

### 3. Create pooled group return maps

```bash
python build_group_return_maps.py "/path/to/medpc-files" --output-folder "/path/to/outputs" --output-prefix "dayXX" --press-density-max 4
```

Outputs:

- `dayXX_group_press_scatter.svg`
- `dayXX_group_press_density.svg`
- `dayXX_group_mag_scatter.svg`

## Optional settings

Both plotting scripts accept `--pattern` to restrict input filenames. The
calibration and plotting defaults are an IPI range of 0.1-100 seconds and 40
log-spaced bins. Run any script with `--help` to see all available options.
