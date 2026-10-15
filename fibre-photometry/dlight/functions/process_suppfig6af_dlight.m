function results = process_suppfig6af_dlight(paths,cfg)
% PROCESS_SUPPFIG6AF_DLIGHT Derive Supplemental Fig. 6a-f from raw Parquet.
%
% The workflow deliberately does not read the manuscript source-data CSVs.
% It loads the habituation recordings from cohorts 1-3 and the representative
% cohort-1 test recording, then recreates the plotted-value tables used by
% the summary workflow.

arguments
    paths (1,1) struct
    cfg (1,1) struct
end

requiredPaths = {'fig2bd_root','fig3dg_root','suppfig6af_root', ...
    'suppfig6af_processed_root'};
for i = 1:numel(requiredPaths)
    name = requiredPaths{i};
    assert(isfield(paths,name) && strlength(string(paths.(name)))>0, ...
        'dlight_paths.m must define paths.%s.',name);
end

processedRoot = paths.suppfig6af_processed_root;
if ~isfolder(processedRoot), mkdir(processedRoot); end
cfg = prepareFitConfig(cfg);

cohorts = { ...
    'Cohort1', cfg.cohort1_subjects, fullfile(paths.fig3dg_root,'hab3'); ...
    'Cohort2', cfg.cohort2_subjects, fullfile(paths.fig2bd_root,'hab3'); ...
    'Cohort3', cfg.cohort3_subjects, fullfile(paths.suppfig6af_root,'hab3-cohort3')};

panelC = table();
panelE = table();
panelAB = table();
panelD = table();
fitCoefficientsUsed = table();
bleachCoefficientsUsed = table();
representativeHabFit = struct();

for c = 1:size(cohorts,1)
    cohort = cohorts{c,1};
    subjects = cohorts{c,2};
    sourceRoot = cohorts{c,3};
    assert(isfolder(sourceRoot),'Required raw-data folder not found: %s',sourceRoot);

    for s = 1:numel(subjects)
        subject = subjects{s};
        fprintf('\n=== Supplemental Fig. 6a-f | %s | %s ===\n',cohort,subject);
        dataFolder = fullfile(sourceRoot,subject);
        H = prepareHabituation(dataFolder,subject,cohort,cfg);
        bleachCoefficientsUsed = [bleachCoefficientsUsed; ...
            bleachCoefficientTable(cfg.fit_window_mode,cohort,subject, ...
            H.coeff405,H.coeff465)]; %#ok<AGROW>

        [row,example] = calculateRmse(H,cohort,subject,cfg);
        panelC = [panelC; row]; %#ok<AGROW>
        if strcmp(subject,cfg.panel_ab_subject)
            panelAB = example;
        end

        [rows,traceTable,coefficientRows] = ...
            calculateFitWindows(H,cohort,subject,cfg);
        panelE = [panelE; rows]; %#ok<AGROW>
        fitCoefficientsUsed = [fitCoefficientsUsed; coefficientRows]; %#ok<AGROW>
        if strcmp(subject,cfg.panel_d_subject)
            panelD = traceTable;
        end

        if strcmp(subject,cfg.panel_f_subject)
            representativeHabFit = H;
        end
    end
end

assert(~isempty(panelAB),'Panel a-b representative subject %s was not processed.', ...
    cfg.panel_ab_subject);
assert(~isempty(panelD),'Panel d representative subject %s was not processed.', ...
    cfg.panel_d_subject);
assert(~isempty(fieldnames(representativeHabFit)), ...
    'Panel f habituation fit for %s was not processed.',cfg.panel_f_subject);

panelF = calculateTestExample(paths.fig3dg_root,representativeHabFit,cfg);

writetable(panelAB,fullfile(processedRoot,cfg.files.panel_ab));
writetable(panelC,fullfile(processedRoot,cfg.files.panel_c));
writetable(panelD,fullfile(processedRoot,cfg.files.panel_d));
writetable(panelE,fullfile(processedRoot,cfg.files.panel_e));
writetable(panelF,fullfile(processedRoot,cfg.files.panel_f));
writetable(fitCoefficientsUsed, ...
    fullfile(processedRoot,cfg.files.fit_coefficients));
