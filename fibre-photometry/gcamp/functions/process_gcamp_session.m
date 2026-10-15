function output = process_gcamp_session(session,cfg,mode)
% PROCESS_GCAMP_SESSION Process one Hab3 or test-day GCaMP recording.

mode = lower(char(string(mode)));
assert(any(strcmp(mode,{'hab3','test'})),'Mode must be hab3 or test.');
subject = session.subject;
if strcmp(mode,'hab3')
    condition = 'hab3';
    data_folder = fullfile(cfg.data_root,'hab3',subject);
else
    condition = session.group;
    data_folder = fullfile(resolve_gcamp_group_folder(cfg.data_root,condition),subject);
end

recording = load_gcamp_recording(data_folder, ...
    'ExpectedSubject',subject,'ExpectedCondition',condition);
fs_full = recording.fs;
% TDT indexed the first sample at 1/fs; public Parquet time starts at zero.
time_full_s = recording.time_s(:)+1/fs_full;
finish_s = time_full_s(end);
labels = lower(strtrim(string(recording.notes.event_label)));
end_rows = find(labels=="end");
if ~isempty(end_rows)
    finish_s = min(finish_s,max(recording.notes.onset_s(end_rows)));
end

i1 = find(time_full_s>cfg.processing.raw_start_s,1,'first');
i2 = find(time_full_s<=finish_s,1,'last');
assert(~isempty(i1)&&~isempty(i2)&&i2>i1,'Invalid recording crop for %s.',subject);
raw405 = recording.reference(i1:i2);
raw465 = recording.signal(i1:i2);
time_cropped_min = time_full_s(i1:i2)./60;

lp405 = lowpass(raw405,cfg.processing.lowpass_hz,fs_full);
lp465 = lowpass(raw465,cfg.processing.lowpass_hz,fs_full);
factor = round(fs_full/cfg.processing.target_fs);
fs = fs_full/factor;
n = ceil(numel(lp465)/factor);
down405 = nan(n,1);
down465 = nan(n,1);
for k = 1:n
    first = (k-1)*factor+1;
    last = min(first+factor-1,numel(lp465));
    down405(k) = median(lp405(first:last));
    down465(k) = median(lp465(first:last));
end
actual_step_min = median(diff(time_cropped_min(1:factor:end)));
time_min = (0:n-1)'.*actual_step_min+time_cropped_min(1);

if strcmp(mode,'hab3')
    output = fit_hab3(session,cfg,time_min,down405,down465,fs,recording);
else
    output = process_test(session,cfg,time_min,down405,down465,fs,recording);
end
end

function output = fit_hab3(session,cfg,time_min,down405,down465,fs,recording)
subject = session.subject;
smooth405 = movmin(down405,cfg.processing.bleach_smoothing_window);
smooth465 = movmin(down465,cfg.processing.bleach_smoothing_window);
fit_start = session.hab3_fit_start_index;
fit_end = numel(time_min)-cfg.processing.bleach_fit_trim_end_samples;
assert(fit_start>=1&&fit_end>fit_start, ...
    'Invalid Hab3 bleach-fit interval for %s.',subject);

double_exp = fittype('a*exp(b*x)+c*exp(d*x)', ...
    'independent','x','dependent','y');
opts405 = fitoptions(double_exp);
opts405.StartPoint = session.hab3_start_point_405;
opts465 = fitoptions(double_exp);
opts465.StartPoint = session.hab3_start_point_465;
use_fixed_fit = isfield(session,'hab3_fit_coefficients_405')&& ...
    numel(session.hab3_fit_coefficients_405)==4&& ...
    isfield(session,'hab3_fit_coefficients_465')&& ...
    numel(session.hab3_fit_coefficients_465)==4;
if use_fixed_fit
    coefficients_405 = session.hab3_fit_coefficients_405;
    coefficients_465 = session.hab3_fit_coefficients_465;
    fitted_curve_405 = cfit(double_exp,coefficients_405(1), ...
        coefficients_405(2),coefficients_405(3),coefficients_405(4));
    fitted_curve_465 = cfit(double_exp,coefficients_465(1), ...
        coefficients_465(2),coefficients_465(3),coefficients_465(4));
    gof_405 = struct('sse',NaN,'rsquare',NaN,'dfe',NaN, ...
        'adjrsquare',NaN,'rmse',NaN);
    gof_465 = gof_405;
