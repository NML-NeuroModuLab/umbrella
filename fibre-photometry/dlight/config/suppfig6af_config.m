function cfg = suppfig6af_config()
% SUPPFIG6AF_CONFIG  Supplemental Fig. 6a-f raw-data processing settings.

cfg.figure = 'suppfig6af';
cfg.figure_label = 'Supplemental Fig. 6a-f';
cfg.sensor = 'dLight';

cfg.cohort1_subjects = {'032417','032418','032419','032421','032422', ...
    '032423','032426','035031','035032'};
cfg.cohort2_subjects = {'043897','043898','043899'};
cfg.cohort3_subjects = {'055619','055620','055621','056125','055625'};

cfg.lowpass_hz = 20;
cfg.target_fs = 100;
cfg.slow_smoothing_window = 5000;
cfg.fit_windows_min = [10 30 Inf];
cfg.fit_window_labels = {'10 min','30 min','Full trace'};
cfg.fit_stride = 100;
cfg.fit_comparison_duration_min = 60;
cfg.fit_window_start_crop_035031_min = 4;

% The manuscript fit-window comparison used reviewed/customised nonlinear
% fits. "locked" reproduces those fits from the coefficients supplied with
% the code. Change this to "refit" to regenerate all 10-min, 30-min and
% full-trace fits from the Parquet recordings using the settings above.
configRoot = fileparts(mfilename('fullpath'));
cfg.fit_window_mode = 'locked';
cfg.fit_window_coefficients_file = fullfile(configRoot, ...
    'suppfig6af_fit_coefficients.csv');
cfg.example_fit_coefficients_file = fullfile(configRoot, ...
    'suppfig6af_example_fit_coefficients.csv');
cfg.bleach_fit_coefficients_file = fullfile(configRoot, ...
    'suppfig6af_bleach_fit_coefficients.csv');

% Exact reviewed exclusions recovered from the historical cohort-3 fits.
% Times are minutes from recording start. End intervals may extend beyond
% the available stream and are intentionally retained as originally saved.
cfg.cohort3_artifact_intervals.x055619 = [ ...
    19.5276497695853 21.3709677419355; ...
    22.9838709677419 24.8271889400922; ...
    52.2465437788019 53.6290322580645; ...
    89.1129032258065 98.0990783410138];
cfg.cohort3_artifact_intervals.x055620 = [ ...
    78.2834101382488 91.6474654377880];
cfg.cohort3_artifact_intervals.x055621 = zeros(0,2);
cfg.cohort3_artifact_intervals.x055625 = [ ...
    0.155529953917053 3.88824884792627; ...
    85.3859447004609 89.1186635944701];
cfg.cohort3_artifact_intervals.x056125 = [ ...
    83.5195852534562 85.5933179723502];

% Historical recording endpoints recovered from the saved fit files. These
% prevent a later, longer export from changing the published analysis.
cfg.cohort2_recording_end_min.x043897 = 124.116612685;
cfg.cohort2_recording_end_min.x043898 = 130.549953997;
cfg.cohort2_recording_end_min.x043899 = 125.050009147;
cfg.cohort3_recording_end_min.x055619 = 90.3725037925499;
cfg.cohort3_recording_end_min.x055620 = 90.3725037925499;
cfg.cohort3_recording_end_min.x055621 = 84.7123234257535;
cfg.cohort3_recording_end_min.x055625 = 86.8030856239383;
cfg.cohort3_recording_end_min.x056125 = 84.7123234257535;

cfg.panel_ab_subject = '055621';
cfg.panel_d_subject = '035032';
cfg.panel_f_subject = '032422';
cfg.panel_f_injection1_min = 11;

cfg.files.panel_ab = 'suppfig6ab_dlight_example_055621.csv';
cfg.files.panel_c = 'suppfig6c_dlight_rmse.csv';
cfg.files.panel_d = 'suppfig6d_dlight_fit_windows_035032.csv';
cfg.files.panel_e = 'suppfig6e_dlight_fit_window_comparison.csv';
cfg.files.panel_f = 'suppfig6f_dlight_test_workflow_032422.csv';
cfg.files.fit_coefficients = 'suppfig6af_fit_coefficients_used.csv';
cfg.files.bleach_coefficients = 'suppfig6af_bleach_coefficients_used.csv';

cfg.panel_ab_window_min = [35 55];
cfg.panel_d_window_min = [0 60];
cfg.panel_f_window_min = [-10 30];
end
