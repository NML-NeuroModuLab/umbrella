function output = process_fig3d_hab3_dlight(varargin)
% PROCESS_FIG3D_HAB3_DLIGHT  Habituation-day preprocessing for Fig. 3d.
%
% Sequence:
%   raw x405/x465
%   -> crop using raw start + Notes onset
%   -> 20 Hz low-pass
%   -> median downsample to ~100 Hz
%   -> per-animal double-exponential bleach fits
%   -> bleach-subtracted 405/465
%   -> baseline-only linear 405->465 fit
%   -> dFF + baseline z-score
%   -> save new hab3 fit parameters for test-day processing
%
% The per-animal differences are passed in as arguments/configuration:
%   raw_finish_note
%   bleach_smoothing_method
%   bleach_fit_start_idx
%   bleach_fit_end_trim_idx
%   start_point_405 / start_point_465
%   baseline_start/end
%   baseline_fit_smoothing_method / window

p = inputParser;
addParameter(p,'day','hab3',@ischar);
addParameter(p,'raw_folder','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'subject','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'timestamps',struct(),@valid_timestamps);
addParameter(p,'output_root','',@ischar);
addParameter(p,'raw_start_s',16,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'lowpass_hz',20,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'target_fs',100,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'raw_finish_note',6,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'bleach_smoothing_method','movmin',@(s)any(strcmpi(s,{'movmin','movmedian'})));
addParameter(p,'bleach_smoothing_window',5000,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'bleach_fit_start_idx',10,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'bleach_fit_end_trim_idx',6000,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'start_point_405',[450 -0.003 30 -0.3],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'start_point_465',[400 -0.003 30 -0.3],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'baseline_fit_smoothing_method','movmedian',@(s)any(strcmpi(s,{'none','movmedian'})));
addParameter(p,'baseline_fit_smoothing_window',5000,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'baseline_fit_start_offset',0,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'save_figures',false,@islogical);
addParameter(p,'save_mat',true,@islogical);
addParameter(p,'logger',[],@(x)isempty(x)||isa(x,'function_handle'));
parse(p,varargin{:});
args = p.Results;

animal = normalize_id(args.subject);
if isempty(args.output_root)
    args.output_root = fullfile(pwd,'exp-days');
end
if isempty(args.logger)
    logf = @(s) fprintf('%s\n',s);
else
    logf = args.logger;
end

% ---------- Load TDT ----------
if ~isfolder(args.raw_folder)
    error('Raw folder not found: %s',args.raw_folder);
end
T = TDTbin2mat(args.raw_folder,'TYPE',{'streams','epocs'});

% ---------- Resolve dLight streams ----------
sig_store = resolve_store(T,'x465A');
ref_store = resolve_store(T,'x405A');
if isempty(sig_store) || isempty(ref_store)
    error('Could not resolve x465A/x405A streams for %s.',animal);
end
[time_full,sig_full,fs_full] = get_stream(T,sig_store);
[~,ref_full] = get_stream(T,ref_store);

% ---------- Raw crop ----------
if ~isfield(T,'epocs') || ~isfield(T.epocs,'Note') || ~isfield(T.epocs.Note,'onset')
    error('Notes epoc not available for %s.',animal);
end
notes = T.epocs.Note.onset;
if args.raw_finish_note > numel(notes)
    error('Requested Note onset %d but only %d notes exist for %s.',args.raw_finish_note,numel(notes),animal);
end
finish_s = notes(args.raw_finish_note,1);
idx1 = find(time_full > args.raw_start_s,1,'first');
idx2 = find(time_full > finish_s,1,'first');
if isempty(idx1) || isempty(idx2) || idx2 <= idx1
    error('Invalid raw crop for %s.',animal);
end
raw_465 = double(sig_full(idx1:idx2));
raw_405 = double(ref_full(idx1:idx2));

% ---------- Filter + median downsample ----------
LP_405 = lowpass(raw_405,args.lowpass_hz,fs_full);
LP_465 = lowpass(raw_465,args.lowpass_hz,fs_full);

