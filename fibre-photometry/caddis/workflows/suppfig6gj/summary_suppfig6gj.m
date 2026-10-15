%% SUMMARY_SUPPFIG6GJ
% Recreate Supplemental Fig. 6g-j from the generated analysis tables.

paths = caddis_paths('suppfig6gj');
addpath(fullfile(paths.script_root,'config'));
addpath(fullfile(paths.script_root,'functions'));
cfg = suppfig6gj_config();
generatedRoot = fullfile(paths.processing_root,'generated-source-data');
summarise_suppfig6gj_caddis(generatedRoot,paths.summary_root,cfg);
