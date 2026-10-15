%% SUMMARY_SUPPFIG7CD
% Combine Supplemental Fig. 7c-d cADDis data for the RV treatment group.

clear; clc;

sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = caddis_paths('suppfig7cd');
cfg = suppfig7cd_config();

summarise_caddis_dataset( ...
    paths.output_root, paths.summary_root, cfg, ...
    'save_figure', true);

fprintf('\nSupplemental Fig. 7c-d cADDis summary complete.\n');
