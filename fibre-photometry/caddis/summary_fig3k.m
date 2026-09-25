%% SUMMARY_FIG3K
% Combine the processed Fig. 3k cADDis data for the GR treatment group.

clear; clc;

script_root = fileparts(mfilename('fullpath'));
addpath(script_root);
paths = caddis_paths('fig3k');
cfg = fig3k_config();

summarize_caddis_dataset( ...
    paths.output_root, paths.summary_root, cfg, ...
    'save_figure', true);

fprintf('\nFig. 3k cADDis summary complete.\n');
