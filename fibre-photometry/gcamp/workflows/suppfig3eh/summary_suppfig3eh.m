%% SUMMARY_SUPPFIG3EH
% Create source-data tables and the Supplemental Fig. 3h summary plot.

clear; clc;
sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
cfg = suppfig3eh_config();
summarise_gcamp_dataset(cfg);
