function cfg = fig3j_config(animal)
% FIG3J_CONFIG  Configuration for the Fig. 3j GR dLight dataset.
%
% Raw-data layout:
%   raw-data/GR/<animal>/
%
% Timing and artefact values are in minutes on the original recording axis.

animal = char(string(animal));

%% Shared processing settings
cfg.figure = 'fig3j';
cfg.figure_label = 'Fig. 3j';
cfg.group = 'GR';
cfg.signal_suffix = '465';
cfg.reference_suffix = '405';
cfg.lowpass_hz = 20;
cfg.target_fs = 100;
cfg.canonical_xlim = [-30 60];
cfg.artifact_policy = 'interp';

%% Downstream analysis settings
cfg.smooth_min = 1;
cfg.analysis_intervals = [ ...
    -14.9   0.0; ...
      0.1  15.0; ...
     15.1  30.0; ...
     30.1  45.0; ...
     45.1  60.0];
cfg.analysis_labels = {'Baseline','T1','T2-1','T2-2','T2-3'};
cfg.mean_intervals = [ ...
    -10   0; ...
      5  15; ...
     20  30; ...
     35  45; ...
     50  60];
cfg.summary_xlim = [-10 45];
cfg.summary_boundaries = 0;
cfg.save_summary_png = false;

%% Animal-specific recording settings
switch animal
    case '055619'
        cfg.stream_letter = 'A';
        cfg.timestamps.baseline = [17 47];
        cfg.timestamps.t1 = [48 63];
        cfg.timestamps.t2 = [64 109];
        cfg.artifact_ranges = [0 17.422979];

    case '055620'
        cfg.stream_letter = 'B';
        cfg.timestamps.baseline = [2 32];
        cfg.timestamps.t1 = [33 48];
        cfg.timestamps.t2 = [49 94];
        cfg.artifact_ranges = [95.070367 96.070367];

    case '055621'
        cfg.stream_letter = 'A';
        cfg.timestamps.baseline = [13 43];
        cfg.timestamps.t1 = [44 60];
        cfg.timestamps.t2 = [61.5 106.5];
        cfg.artifact_ranges = [0 13.266385];

    case '056125'
        cfg.stream_letter = 'B';
        cfg.timestamps.baseline = [6 36];
        cfg.timestamps.t1 = [37 52];
        cfg.timestamps.t2 = [53 98];
        cfg.artifact_ranges = [ ...
            0 0.539290; ...
            97.816951 98.253519];

    case '055625'
        cfg.stream_letter = 'A';
        cfg.timestamps.baseline = [1 31];
        cfg.timestamps.t1 = [32 47];
        cfg.timestamps.t2 = [48 93];
        cfg.artifact_ranges = [ ...
            0 10.686612; ...
            22.152718 24.466055; ...
            41.162314 42.162314];

    otherwise
        error('No Fig. 3j configuration found for animal %s.',animal);
end

cfg.signal_stream = [cfg.stream_letter cfg.signal_suffix];
cfg.reference_stream = [cfg.stream_letter cfg.reference_suffix];
end
