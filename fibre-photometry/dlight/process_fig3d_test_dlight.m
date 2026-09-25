function output = process_fig3d_test_dlight(varargin)
% PROCESS_FIG3D_TEST_DLIGHT  Test-day dLight preprocessing for Fig. 3d.
%
%   1) hab3_curve
%      Use the independently fitted habituation-day double-exponential
%      bleaching curves, followed by the Fig. 3d baseline 405->465 fit.
%
%   2) baseline_double_exp
%      Fallback used for animals where the hab3
%      bleaching curves did not fit well. This is used for 032417, 032419
%      and 032421 and uses animal-specific double-exponential fit constraints.


p = inputParser;
addParameter(p,'day','test',@ischar);
addParameter(p,'raw_folder','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'subject','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'timestamps',struct(),@valid_timestamps);
addParameter(p,'hab3_fit_file','',@ischar);
addParameter(p,'bleach_mode','hab3_curve',@(s)any(strcmpi(s,{'hab3_curve','hab3_curve_fixed','none','baseline_double_exp','baseline_double_exp_fixed'})));
addParameter(p,'bleach_fixed_coeff_405',[],@(x)isnumeric(x) && (isempty(x) || numel(x)==4));
addParameter(p,'bleach_fixed_coeff_465',[],@(x)isnumeric(x) && (isempty(x) || numel(x)==4));
addParameter(p,'fixed_hab3_coeff_405',[],@(x)isnumeric(x) && (isempty(x) || numel(x)==4));
addParameter(p,'fixed_hab3_coeff_465',[],@(x)isnumeric(x) && (isempty(x) || numel(x)==4));
addParameter(p,'raw_finish_note',6,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'baseline_smooth',5000,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
addParameter(p,'baseline_bleach_target_fs',60,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'baseline_bleach_start_point_405',[500 -0.001 90 -0.2],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'baseline_bleach_lower_405',[-Inf -Inf -Inf -Inf],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'baseline_bleach_upper_405',[Inf Inf Inf Inf],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'baseline_bleach_start_point_465',[500 -0.001 90 -0.2],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'baseline_bleach_lower_465',[-Inf -Inf -Inf -Inf],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'baseline_bleach_upper_465',[Inf Inf Inf Inf],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'output_root','',@ischar);
addParameter(p,'raw_start_s',16,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p,'lowpass_hz',20,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'target_fs',100,@(x)isnumeric(x)&&isscalar(x)&&x>0);
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

if ~isfolder(args.raw_folder)
    error('Raw folder not found: %s',args.raw_folder);
end

T = TDTbin2mat(args.raw_folder,'TYPE',{'streams','epocs'});

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

note_onsets = T.epocs.Note.onset;
if args.raw_finish_note > numel(note_onsets)
    error('Requested Note onset %d but only %d notes exist for %s.', ...
        args.raw_finish_note,numel(note_onsets),animal);
end

finish_s = note_onsets(args.raw_finish_note,1);

ind1 = find(time_full > args.raw_start_s,1,'first');
ind2 = find(time_full > finish_s,1,'first');

if isempty(ind1) || isempty(ind2) || ind2 <= ind1
    error('Invalid raw crop for %s.',animal);
end

raw_465_full = double(sig_full(ind1:ind2));
raw_405_full = double(ref_full(ind1:ind2));

% ---------- Animal-specific timestamps from figure configuration ----------
base_start = args.timestamps.baseline(1);
base_end   = args.timestamps.baseline(2);
t1_start   = args.timestamps.t1(1);
t1_end     = args.timestamps.t1(2);
t2_start   = args.timestamps.t2(1);
t2_end     = args.timestamps.t2(2);

% ---------- Branch: archived baseline-derived bleaching fallback ----------
if strcmpi(args.bleach_mode,'baseline_double_exp')

    % The archived Day1 scripts did NOT low-pass before this path.
    % They downsampled the cropped raw vectors directly to ~60 Hz using
    % MATLAB's downsample() and reset the time vector to zero.
    % Historical archived pathway:
    % The archived Day1 scripts deliberately used a nominal fs of exactly
    % 60 Hz after integer downsampling, even though the realised rate from
    % the integer factor may differ slightly from 60 Hz.
    fs = args.baseline_bleach_target_fs;
    downsampling_factor = round(fs_full / fs);

    downsampled_465 = downsample(raw_465_full,downsampling_factor);
    downsampled_405 = downsample(raw_405_full,downsampling_factor);

    raw_465 = downsampled_465(:);
    raw_405 = downsampled_405(:);

    % Reconstruct the historical time base using exactly 1/60 s steps.
    time_step = 1 / fs;
    time_cropped = ((0:numel(raw_465)-1)' * time_step) / 60;

    idx_base_start = find(time_cropped > base_start,1,'first');
    idx_base_end   = find(time_cropped > base_end,1,'first');
    idx_t1_start   = find(time_cropped > t1_start,1,'first');
    idx_t1_end     = find(time_cropped > t1_end,1,'first');
    idx_t2_start   = find(time_cropped > t2_start,1,'first');
    idx_t2_end     = find(time_cropped > t2_end,1,'first');

    idx_sync_start = find(time_cropped > ...
        (T.epocs.PrtA.onset(1,1)/60),1,'first');

    if any(cellfun(@isempty,{idx_base_start,idx_base_end, ...
            idx_t1_start,idx_t1_end,idx_t2_start,idx_t2_end,idx_sync_start}))
        error('Could not map Fig. 3d fallback timestamps for %s.',animal);
    end

    base465 = raw_465(idx_base_start:idx_base_end);
    base405 = raw_405(idx_base_start:idx_base_end);
    base_time = time_cropped(idx_base_start:idx_base_end);

    % Archived baseline double-exponential model:
    % y = a*exp(b*x) + c*exp(d*x)
    doubleExp = fittype('a*exp(b*x) + c*exp(d*x)', ...
        'independent','x','dependent','y');

    if strcmpi(args.bleach_mode,'baseline_double_exp_fixed')

        if numel(args.bleach_fixed_coeff_405) ~= 4 || ...
                numel(args.bleach_fixed_coeff_465) ~= 4
            error(['Fixed historical bleaching mode requires four coefficients ' ...
                   'for both 405 and 465 for %s.'],animal);
        end

        coeff405 = args.bleach_fixed_coeff_405(:)';
        coeff465 = args.bleach_fixed_coeff_465(:)';

        fitted_curve_405 = cfit( ...
            doubleExp, ...
            coeff405(1),coeff405(2),coeff405(3),coeff405(4));

        fitted_curve_465 = cfit( ...
            doubleExp, ...
            coeff465(1),coeff465(2),coeff465(3),coeff465(4));

        gof_405 = struct('method','fixed_historical_coefficients');
        gof_465 = struct('method','fixed_historical_coefficients');

    else

        opts_465 = fitoptions(doubleExp);
        opts_465.StartPoint = args.baseline_bleach_start_point_465;
        opts_465.Lower = args.baseline_bleach_lower_465;
        opts_465.Upper = args.baseline_bleach_upper_465;

        opts_405 = fitoptions(doubleExp);
        opts_405.StartPoint = args.baseline_bleach_start_point_405;
        opts_405.Lower = args.baseline_bleach_lower_405;
        opts_405.Upper = args.baseline_bleach_upper_405;

        [fitted_curve_465,gof_465] = fit( ...
            base_time(:),base465(:),doubleExp,opts_465);

        [fitted_curve_405,gof_405] = fit( ...
            base_time(:),base405(:),doubleExp,opts_405);

    end

    % Force all vectors to columns before subtraction. Without this,
    % MATLAB can implicitly expand a row vector and column vector into a
    % huge N-by-N matrix.
    raw_465 = raw_465(:);
    raw_405 = raw_405(:);
    time_cropped = time_cropped(:);

    full_evaluated_fit_465 = feval(fitted_curve_465,time_cropped);
    full_evaluated_fit_465 = full_evaluated_fit_465(:);
    full_residuals_465 = raw_465 - full_evaluated_fit_465;

    full_evaluated_fit_405 = feval(fitted_curve_405,time_cropped);
    full_evaluated_fit_405 = full_evaluated_fit_405(:);
    full_residuals_405 = raw_405 - full_evaluated_fit_405;

    % Archived 405->465 scaling used the UNSMOOTHED baseline data.
    base465_corr = full_residuals_465(idx_base_start:idx_base_end);
    base405_corr = full_residuals_405(idx_base_start:idx_base_end);

    fit_coeff = polyfit(base405_corr,base465_corr,1);
    full_residuals_405 = full_residuals_405(:);
full_residuals_465 = full_residuals_465(:);
fit_405 = fit_coeff(1)*full_residuals_405 + fit_coeff(2);
fit_405 = fit_405(:);

    % Archived fallback adds 100 before calculating percent dF/F.
    adjusted_405 = fit_405(:) + 100;
    adjusted_465 = full_residuals_465(:) + 100;

    dFF = 100 * (adjusted_465 - adjusted_405) ./ adjusted_405;
    dFF = dFF(:);

    base_dFF = dFF(idx_base_start:idx_base_end);
    zdFF = (dFF-mean(base_dFF))/std(base_dFF);

    % Historical FPX extraction, including its +1 starts for T1/T2.
    idx_FPbase_start = idx_base_start - idx_sync_start;
    idx_FPbase_end   = idx_base_end   - idx_sync_start;
    idx_FPt1_start   = idx_t1_start   - idx_sync_start + 1;
    idx_FPt1_end     = idx_t1_end     - idx_sync_start;
    idx_FPt2_start   = idx_t2_start   - idx_sync_start + 1;
    idx_FPt2_end     = idx_t2_end     - idx_sync_start;

    idx_FPbase_start = max(1,idx_FPbase_start);
    idx_FPt1_start   = max(1,idx_FPt1_start);
    idx_FPt2_start   = max(1,idx_FPt2_start);

    idx_FPbase_end = min(numel(zdFF),idx_FPbase_end);
    idx_FPt1_end   = min(numel(zdFF),idx_FPt1_end);
    idx_FPt2_end   = min(numel(zdFF),idx_FPt2_end);

    FPX_base = zdFF(idx_FPbase_start:idx_FPbase_end);
    FPX_t1   = zdFF(idx_FPt1_start:idx_FPt1_end);
    FPX_t2   = zdFF(idx_FPt2_start:idx_FPt2_end);

    FPX_zdFF = vertcat(FPX_base,FPX_t1,FPX_t2);
    FPX_SampleRate = fs;
    FPX_SampleDuration = 1/(fs*60);
    FPX_time = (-10:FPX_SampleDuration:30)';

    % Historical saved traces use this branch's parameters.
    meta = struct();
    meta.figure = 'fig3d';
    meta.animal = animal;
    meta.day = args.day;
    meta.sensor = 'dLight';
    meta.bleach_mode = args.bleach_mode;
    meta.bleach_fixed_coeff_405 = args.bleach_fixed_coeff_405;
    meta.bleach_fixed_coeff_465 = args.bleach_fixed_coeff_465;
    meta.baseline_bleach_target_fs = args.baseline_bleach_target_fs;
    meta.baseline_bleach_nominal_fs = fs;
    meta.baseline_bleach_downsampling_method = 'MATLAB downsample';
    meta.baseline_bleach_start_point_405 = args.baseline_bleach_start_point_405;
    meta.baseline_bleach_start_point_465 = args.baseline_bleach_start_point_465;
    meta.baseline_bleach_lower_405 = args.baseline_bleach_lower_405;
    meta.baseline_bleach_upper_405 = args.baseline_bleach_upper_405;
    meta.baseline_bleach_lower_465 = args.baseline_bleach_lower_465;
    meta.baseline_bleach_upper_465 = args.baseline_bleach_upper_465;
    meta.baseline_bleach_model = 'a*exp(b*x)+c*exp(d*x)';
    meta.baseline_linear_fit_method = 'polyfit_unsmoothed_baseline';
    meta.dFF_method = '100*((residual465+100)-(fit405+100))/(fit405+100)';
    meta.timestamps = [base_start base_end; t1_start t1_end; t2_start t2_end];
    meta.sync_start_min = T.epocs.PrtA.onset(1,1)/60;
    meta.fit_coeff = fit_coeff;
    meta.gof_405 = gof_405;
    meta.gof_465 = gof_465;

else

    % ---------- Standard hab3-derived pathway ----------
    LP_405 = lowpass(raw_405_full,args.lowpass_hz,fs_full);
    LP_465 = lowpass(raw_465_full,args.lowpass_hz,fs_full);

    down_fac = round(fs_full/args.target_fs);
    fs = fs_full/down_fac;
    numEl = ceil(numel(LP_465)/down_fac);

    down_405 = NaN(numEl,1);
    down_465 = NaN(numEl,1);

    for i = 1:numEl
        a = (i-1)*down_fac+1;
        b = min(a+down_fac-1,numel(LP_465));
        down_405(i) = median(LP_405(a:b));
        down_465(i) = median(LP_465(a:b));
    end

    time_cropped_s = time_full(ind1:ind2);

    if numel(time_cropped_s) >= down_fac+1
        actual_intervals = diff(time_cropped_s(1:down_fac:end));
        actual_time_step = median(actual_intervals);
    else
        actual_time_step = 1/fs;
    end

    time_cropped = ((0:numEl-1)'*actual_time_step + time_cropped_s(1))/60;

    idx_base_start = find(time_cropped > base_start,1,'first');
    idx_base_end   = find(time_cropped > base_end,1,'first');
    idx_t1_start   = find(time_cropped > t1_start,1,'first');
    idx_t1_end     = find(time_cropped > t1_end,1,'first');
    idx_t2_start   = find(time_cropped > t2_start,1,'first');
    idx_t2_end     = find(time_cropped > t2_end,1,'first');

    sync_start = T.epocs.PrtA.onset(1,1)/60;
    idx_sync_start = find(time_cropped > sync_start,1,'first');

    if strcmpi(args.bleach_mode,'hab3_curve_fixed')

        if numel(args.fixed_hab3_coeff_405) ~= 4 || ...
                numel(args.fixed_hab3_coeff_465) ~= 4
            error(['Fixed historical hab3 mode requires four coefficients ' ...
                   'for both 405 and 465 for %s.'],animal);
        end

        fixedExp = fittype( ...
            'a*exp(b*x) + c*exp(d*x)', ...
            'independent','x', ...
            'dependent','y');

        c405 = args.fixed_hab3_coeff_405(:)';
        c465 = args.fixed_hab3_coeff_465(:)';

        fitted_curve_405 = cfit( ...
            fixedExp,c405(1),c405(2),c405(3),c405(4));

        fitted_curve_465 = cfit( ...
            fixedExp,c465(1),c465(2),c465(3),c465(4));

    elseif strcmpi(args.bleach_mode,'none')

        % No bleaching correction: the archived test-day pathway for these
        % animals used the downsampled 405 and 465 traces directly for the
        % subsequent baseline 405->465 linear fit.
        fitted_curve_405 = [];
        fitted_curve_465 = [];

    else

        if ~isfile(args.hab3_fit_file)
            error('Hab3 fit file not found for %s: %s',animal,args.hab3_fit_file);
        end

        S = load(args.hab3_fit_file,'fitted_curve_405','fitted_curve_465','meta');
        if ~isfield(S,'fitted_curve_405') || ~isfield(S,'fitted_curve_465')
            error('Hab3 fit file for %s lacks fitted_curve_405/fitted_curve_465.',animal);
        end

        fitted_curve_405 = S.fitted_curve_405;
        fitted_curve_465 = S.fitted_curve_465;
    end

    if strcmpi(args.bleach_mode,'none')

        % No bleaching subtraction.
        residuals_405 = down_405(:);
        residuals_465 = down_465(:);

    else

        evaluated_fit_405 = feval(fitted_curve_405,time_cropped);
        evaluated_fit_405 = evaluated_fit_405(:);
        residuals_405 = (down_405(:)-evaluated_fit_405)+down_405(1);

        evaluated_fit_465 = feval(fitted_curve_465,time_cropped);
        evaluated_fit_465 = evaluated_fit_465(:);
        residuals_465 = (down_465(:)-evaluated_fit_465)+down_465(1);

    end

    base405 = residuals_405(idx_base_start:idx_base_end);
    base465 = residuals_465(idx_base_start:idx_base_end);

    movmedian_base405 = movmedian(base405,args.baseline_smooth);
    movmedian_base465 = movmedian(base465,args.baseline_smooth);

    fit_coeff = polyfit(movmedian_base405,movmedian_base465,1);
    fit_405 = fit_coeff(1)*residuals_405 + fit_coeff(2);

    dFF = (residuals_465-fit_405)./fit_405;
    base_dFF = dFF(idx_base_start:idx_base_end);
    zdFF = (dFF-mean(base_dFF))/std(base_dFF);

    idx_FPbase_start = max(1,idx_base_start-idx_sync_start);
    idx_FPbase_end   = idx_base_end-idx_sync_start;
    idx_FPt1_start   = max(1,idx_t1_start-idx_sync_start);
    idx_FPt1_end     = idx_t1_end-idx_sync_start;
    idx_FPt2_start   = max(1,idx_t2_start-idx_sync_start);
    idx_FPt2_end     = idx_t2_end-idx_sync_start;

    FPX_base = zdFF(idx_FPbase_start:idx_FPbase_end);
    FPX_t1   = zdFF(idx_FPt1_start:idx_FPt1_end);
    FPX_t2   = zdFF(idx_FPt2_start:idx_FPt2_end);

    FPX_SampleRate = fs;
    FPX_SampleDuration = 1/(fs*60);
    FPX_zdFF = vertcat(FPX_base,FPX_t1,FPX_t2);
    FPX_time = (-10:FPX_SampleDuration:30)';

    meta = struct();
    meta.figure = 'fig3d';
    meta.animal = animal;
    meta.day = args.day;
    meta.sensor = 'dLight';
    meta.bleach_mode = args.bleach_mode;
    meta.fixed_hab3_coeff_405 = args.fixed_hab3_coeff_405;
    meta.fixed_hab3_coeff_465 = args.fixed_hab3_coeff_465;
    meta.hab3_fit_file = args.hab3_fit_file;
    meta.hab3_fit_file = args.hab3_fit_file;
    meta.baseline_smooth_window = args.baseline_smooth;
    meta.fit_coeff = fit_coeff;
    meta.timestamps = [base_start base_end; t1_start t1_end; t2_start t2_end];
    meta.sync_start_min = sync_start;
end

% ---------- Shared save ----------
save_dir = fullfile(args.output_root,args.day,animal);
if ~isfolder(save_dir), mkdir(save_dir); end

file_name = fullfile(save_dir,[args.day,'_',animal,'_processed.mat']);

save(file_name, ...
    'FPX_base','FPX_SampleDuration','FPX_SampleRate','FPX_t1','FPX_t2', ...
    'FPX_time','FPX_zdFF','fs','fit_coeff', ...
    'raw_465_full','raw_405_full','time_cropped','dFF','zdFF','meta', ...
    '-v7.3');

output = struct();
output.animal = animal;
output.day = args.day;
output.FPX_zdFF = FPX_zdFF;
output.FPX_time = FPX_time;
output.FPX_SampleRate = FPX_SampleRate;
output.dFF = dFF;
output.zdFF = zdFF;
output.meta = meta;

logf(sprintf('Saved %s',file_name));
end

function id = normalize_id(x)
s = regexprep(char(string(x)),'[^0-9]','');
if numel(s) < 6, s = sprintf('%06s',s); end
id = s;
end

function store = resolve_store(T,wanted)
store = '';
if isfield(T,'streams')
    f = fieldnames(T.streams);
    idx = find(strcmpi(f,wanted),1,'first');
    if ~isempty(idx), store = f{idx}; end
end
end

function [time_s,sig,fs] = get_stream(T,store)
S = T.streams.(store);
sig = double(S.data(:));
fs = S.fs;
time_s = (1:numel(sig))'/fs;
end

function tf = valid_timestamps(x)
required_fields = {'baseline','t1','t2'};
tf = isstruct(x) && all(isfield(x,required_fields)) && ...
    all(cellfun(@(f) isnumeric(x.(f)) && numel(x.(f)) == 2, ...
    required_fields));
end
