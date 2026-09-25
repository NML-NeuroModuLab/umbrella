%% SUMMARY_FIG3FK
% Generate the Fig. 3f and Fig. 3k ExRaiAKAR2 source tables and figures.

clear; clc;

script_root = fileparts(mfilename('fullpath'));
addpath(script_root);
paths = exrai_paths('fig3fk');
cfg = fig3fk_config(paths.project_root);

summarize_fig3fk_exrai(cfg);