down_fac = round(fs_full/args.target_fs);
fs = fs_full/down_fac;
numEl = ceil(numel(LP_465)/down_fac);
down_405 = NaN(numEl,1);
down_465 = NaN(numEl,1);
for i = 1:numEl
    a = (i-1)*down_fac + 1;
    b = min(a+down_fac-1,numel(LP_465));
    down_405(i) = median(LP_405(a:b));
    down_465(i) = median(LP_465(a:b));
end

% Preserve the historical time-base construction.
% The original Fig. 3d workflow retained the first post-crop TDT time point
% and reconstructed the downsampled time axis using the median interval
% between samples separated by the downsampling factor. Importantly, the
% first timestamp was NOT replaced by the median of the first bin.
time_cropped_s = time_full(idx1:idx2);

if numel(time_cropped_s) >= down_fac + 1
    actual_intervals = diff(time_cropped_s(1:down_fac:end));
    actual_time_step = median(actual_intervals);
else
    actual_time_step = 1/fs;
end

downsampled_time = (0:numEl-1)' * actual_time_step + time_cropped_s(1);
time_cropped = downsampled_time / 60; % minutes

% ---------- Animal-specific timestamps from figure configuration ----------
base_start = args.timestamps.baseline(1);
base_end   = args.timestamps.baseline(2);
t1_start   = args.timestamps.t1(1);
t1_end     = args.timestamps.t1(2);
t2_start   = args.timestamps.t2(1);
t2_end     = args.timestamps.t2(2);
idx_base_start = find(time_cropped > base_start,1,'first');
idx_base_end   = find(time_cropped > base_end,1,'first');
if isempty(idx_base_start) || isempty(idx_base_end)
    error('Could not map hab3 baseline timestamps for %s.',animal);
end

% Historical script also used the first PrtA onset as a downstream sync point.
sync_start = NaN;
idx_sync_start = [];
if isfield(T,'epocs') && isfield(T.epocs,'PrtA') && isfield(T.epocs.PrtA,'onset')
    sync_start = T.epocs.PrtA.onset(1,1)/60;
    idx_sync_start = find(time_cropped > sync_start,1,'first');
end

% ---------- Historical bleach smoothing ----------
window_size = args.bleach_smoothing_window;
switch lower(args.bleach_smoothing_method)
    case 'movmin'
        smooth_405 = movmin(down_405,window_size);
        smooth_465 = movmin(down_465,window_size);
    case 'movmedian'
        smooth_405 = movmedian(down_405,window_size);
        smooth_465 = movmedian(down_465,window_size);
end

% ---------- Historical double-exponential bleach fit ----------
doubleExp = fittype('a*exp(b*x) + c*exp(d*x)', ...
    'independent','x','dependent','y');
opts_405 = fitoptions(doubleExp);
opts_405.StartPoint = args.start_point_405;
opts_465 = fitoptions(doubleExp);
opts_465.StartPoint = args.start_point_465;

fit_i1 = max(1,args.bleach_fit_start_idx);
fit_i2 = min(numel(time_cropped),numel(time_cropped)-args.bleach_fit_end_trim_idx);
if fit_i2 <= fit_i1
    error('Invalid bleach fit range for %s: %d:%d',animal,fit_i1,fit_i2);
end

[fitted_curve_405,gof_405] = fit( ...
    time_cropped(fit_i1:fit_i2),smooth_405(fit_i1:fit_i2),doubleExp,opts_405);
[fitted_curve_465,gof_465] = fit( ...
    time_cropped(fit_i1:fit_i2),smooth_465(fit_i1:fit_i2),doubleExp,opts_465);

evaluated_fit_405 = feval(fitted_curve_405,time_cropped);
residuals_405 = down_405 - evaluated_fit_405;
residuals_405 = residuals_405 + smooth_405(1);

evaluated_fit_465 = feval(fitted_curve_465,time_cropped);
residuals_465 = down_465 - evaluated_fit_465;
residuals_465 = residuals_465 + smooth_465(1);

