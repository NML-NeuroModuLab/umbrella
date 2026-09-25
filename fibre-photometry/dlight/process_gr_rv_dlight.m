function output = process_gr_rv_dlight(varargin)
% PROCESS_GR_RV_DLIGHT  Process one GR or RV dLight recording.
%
% Workflow:
%   raw 465/405 -> low-pass filter -> median downsample -> interpolate
%   configured artefacts -> baseline 405-to-465 fit -> dF/F -> baseline
%   z-score -> canonical time axis aligned to T1 start.

p = inputParser;
addParameter(p,'raw_folder','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'animal','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'group','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'figure','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'signal_stream','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'reference_stream','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'timestamps',struct(),@valid_timestamps);
addParameter(p,'artifact_ranges',zeros(0,2), ...
    @(x)isnumeric(x)&&size(x,2)==2);
addParameter(p,'artifact_policy','interp', ...
    @(s)any(strcmpi(s,{'interp','nan','cut'})));
addParameter(p,'lowpass_hz',20,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'target_fs',100,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'canonical_xlim',[-30 60], ...
    @(x)isnumeric(x)&&numel(x)==2);
addParameter(p,'output_root','',@(s)ischar(s)&&~isempty(s));
parse(p,varargin{:});
args = p.Results;

animal = normalize_id(args.animal);
group = upper(args.group);
figure_id = lower(args.figure);

if ~isfolder(args.raw_folder)
    error('Raw folder not found: %s',args.raw_folder);
end

%% Load raw TDT streams
T = TDTbin2mat(args.raw_folder,'TYPE',{'streams'});

if ~isfield(T.streams,args.signal_stream)
    error('Signal stream %s not found for %s.',args.signal_stream,animal);
end
if ~isfield(T.streams,args.reference_stream)
    error('Reference stream %s not found for %s.',args.reference_stream,animal);
end

sig_full = double(T.streams.(args.signal_stream).data(:));
ref_full = double(T.streams.(args.reference_stream).data(:));
fs_raw = double(T.streams.(args.signal_stream).fs);

n_raw = min(numel(sig_full),numel(ref_full));
sig_full = sig_full(1:n_raw);
ref_full = ref_full(1:n_raw);
time_s_full = (0:n_raw-1)' ./ fs_raw;

%% Low-pass filter and median downsample
sig_lp = lowpass(sig_full,args.lowpass_hz,fs_raw);
ref_lp = lowpass(ref_full,args.lowpass_hz,fs_raw);

down_fac = max(1,round(fs_raw/args.target_fs));
fs = fs_raw/down_fac;
[sig,ref,time_s] = downsample_median( ...
    sig_lp,ref_lp,time_s_full,down_fac);
time_min = (time_s-time_s(1))/60;

%% Apply configured artefact ranges
artifact_ranges = args.artifact_ranges;

if ~isempty(artifact_ranges)
    mask = false(size(time_min));
    for k = 1:size(artifact_ranges,1)
        mask = mask | ...
            (time_min >= artifact_ranges(k,1) & ...
             time_min <= artifact_ranges(k,2));
    end

    switch lower(args.artifact_policy)
        case 'interp'
            sig = interp_over_mask(sig,mask);
            ref = interp_over_mask(ref,mask);
        case 'nan'
            sig(mask) = NaN;
            ref(mask) = NaN;
        case 'cut'
            keep = ~mask;
            sig = sig(keep);
            ref = ref(keep);
            time_s = time_s(keep);
            time_min = time_min(keep);
    end
end

%% Map configured timestamps to samples
timestamps = args.timestamps;
i_bs = first_ge(time_min,timestamps.baseline(1));
i_be = first_ge(time_min,timestamps.baseline(2));
i_t1s = first_ge(time_min,timestamps.t1(1));
i_t1e = first_ge(time_min,timestamps.t1(2));
if any(cellfun(@isempty,{i_bs,i_be,i_t1s,i_t1e}))
    error('Configured timestamps could not be mapped for %s.',animal);
end

%% Baseline 405-to-465 linear fit
base_ref = ref(i_bs:i_be);
base_sig = sig(i_bs:i_be);
valid_baseline = isfinite(base_ref) & isfinite(base_sig);

if nnz(valid_baseline) < 2
    error('Insufficient finite baseline samples for %s.',animal);
end

fit_coeff = polyfit(base_ref(valid_baseline),base_sig(valid_baseline),1);
ref_fit = fit_coeff(1).*ref + fit_coeff(2);

% Preserve the original GR/RV denominator handling.
denominator = max(ref_fit,eps);
dFF = (sig-ref_fit)./denominator;

%% Baseline z-score
base_dFF = dFF(i_bs:i_be);
baseline_mean = mean(base_dFF,'omitnan');
baseline_sd = std(base_dFF,'omitnan');

