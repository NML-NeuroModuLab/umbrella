%% BATCH_PROCESSING_FIG3K
% Import, crop, and process the Fig. 3k cADDis recordings.

clear; clc;

script_root = fileparts(mfilename('fullpath'));
addpath(script_root);
paths = caddis_paths('fig3k');
cfg = fig3k_config();

fprintf('\n1/3 Importing parquet files...\n');
[~, SIM_clean, import_summary] = import_caddis_parquet( ...
    paths.raw_root, paths.processing_root, cfg);
disp(import_summary);

fprintf('\n2/3 Cropping baseline, T1, and T2 periods...\n');
[SIM_cropped, crop_summary] = crop_caddis_recordings(SIM_clean, cfg);
save(fullfile(paths.processing_root, 'cropped_SIM_data.mat'), ...
    'SIM_cropped', 'crop_summary', '-v7.3');
disp(crop_summary);

fprintf('\n3/3 Calculating dF/F, smoothed traces, and AUC...\n');
process_only = cfg.subjects;  % e.g. {'042440'} for a validation run.
process_caddis_dataset( ...
    SIM_cropped, cfg, paths.output_root, ...
    'process_only', process_only, ...
    'save_figures', true, ...
    'save_csv_per_subject', false);

fprintf('\nFig. 3k cADDis processing complete.\n');
