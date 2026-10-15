# Fibre-photometry analysis

This directory contains the analysis workflows for all fibre-photometry figures.
Use the figure index below to identify the sensor folder and analysis entry
point. Each sensor folder has a separate README with its source-data layout,
configuration, and complete processing order.

Within each sensor folder, runnable scripts are grouped by figure under
`workflows/`, figure settings are in `config/`, and reusable analysis code is
in `functions/`. Functions that apply across sensors are in the top-level
`functions/` folder. The editable paths file remains at the sensor-folder root.

## Figure index

### Main Figures

| Processing ID | Figure panel(s) | Sensor and readout | Analysis folder | Start here |
|---|---|---|---|---|
| `fig2bd` | Fig. 2b-d | dLight (dopamine) | [`dlight/`](dlight/README.md) | [`batch_processing_fig2bd.m`](dlight/workflows/fig2bd/batch_processing_fig2bd.m) |
| `fig3dg` | Fig. 3d and 3g | dLight (dopamine) | [`dlight/`](dlight/README.md) | [`batch_processing_fig3dg_hab3.m`](dlight/workflows/fig3dg/batch_processing_fig3dg_hab3.m) |
| `fig3eh` | Fig. 3e and 3h | cADDis (cAMP) | [`caddis/`](caddis/README.md) | [`batch_processing_fig3eh.m`](caddis/workflows/fig3eh/batch_processing_fig3eh.m) |
| `fig3fil` | Fig. 3f, 3i, and 3l | ExRaiAKAR2 (PKA activity) | [`exrai-akar2/`](exrai-akar2/README.md) | [`batch_processing_fig3fil.m`](exrai-akar2/workflows/fig3fil/batch_processing_fig3fil.m) |
| `fig3j` | Fig. 3j | dLight (dopamine) | [`dlight/`](dlight/README.md) | [`batch_processing_fig3j.m`](dlight/workflows/fig3j/batch_processing_fig3j.m) |
| `fig3k` | Fig. 3k | cADDis (cAMP) | [`caddis/`](caddis/README.md) | [`batch_processing_fig3k.m`](caddis/workflows/fig3k/batch_processing_fig3k.m) |
| `fig4j` | Fig. 4j | ExRaiAKAR2 (PKA activity) | [`exrai-akar2/`](exrai-akar2/README.md) | *see Behapy pipeline notes |
| `fig4l` | Fig. 4l | ExRaiAKAR2 (PKA activity) | [`exrai-akar2/`](exrai-akar2/README.md) | *see Behapy pipeline notes |
| `fig4mn` | Fig. 4mn | ExRaiAKAR2 (PKA activity) | [`exrai-akar2/`](exrai-akar2/README.md) | *see Behapy pipeline notes |

### Supplemental Figures
| Processing ID | Figure panel(s) | Sensor and readout | Analysis folder | Start here |
|---|---|---|---|---|
| `suppfig3e-h` | Supplemental Fig. 3e-h | GCaMP6m (D1-SPN calcium) | [`gcamp/`](gcamp/README.md) | [`batch_processing_suppfig3eh.m`](gcamp/workflows/suppfig3eh/batch_processing_suppfig3eh.m) |
| `suppfig4` | Supplemental Fig. 4 | GCaMP6m (D1-SPN calcium) | [`gcamp/`](gcamp/README.md) | *See Behapy pipeline notes |
| `suppfig5c-f` | Supplemental Fig. 5c-f | GCaMP6m (D2-SPN calcium) | [`gcamp/`](gcamp/README.md) | [`batch_processing_suppfig5cf.m`](gcamp/workflows/suppfig5cf/batch_processing_suppfig5cf.m) |
| `suppfig6af` | Supplemental Fig. 6a-f | dLight (dopamine) | [`dlight/`](dlight/README.md) | [`batch_processing_suppfig6af.m`](dlight/workflows/suppfig6af/batch_processing_suppfig6af.m) |
| `suppfig6gj` | Supplemental Fig. 6g-j | cADDis (cAMP) | [`caddis/`](caddis/README.md) | [`batch_processing_suppfig6gj.m`](caddis/workflows/suppfig6gj/batch_processing_suppfig6gj.m) |
| `suppfig6ko` | Supplemental Fig. 6k-o | ExRaiAKAR2 (PKA activity) | [`exrai-akar2/`](exrai-akar2/README.md) | [`batch_processing_suppfig6ko.m`](exrai-akar2/workflows/suppfig6ko/batch_processing_suppfig6ko.m), then [`summary_suppfig6ko.m`](exrai-akar2/workflows/suppfig6ko/summary_suppfig6ko.m) |
| `suppfig7ab` | Supplemental Fig. 7a-b | dLight (dopamine) | [`dlight/`](dlight/README.md) | [`batch_processing_suppfig7ab.m`](dlight/workflows/suppfig7ab/batch_processing_suppfig7ab.m) |
| `suppfig7cd` | Supplemental Fig. 7c-d | cADDis (cAMP) | [`caddis/`](caddis/README.md) | [`batch_processing_suppfig7cd.m`](caddis/workflows/suppfig7cd/batch_processing_suppfig7cd.m) |
| `suppfig7ef` | Supplemental Fig. 7e-f | ExRaiAKAR2 (PKA activity) | [`exrai-akar2/`](exrai-akar2/README.md) | [`summary_suppfig7ef.m`](exrai-akar2/workflows/suppfig7ef/summary_suppfig7ef.m) |

