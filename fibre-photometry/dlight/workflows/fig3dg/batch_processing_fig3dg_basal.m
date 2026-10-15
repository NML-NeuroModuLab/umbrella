%% BATCH_PROCESSING_FIG3DG_BASAL
% Fig. 3d-g basal-fluorescence analysis.

% Input:
%   processed test-day fluorescence output
%
% Output:
%   per-animal basal fluorescence MAT files

clear; clc;

sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = dlight_paths('fig3dg');

source_root = paths.output_root;
output_root = paths.output_root;

subjects = fig3dg_subjects();
process_only = subjects;  % e.g. {'032417'} for validation

day = 'test';

% Historical Fig. 3d smoothing parameter.
smooth_min = 1.0;

for i = 1:numel(subjects)

    animal = subjects{i};
    if ~isempty(process_only) && ~any(strcmp(process_only,animal))
        continue;
    end

    % Locate the processed test output.
    input_mat = find_test_processed_mat(source_root,day,animal);

    fprintf('\n=== Fig. 3d-g | basal | %s ===\n',animal);

    if isempty(input_mat)
        fprintf(2,'[ERROR] %s: processed test output not found.\n',animal);
        continue;
    end

    fprintf('Input: %s\n',input_mat);

    try
        process_basal_fig3dg( ...
            'input_mat',input_mat, ...
            'animal',animal, ...
            'day',day, ...
            'output_root',output_root, ...
            'smooth_min',smooth_min, ...
            'save_figures',false, ...
            'save_mat',true);

    catch ME
        fprintf(2,'[ERROR] %s: %s\n',animal,ME.message);
        for k = 1:numel(ME.stack)
            fprintf(2,'  %s (line %d)\n',ME.stack(k).name,ME.stack(k).line);
        end
    end
end

fprintf('\nFig. 3d-g basal batch complete.\n');

function p = find_test_processed_mat(source_root,day,animal)
% Prefer the new naming convention, but tolerate the historical filename
% while the pipeline is being migrated.

p = '';

outdir = fullfile(source_root,day,animal);

candidates = { ...
    [day,'_',animal,'_processed.mat'], ...
    'data_processed.mat', ...
    [day,'_',animal,'_outputs_a_preprocessing.mat']};

for i = 1:numel(candidates)
    f = fullfile(outdir,candidates{i});
    if isfile(f)
        p = f;
        return;
    end
end

% Fallback: search recursively for a MAT file containing the expected animal.
listing = dir(fullfile(source_root,day,'**','*.mat'));
for i = 1:numel(listing)
    if contains(listing(i).name,animal) || strcmp(listing(i).name,'data_processed.mat')
        p = fullfile(listing(i).folder,listing(i).name);
        return;
    end
end
end
