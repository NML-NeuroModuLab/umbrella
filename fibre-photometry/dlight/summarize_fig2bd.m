function summarize_fig2bd(varargin)
% SUMMARIZE_FIG2BD  Collate summaries and create the four-panel trace figure.

p = inputParser;
addParameter(p,'subjects',{},@iscell);
addParameter(p,'conditions',{},@iscell);
addParameter(p,'basal_root','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'summary_root','',@(s)ischar(s)&&~isempty(s));
parse(p,varargin{:});
args = p.Results;

subjects = args.subjects;
conditions = args.conditions;
basal_root = args.basal_root;
summary_root = args.summary_root;
if ~isfolder(summary_root), mkdir(summary_root); end

max_rows = numel(conditions)*numel(subjects);
mean_rows = cell(max_rows,1);
change_rows = cell(max_rows,1);
auc_rows = cell(max_rows,1);
row_count = 0;
source_traces = struct();

%% Collate tables and source traces
for c = 1:numel(conditions)
    condition = conditions{c};
    trace_times = cell(numel(subjects),1);
    trace_values = cell(numel(subjects),1);
    trace_ids = cell(numel(subjects),1);
    trace_count = 0;

    for i = 1:numel(subjects)
        animal = subjects{i};
        input_file = fullfile(basal_root,condition,animal, ...
            ['basal_' condition '_' animal '.mat']);
        if ~isfile(input_file)
            warning('Missing basal output: %s',input_file);
            continue;
        end

        loaded = load(input_file,'FPX_basalfm','FPX_basal_fm_change', ...
            'FPX_auc','FPX_smooth','FPX_time');
        row_count = row_count+1;

        means = loaded.FPX_basalfm;
        means.AnimalID = string(animal);
        means.Condition = string(condition);
        mean_rows{row_count} = movevars( ...
            means,{'AnimalID','Condition'},'Before',1);

        changes = loaded.FPX_basal_fm_change;
        changes.AnimalID = string(animal);
        changes.Condition = string(condition);
        change_rows{row_count} = movevars( ...
            changes,{'AnimalID','Condition'},'Before',1);

        auc = loaded.FPX_auc;
        auc.AnimalID = repmat(string(animal),height(auc),1);
        auc.Condition = repmat(string(condition),height(auc),1);
        auc_rows{row_count} = movevars( ...
            auc,{'AnimalID','Condition'},'Before',1);

        time = loaded.FPX_time(:);
        trace = loaded.FPX_smooth(:);
        n = min(numel(time),numel(trace));
        keep = time(1:n) >= -10 & time(1:n) <= 30;
        trace_count = trace_count+1;
        trace_times{trace_count} = time(keep);
        trace_values{trace_count} = trace(keep);
        trace_ids{trace_count} = animal;
    end

    if trace_count > 0
        trace_times = trace_times(1:trace_count);
        trace_values = trace_values(1:trace_count);
        trace_ids = trace_ids(1:trace_count);
        common_time = trace_times{1};
        values = nan(numel(common_time),numel(trace_values));
        for i = 1:numel(trace_values)
            if isequal(trace_times{i},common_time)
                values(:,i) = trace_values{i};
            else
                valid = isfinite(trace_times{i}) & isfinite(trace_values{i});
                values(:,i) = interp1(trace_times{i}(valid), ...
                    trace_values{i}(valid),common_time,'linear',NaN);
            end
        end

        source_table = table(common_time,'VariableNames',{'Time'});
        for i = 1:numel(trace_ids)
            source_table.(trace_ids{i}) = values(:,i);
        end
        source_traces.(condition) = source_table;
        writetable(source_table,fullfile(summary_root, ...
            ['fig2bd_' condition '_smoothed_traces_source_data.csv']));
    end
end

if row_count == 0
    error('No Fig. 2b-d basal outputs were found.');
end

mean_rows = mean_rows(1:row_count);
change_rows = change_rows(1:row_count);
auc_rows = auc_rows(1:row_count);
Means = vertcat(mean_rows{:});
Changes = vertcat(change_rows{:});
AUC = vertcat(auc_rows{:});
writetable(Means,fullfile(summary_root,'fig2bd_basal_means.csv'));
writetable(Changes,fullfile(summary_root,'fig2bd_basal_changes.csv'));
writetable(AUC,fullfile(summary_root,'fig2bd_basal_auc.csv'));

%% Four-panel smoothed-trace figure
fig = figure('Visible','off','Color','w','Units','inches', ...
    'Position',[0.5 0.5 10 2.8]);
tiledlayout(1,numel(conditions),'TileSpacing','compact','Padding','compact');
all_axes = gobjects(numel(conditions),1);
all_y = [];

for c = 1:numel(conditions)
    condition = conditions{c};
    all_axes(c) = nexttile;
    hold(all_axes(c),'on');

    if isfield(source_traces,condition)
        source_table = source_traces.(condition);
        time = source_table.Time;
        values = source_table{:,2:end};
        for i = 1:size(values,2)
            plot(all_axes(c),time,values(:,i), ...
                'Color',[0.8 0.8 0.8],'LineWidth',0.6);
        end
        mean_trace = mean(values,2,'omitnan');
        plot(all_axes(c),time,mean_trace,'k','LineWidth',1.8);
        all_y = [all_y; values(:)]; %#ok<AGROW>
    end

    title(all_axes(c),condition,'FontWeight','bold');
    xlabel(all_axes(c),'Time (min)');
    ylabel(all_axes(c),'z dF/F');
    xlim(all_axes(c),[-10 30]);
    box(all_axes(c),'off');
end

finite_y = all_y(isfinite(all_y));
if ~isempty(finite_y)
    y_limits = [min(finite_y) max(finite_y)];
    padding = 0.05*max(diff(y_limits),eps);
    set(all_axes,'YLim',y_limits+[-padding padding]);
end
sgtitle(fig,'Fig. 2b-d dLight traces');

figure_file = fullfile(summary_root,'fig2bd_dlight_traces.pdf');
exportgraphics(fig,figure_file,'ContentType','vector');
close(fig);

save(fullfile(summary_root,'fig2bd_basal_summary.mat'), ...
    'Means','Changes','AUC','source_traces','conditions','subjects');

fprintf('\nFig. 2b-d summary complete.\n');
fprintf('Files written to: %s\n',summary_root);
end
