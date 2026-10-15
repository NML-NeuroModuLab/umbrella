# cADDis workflows

## Setup

Open `caddis_paths.m` and set the source root for each dataset being analysed:

| Processing ID | Figshare folder | Treatment folders |
|---|---|---|
| `fig3eh` | `1_figures-main/fig3/panel_e_h/` | `RG/`, `VG/` |
| `fig3k` | `1_figures-main/fig3/panel_k/` | `GR/` |
| `suppfig6gj` | `2_figures-supplemental/suppfig6/panel_g-j/` | `hab3/` (and recordings reused from Fig. 3) |
| `suppfig7cd` | `2_figures-supplemental/suppfig7/panel_c_d/` | `rv/` |

The corresponding `*_analysis_root` setting is optional. If empty, outputs
are written to `<figure-root>/analysis-output/`.

## Expected source-data structure

```text
<figure-root>/
  <treatment>/
    <subject-id>/
      sub-<subject-id>_photometry.parquet
      sub-<subject-id>_notes.csv
      sub-<subject-id>_metadata.json
```

The Parquet file contains `time_s`, the 465-nm cADDis stream, and the 560-nm
mCherry reference stream.

## Behapy preprocessing

The cADDis recordings were preprocessed using the simultaneous fitting procedure in the Behapy pipeline.

- The resulting fit coefficients and reviewed rejection intervals are provided in `config/`. The MATLAB workflow uses these values to reconstruct the corrected signals, so Behapy is not required to reproduce the reported analysis.
- Instructions, configuration files, and environment details for rerunning the preprocessing from the exported raw streams in Behapy will also be provided.

## Processing order

### Fig. 3e-h

1. Run `workflows/fig3eh/batch_processing_fig3eh.m`.
2. Run `workflows/fig3eh/summary_fig3eh.m`.

### Fig. 3k

1. Run `workflows/fig3k/batch_processing_fig3k.m`.
2. Run `workflows/fig3k/summary_fig3k.m`.

### Supplemental Fig. 6g-j

1. Set `suppfig6gj_root`, `fig3eh_root`, and `fig3k_root` in
   `caddis_paths.m`.
2. Run `workflows/suppfig6gj/batch_processing_suppfig6gj.m`.
3. Run `workflows/suppfig6gj/summary_suppfig6gj.m`.

Panel g shows the representative habituation recording from subject `038537`.
Panels h-j report animal-level or cohort-level comparisons rather than a
single example animal.

Panels g-h validate the 560-nm mCherry reference using habituation
recordings. Panels i-j compare the historical sequential fitting workflow
with the Behapy simultaneous fit. The batch workflow derives new panel tables
from the shared raw streams; it does not read the separately submitted
manuscript source-data tables. Raw pharmacological recordings are reused from
Fig. 3e-h and Fig. 3k, while the additional habituation recordings are
supplied in `hab3/` with Supplemental Fig. 6.

Generated panel tables are written to
`<analysis-root>/generated-source-data/`. The summary workflow reads these
generated tables and writes the panel PDFs and statistics to
`<analysis-root>/summary/`.

### Supplemental Fig. 7c-d

1. Run `workflows/suppfig7cd/batch_processing_suppfig7cd.m`.
2. Run `workflows/suppfig7cd/summary_suppfig7cd.m`.

## Configuration

- `config/caddis_common_config.m` contains the shared dF/F, smoothing, and
  section-mean settings.
- `config/fig3eh_config.m`, `config/fig3k_config.m`, and
  `config/suppfig7cd_config.m` contain the cohorts, crop times, treatment
  assignments, AUC intervals, and plot limits.
- `config/suppfig6gj_config.m` defines the Supplemental Fig. 6g-j cohorts,
  epoch timings, fitting mode, plotting windows, and bootstrap settings.
- `config/suppfig6gj_hab3_fit_coefficients.csv` contains the reviewed
  independent 465- and 560-nm bleach fits used for panels g-h.
- `config/suppfig6gj_sequential_fit_coefficients.csv` contains the reviewed
  historical sequential bleach and linear-fit coefficients used for panels
  i-j. The corresponding artifact and fit-exclusion tables are also retained
  in `config/`.
- The Fig. 3 and Supplemental Fig. 7 configurations have corresponding
  Behapy joint-fit parameter and rejected-interval CSVs in `config/`.
  Supplemental Fig. 6 reuses the Fig. 3 Behapy fits for its simultaneous-fit
  comparison.
- `caddis_paths.m` is the only file that requires local source and output
  paths.

## Shared functions

- `functions/import_caddis_raw.m` downsamples the raw streams, applies the
  reviewed rejection intervals, and reconstructs the Behapy simultaneous
  fit.
- `functions/crop_caddis_recordings.m` joins the configured baseline, T1,
  and T2 periods, removing the artifact periods where injections occur.
- `functions/compute_caddis_dff.m` calculates dF/F and the baseline z-score.
- `functions/process_caddis_dataset.m` calculates the smoothed traces and AUC
  measurements.
- `functions/summarise_caddis_dataset.m` exports the source tables and summary
  figures.
- `functions/process_suppfig6gj_caddis.m` processes the habituation
  validation, reconstructs the Behapy simultaneous fits, applies the
  historical sequential fits, and exports newly generated panel tables.
- `functions/summarise_suppfig6gj_caddis.m` creates panels g-j and the
  animal-level 465/560 correlation statistics from those generated tables.

## Supplemental Fig. 6 fitting options

`suppfig6gj_config.m` defaults to `independent_fit_mode = 'locked'`. This uses
the reviewed coefficients associated with the reported analysis and is the
recommended reproduction mode. Changing this to `'refit'` reruns the older
independent exponential bleach fits using the recorded model and exclusion
choices; this route requires MATLAB's Curve Fitting Toolbox and may vary
slightly with optimiser version.

The simultaneous fits remain fixed in both modes because they were produced
by Behapy. Their exported coefficients are sufficient for the MATLAB
workflow, so Behapy is not required unless the simultaneous preprocessing
itself is being refitted.

## Treatment codes

- `VG`: VEH followed by GBR
- `RG`: RAC followed by GBR
- `GR`: GBR followed by RAC
- `RV`: RAC followed by VEH
