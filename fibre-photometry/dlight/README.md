# dLight workflows

## Setup

Open `dlight_paths.m` and set the source root for each dataset being analysed:

| Processing ID | Figshare folder | Required subfolders |
|---|---|---|
| `fig2bd` | `1_figures-main/fig2/panel_b_d/` | `hab3/`, `vg/`, `rg/`, `rv/` |
| `fig3dg` | `1_figures-main/fig3/panel_d_g/` | `hab3/`, `test/` |
| `fig3j` | `1_figures-main/fig3/panel_j/` | `GR/` |
| `suppfig6af` | `2_figures-supplemental/suppfig6/panel_a-f/` | `hab3-cohort3/` |
| `suppfig7ab` | `2_figures-supplemental/suppfig7/panel_a_b/` | `rv/` |

The corresponding `*_analysis_root` setting is optional. If empty, outputs
are written to `<figure-root>/analysis-output/`.

## Expected source-data structure

```text
<figure-root>/
  <condition>/
    <subject-id>/
      sub-<subject-id>_photometry.parquet
      sub-<subject-id>_notes.csv
      sub-<subject-id>_metadata.json
```

The Parquet file contains `time_s` and the selected animal's 405- and
465-nm streams. 

## Processing order
### Fig. 2b-d

1. Run `workflows/fig2bd/batch_processing_fig2bd.m`.
2. Run `workflows/fig2bd/batch_processing_fig2bd_basal.m`.
3. Run `workflows/fig2bd/summary_basal_fig2bd.m`.

### Fig. 3d-g

1. Run `workflows/fig3dg/batch_processing_fig3dg_hab3.m`.
2. Run `workflows/fig3dg/batch_processing_fig3dg_test.m`.
3. Run `workflows/fig3dg/batch_processing_fig3dg_basal.m`.
4. Run `workflows/fig3dg/summary_basal_fig3dg.m`.

### Fig. 3j

1. Run `workflows/fig3j/batch_processing_fig3j.m`.
2. Run `workflows/fig3j/batch_processing_fig3j_basal.m`.
3. Run `workflows/fig3j/summary_basal_fig3j.m`.

### Supplemental Fig. 6a-f

1. Set `fig3dg_root`, `fig2bd_root`, and `suppfig6af_root` in `dlight_paths.m`.
2. Run `workflows/suppfig6af/batch_processing_suppfig6af.m`.
3. Run `workflows/suppfig6af/summary_suppfig6af.m`.

Representative animals shown in individual-example panels are:

- panels a-b: subject `055621`;
- panel d: subject `035032`; and
- panel f: subject `032422`.

Panels c and e summarise the complete configured cohorts rather than a single
example animal.

The batch workflow starts from the raw Parquet recordings and calculates the
plotted values for panels a-f. Generated tables are written to
`<suppfig6af_analysis_root>/processed-data/` (or the default
`<suppfig6af_root>/analysis-output/processed-data/`). The summary workflow reads
those generated tables; it does not use the separately submitted manuscript
source-data files.

Recordings are stored only once in the Figshare archive:

- cohort 1 recordings are supplied with Fig. 3d-g;
- cohort 2 recordings are supplied with Fig. 2b-d;
- cohort 3 pharmacological recordings are supplied with Fig. 3j and Extended
  Data Fig. 6a-b; and
- the cohort 3 habituation recordings unique to the bleaching-correction
  validation are supplied in the Supplemental Fig. 6 `hab3-cohort3/` folder.

The cohort 1 and 2 habituation recordings are also used as bleaching references
for their main-figure workflows. The cohort 3 habituation recordings are unique
to this validation analysis.

The cohort 2 and cohort 3 habituation exports retain the complete recording,
including samples after the curated `end` note where present. These later
samples were included in the historical bleaching validation. The exact
analysis endpoints and reviewed artifact exclusions are defined in
`config/suppfig6af_config.m`; note timestamps are retained as recording
annotations and do not crop this workflow automatically.

#### Reviewed and custom fitting modes

`config/suppfig6af_config.m` sets `fit_window_mode` to `locked` by default.
This reproduces the reviewed manuscript fits using the supplied coefficients:

