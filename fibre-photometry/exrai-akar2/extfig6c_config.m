function cfg = extfig6c_config(source_project_root, figure_root)
% EXTFIG6C_CONFIG  Configuration for the Extended Data Fig. 6c analysis.
%
% Extended Data Fig. 6c is a 10-minute-bin analysis of the RV recordings
% already preprocessed and normalized for the Fig. 3f/k ExRaiAKAR2 set.

if nargin < 2 || isempty(source_project_root) || isempty(figure_root)
    paths = exrai_paths('extfig6c');
    source_project_root = paths.source_project_root;
    figure_root = paths.project_root;
end

source_cfg = fig3fk_config(source_project_root);

cfg.figure = 'extfig6c';
cfg.figure_label = 'Extended Data Fig. 6c';
cfg.sensor = 'ExRaiAKAR2';
cfg.source_figure = 'fig3fk';
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
