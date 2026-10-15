%% SUMMARY_SUPPFIG6KO
% Recreate Supplemental Fig. 6k-o from the generated analysis tables.

clear; clc;
sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = exrai_paths('suppfig6ko');
cfg = suppfig6ko_config();
generated_root = fullfile(paths.processing_root,'generated-source-data');
summarise_suppfig6ko_exrai(generated_root,paths.summary_root,cfg);
