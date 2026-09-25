function output = process_basal_fig2bd(varargin)
% PROCESS_BASAL_FIG2BD  Prepare smoothed traces and historical summaries.

p = inputParser;
addParameter(p,'input_file','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'animal','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'condition','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'output_root','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'smooth_window',3600,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'save_figure',false,@islogical);
parse(p,varargin{:});
args = p.Results;

if ~isfile(args.input_file)
    error('Processed input file not found: %s',args.input_file);
end
loaded = load(args.input_file,'FPX_zdFF','FPX_time');
if ~isfield(loaded,'FPX_zdFF') || ~isfield(loaded,'FPX_time')
    error('Input file must contain FPX_zdFF and FPX_time.');
end

FPX_zdFF = loaded.FPX_zdFF(:);
FPX_time = loaded.FPX_time(:);
n = min(numel(FPX_zdFF),numel(FPX_time));
FPX_zdFF = FPX_zdFF(1:n);
FPX_time = FPX_time(1:n);
FPX_smooth = movmean(FPX_zdFF,args.smooth_window,'omitnan');

mean_intervals = [-10.1 -0.1; 5 14.9; 20 29.9];
auc_intervals = [-10 0; 0 15; 15 30];
means = nan(1,3);
for k = 1:3
    idx = FPX_time > mean_intervals(k,1) & ...
        FPX_time <= mean_intervals(k,2);
    if ~any(idx)
        error('Analysis window %d is empty for %s %s.', ...
            k,args.animal,args.condition);
    end
    means(k) = mean(FPX_smooth(idx),'omitnan');
end

FPX_basalfm = array2table(means, ...
    'VariableNames',{'Baseline','T1','T2'});
FPX_basal_fm_change = table( ...
    means(2)-means(1),means(3)-means(2), ...
    'VariableNames',{'T1_minus_Baseline','T2_minus_T1'});

areas = nan(3,3);
for k = 1:3
    idx = FPX_time >= auc_intervals(k,1) & ...
        FPX_time <= auc_intervals(k,2);
    x = FPX_time(idx);
    y = FPX_smooth(idx);
    if numel(x) < 2, continue; end

    areas(k,1) = trapz(x,y);
    negative_area = 0;
    positive_area = 0;
    for j = 1:numel(x)-1
        segment_area = trapz(x(j:j+1),y(j:j+1));
        if segment_area < 0
            negative_area = negative_area+segment_area;
        else
            positive_area = positive_area+segment_area;
        end
    end
    areas(k,2:3) = [negative_area positive_area];
end

FPX_auc = table( ...
    auc_intervals(:,1),auc_intervals(:,2), ...
    areas(:,1),areas(:,2),areas(:,3), ...
    'VariableNames',{'IntervalStart','IntervalEnd','TotalArea', ...
    'NegativeAreaWithinInterval','PositiveAreaWithinInterval'});

save_dir = fullfile(args.output_root,args.condition,args.animal);
if ~isfolder(save_dir), mkdir(save_dir); end
output_file = fullfile(save_dir, ...
    ['basal_' args.condition '_' args.animal '.mat']);

meta = struct( ...
    'figure','fig2bd', ...
    'animal',args.animal, ...
    'condition',args.condition, ...
    'smoothing_window',args.smooth_window, ...
    'mean_intervals',mean_intervals, ...
    'auc_intervals',auc_intervals);
save(output_file,'FPX_zdFF','FPX_time','FPX_smooth', ...
    'FPX_basalfm','FPX_basal_fm_change','FPX_auc','meta','-v7.3');

if args.save_figure
    fig = figure('Visible','off','Color','w');
    plot(FPX_time,FPX_zdFF,'Color',[0.75 0.75 0.75]); hold on;
    plot(FPX_time,FPX_smooth,'k','LineWidth',1.5);
    xlim([-10 30]);
    xlabel('Time (min)'); ylabel('z dF/F'); box off;
    exportgraphics(fig,fullfile(save_dir, ...
        ['basal_' args.condition '_' args.animal '.pdf']), ...
        'ContentType','vector');
    close(fig);
end

output = struct('file',output_file,'FPX_smooth',FPX_smooth, ...
    'FPX_basalfm',FPX_basalfm,'FPX_basal_fm_change', ...
    FPX_basal_fm_change,'FPX_auc',FPX_auc);
end
