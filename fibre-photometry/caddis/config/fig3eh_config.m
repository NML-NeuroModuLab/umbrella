function cfg = fig3eh_config()
% FIG3EH_CONFIG Experimental settings for the Fig. 3e-h cADDis analysis.

cfg = caddis_common_config();
cfg.figure = 'fig3eh';
cfg.figure_label = 'Fig. 3e-h';
cfg.sensor = 'cADDis';
cfg.source_layout = 'raw_streams';

subject = [ ...
    "038232"; "038324"; "038326"; "038329"; ...
    "038537"; "038541"; "038543"; "038805"];
treatment = ["RG"; "RG"; "VG"; "VG"; "RG"; "VG"; "RG"; "VG"];
base_start = [1; 2; 2; 1; 2; 2; 3; 2];
base_end   = [31; 32; 32; 31; 32; 32; 33; 32];
t1_start   = [32; 33; 33; 32; 33; 33; 34; 33];
t1_end     = [47; 48; 48; 47; 48; 48; 49; 48];
t2_start   = [48; 49; 49; 48; 49; 49; 50; 49];
t2_end     = [78; 79; 79; 78; 79; 79; 80; 79];

cfg.crop_timestamps = table(subject, treatment, base_start, base_end, ...
    t1_start, t1_end, t2_start, t2_end, ...
    'VariableNames', {'Subject','Treatment','BaseStartMin','BaseEndMin', ...
    'T1StartMin','T1EndMin','T2StartMin','T2EndMin'});
cfg.subjects = cellstr(subject);
cfg.summary_mapping = cfg.crop_timestamps(:, {'Subject','Treatment'});
cfg.treatment_order = {'VG', 'RG'};

cfg.behapy_downsample_factor = 64;
config_root = fileparts(mfilename('fullpath'));
cfg.joint_fit_parameters_file = fullfile(config_root, ...
    'fig3eh_joint_fit_parameters.csv');
cfg.rejected_intervals_file = fullfile(config_root, ...
    'fig3eh_rejected_intervals.csv');

cfg.auc_intervals_min = [-14.9, 0; 0.1, 15; 15.1, 30];
cfg.auc_labels = {'Baseline', 'T1', 'T2'};
cfg.summary_x_limits_min = [-10, 30];
cfg.summary_y_limits = [-4, 2];
end
