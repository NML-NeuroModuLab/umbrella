%% BATCH_PROCESSING_FIG3DG_TEST
clear; clc;

sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
paths = dlight_paths('fig3dg');

subjects = fig3dg_subjects();
process_only = subjects;  % e.g. {'032417'} for validation

exp_day = 'test';

for i = 1:numel(subjects)

    animal = subjects{i};

    if ~isempty(process_only) && ~any(strcmp(process_only,animal))
        continue;
    end

    cfg = fig3dg_config(animal);

    % Safe defaults for optional fixed-curve parameters. These fields are
    % only populated for animals using a fixed historical hab3 pathway.
    fixed_hab3_coeff_405 = [];
    fixed_hab3_coeff_465 = [];

    if isfield(cfg.test,'fixed_hab3_coeff_405')
        fixed_hab3_coeff_405 = cfg.test.fixed_hab3_coeff_405;
    end

    if isfield(cfg.test,'fixed_hab3_coeff_465')
        fixed_hab3_coeff_465 = cfg.test.fixed_hab3_coeff_465;
    end

    data_folder = fullfile(paths.data_root,exp_day,animal);

    if any(strcmpi(cfg.test.bleach_mode,{'hab3_curve','hab3_curve_fixed'}))
        hab3_fit_file = fullfile(paths.hab3_output_root,animal,['hab3_' animal '_fit.mat']);
    else
        hab3_fit_file = '';
    end

    fprintf('\n=== Fig. 3d-g | test | %s | bleach=%s ===\n', ...
        animal,cfg.test.bleach_mode);

    if ~valid_recording_folder(data_folder)
        fprintf(2,'[ERROR] %s: recording files not found: %s\n',animal,data_folder);
        continue;
    end

    if strcmpi(cfg.test.bleach_mode,'hab3_curve') && ~isfile(hab3_fit_file)
        fprintf(2,'[ERROR] %s: new hab3 fit not found: %s\n',animal,hab3_fit_file);
        continue;
    end

    try

        process_fig3dg_test_dlight( ...
            'day',exp_day, ...
            'data_folder',data_folder, ...
            'subject',animal, ...
            'timestamps',cfg.test.timestamps, ...
            'hab3_fit_file',hab3_fit_file, ...
            'bleach_mode',cfg.test.bleach_mode, ...
            'baseline_smooth',cfg.test.baseline_fit_smoothing_window, ...
            'baseline_bleach_target_fs',cfg.test.baseline_bleach_target_fs, ...
            'baseline_bleach_start_point_405',cfg.test.baseline_bleach_start_point_405, ...
            'baseline_bleach_lower_405',cfg.test.baseline_bleach_lower_405, ...
            'baseline_bleach_upper_405',cfg.test.baseline_bleach_upper_405, ...
            'baseline_bleach_start_point_465',cfg.test.baseline_bleach_start_point_465, ...
            'baseline_bleach_lower_465',cfg.test.baseline_bleach_lower_465, ...
            'baseline_bleach_upper_465',cfg.test.baseline_bleach_upper_465, ...
            'bleach_fixed_coeff_405',cfg.test.bleach_fixed_coeff_405, ...
            'bleach_fixed_coeff_465',cfg.test.bleach_fixed_coeff_465, ...
            'fixed_hab3_coeff_405',fixed_hab3_coeff_405, ...
            'fixed_hab3_coeff_465',fixed_hab3_coeff_465, ...
            'output_root',paths.output_root, ...
            'raw_start_s',cfg.raw_start_s, ...
            'lowpass_hz',cfg.lowpass_hz, ...
            'target_fs',cfg.target_fs, ...
            'save_figures',false, ...
            'save_mat',true);

        fprintf('[OK] %s complete.\n',animal);

    catch ME

        fprintf(2,'[ERROR] %s: %s\n',animal,ME.message);

        for k = 1:numel(ME.stack)
            fprintf(2,'  %s (line %d)\n',ME.stack(k).name,ME.stack(k).line);
        end
    end
end

fprintf('\nFig. 3d-g test batch complete.\n');

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
