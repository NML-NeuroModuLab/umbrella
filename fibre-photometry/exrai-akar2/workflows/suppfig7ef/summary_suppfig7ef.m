%% SUMMARY_SUPPFIG7EF
% Generate source tables and figures for Supplemental Fig. 7e-f.

clear; clc;

sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = exrai_paths('suppfig7ef');
cfg = suppfig7ef_config(paths.source_project_root,paths.project_root, ...
    paths.source_analysis_root);

summarise_suppfig7ef_exrai(cfg);