writetable(bleachCoefficientsUsed, ...
    fullfile(processedRoot,cfg.files.bleach_coefficients));

manifest = table( ...
    ["a-b";"c";"d";"e";"f"], ...
    string({cfg.files.panel_ab;cfg.files.panel_c;cfg.files.panel_d; ...
    cfg.files.panel_e;cfg.files.panel_f}), ...
    ["raw Parquet: cohort 3 habituation"; ...
    "raw Parquet: cohort 1-3 habituation"; ...
    "raw Parquet: cohort 1 habituation"; ...
    "raw Parquet: cohort 1-3 habituation"; ...
    "raw Parquet: cohort 1 habituation and test"], ...
    repmat(string(cfg.fit_window_mode),5,1), ...
    'VariableNames',{'Panel','OutputFile','DerivedFrom','FitMode'});
writetable(manifest,fullfile(processedRoot,'suppfig6af_processing_manifest.csv'));

results = struct('processed_root',processedRoot,'panel_ab',panelAB, ...
    'panel_c',panelC,'panel_d',panelD,'panel_e',panelE,'panel_f',panelF, ...
    'fit_coefficients',fitCoefficientsUsed, ...
    'bleach_coefficients',bleachCoefficientsUsed);
fprintf('\nSupplemental Fig. 6a-f processing complete: %s\n',processedRoot);
end

function H = prepareHabituation(dataFolder,subject,cohort,cfg)
switch cohort
    case 'Cohort1'
        subjectCfg = fig3dg_config(subject);
        options = struct( ...
            'raw_start_s',subjectCfg.raw_start_s, ...
            'lowpass_hz',subjectCfg.lowpass_hz, ...
            'target_fs',subjectCfg.target_fs, ...
            'reset_time',false, ...
            'use_end_note',true, ...
            'smooth_method',subjectCfg.hab3.bleach_smoothing_method, ...
            'smooth_window',subjectCfg.hab3.bleach_smoothing_window, ...
            'fit_start',subjectCfg.hab3.bleach_fit_start_idx, ...
            'fit_end_trim',subjectCfg.hab3.bleach_fit_end_trim_idx, ...
            'start_405',subjectCfg.hab3.start_point_405, ...
            'start_465',subjectCfg.hab3.start_point_465, ...
            'fit_offset',false, ...
            'recording_end_min',Inf, ...
            'artifact_intervals',zeros(0,2));
    case 'Cohort2'
        subjectCfg = fig2bd_config(subject,'hab3');
        options = struct( ...
            'raw_start_s',subjectCfg.raw_start_s, ...
            'lowpass_hz',subjectCfg.hab3.lowpass_hz, ...
            'target_fs',subjectCfg.target_fs, ...
            'reset_time',false, ...
            'use_end_note',false, ...
            'smooth_method','movmin', ...
            'smooth_window',subjectCfg.hab3.bleach_smoothing_window, ...
            'fit_start',subjectCfg.hab3.fit_trim_start, ...
            'fit_end_trim',subjectCfg.hab3.fit_trim_end, ...
            'start_405',subjectCfg.hab3.start_point_405, ...
            'start_465',subjectCfg.hab3.start_point_465, ...
            'fit_offset',false, ...
            'recording_end_min',subjectValue( ...
                cfg.cohort2_recording_end_min,subject), ...
            'artifact_intervals',zeros(0,2));
    case 'Cohort3'
        options = struct( ...
            'raw_start_s',0, ...
            'lowpass_hz',cfg.lowpass_hz, ...
            'target_fs',cfg.target_fs, ...
            'reset_time',true, ...
            'use_end_note',false, ...
            'smooth_method','movmedian', ...
            'smooth_window',cfg.slow_smoothing_window, ...
            'fit_start',1, ...
            'fit_end_trim',0, ...
            'start_405',[], ...
            'start_465',[], ...
            'fit_offset',true, ...
            'recording_end_min',subjectValue( ...
                cfg.cohort3_recording_end_min,subject), ...
            'artifact_intervals',artifactIntervals(cfg,subject));
    otherwise
        error('Unknown cohort: %s',cohort);
end

