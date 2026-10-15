%% SUMMARY_SUPPFIG5CF
% Create source-data tables and the Supplemental Fig. 5f summary plot.

clear; clc;
sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
cfg = suppfig5cf_config();
summarise_gcamp_dataset(cfg);
