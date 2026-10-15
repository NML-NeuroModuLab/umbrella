function paths = dlight_paths(dataset)
% DLIGHT_PATHS  User-editable paths for the dLight workflows.
%
% Edit only the settings below when running this workflow on a new computer.
% Figure datasets may be stored separately; all analysis code remains
% together in this folder.

% Fig. 3d-g public source-data folder containing hab3/ and test/.
paths.fig3dg_root = '';
% Optional; defaults to fig3dg_root/analysis-output when empty.
paths.fig3dg_analysis_root = '';
% Fig. 3j public source-data folder containing GR/.
paths.fig3j_root = '';
% Optional; defaults to fig3j_root/analysis-output when empty.
paths.fig3j_analysis_root = '';
% Supplemental Fig. 7a-b public source-data folder containing rv/.
paths.suppfig7ab_root = '';
% Optional; defaults to suppfig7ab_root/analysis-output when empty.
paths.suppfig7ab_analysis_root = '';
% Supplemental Fig. 6a-f unique cohort-3 habituation recordings. This
% workflow also reads cohort 1 from fig3dg_root and cohort 2 from fig2bd_root.
paths.suppfig6af_root = '';
% Optional; defaults to suppfig6af_root/analysis-output when empty.
paths.suppfig6af_analysis_root = '';

% Fig. 2b-d uses the public export rather than a TDT tank. Set this to the
% folder that directly contains hab3/, vg/, rg/, and rv/.
paths.fig2bd_root = '';

% Optional Fig. 2b-d output location. Leave empty to write results to an
% analysis-output/ folder inside fig2bd_root.
paths.fig2bd_analysis_root = '';

if nargin < 1
    dataset = 'fig3dg';
end

switch lower(char(string(dataset)))
    case 'fig2bd'
        paths.project_root = paths.fig2bd_root;
        path_setting = 'fig2bd_root';
    case 'fig3dg'
        paths.project_root = paths.fig3dg_root;
        path_setting = 'fig3dg_root';
    case {'fig3j','gr'}
        paths.project_root = paths.fig3j_root;
        path_setting = 'fig3j_root';
    case {'suppfig7ab','rv'}
        paths.project_root = paths.suppfig7ab_root;
        path_setting = 'suppfig7ab_root';
    case {'suppfig6af','suppfig6a-f'}
        paths.project_root = paths.suppfig6af_root;
        path_setting = 'suppfig6af_root';
    otherwise
        error('Unknown dLight dataset: %s.',char(string(dataset)));
end

if isempty(paths.project_root)
    error('Set paths.%s in dlight_paths.m before running this workflow.', ...
        path_setting);
end

paths.script_root = fileparts(mfilename('fullpath'));
dataset = lower(char(string(dataset)));
uses_public_export = any(strcmp(dataset, ...
    {'fig2bd','fig3dg','fig3j','gr','suppfig6af','suppfig6a-f', ...
     'suppfig7ab','rv'}));

if uses_public_export
    paths.data_root = paths.project_root;
    paths.raw_root = paths.data_root; % Backward-compatible alias.
    if strcmp(dataset,'fig2bd')
        analysis_root = paths.fig2bd_analysis_root;
    elseif strcmp(dataset,'fig3dg')
        analysis_root = paths.fig3dg_analysis_root;
    elseif any(strcmp(dataset,{'fig3j','gr'}))
        analysis_root = paths.fig3j_analysis_root;
    elseif any(strcmp(dataset,{'suppfig6af','suppfig6a-f'}))
        analysis_root = paths.suppfig6af_analysis_root;
    else
        analysis_root = paths.suppfig7ab_analysis_root;
    end
    if isempty(analysis_root)
        paths.output_root = fullfile(paths.project_root,'analysis-output');
    else
        paths.output_root = analysis_root;
    end
else
    paths.raw_root = fullfile(paths.project_root,'raw-data');
    paths.data_root = paths.raw_root;
    paths.output_root = fullfile(paths.project_root,'processing','outputs');
end

paths.hab3_output_root = fullfile(paths.output_root,'hab3');
paths.gr_output_root = fullfile(paths.output_root,'GR');
paths.gr_basal_root = fullfile(paths.output_root,'GR-basal');
paths.gr_summary_root = fullfile(paths.output_root,'GR-summary');
paths.rv_output_root = fullfile(paths.output_root,'RV');
paths.rv_basal_root = fullfile(paths.output_root,'RV-basal');
paths.rv_summary_root = fullfile(paths.output_root,'RV-summary');
if strcmp(dataset,'fig2bd')
    paths.fig2bd_output_root = paths.output_root;
else
    paths.fig2bd_output_root = fullfile(paths.output_root,'fig2bd');
end
paths.fig2bd_basal_root = fullfile(paths.fig2bd_output_root,'basal');
paths.fig2bd_summary_root = fullfile(paths.fig2bd_output_root,'summary');
paths.suppfig6af_processed_root = fullfile(paths.output_root,'processed-data');
paths.suppfig6af_summary_root = fullfile(paths.output_root,'summary');
end
