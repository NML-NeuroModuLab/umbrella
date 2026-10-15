%% BATCH_PROCESSING_SUPPFIG6GJ
% Derive Supplemental Fig. 6g-j from the shared raw recordings.

clear; clc;
sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = caddis_paths('suppfig6gj');
cfg = suppfig6gj_config();
process_suppfig6gj_caddis(paths,cfg);
fprintf('\nSupplemental Fig. 6g-j cADDis processing complete.\n');
