function results = process_suppfig6gj_caddis(paths,cfg)
% PROCESS_SUPPFIG6GJ_CADDIS Derive Supplemental Fig. 6g-j from raw streams.
%
% Independent bleach fits use the reviewed coefficients in config by
% default. The simultaneous cADDis/mCherry fits use the reviewed Behapy
% coefficients supplied with the Fig. 3 cADDis workflows.

if nargin < 2 || isempty(cfg), cfg = suppfig6gj_config(); end
requiredRoots = {'project_root','fig3eh_root','fig3k_root','processing_root'};
for i = 1:numel(requiredRoots)
    assert(isfield(paths,requiredRoots{i}) && ~isempty(paths.(requiredRoots{i})), ...
        'Required path is not set: paths.%s',requiredRoots{i});
end

generatedRoot = fullfile(paths.processing_root,'generated-source-data');
if ~isfolder(generatedRoot), mkdir(generatedRoot); end

habFits = readtable(cfg.hab3_fit_parameters_file,'TextType','string');
habArtifacts = readtable(cfg.hab3_artifact_intervals_file,'TextType','string');
seqFits = readtable(cfg.sequential_fit_parameters_file,'TextType','string');
seqArtifacts = readtable(cfg.sequential_artifact_intervals_file,'TextType','string');
fitExclusions = readtable(cfg.independent_fit_exclusions_file,'TextType','string');
habFits.Subject = padSubjects(habFits.Subject);
habArtifacts.Subject = padSubjects(habArtifacts.Subject);
seqFits.Subject = padSubjects(seqFits.Subject);
seqArtifacts.Subject = padSubjects(seqArtifacts.Subject);
fitExclusions.Subject = padSubjects(fitExclusions.Subject);

fprintf('\n1/3 Processing habituation recordings for panels g-h...\n');
[panelGRaw,panelGCorrected,panelH,hab3] = processHabituation( ...
    paths.project_root,habFits,habArtifacts,fitExclusions,cfg);
writetable(panelGRaw,fullfile(generatedRoot, ...
    'suppfig6g_caddis_example_raw_038537.csv'));
writetable(panelGCorrected,fullfile(generatedRoot, ...
    'suppfig6g_caddis_example_corrected_038537.csv'));
writetable(panelH,fullfile(generatedRoot, ...
    'suppfig6h_caddis_465_560_correlations.csv'));

fprintf('\n2/3 Reconstructing the Behapy simultaneous fits...\n');
[simTraces,simImport] = processSimultaneous(paths,seqFits,cfg);

fprintf('\n3/3 Processing the historical sequential fits...\n');
sequentialTraces = processSequential(paths,seqFits,seqArtifacts, ...
    fitExclusions,cfg);
[panelI,panelJ] = makeComparisonTables( ...
    sequentialTraces,simTraces,seqFits,cfg);
writetable(panelI,fullfile(generatedRoot, ...
    'suppfig6i_caddis_sequential_simultaneous.csv'));
writetable(panelJ,fullfile(generatedRoot, ...
    'suppfig6j_caddis_between_animal_variability.csv'));

save(fullfile(paths.processing_root,'suppfig6gj_processed.mat'), ...
    'hab3','sequentialTraces','simTraces','simImport','panelH','panelJ','-v7.3');
results = struct('generated_source_root',generatedRoot,'panel_g_raw',panelGRaw, ...
    'panel_g_corrected',panelGCorrected,'panel_h',panelH, ...
    'panel_i',panelI,'panel_j',panelJ);
fprintf('\nGenerated panel tables written to:\n%s\n',generatedRoot);
end

function [rawTable,correctedTable,summaryTable,outputs] = processHabituation( ...
        sourceRoot,fitTable,artifactTable,exclusionTable,cfg)
