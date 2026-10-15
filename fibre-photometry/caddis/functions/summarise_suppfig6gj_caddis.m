function results = summarise_suppfig6gj_caddis(sourceDir,outputRoot,cfg)
% SUMMARISE_SUPPFIG6GJ_CADDIS Recreate panels from generated analysis tables.

if nargin < 3 || isempty(cfg), cfg = suppfig6gj_config(); end
assert(isfolder(sourceDir),'Generated source-data folder not found: %s',sourceDir);
if ~isfolder(outputRoot), mkdir(outputRoot); end

gRaw = readSource(sourceDir,cfg.files.panel_g_raw);
gCorrected = readSource(sourceDir,cfg.files.panel_g_corrected);
h = readSource(sourceDir,cfg.files.panel_h);
i = readSource(sourceDir,cfg.files.panel_i);
j = readSource(sourceDir,cfg.files.panel_j);

plotPanelG(gRaw,gCorrected,cfg,outputRoot);
panelHStats = plotPanelH(h,cfg,outputRoot);
plotPanelI(i,cfg,outputRoot);
plotPanelJ(j,outputRoot);

writetable(panelHStats,fullfile(outputRoot,'suppfig6h_statistics.csv'));
results = struct('panel_h_statistics',panelHStats, ...
    'output_root',outputRoot,'source_root',sourceDir);
end

function T = readSource(root,name)
path = fullfile(root,name);
assert(isfile(path),'Required source table not found: %s',path);
T = readtable(path,'TextType','string','VariableNamingRule','preserve');
end

function plotPanelG(raw,corrected,cfg,out)
requireColumns(raw,{'Time_min','Downsampled465','Downsampled560', ...
    'BleachFit465','BleachFit560'});
requireColumns(corrected,{'Time_min','Slow465_60s_pctBaseline', ...
    'Slow560_60s_pctBaseline'});
showRaw = raw.Time_min>=cfg.example_window_min(1) & ...
    raw.Time_min<=cfg.example_window_min(2);
showCorrected = corrected.Time_min>=cfg.example_window_min(1) & ...
    corrected.Time_min<=cfg.example_window_min(2);
