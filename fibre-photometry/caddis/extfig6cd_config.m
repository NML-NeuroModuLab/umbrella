function cfg = extfig6cd_config()
% EXTFIG6CD_CONFIG  Settings for Extended Data Fig. 6c-d cADDis analysis.
%
% Crop timestamps were transcribed from time-stamps.xlsx. Times are in
% minutes relative to the start of each raw recording. Both spreadsheet
% entries for subject 042443 are retained; UseForCrop records which entry
% the original lookup selected.

cfg = caddis_common_config();
cfg.figure = 'extfig6cd';
cfg.figure_label = 'Extended Data Fig. 6c-d';
cfg.sensor = 'cADDis';

%% Subject-level crop timestamps
session_key = [ ...
    "test-042443"; ...
    "test-042440"; ...
    "test-042441"; ...
    "test-042442"; ...
    "test0-042443"; ...
    "test-042445"];
subject = ["042443"; "042440"; "042441"; "042442"; "042443"; "042445"];
treatment = repmat("RV", size(subject));
use_for_crop = [true; true; true; true; false; true];

base_start = [2; 1; 2; 1; 2; 2];
base_end = [32; 31; 32; 31; 32; 32];
t1_start = [32.5; 31.4; 32.4; 31.4; 32.3; 32.5];
t1_end = [47.5; 46.4; 47.4; 46.4; 47.3; 47.5];
t2_start = [49.5; 47.5; 48.6; 47.6; 48.5; 50.2];
t2_end = [79.5; 77.5; 78.6; 77.6; 78.5; 80.2];
t2_extra = [109.5; 107.5; 108.6; 107.6; 108.5; 110.2];
t3_start = [95.6; 94.2; 94.7; 95.2; 95.5; 98.1];
t3_end = [125.6; 124.2; 124.7; 125.2; 125.5; 128.1];

cfg.crop_timestamps = table( ...
    session_key, subject, treatment, use_for_crop, ...
    base_start, base_end, t1_start, t1_end, t2_start, t2_end, ...
    t2_extra, t3_start, t3_end, ...
    'VariableNames', { ...
    'SessionKey', 'Subject', 'Treatment', 'UseForCrop', ...
    'BaseStartMin', 'BaseEndMin', 'T1StartMin', 'T1EndMin', ...
    'T2StartMin', 'T2EndMin', 'T2ExtraMin', 'T3StartMin', 'T3EndMin'});

summary_subject = ["042440"; "042441"; "042442"; "042443"; "042445"];
summary_treatment = repmat("RV", size(summary_subject));
cfg.subjects = cellstr(summary_subject);
cfg.summary_mapping = table(summary_subject, summary_treatment, ...
    'VariableNames', {'Subject', 'Treatment'});
cfg.treatment_order = {'RV'};

%% Figure-specific analysis settings
cfg.auc_intervals_min = [ ...
    -9.9, 0; ...
     0.1, 10; ...
    10.1, 20; ...
    20.1, 30];
cfg.auc_labels = {'Baseline', 'T1a', 'T1b', 'T1c'};

cfg.section_mean_intervals_min = [-10, 0; 0, 10; 10, 20; 20, 30];
cfg.section_mean_labels = {'Baseline', 'T1a', 'T1b', 'T1c'};

cfg.summary_x_limits_min = [-10, 30];
cfg.summary_y_limits = [-6, 2];
end