outputs = struct();
summaryRows = cell(height(fitTable),10);
rawTable = table(); correctedTable = table();
for i = 1:height(fitTable)
    row = fitTable(i,:); subject = row.Subject;
    fprintf('  Hab3 %s (%d/%d)\n',subject,i,height(fitTable));
    file = subjectParquet(fullfile(sourceRoot,'hab3'),subject);
    [time,signal,reference,fs] = prepareHistoricalRaw(file,cfg);
    regions = subjectIntervals(artifactTable,subject,'hab3');
    [signal,reference,artifactMask] = maskArtifacts( ...
        time,signal,reference,regions);
    exclusion = subjectIntervals(exclusionTable,subject,'hab3');
    [signalFit,referenceFit,fitInfo] = independentFits( ...
        time,signal,reference,row,exclusion,cfg);
    correctedSignal = signal-signalFit+fitInfo.signal_offset;
    correctedReference = reference-referenceFit+fitInfo.reference_offset;
    stamp = cfg.hab3_timestamps(cfg.hab3_timestamps.Subject==subject,:);
    [canonical,signalCrop,referenceCrop,artifactCrop] = cropHab3( ...
        time,correctedSignal,correctedReference,artifactMask,stamp,fs);
    normalise = canonical>=cfg.normalisation_window_min(1) & ...
        canonical<=cfg.normalisation_window_min(2) & ~artifactCrop & ...
        isfinite(signalCrop) & isfinite(referenceCrop);
    signalPct = 100.*signalCrop./mean(signalCrop(normalise),'omitnan');
    referencePct = 100.*referenceCrop./mean(referenceCrop(normalise),'omitnan');
    slowN = max(1,round(cfg.hab3_slow_window_sec*fs));
    slowSignal = movmean(signalPct,[slowN-1 0],'omitnan');
    slowReference = movmean(referencePct,[slowN-1 0],'omitnan');
    analyse = canonical>=cfg.correlation_window_min(1) & ...
        canonical<=cfg.correlation_window_min(2) & ~artifactCrop & ...
        isfinite(slowSignal) & isfinite(slowReference);
    correlation = corrcoef(slowReference(analyse),slowSignal(analyse));
    direct = polyfit(slowReference(analyse),slowSignal(analyse),1);
    r = correlation(1,2);
    summaryRows(i,:) = {string(row.Cohort),subject,string(row.SignalModel), ...
        string(row.ReferenceModel),row.SignalFitR2,row.ReferenceFitR2, ...
        r,r.^2,direct(1),direct(2)};
    field = matlab.lang.makeValidName('s'+subject);
    outputs.(field) = struct('time_min',canonical,'signal_pct',signalPct, ...
        'reference_pct',referencePct,'slow_signal',slowSignal, ...
        'slow_reference',slowReference,'artifact_mask',artifactCrop);

    if subject == string(cfg.example_subject)
        displayTime = time-cfg.example_raw_time_offset_min;
        displayed = displayTime>=cfg.example_window_min(1) & ...
            displayTime<=cfg.example_window_min(2);
        rawTable = table(displayTime,displayed,signal,reference, ...
            signalFit,referenceFit,'VariableNames',{'Time_min', ...
            'DisplayedWindow','Downsampled465','Downsampled560', ...
            'BleachFit465','BleachFit560'});
        [exampleTime,exampleSignalCrop,exampleReferenceCrop] = ...
            cropExample(time,correctedSignal,correctedReference,stamp);
        exampleBase = exampleTime>=cfg.normalisation_window_min(1) & ...
            exampleTime<=cfg.normalisation_window_min(2);
        exampleSignalPct = 100.*exampleSignalCrop./ ...
            mean(exampleSignalCrop(exampleBase),'omitnan');
        exampleReferencePct = 100.*exampleReferenceCrop./ ...
            mean(exampleReferenceCrop(exampleBase),'omitnan');
        exampleN = max(1,round(cfg.example_slow_window_sec*fs));
        exampleSignal = movmean(exampleSignalPct,[exampleN-1 0],'omitnan');
        exampleReference = movmean(exampleReferencePct,[exampleN-1 0],'omitnan');
        correctedTable = table(exampleTime,exampleSignalCrop,exampleReferenceCrop, ...
            exampleSignalPct,exampleReferencePct,exampleSignal,exampleReference, ...
            'VariableNames',{'Time_min','BleachCorrected465', ...
            'BleachCorrected560','Normalised465_pctBaseline', ...
            'Normalised560_pctBaseline','Slow465_60s_pctBaseline', ...
            'Slow560_60s_pctBaseline'});
    end
end
summaryTable = cell2table(summaryRows,'VariableNames',{'Cohort','Animal', ...
    'SignalBleachModel','ReferenceBleachModel','BleachR2_465', ...
    'BleachR2_560','SlowCorrelationR','SlowCorrelationR2', ...
    'DirectFitSlope','DirectFitIntercept'});
end

