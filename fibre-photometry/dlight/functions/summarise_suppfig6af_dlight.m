function results = summarise_suppfig6af_dlight(processedRoot,outputRoot,cfg)
% SUMMARISE_SUPPFIG6AF_DLIGHT Recreate Supplemental Fig. 6a-f panels.
%
% Input CSV files must first be generated from raw Parquet recordings by
% process_suppfig6af_dlight.

if nargin < 3 || isempty(cfg), cfg = suppfig6af_config(); end
sourceDir = processedRoot;
assert(isfolder(sourceDir), ...
    ['Processed-data folder not found: %s\nRun ' ...
    'workflows/suppfig6af/batch_processing_suppfig6af.m first.'],sourceDir);
if ~isfolder(outputRoot), mkdir(outputRoot); end

ab = readSource(sourceDir,cfg.files.panel_ab);
c = readSource(sourceDir,cfg.files.panel_c);
d = readSource(sourceDir,cfg.files.panel_d);
e = readSource(sourceDir,cfg.files.panel_e);
f = readSource(sourceDir,cfg.files.panel_f);

plotPanelAB(ab,cfg,outputRoot);
panelCStats = plotPanelC(c,outputRoot);
plotPanelD(d,cfg,outputRoot);
panelEStats = plotPanelE(e,outputRoot);
plotPanelF(f,cfg,outputRoot);

writetable(panelCStats,fullfile(outputRoot,'suppfig6c_statistics.csv'));
writetable(panelEStats,fullfile(outputRoot,'suppfig6e_statistics.csv'));
results = struct('panel_c_statistics',panelCStats, ...
    'panel_e_statistics',panelEStats,'output_root',outputRoot, ...
    'processed_root',processedRoot);
end

function T = readSource(root,name)
path = fullfile(root,name);
assert(isfile(path),'Required source table not found: %s',path);
T = readtable(path,'TextType','string','VariableNamingRule','preserve');
end

function plotPanelAB(T,cfg,out)
required = {'Time_min','Uncorrected465','UncorrectedScaled405', ...
    'BleachCorrected465','BleachCorrectedScaled405'};
requireColumns(T,required);
show = T.Time_min >= cfg.panel_ab_window_min(1) & ...
    T.Time_min <= cfg.panel_ab_window_min(2);