if isfinite(baseline_sd) && baseline_sd > 0
    z = (dFF-baseline_mean)./baseline_sd;
else
    z = dFF-baseline_mean;
end

%% Build canonical trace aligned to T1 start
x_limits = args.canonical_xlim;
step = 1/(fs*60);
fpx_time = (x_limits(1):step:x_limits(2))';
n_canonical = numel(fpx_time);
fpx_dFF = nan(n_canonical,1);
fpx_zdFF = nan(n_canonical,1);
t0 = time_min(i_t1s);

segments = {i_bs,i_be; i_t1s,i_t1e};
if isfield(timestamps,'t2') && ~isempty(timestamps.t2)
    i_t2s = first_ge(time_min,timestamps.t2(1));
    i_t2e = first_ge(time_min,timestamps.t2(2));
    if any(cellfun(@isempty,{i_t2s,i_t2e}))
        error('Configured T2 timestamps could not be mapped for %s.',animal);
    end
    segments(end+1,:) = {i_t2s,i_t2e};
end

for s = 1:size(segments,1)
    i1 = segments{s,1};
    i2 = segments{s,2};
    segment_time = time_min(i1:i2);
    segment_dff = dFF(i1:i2);
    segment_z = z(i1:i2);

    canonical_idx = round( ...
        (segment_time-t0-x_limits(1))./step)+1;
    valid = canonical_idx >= 1 & canonical_idx <= n_canonical;
    canonical_idx = canonical_idx(valid);

    fpx_dFF(canonical_idx) = segment_dff(valid);
    fpx_zdFF(canonical_idx) = segment_z(valid);
end

%% Metadata and save
meta = struct();
meta.figure = figure_id;
meta.group = group;
meta.animal = animal;
meta.signal_stream = args.signal_stream;
meta.reference_stream = args.reference_stream;
meta.fs_raw = fs_raw;
meta.fs = fs;
meta.lowpass_hz = args.lowpass_hz;
meta.target_fs = args.target_fs;
meta.downsample_factor = down_fac;
meta.fit_coeff = fit_coeff;
meta.baseline_mean = baseline_mean;
meta.baseline_sd = baseline_sd;
meta.timestamps = timestamps;
meta.base_start = timestamps.baseline(1);
meta.base_end = timestamps.baseline(2);
meta.t1_start = timestamps.t1(1);
meta.t1_end = timestamps.t1(2);
if isfield(timestamps,'t2') && ~isempty(timestamps.t2)
    meta.t2_start = timestamps.t2(1);
    meta.t2_end = timestamps.t2(2);
end
meta.artifact_policy = args.artifact_policy;
meta.artifact_ranges = artifact_ranges;
meta.canonical_xlim = args.canonical_xlim;

save_dir = fullfile(args.output_root,animal);
if ~isfolder(save_dir), mkdir(save_dir); end
output_file = fullfile(save_dir,[group '_' animal '_processed.mat']);

save(output_file, ...
    'time_s','time_min','sig','ref','ref_fit','dFF','z','fs', ...
    'fpx_time','fpx_dFF','fpx_zdFF','meta','-v7.3');

output = struct( ...
    'file',output_file, ...
    'animal',animal, ...
    'fs',fs, ...
    'fit_coeff',fit_coeff);
end

function [sig,ref,time_s] = downsample_median(sig0,ref0,time0,factor)
n = ceil(numel(sig0)/factor);
sig = nan(n,1);
ref = nan(n,1);
time_s = nan(n,1);

for i = 1:n
    first_idx = (i-1)*factor+1;
    last_idx = min(first_idx+factor-1,numel(sig0));
    sig(i) = median(sig0(first_idx:last_idx));
    ref(i) = median(ref0(first_idx:last_idx));
    time_s(i) = median(time0(first_idx:last_idx));
end
end

function idx = first_ge(x,value)
if ~isfinite(value)
    idx = [];
else
    idx = find(x >= value,1,'first');
end
end

function y = interp_over_mask(y,mask)
if ~any(mask), return; end

good = ~mask & isfinite(y);
if ~any(good)
    y(:) = NaN;
    return;
end

first = find(good,1,'first');
last = find(good,1,'last');
y(~good) = NaN;
y(1:first-1) = y(first);
y(last+1:end) = y(last);
y = fillmissing(y,'linear');
end

function tf = valid_timestamps(x)
required_fields = {'baseline','t1'};
tf = isstruct(x) && all(isfield(x,required_fields)) && ...
    all(cellfun(@(f) isnumeric(x.(f)) && numel(x.(f)) == 2, ...
    required_fields)) && ...
    (~isfield(x,'t2') || isempty(x.t2) || ...
    (isnumeric(x.t2) && numel(x.t2) == 2));
end

function id = normalize_id(x)
s = regexprep(char(string(x)),'[^0-9]','');
if numel(s) < 6, s = sprintf('%06s',s); end
id = s;
end
