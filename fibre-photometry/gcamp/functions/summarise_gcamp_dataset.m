function summary = summarise_gcamp_dataset(cfg)
% SUMMARISE_GCAMP_DATASET Export GCaMP source tables and summary figure.

assert(nargin>=1 && isstruct(cfg), ...
    'A GCaMP figure configuration is required.');
assert(isfield(cfg,'summary') && isstruct(cfg.summary), ...
    'The configuration has no cfg.summary settings.');
required = {'subject_csv','minute_csv','group_csv','figure_title', ...
    'figure_pdf','mat_file'};
for index = 1:numel(required)
    assert(isfield(cfg.summary,required{index}), ...
        'Configuration is missing cfg.summary.%s.',required{index});
end

if ~isfolder(cfg.summary_root), mkdir(cfg.summary_root); end
rows = cell(numel(cfg.sessions),1);
minute_rows = cell(numel(cfg.sessions),1);

for index = 1:numel(cfg.sessions)
    session = cfg.sessions(index);
    folder = fullfile(cfg.processed_root,session.group,session.subject);
    file = fullfile(folder, ...
        ['test_' session.group '_' session.subject '_transients.mat']);
    assert(isfile(file),'Missing transient output: %s',file);
    data = load(file,'section_summary','minute_summary');
    rows{index} = data.section_summary;
    minute = data.minute_summary;
    minute.subject = repmat(string(session.subject),height(minute),1);
    minute.group = repmat(string(session.group),height(minute),1);
    minute_rows{index} = movevars(minute,{'subject','group'},'Before',1);
end

by_subject = vertcat(rows{:});
per_minute = vertcat(minute_rows{:});
writetable(by_subject,fullfile(cfg.summary_root,cfg.summary.subject_csv));
writetable(per_minute,fullfile(cfg.summary_root,cfg.summary.minute_csv));

epochs = {'baseline','t1','t2'};
group_rows = cell(numel(cfg.groups)*numel(epochs),1);
row = 0;
for group_index = 1:numel(cfg.groups)
    group = cfg.groups{group_index};
    group_mask = strcmpi(by_subject.group,group);
    for epoch_index = 1:numel(epochs)
        row = row+1;
        variable = [epochs{epoch_index} '_transients_per_min'];
        values = by_subject.(variable)(group_mask);
        n = nnz(isfinite(values));
        group_rows{row} = table( ...
            string(group),string(epochs{epoch_index}),n, ...
            mean(values,'omitnan'),std(values,'omitnan')/sqrt(n), ...
            'VariableNames',{'group','epoch','n', ...
            'mean_transients_per_min','sem_transients_per_min'});
    end
end
group_summary = vertcat(group_rows{:});
writetable(group_summary,fullfile(cfg.summary_root,cfg.summary.group_csv));

fig = figure('Visible','off','Color','w','Units','inches', ...
    'Position',[1 1 8.5 3]);
tiledlayout(1,numel(cfg.groups),'TileSpacing','compact','Padding','compact');
highlight = {[0.65 0.65 0.65],[0.95 0.45 0.25],[0.45 0.35 0.95]};
for group_index = 1:numel(cfg.groups)
    group = cfg.groups{group_index};
    mask = strcmpi(by_subject.group,group);
    values = [by_subject.baseline_transients_per_min(mask), ...
        by_subject.t1_transients_per_min(mask), ...
        by_subject.t2_transients_per_min(mask)];
    ax = nexttile;
    hold(ax,'on');
    for subject_index = 1:size(values,1)
        plot(ax,1:3,values(subject_index,:),'-o', ...
            'Color',[0.85 0.85 0.85], ...
            'MarkerFaceColor',[0.85 0.85 0.85], ...
            'MarkerEdgeColor','none','MarkerSize',3);
    end
    means = mean(values,1,'omitnan');
    sem = std(values,0,1,'omitnan')./sqrt(sum(isfinite(values),1));
    errorbar(ax,1:3,means,sem,'-o','Color','k','LineWidth',1.3, ...
        'MarkerFaceColor','w','MarkerEdgeColor','k','MarkerSize',5);
    scatter(ax,3,means(3),34,highlight{group_index},'filled');
    title(ax,group);
    ylabel(ax,'Ca^{2+} transients/min');
    xlim(ax,[0.7 3.3]);
    xticks(ax,1:3);
    xticklabels(ax,{'BL','T1','T2'});
    box(ax,'off');
end
sgtitle(fig,cfg.summary.figure_title);
figure_file = fullfile(cfg.summary_root,cfg.summary.figure_pdf);
exportgraphics(fig,figure_file,'ContentType','vector');
close(fig);

summary = struct('by_subject',by_subject,'per_minute',per_minute, ...
    'group_summary',group_summary,'figure_file',figure_file);
save(fullfile(cfg.summary_root,cfg.summary.mat_file), ...
    'by_subject','per_minute','group_summary');
fprintf('%s summary complete: %s\n',cfg.figure_label,cfg.summary_root);
end
