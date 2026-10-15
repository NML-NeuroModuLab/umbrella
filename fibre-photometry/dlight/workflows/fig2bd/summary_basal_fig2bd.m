%% SUMMARY_BASAL_FIG2BD
% Run the Fig. 2b-d table, source-data and trace summary.

clear; clc;

sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = dlight_paths('fig2bd');
summarise_fig2bd( ...
    'subjects',fig2bd_subjects(), ...
    'conditions',fig2bd_conditions(), ...
    'basal_root',paths.fig2bd_basal_root, ...
    'summary_root',paths.fig2bd_summary_root);
