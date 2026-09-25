Figures 2 and 3 and Extended Data Fig. 6 - dLight fibre photometry workflows

Setup
1. Open dlight_paths.m.
2. Set fig2bd_root, fig3d_root, fig3j_root, and extfig6a_root to the respective
   data folders.
3. Set tdt_sdk_root to the folder containing the TDT MATLAB SDK.
4. Confirm that the folder structure below matches your data.

All analysis code is kept together in this folder. The datasets may remain in
separate locations and are selected through dlight_paths.m.

Expected Fig. 2b-d data structure
- raw-data/hab3/<animal-id>/
- raw-data/VG/<animal-id>/
- raw-data/RG/<animal-id>/
- raw-data/RV/<animal-id>/
- processing/outputs/

Expected Fig. 3d data structure
- raw-data/hab3/<animal-id>/
- raw-data/test/<animal-id>/
- processing/outputs/

Expected Fig. 3j GR data structure
- raw-data/GR/<animal-id>/
- processing/outputs/

Expected Extended Data Fig. 6a RV data structure
- raw-data/RV/<animal-id>/
- processing/outputs/

Fig. 2b-d processing order
1. batch_processing_fig2bd.m
2. batch_processing_fig2bd_basal.m
3. summary_basal_fig2bd.m

Fig. 3d processing order
1. batch_processing_fig3d_hab3.m
2. batch_processing_fig3d_test.m
3. batch_processing_fig3d_basal.m
4. summary_basal_fig3d.m

Fig. 3j GR processing order
1. batch_processing_fig3j.m
2. batch_processing_fig3j_basal.m
3. summary_basal_fig3j.m

Extended Data Fig. 6a RV processing order
1. batch_processing_extfig6a.m
2. batch_processing_extfig6a_basal.m
3. summary_basal_extfig6a.m

Fig. 3d processing functions
- process_fig3d_hab3_dlight.m
- process_fig3d_test_dlight.m
- process_basal_fig3d.m

Fig. 2b-d processing functions
- process_fig2bd_dlight.m
- process_basal_fig2bd.m
- summarize_fig2bd.m

Shared GR/RV processing functions
- process_gr_rv_dlight.m performs filtering, downsampling, artefact
  interpolation, baseline fitting, and construction of the canonical trace.
- process_basal_gr_rv.m performs configurable smoothing, mean, change,
  and AUC analysis.
- summarize_basal_gr_rv.m exports tables, source traces, and figures.

Configuration
- fig2bd_config.m contains the stream assignments, habituation bleach-fit
  settings, recording timestamps, and historical correction exceptions.
- fig2bd_subjects.m and fig2bd_conditions.m define the displayed datasets.
- fig3d_config.m contains shared settings, animal-specific settings, and
  the baseline, T1, and T2 timestamps for each experimental day.
- fig3j_config.m contains the GR stream assignments, timestamps,
  artefact intervals, and 15-minute analysis settings.
- extfig6a_config.m contains the RV stream assignments, timestamps,
  artefact intervals, and 10-minute analysis settings.
- gr_rv_subjects.m contains the animal list shared by GR and RV.
- The batch scripts contain the processing selection.

The Fig. 2b-d and Fig. 3d calculations remain separate because both use
figure-specific habituation bleaching workflows. Fig. 3j GR and Extended Data
Fig. 6a RV share the same processing functions; their differences are defined
in configuration.