else
    [fitted_curve_405,gof_405] = fit(time_min(fit_start:fit_end), ...
        smooth405(fit_start:fit_end),double_exp,opts405);
    [fitted_curve_465,gof_465] = fit(time_min(fit_start:fit_end), ...
        smooth465(fit_start:fit_end),double_exp,opts465);
end

save_dir = fullfile(cfg.processed_root,'hab3',subject);
if ~isfolder(save_dir), mkdir(save_dir); end
output_file = fullfile(save_dir,['hab3_' subject '_processed.mat']);
meta = common_meta(session,cfg,'hab3',recording,fs);
meta.bleach_fit_start_index = fit_start;
meta.bleach_fit_end_index = fit_end;
meta.start_point_405 = session.hab3_start_point_405;
meta.start_point_465 = session.hab3_start_point_465;
meta.used_archived_fit_coefficients = use_fixed_fit;
save(output_file,'fitted_curve_405','fitted_curve_465','gof_405','gof_465', ...
    'time_min','down405','down465','smooth405','smooth465','fs','meta','-v7.3');

output = struct('subject',subject,'mode','hab3','file',output_file, ...
    'coefficients_405',coeffvalues(fitted_curve_405), ...
    'coefficients_465',coeffvalues(fitted_curve_465));
end

function output = process_test(session,cfg,time_min,down405,down465,fs,recording)
subject = session.subject;
fit_file = fullfile(cfg.processed_root,'hab3',subject, ...
    ['hab3_' subject '_processed.mat']);
bleach_mode = lower(char(string(session.test_bleach_mode)));
fitted_curve_405 = [];
fitted_curve_465 = [];
gof_405 = [];
gof_465 = [];
test_fit_coefficients_405 = [];
test_fit_coefficients_465 = [];
evaluated_fit_405 = nan(size(down405));
evaluated_fit_465 = nan(size(down465));

switch bleach_mode
    case 'hab3'
        assert(isfile(fit_file),'Hab3 fit is missing for %s: %s',subject,fit_file);
        H = load(fit_file,'fitted_curve_405','fitted_curve_465');
        fitted_curve_405 = H.fitted_curve_405;
        fitted_curve_465 = H.fitted_curve_465;
        evaluated_fit_405 = feval(fitted_curve_405,time_min);
        evaluated_fit_465 = feval(fitted_curve_465,time_min);
        residuals_405 = down405(:)-evaluated_fit_405(:)+down405(1);
        residuals_465 = down465(:)-evaluated_fit_465(:)+down465(1);

    case 'none'
        % Several historical test-day scripts intentionally performed no
        % bleach subtraction before fitting the 405-nm reference.
        residuals_405 = down405(:);
        residuals_465 = down465(:);

    case 'test-refit'
        % Subject 027590 was re-fitted on the test-day recording in the
        % analysis used for the figure, superseding the loaded Hab3 curves.
        smooth405 = movmin(down405,cfg.processing.bleach_smoothing_window);
        smooth465 = movmin(down465,cfg.processing.bleach_smoothing_window);
        fit_start = session.test_refit_start_index;
        double_exp = fittype('a*exp(b*x)+c*exp(d*x)', ...
            'independent','x','dependent','y');
        opts405 = fitoptions(double_exp);
        opts405.StartPoint = session.test_refit_start_point_405;
        opts465 = fitoptions(double_exp);
        opts465.StartPoint = session.test_refit_start_point_465;
        [fitted_curve_405,gof_405] = fit(time_min(fit_start:end), ...
            smooth405(fit_start:end),double_exp,opts405);
        [fitted_curve_465,gof_465] = fit(time_min(fit_start:end), ...
            smooth465(fit_start:end),double_exp,opts465);
        evaluated_fit_405 = feval(fitted_curve_405,time_min);
        evaluated_fit_465 = feval(fitted_curve_465,time_min);
        residuals_405 = down405(:)-evaluated_fit_405(:)+smooth405(1);
        residuals_465 = down465(:)-evaluated_fit_465(:)+smooth465(1);

    case 'test-fixed-fit'
        % The coefficients saved by the original 027590 analysis are used
        % explicitly because newer MATLAB releases converge to a different
        % local solution when the same unconstrained fit is repeated.
        test_fit_coefficients_405 = session.test_fit_coefficients_405;
        test_fit_coefficients_465 = session.test_fit_coefficients_465;
        assert(numel(test_fit_coefficients_405)==4&& ...
            numel(test_fit_coefficients_465)==4, ...
            'Fixed test-day fit coefficients are missing for %s.',subject);
        evaluated_fit_405 = evaluate_double_exp( ...
            test_fit_coefficients_405,time_min);
        evaluated_fit_465 = evaluate_double_exp( ...
            test_fit_coefficients_465,time_min);
        smooth405 = movmin(down405,cfg.processing.bleach_smoothing_window);
        smooth465 = movmin(down465,cfg.processing.bleach_smoothing_window);
        residuals_405 = down405(:)-evaluated_fit_405(:)+smooth405(1);
        residuals_465 = down465(:)-evaluated_fit_465(:)+smooth465(1);

    otherwise
        error('Unknown test-day bleach mode "%s" for %s.',bleach_mode,subject);
