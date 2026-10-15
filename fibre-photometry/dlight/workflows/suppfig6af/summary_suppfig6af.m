%% SUMMARY_SUPPFIG6AF
% Recreate Supplemental Fig. 6a-f from tables generated from raw Parquet.

paths = dlight_paths('suppfig6af');
addpath(fullfile(paths.script_root,'config'));
addpath(fullfile(paths.script_root,'functions'));
cfg = suppfig6af_config();
summarise_suppfig6af_dlight( ...
    paths.suppfig6af_processed_root,paths.suppfig6af_summary_root,cfg);
