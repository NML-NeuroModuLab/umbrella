function paths = caddis_paths(dataset)
% CADDIS_PATHS  User-editable paths for the cADDis workflows.
%
% Edit only the figure root settings below when running the analysis on a
% new computer. Each root should contain raw-data/ and processing/ folders.

paths.fig3e_root = '';  % Fig. 3e cADDis dataset root.
paths.fig3k_root = '';  % Fig. 3k cADDis dataset root.
paths.extfig6cd_root = ''; % Extended Data Fig. 6c-d cADDis dataset root.

if nargin < 1
    dataset = 'fig3e';
end

switch lower(char(string(dataset)))
    case 'fig3e'
        paths.project_root = paths.fig3e_root;
        path_setting = 'fig3e_root';
    case 'fig3k'
        paths.project_root = paths.fig3k_root;
        path_setting = 'fig3k_root';
    case {'extfig6cd', 'extfig6'}
        paths.project_root = paths.extfig6cd_root;
        path_setting = 'extfig6cd_root';
    otherwise
        error('Unknown cADDis dataset: %s.', char(string(dataset)));
end

if isempty(paths.project_root)
    error('Set paths.%s in caddis_paths.m before running this workflow.', ...
        path_setting);
end

paths.raw_root = fullfile(paths.project_root, 'raw-data');
paths.processing_root = fullfile(paths.project_root, 'processing');
paths.output_root = fullfile(paths.processing_root, 'outputs');
paths.summary_root = fullfile(paths.processing_root, 'summary');
paths.script_root = fileparts(mfilename('fullpath'));
end
