function paths = gcamp_paths(dataset)
% GCAMP_PATHS User-editable paths for the GCaMP workflows.
%
% Set the root for each downloaded source-data folder. Leave the matching
% analysis root empty to write results beneath data_root/analysis-output.

paths.suppfig3eh_root = '';
paths.suppfig3eh_analysis_root = '';
paths.suppfig5cf_root = '';
paths.suppfig5cf_analysis_root = '';

if nargin < 1 || strlength(string(dataset)) == 0
    dataset = 'suppfig3eh';
end

switch lower(char(string(dataset)))
    case {'suppfig3','suppfig3eh','suppfig3e-h','supplementalfig3'}
        paths.data_root = paths.suppfig3eh_root;
        paths.analysis_root = paths.suppfig3eh_analysis_root;
        path_setting = 'suppfig3eh_root';
    case {'suppfig5','suppfig5cf','suppfig5c-f','supplementalfig5'}
        paths.data_root = paths.suppfig5cf_root;
        paths.analysis_root = paths.suppfig5cf_analysis_root;
        path_setting = 'suppfig5cf_root';
    otherwise
        error('Unknown GCaMP dataset: %s',dataset);
end

if isempty(paths.data_root)
    error('Set paths.%s in gcamp_paths.m before running this workflow.', ...
        path_setting);
end

if isempty(paths.analysis_root)
    paths.output_root = fullfile(paths.data_root,'analysis-output');
else
    paths.output_root = paths.analysis_root;
end
paths.processed_root = fullfile(paths.output_root,'processed');
paths.summary_root = fullfile(paths.output_root,'summary');
paths.script_root = fileparts(mfilename('fullpath'));
end