function [traces,details] = processSimultaneous(paths,comparisonFits,cfg)
configs = {fig3eh_config(),fig3k_config()};
roots = {paths.fig3eh_root,paths.fig3k_root};
traces = struct(); details = struct();
for i = 1:2
    thisCfg = configs{i};
    % Use the output rate measured from the archived Behapy tables.
    thisCfg.behapy_downsample_factor = cfg.behapy_downsample_factor;
    workRoot = fullfile(paths.processing_root,'behapy-sim',thisCfg.figure);
    [clean,importSummary] = import_caddis_raw(roots{i},workRoot,thisCfg);
    fields = fieldnames(clean);
    cropRows = cell(0,5);
    for k = 1:numel(fields)
        subject = string(regexprep(fields{k},'^s',''));
        comparisonRow = comparisonFits(comparisonFits.Subject==subject,:);
        assert(height(comparisonRow)==1, ...
            'No unique comparison timing row found for subject %s.',subject);
        [cropped,counts] = cropComparisonRecording(clean.(fields{k}),comparisonRow);
        traces.(fields{k}) = makeSimTrace(cropped,comparisonRow,counts,cfg);
        traces.(fields{k}).subject = subject;
        cropRows(end+1,:) = {subject,counts(1),counts(2),counts(3),sum(counts)}; %#ok<AGROW>
    end
    cropSummary = cell2table(cropRows,'VariableNames',{'Subject', ...
        'BaselineRows','T1Rows','T2Rows','RowsAfterCrop'});
    details.(thisCfg.figure) = struct('import',importSummary,'crop',cropSummary);
end

function [cropped,counts] = cropComparisonRecording(T,row)
timeMin = double(T.Time(:))./60;
masks = {timeMin>=row.BaseStartMin & timeMin<=row.BaseEndMin, ...
    timeMin>=row.T1StartMin & timeMin<=row.T1EndMin, ...
    timeMin>=row.T2StartMin & timeMin<=row.T2EndMin};
counts = cellfun(@nnz,masks);
assert(all(counts>0),'One or more simultaneous-fit epochs are empty.');
cropped = [T(masks{1},:);T(masks{2},:);T(masks{3},:)];
end
end

function traces = processSequential(paths,fitTable,artifactTable,exclusionTable,cfg)
traces = struct();
for i = 1:height(fitTable)
    row = fitTable(i,:); subject = row.Subject;
    fprintf('  Sequential %s (%d/%d)\n',subject,i,height(fitTable));
    if string(row.Treatment)=="GR"
        sourceRoot = fullfile(paths.fig3k_root,'GR');
    else
        sourceRoot = fullfile(paths.fig3eh_root,char(row.Treatment));
    end
    file = subjectParquet(sourceRoot,subject);
    [time,signal,reference,fs] = prepareHistoricalRaw(file,cfg);
    regions = subjectIntervals(artifactTable,subject,'test');
    [signal,reference] = maskArtifacts(time,signal,reference,regions);
    exclusion = subjectIntervals(exclusionTable,subject,'test');
    [signalFit,referenceFit,fitInfo] = independentFits( ...
        time,signal,reference,row,exclusion,cfg);
    signalResidual = signal-signalFit+fitInfo.signal_offset;
    referenceResidual = reference-referenceFit+fitInfo.reference_offset;
    linearSlope = row.LinearSlope; linearIntercept = row.LinearIntercept;
    if strcmpi(cfg.independent_fit_mode,'refit')
        use = isfinite(signalResidual)&isfinite(referenceResidual);
        % The saved CSG018 RG workflow applied its bleach-fit exclusion to
        % the subsequent linear fit; the VG workflow used all valid points.
        if string(row.Treatment)=="RG"
            for regionIndex=1:size(exclusion,1)
                use=use&~(time>=exclusion(regionIndex,1)& ...
                    time<=exclusion(regionIndex,2));
            end
        end
        linear = polyfit(referenceResidual(use),signalResidual(use),1);
        linearSlope=linear(1); linearIntercept=linear(2);
    end
    fittedReference = linearSlope.*referenceResidual+linearIntercept;
    dff = (signalResidual-fittedReference)./fittedReference;
    baseMid = (row.BaseStartMin+row.BaseEndMin)/2;
    base = time>=baseMid & time<=row.BaseEndMin & isfinite(dff);
    z = (dff-mean(dff(base),'omitnan'))./std(dff(base),0,'omitnan');
    [canonical,zCrop] = cropSequential(time,z,row,fs);
    smoothN = max(1,round(cfg.comparison_smooth_window_sec*fs));
    zSmooth = movmean(zCrop,smoothN,'omitnan','Endpoints','shrink');
    good = isfinite(canonical)&isfinite(zSmooth);
    aligned = interp1(canonical(good),zSmooth(good),cfg.trace_grid_min, ...
        'linear',NaN);
    field = matlab.lang.makeValidName('s'+subject);
    traces.(field) = struct('subject',subject,'treatment',string(row.Treatment), ...
        'time_min',cfg.trace_grid_min,'z_smooth',aligned, ...
        'native_time_min',canonical,'native_z_smooth',zSmooth);
