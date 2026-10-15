function result = compute_caddis_dff(data_table, cfg)
% COMPUTE_CADDIS_DFF  Compute dF/F and baseline z score for one recording.
%
% The raw Time column is used only to infer the sampling interval. A
% canonical time vector is then built from cfg.canonical_start_min

if ~istable(data_table)
    error('Input must be a MATLAB table.');
end

variable_names = data_table.Properties.VariableNames;
time_name = find_first_column(variable_names, cfg.time_column_candidates);
signal_name = find_first_column(variable_names, cfg.signal_column_candidates);
reference_name = find_first_column(variable_names, cfg.reference_column_candidates);

if isempty(time_name) || isempty(signal_name)
    error('Required Time or cADDis signal column is missing.');
end

time_sec = double(data_table.(time_name)(:));
signal = double(data_table.(signal_name)(:));
if isempty(reference_name)
    reference = NaN(size(signal));
else
    reference = double(data_table.(reference_name)(:));
end

if numel(time_sec) ~= numel(signal) || numel(reference) ~= numel(signal)
    error('Time, signal, and reference columns must have matching lengths.');
end

valid_steps = diff(time_sec);
valid_steps = valid_steps(isfinite(valid_steps) & valid_steps > 0);
if isempty(valid_steps)
    error('Could not infer a positive sampling interval from the Time column.');
end

step_sec = median(valid_steps);
step_min = step_sec / 60;
sample_count = numel(signal);
fpx_time = cfg.canonical_start_min + (0:sample_count-1)' .* step_min;

if any(isfinite(reference))
    median_reference = median(abs(reference(isfinite(reference))));
    floor_value = max(eps, cfg.safe_floor_relative * max(1, median_reference));
    dff = (signal - reference) ./ max(reference, floor_value);
else
    median_signal = median(abs(signal(isfinite(signal))));
    floor_value = max(eps, cfg.safe_floor_relative * max(1, median_signal));
    dff = (signal - median_signal) ./ max(median_signal, floor_value);
end

baseline_window = cfg.baseline_window_min;
baseline_mask = fpx_time >= baseline_window(1) & ...
    fpx_time <= baseline_window(2);
baseline_values = dff(baseline_mask & isfinite(dff));
if isempty(baseline_values)
    error('The baseline window contains no finite samples.');
end

baseline_mean = mean(baseline_values);
baseline_std = std(baseline_values);
if isfinite(baseline_std) && baseline_std > 0
    z = (dff - baseline_mean) ./ baseline_std;
else
    z = dff - baseline_mean;
end

result = struct();
result.fpx_time = fpx_time;
result.dff = dff;
result.z = z;
result.baseline_mask = baseline_mask;
result.baseline_mean = baseline_mean;
result.baseline_std = baseline_std;
result.floor_value = floor_value;
result.step_sec = step_sec;
result.step_min = step_min;
result.time_column = time_name;
result.signal_column = signal_name;
result.reference_column = reference_name;
end

function name = find_first_column(variable_names, candidates)
name = '';
for i = 1:numel(candidates)
    match = find(strcmpi(variable_names, candidates{i}), 1);
    if ~isempty(match)
        name = variable_names{match};
        return;
    end
end
end
