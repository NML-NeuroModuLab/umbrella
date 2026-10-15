function results = summarise_suppfig6ko_exrai(generatedRoot,outputRoot,cfg)
% SUMMARISE_SUPPFIG6KO_EXRAI Recreate Supplemental Fig. 6k-o panels.

if nargin < 3 || isempty(cfg), cfg = suppfig6ko_config(); end
assert(isfolder(generatedRoot), ...
    'Generated analysis-table folder not found: %s',generatedRoot);
if ~isfolder(outputRoot), mkdir(outputRoot); end

k = readSource(generatedRoot,cfg.files.panel_k);
l = readSource(generatedRoot,cfg.files.panel_l);
m = readSource(generatedRoot,cfg.files.panel_m);
mStats = readSource(generatedRoot,cfg.files.panel_m_stats);
n = readSource(generatedRoot,cfg.files.panel_n);
o = readSource(generatedRoot,cfg.files.panel_o);
oStats = readSource(generatedRoot,cfg.files.panel_o_stats);

plotPanelK(k,cfg,outputRoot);
plotPanelL(l,cfg,outputRoot);
plotPanelM(m,outputRoot);
plotPanelN(n,cfg,outputRoot);
plotPanelO(o,outputRoot);

writetable(mStats,fullfile(outputRoot,'suppfig6m_statistics.csv'));
writetable(oStats,fullfile(outputRoot,'suppfig6o_statistics.csv'));
results = struct('panel_m_statistics',mStats, ...
    'panel_o_statistics',oStats,'output_root',outputRoot, ...
    'generated_source_root',generatedRoot);
end

function T = readSource(root,name)
path = fullfile(root,name);
assert(isfile(path),'Required generated analysis table not found: %s',path);
T = readtable(path,'TextType','string','VariableNamingRule','preserve');
end

function plotPanelK(T,cfg,out)
requireColumns(T,{'Time_min','Fitted_405_nm','Signal_465_nm'});
show = T.Time_min>=cfg.panel_k_window_min(1) & T.Time_min<=cfg.panel_k_window_min(2);
fig = figure('Color','w','Visible','off','Position',[100 100 500 330]);
ax=axes(fig); yyaxis(ax,'left');
plot(ax,T.Time_min(show),T.Fitted_405_nm(show),'Color',[.55 .15 .55]);
ylabel(ax,'Fitted 405 nm');
yyaxis(ax,'right');
plot(ax,T.Time_min(show),T.Signal_465_nm(show),'Color',[0 .6 .85]);
ylabel(ax,'465 nm'); xlabel(ax,'Time (min)'); title(ax,'k'); box(ax,'off');
exportgraphics(fig,fullfile(out,'suppfig6k_exrai.pdf'),'ContentType','vector');
close(fig);
end

function plotPanelL(T,cfg,out)
requireColumns(T,{'Subject','Time_min','dRR'});
subjects = unique(string(T.Subject),'stable');
fig = figure('Color','w','Visible','off','Position',[100 100 500 430]);
tiledlayout(numel(subjects),1,'TileSpacing','compact','Padding','compact');
for i=1:numel(subjects)
    ax=nexttile; rows=string(T.Subject)==subjects(i) & ...
        T.Time_min>=cfg.panel_l_window_min(1) & T.Time_min<=cfg.panel_l_window_min(2);
    plot(ax,T.Time_min(rows),T.dRR(rows),'k');
    ylabel(ax,'dR/R'); title(ax,subjects(i)); box(ax,'off');
    if i==numel(subjects), xlabel(ax,'Time (min)'); end
end
exportgraphics(fig,fullfile(out,'suppfig6l_exrai.pdf'),'ContentType','vector');
close(fig);
end

function plotPanelM(T,out)
requireColumns(T,{'Subject','RAC_Peak_Administration_1','RAC_Peak_Administration_2'});
x=T.RAC_Peak_Administration_1; y=T.RAC_Peak_Administration_2;
fig=figure('Color','w','Visible','off','Position',[100 100 400 400]);
scatter(x,y,35,'r','filled'); hold on;
lims=[min([x;y]) max([x;y])]; plot(lims,lims,'k--');
for i=1:height(T), text(x(i),y(i),['  ' char(string(T.Subject(i)))],'FontSize',8); end
xlim(lims); ylim(lims); axis square;
xlabel('Raclopride peak 1'); ylabel('Raclopride peak 2'); title('m'); box off;
exportgraphics(fig,fullfile(out,'suppfig6m_exrai.pdf'),'ContentType','vector');
close(fig);
end

function plotPanelN(T,cfg,out)
requireColumns(T,{'Time_min'});
names=T.Properties.VariableNames;
zNames=names(endsWith(names,'_conventional_z'));
scaledNames=names(endsWith(names,'_RACnormalised'));
assert(~isempty(zNames) && numel(zNames)==numel(scaledNames), ...
    'Panel n generated table has unexpected trace columns.');
show=T.Time_min>=cfg.panel_n_window_min(1) & T.Time_min<=cfg.panel_n_window_min(2);
colours=lines(numel(zNames));
fig=figure('Color','w','Visible','off','Position',[100 100 540 480]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
ax=nexttile; hold(ax,'on');
for i=1:numel(zNames), plot(ax,T.Time_min(show),T.(zNames{i})(show),'Color',colours(i,:)); end
xline(ax,0,'k:'); xline(ax,15,'k:'); ylabel(ax,'z-score'); title(ax,'n'); box(ax,'off');
ax=nexttile; hold(ax,'on');
for i=1:numel(scaledNames), plot(ax,T.Time_min(show),T.(scaledNames{i})(show),'Color',colours(i,:)); end
xline(ax,0,'k:'); xline(ax,15,'k:'); xlabel(ax,'Time (min)');
ylabel(ax,'Scaled dR/R'); box(ax,'off');
exportgraphics(fig,fullfile(out,'suppfig6n_exrai.pdf'),'ContentType','vector');
close(fig);
end

function plotPanelO(T,out)
required={'Baseline_z_positiveAUC_relative_to_group_mean', ...
    'RVpeak_scaled_positiveAUC_relative_to_group_mean'};
requireColumns(T,required);
x=T.(required{1}); y=T.(required{2});
fig=figure('Color','w','Visible','off','Position',[100 100 330 430]); hold on;
for i=1:height(T), plot([1 2],[x(i) y(i)],'-o','Color',[.25 .25 .25]); end
yline(1,'k:'); xlim([.7 2.3]); xticks([1 2]);
xticklabels({'Baseline z-score','RAC-peak scaled'});
ylabel('Positive AUC / group mean'); title('o'); box off;
exportgraphics(fig,fullfile(out,'suppfig6o_exrai.pdf'),'ContentType','vector');
close(fig);
end

function requireColumns(T,names)
missing=setdiff(names,T.Properties.VariableNames);
assert(isempty(missing),'Source table is missing: %s',strjoin(missing,', '));
end
