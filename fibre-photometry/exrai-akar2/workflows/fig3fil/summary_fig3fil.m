%% SUMMARY_FIG3FIL
% Generate source tables and figures for Fig. 3f, 3i, and 3l.

clear; clc;

sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = exrai_paths('fig3fil');
cfg = fig3fil_config(paths.project_root,paths.analysis_root);

summarise_fig3fil_exrai(cfg);
