%% BATCH_PROCESSING_FIG3D_TEST
clear; clc;

paths = dlight_paths('fig3d');
addpath(paths.script_root);
if isfolder(paths.tdt_sdk_root), addpath(genpath(paths.tdt_sdk_root)); end

subjects = {'032417','032418','032419','032421','032422','032423','032426','035031','035032'};
process_only = subjects;  % e.g. {'032417'} for validation

exp_day = 'test';

for i = 1:numel(subjects)

    animal = subjects{i};

    if ~isempty(process_only) && ~any(strcmp(process_only,animal))
        continue;
    end

    cfg = fig3d_config(animal);

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

    raw_folder = fullfile(paths.raw_root,exp_day,animal);

    if any(strcmpi(cfg.test.bleach_mode,{'hab3_curve','hab3_curve_fixed'}))
        hab3_fit_file = fullfile(paths.hab3_output_root,animal,['hab3_' animal '_fit.mat']);
    else
        hab3_fit_file = '';
    end

    fprintf('\n=== Fig. 3d | test | %s | bleach=%s ===\n', ...
        animal,cfg.test.bleach_mode);

    if ~isfolder(raw_folder)
        fprintf(2,'[ERROR] %s: raw folder not found: %s\n',animal,raw_folder);
        continue;
    end

    if strcmpi(cfg.test.bleach_mode,'hab3_curve') && ~isfile(hab3_fit_file)
        fprintf(2,'[ERROR] %s: new hab3 fit not found: %s\n',animal,hab3_fit_file);
        continue;
    end

    try

        process_fig3d_test_dlight( ...
            'day',exp_day, ...
            'raw_folder',raw_folder, ...
            'subject',animal, ...
            'timestamps',cfg.test.timestamps, ...
            'hab3_fit_file',hab3_fit_file, ...
            'bleach_mode',cfg.test.bleach_mode, ...
            'raw_finish_note',cfg.test.raw_finish_note, ...
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

fprintf('\nFig. 3d test batch complete.\n');