% ---------- Historical baseline-only 405->465 fit ----------
% The optional offset applies ONLY to the linear 405->465 fit.
fit_base_start = idx_base_start + args.baseline_fit_start_offset;
if fit_base_start > idx_base_end
    error(['Baseline fit start offset (%d samples) moves the fit start ' ...
           'beyond the baseline end for %s.'], ...
           args.baseline_fit_start_offset,animal);
end

base405 = residuals_405(fit_base_start:idx_base_end);
base465 = residuals_465(fit_base_start:idx_base_end);
base_time = time_cropped(fit_base_start:idx_base_end);

switch lower(args.baseline_fit_smoothing_method)
    case 'none'
        movmedian_base405 = base405;
        movmedian_base465 = base465;
    case 'movmedian'
        movmedian_base405 = movmedian(base405,args.baseline_fit_smoothing_window);
        movmedian_base465 = movmedian(base465,args.baseline_fit_smoothing_window);
end

fit_coeff = polyfit(movmedian_base405,movmedian_base465,1);
fit_405 = fit_coeff(1)*residuals_405 + fit_coeff(2);
dFF = (residuals_465-fit_405)./fit_405;

% Full baseline is retained for historical z-scoring.
base_dFF = dFF(idx_base_start:idx_base_end);
zdFF = (dFF-mean(base_dFF))/std(base_dFF);

% ---------- Historical FPX extraction ----------
% Reproduce the historical Fig. 3d trace used by downstream analyses.
% Indices are expressed relative to the first PrtA synchronisation event.
if isempty(idx_sync_start)
    error('Could not find PrtA synchronisation point for %s; FPX extraction cannot be reproduced.',animal);
end

idx_t1_start = find(time_cropped > t1_start,1,'first');
idx_t1_end   = find(time_cropped > t1_end,1,'first');
idx_t2_start = find(time_cropped > t2_start,1,'first');
idx_t2_end   = find(time_cropped > t2_end,1,'first');
if any(cellfun(@isempty,{idx_t1_start,idx_t1_end,idx_t2_start,idx_t2_end}))
    error('Could not map one or more hab3 treatment timestamps for %s.',animal);
end

idx_FPbase_start = max(1,idx_base_start - idx_sync_start);
idx_FPbase_end   = idx_base_end - idx_sync_start;
idx_FPt1_start   = max(1,idx_t1_start - idx_sync_start);
idx_FPt1_end     = idx_t1_end - idx_sync_start;
idx_FPt2_start   = max(1,idx_t2_start - idx_sync_start);
idx_FPt2_end     = idx_t2_end - idx_sync_start;

% Initial extraction, followed by the historical length correction that
% enforces the intended 10 + 15 + 15 minute segment durations.
FPX_base = zdFF(idx_FPbase_start:idx_FPbase_end);
FPX_t1   = zdFF(idx_FPt1_start:idx_FPt1_end);
FPX_t2   = zdFF(idx_FPt2_start:idx_FPt2_end);

FPX_SampleRate = fs;
FPX_SampleDuration = 1/(FPX_SampleRate*60); % minutes/sample

expectedLenBase = round(10*60*fs);
expectedLenT1T2 = round(15*60*fs);
diffBase = expectedLenBase - length(FPX_base);
diffT1   = expectedLenT1T2 - length(FPX_t1);
diffT2   = expectedLenT1T2 - length(FPX_t2);

idx_FPbase_end = min(idx_FPbase_end + diffBase,length(zdFF));
idx_FPt1_end   = min(idx_FPt1_end + diffT1,length(zdFF));
idx_FPt2_end   = min(idx_FPt2_end + diffT2,length(zdFF));

FPX_base = zdFF(idx_FPbase_start:idx_FPbase_end);
FPX_t1   = zdFF(idx_FPt1_start:idx_FPt1_end);
FPX_t2   = zdFF(idx_FPt2_start:idx_FPt2_end);
FPX_zdFF = vertcat(FPX_base,FPX_t1,FPX_t2);
FPX_time = (-10:FPX_SampleDuration:30)';