fig = figure('Color','w','Visible','off','Position',[100 100 700 300]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot(T.Time_min(show),T.Uncorrected465(show),'Color',[0 .45 .74]); hold on;
plot(T.Time_min(show),T.UncorrectedScaled405(show),'Color',[.85 .33 .10]);
xlabel('Time (min)'); ylabel('Slow fluorescence (a.u.)');
title('a  Uncorrected'); legend({'465 nm','Scaled 405 nm'},'Box','off'); box off;
nexttile;
plot(T.Time_min(show),T.BleachCorrected465(show),'Color',[0 .45 .74]); hold on;
plot(T.Time_min(show),T.BleachCorrectedScaled405(show),'Color',[.85 .33 .10]);
xlabel('Time (min)'); ylabel('Slow fluorescence (a.u.)');
title('b  Bleach corrected'); legend({'465 nm','Scaled 405 nm'},'Box','off'); box off;
exportgraphics(fig,fullfile(out,'suppfig6ab_dlight.pdf'),'ContentType','vector');
close(fig);
end

function statsTable = plotPanelC(T,out)
required = {'Cohort','AnimalID','RMSE_Uncorrected','RMSE_BleachCorrected'};
requireColumns(T,required);
fig = figure('Color','w','Visible','off','Position',[100 100 330 430]); hold on;
for i = 1:height(T)
    plot([1 2],[T.RMSE_Uncorrected(i) T.RMSE_BleachCorrected(i)], ...
        '-o','Color',[.55 .75 .40],'MarkerFaceColor',[.55 .75 .40]);
end
xlim([.7 2.3]); xticks([1 2]);
xticklabels({'Uncorrected','Bleach corrected'});
ylabel('Slow-component fitting error (RMSE)'); title('c'); box off;
exportgraphics(fig,fullfile(out,'suppfig6c_dlight.pdf'),'ContentType','vector');
close(fig);

difference = T.RMSE_Uncorrected-T.RMSE_BleachCorrected;
[p,~,s] = signrank(T.RMSE_Uncorrected,T.RMSE_BleachCorrected,'tail','right');
statsTable = table(height(T),mean(difference),median(difference),p,s.signedrank, ...
    'VariableNames',{'N','MeanReduction','MedianReduction','PValue','SignedRank'});
end

function plotPanelD(T,cfg,out)
required = {'Time_min','Smoothed405','Fit405_10min','Fit405_30min', ...
    'Fit405_FullTrace','Smoothed465','Fit465_10min','Fit465_30min', ...
    'Fit465_FullTrace'};
requireColumns(T,required);
show = T.Time_min >= cfg.panel_d_window_min(1) & ...
    T.Time_min <= cfg.panel_d_window_min(2);
fig = figure('Color','w','Visible','off','Position',[100 100 380 600]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
plotFits(nexttile,T,show,'405');
plotFits(nexttile,T,show,'465');
exportgraphics(fig,fullfile(out,'suppfig6d_dlight.pdf'),'ContentType','vector');
close(fig);
end

function plotFits(ax,T,show,wavelength)
trace = ['Smoothed' wavelength];
plot(ax,T.Time_min(show),T.(trace)(show),'Color',[.75 .75 .75]); hold(ax,'on');
plot(ax,T.Time_min(show),T.(['Fit' wavelength '_10min'])(show),'Color',[0 .45 .74]);
plot(ax,T.Time_min(show),T.(['Fit' wavelength '_30min'])(show),'Color',[.85 .33 .10]);
plot(ax,T.Time_min(show),T.(['Fit' wavelength '_FullTrace'])(show),'k');
xlabel(ax,'Time (min)'); ylabel(ax,[wavelength ' nm']); title(ax,'d'); box(ax,'off');
legend(ax,{'Smoothed','10 min','30 min','Full trace'},'Box','off');
end

function statsTable = plotPanelE(T,out)
required = {'Cohort','AnimalID','FitWindow', ...
    'AbsoluteEndpointDifference405_percent','AbsoluteEndpointDifference465_percent'};
requireColumns(T,required);
keys = unique(string(T.AnimalID),'stable');
v405 = nan(numel(keys),2); v465 = v405;
for i = 1:numel(keys)
    rows = string(T.AnimalID)==keys(i);
    ten = rows & string(T.FitWindow)=="10 min";
    thirty = rows & string(T.FitWindow)=="30 min";
    if nnz(ten)==1 && nnz(thirty)==1
        v405(i,:) = [T.AbsoluteEndpointDifference405_percent(ten), ...
            T.AbsoluteEndpointDifference405_percent(thirty)];
        v465(i,:) = [T.AbsoluteEndpointDifference465_percent(ten), ...
            T.AbsoluteEndpointDifference465_percent(thirty)];
    end
end
fig = figure('Color','w','Visible','off','Position',[100 100 600 360]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
paired(nexttile,v405,'405 nm'); paired(nexttile,v465,'465 nm');
exportgraphics(fig,fullfile(out,'suppfig6e_dlight.pdf'),'ContentType','vector');
close(fig);

metrics = {'AbsoluteEndpointDifference405_percent', ...
    'AbsoluteEndpointDifference465_percent'};
labels = {'405 nm','465 nm'};
statsTable = table();
for m = 1:numel(metrics)
    ten = T{string(T.FitWindow)=="10 min",metrics{m}};
    thirty = T{string(T.FitWindow)=="30 min",metrics{m}};
    valid = isfinite(ten)&isfinite(thirty);
    difference = ten(valid)-thirty(valid);
    [p,~,s] = signrank(ten(valid),thirty(valid));
    statsTable = [statsTable; table(string(labels{m}),nnz(valid), ...
        mean(difference),median(difference),p,s.signedrank, ...
        'VariableNames',{'Channel','N','MeanReduction10minus30', ...
        'MedianReduction10minus30','PValue','SignedRank'})]; %#ok<AGROW>
end
end

function paired(ax,values,label)
hold(ax,'on');
for i=1:size(values,1), plot(ax,[1 2],values(i,:),'-o','Color',[.55 .75 .40]); end
xlim(ax,[.7 2.3]); xticks(ax,[1 2]); xticklabels(ax,{'10 min','30 min'});
ylabel(ax,'Endpoint difference (% bleach range)'); title(ax,['e  ' label]); box(ax,'off');
end

function plotPanelF(T,cfg,out)
required = {'TimeRelativeToRAC_min','Raw405','HabituationDerivedFit405', ...
    'Raw465','HabituationDerivedFit465','BleachCorrected465', ...
    'Scaled405Reference','dFF'};
requireColumns(T,required);
t = T.TimeRelativeToRAC_min;
show = t >= cfg.panel_f_window_min(1) & t <= cfg.panel_f_window_min(2);
fig = figure('Color','w','Visible','off','Position',[100 100 720 480]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
plotPair(nexttile,t(show),T.Raw405(show),T.HabituationDerivedFit405(show), ...
    '405 nm','Raw','Bleaching fit');
plotPair(nexttile,t(show),T.Raw465(show),T.HabituationDerivedFit465(show), ...
    '465 nm','Raw','Bleaching fit');
plotPair(nexttile,t(show),T.BleachCorrected465(show),T.Scaled405Reference(show), ...
    'Bleach corrected','465 nm','Scaled 405 nm');
ax=nexttile; plot(ax,t(show),T.dFF(show),'Color',[.20 .70 .20]);
xlabel(ax,'Time (min)'); ylabel(ax,'dF/F'); title(ax,'f'); box(ax,'off');
exportgraphics(fig,fullfile(out,'suppfig6f_dlight.pdf'),'ContentType','vector');
close(fig);
end

function plotPair(ax,t,y1,y2,ylabelText,name1,name2)
plot(ax,t,y1,'Color',[.65 .65 .65]); hold(ax,'on');
plot(ax,t,y2,'Color',[.15 .15 .15]);
xlabel(ax,'Time (min)'); ylabel(ax,ylabelText); title(ax,'f');
legend(ax,{name1,name2},'Box','off'); box(ax,'off');
end

function requireColumns(T,names)
missing = setdiff(names,T.Properties.VariableNames);
assert(isempty(missing),'Source table is missing: %s',strjoin(missing,', '));
end
