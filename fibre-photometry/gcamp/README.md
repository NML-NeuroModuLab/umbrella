# GCaMP6m workflows

This folder contains the D1-SPN analysis for Supplemental Fig. 3e-h and the
D2-SPN analysis for Supplemental Fig. 5c-f.

## Setup

1. Open `gcamp_paths.m`.
2. Set `suppfig3eh_root` to
   `2_figures-supplemental/suppfig3/panel_e-h/` in the downloaded Figshare archive.
3. Set `suppfig5cf_root` to
   `2_figures-supplemental/suppfig5/panel_c-f/`.
4. Optionally set the corresponding `*_analysis_root`. If empty, outputs are
   written to `<figure-root>/analysis-output/`.

The TDT MATLAB SDK is not required.

## Expected source-data structure

```text
<figure-root>/
  hab3/
    <subject-id>/
      sub-<subject-id>_photometry.parquet
      sub-<subject-id>_video_sync.parquet
      sub-<subject-id>_notes.csv
      sub-<subject-id>_metadata.json
  <treatment>/
    <subject-id>/
      sub-<subject-id>_photometry.parquet
      sub-<subject-id>_video_sync.parquet
      sub-<subject-id>_notes.csv
      sub-<subject-id>_metadata.json
```

The photometry Parquet contains `time_s` and the selected animal's 405- and
465-nm streams. The video-sync Parquet contains the TDT pulse times used to
align the photometry analysis windows. Video, pose-estimation, and locomotion
files are not included in this workflow.

## Processing order

### Supplemental Fig. 3e-h

1. Run `workflows/suppfig3eh/batch_processing_suppfig3eh.m`.
2. Run `workflows/suppfig3eh/summary_suppfig3eh.m`.

### Supplemental Fig. 5c-f

1. Run `workflows/suppfig5cf/batch_processing_suppfig5cf.m`.
2. Run `workflows/suppfig5cf/summary_suppfig5cf.m`.

## Analysis

Both workflows process the Hab3 and test-day recordings, apply the configured
bleaching correction, fit the 405-nm reference to the 465-nm signal, and
calculate dF/F and baseline z-scores. The test-day periods are aligned using
the exported video-sync pulses. The workflow then detects calcium transients
and reports transient rates for the final 10 minutes of each experimental
period.

## Configuration

- `config/suppfig3eh_config.m` contains the D1-SPN cohort, stream assignments,
  analysis times, synchronisation settings, and subject-specific bleaching
  choices.
- `config/suppfig5cf_config.m` contains the D2-SPN cohort, analysis times,
  synchronisation settings, and fixed Hab3 bleaching fits.
- `gcamp_paths.m` is the only file that requires local source and output
  paths.

## Shared functions

- `functions/load_gcamp_recording.m` reads and validates the photometry,
  notes, metadata, and video-sync files.
- `functions/process_gcamp_session.m` provides the shared Hab3 and test-day
  processing.
- `functions/detect_gcamp_transients.m` detects transients and calculates
  one-minute summaries.
- `functions/summarise_gcamp_dataset.m` exports the figure-specific source
  tables and summary figures using the selected configuration.

## Treatment codes

- `VV`: VEH followed by VEH
- `VG`: VEH followed by GBR
- `RG`: RAC followed by GBR
