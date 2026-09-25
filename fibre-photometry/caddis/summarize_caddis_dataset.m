function summary = summarize_caddis_dataset(output_root, summary_root, cfg, varargin)
% SUMMARIZE_CADDIS_DATASET  Combine subject traces and AUC values by group.

p = inputParser;
addParameter(p, 'save_figure', true, @islogical);
parse(p, varargin{:});

if ~isfolder(summary_root)
    mkdir(summary_root);
end

treatments = cfg.treatment_order;
dataTables = struct();
for i = 1:numel(treatments)
    group = treatments{i};
    dataTables.(group).BasalFluorescence = table();
    dataTables.(group).fpx_time = table();
    dataTables.(group).AUC = table();
    dataTables.(group).SectionMeans = table();
end

negative_AUC_summary = table();
section_mean_summary = table();
mapping = cfg.summary_mapping;

for i = 1:height(mapping)
    subject_id = char(mapping.Subject(i));
    treatment = char(mapping.Treatment(i));
    input_file = fullfile(output_root, subject_id, ...
        'data_basal-fluorescence.mat');

    if ~isfile(input_file)
        warning('Processed file not found for subject %s: %s', ...
            subject_id, input_file);
        continue;
    end

    loaded = load(input_file, 'fpx_time', 'fpx_smooth', 'fpx_auc');
    if ~isfield(loaded, 'fpx_time') || ~isfield(loaded, 'fpx_smooth')
        warning('Time or smoothed trace missing for subject %s.', subject_id);
        continue;
    end

    column_name = matlab.lang.makeValidName(['sub_', subject_id]);
    dataTables.(treatment).BasalFluorescence = append_padded_column( ...
        dataTables.(treatment).BasalFluorescence, column_name, ...
        loaded.fpx_smooth(:));
    dataTables.(treatment).fpx_time = append_padded_column( ...
        dataTables.(treatment).fpx_time, column_name, loaded.fpx_time(:));

    section_values = NaN(1, numel(cfg.section_mean_labels));
    for section_index = 1:numel(cfg.section_mean_labels)
        interval = cfg.section_mean_intervals_min(section_index, :);
        % Half-open intervals reproduce the original row-based ranges.
        in_section = loaded.fpx_time >= interval(1) & ...
            loaded.fpx_time < interval(2);
        section_values(section_index) = mean( ...
            loaded.fpx_smooth(in_section), 'omitnan');
    end
    section_row = array2table(section_values, ...
        'VariableNames', cfg.section_mean_labels);
    section_row = addvars(section_row, string(subject_id), string(treatment), ...
        'Before', 1, 'NewVariableNames', {'Subject', 'Treatment'});
    section_mean_summary = [section_mean_summary; section_row]; %#ok<AGROW>

    required_auc_rows = numel(cfg.auc_labels);
    if isfield(loaded, 'fpx_auc') && ...
            height(loaded.fpx_auc) >= required_auc_rows
        auc = loaded.fpx_auc;
        negative_values = reshape( ...
            auc.NegativeAreaWithinInterval(1:required_auc_rows), 1, []);
        negative_names = cellfun( ...
            @(label) [matlab.lang.makeValidName(label), '_Negative_AUC'], ...
            cfg.auc_labels, 'UniformOutput', false);
        auc_row = array2table(negative_values, ...
            'VariableNames', negative_names);
        auc_row = addvars(auc_row, string(subject_id), string(treatment), ...
            'Before', 1, 'NewVariableNames', {'Subject', 'Treatment'});
        negative_AUC_summary = [negative_AUC_summary; auc_row]; %#ok<AGROW>

        auc_subject = repmat(string(subject_id), height(auc), 1);
        auc_with_subject = addvars(auc, auc_subject, ...
            'Before', 1, 'NewVariableNames', 'Subject');
        dataTables.(treatment).AUC = [ ...
            dataTables.(treatment).AUC; auc_with_subject];
    end
