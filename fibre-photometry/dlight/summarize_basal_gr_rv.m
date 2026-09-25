function summarize_basal_gr_rv(varargin)
% SUMMARIZE_BASAL_GR_RV  Summarize one GR or RV dLight dataset.

p = inputParser;
addParameter(p,'group','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'figure','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'figure_label','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'subjects',{},@iscell);
addParameter(p,'basal_root','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'summary_root','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'summary_xlim',[-10 45],@(x)isnumeric(x)&&numel(x)==2);
addParameter(p,'summary_boundaries',0,@isnumeric);
addParameter(p,'save_png',false,@islogical);
parse(p,varargin{:});
args = p.Results;

group = upper(args.group);
figure_id = lower(args.figure);
figure_label = args.figure_label;
subjects = args.subjects;
basal_root = args.basal_root;
summary_root = args.summary_root;
file_prefix = [figure_id '_' group];

if ~isfolder(summary_root), mkdir(summary_root); end

all_means = table();
all_auc = table();
all_changes = table();
trace_cells = {};
time_cells = {};
trace_animals = {};

%% Collect per-animal outputs
for i = 1:numel(subjects)
    animal = subjects{i};
    input_file = fullfile(basal_root,animal,[group '_' animal '_basal.mat']);

    if ~isfile(input_file)
        fprintf(2,'[WARN] Missing basal file: %s\n',input_file);
        continue;
    end

    loaded = load(input_file, ...
        'fpx_time','fpx_smooth','basal_table','change_table');

    means = loaded.basal_table(:,{'Interval','StartMin','EndMin','MeanZ'});
    means.Animal = repmat(string(animal),height(means),1);
    means = movevars(means,'Animal','Before',1);
    all_means = [all_means; means]; %#ok<AGROW>

    auc = loaded.basal_table(:,{ ...
        'Interval','StartMin','EndMin', ...
        'TotalAUC','PositiveAUC','NegativeAUC'});
    auc.Animal = repmat(string(animal),height(auc),1);
    auc = movevars(auc,'Animal','Before',1);
    all_auc = [all_auc; auc]; %#ok<AGROW>

    changes = loaded.change_table;
    changes.Animal = repmat(string(animal),height(changes),1);
    changes = movevars(changes,'Animal','Before',1);
    all_changes = [all_changes; changes]; %#ok<AGROW>

    time = loaded.fpx_time(:);
    trace = loaded.fpx_smooth(:);
    n = min(numel(time),numel(trace));
    time_cells{end+1} = time(1:n); %#ok<SAGROW>
    trace_cells{end+1} = trace(1:n); %#ok<SAGROW>
    trace_animals{end+1} = animal; %#ok<SAGROW>
end

%% Write tabular outputs
if ~isempty(all_means)
    writetable(all_means, ...
        fullfile(summary_root,[file_prefix '_basal_means.csv']));
end
if ~isempty(all_auc)
    writetable(all_auc, ...
        fullfile(summary_root,[file_prefix '_basal_auc.csv']));
end
if ~isempty(all_changes)
    writetable(all_changes, ...
        fullfile(summary_root,[file_prefix '_basal_changes.csv']));
end

%% Wide trace and group-mean exports
if ~isempty(trace_cells)
    lower_limit = max(cellfun(@min,time_cells));
    upper_limit = min(cellfun(@max,time_cells));
    common_time = linspace(lower_limit,upper_limit,2000)';
    wide_traces = nan(numel(common_time),numel(trace_cells));
    variable_names = cell(1,numel(trace_cells));

    for i = 1:numel(trace_cells)
        [unique_time,unique_idx] = unique(time_cells{i},'stable');
        wide_traces(:,i) = interp1( ...
            unique_time,trace_cells{i}(unique_idx), ...
            common_time,'linear',NaN);
        variable_names{i} = matlab.lang.makeValidName( ...
            ['sub_' trace_animals{i}]);
    end

    trace_export = array2table([common_time wide_traces], ...
        'VariableNames',[{'TimeMin'},variable_names]);
    writetable(trace_export,fullfile( ...
        summary_root,[file_prefix '_basal_traces_wide.csv']));

    mean_export = table( ...
        common_time, ...
        mean(wide_traces,2,'omitnan'), ...
        std(wide_traces,0,2,'omitnan')./sqrt(sum(isfinite(wide_traces),2)), ...
        sum(isfinite(wide_traces),2), ...
        'VariableNames',{'TimeMin','Mean_zSmooth','SEM','N'});
    writetable(mean_export,fullfile( ...
        summary_root,[file_prefix '_basal_group_mean.csv']));
end

%% Summary trace figure
if ~isempty(trace_cells)
    min_length = min(cellfun(@numel,trace_cells));
    traces = nan(min_length,numel(trace_cells));
    times = nan(min_length,numel(time_cells));

    for i = 1:numel(trace_cells)
        traces(:,i) = trace_cells{i}(1:min_length);
        times(:,i) = time_cells{i}(1:min_length);
    end

    mean_trace = mean(traces,2,'omitnan');
    mean_time = mean(times,2,'omitnan');
    fig = figure( ...
        'Visible','off', ...
        'Units','pixels', ...
        'Position',[100 100 720 440], ...
        'Color','w');
    ax = axes(fig);
    hold(ax,'on');

    for i = 1:size(traces,2)
        valid = isfinite(times(:,i)) & isfinite(traces(:,i));
        if any(valid)
            plot(ax,times(valid,i),traces(valid,i), ...
                'Color',[0.78 0.78 0.78],'LineWidth',0.8);
        end
    end

    valid_mean = isfinite(mean_time) & isfinite(mean_trace);
    plot(ax,mean_time(valid_mean),mean_trace(valid_mean), ...
        'k','LineWidth',2);
    for boundary = args.summary_boundaries(:)'
        if boundary == 0
            xline(ax,boundary,'k:','LineWidth',1);
        else
            xline(ax,boundary,':', ...
                'Color',[0.6 0.6 0.6],'LineWidth',0.8);
        end
    end
    xlim(ax,args.summary_xlim);
    xlabel(ax,'Time (min)');
    ylabel(ax,'z(dF/F)');
    title(ax,sprintf('%s %s (n = %d)', ...
        figure_label,group,size(traces,2)));
    box(ax,'on');

    exportgraphics(fig,fullfile( ...
        summary_root,[file_prefix '_basal_traces.pdf']), ...
        'ContentType','vector');
    if args.save_png
        exportgraphics(fig,fullfile( ...
            summary_root,[file_prefix '_basal_traces.png']), ...
            'Resolution',300);
    end
    close(fig);
end

%% Group mean table
if ~isempty(all_means)
    intervals = unique(all_means.Interval,'stable');
    group_means = table();

    for k = 1:numel(intervals)
        idx = all_means.Interval == intervals(k);
        values = all_means.MeanZ(idx);
        row = table( ...
            intervals(k), ...
            mean(values,'omitnan'), ...
            std(values,'omitnan')/sqrt(sum(isfinite(values))), ...
            sum(isfinite(values)), ...
            'VariableNames',{'Interval','MeanZ','SEM','N'});
        group_means = [group_means; row]; %#ok<AGROW>
    end

    writetable(group_means, ...
        fullfile(summary_root,[file_prefix '_group_means.csv']));
end

fprintf('\n%s %s basal summary complete.\n',figure_label,group);
fprintf('Files written to: %s\n',summary_root);
end