[t,x405,x465,fs] = loadAndDownsample(dataFolder,subject,options);
if isfinite(options.recording_end_min)
    keep = t<=options.recording_end_min;
    assert(any(keep),'Historical recording endpoint is outside %s.',subject);
    t=t(keep); x405=x405(keep); x465=x465(keep);
end
valid = isfinite(t) & isfinite(x405) & isfinite(x465);
[~,excluded] = apply_fp_artifact_intervals( ...
    t,[x405 x465],options.artifact_intervals,'Method','mask');
fitStart = max(1,options.fit_start);
fitEnd = numel(t)-options.fit_end_trim;
assert(fitEnd>fitStart,'Invalid habituation fit range for %s.',subject);
fitMask = valid & ~excluded;
fitMask(1:fitStart-1) = false;
if fitEnd<numel(fitMask), fitMask(fitEnd+1:end) = false; end
fitIdx = find(fitMask);
assert(numel(fitIdx)>=20,'Too few fit samples for %s.',subject);
% Historical RMSE summaries used the first-to-last bleaching-fit range,
% including any internal artifact periods. The artifacts affected the
% bleaching fit itself, but were not removed from the later RMSE comparison.
rmseIdx = (fitIdx(1):fitIdx(end))';
rmseIdx = rmseIdx(valid(rmseIdx));

switch lower(options.smooth_method)
    case 'movmin'
        smooth405 = movmin(x405,options.smooth_window);
        smooth465 = movmin(x465,options.smooth_window);
    case 'movmedian'
        smooth405 = movmedian(x405,options.smooth_window,'omitnan');
        smooth465 = movmedian(x465,options.smooth_window,'omitnan');
    otherwise
        error('Unknown smoothing method: %s',options.smooth_method);
end

if strcmp(cfg.fit_window_mode,'locked')
    [coeff405,coeff465] = lockedBleachFits( ...
        cfg.bleach_fit_coefficients,cohort,subject);
elseif options.fit_offset
    coeff405 = fitBleachWithOffset(t(fitIdx),smooth405(fitIdx));
    coeff465 = fitBleachWithOffset(t(fitIdx),smooth465(fitIdx));
else
    coeff405 = fitBleachNoOffset(t(fitIdx),smooth405(fitIdx),options.start_405);
    coeff465 = fitBleachNoOffset(t(fitIdx),smooth465(fitIdx),options.start_465);
end

H = struct('subject',subject,'cohort',cohort,'time_min',t, ...
    'raw405',x405,'raw465',x465,'fs',fs,'fit_idx',fitIdx, ...
    'rmse_idx',rmseIdx, ...
    'fit_mask',fitMask,'artifact_mask',~excluded,'fit_offset',options.fit_offset, ...
    'coeff405',coeff405,'coeff465',coeff465, ...
    'artifact_intervals',options.artifact_intervals);
end

function [t,x405,x465,fs] = loadAndDownsample(dataFolder,subject,options)
recording = load_dlight_recording(dataFolder, ...
    'ExpectedSubject',subject,'ExpectedCondition','hab3');
time = recording.time_s(:);
finish = time(end);
if options.use_end_note
    labels = lower(strtrim(string(recording.notes.event_label)));
    endRows = find(labels=="end");
    if ~isempty(endRows)
        finish = min(finish,max(recording.notes.onset_s(endRows)));
    end
end

if options.raw_start_s>0
    first = find(time>options.raw_start_s,1,'first');
else
    first = 1;
end
last = find(time<=finish,1,'last');
assert(~isempty(first) && ~isempty(last) && last>first, ...
    'Invalid raw crop for %s.',subject);

raw405 = double(recording.reference(first:last));
raw465 = double(recording.signal(first:last));
croppedTime = time(first:last);
filtered405 = lowpass(raw405,options.lowpass_hz,recording.fs);
filtered465 = lowpass(raw465,options.lowpass_hz,recording.fs);
factor = max(1,round(recording.fs/options.target_fs));
fs = recording.fs/factor;
x405 = medianDownsample(filtered405,factor);
x465 = medianDownsample(filtered465,factor);
n = min(numel(x405),numel(x465));
x405 = x405(1:n); x465 = x465(1:n);