% Keep time and trace lengths matched in the event that floating-point
% colon construction differs by one sample.
Nfpx = min(length(FPX_time),length(FPX_zdFF));
FPX_time = FPX_time(1:Nfpx);
FPX_zdFF = FPX_zdFF(1:Nfpx);

% ---------- Save new hab3-derived parameters ----------
save_dir = fullfile(args.output_root,args.day,animal);
if ~isfolder(save_dir), mkdir(save_dir); end
fit_file = fullfile(save_dir,[args.day,'_',animal,'_fit.mat']);

meta = struct();
meta.figure = 'fig3d';
meta.day = args.day;
meta.animal = animal;
meta.sensor = 'dLight';
meta.raw_start_s = args.raw_start_s;
meta.raw_finish_note = args.raw_finish_note;
meta.raw_finish_s = finish_s;
meta.lowpass_hz = args.lowpass_hz;
meta.target_fs = args.target_fs;
meta.actual_fs = fs;
meta.bleach_smoothing_method = args.bleach_smoothing_method;
meta.bleach_smoothing_window = args.bleach_smoothing_window;
meta.bleach_fit_indices = [fit_i1 fit_i2];
meta.start_point_405 = args.start_point_405;
meta.start_point_465 = args.start_point_465;
meta.baseline_fit_smoothing_method = args.baseline_fit_smoothing_method;
meta.baseline_fit_smoothing_window = args.baseline_fit_smoothing_window;
meta.baseline_fit_start_offset = args.baseline_fit_start_offset;
meta.timestamps = [base_start base_end; t1_start t1_end; t2_start t2_end];
meta.sync_start_min = sync_start;
meta.fit_coeff = fit_coeff;
meta.fit_method = 'polyfit_linear_on_bleach_corrected_baseline';
meta.bleach_fit_method = 'double_exponential';
meta.gof_405 = gof_405;
meta.gof_465 = gof_465;

if args.save_mat
    save(fit_file,'fitted_curve_405','fitted_curve_465', ...
        'gof_405','gof_465','fit_coeff','meta', ...
        'residuals_405','residuals_465','down_405','down_465', ...
        'time_cropped','dFF','zdFF','fs', ...
        'FPX_base','FPX_t1','FPX_t2','FPX_zdFF','FPX_time', ...
        'FPX_SampleRate','FPX_SampleDuration', ...
        'idx_FPbase_start','idx_FPbase_end','idx_FPt1_start','idx_FPt1_end', ...
        'idx_FPt2_start','idx_FPt2_end','-v7.3');
    logf(sprintf('Saved new hab3 fit: %s',fit_file));
end

output = struct('animal',animal,'day',args.day, ...
    'fitted_curve_405',fitted_curve_405, ...
    'fitted_curve_465',fitted_curve_465, ...
    'fit_coeff',fit_coeff,'dFF',dFF,'zdFF',zdFF, ...
    'FPX_zdFF',FPX_zdFF,'FPX_time',FPX_time,'meta',meta);
end

function tf = valid_timestamps(x)
required_fields = {'baseline','t1','t2'};
tf = isstruct(x) && all(isfield(x,required_fields)) && ...
    all(cellfun(@(f) isnumeric(x.(f)) && numel(x.(f)) == 2, ...
    required_fields));
end

function id = normalize_id(x)
s = regexprep(char(string(x)),'[^0-9]','');
if numel(s)<6, s=sprintf('%06s',s); end
id=s;
end

function store = resolve_store(T,wanted)
store='';
if isfield(T,'streams')
    f=fieldnames(T.streams);
    idx=find(strcmpi(f,wanted),1,'first');
    if ~isempty(idx), store=f{idx}; end
end
end

function [time_s,sig,fs] = get_stream(T,store)
S=T.streams.(store);
sig=double(S.data(:)); fs=S.fs; time_s=(0:numel(sig)-1)'/fs;
end
