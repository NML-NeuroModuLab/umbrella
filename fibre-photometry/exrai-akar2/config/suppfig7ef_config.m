function cfg = suppfig7ef_config(source_project_root,figure_root,source_analysis_root)
% SUPPFIG7EF_CONFIG Configuration for Supplemental Fig. 7e-f.
%
% Supplemental Fig. 7e-f is a 10-minute-bin analysis of the RV recordings
% already preprocessed and normalized for the Fig. 3f, 3i, and 3l set.

if nargin < 2 || isempty(source_project_root) || isempty(figure_root)
    paths = exrai_paths('suppfig7ef');
    source_project_root = paths.source_project_root;
    figure_root = paths.project_root;
    source_analysis_root = paths.source_analysis_root;
elseif nargin < 3
    source_analysis_root = '';
end

source_cfg = fig3fil_config(source_project_root,source_analysis_root);

cfg.figure = 'suppfig7ef';
cfg.figure_label = 'Supplemental Fig. 7e-f';
cfg.sensor = 'ExRaiAKAR2';
cfg.source_figure = 'fig3fil';
cfg.source_project_root = source_project_root;
cfg.project_root = figure_root;
cfg.processed_root = source_cfg.processed_root;
cfg.summary_root = fullfile(figure_root,'processing');
cfg.subjects = source_cfg.subjects;

is_rv = strcmp({source_cfg.sessions.treatment},'RV');
cfg.sessions = source_cfg.sessions(is_rv);

cfg.analysis.treatment = 'RV';
cfg.analysis.intervals = [ ...
   -10.0   0.0; ...
     0.0  10.0; ...
    10.0  20.0; ...
    20.0  30.0];
cfg.analysis.labels = {'Baseline','T1_1','T1_2','T1_3'};
cfg.analysis.carry_forward_tail = true;
end
