function [SIM_cropped, crop_summary] = crop_caddis_recordings(SIM_clean, cfg)
% CROP_CADDIS_RECORDINGS  Crop and concatenate baseline, T1, and T2 periods.

if ~isstruct(SIM_clean)
    error('SIM_clean must be a structure containing one table per subject.');
end

SIM_cropped = struct();
summary_rows = cell(0, 5);
subject_fields = fieldnames(SIM_clean);

for i = 1:numel(subject_fields)
    subject_field = subject_fields{i};
    subject_id = regexprep(subject_field, '^s', '');
    table_in = SIM_clean.(subject_field);

    timestamp_match = cfg.crop_timestamps.Subject == string(subject_id);
    if ismember('UseForCrop', cfg.crop_timestamps.Properties.VariableNames)
        timestamp_match = timestamp_match & cfg.crop_timestamps.UseForCrop;
    end
    timestamp_row = find(timestamp_match, 1);
    if isempty(timestamp_row)
        warning('No crop timestamps found for subject %s.', subject_id);
        summary_rows(end+1, :) = {subject_id, 0, 0, 0, 0}; %#ok<AGROW>
        continue;
    end
    if ~istable(table_in) || ~ismember('Time', table_in.Properties.VariableNames)
        warning('Subject %s does not contain a Time column.', subject_id);
        summary_rows(end+1, :) = {subject_id, 0, 0, 0, 0}; %#ok<AGROW>
        continue;
    end

    stamp = cfg.crop_timestamps(timestamp_row, :);
    time_sec = double(table_in.Time(:));
    ranges_sec = 60 .* [ ...
        stamp.BaseStartMin, stamp.BaseEndMin; ...
        stamp.T1StartMin, stamp.T1EndMin; ...
        stamp.T2StartMin, stamp.T2EndMin];

    baseline_mask = time_sec >= ranges_sec(1, 1) & time_sec <= ranges_sec(1, 2);
    t1_mask = time_sec >= ranges_sec(2, 1) & time_sec <= ranges_sec(2, 2);
    t2_mask = time_sec >= ranges_sec(3, 1) & time_sec <= ranges_sec(3, 2);

    cropped_table = [ ...
        table_in(baseline_mask, :); ...
        table_in(t1_mask, :); ...
        table_in(t2_mask, :)];
    SIM_cropped.(subject_field) = cropped_table;

    summary_rows(end+1, :) = { ...
        subject_id, nnz(baseline_mask), nnz(t1_mask), nnz(t2_mask), ...
        height(cropped_table)}; %#ok<AGROW>
end

crop_summary = cell2table(summary_rows, 'VariableNames', ...
    {'Subject', 'BaselineRows', 'T1Rows', 'T2Rows', 'RowsAfterCrop'});
end
