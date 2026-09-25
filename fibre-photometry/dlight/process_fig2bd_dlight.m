function output = process_fig2bd_dlight(varargin)
% PROCESS_FIG2BD_DLIGHT  Process one Fig. 2b-d dLight recording.
%
% Habituation recordings fit double-exponential bleaching curves. Test
% recordings reuse those curves unless configuration explicitly bypasses
% bleach correction for a historical exception.

p = inputParser;
addParameter(p,'mode','test',@(s)any(strcmpi(s,{'hab3','test'})));
addParameter(p,'condition','',@ischar);
addParameter(p,'raw_folder','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'subject','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'hab3_fit_file','',@ischar);
addParameter(p,'output_root','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'signal_stream','C465',@ischar);
addParameter(p,'reference_stream','C405',@ischar);
addParameter(p,'raw_start_s',16,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'raw_finish_note',6,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'lowpass_hz',20,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'target_fs',100,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'baseline_smoothing_window',500,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'use_bleach_correction',true,@(x)islogical(x)||(isnumeric(x)&&isscalar(x)));
addParameter(p,'bleach_smoothing_window',5000,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'hab3_fit_trim_start',6000,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'hab3_fit_trim_end',6000,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'start_point_405',[300 -0.003 30 -0.3],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'start_point_465',[300 -0.003 30 -0.3],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'timestamps',struct(),@valid_timestamps);
addParameter(p,'fpx_time_range',[-30 30],@(x)isnumeric(x)&&numel(x)==2);
addParameter(p,'sync_epoc','PrtC',@ischar);
parse(p,varargin{:});
args = p.Results;

animal = normalize_id(args.subject);
mode = lower(char(string(args.mode)));
condition = upper(char(string(args.condition)));

if ~isfolder(args.raw_folder)
    error('Raw folder not found: %s',args.raw_folder);
end
if strcmp(mode,'test') && ~isfile(args.hab3_fit_file)
    error('Hab3 fit file not found for %s: %s',animal,args.hab3_fit_file);
end

T = TDTbin2mat(args.raw_folder,'TYPE',{'streams','epocs'});
[time_full,sig_full,fs_full] = get_stream(T,args.signal_stream);
[~,ref_full] = get_stream(T,args.reference_stream);

if ~isfield(T,'epocs') || ~isfield(T.epocs,'Note')
    error('Note epoc not available for %s.',animal);
end
if args.raw_finish_note > numel(T.epocs.Note.onset)
    error('Requested finish Note %d for %s but only %d notes are present.', ...
        args.raw_finish_note,animal,numel(T.epocs.Note.onset));
end

finish_s = T.epocs.Note.onset(args.raw_finish_note,1);
i1 = find(time_full > args.raw_start_s,1,'first');
i2 = find(time_full > finish_s,1,'first');
if isempty(i1) || isempty(i2) || i2 <= i1
    error('Invalid crop for %s.',animal);
end

raw465 = double(sig_full(i1:i2));
raw405 = double(ref_full(i1:i2));

%% Filtering and median downsampling
lp465 = lowpass(raw465,args.lowpass_hz,fs_full);
lp405 = lowpass(raw405,args.lowpass_hz,fs_full);
down_fac = round(fs_full/args.target_fs);
fs = fs_full/down_fac;
n = ceil(numel(lp465)/down_fac);
down465 = nan(n,1);
down405 = nan(n,1);

for k = 1:n
    first_idx = (k-1)*down_fac+1;
    last_idx = min(first_idx+down_fac-1,numel(lp465));
    down465(k) = median(lp465(first_idx:last_idx));
    down405(k) = median(lp405(first_idx:last_idx));
end

time_s = time_full(i1:i2);
if numel(time_s) >= down_fac+1
    actual_step = median(diff(time_s(1:down_fac:end)));
else
    actual_step = 1/fs;
end
time_min = ((0:n-1)'*actual_step+time_s(1))/60;

%% Bleaching curves
double_exp = fittype('a*exp(b*x)+c*exp(d*x)', ...
    'independent','x','dependent','y');

if strcmp(mode,'hab3')
    smooth405 = movmin(down405,args.bleach_smoothing_window);
    smooth465 = movmin(down465,args.bleach_smoothing_window);
    fit_start = max(1,args.hab3_fit_trim_start+1);
    fit_end = n-args.hab3_fit_trim_end;
    if fit_end <= fit_start
        error('Invalid hab3 fit trim for %s.',animal);
    end

    options405 = fitoptions(double_exp);
    options405.StartPoint = args.start_point_405;
    options465 = fitoptions(double_exp);
    options465.StartPoint = args.start_point_465;
    [fitted_curve_405,gof_405] = fit( ...
        time_min(fit_start:fit_end),smooth405(fit_start:fit_end), ...
        double_exp,options405);
    [fitted_curve_465,gof_465] = fit( ...
        time_min(fit_start:fit_end),smooth465(fit_start:fit_end), ...
        double_exp,options465);
else
    loaded = load(args.hab3_fit_file,'fitted_curve_405','fitted_curve_465');
    fitted_curve_405 = loaded.fitted_curve_405;
    fitted_curve_465 = loaded.fitted_curve_465;
    gof_405 = [];
    gof_465 = [];
end

eval405 = feval(fitted_curve_405,time_min);
eval465 = feval(fitted_curve_465,time_min);
res405 = down405(:)-eval405(:)+down405(1);
res465 = down465(:)-eval465(:)+down465(1);

if strcmp(mode,'hab3') || logical(args.use_bleach_correction)
    analysis405 = res405;
    analysis465 = res465;
    bleach_correction_used = true;
else
    analysis405 = down405(:);
    analysis465 = down465(:);
    bleach_correction_used = false;
end

%% Baseline fit, dF/F and z-score
timestamps = args.timestamps;
base_start_idx = first_gt(time_min,timestamps.baseline(1));
base_end_idx = first_gt(time_min,timestamps.baseline(2));
if isempty(base_start_idx) || isempty(base_end_idx)
    error('Cannot map baseline for %s.',animal);
end

base405 = analysis405(base_start_idx:base_end_idx);
base465 = analysis465(base_start_idx:base_end_idx);
sm405 = movmedian(base405,args.baseline_smoothing_window);
sm465 = movmedian(base465,args.baseline_smoothing_window);
fit_coeff = polyfit(sm405,sm465,1);
fit_405 = fit_coeff(1)*analysis405+fit_coeff(2);
dFF = (analysis465-fit_405)./fit_405;
base_dFF = dFF(base_start_idx:base_end_idx);
zdFF = (dFF-mean(base_dFF))/std(base_dFF);

%% Canonical trace extraction
if ~isfield(T.epocs,args.sync_epoc)
    error('Sync epoc %s not found for %s.',args.sync_epoc,animal);
end
sync_start = T.epocs.(args.sync_epoc).onset(1,1)/60;
sync_idx = first_gt(time_min,sync_start);
t1_start_idx = first_gt(time_min,timestamps.t1(1));
t1_end_idx = first_gt(time_min,timestamps.t1(2));
t2_start_idx = first_gt(time_min,timestamps.t2(1));
t2_end_idx = first_gt(time_min,timestamps.t2(2));

indices = {base_start_idx-sync_idx,base_end_idx-sync_idx; ...
    t1_start_idx-sync_idx+1,t1_end_idx-sync_idx; ...
    t2_start_idx-sync_idx+1,t2_end_idx-sync_idx};
for row = 1:size(indices,1)
    indices{row,1} = max(1,indices{row,1});
    indices{row,2} = min(numel(zdFF),indices{row,2});
end

FPX_base = zdFF(indices{1,1}:indices{1,2});
FPX_t1 = zdFF(indices{2,1}:indices{2,2});
FPX_t2 = zdFF(indices{3,1}:indices{3,2});
FPX_zdFF = vertcat(FPX_base,FPX_t1,FPX_t2);
FPX_SampleRate = fs;
FPX_SampleDuration = 1/(fs*60);
FPX_time = (args.fpx_time_range(1):FPX_SampleDuration:args.fpx_time_range(2))';

n_fpx = min(numel(FPX_zdFF),numel(FPX_time));
FPX_zdFF = FPX_zdFF(1:n_fpx);
FPX_time = FPX_time(1:n_fpx);
FPX_smooth = movmean(FPX_zdFF,3600);

%% Save
if strcmp(mode,'hab3')
    save_dir = fullfile(args.output_root,'hab3',animal);
    output_file = fullfile(save_dir,['hab3_' animal '_processed.mat']);
else
    save_dir = fullfile(args.output_root,condition,animal);
    output_file = fullfile(save_dir, ...
        ['test_' condition '_' animal '_processed.mat']);
end
if ~isfolder(save_dir), mkdir(save_dir); end

meta = struct();
meta.figure = 'fig2bd';
meta.animal = animal;
meta.mode = mode;
meta.condition = condition;
meta.signal_stream = args.signal_stream;
meta.reference_stream = args.reference_stream;
meta.lowpass_hz = args.lowpass_hz;
meta.target_fs = args.target_fs;
meta.bleach_correction_used_for_dff = bleach_correction_used;
meta.fit_coeff = fit_coeff;
meta.timestamps = timestamps;
meta.sync_epoc = args.sync_epoc;
meta.hab3_fit_file = args.hab3_fit_file;

save(output_file, ...
    'FPX_base','FPX_t1','FPX_t2','FPX_zdFF','FPX_smooth','FPX_time', ...
    'FPX_SampleRate','FPX_SampleDuration','zdFF','dFF', ...
    'time_min','down405','down465','res405','res465', ...
    'analysis405','analysis465','fit_405','fit_coeff', ...
    'fitted_curve_405','fitted_curve_465','gof_405','gof_465','meta','-v7.3');

output = struct('animal',animal,'mode',mode,'condition',condition, ...
    'file',output_file,'FPX_zdFF',FPX_zdFF, ...
    'FPX_smooth',FPX_smooth,'FPX_time',FPX_time);
end

function [time_s,signal,fs] = get_stream(T,name)
if ~isfield(T.streams,name)
    error('Stream %s was not found.',name);
end
stream = T.streams.(name);
signal = double(stream.data(:));
fs = stream.fs;
time_s = (1:numel(signal))'/fs;
end

function idx = first_gt(x,value)
idx = find(x > value,1,'first');
end

function tf = valid_timestamps(x)
fields = {'baseline','t1','t2'};
tf = isstruct(x) && all(isfield(x,fields)) && ...
    all(cellfun(@(f) isnumeric(x.(f))&&numel(x.(f))==2,fields));
end

function id = normalize_id(x)
id = regexprep(char(string(x)),'[^0-9]','');
if numel(id) < 6, id = sprintf('%06s',id); end
end
