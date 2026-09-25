function paths = dlight_paths(dataset)
% DLIGHT_PATHS  User-editable paths for the dLight workflows.
%
% Edit only the settings below when running this workflow on a new computer.
% Figure datasets may be stored separately; all analysis code remains
% together in this folder.

paths.fig3d_root = '';    % Fig. 3d folder containing raw-data/processing.
paths.fig3j_root = '';    % Fig. 3j GR folder containing raw-data/processing.
paths.extfig6a_root = ''; % Ext. Fig. 6a RV folder containing raw-data/processing.
paths.fig2bd_root = '';   % Fig. 2b-d folder containing raw-data/processing.
paths.tdt_sdk_root = '';  % Folder containing the TDT MATLAB SDK.

if nargin < 1
    dataset = 'fig3d';
end

switch lower(char(string(dataset)))
    case 'fig2bd'
        paths.project_root = paths.fig2bd_root;
        path_setting = 'fig2bd_root';
    case 'fig3d'
        paths.project_root = paths.fig3d_root;
        path_setting = 'fig3d_root';
    case {'fig3j','gr'}
        paths.project_root = paths.fig3j_root;
        path_setting = 'fig3j_root';
    case {'extfig6a','rv'}
        paths.project_root = paths.extfig6a_root;
        path_setting = 'extfig6a_root';
    otherwise
        error('Unknown dLight dataset: %s.',char(string(dataset)));
end

if isempty(paths.project_root)
    error('Set paths.%s in dlight_paths.m before running this workflow.', ...
        path_setting);
end

paths.raw_root = fullfile(paths.project_root,'raw-data');
paths.output_root = fullfile(paths.project_root,'processing','outputs');
paths.script_root = fileparts(mfilename('fullpath'));
paths.hab3_output_root = fullfile(paths.output_root,'hab3');
paths.gr_output_root = fullfile(paths.output_root,'GR');
paths.gr_basal_root = fullfile(paths.output_root,'GR-basal');
paths.gr_summary_root = fullfile(paths.output_root,'GR-summary');
paths.rv_output_root = fullfile(paths.output_root,'RV');
paths.rv_basal_root = fullfile(paths.output_root,'RV-basal');
paths.rv_summary_root = fullfile(paths.output_root,'RV-summary');
paths.fig2bd_output_root = fullfile(paths.output_root,'fig2bd');
paths.fig2bd_basal_root = fullfile(paths.fig2bd_output_root,'basal');
paths.fig2bd_summary_root = fullfile(paths.fig2bd_output_root,'summary');
end
