%% BATCH_PROCESSING_SUPPFIG6KO
% Derive Supplemental Fig. 6k-o from the Fig. 3 ExRaiAKAR2 outputs.

clear; clc;
sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = exrai_paths('suppfig6ko');
cfg = suppfig6ko_config();
generated_root = fullfile(paths.processing_root,'generated-source-data');
process_suppfig6ko_exrai(paths.source_analysis_root,generated_root,cfg);
fprintf('\nSupplemental Fig. 6k-o ExRaiAKAR2 processing complete.\n');