end

W = session.timestamps;
absolute.base_start = first_gt(time_min,W.baseline(1));
absolute.base_end = first_gt(time_min,W.baseline(2));
absolute.t1_start = first_gt(time_min,W.t1(1));
absolute.t1_end = first_gt(time_min,W.t1(2));
absolute.t2_start = first_gt(time_min,W.t2(1));
absolute.t2_end = first_gt(time_min,W.t2(2));
assert(all(structfun(@(x)~isempty(x),absolute)), ...
    'One or more test windows could not be mapped for %s.',subject);
index_fields = fieldnames(absolute);
for index_field = index_fields(:)'
    name = index_field{1};
    absolute.(name) = absolute.(name)+session.window_index_offsets.(name);
end
assert(all(structfun(@(x)x>=1&&x<=numel(time_min),absolute)), ...
    'One or more adjusted test-window indices are invalid for %s.',subject);

baseline_fit_start = absolute.base_start+session.baseline_fit_start_offset_samples;
assert(baseline_fit_start<=absolute.base_end, ...
    'Baseline fit start offset is invalid for %s.',subject);
base405 = residuals_405(baseline_fit_start:absolute.base_end);
base465 = residuals_465(baseline_fit_start:absolute.base_end);
sm405 = movmedian(base405,session.baseline_smoothing_window);
sm465 = movmedian(base465,session.baseline_smoothing_window);
fit_coeff = polyfit(sm405,sm465,1);
fit_405 = fit_coeff(1).*residuals_405+fit_coeff(2);
dFF = (residuals_465-fit_405)./fit_405;
base_dFF = dFF(absolute.base_start:absolute.base_end);
zdFF = (dFF-mean(base_dFF))./std(base_dFF);

sync_start_s = recording.video_sync.onset_s(1);
shift = first_gt(time_min,sync_start_s/60);
assert(~isempty(shift),'Video-synchronization start could not be mapped for %s.',subject);
assert(shift==session.historical_sync_shift_samples, ...
    ['Video-synchronization shift for %s is %d samples; the archived ', ...
    'analysis recorded %d.'],subject,shift,session.historical_sync_shift_samples);
analysis_indices = structfun(@(x)x-shift,absolute,'UniformOutput',false);
values = cell2mat(struct2cell(analysis_indices));
assert(all(values>=1)&&all(values<=numel(zdFF)), ...
    'Historical index shift is invalid for %s.',subject);

