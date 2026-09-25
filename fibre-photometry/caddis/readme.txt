Figure 3 and Extended Data Figure 6 - cADDis fibre-photometry workflows

Setup
1. Open caddis_paths.m.
2. Set fig3e_root, fig3k_root, and extfig6cd_root to the corresponding data
   folders.
3. Confirm that each data folder contains raw-data/ and processing/.

Expected raw-data structure
- raw-data/<subject-id>/<recording>.parquet
- processing/

The subject folders should use the six-digit identifiers listed in the
relevant figure configuration. Each parquet file must use the same 13-column
layout as the files exported for these experiments.

Fig. 3e processing order
1. Run batch_processing_fig3e.m.
2. Run summary_fig3e.m.

Fig. 3k processing order
1. Run batch_processing_fig3k.m.
2. Run summary_fig3k.m.

Extended Data Fig. 6c-d processing order
1. Run batch_processing_extfig6cd.m.
2. Run summary_extfig6cd.m.

Configuration
- caddis_common_config.m contains the shared parquet layout, dF/F settings,
  60-second causal smoothing, and section-mean intervals.
- fig3e_config.m, fig3k_config.m, and extfig6cd_config.m contain each figure's
  crop timestamps, treatment assignments, AUC intervals, and plot limits.
- The timestamps and treatment assignments were moved from the original
  time-stamps.xlsx and animal_mapping.csv files into the figure configs.
- Subject 038536 has Fig. 3e crop timestamps but no treatment assignment or
  raw parquet folder. It remains documented but is excluded from the Fig. 3e
  treatment-group summary.
- caddis_paths.m is the only file that needs local data paths.

Shared functions
- import_caddis_parquet.m imports one parquet file per subject and applies
  consistent column names.
- crop_caddis_recordings.m extracts and concatenates the baseline, T1, and
  T2 recording periods.
- compute_caddis_dff.m calculates the canonical time vector, dF/F, and
  baseline z score.
- process_caddis_dataset.m applies smoothing and calculates total, negative,
  and positive AUC for the intervals in the selected figure config.
- summarize_caddis_dataset.m exports treatment-group traces, group means,
  section means, negative-AUC values, and the summary figure.

Figure-specific differences
- Fig. 3e contains VG and RG groups and uses three AUC intervals ending at
  30 minutes.
- Fig. 3k contains one GR group and uses a fourth AUC interval from
  30.1 to 45 minutes.
- Extended Data Fig. 6c-d contains one RV group and uses four 10-minute
  periods: Baseline, T1a, T1b, and T1c.
- The Fig. 3k timestamp sheet also records t2_extra, t3_start, and t3_end.
  These are retained in fig3k_config.m for provenance. The original crop
  script calculated but did not append an extra segment, so the consolidated
  workflow preserves the original baseline + T1 + T2 crop.
- The Extended Data Fig. 6c-d timestamp sheet contains both test-042443 and
  test0-042443. Both are retained for provenance, while test-042443 is marked
  as the crop entry used by the original lookup.

Analysis provenance
The workflow follows the c_basal_AUC.m route because its AUC intervals match
the final summary scripts. The older c_basal_processing.m route used a
different z-score source and smoothing window and is not part of this
consolidated workflow.
