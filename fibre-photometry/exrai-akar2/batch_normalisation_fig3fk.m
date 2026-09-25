%% BATCH_NORMALISATION_FIG3FK
% Normalize all Fig. 3f/k treatment traces to each animal's RV peak.

clear; clc;

script_root = fileparts(mfilename('fullpath'));
addpath(script_root);
paths = exrai_paths('fig3fk');
cfg = fig3fk_config(paths.project_root);

normalise_exrai_to_rv(cfg,'save_figures',true);