end
end

function [panelI,panelJ] = makeComparisonTables(seq,sim,fitTable,cfg)
t = cfg.trace_grid_min;
panelI = table(t,'VariableNames',{'Time_min'});
panelSubjects = fitTable.Subject(string(fitTable.Treatment)==string(cfg.panel_i_treatment));
for method = ["Sequential","Simultaneous"]
    values = nan(numel(t),numel(panelSubjects));
    for i = 1:numel(panelSubjects)
        field = matlab.lang.makeValidName('s'+panelSubjects(i));
        source = seq;
        if method=="Simultaneous", source=sim; end
        values(:,i) = source.(field).z_smooth;
        panelI.(char(method+'_'+panelSubjects(i))) = values(:,i);
    end
    panelI.(char(method+'_Mean')) = mean(values,2,'omitnan');
end

rows = cell(numel(cfg.treatment_order),5);
for groupIndex = 1:numel(cfg.treatment_order)
    treatment = string(cfg.treatment_order{groupIndex});
    subjects = fitTable.Subject(string(fitTable.Treatment)==treatment);
    variabilityGrid = t;
    if treatment=="GR", variabilityGrid=cfg.gr_trace_grid_min; end
    seqMatrix = nan(numel(subjects),numel(variabilityGrid));
    simMatrix = nan(numel(subjects),numel(variabilityGrid));
    for i = 1:numel(subjects)
        field = matlab.lang.makeValidName('s'+subjects(i));
        seqMatrix(i,:) = interp1(seq.(field).native_time_min, ...
            seq.(field).native_z_smooth,variabilityGrid,'linear',NaN);
        simMatrix(i,:) = interp1(sim.(field).native_time_min, ...
            sim.(field).native_z_smooth,variabilityGrid,'linear',NaN);
    end
    variabilityLate = variabilityGrid>=cfg.variability_window_min(1) & ...
        variabilityGrid<=cfg.variability_window_min(2);
    seqValue = mean(std(seqMatrix(:,variabilityLate),0,1,'omitnan'),'omitnan');
    simValue = mean(std(simMatrix(:,variabilityLate),0,1,'omitnan'),'omitnan');
    cohort = string(fitTable.Cohort(find(string(fitTable.Treatment)==treatment,1)));
    rows(groupIndex,:) = {string(cfg.treatment_labels{groupIndex}),cohort, ...
        treatment,seqValue,simValue};
end
panelJ = cell2table(rows,'VariableNames', ...
    {'Condition','Cohort','Group','Sequential','Simultaneous'});
end

