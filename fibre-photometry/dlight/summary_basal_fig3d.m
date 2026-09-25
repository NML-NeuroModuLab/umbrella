%% SUMMARY_BASAL_FIG3D
% Group and per-animal summary of Fig. 3d basal fluorescence.
%
% This is deliberately limited to basal-fluorescence outputs.

clear; clc;

paths = dlight_paths('fig3d');
source_root = paths.output_root;
summary_root = fullfile(source_root,'summary');

if ~isfolder(summary_root), mkdir(summary_root); end

subjects = {'032417','032418','032419','032421','032422','032423','032426','035031','035032'};

% Fig. 3d treatment map.
animals_map = {
    '032417','RAC','GBR'
    '032418','RAC','GBR'
    '032419','VEH','GBR'
    '032421','VEH','GBR'
    '032422','RAC','GBR'
    '032423','VEH','GBR'
    '032426','RAC','GBR'
    '035031','RAC','GBR'
    '035032','VEH','GBR'
    };

% Load per-animal basal outputs.
rows = table();

for i = 1:numel(subjects)

    animal = subjects{i};
    f = fullfile(source_root,'test',animal, ...
        ['test_',animal,'_basal-fluorescence.mat']);

    if ~isfile(f)
        fprintf('[WARN] Missing basal output: %s\n',f);
        continue;
    end

    S = load(f);

    maprow = find(strcmp(animals_map(:,1),animal),1,'first');
    if isempty(maprow)
        drug1 = "";
        drug2 = "";
    else
        drug1 = string(animals_map{maprow,2});
        drug2 = string(animals_map{maprow,3});
    end

    T = S.BasalFluorescence;

    rows = [rows; table( ...
        string(animal),drug1,drug2, ...
        T.Baseline,T.T1,T.T2, ...
        S.BasalFluorescenceChange.ChangeT1, ...
        S.BasalFluorescenceChange.ChangeT2, ...
        'VariableNames',{'AnimalID','Drug1','Drug2', ...
        'Baseline','T1','T2','ChangeT1','ChangeT2'})]; %#ok<AGROW>
end

writetable(rows,fullfile(summary_root,'fig3d_basal_fluorescence_summary.csv'));

% Long-form AUC export.
auc_rows = table();

for i = 1:numel(subjects)

    animal = subjects{i};
    f = fullfile(source_root,'test',animal, ...
        ['test_',animal,'_basal-fluorescence.mat']);

    if ~isfile(f), continue; end
    S = load(f);

    A = S.AUC;
    labels = ["Baseline";"T1";"T2"];
    n = min(height(A),numel(labels));

    tr = strings(n,1);
    for k = 1:n
        tr(k) = labels(k);
    end

    auc_rows = [auc_rows; table( ...
        repmat(string(animal),n,1), ...
        tr, ...
        A.IntervalStart(1:n), ...
        A.IntervalEnd(1:n), ...
        A.TotalArea(1:n), ...
        A.PositiveArea(1:n), ...
        A.NegativeArea(1:n), ...
        A.TailMean(1:n), ...
        'VariableNames',{'AnimalID','Interval','StartMin','EndMin', ...
        'TotalAUC','PositiveAUC','NegativeAUC','TailMean'})]; %#ok<AGROW>
end

writetable(auc_rows,fullfile(summary_root,'fig3d_basal_auc_summary.csv'));

fprintf('\nFig. 3d basal summary complete.\n');
fprintf('Files written to: %s\n',summary_root);
