function output = process_basal_gr_rv(varargin)
% PROCESS_BASAL_GR_RV  Analyse one processed GR or RV dLight trace.

p = inputParser;
addParameter(p,'animal','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'group','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'figure','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'input_file','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'output_root','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'smooth_min',1,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'analysis_intervals',[], ...
    @(x)isnumeric(x)&&size(x,2)==2&&~isempty(x));
addParameter(p,'mean_intervals',[], ...
    @(x)isnumeric(x)&&size(x,2)==2&&~isempty(x));
addParameter(p,'analysis_labels',{},@iscell);
parse(p,varargin{:});
args = p.Results;

animal = normalize_id(args.animal);
group = upper(args.group);
figure_id = lower(args.figure);
if ~isfile(args.input_file)
    error('Processed input file not found: %s',args.input_file);
end

loaded = load(args.input_file,'fpx_time','fpx_zdFF');

fpx_time = loaded.fpx_time(:);
fpx_zdFF = loaded.fpx_zdFF(:);
n = min(numel(fpx_time),numel(fpx_zdFF));
fpx_time = fpx_time(1:n);
fpx_zdFF = fpx_zdFF(1:n);

%% Smooth trace
dt_min = median(diff(fpx_time),'omitnan');
window_samples = max(3,round(args.smooth_min/max(dt_min,eps)));
fpx_smooth = movmean(fpx_zdFF,window_samples,'omitnan');

%% Section means and AUC
intervals = args.analysis_intervals;
mean_intervals = args.mean_intervals;
labels = args.analysis_labels;
n_intervals = size(intervals,1);

if size(mean_intervals,1) ~= n_intervals || numel(labels) ~= n_intervals
    error('Analysis intervals, mean intervals and labels must have equal lengths.');
end

mean_z = nan(n_intervals,1);
full_interval_mean_z = nan(n_intervals,1);
mean_start = nan(n_intervals,1);
mean_end = nan(n_intervals,1);
total_auc = nan(n_intervals,1);
positive_auc = nan(n_intervals,1);
negative_auc = nan(n_intervals,1);

for k = 1:n_intervals
    interval_start = intervals(k,1);
    interval_end = intervals(k,2);

    idx_auc = fpx_time >= interval_start & fpx_time <= interval_end;
    x = fpx_time(idx_auc);
    y = fpx_smooth(idx_auc);
    full_interval_mean_z(k) = mean(y,'omitnan');

    valid = isfinite(x) & isfinite(y);
    x = x(valid);
    y = y(valid);
    if numel(x) >= 2
        total_auc(k) = trapz(x,y);
        positive_auc(k) = trapz(x,max(y,0));
        negative_auc(k) = trapz(x,min(y,0));
    end

    mean_start(k) = mean_intervals(k,1);
    mean_end(k) = mean_intervals(k,2);
    idx_mean = fpx_time >= mean_start(k) & fpx_time <= mean_end(k);
    mean_z(k) = mean(fpx_smooth(idx_mean),'omitnan');
end

change_z = diff(mean_z);
basal_table = table( ...
    string(labels(:)),intervals(:,1),intervals(:,2), ...
    mean_start,mean_end,mean_z,full_interval_mean_z, ...
    total_auc,positive_auc,negative_auc, ...
    'VariableNames',{ ...
    'Interval','StartMin','EndMin','MeanStartMin','MeanEndMin', ...
    'MeanZ','FullIntervalMeanZ','TotalAUC','PositiveAUC','NegativeAUC'});

change_table = table( ...
    string(labels(1:end-1))',string(labels(2:end))',change_z, ...
    'VariableNames',{'FromInterval','ToInterval','DeltaMeanZ'});

%% Save
output_dir = fullfile(args.output_root,animal);
if ~isfolder(output_dir), mkdir(output_dir); end
output_file = fullfile(output_dir,[group '_' animal '_basal.mat']);

save(output_file, ...
    'fpx_time','fpx_zdFF','fpx_smooth', ...
    'basal_table','change_table','intervals','labels','figure_id','group');

output = struct( ...
    'file',output_file, ...
    'animal',animal, ...
    'basal_table',basal_table, ...
    'change_table',change_table);
end

function id = normalize_id(x)
s = regexprep(char(string(x)),'[^0-9]','');
if numel(s) < 6, s = sprintf('%06s',s); end
id = s;
end
