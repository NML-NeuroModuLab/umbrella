%% SUMMARY_EXTFIG6CD
% Combine Extended Data Fig. 6c-d cADDis data for the RV treatment group.

clear; clc;

script_root = fileparts(mfilename('fullpath'));
addpath(script_root);
paths = caddis_paths('extfig6cd');
cfg = extfig6cd_config();

summarize_caddis_dataset( ...
    paths.output_root, paths.summary_root, cfg, ...
    'save_figure', true);

fprintf('\nExtended Data Fig. 6c-d cADDis summary complete.\n');
