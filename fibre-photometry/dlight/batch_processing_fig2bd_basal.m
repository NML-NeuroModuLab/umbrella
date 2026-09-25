%% BATCH_PROCESSING_FIG2BD_BASAL
% Prepare smoothed traces and historical summaries for Fig. 2b-d.

clear; clc;

paths = dlight_paths('fig2bd');
subjects = fig2bd_subjects();
conditions = fig2bd_conditions();
process_only_animals = subjects;
process_only_conditions = conditions;

for c = 1:numel(conditions)
    condition = conditions{c};
    if ~isempty(process_only_conditions) && ...
            ~any(strcmp(process_only_conditions,condition))
        continue;
    end

    for i = 1:numel(subjects)
        animal = subjects{i};
        if ~isempty(process_only_animals) && ...
                ~any(strcmp(process_only_animals,animal))
            continue;
        end

        if strcmpi(condition,'hab3')
            file_name = ['hab3_' animal '_processed.mat'];
        else
            file_name = ['test_' condition '_' animal '_processed.mat'];
        end
        input_file = fullfile( ...
            paths.fig2bd_output_root,condition,animal,file_name);
        fprintf('\n=== Fig. 2b-d | basal | %s | %s ===\n',condition,animal);

        if ~isfile(input_file)
            fprintf(2,'[ERROR] Input file not found: %s\n',input_file);
            continue;
        end

        try
            process_basal_fig2bd( ...
                'input_file',input_file, ...
                'animal',animal, ...
                'condition',condition, ...
                'output_root',paths.fig2bd_basal_root, ...
                'smooth_window',3600, ...
                'save_figure',false);
        catch ME
            fprintf(2,'[ERROR] %s | %s: %s\n', ...
                condition,animal,ME.message);
        end
    end
end

fprintf('\nFig. 2b-d basal processing complete.\n');
