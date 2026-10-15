%% BATCH_PROCESSING_FIG3J
% Batch preprocessing for the five Fig. 3j GR recordings.

clear; clc;

sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = dlight_paths('fig3j');

subjects = gr_rv_subjects();
process_only = subjects;  % e.g. {'055619'} for validation

for i = 1:numel(subjects)
    animal = subjects{i};
    if ~isempty(process_only) && ~any(strcmp(process_only,animal))
        continue;
    end

    cfg = fig3j_config(animal);
    data_folder = fullfile(paths.data_root,'GR',animal);

    fprintf('\n=== Fig. 3j | GR | %s ===\n',animal);
    fprintf('Data folder: %s\n',data_folder);

    if ~valid_recording_folder(data_folder)
        fprintf(2,'[ERROR] %s: recording files not found.\n',animal);
        continue;
    end

    try
        process_gr_rv_dlight( ...
            'data_folder',data_folder, ...
            'animal',animal, ...
            'group',cfg.group, ...
            'figure',cfg.figure, ...
            'signal_stream',cfg.signal_stream, ...
            'reference_stream',cfg.reference_stream, ...
            'timestamps',cfg.timestamps, ...
            'artifact_ranges',cfg.artifact_ranges, ...
            'artifact_policy',cfg.artifact_policy, ...
            'lowpass_hz',cfg.lowpass_hz, ...
            'target_fs',cfg.target_fs, ...
            'canonical_xlim',cfg.canonical_xlim, ...
            'output_root',paths.gr_output_root);
        fprintf('[OK] %s complete.\n',animal);
    catch ME
        fprintf(2,'[ERROR] GR %s: %s\n',animal,ME.message);
        for k = 1:numel(ME.stack)
            fprintf(2,'  %s (line %d)\n',ME.stack(k).name,ME.stack(k).line);
        end
    end
end

fprintf('\nFig. 3j GR preprocessing complete.\n');

function tf = valid_recording_folder(folder)
if ~isfolder(folder)
    tf = false;
    return;
end
[~,subject] = fileparts(folder);
prefix = ['sub-' subject '_'];
tf = isfile(fullfile(folder,[prefix 'photometry.parquet'])) && ...
    isfile(fullfile(folder,[prefix 'notes.csv'])) && ...
    isfile(fullfile(folder,[prefix 'metadata.json']));
end
