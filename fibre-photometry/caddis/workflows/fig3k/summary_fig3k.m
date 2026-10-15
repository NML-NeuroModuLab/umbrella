%% SUMMARY_FIG3K
% Combine the processed Fig. 3k cADDis data for the GR treatment group.

clear; clc;

sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = caddis_paths('fig3k');
cfg = fig3k_config();

summarise_caddis_dataset( ...
    paths.output_root, paths.summary_root, cfg, ...
    'save_figure', true);

fprintf('\nFig. 3k cADDis summary complete.\n');
