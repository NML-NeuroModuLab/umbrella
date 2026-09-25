function cfg = fig3d_config(animal)
% FIG3D_CONFIG  Configuration for the Fig. 3d dLight analysis.
%
% Usage:
%   cfg = fig3d_config('032417');
%
% Test-day bleaching modes:
%   most animals:      'hab3_curve'
%   032417/032419/032421: 'baseline_double_exp'
%

animal = char(string(animal));

%% Shared settings
cfg.figure = 'fig3d';
cfg.figure_label = 'Fig. 3d';
cfg.sensor = 'dLight';

cfg.raw_start_s = 16;
cfg.lowpass_hz = 20;       % used for the hab3-curve pathway
cfg.target_fs = 100;       % used for the hab3-curve pathway

cfg.signal_channel = '465';
cfg.reference_channel = '405';
cfg.fit_method = 'linear_polyfit';

cfg.fpx_time_start_min = -10;
cfg.fpx_time_end_min = 30;

%% Hab3 defaults
cfg.hab3.timestamps.baseline = [1 11];
cfg.hab3.timestamps.t1 = [12 27];
cfg.hab3.timestamps.t2 = [28 43];
cfg.hab3.raw_finish_note = 6;
cfg.hab3.bleach_smoothing_method = 'movmin';
cfg.hab3.bleach_smoothing_window = 5000;
cfg.hab3.bleach_fit_start_idx = 10;
cfg.hab3.bleach_fit_end_trim_idx = 6000;
cfg.hab3.start_point_405 = [450 -0.003 30 -0.3];
cfg.hab3.start_point_465 = [400 -0.003 30 -0.3];
cfg.hab3.baseline_fit_smoothing_method = 'movmedian';
cfg.hab3.baseline_fit_smoothing_window = 5000;
cfg.hab3.baseline_fit_start_offset = 0;

%% Test defaults
cfg.test.timestamps.baseline = [1 11];
cfg.test.timestamps.t1 = [12 27];
cfg.test.timestamps.t2 = [28 43];
cfg.test.bleach_mode = 'hab3_curve';
cfg.test.bleach_fixed_coeff_405 = [];
cfg.test.bleach_fixed_coeff_465 = [];
cfg.test.raw_finish_note = 6;
cfg.test.baseline_fit_smoothing_window = 5000;

% Archived baseline-derived bleach fallback defaults.
cfg.test.baseline_bleach_target_fs = 60;
cfg.test.baseline_bleach_fit_smoothing_window = 5000;
cfg.test.baseline_bleach_model = 'double_exponential';
cfg.test.baseline_bleach_start_point_405 = [500 -0.001 90 -0.2];
cfg.test.baseline_bleach_start_point_465 = [500 -0.001 90 -0.2];
cfg.test.baseline_bleach_lower_405 = [-Inf -Inf -Inf -Inf];
cfg.test.baseline_bleach_upper_405 = [Inf Inf Inf Inf];
cfg.test.baseline_bleach_lower_465 = [-Inf -Inf -Inf -Inf];
cfg.test.baseline_bleach_upper_465 = [Inf Inf Inf Inf];