if options.reset_time
    t = ((0:n-1)'/fs)/60;
else
    if numel(croppedTime)>=factor+1
        step = median(diff(croppedTime(1:factor:end)));
    else
        step = 1/fs;
    end
    t = ((0:n-1)'*step+croppedTime(1))/60;
end
end

function y = medianDownsample(x,factor)
n = ceil(numel(x)/factor);
y = nan(n,1);
for i = 1:n
    first = (i-1)*factor+1;
    last = min(i*factor,numel(x));
    y(i) = median(x(first:last),'omitnan');
end
end

function [row,example] = calculateRmse(H,cohort,subject,cfg)
t = H.time_min; raw405 = H.raw405; raw465 = H.raw465;
fit405 = evalBleach(H.coeff405,t);
fit465 = evalBleach(H.coeff465,t);
fitIdx = H.rmse_idx;
if strcmp(cohort,'Cohort1') && strcmp(subject,'035031')
    fitIdx = fitIdx(t(fitIdx)>=t(fitIdx(1))+1);
end
anchor = fitIdx(t(fitIdx)<=t(fitIdx(1))+1);
if numel(anchor)<5, anchor=fitIdx(1:min(100,numel(fitIdx))); end
corr405 = raw405-fit405+median(raw405(anchor),'omitnan');
corr465 = raw465-fit465+median(raw465(anchor),'omitnan');

slowRaw405 = movmedian(raw405,cfg.slow_smoothing_window,'omitnan');
slowRaw465 = movmedian(raw465,cfg.slow_smoothing_window,'omitnan');
slowCorr405 = movmedian(corr405,cfg.slow_smoothing_window,'omitnan');
slowCorr465 = movmedian(corr465,cfg.slow_smoothing_window,'omitnan');
[rmseRaw,pRaw] = linearRmse(slowRaw405(fitIdx),slowRaw465(fitIdx));
[rmseCorr,pCorr] = linearRmse(slowCorr405(fitIdx),slowCorr465(fitIdx));

row = table(string(cohort),string(subject),rmseRaw,rmseCorr,rmseRaw-rmseCorr, ...
    'VariableNames',{'Cohort','AnimalID','RMSE_Uncorrected', ...
    'RMSE_BleachCorrected','RMSE_Reduction'});

example = table();
if strcmp(subject,cfg.panel_ab_subject)
    scaledRaw = polyval(pRaw,slowRaw405);
    scaledCorr = polyval(pCorr,slowCorr405);
    included = false(size(t)); included(fitIdx)=true;
    displayed = t>=cfg.panel_ab_window_min(1) & t<=cfg.panel_ab_window_min(2);
    example = table(t,displayed,H.artifact_mask,included,included, ...
        slowRaw465,scaledRaw,slowRaw465-scaledRaw, ...
        slowCorr465,scaledCorr,slowCorr465-scaledCorr, ...
        'VariableNames',{'Time_min','DisplayedWindow','ArtifactIncluded', ...
        'Included_UncorrectedRMSE','Included_CorrectedRMSE', ...
        'Uncorrected465','UncorrectedScaled405','UncorrectedResidual', ...
        'BleachCorrected465','BleachCorrectedScaled405', ...
        'BleachCorrectedResidual'});
end
end

function [rmse,p] = linearRmse(x,y)
valid = isfinite(x) & isfinite(y);
p = polyfit(x(valid),y(valid),1);
residual = y(valid)-polyval(p,x(valid));
rmse = sqrt(mean(residual.^2));
end

function cfg = prepareFitConfig(cfg)
assert(isfield(cfg,'fit_window_mode'), ...
    'suppfig6af_config.m must define fit_window_mode.');
mode = validatestring(lower(char(string(cfg.fit_window_mode))), ...
    {'locked','refit'});
cfg.fit_window_mode = mode;

if strcmp(mode,'locked')
    assert(isfield(cfg,'fit_window_coefficients_file') && ...
        isfile(cfg.fit_window_coefficients_file), ...
        'Locked fit coefficient file not found: %s', ...
        string(cfg.fit_window_coefficients_file));
    assert(isfield(cfg,'example_fit_coefficients_file') && ...
        isfile(cfg.example_fit_coefficients_file), ...
        'Locked example-fit coefficient file not found: %s', ...
        string(cfg.example_fit_coefficients_file));
    assert(isfield(cfg,'bleach_fit_coefficients_file') && ...
        isfile(cfg.bleach_fit_coefficients_file), ...
        'Locked bleaching coefficient file not found: %s', ...
        string(cfg.bleach_fit_coefficients_file));
    cfg.fit_window_coefficients = readFitCoefficientTable( ...
        cfg.fit_window_coefficients_file,true);
    cfg.example_fit_coefficients = readFitCoefficientTable( ...
        cfg.example_fit_coefficients_file,false);
    cfg.bleach_fit_coefficients = readBleachCoefficientTable( ...
        cfg.bleach_fit_coefficients_file);
else
    cfg.fit_window_coefficients = table();
    cfg.example_fit_coefficients = table();
    cfg.bleach_fit_coefficients = table();
end
end

function coefficients = readFitCoefficientTable(file,hasCohort)
options = detectImportOptions(file,'TextType','string');
textVariables = {'AnimalID','FitWindow'};
if hasCohort, textVariables = [{'Cohort'},textVariables]; end
options = setvartype(options,textVariables,'string');
coefficients = readtable(file,options);
required = [textVariables,{'Wavelength_nm','a','b','c','d','e'}];
assert(all(ismember(required,coefficients.Properties.VariableNames)), ...
    'Fit coefficient file has missing columns: %s',file);
numericValues = coefficients{:,{'Wavelength_nm','a','b','c','d','e'}};
assert(all(isfinite(numericValues),'all'), ...
    'Fit coefficient file contains non-finite values: %s',file);
end

function coefficients = readBleachCoefficientTable(file)
options = detectImportOptions(file,'TextType','string');
options = setvartype(options,{'Cohort','AnimalID'},'string');
coefficients = readtable(file,options);
required = {'Cohort','AnimalID','Wavelength_nm','CoefficientCount', ...
    'a','b','c','d','e'};
assert(all(ismember(required,coefficients.Properties.VariableNames)), ...
    'Bleaching coefficient file has missing columns: %s',file);
coreValues = coefficients{:,{'Wavelength_nm','CoefficientCount','a','b','c','d'}};
assert(all(isfinite(coreValues),'all'), ...
    'Bleaching coefficient file contains invalid core values: %s',file);
assert(all(ismember(coefficients.CoefficientCount,[4 5])), ...
    'Bleaching coefficient count must be four or five: %s',file);
assert(all(isfinite(coefficients.e(coefficients.CoefficientCount==5))), ...
    'Five-parameter bleaching fits require a finite offset: %s',file);
end

function [coeff405,coeff465] = lockedBleachFits( ...
        coefficients,cohort,subject)
coeff405 = lockedBleachVector( ...
    coefficients,lower(string(cohort)),string(subject),405);
coeff465 = lockedBleachVector( ...
    coefficients,lower(string(cohort)),string(subject),465);
end

function p = lockedBleachVector(coefficients,cohort,subject,wavelength)
row = coefficients.Cohort==cohort & coefficients.AnimalID==subject & ...
    coefficients.Wavelength_nm==wavelength;
assert(nnz(row)==1,'Expected one locked bleaching fit for %s, %d nm.', ...
    char(subject),wavelength);
count = coefficients.CoefficientCount(row);
p = coefficients{row,{'a','b','c','d','e'}};
p = p(1:count);
end

function rows = bleachCoefficientTable(mode,cohort,subject,coeff405,coeff465)
rows = table();
for wavelength = [405 465]
    if wavelength==405, p=coeff405; else, p=coeff465; end
    values = nan(1,5); values(1:numel(p))=p;
    rows = [rows; table(string(mode),string(lower(cohort)), ...
        string(subject),wavelength,numel(p),values(1),values(2),values(3), ...
        values(4),values(5),'VariableNames',{'Mode','Cohort','AnimalID', ...
        'Wavelength_nm','CoefficientCount','a','b','c','d','e'})]; %#ok<AGROW>
end
end

function [fits405,fits465] = lockedFitWindows( ...
        coefficients,cohort,subject,labels)
fits405 = coefficientCells(coefficients,lower(string(cohort)), ...
    string(subject),405,labels,true);
fits465 = coefficientCells(coefficients,lower(string(cohort)), ...
    string(subject),465,labels,true);
end

function [fits405,fits465] = lockedExampleFits(coefficients,subject,labels)
fits405 = coefficientCells(coefficients,"",string(subject),405,labels,false);
fits465 = coefficientCells(coefficients,"",string(subject),465,labels,false);
end

function fits = coefficientCells(coefficients,cohort,subject,wavelength, ...
        labels,hasCohort)
fits = cell(1,numel(labels));
for w = 1:numel(labels)
    rows = coefficients.AnimalID==subject & ...
        coefficients.Wavelength_nm==wavelength & ...
        coefficients.FitWindow==string(labels{w});
    if hasCohort, rows = rows & coefficients.Cohort==cohort; end
    assert(nnz(rows)==1, ...
        'Expected one locked fit for subject %s, %d nm, %s.', ...
        char(subject),wavelength,labels{w});
    fits{w} = coefficients{rows,{'a','b','c','d','e'}};
end
end

function rows = fitCoefficientTable(mode,cohort,subject,labels,fits405,fits465)
rows = table();
for wavelength = [405 465]
    if wavelength==405, fits=fits405; else, fits=fits465; end
    for w = 1:numel(labels)
        p = fits{w};
        rows = [rows; table(string(mode),string(lower(cohort)), ...
            string(subject),wavelength,string(labels{w}), ...
            p(1),p(2),p(3),p(4),p(5), ...
            'VariableNames',{'Mode','Cohort','AnimalID','Wavelength_nm', ...
            'FitWindow','a','b','c','d','e'})]; %#ok<AGROW>
    end
end
end

function [rows,traceTable,coefficientRows] = ...
        calculateFitWindows(H,cohort,subject,cfg)
t = H.time_min; x405 = H.raw405; x465 = H.raw465;
startCrop = 0;
if strcmp(subject,'035031'), startCrop=cfg.fit_window_start_crop_035031_min; end
keep = isfinite(t) & isfinite(x405) & isfinite(x465) & t>=startCrop;
keep = keep & H.artifact_mask;
x405(~keep)=NaN; x465(~keep)=NaN;
s405 = movmedian(x405,cfg.slow_smoothing_window,'omitnan');
s465 = movmedian(x465,cfg.slow_smoothing_window,'omitnan');

if strcmp(cfg.fit_window_mode,'locked')
    [fits405,fits465] = lockedFitWindows( ...
        cfg.fit_window_coefficients,cohort,subject,cfg.fit_window_labels);
else
    fits405 = cell(1,3); fits465 = cell(1,3);
    for w = 1:3
        idx = keep & (isinf(cfg.fit_windows_min(w)) | ...
            t<=startCrop+cfg.fit_windows_min(w));
        fitIdx = find(idx);
        fitIdx = fitIdx(1:cfg.fit_stride:end);
        fits405{w}=fitBleachWithOffset(t(fitIdx),s405(fitIdx));
        fits465{w}=fitBleachWithOffset(t(fitIdx),s465(fitIdx));
    end
end
coefficientRows = fitCoefficientTable( ...
    cfg.fit_window_mode,cohort,subject,cfg.fit_window_labels,fits405,fits465);

comparisonEnd = min(max(t(keep)),startCrop+cfg.fit_comparison_duration_min);
comparisonKeep = keep & t<=comparisonEnd;
full405 = evalBleach(fits405{3},t);
full465 = evalBleach(fits465{3},t);
range405 = max(full405(comparisonKeep))-min(full405(comparisonKeep));
range465 = max(full465(comparisonKeep))-min(full465(comparisonKeep));
rows = table();
for w = 1:2
    post = comparisonKeep & t>startCrop+cfg.fit_windows_min(w);
    endpoint405 = evalBleach(fits405{w},comparisonEnd)- ...
        evalBleach(fits405{3},comparisonEnd);
    endpoint465 = evalBleach(fits465{w},comparisonEnd)- ...
        evalBleach(fits465{3},comparisonEnd);
    rmse405 = sqrt(mean((evalBleach(fits405{w},t(post))- ...
        evalBleach(fits405{3},t(post))).^2,'omitnan'));
    rmse465 = sqrt(mean((evalBleach(fits465{w},t(post))- ...
        evalBleach(fits465{3},t(post))).^2,'omitnan'));
    norm405 = 100*endpoint405/range405;
    norm465 = 100*endpoint465/range465;
    rows = [rows; table(string(lower(cohort)),string(subject), ...
        string(cfg.fit_window_labels{w}),endpoint405,endpoint465,rmse405,rmse465, ...
        norm405,norm465,abs(norm405),abs(norm465),rmse405/range405, ...
        rmse465/range465,'VariableNames',{'Cohort','AnimalID','FitWindow', ...
        'EndpointDifference405_raw','EndpointDifference465_raw', ...
        'ExtrapRMSE405_raw','ExtrapRMSE465_raw', ...
        'EndpointDifference405_percent','EndpointDifference465_percent', ...
        'AbsoluteEndpointDifference405_percent', ...
        'AbsoluteEndpointDifference465_percent','ExtrapRMSE405_fraction', ...
        'ExtrapRMSE465_fraction'})]; %#ok<AGROW>
end

traceTable = table();
if strcmp(subject,cfg.panel_d_subject)
    % The representative panel used all available samples rather than the
    % stride used for the across-animal comparison.
    repFits405=cell(1,3); repFits465=cell(1,3);
    repKeep=isfinite(t)&isfinite(x405)&isfinite(x465)&t>=0&H.artifact_mask;
    rep405=movmedian(x405,cfg.slow_smoothing_window,'omitnan');
    rep465=movmedian(x465,cfg.slow_smoothing_window,'omitnan');
    if strcmp(cfg.fit_window_mode,'locked')
        [repFits405,repFits465] = lockedExampleFits( ...
            cfg.example_fit_coefficients,subject,cfg.fit_window_labels);
    else
        for w=1:3
            idx=repKeep & (isinf(cfg.fit_windows_min(w)) | ...
                t<=cfg.fit_windows_min(w));
            repFits405{w}=fitBleachWithOffset(t(idx),rep405(idx));
            repFits465{w}=fitBleachWithOffset(t(idx),rep465(idx));
        end
    end
    displayed=t>=cfg.panel_d_window_min(1)&t<=cfg.panel_d_window_min(2);
    traceTable=table(t,displayed,repKeep,rep405, ...
        evalBleach(repFits405{1},t),evalBleach(repFits405{2},t), ...
        evalBleach(repFits405{3},t),rep465,evalBleach(repFits465{1},t), ...
        evalBleach(repFits465{2},t),evalBleach(repFits465{3},t), ...
        'VariableNames',{'Time_min','DisplayedWindow','IncludedInFit', ...
        'Smoothed405','Fit405_10min','Fit405_30min','Fit405_FullTrace', ...
        'Smoothed465','Fit465_10min','Fit465_30min','Fit465_FullTrace'});
end
end

function panelF = calculateTestExample(fig3Root,H,cfg)
subject=cfg.panel_f_subject;
subjectCfg=fig3dg_config(subject);
options=struct('raw_start_s',subjectCfg.raw_start_s, ...
    'lowpass_hz',subjectCfg.lowpass_hz,'target_fs',subjectCfg.target_fs, ...
    'reset_time',false);
[t,x405,x465] = loadAndDownsampleTest( ...
    fullfile(fig3Root,'test',subject),subject,options);
hab405=evalBleach(H.coeff405,t);
hab465=evalBleach(H.coeff465,t);
base=t>=subjectCfg.test.timestamps.baseline(1) & ...
    t<=subjectCfg.test.timestamps.baseline(2) & ...
    isfinite(x405)&isfinite(x465);
assert(nnz(base)>=20,'Too few representative baseline samples for %s.',subject);

hab405Plot=hab405+median(x405(base)-hab405(base),'omitnan');
hab465Plot=hab465+median(x465(base)-hab465(base),'omitnan');
corrected405=x405-hab405+x405(1);
corrected465=x465-hab465+x465(1);
base405=movmedian(corrected405(base),subjectCfg.test.baseline_fit_smoothing_window);
base465=movmedian(corrected465(base),subjectCfg.test.baseline_fit_smoothing_window);
fitCoeff=polyfit(base405,base465,1);
scaled405=polyval(fitCoeff,corrected405);
dff=(corrected465-scaled405)./scaled405;
relativeTime=t-cfg.panel_f_injection1_min;
displayed=relativeTime>=cfg.panel_f_window_min(1)& ...
    relativeTime<=cfg.panel_f_window_min(2);

panelF=table(t,relativeTime,displayed,base,x405,hab405Plot,hab405, ...
    x465,hab465Plot,hab465,corrected405,corrected465,scaled405,dff, ...
    'VariableNames',{'TimeOriginal_min','TimeRelativeToRAC_min', ...
    'DisplayedWindow','IncludedInBaselineFit','Raw405', ...
    'HabituationDerivedFit405','HabituationDerivedFit405_UnshiftedForProcessing', ...
    'Raw465','HabituationDerivedFit465', ...
    'HabituationDerivedFit465_UnshiftedForProcessing','BleachCorrected405', ...
    'BleachCorrected465','Scaled405Reference','dFF'});
end

function [t,x405,x465,fs] = loadAndDownsampleTest(dataFolder,subject,options)
recording=load_dlight_recording(dataFolder,'ExpectedSubject',subject, ...
    'ExpectedCondition','test');
time=recording.time_s(:); finish=time(end);
labels=lower(strtrim(string(recording.notes.event_label)));
endRows=find(labels=="end");
if ~isempty(endRows), finish=min(finish,max(recording.notes.onset_s(endRows))); end
first=find(time>options.raw_start_s,1,'first');
last=find(time<=finish,1,'last');
raw405=double(recording.reference(first:last));
raw465=double(recording.signal(first:last));
croppedTime=time(first:last);
filtered405=lowpass(raw405,options.lowpass_hz,recording.fs);
filtered465=lowpass(raw465,options.lowpass_hz,recording.fs);
factor=max(1,round(recording.fs/options.target_fs));
fs=recording.fs/factor;
x405=medianDownsample(filtered405,factor);
x465=medianDownsample(filtered465,factor);
n=min(numel(x405),numel(x465)); x405=x405(1:n); x465=x465(1:n);
step=median(diff(croppedTime(1:factor:end)));
t=((0:n-1)'*step+croppedTime(1))/60;
end

function coeff = fitBleachNoOffset(t,y,startPoint)
model=fittype('a*exp(b*x)+c*exp(d*x)','independent','x','dependent','y');
options=fitoptions(model); options.StartPoint=startPoint;
curve=fit(t(:),y(:),model,options);
coeff=coeffvalues(curve);
end

function coeff = fitBleachWithOffset(t,y)
model=fittype('a*exp(b*x)+c*exp(d*x)+e','independent','x','dependent','y');
y0=median(y(1:min(100,end)),'omitnan');
ye=median(y(max(1,numel(y)-99):end),'omitnan');
delta=max(y0-ye,eps);
options=fitoptions(model);
options.StartPoint=[.6*delta -.001 .4*delta -.0001 max(ye,eps)];
options.Lower=[0 -Inf 0 -Inf 0];
options.Upper=[Inf 0 Inf 0 Inf];
curve=fit(t(:),y(:),model,options);
coeff=coeffvalues(curve);
end

function y = evalBleach(coeff,t)
if numel(coeff)==4
    y=coeff(1).*exp(coeff(2).*t)+coeff(3).*exp(coeff(4).*t);
elseif numel(coeff)==5
    y=coeff(1).*exp(coeff(2).*t)+coeff(3).*exp(coeff(4).*t)+coeff(5);
else
    error('Unexpected bleaching coefficient count: %d',numel(coeff));
end
end

function intervals = artifactIntervals(cfg,subject)
intervals=zeros(0,2);
if isfield(cfg,'cohort3_artifact_intervals') && ...
        isfield(cfg.cohort3_artifact_intervals,['x' subject])
    intervals=cfg.cohort3_artifact_intervals.(['x' subject]);
end
end

function value = subjectValue(values,subject)
field = ['x' subject];
assert(isfield(values,field),'Missing setting for subject %s.',subject);
value = values.(field);
end