- `config/suppfig6af_bleach_fit_coefficients.csv` contains the reviewed
  full-recording bleaching fits;
- `config/suppfig6af_fit_coefficients.csv` contains the 10-minute, 30-minute,
  and full-trace coefficients used for the across-animal comparison in panel
  e; and
- `config/suppfig6af_example_fit_coefficients.csv` contains the corresponding
  all-sample fits for the representative trace in panel d.

The coefficient files preserve the customised fits without requiring the
historical MATLAB fit files. They are analysis configuration, not copies of
the submitted plotted-value tables.

To generate new fits from the Parquet recordings, set:

```matlab
cfg.fit_window_mode = 'refit';
```

This can be done in `config/suppfig6af_config.m` or by uncommenting the override
in `workflows/suppfig6af/batch_processing_suppfig6af.m`. In refit mode, the
workflow uses `fit_windows_min`, `fit_window_labels`, `fit_stride`, smoothing,
recording endpoints, and artifact exclusions from the configuration. These
settings can therefore be changed for alternative fitting windows or reviewed
exclusions. Both modes export the coefficients actually used to
`processed-data/`, alongside the panel tables.

For example, a custom comparison can be run programmatically with:

```matlab
paths = dlight_paths('suppfig6af');
cfg = suppfig6af_config();
cfg.fit_window_mode = 'refit';
cfg.fit_windows_min = [5 20 Inf];
cfg.fit_window_labels = {'5 min','20 min','Full trace'};
cfg.fit_stride = 50;
process_suppfig6af_dlight(paths,cfg);
```

The fitting implementation remains in
`functions/process_suppfig6af_dlight.m`, including the model definition,
starting points, parameter bounds, smoothing and sample-selection logic, so it
can be modified for other fitting strategies rather than requiring the locked
coefficients.

### Supplemental Fig. 7a-b

1. Run `workflows/suppfig7ab/batch_processing_suppfig7ab.m`.
2. Run `workflows/suppfig7ab/batch_processing_suppfig7ab_basal.m`.
3. Run `workflows/suppfig7ab/summary_basal_suppfig7ab.m`.

## Configuration

- `config/fig2bd_config.m` and its subject and condition files define the
  Fig. 2b-d streams, crop times, bleaching fits, and analysis windows.
- `config/fig3dg_config.m` and `config/fig3dg_subjects.m` define the Fig. 3d-g
  cohort and subject-specific fitting settings.
- `config/fig3j_config.m` and `config/suppfig7ab_config.m` define the GR and RV
  analyses. Both use the cohort in `config/gr_rv_subjects.m`.
- `config/suppfig6af_config.m` defines the Supplemental Fig. 6a-f cohorts,
  historical recording endpoints, reviewed artifact intervals, fitting
  mode and settings, representative animals, windows, and output names.
- `dlight_paths.m` is the only file that requires local source and output
  paths.

## Shared functions

- `functions/load_dlight_recording.m` reads and validates the public source
  files.
- `functions/process_fig2bd_dlight.m` and the two
  `functions/process_fig3dg_*_dlight.m` files perform the figure-specific
  filtering, bleaching correction, dF/F calculation, and time-window
  extraction.
- `functions/process_gr_rv_dlight.m` provides the shared Fig. 3j and Extended
  Data Fig. 6a-b processing pathway.
- The remaining functions prepare the basal analyses and export the summary
  tables and figures.
- `functions/process_suppfig6af_dlight.m` calculates panels a-f directly from
  the cohort 1-3 raw Parquet recordings. Its cohort-3 fit exclusions use the
  reviewed intervals stored in `config/suppfig6af_config.m`.
- `functions/summarise_suppfig6af_dlight.m` recreates panels a-f and their
  statistics from the tables generated by the processing function.
- The top-level `../functions/select_fp_artifact_intervals.m` and
  `../functions/apply_fp_artifact_intervals.m` provide general interactive
  interval selection and time-preserving artifact masking for new analyses.

## Treatment codes

- `VG`: VEH followed by GBR
- `RG`: RAC followed by GBR
- `GR`: GBR followed by RAC
- `RV`: RAC followed by VEH
