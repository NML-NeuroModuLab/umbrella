function [SIM_data, SIM_clean, import_summary] = import_caddis_parquet( ...
    raw_root, processing_root, cfg)
% IMPORT_CADDIS_PARQUET  Import and standardise one parquet file per animal.

if nargin < 3 || isempty(cfg)
    error('A figure configuration structure is required.');
end
if ~isfolder(raw_root)
    error('Raw-data folder not found: %s', raw_root);
end
if ~isfolder(processing_root)
    mkdir(processing_root);
end

SIM_data = struct();
SIM_clean = struct();
summary_rows = cell(0, 4);

subject_dirs = dir(raw_root);
subject_dirs = subject_dirs([subject_dirs.isdir]);
subject_dirs = subject_dirs(~ismember({subject_dirs.name}, {'.', '..'}));
[~, order] = sort({subject_dirs.name});
subject_dirs = subject_dirs(order);

for i = 1:numel(subject_dirs)
    subject_id = subject_dirs(i).name;
    subject_dir = fullfile(raw_root, subject_id);
    parquet_files = dir(fullfile(subject_dir, '*.parquet'));

    if isempty(parquet_files)
        warning('No parquet file found for subject folder %s.', subject_id);
        summary_rows(end+1, :) = {subject_id, '', 0, 'no parquet file'}; %#ok<AGROW>
        continue;
    end

    [~, file_order] = sort({parquet_files.name});
    parquet_files = parquet_files(file_order);
    if numel(parquet_files) > 1
        warning(['Multiple parquet files found for %s. Using the first ' ...
            'alphabetically: %s'], subject_id, parquet_files(1).name);
    end

    parquet_path = fullfile(parquet_files(1).folder, parquet_files(1).name);
    try
        raw_table = parquetread(parquet_path);
    catch ME
        warning('Could not read %s: %s', parquet_path, ME.message);
        summary_rows(end+1, :) = {subject_id, parquet_files(1).name, 0, ...
            'read failed'}; %#ok<AGROW>
        continue;
    end

    field_name = matlab.lang.makeValidName(['s', subject_id]);
    SIM_data.(field_name) = raw_table;

    required_width = max(cfg.source_column_order);
    if width(raw_table) < required_width
        warning('Skipping %s: expected at least %d columns, found %d.', ...
            subject_id, required_width, width(raw_table));
        summary_rows(end+1, :) = {subject_id, parquet_files(1).name, ...
            height(raw_table), 'too few columns'}; %#ok<AGROW>
        continue;
    end

    clean_table = raw_table(:, cfg.source_column_order);
    clean_table.Properties.VariableNames = cfg.clean_column_names;
    SIM_clean.(field_name) = clean_table;
    summary_rows(end+1, :) = {subject_id, parquet_files(1).name, ...
        height(clean_table), 'imported'}; %#ok<AGROW>
end

import_summary = cell2table(summary_rows, 'VariableNames', ...
    {'Subject', 'ParquetFile', 'RowsImported', 'Status'});

save(fullfile(processing_root, 'SIM_data.mat'), 'SIM_data', '-v7.3');
save(fullfile(processing_root, 'clean_SIM_data.mat'), ...
    'SIM_clean', 'import_summary', '-v7.3');
end
