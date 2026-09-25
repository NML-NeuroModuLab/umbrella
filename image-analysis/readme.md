# Image analysis

These MATLAB functions reconstruct classified neuron locations within a
polygon region and create spatial density plots from tab-delimited point
files. They contain no user-specific paths.

## Requirements

- MATLAB
- ImageJ/Fiji, or equivalent software, for exporting polygon and point
  coordinates as tab-delimited text files

Keep `ActivityPlot.m`, `DensityPlot.m`, `scatter_kde.m`, and `kde2d.m` in the
same folder, or add this folder to the MATLAB path.

## Activity plots and cell counts

`ActivityPlot` expects paired text files in one data folder:

- filenames containing `_pVLS` for polygon boundaries;
- filenames containing `_taSPNs` for neuronal measurements.

Polygon files must contain two tab-delimited numeric columns after one header
row. Neuronal files must contain five numeric columns after one header row;
the function reads signal intensity from column 3 and x/y coordinates from
columns 4 and 5.

Run:

```matlab
summary = ActivityPlot("/path/to/data");
```

The function plots the classified points within each polygon. It classifies
signal values greater than 30000 as D2 and all remaining values as D1, then
returns D1 and D2 counts for filenames beginning with `SH` or `DD`.

## Density plots

`DensityPlot` expects paired tab-delimited files whose names contain `_D1`
and `_D2`. Each file must contain x and y coordinates in the first two
columns after one header row.

Run:

```matlab
output_files = DensityPlot("/path/to/data","/path/to/outputs");
```

If the output folder is omitted, figures are saved in the data folder. The
function produces separate density-coloured D1 and D2 scatter plots in EPS
format. Density values are calculated by the bundled `kde2d.m` function.
