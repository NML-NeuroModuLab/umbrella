function cfg = fig3k_config()
% FIG3K_CONFIG  Experimental settings for the Fig. 3k cADDis analysis.
%
% Crop timestamps were transcribed from time-stamps.xlsx. Times are in
% minutes relative to the start of each raw recording. The extra timestamp
% fields are retained for provenance even though the original crop joined
% only the baseline, T1, and T2 periods.

cfg = caddis_common_config();
cfg.figure = 'fig3k';
cfg.figure_label = 'Fig. 3k';
cfg.sensor = 'cADDis';

%% Subject-level crop timestamps and treatment assignments
subject = ["042442"; "042443"; "042440"; "042441"; "042445"];
treatment = repmat("GR", size(subject));

base_start = [1; 2; 1; 2; 4];
base_end = [31; 32; 31; 32; 34];
t1_start = [31.8; 32.5; 31.6; 32.8; 34.4];
t1_end = [46.8; 47.5; 46.6; 47.8; 49.4];
t2_start = [47.5; 48.4; 47.5; 48.5; 50.4];
t2_end = [77.5; 78.4; 77.5; 78.5; 80.4];
t2_extra = [107.5; 108.4; 107.5; 108.5; 110.4];
t3_start = [93.9; 94.5; 93.5; 94.8; 97];
t3_end = [123.9; 124.5; 123.5; 124.8; 127];

cfg.crop_timestamps = table( ...
    subject, treatment, base_start, base_end, t1_start, t1_end, ...
    t2_start, t2_end, t2_extra, t3_start, t3_end, ...
    'VariableNames', { ...
    'Subject', 'Treatment', 'BaseStartMin', 'BaseEndMin', ...
    'T1StartMin', 'T1EndMin', 'T2StartMin', 'T2EndMin', ...
    'T2ExtraMin', 'T3StartMin', 'T3EndMin'});

cfg.subjects = cellstr(subject);
cfg.summary_mapping = cfg.crop_timestamps(:, {'Subject', 'Treatment'});
cfg.treatment_order = {'GR'};

%% Figure-specific analysis settings
cfg.auc_intervals_min = [ ...
    -14.9, 0; ...
      0.1, 15; ...
     15.1, 30; ...
     30.1, 45];
cfg.auc_labels = {'Baseline', 'T1', 'T2', 'T2b'};

cfg.summary_x_limits_min = [-10, 45];
cfg.summary_y_limits = [-5, 3];
end
