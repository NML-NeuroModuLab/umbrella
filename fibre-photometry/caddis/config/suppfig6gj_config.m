function cfg = suppfig6gj_config()
% SUPPFIG6GJ_CONFIG Supplemental Fig. 6g-j cADDis analysis settings.

cfg = caddis_common_config();
cfg.figure = 'suppfig6gj';
cfg.figure_label = 'Supplemental Fig. 6g-j';
cfg.sensor = 'cADDis';
cfg.source_layout = 'raw_streams';
cfg.files.panel_g_raw = 'suppfig6g_caddis_example_raw_038537.csv';
cfg.files.panel_g_corrected = 'suppfig6g_caddis_example_corrected_038537.csv';
cfg.files.panel_h = 'suppfig6h_caddis_465_560_correlations.csv';
cfg.files.panel_i = 'suppfig6i_caddis_sequential_simultaneous.csv';
cfg.files.panel_j = 'suppfig6j_caddis_between_animal_variability.csv';

configRoot = fileparts(mfilename('fullpath'));
cfg.hab3_fit_parameters_file = fullfile(configRoot, ...
    'suppfig6gj_hab3_fit_coefficients.csv');
cfg.hab3_artifact_intervals_file = fullfile(configRoot, ...
    'suppfig6gj_hab3_artifact_intervals.csv');
cfg.sequential_fit_parameters_file = fullfile(configRoot, ...
    'suppfig6gj_sequential_fit_coefficients.csv');
cfg.sequential_artifact_intervals_file = fullfile(configRoot, ...
    'suppfig6gj_sequential_artifact_intervals.csv');
cfg.independent_fit_exclusions_file = fullfile(configRoot, ...
    'suppfig6gj_independent_fit_exclusions.csv');

% 'locked' reproduces the reviewed historical fits. 'refit' regenerates the
% independent bleach fits using the recorded model choices. The Behapy
% simultaneous-fit coefficients remain fixed in both modes.
cfg.independent_fit_mode = 'locked';
cfg.raw_start_sec = 16;
cfg.lowpass_hz = 20;
cfg.target_sample_rate_hz = 100;
% The archived Behapy output has a 15.729-ms interval (~63.6 Hz), which is
% a factor of 16 relative to the exported 1,017-Hz streams.
cfg.behapy_downsample_factor = 16;
cfg.bleach_smooth_samples = 500;
cfg.hab3_slow_window_sec = 30;
cfg.example_slow_window_sec = 60;
cfg.comparison_smooth_window_sec = 60;
cfg.normalisation_window_min = [-15 0];
cfg.correlation_window_min = [0 45];
cfg.variability_window_min = [15 45];
cfg.example_subject = '038537';
cfg.example_raw_time_offset_min = 31;
cfg.example_window_min = [-30 45];
cfg.trace_window_min = [-15 45];
cfg.trace_grid_min = (-15:0.05:45)';
cfg.gr_trace_grid_min = (-15:1/60:45)';
cfg.n_bootstrap = 10000;
cfg.random_seed = 1;

subject = ["038232";"038324";"038326";"038329";"038537"; ...
    "038541";"038543";"038805";"042440";"042441";"042442"; ...
    "042443";"042445"];
cohort = [repmat("CSG018",8,1);repmat("CSG022",5,1)];
baseStart = [1;2.5;2;1;2;1;2;2;1;2;1;2;1];
baseEnd = [31;32.5;32;31;32;31;32;32;31;32;31;32;31];
t1Start = [32;34;33;32;33;32;33;33;32;33;32;33;32];
t1End = [47;49;48;47;48;47;48;48;47;48;47;48;47];
t2Start = [48;50;49;48;49;48;49;48.5;48;49;48;49;48];
t2End = [78;80;79;78;79;78;79;78;78;79;78;79;78];
padShortT2 = [false(7,1);true;false(5,1)];
cfg.hab3_timestamps = table(subject,cohort,baseStart,baseEnd,t1Start, ...
    t1End,t2Start,t2End,padShortT2,'VariableNames', ...
    {'Subject','Cohort','BaseStartMin','BaseEndMin','T1StartMin', ...
    'T1EndMin','T2StartMin','T2EndMin','PadShortT2'});

cfg.panel_i_treatment = 'RG';
cfg.treatment_order = {'VG','RG','GR'};
cfg.treatment_labels = {'VEH -> GBR','RAC -> GBR','GBR -> RAC'};
end