fig = figure('Color','w','Visible','off','Position',[100 100 700 500]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
ax=nexttile;
yyaxis(ax,'left');
plot(ax,raw.Time_min(showRaw),raw.Downsampled465(showRaw),'k'); hold(ax,'on');
plot(ax,raw.Time_min(showRaw),raw.BleachFit465(showRaw),'k--');
ylabel(ax,'465-nm fluorescence');
yyaxis(ax,'right');
plot(ax,raw.Time_min(showRaw),raw.Downsampled560(showRaw),'Color',[.2 .75 .75]);
plot(ax,raw.Time_min(showRaw),raw.BleachFit560(showRaw),'--','Color',[.2 .75 .75]);
ylabel(ax,'560-nm fluorescence'); xlabel(ax,'Time (min)'); title(ax,'g'); box(ax,'off');
ax=nexttile;
plot(ax,corrected.Time_min(showCorrected), ...
    corrected.Slow465_60s_pctBaseline(showCorrected),'k'); hold(ax,'on');
plot(ax,corrected.Time_min(showCorrected), ...
    corrected.Slow560_60s_pctBaseline(showCorrected),'Color',[.2 .75 .75]);
set(ax,'YDir','reverse'); xlabel(ax,'Time (min)');
ylabel(ax,'Normalised fluorescence (% baseline)');
legend(ax,{'465 nm','560 nm'},'Box','off'); box(ax,'off');
exportgraphics(fig,fullfile(out,'suppfig6g_caddis.pdf'),'ContentType','vector');
close(fig);
end

function statsTable = plotPanelH(T,cfg,out)
requireColumns(T,{'Cohort','Animal','SlowCorrelationR'});
r = T.SlowCorrelationR;
valid = isfinite(r) & r>-1 & r<1;
r = r(valid); z = atanh(r);
meanR = tanh(mean(z));
[~,p,ci,stats] = ttest(z,0);
rng(cfg.random_seed);
bootR = nan(cfg.n_bootstrap,1);
for b=1:cfg.n_bootstrap
    bootR(b)=tanh(mean(z(randi(numel(z),numel(z),1))));
end
bootCI = prctile(bootR,[2.5 97.5]);
fig = figure('Color','w','Visible','off','Position',[100 100 300 430]); hold on;
scatter(ones(size(r)),r,35,'k','filled');
plot([.8 1.2],[meanR meanR],'k','LineWidth',1.5);
xlim([.7 1.3]); xticks(1); xticklabels({'465 vs 560'});
ylabel('Slow-signal Pearson r'); ylim([0 1]); title('h'); box off;
exportgraphics(fig,fullfile(out,'suppfig6h_caddis.pdf'),'ContentType','vector');
close(fig);
statsTable = table(numel(r),meanR,bootCI(1),bootCI(2), ...
    stats.tstat,stats.df,p,tanh(ci(1)),tanh(ci(2)), ...
    'VariableNames',{'N','FisherBackTransformedMeanR','BootstrapCILow', ...
    'BootstrapCIHigh','TStatistic','DF','PValue','TTestCILowR','TTestCIHighR'});
end

function plotPanelI(T,cfg,out)
requireColumns(T,{'Time_min','Sequential_Mean','Simultaneous_Mean'});
t = T.Time_min;
show = t>=cfg.trace_window_min(1) & t<=cfg.trace_window_min(2);
seqNames = T.Properties.VariableNames(startsWith(T.Properties.VariableNames,'Sequential_'));
seqNames = setdiff(seqNames,{'Sequential_Mean'},'stable');
simNames = T.Properties.VariableNames(startsWith(T.Properties.VariableNames,'Simultaneous_'));
simNames = setdiff(simNames,{'Simultaneous_Mean'},'stable');
colours = lines(max(numel(seqNames),numel(simNames)));
fig = figure('Color','w','Visible','off','Position',[100 100 760 350]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
plotTraces(nexttile,T,t,show,seqNames,'Sequential_Mean',colours,'Sequential fit');
plotTraces(nexttile,T,t,show,simNames,'Simultaneous_Mean',colours,'Simultaneous fit');
exportgraphics(fig,fullfile(out,'suppfig6i_caddis.pdf'),'ContentType','vector');
close(fig);
end

function plotTraces(ax,T,t,show,names,meanName,colours,titleText)
hold(ax,'on');
for k=1:numel(names), plot(ax,t(show),T.(names{k})(show),'Color',colours(k,:)); end
plot(ax,t(show),T.(meanName)(show),'k','LineWidth',2);
xline(ax,0,'k:'); xline(ax,15,'k:'); set(ax,'YDir','reverse');
xlabel(ax,'Time (min)'); ylabel(ax,'z dF/F'); title(ax,titleText); box(ax,'off');
end

function plotPanelJ(T,out)
requireColumns(T,{'Condition','Sequential','Simultaneous'});
fig = figure('Color','w','Visible','off','Position',[100 100 330 430]); hold on;
colours = [0.47 .67 .19; .85 .33 .10; 0 .45 .74];
for k=1:height(T)
    plot([1 2],[T.Sequential(k) T.Simultaneous(k)],'-o', ...
        'Color',colours(min(k,size(colours,1)),:), ...
        'MarkerFaceColor',colours(min(k,size(colours,1)),:));
end
xlim([.7 2.3]); xticks([1 2]); xticklabels({'Sequential','Simultaneous'});
ylabel('Between-animal SD (z dF/F)'); title('j');
legend(cellstr(T.Condition),'Box','off','Location','best'); box off;
exportgraphics(fig,fullfile(out,'suppfig6j_caddis.pdf'),'ContentType','vector');
close(fig);
end

function requireColumns(T,names)
missing = setdiff(names,T.Properties.VariableNames);
assert(isempty(missing),'Source table is missing: %s',strjoin(missing,', '));
end