FPX_base = zdFF(analysis_indices.base_start:analysis_indices.base_end);
FPX_t1 = zdFF(analysis_indices.t1_start:analysis_indices.t1_end);
FPX_t2 = zdFF(analysis_indices.t2_start:analysis_indices.t2_end);
FPX_base = pad_to_expected(FPX_base,round(10*60*fs));
FPX_t1 = pad_to_expected(FPX_t1,round(15*60*fs));
FPX_t2 = pad_to_expected(FPX_t2,round(15*60*fs));
FPX_zdFF = vertcat(FPX_base,FPX_t1,FPX_t2);
FPX_time = linspace(cfg.processing.fpx_time_range_min(1), ...
    cfg.processing.fpx_time_range_min(2),numel(FPX_zdFF))';
FPX_SampleRate = fs;
FPX_SampleDuration = 1/(fs*60);

save_dir = fullfile(cfg.processed_root,session.group,subject);
if ~isfolder(save_dir), mkdir(save_dir); end
output_file = fullfile(save_dir, ...
    ['test_' session.group '_' subject '_processed.mat']);
meta = common_meta(session,cfg,'test',recording,fs);
meta.test_bleach_mode = bleach_mode;
if strcmp(bleach_mode,'hab3')
    meta.hab3_fit_file = fit_file;
else
    meta.hab3_fit_file = '';
end
meta.baseline_fit_start_offset_samples = ...
    session.baseline_fit_start_offset_samples;
meta.test_fit_coefficients_405 = test_fit_coefficients_405;
meta.test_fit_coefficients_465 = test_fit_coefficients_465;
meta.baseline_fit_coefficients = fit_coeff;
meta.historical_sync_shift_samples = shift;
meta.video_sync_used = true;
meta.video_sync_start_s = sync_start_s;
meta.video_sync_source_store = ...
    char(string(recording.metadata.video_synchronization.source_store));
meta.timestamps_min = W;
meta.window_index_offsets = session.window_index_offsets;
save(output_file,'FPX_base','FPX_t1','FPX_t2','FPX_zdFF','FPX_time', ...
    'FPX_SampleRate','FPX_SampleDuration','time_min','down405','down465', ...
    'residuals_405','residuals_465','fit_405','fit_coeff','dFF','zdFF', ...
    'evaluated_fit_405','evaluated_fit_465','absolute','analysis_indices', ...
    'fitted_curve_405','fitted_curve_465','gof_405','gof_465', ...
    'test_fit_coefficients_405','test_fit_coefficients_465', ...
    'bleach_mode','baseline_fit_start','meta','-v7.3');

output = struct('subject',subject,'mode','test','group',session.group, ...
    'file',output_file,'FPX_zdFF',FPX_zdFF,'FPX_time',FPX_time, ...
    'analysis_indices',analysis_indices);
end

function values = pad_to_expected(values,expected)
difference = expected-numel(values);
if difference>0, values=[values;nan(difference,1)]; end
end

function idx = first_gt(values,boundary)
idx = find(values>boundary,1,'first');
end

function values = evaluate_double_exp(coefficients,time)
values = coefficients(1).*exp(coefficients(2).*time)+ ...
    coefficients(3).*exp(coefficients(4).*time);
end

function meta = common_meta(session,cfg,mode,recording,fs)
meta = struct('figure',cfg.figure,'subject',session.subject, ...
    'group',session.group,'mode',mode,'sensor',cfg.sensor, ...
    'sample_rate_hz',fs,'lowpass_hz',cfg.processing.lowpass_hz, ...
    'target_sample_rate_hz',cfg.processing.target_fs, ...
    'input_format',['subject-prefixed photometry and video-sync Parquet + ', ...
    'subject-prefixed notes CSV + metadata JSON'], ...
    'reference_column',recording.reference_column, ...
    'signal_column',recording.signal_column,'video_sync_available',true, ...
    'video_sync_used',false);
end

function folder = resolve_gcamp_group_folder(root,group)
% The shared archive uses lower-case group directories (e.g. rg/), while
% the figure configuration retains the conventional upper-case group codes.
% Resolve the directory by name so extraction on a case-sensitive filesystem
% remains reproducible.
entries = dir(root);
matches = entries([entries.isdir] & strcmpi({entries.name},char(group)));
if isempty(matches)
    folder = fullfile(root,char(group));
else
    folder = fullfile(root,matches(1).name);
end
end
