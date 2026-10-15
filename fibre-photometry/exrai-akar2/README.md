# ExRaiAKAR2 workflow

## Setup

1. Open `exrai_paths.m`.
2. Set `fig3fil_root` to `1_figures-main/fig3/panel_f_i_l/` in the
   downloaded Figshare archive. This folder contains `VG/`, `RG/`, `GR/`,
   and `RV/`.
3. Optionally set `fig3fil_analysis_root`. If empty, outputs are written to
   `<fig3fil_root>/analysis-output/`.
4. Set `suppfig7ef_root` to the folder where Supplemental Fig. 7e-f outputs
   should be saved.
5. Optionally set `suppfig6ko_analysis_root` to choose where Supplemental
   Fig. 6k-o outputs are written. If empty, they are written beneath the
   Fig. 3 analysis folder.

The TDT MATLAB SDK is not required.

## Expected source-data structure

```text
<fig3fil_root>/
  <treatment>/
    <subject-id>/
      sub-<subject-id>_photometry.parquet
      sub-<subject-id>_notes.csv
      sub-<subject-id>_metadata.json
```

Treatment is `VG`, `RG`, `GR`, or `RV`. The Parquet file contains `time_s`
and the selected animal's 405- and 465-nm streams.

## Processing order

### Fig. 3f, 3i, and 3l

1. Run `workflows/fig3fil/batch_processing_fig3fil.m`.
2. Run `workflows/fig3fil/batch_normalisation_fig3fil.m`.
3. Run `workflows/fig3fil/summary_fig3fil.m`.

### Supplemental Fig. 7e-f

1. Complete steps 1 and 2 above.
2. Run `workflows/suppfig7ef/summary_suppfig7ef.m`.

Supplemental Fig. 7e-f is a 10-minute-bin analysis of the RV sessions from
the same recording set. It reuses the Fig. 3 preprocessed and RV-normalised
files. Outputs are saved to `<suppfig7ef_root>/processing/RV_10min/`.

### Supplemental Fig. 6k-o

1. Complete the Fig. 3 batch processing. The normalisation step is not
   required for this validation workflow.
2. Run `workflows/suppfig6ko/batch_processing_suppfig6ko.m`.
3. Run `workflows/suppfig6ko/summary_suppfig6ko.m`.

Representative animals shown in individual-example panels are:

- panel k: subject `045871` from the RV condition;
- panel l: subjects `045871` and `046141` from the VG condition; and
- panel n: the same VG subjects (`045871` and `046141`), with each trace
  scaled to its matched RV recording.

Panels m and o use all seven configured subjects rather than selected
examples.

These panels validate the ratiometric signal and RAC-peak normalisation.
They use recordings already supplied with Fig. 3f, 3i, and 3l, so the raw
Parquet files are not duplicated in the Supplemental Fig. 6 package. The
batch workflow regenerates the plotted-value tables from the Fig. 3
preprocessing outputs and writes them to
`<suppfig6ko_analysis_root>/generated-source-data/`. By default this is
`<fig3fil_analysis_root>/suppfig6ko/generated-source-data/`, or
`<fig3fil_root>/analysis-output/suppfig6ko/generated-source-data/` when the
Fig. 3 analysis root is also left empty. The summary workflow reads those
generated tables; submitted manuscript source-data tables are not included
in the raw-data archive and are not required by this workflow.

## Configuration

- `config/fig3fil_config.m` contains the subjects, stream assignments,
  crop times, artefact intervals, preprocessing settings, RV normalisation,
  and 15-minute analysis intervals.
- `config/suppfig7ef_config.m` contains the Supplemental Fig. 7e-f
  10-minute intervals and points to the shared normalised RV files.
- `config/suppfig6ko_config.m` defines the Supplemental Fig. 6k-o subjects,
  treatments, smoothing and analysis windows, bootstrap settings, and output
  table names.
- `exrai_paths.m` is the only file that requires local source and output
  paths.

VG and RG supply Fig. 3f and 3i, GR supplies Fig. 3l, and RV is the
within-animal normalisation reference.

## Shared functions

- `functions/process_exrai_session.m` filters and downsamples the 405- and
  465-nm streams, masks configured artefacts, calculates dR/R and z(dR/R),
  and extracts the analysis periods.
- `functions/normalise_exrai_to_rv.m` applies the 30-second moving mean and
  scales each treatment to the same animal's RV peak.
- `functions/summarise_fig3fil_exrai.m` exports the Fig. 3 source tables and
  figures.
- `functions/summarise_suppfig7ef_exrai.m` performs the separate 10-minute RV
  analysis and exports its source tables and figure.
- `functions/process_suppfig6ko_exrai.m` derives panels k-o from the Fig. 3
  preprocessing outputs, including RAC-peak repeatability and the
  between-animal variability comparison.
- `functions/summarise_suppfig6ko_exrai.m` creates the panel figures from the
  regenerated tables and exports the accompanying statistics.

## Treatment codes

- `VG`: VEH followed by GBR
- `RG`: RAC followed by GBR
- `GR`: GBR followed by RAC
- `RV`: RAC followed by VEH
