%% BATCH_PROCESSING_SUPPFIG7AB
% Batch preprocessing for the five Supplemental Fig. 7a-b RV recordings.

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
    % The shared archive currently calls this folder "rv". Resolve it
    % case-insensitively so the workflow also works after extraction on a
    % case-sensitive filesystem.
    data_folder = fullfile(resolve_group_folder(paths.data_root,'RV'),animal);

    fprintf('\n=== Supplemental Fig. 7a-b | RV | %s ===\n',animal);
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
            'output_root',paths.rv_output_root);
        fprintf('[OK] %s complete.\n',animal);
    catch ME
        fprintf(2,'[ERROR] RV %s: %s\n',animal,ME.message);
        for k = 1:numel(ME.stack)
            fprintf(2,'  %s (line %d)\n',ME.stack(k).name,ME.stack(k).line);
        end
    end
end

fprintf('\nSupplemental Fig. 7a-b RV preprocessing complete.\n');

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

function folder = resolve_group_folder(root,group)
entries = dir(root);
matches = entries([entries.isdir] & strcmpi({entries.name},group));
if isempty(matches)
    % Preserve the normal missing-recording message when the source package
    % is incomplete, rather than failing while constructing the path.
    folder = fullfile(root,group);
else
    folder = fullfile(root,matches(1).name);
end
end
