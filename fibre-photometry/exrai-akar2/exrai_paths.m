function paths = exrai_paths(dataset)
% EXRAI_PATHS  User-editable paths for the ExRaiAKAR2 workflows.
%
% Edit only the settings below when running the analysis on a new computer.

paths.fig3fk_root = ''; % Folder containing raw-data/, processed/, and summary/.
paths.extfig6c_root = ''; % Folder where Extended Data Fig. 6c outputs are saved.
paths.tdt_sdk_root = ''; % Folder containing the TDT MATLAB SDK.

if nargin < 1
    dataset = 'fig3fk';
end

switch lower(char(string(dataset)))
    case 'fig3fk'
        paths.project_root = paths.fig3fk_root;
        path_setting = 'fig3fk_root';
    case 'extfig6c'
        if isempty(paths.fig3fk_root)
            error(['Set paths.fig3fk_root in exrai_paths.m. Extended Data ' ...
                'Fig. 6c reuses the RV recordings processed for Fig. 3.']);
        end
        paths.source_project_root = paths.fig3fk_root;
        paths.project_root = paths.extfig6c_root;
        path_setting = 'extfig6c_root';
    otherwise
        error('Unknown ExRaiAKAR2 dataset: %s.', char(string(dataset)));
end

if isempty(paths.project_root)
    error('Set paths.%s in exrai_paths.m before running this workflow.', ...
        path_setting);
end

if strcmpi(char(string(dataset)),'extfig6c')
    paths.raw_root = fullfile(paths.source_project_root, 'raw-data');
    paths.processed_root = fullfile(paths.source_project_root, 'processed');
    paths.summary_root = fullfile(paths.project_root, 'processing');
else
    paths.raw_root = fullfile(paths.project_root, 'raw-data');
    paths.processed_root = fullfile(paths.project_root, 'processed');
    paths.summary_root = fullfile(paths.project_root, 'summary');
end
paths.script_root = fileparts(mfilename('fullpath'));
end