**Note:** The `suppfig7ef` analysis reuses the preprocessed and RV-normalised recordings
from `fig3fil`. Complete the `fig3fil` processing and normalisation steps
before running its summary script.

## General workflow

1. Open the sensor folder's path file and set the source-data location.
2. Check the figure-specific configuration file in that sensor's `config/`
   folder.
3. Run the batch and summary scripts in the order listed in that folder's
   README.

## Artifact intervals

Reviewed artifact intervals are stored explicitly in the relevant figure
configuration so that public workflows are non-interactive and reproducible.
For new analyses, `functions/select_fp_artifact_intervals.m` provides the
historical click-to-select review interface. The resulting intervals can be
applied without changing the time axis using
`functions/apply_fp_artifact_intervals.m`, either as a fit-exclusion mask, by
setting affected samples to `NaN`, or by interpolation when valid data bracket
the interval.

Raw data will be available via Figshare upon manuscript publication: https://doi.org/10.6084/m9.figshare.33969307

## Requirements

### Matlab

The analysis code provided here was developed for MATLAB. MATLAB R2021a or later is
recommended.

Required toolboxes:

- **Signal Processing Toolbox** — used for low-pass filtering and
  downsampling (`lowpass`, `downsample`) throughout the dLight, GCaMP6m, and
  ExRaiAKAR2 workflows, and for GCaMP transient detection (`findpeaks`).
- **Curve Fitting Toolbox** — required for the dLight and GCaMP6m workflows,
  which use `fit` and `fittype` for bleaching correction and reference-channel
  fitting. It is also required when the optional cADDis independent-refit
  mode is used; the default locked-coefficient cADDis workflows do not need it.
- **Statistics and Machine Learning Toolbox** — used for the paired and
  one-sample tests reported in Supplemental Fig. 6 and other summary
  analyses, including the ExRaiAKAR2 repeatability model (`signrank`, `ttest`,
  `prctile`, and `fitlme`).

### Behapy (Python)

The original cADDis preprocessing and the analyses presented in Supplemental Fig. 4 were performed using development versions of Behapy. A substantially updated and fully validated Behapy release is being prepared alongside a separate methods manuscript.

- See Behapy: https://github.com/crnolan/behapy.

For the cADDis datasets, the fitted parameters and reviewed rejection intervals from the historical Behapy preprocessing are supplied with the MATLAB analysis code. These fixed parameters allow the reported corrected signals to be reconstructed without rerunning Behapy.

Reproduction of the Fig 4 and Supplemental Fig. 4 analyses requires the corresponding Behapy version together with the figure-specific configuration and analysis scripts. A version-specific archival link will be provided when the validated Behapy release becomes publicly available.


## Raw data notes
- Relevant data streams from the original TDT tanks have been extracted and provided as .parquet files with .json meta data in the figshare archive
- The analysis workflows have been adapted to use raw data provided in this format as input.
- Original extraction from TDT tank format was performed using the TDTbin2mat function provided by TDT (https://github.com/tdtneuro/TDTMatlabSDK)
- The separately submitted manuscript source-data tables are not duplicated in this raw-data archive. Figure-level tables are regenerated by the analysis workflows and written to their analysis-output folders.
