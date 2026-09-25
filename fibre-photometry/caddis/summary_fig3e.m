%% SUMMARY_FIG3E
% Combine the processed Fig. 3e cADDis data by treatment group.

clear; clc;

script_root = fileparts(mfilename('fullpath'));
addpath(script_root);
paths = caddis_paths('fig3e');
cfg = fig3e_config();

summarize_caddis_dataset( ...
    paths.output_root, paths.summary_root, cfg, ...
    'save_figure', true);

fprintf('\nFig. 3e cADDis summary complete.\n');
