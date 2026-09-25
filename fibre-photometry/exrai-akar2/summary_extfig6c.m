%% SUMMARY_EXTFIG6C
% Generate the Extended Data Fig. 6c ExRaiAKAR2 tables and trace figure.

clear; clc;

script_root = fileparts(mfilename('fullpath'));
addpath(script_root);
paths = exrai_paths('extfig6c');
cfg = extfig6c_config(paths.source_project_root,paths.project_root);

summarize_extfig6c_exrai(cfg);