function trace = makeSimTrace(T,row,counts,cfg)
time = double(T.Time(:)); signal = double(T.cADDisRaw(:));
reference = double(T.mCherrySimultaneous(:));
floorValue = max(eps,1e-6*median(abs(reference(isfinite(reference))),'omitnan'));
reference(abs(reference)<floorValue)=NaN;
dff = (signal-reference)./reference;
steps = diff(time); steps = steps(isfinite(steps)&steps>0);
stepSec = median(steps,'omitnan');
if string(row.Cohort)=="CSG022"
    canonical = [linspace(-30,0,counts(1))'; ...
        linspace(15/counts(2),15,counts(2))'; ...
        linspace(15+30/counts(3),45,counts(3))'];
else
    canonical = -30+(0:numel(dff)-1)'.*(stepSec/60);
end
base = canonical>=cfg.normalisation_window_min(1) & ...
    canonical<=cfg.normalisation_window_min(2) & isfinite(dff);
z = (dff-mean(dff(base),'omitnan'))./std(dff(base),0,'omitnan');
smoothN = max(1,round(cfg.comparison_smooth_window_sec/stepSec));
zSmooth = movmean(z,smoothN,'omitnan','Endpoints','shrink');
good = isfinite(canonical)&isfinite(zSmooth);
trace = struct('time_min',cfg.trace_grid_min,'z_smooth', ...
    interp1(canonical(good),zSmooth(good),cfg.trace_grid_min,'linear',NaN), ...
    'native_time_min',canonical,'native_z_smooth',zSmooth);
end

function [canonical,signalCrop,referenceCrop] = cropExample( ...
        time,signal,reference,stamp)
ranges = [stamp.BaseStartMin stamp.BaseEndMin;stamp.T1StartMin stamp.T1EndMin; ...
    stamp.T2StartMin stamp.T2EndMin];
signalParts=cell(3,1); referenceParts=cell(3,1);
for i=1:3
    first=find(time>ranges(i,1),1); last=find(time>ranges(i,2),1);
    signalParts{i}=signal(first:last); referenceParts{i}=reference(first:last);
end
signalCrop=vertcat(signalParts{:}); referenceCrop=vertcat(referenceParts{:});
n=min(numel(signalCrop),numel(referenceCrop));
signalCrop=signalCrop(1:n); referenceCrop=referenceCrop(1:n);
canonical=linspace(-30,45,n)';
end

function [time,signal,reference,fs] = prepareHistoricalRaw(file,cfg)
T = parquetread(file); names = string(T.Properties.VariableNames);
timeName = findName(names,'time_s'); signalName = findSuffix(names,'_465nm');
referenceName = findSuffix(names,'_560nm');
rawTime = double(T.(timeName)(:)); signal = double(T.(signalName)(:));
reference = double(T.(referenceName)(:));
originalFs = 1/median(diff(rawTime(1:min(end,100000))));
historicalTime = (1:numel(rawTime))'./originalFs;
first = find(historicalTime>cfg.raw_start_sec,1);
historicalTime = historicalTime(first:end)./60;
signal = lowpass(signal(first:end),cfg.lowpass_hz,originalFs);
reference = lowpass(reference(first:end),cfg.lowpass_hz,originalFs);
factor = round(originalFs/cfg.target_sample_rate_hz);
fs = originalFs/factor; count = ceil(numel(signal)/factor);
downSignal = nan(count,1); downReference = nan(count,1);
for i = 1:count
    firstIndex=(i-1)*factor+1; lastIndex=min(firstIndex+factor-1,numel(signal));
    downSignal(i)=median(signal(firstIndex:lastIndex));
    downReference(i)=median(reference(firstIndex:lastIndex));
end
sampledTime = historicalTime(1:factor:end);
step = median(diff(sampledTime));
time = (0:count-1)'.*step+historicalTime(1);
signal=downSignal; reference=downReference;
end

function [signalFit,referenceFit,info] = independentFits( ...
        time,signal,reference,row,exclusion,cfg)
if strcmpi(cfg.independent_fit_mode,'locked')
    signalFit = evaluateExponential(time,row.SignalModel,row.SignalA, ...
        row.SignalB,row.SignalC,row.SignalD);
    referenceFit = evaluateExponential(time,row.ReferenceModel,row.ReferenceA, ...
        row.ReferenceB,row.ReferenceC,row.ReferenceD);
    info.signal_offset=row.SignalOffset; info.reference_offset=row.ReferenceOffset;
elseif strcmpi(cfg.independent_fit_mode,'refit')
    fitEnd = row.T2EndMin;
    if ismember('FitEndMin',row.Properties.VariableNames)
        fitEnd = row.FitEndMin;
    end
    [signalFit,info.signal_offset] = refitBleach(time,signal,row.SignalModel, ...
        fitEnd,row.BaseStartMin,exclusion,cfg);
    [referenceFit,info.reference_offset] = refitBleach(time,reference, ...
        row.ReferenceModel,fitEnd,row.BaseStartMin,exclusion,cfg);
else
    error('Unknown independent_fit_mode: %s',cfg.independent_fit_mode);
end
end

function [evaluated,offset] = refitBleach(time,data,model,fitEnd,baseStart,exclusion,cfg)
smoothed=movmax(data,cfg.bleach_smooth_samples,'omitnan');
use=time<=fitEnd & isfinite(time)&isfinite(smoothed);
for i=1:size(exclusion,1), use=use&~(time>=exclusion(i,1)&time<=exclusion(i,2)); end
[x,y]=prepareCurveData(time(use),smoothed(use));
options=fitoptions('Method','NonlinearLeastSquares'); options.Display='Off';
fitted=fit(x,y,fittype(char(model)),options); evaluated=fitted(time);
first=find(time>baseStart & isfinite(smoothed),1); offset=smoothed(first);
end

function values = evaluateExponential(time,model,a,b,c,d)
values=a.*exp(b.*time);
if strcmpi(model,'exp2'), values=values+c.*exp(d.*time); end
end

function [canonical,signalCrop,referenceCrop,artifactCrop] = cropHab3( ...
        time,signal,reference,artifact,stamp,fs)
nBase=round(30*60*fs); nT1=round(15*60*fs); nT2=round(30*60*fs);
[s0,r0,a0]=fixedEpoch(time,signal,reference,artifact,stamp.BaseStartMin, ...
    stamp.BaseEndMin,nBase,false);
[s1,r1,a1]=fixedEpoch(time,signal,reference,artifact,stamp.T1StartMin, ...
    stamp.T1EndMin,nT1,false);
[s2,r2,a2]=fixedEpoch(time,signal,reference,artifact,stamp.T2StartMin, ...
    stamp.T2EndMin,nT2,stamp.PadShortT2);
signalCrop=[s0;s1;s2]; referenceCrop=[r0;r1;r2]; artifactCrop=[a0;a1;a2];
step=1/(fs*60); canonical=(-30+step:step:45)';
n=min([numel(canonical),numel(signalCrop),numel(referenceCrop)]);
canonical=canonical(1:n); signalCrop=signalCrop(1:n);
referenceCrop=referenceCrop(1:n); artifactCrop=artifactCrop(1:n);
end

function [s,r,a] = fixedEpoch(time,signal,reference,artifact,startMin,endMin,n,padAtEnd)
first=find(time>startMin,1); last=find(time>endMin,1);
if isempty(last), last=numel(time); end
if padAtEnd, indices=first:last; else, indices=first:min(first+n-1,numel(time)); end
s=signal(indices); r=reference(indices); a=artifact(indices);
if numel(s)>n, s=s(1:n); r=r(1:n); a=a(1:n); end
if numel(s)<n
    missing=n-numel(s); s=[s;nan(missing,1)]; r=[r;nan(missing,1)];
    a=[a;true(missing,1)];
end
end

function [canonical,zCrop] = cropSequential(time,z,row,fs)
if string(row.Cohort)=="CSG018"
    nBase=round(30*60*fs); nT1=round(15*60*fs); nT2=round(30*60*fs);
    dummy=zeros(size(z));
    [z0,~,~]=fixedEpoch(time,z,z,dummy,row.BaseStartMin,row.BaseEndMin,nBase,false);
    [z1,~,~]=fixedEpoch(time,z,z,dummy,row.T1StartMin,row.T1EndMin,nT1,false);
    [z2,~,~]=fixedEpoch(time,z,z,dummy,row.T2StartMin,row.T2EndMin,nT2,false);
    zCrop=[z0;z1;z2]; step=1/(fs*60);
    canonical=(-30+step:step:45)';
    n=min(numel(canonical),numel(zCrop)); canonical=canonical(1:n); zCrop=zCrop(1:n);
else
    masks={time>=row.BaseStartMin&time<=row.BaseEndMin, ...
        time>=row.T1StartMin&time<=row.T1EndMin, ...
        time>=row.T2StartMin&time<=row.T2EndMin};
    parts=cellfun(@(m)z(m),masks,'UniformOutput',false); zCrop=vertcat(parts{:});
    n=cellfun(@nnz,masks);
    canonical=[linspace(-30,0,n(1))';linspace(15/n(2),15,n(2))'; ...
        linspace(15+30/n(3),45,n(3))'];
end
end

function [signal,reference,mask] = maskArtifacts(time,signal,reference,regions)
mask=false(size(time));
for i=1:size(regions,1), mask=mask|(time>=regions(i,1)&time<=regions(i,2)); end
signal(mask)=NaN; reference(mask)=NaN;
end

function regions = subjectIntervals(T,subject,session)
rows=T.Subject==subject & strcmpi(string(T.Session),session);
regions=[double(T.StartMin(rows)) double(T.EndMin(rows))];
end

function file = subjectParquet(root,subject)
file=fullfile(root,subject,'sub-'+subject+'_photometry.parquet');
assert(isfile(file),'Photometry file not found: %s',file);
end

function subjects = padSubjects(values)
values=string(values); subjects=strings(size(values));
for i=1:numel(values)
    number=str2double(values(i));
    if isfinite(number), subjects(i)=compose('%06d',number); else, subjects(i)=values(i); end
end
end

function name = findName(names,requested)
index=find(strcmpi(names,requested),1); assert(~isempty(index),'Missing column %s.',requested);
name=char(names(index));
end

function name = findSuffix(names,suffix)
index=find(endsWith(lower(names),lower(suffix)),1);
assert(~isempty(index),'Missing channel ending in %s.',suffix); name=char(names(index));
end
