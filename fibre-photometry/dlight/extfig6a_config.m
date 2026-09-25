function cfg = extfig6a_config(animal)
% EXTFIG6A_CONFIG  Configuration for the Extended Data Fig. 6a RV dataset.
%
% Raw-data layout:
%   raw-data/RV/<animal>/
%
% Timing and artefact values are in minutes on the original recording axis.

animal = char(string(animal));

%% Shared processing settings
cfg.figure = 'extfig6a';
cfg.figure_label = 'Extended Data Fig. 6a';
cfg.group = 'RV';
cfg.signal_suffix = '465';
cfg.reference_suffix = '405';
cfg.lowpass_hz = 20;
cfg.target_fs = 100;
cfg.canonical_xlim = [-30 60];
cfg.artifact_policy = 'interp';

%% Downstream 10-minute analysis settings
cfg.smooth_min = 1;
cfg.analysis_intervals = [ ...
    -10   0; ...
      0  10; ...
     10  20; ...
     20  30];
cfg.mean_intervals = cfg.analysis_intervals;
cfg.analysis_labels = {'Baseline','T1-1','T1-2','T1-3'};
cfg.summary_xlim = [-10 30];
cfg.summary_boundaries = [0 10 20];
cfg.save_summary_png = true;

%% Animal-specific recording settings
switch animal
    case '055619'
        cfg.stream_letter = 'A';
        cfg.timestamps.baseline = [32 47];
        cfg.timestamps.t1 = [48 93];
        cfg.artifact_ranges = zeros(0,2);

    case '055620'
        cfg.stream_letter = 'B';
        cfg.timestamps.baseline = [33 48];
        cfg.timestamps.t1 = [49 94];
        cfg.artifact_ranges = zeros(0,2);

    case '055621'
        cfg.stream_letter = 'A';
        cfg.timestamps.baseline = [32 47];
        cfg.timestamps.t1 = [48 93];
        cfg.artifact_ranges = zeros(0,2);

    case '056125'
        cfg.stream_letter = 'B';
        cfg.timestamps.baseline = [32 47];
        cfg.timestamps.t1 = [48 93];
        cfg.artifact_ranges = [94.603631 107.309070];

    case '055625'
        cfg.stream_letter = 'A';
        cfg.timestamps.baseline = [56 72];
        cfg.timestamps.t1 = [73 118];
        cfg.artifact_ranges = [ ...
            0 25.629289; ...
            121.747121 122.419050];

    otherwise
        error('No Extended Data Fig. 6a configuration found for animal %s.',animal);
end

cfg.signal_stream = [cfg.stream_letter cfg.signal_suffix];
cfg.reference_stream = [cfg.stream_letter cfg.reference_suffix];
end
