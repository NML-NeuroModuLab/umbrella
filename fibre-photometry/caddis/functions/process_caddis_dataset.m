function results = process_caddis_dataset(SIM_cropped, cfg, output_root, varargin)
% PROCESS_CADDIS_DATASET  Calculate z(dF/F), smoothing, and AUC by subject.

p = inputParser;
addParameter(p, 'process_only', {}, @(x) iscell(x) || isstring(x));
addParameter(p, 'save_figures', true, @islogical);
addParameter(p, 'save_csv_per_subject', false, @islogical);
parse(p, varargin{:});
options = p.Results;

if ~isfolder(output_root)
    mkdir(output_root);
end

process_only = cellstr(string(options.process_only));
results = struct();
subject_fields = fieldnames(SIM_cropped);

for i = 1:numel(subject_fields)
    subject_field = subject_fields{i};
    subject_id = regexprep(subject_field, '^s', '');
    if ~isempty(process_only) && ~any(strcmp(process_only, subject_id))
        continue;
    end

    fprintf('\n=== %s | %s ===\n', cfg.figure_label, subject_id);
    derived = compute_caddis_dff(SIM_cropped.(subject_field), cfg);
    fpx_time = derived.fpx_time(:);
    z_vec = derived.z(:);

    window_samples = max(1, round(cfg.smoothing_window_sec / derived.step_sec));
    switch lower(cfg.smoothing_mode)
        case 'causal'
            fpx_smooth = movmean(z_vec, [window_samples - 1, 0], 'omitnan');
        case 'centered'
            fpx_smooth = movmean(z_vec, window_samples, 'omitnan');
        otherwise
            error('Unknown smoothing mode: %s', cfg.smoothing_mode);
    end

    if all(isnan(fpx_smooth))
        error('All smoothed values are NaN for subject %s.', subject_id);
    end
    if any(isnan(fpx_smooth))
        fpx_smooth = fillmissing(fpx_smooth, 'linear');
        fpx_smooth = fillmissing(fpx_smooth, 'nearest');
    end

    interval_count = size(cfg.auc_intervals_min, 1);
    total_area = NaN(interval_count, 1);
    negative_area = NaN(interval_count, 1);
    positive_area = NaN(interval_count, 1);
    sample_count = zeros(interval_count, 1);

    for interval_index = 1:interval_count
        interval = cfg.auc_intervals_min(interval_index, :);
        in_interval = fpx_time >= interval(1) & fpx_time <= interval(2);
        sample_count(interval_index) = nnz(in_interval);
        if sample_count(interval_index) < 2
            continue;
        end

        x = fpx_time(in_interval);
        y = fpx_smooth(in_interval);
        total_area(interval_index) = trapz(x, y);
        negative_area(interval_index) = trapz(x, min(y, 0));
        positive_area(interval_index) = trapz(x, max(y, 0));
    end

    fpx_auc = table( ...
        string(cfg.auc_labels(:)), ...
        cfg.auc_intervals_min(:, 1), ...
        cfg.auc_intervals_min(:, 2), ...
        sample_count, total_area, negative_area, positive_area, ...
        'VariableNames', { ...
        'Interval', 'IntervalStart', 'IntervalEnd', 'SampleCount', ...
        'TotalArea', 'NegativeAreaWithinInterval', ...
        'PositiveAreaWithinInterval'});

    metadata = struct( ...
        'figure', cfg.figure, ...
        'figure_label', cfg.figure_label, ...
        'subject', subject_id, ...
        'smoothing_mode', cfg.smoothing_mode, ...
        'smoothing_window_sec', cfg.smoothing_window_sec, ...
        'smoothing_window_samples', window_samples, ...
        'baseline_window_min', cfg.baseline_window_min, ...
        'signal_column', derived.signal_column, ...
        'reference_column', derived.reference_column, ...
        'step_sec', derived.step_sec);

    subject_output = fullfile(output_root, subject_id);
    if ~isfolder(subject_output)
        mkdir(subject_output);
    end

    save_data = struct( ...
        'fpx_smooth', fpx_smooth, ...
        'z_vec', z_vec, ...
        'fpx_time', fpx_time, ...
        'step_sec', derived.step_sec, ...
        'smoothing_mode', cfg.smoothing_mode, ...
        'smooth_win_sec', cfg.smoothing_window_sec, ...
        'fpx_auc', fpx_auc, ...
        'metadata', metadata);
    save(fullfile(subject_output, 'data_basal-fluorescence.mat'), ...
        '-struct', 'save_data', '-v7.3');

    if options.save_csv_per_subject
        trace_table = table(fpx_time, z_vec, fpx_smooth, ...
            'VariableNames', {'TimeMin', 'ZRaw', 'ZSmooth'});
        writetable(trace_table, fullfile(subject_output, ...
            [subject_id, '_basal-fluorescence.csv']));
        writetable(fpx_auc, fullfile(subject_output, ...
            [subject_id, '_auc.csv']));
    end

    if options.save_figures
        save_subject_figures(subject_output, subject_id, fpx_time, ...
            z_vec, fpx_smooth, fpx_auc, cfg);
    end

    results.(subject_field) = struct( ...
        'subject', subject_id, ...
        'fpx_time', fpx_time, ...
        'z', z_vec, ...
        'z_smooth', fpx_smooth, ...
        'auc', fpx_auc, ...
        'metadata', metadata);
    fprintf('[OK] Saved cADDis analysis for %s.\n', subject_id);
end
end

function save_subject_figures(output_dir, subject_id, time, z, z_smooth, auc, cfg)
trace_figure = figure('Visible', 'off', 'Position', [100, 100, 900, 350]);
plot(time, z, '-', 'Color', [0.65, 0.65, 0.65], ...
    'DisplayName', 'Original z');
hold on;
plot(time, z_smooth, 'k-', 'LineWidth', 1.5, ...
    'DisplayName', 'Smoothed z');
xline(-15, 'k--', 'Baseline start');
xline(0, 'k--', 'Injection');
xlabel('Time (min)');
ylabel('z dF/F');
title(sprintf('%s basal fluorescence', subject_id), 'Interpreter', 'none');
legend('Location', 'best');
box on;
exportgraphics(trace_figure, fullfile(output_dir, ...
    'c1_basal-fluorescence.pdf'), 'ContentType', 'vector');
close(trace_figure);

colours = [ ...
    0.8, 0.8, 0.8; ...
    0.3843, 0.3373, 0.6902; ...
    0.9412, 0.5725, 0.8902; ...
    0.8588, 0.2510, 0.8196];
auc_figure = figure('Visible', 'off', 'Position', [100, 100, 900, 350]);
hold on;
for i = 1:height(auc)
    in_interval = time >= auc.IntervalStart(i) & time <= auc.IntervalEnd(i);
    if nnz(in_interval) < 2
        continue;
    end
    x = time(in_interval);
    y = z_smooth(in_interval);
    colour_index = min(i, size(colours, 1));
    fill([x(1); x; x(end)], [0; y; 0], colours(colour_index, :), ...
        'FaceAlpha', 0.35, 'EdgeColor', 'none');
end
plot(time, z_smooth, 'k-', 'LineWidth', 1.2);
xlim([cfg.canonical_start_min, max(cfg.auc_intervals_min(:, 2))]);
xlabel('Time (min)');
ylabel('z dF/F');
title(sprintf('%s AUC', subject_id), 'Interpreter', 'none');
box on;
exportgraphics(auc_figure, fullfile(output_dir, ...
    'c2_basal-fluorescence_auc.pdf'), 'ContentType', 'vector');
close(auc_figure);
end
