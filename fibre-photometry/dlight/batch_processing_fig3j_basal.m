%% BATCH_PROCESSING_FIG3J_BASAL
% Batch 15-minute basal analysis for Fig. 3j GR.

clear; clc;

paths = dlight_paths('fig3j');
addpath(paths.script_root);

subjects = gr_rv_subjects();
process_only = subjects;  % e.g. {'055619'} for validation

for i = 1:numel(subjects)
    animal = subjects{i};
    if ~isempty(process_only) && ~any(strcmp(process_only,animal))
        continue;
    end

    input_file = fullfile(paths.gr_output_root,animal, ...
        ['GR_' animal '_processed.mat']);
    cfg = fig3j_config(animal);

    fprintf('\n=== Fig. 3j | GR basal | %s ===\n',animal);

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
            'output_root',paths.gr_basal_root, ...
            'smooth_min',cfg.smooth_min, ...
            'analysis_intervals',cfg.analysis_intervals, ...
            'mean_intervals',cfg.mean_intervals, ...
            'analysis_labels',cfg.analysis_labels);
    catch ME
        fprintf(2,'[ERROR] GR basal %s: %s\n',animal,ME.message);
        for k = 1:numel(ME.stack)
            fprintf(2,'  %s (line %d)\n',ME.stack(k).name,ME.stack(k).line);
        end
    end
end

fprintf('\nFig. 3j GR basal batch complete.\n');
