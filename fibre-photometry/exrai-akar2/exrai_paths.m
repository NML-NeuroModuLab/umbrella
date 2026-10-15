function paths = exrai_paths(dataset)
% EXRAI_PATHS  User-editable paths for the ExRaiAKAR2 workflows.

% Edit only the settings below when running the analysis on a new computer.

paths.fig3fil_root = ''; % Source package root containing VG/, RG/, GR/, and RV/.
paths.fig3fil_analysis_root = ''; % Optional output folder for Fig. 3 analysis.
paths.suppfig7ef_root = ''; % Folder where Supplemental Fig. 7e-f outputs are saved.
paths.suppfig6ko_analysis_root = ''; % Optional Supplemental Fig. 6k-o output folder.
paths.tdt_sdk_root = ''; % Folder containing the TDT MATLAB SDK.

if nargin < 1
    dataset = 'fig3fil';
end

switch lower(char(string(dataset)))
    case 'fig3fil'
        paths.project_root = paths.fig3fil_root;
        paths.analysis_root = paths.fig3fil_analysis_root;
        path_setting = 'fig3fil_root';
    case 'suppfig7ef'
        source_root = paths.fig3fil_root;
        source_analysis_root = paths.fig3fil_analysis_root;
        if isempty(source_root)
            error(['Set paths.fig3fil_root in exrai_paths.m. Supplemental ' ...
                'Fig. 7e-f reuses the RV recordings processed for Fig. 3.']);
        end
        paths.source_project_root = source_root;
        paths.source_analysis_root = source_analysis_root;
        if isempty(paths.source_analysis_root)
            paths.source_analysis_root = fullfile(source_root,'analysis-output');
        end
        paths.project_root = paths.suppfig7ef_root;
        paths.analysis_root = paths.suppfig7ef_root;
        path_setting = 'suppfig7ef_root';
    case {'suppfig6ko','suppfig6k-o'}
        source_root = paths.fig3fil_root;
        source_analysis_root = paths.fig3fil_analysis_root;
        if isempty(source_root)
            error(['Set paths.fig3fil_root in exrai_paths.m. Supplemental ' ...
                'Fig. 6k-o reuses the recordings processed for Fig. 3.']);
        end
        paths.source_project_root = source_root;
        paths.source_analysis_root = source_analysis_root;
        if isempty(paths.source_analysis_root)
            paths.source_analysis_root = fullfile(source_root,'analysis-output');
        end
        paths.analysis_root = paths.suppfig6ko_analysis_root;
        if isempty(paths.analysis_root)
            paths.analysis_root = fullfile(paths.source_analysis_root,'suppfig6ko');
        end
        paths.project_root = paths.analysis_root;
        path_setting = 'fig3fil_root';
    otherwise
        error('Unknown ExRaiAKAR2 dataset: %s.', char(string(dataset)));
end

if isempty(paths.project_root)
    error('Set paths.%s in exrai_paths.m before running this workflow.', ...
        path_setting);
end

if strcmpi(char(string(dataset)),'suppfig7ef')
    paths.raw_root = paths.source_project_root;
    paths.processed_root = paths.source_analysis_root;
    paths.summary_root = fullfile(paths.project_root, 'processing');
elseif any(strcmpi(char(string(dataset)),{'suppfig6ko','suppfig6k-o'}))
    paths.raw_root = paths.source_project_root;
    if isempty(paths.analysis_root)
        paths.analysis_root = fullfile(paths.project_root,'analysis-output');
    end
    paths.processed_root = paths.source_analysis_root;
    paths.processing_root = paths.analysis_root;
    paths.summary_root = fullfile(paths.analysis_root,'summary');
else
    paths.raw_root = paths.project_root;
    if isempty(paths.analysis_root)
        paths.analysis_root = fullfile(paths.project_root,'analysis-output');
    end
    paths.processed_root = paths.analysis_root;
    paths.summary_root = fullfile(paths.analysis_root,'summary');
end
paths.script_root = fileparts(mfilename('fullpath'));
end
