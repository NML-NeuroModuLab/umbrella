%% SUMMARY_FIG3EH
% Combine the processed Fig. 3e-h cADDis data by treatment group.

clear; clc;
sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = caddis_paths('fig3eh');
cfg = fig3eh_config();
summarise_caddis_dataset(paths.output_root, paths.summary_root, cfg, ...
    'save_figure', true);
fprintf('\nFig. 3e-h cADDis summary complete.\n');
