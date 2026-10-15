%% BATCH_PROCESSING_SUPPFIG7AB_BASAL
% Batch 10-minute basal analysis for Supplemental Fig. 7a-b RV.

clear; clc;

sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = dlight_paths('suppfig7ab');

subjects = gr_rv_subjects();
process_only = subjects;  % e.g. {'055619'} for validation

for i = 1:numel(subjects)
    animal = subjects{i};
    if ~isempty(process_only) && ~any(strcmp(process_only,animal))
        continue;
    end

    cfg = suppfig7ab_config(animal);
    input_file = fullfile(paths.rv_output_root,animal, ...
        ['RV_' animal '_processed.mat']);

    fprintf('\n=== Supplemental Fig. 7a-b | RV basal | %s ===\n',animal);

    if ~isfile(input_file)
        fprintf(2,'[ERROR] %s: processed input not found.\n',animal);
        continue;
    end

    try
        process_basal_gr_rv( ...
            'animal',animal, ...
            'group',cfg.group, ...
            'figure',cfg.figure, ...
            'input_file',input_file, ...
            'output_root',paths.rv_basal_root, ...
            'smooth_min',cfg.smooth_min, ...
            'analysis_intervals',cfg.analysis_intervals, ...
            'mean_intervals',cfg.mean_intervals, ...
            'analysis_labels',cfg.analysis_labels);
    catch ME
        fprintf(2,'[ERROR] RV basal %s: %s\n',animal,ME.message);
        for k = 1:numel(ME.stack)
            fprintf(2,'  %s (line %d)\n',ME.stack(k).name,ME.stack(k).line);
        end
    end
end

fprintf('\nSupplemental Fig. 7a-b RV basal batch complete.\n');
