function paths = caddis_paths(dataset)
% CADDIS_PATHS  User-editable paths for the cADDis workflows.
%
% Edit only the figure root settings below when running the analysis on a
% new computer. Source-data roots point directly to folders containing
% treatment groups.

paths.fig3eh_root = ''; % Fig. 3e-h root containing RG/ and VG/.
% Optional; defaults to fig3eh_root/analysis-output when empty.
paths.fig3eh_analysis_root = '';
paths.fig3k_root = '';  % Fig. 3k root containing GR/.
% Optional; defaults to fig3k_root/analysis-output when empty.
paths.fig3k_analysis_root = '';
paths.suppfig7cd_root = ''; % Supplemental Fig. 7c-d root containing RV/.
% Optional; defaults to suppfig7cd_root/analysis-output when empty.
paths.suppfig7cd_analysis_root = '';
paths.suppfig6gj_root = ''; % Supplemental Fig. 6g-j root containing hab3/.
% Optional; defaults to suppfig6gj_root/analysis-output when empty.
paths.suppfig6gj_analysis_root = '';

if nargin < 1
    dataset = 'fig3eh';
end

switch lower(char(string(dataset)))
    case {'fig3eh', 'fig3e-h'}
        paths.project_root = paths.fig3eh_root;
        path_setting = 'fig3eh_root';
        analysis_root = paths.fig3eh_analysis_root;
    case 'fig3k'
        paths.project_root = paths.fig3k_root;
        path_setting = 'fig3k_root';
        analysis_root = paths.fig3k_analysis_root;
    case {'suppfig7cd', 'suppfig7'}
        paths.project_root = paths.suppfig7cd_root;
        path_setting = 'suppfig7cd_root';
        analysis_root = paths.suppfig7cd_analysis_root;
    case {'suppfig6gj', 'suppfig6g-j'}
        paths.project_root = paths.suppfig6gj_root;
        path_setting = 'suppfig6gj_root';
        analysis_root = paths.suppfig6gj_analysis_root;
    otherwise
        error('Unknown cADDis dataset: %s.', char(string(dataset)));
end

if isempty(paths.project_root)
    error('Set paths.%s in caddis_paths.m before running this workflow.', ...
        path_setting);
end

paths.raw_root = paths.project_root;
if isempty(analysis_root)
    paths.processing_root = fullfile(paths.project_root, 'analysis-output');
else
    paths.processing_root = analysis_root;
end
paths.output_root = fullfile(paths.processing_root, 'outputs');
paths.summary_root = fullfile(paths.processing_root, 'summary');
paths.script_root = fileparts(mfilename('fullpath'));
end