%% Animal-specific settings
switch animal

    case '032417'
        cfg.hab3.raw_finish_note = 6;
        cfg.hab3.bleach_smoothing_method = 'movmedian';
        cfg.hab3.bleach_fit_start_idx = 60;
        cfg.hab3.bleach_fit_end_trim_idx = 6000;
        cfg.hab3.start_point_465 = [650 -0.003 30 -0.3];
        cfg.hab3.start_point_405 = [600 -0.003 30 -0.3];
        cfg.hab3.baseline_fit_smoothing_method = 'none';

        cfg.test.raw_finish_note = 8;
        cfg.test.bleach_mode = 'none';
        cfg.test.baseline_bleach_start_point_465 = [500 -0.001 90 -0.2];
        cfg.test.baseline_bleach_lower_465 = [100 -Inf 42 -Inf];
        cfg.test.baseline_bleach_upper_465 = [Inf -0.0001 70 Inf];
        cfg.test.baseline_bleach_start_point_405 = [500 -0.001 90 -0.2];
        cfg.test.baseline_bleach_lower_405 = [-Inf -Inf -Inf -Inf];
        cfg.test.baseline_bleach_upper_405 = [550 Inf Inf Inf];

    case '032418'
        cfg.hab3.timestamps.baseline = [2 12];
        cfg.hab3.timestamps.t1 = [13 28];
        cfg.hab3.timestamps.t2 = [28.6 43.6];
        cfg.hab3.raw_finish_note = 6;
        cfg.hab3.bleach_smoothing_method = 'movmin';
        cfg.hab3.bleach_fit_start_idx = 60;
        cfg.hab3.bleach_fit_end_trim_idx = 6000;
        cfg.hab3.start_point_465 = [600 -0.003 30 -0.3];
        cfg.hab3.start_point_405 = [500 -0.003 30 -0.3];
        cfg.hab3.baseline_fit_smoothing_window = 500;

    case '032419'
        cfg.hab3.timestamps.t2 = [27.7 42.7];
        cfg.hab3.raw_finish_note = 7;
        cfg.hab3.bleach_smoothing_method = 'movmedian';
        cfg.hab3.bleach_fit_start_idx = 60;
        cfg.hab3.bleach_fit_end_trim_idx = 600;
        cfg.hab3.start_point_465 = [400 -0.003 30 -0.3];
        cfg.hab3.start_point_405 = [450 -0.003 30 -0.3];

        cfg.test.raw_finish_note = 6;
        cfg.test.bleach_mode = 'none';
        cfg.test.baseline_bleach_start_point_465 = [500 -0.001 90 -0.2];
        cfg.test.baseline_bleach_lower_465 = [-Inf -0.005 -Inf -Inf];
        cfg.test.baseline_bleach_upper_465 = [Inf Inf Inf Inf];
        cfg.test.baseline_bleach_start_point_405 = [500 -0.001 90 -0.2];
        cfg.test.baseline_bleach_lower_405 = [-Inf -0.0055 95 -Inf];
        cfg.test.baseline_bleach_upper_405 = [Inf -0.0001 Inf -0.8];

    case '032421'
        cfg.hab3.raw_finish_note = 6;
        cfg.hab3.bleach_smoothing_method = 'movmin';
        cfg.hab3.bleach_fit_start_idx = 10;
        cfg.hab3.bleach_fit_end_trim_idx = 6000;
        cfg.hab3.start_point_465 = [400 -0.003 30 -0.3];
        cfg.hab3.start_point_405 = [450 -0.003 30 -0.3];

        cfg.test.raw_finish_note = 6;
        cfg.test.bleach_mode = 'none';
        cfg.test.baseline_bleach_start_point_465 = [500 -0.001 90 -0.2];
        cfg.test.baseline_bleach_lower_465 = [100 -0.04 -Inf -Inf];
        cfg.test.baseline_bleach_upper_465 = [Inf Inf 83 Inf];
        cfg.test.baseline_bleach_start_point_405 = [500 -0.001 90 -0.2];
        cfg.test.baseline_bleach_lower_405 = [200 -0.01 40 -Inf];
        cfg.test.baseline_bleach_upper_405 = [550 -0.002 Inf Inf];
        cfg.test.timestamps.t2 = [27.7 42.7];

    case '032422'
        cfg.hab3.timestamps.t2 = [27.7 42.7];
        cfg.test.timestamps.t2 = [27.6 42.6];
        cfg.hab3.raw_finish_note = 6;
        cfg.hab3.bleach_smoothing_method = 'movmin';
        cfg.hab3.bleach_fit_start_idx = 10;
        cfg.hab3.bleach_fit_end_trim_idx = 6000;
        cfg.hab3.start_point_465 = [400 -0.003 30 -0.3];
        cfg.hab3.start_point_405 = [450 -0.003 30 -0.3];
        cfg.hab3.baseline_fit_start_offset = 12000;

    case '032423'
        cfg.hab3.timestamps.t2 = [30.5 45.5];
        cfg.test.timestamps.t2 = [27.5 42.5];
        cfg.hab3.raw_finish_note = 6;
        cfg.hab3.bleach_smoothing_method = 'movmin';
        cfg.hab3.bleach_fit_start_idx = 10;
        cfg.hab3.bleach_fit_end_trim_idx = 6000;
        cfg.hab3.start_point_465 = [400 -0.003 30 -0.3];
        cfg.hab3.start_point_405 = [450 -0.003 30 -0.3];
        cfg.test.baseline_fit_smoothing_window = 500;

    case '032426'
        cfg.test.timestamps.t2 = [27.7 42.7];
        cfg.hab3.raw_finish_note = 6;
        cfg.hab3.bleach_smoothing_method = 'movmin';
        cfg.hab3.bleach_fit_start_idx = 10;
        cfg.hab3.bleach_fit_end_trim_idx = 6000;
        cfg.hab3.start_point_465 = [500 -0.003 30 -0.3];
        cfg.hab3.start_point_405 = [550 -0.003 30 -0.3];

    case '035031'
        cfg.hab3.timestamps.baseline = [2 12];
        cfg.hab3.timestamps.t1 = [13 28];
        cfg.hab3.timestamps.t2 = [29 44];
        cfg.test.timestamps.baseline = [1.5 11.5];
        cfg.test.timestamps.t1 = [13 28];
        cfg.test.timestamps.t2 = [29 44];
        cfg.hab3.raw_finish_note = 7;
        cfg.hab3.bleach_smoothing_method = 'movmin';
        cfg.hab3.bleach_fit_start_idx = 6000;
        cfg.hab3.bleach_fit_end_trim_idx = 6000;
        cfg.hab3.start_point_465 = [400 -0.003 30 -0.3];
        cfg.hab3.start_point_405 = [450 -0.003 30 -0.3];

    case '035032'
        cfg.hab3.raw_finish_note = 6;
        cfg.hab3.bleach_smoothing_method = 'movmin';
        cfg.hab3.bleach_fit_start_idx = 6000;
        cfg.hab3.bleach_fit_end_trim_idx = 6000;
        cfg.hab3.start_point_465 = [500 -0.003 30 -0.3];
        cfg.hab3.start_point_405 = [650 -0.003 30 -0.3];

    otherwise
        error('No Fig. 3d configuration found for animal %s.',animal);
end
end
