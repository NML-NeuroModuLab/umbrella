%% BATCH_PROCESSING_EXTFIG6A
% Batch preprocessing for the five Extended Data Fig. 6a RV recordings.

clear; clc;

paths = dlight_paths('extfig6a');
addpath(paths.script_root);
if isfolder(paths.tdt_sdk_root), addpath(genpath(paths.tdt_sdk_root)); end

subjects = gr_rv_subjects();
process_only = subjects;  % e.g. {'055619'} for validation

for i = 1:numel(subjects)
    animal = subjects{i};
    if ~isempty(process_only) && ~any(strcmp(process_only,animal))
        continue;
    end

    cfg = extfig6a_config(animal);
    raw_folder = fullfile(paths.raw_root,'RV',animal);

    fprintf('\n=== Extended Data Fig. 6a | RV | %s ===\n',animal);
    fprintf('Raw folder: %s\n',raw_folder);

    if ~isfolder(raw_folder)
        fprintf(2,'[ERROR] %s: raw folder not found.\n',animal);
        continue;
    end

    try
        process_gr_rv_dlight( ...
            'raw_folder',raw_folder, ...
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

fprintf('\nExtended Data Fig. 6a RV preprocessing complete.\n');
