function output = process_fig2bd_dlight(varargin)
% PROCESS_FIG2BD_DLIGHT  Process one Fig. 2b-d dLight recording.
%
% Habituation recordings fit double-exponential bleaching curves. Test
% recordings reuse those curves unless configuration explicitly bypasses
% bleach correction for a historical exception.
%
% Input recordings use the public Fig. 2b-d export format:
%   sub-<id>_photometry.parquet  time, 405-nm reference, and 465-nm signal
%   sub-<id>_notes.csv           curated recording annotations
%   sub-<id>_metadata.json       stream mapping and acquisition metadata

p = inputParser;
addParameter(p,'mode','test',@(s)any(strcmpi(s,{'hab3','test'})));
addParameter(p,'condition','',@ischar);
addParameter(p,'data_folder','',@(s)(ischar(s)||isstring(s))&&strlength(string(s))>0);
addParameter(p,'subject','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'hab3_fit_file','',@ischar);
addParameter(p,'output_root','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'signal_stream','C465',@ischar);
addParameter(p,'reference_stream','C405',@ischar);
addParameter(p,'raw_start_s',16,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
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
parse(p,varargin{:});
args = p.Results;

animal = normalize_id(args.subject);
mode = lower(char(string(args.mode)));
condition = upper(char(string(args.condition)));

if ~isfolder(args.data_folder)
    error('Data folder not found: %s',args.data_folder);
end
if strcmp(mode,'test') && ~isfile(args.hab3_fit_file)
    error('Hab3 fit file not found for %s: %s',animal,args.hab3_fit_file);
end

recording = load_dlight_recording(args.data_folder, ...
    'ExpectedSubject',animal, ...
    'ExpectedCondition',condition, ...
    'SignalStream',args.signal_stream, ...
    'ReferenceStream',args.reference_stream);
time_full = recording.time_s;
sig_full = recording.signal;
ref_full = recording.reference;
fs_full = recording.fs;

% Public files have already been end-cropped. Respect an end annotation if
% it precedes the final sample, while retaining the original time base.
finish_s = time_full(end);
note_labels = lower(strtrim(string(recording.notes.event_label)));
end_rows = find(note_labels == "end");
if ~isempty(end_rows)
    finish_s = min(finish_s,max(recording.notes.onset_s(end_rows)));
end

i1 = find(time_full > args.raw_start_s,1,'first');
i2 = find(time_full <= finish_s,1,'last');
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
base_end_idx = last_le(time_min,timestamps.baseline(2));
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
% Windows are selected directly on the photometry recording time base.
% Historical PrtC offsets supported planned video/locomotion alignment and
% are intentionally absent because those data were not analysed.
t1_start_idx = first_gt(time_min,timestamps.t1(1));
t1_end_idx = last_le(time_min,timestamps.t1(2));
t2_start_idx = first_gt(time_min,timestamps.t2(1));
t2_end_idx = last_le(time_min,timestamps.t2(2));

window_indices = {base_start_idx,base_end_idx,t1_start_idx,t1_end_idx, ...
    t2_start_idx,t2_end_idx};
if any(cellfun(@isempty,window_indices))
    error('Could not map one or more analysis windows for %s.',animal);
end
if base_end_idx < base_start_idx || t1_end_idx < t1_start_idx || ...
        t2_end_idx < t2_start_idx
    error('One or more analysis windows are empty for %s.',animal);
end

FPX_base = zdFF(base_start_idx:base_end_idx);
FPX_t1 = zdFF(t1_start_idx:t1_end_idx);
FPX_t2 = zdFF(t2_start_idx:t2_end_idx);
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
meta.input_format = 'subject-prefixed photometry Parquet + notes CSV + metadata JSON';
meta.source_stream_columns = struct( ...
    'reference',recording.reference_column, ...
    'signal',recording.signal_column);
meta.video_sync_used = false;
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

function idx = first_gt(x,value)
idx = find(x > value,1,'first');
end

function idx = last_le(x,value)
idx = find(x <= value,1,'last');
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