end

writetable(negative_AUC_summary, fullfile(summary_root, ...
    'negative_AUC_summary.csv'));
writetable(section_mean_summary, fullfile(summary_root, ...
    'section_mean_summary.csv'));

if p.Results.save_figure
    summary_figure = figure('Visible', 'off', ...
        'Position', [100, 100, 700, 250]);
    tiledlayout(1, numel(treatments), 'TileSpacing', 'compact');
else
    summary_figure = [];
end

for i = 1:numel(treatments)
    group = treatments{i};
    trace_table = dataTables.(group).BasalFluorescence;
    time_table = dataTables.(group).fpx_time;
    if isempty(trace_table)
        warning('No processed data found for treatment %s.', group);
        continue;
    end

    shared_time = mean(time_table{:,:}, 2, 'omitnan');
    trace_export = table(shared_time, 'VariableNames', {'TimeMin'});
    for column_index = 1:width(trace_table)
        variable_name = trace_table.Properties.VariableNames{column_index};
        trace_export.(variable_name) = trace_table{:, column_index};
    end
    writetable(trace_export, fullfile(summary_root, ...
        sprintf('%s_basal_traces_wide.csv', lower(group))));

    mean_z = mean(trace_table{:,:}, 2, 'omitnan');
    sample_size = sum(isfinite(trace_table{:,:}), 2);
    sem_z = std(trace_table{:,:}, 0, 2, 'omitnan') ./ sqrt(max(sample_size, 1));
    group_mean = table(shared_time, mean_z, sem_z, sample_size, ...
        'VariableNames', {'TimeMin', 'MeanZSmooth', 'SEMZSmooth', 'N'});
    writetable(group_mean, fullfile(summary_root, ...
        sprintf('%s_basal_group_mean.csv', lower(group))));

    if p.Results.save_figure
        axes_handle = nexttile;
        hold(axes_handle, 'on');
        for column_index = 1:width(trace_table)
            x = time_table{:, column_index};
            y = trace_table{:, column_index};
            valid = isfinite(x) & isfinite(y);
            plot(axes_handle, x(valid), y(valid), ...
                'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.5);
        end
        valid_mean = isfinite(shared_time) & isfinite(mean_z);
        plot(axes_handle, shared_time(valid_mean), mean_z(valid_mean), ...
            'k-', 'LineWidth', 2.5);
        title(axes_handle, group, 'Interpreter', 'none');
        xlabel(axes_handle, 'Time (min)');
        ylabel(axes_handle, 'z dF/F');
        xlim(axes_handle, cfg.summary_x_limits_min);
        ylim(axes_handle, cfg.summary_y_limits);
        if cfg.reverse_summary_y_axis
            set(axes_handle, 'YDir', 'reverse');
        end
        box(axes_handle, 'on');
    end
end

if p.Results.save_figure
    sgtitle('cADDis basal fluorescence', 'FontWeight', 'bold');
    exportgraphics(summary_figure, fullfile(summary_root, ...
        'caddis_summary_basal-fluorescence.pdf'), 'ContentType', 'vector');
    close(summary_figure);
end

save(fullfile(summary_root, 'summary_caddis_data.mat'), ...
    'dataTables', 'negative_AUC_summary', 'section_mean_summary', '-v7.3');

summary = struct( ...
    'dataTables', dataTables, ...
    'negative_AUC_summary', negative_AUC_summary, ...
    'section_mean_summary', section_mean_summary);
end

function output_table = append_padded_column(input_table, column_name, values)
values = values(:);
if width(input_table) == 0
    output_table = table(values, 'VariableNames', {column_name});
    return;
end

target_height = max(height(input_table), numel(values));
if height(input_table) < target_height
    input_table{height(input_table)+1:target_height, :} = NaN;
end
if numel(values) < target_height
    values(numel(values)+1:target_height, 1) = NaN;
end
input_table.(column_name) = values;
output_table = input_table;
end
