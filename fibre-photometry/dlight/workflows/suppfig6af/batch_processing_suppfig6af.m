%% BATCH_PROCESSING_SUPPFIG6AF
% Derive Supplemental Fig. 6a-f plotted values from raw Parquet recordings.

clear; clc;

sensorRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
photometryRoot = fileparts(sensorRoot);
addpath(sensorRoot);
addpath(fullfile(sensorRoot,'config'));
addpath(fullfile(sensorRoot,'functions'));
addpath(fullfile(photometryRoot,'functions'));

paths = dlight_paths('suppfig6af');
cfg = suppfig6af_config();
% For exploratory/custom fitting, uncomment the following line. The default
% locked mode reproduces the reviewed manuscript fits.
% cfg.fit_window_mode = 'refit';
process_suppfig6af_dlight(paths,cfg);
