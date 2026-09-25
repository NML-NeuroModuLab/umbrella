Fig. 3f/k and Extended Data Fig. 6c - ExRaiAKAR2 workflow

Setup
1. Open exrai_paths.m.
2. Set fig3fk_root to the data folder containing raw-data/, processed/, and
   summary/.
3. Set extfig6c_root to the folder where Extended Data Fig. 6c outputs
   should be saved.
4. Set tdt_sdk_root to the folder containing the TDT MATLAB SDK.

Expected raw-data structure
- raw-data/VG/<subject-id>/
- raw-data/RG/<subject-id>/
- raw-data/GR/<subject-id>/
- raw-data/RV/<subject-id>/

All four treatment folders are required. Each animal's VG, RG, and GR traces
are normalized to the peak response from that animal's RV session.

Fig. 3f/k processing order
1. Run batch_processing_fig3fk.m.
2. Run batch_normalisation_fig3fk.m.
3. Run summary_fig3fk.m.

Extended Data Fig. 6c processing order
1. Complete steps 1 and 2 above for the Fig. 3f/k dataset.
2. Run summary_extfig6c.m.

Extended Data Fig. 6c is a 10-minute-bin analysis of the RV sessions from
the same recording set. It therefore reuses the Fig. 3 preprocessing and
RV-normalized files rather than duplicating the full processing pipeline.
Its outputs are saved under:
- <extfig6c_root>/processing/RV_10min/

Configuration
- fig3fk_config.m contains subject IDs, stream assignments, crop timestamps,
  artifact intervals, preprocessing settings, RV normalization settings, and
  the 15-minute analysis intervals.
- exrai_paths.m is the only file that needs local project and TDT SDK paths.
- VG and RG supply the Fig. 3f panels. GR supplies the Fig. 3k panel. RV is
  the within-animal normalization reference.
- extfig6c_config.m contains the Extended Data Fig. 6c 10-minute analysis
  intervals and points to the shared normalized RV files.

Shared functions
- process_exrai_session.m imports TDT data, filters and downsamples the 405,
  465, and optional 560 streams, masks configured artifacts, fits the 405
  reference, calculates dR/R and z(dR/R), and crops the three analysis periods.
- normalise_exrai_to_rv.m applies the historical 30-second moving mean and
  scales each treatment to the same animal's RV peak.
- summarize_fig3fk_exrai.m calculates means and positive, negative, and total
  AUC, exports figure source tables, and creates the Fig. 3f/k figures.
- summarize_extfig6c_exrai.m performs the separate 10-minute RV analysis,
  exports source-data tables, and creates the Extended Data Fig. 6c trace.

Historical migration
The artifact intervals previously collected by artifacts.m are now stored
directly in fig3fk_config.m. The migration utility and its personal archive
paths are therefore not part of the publication workflow.
