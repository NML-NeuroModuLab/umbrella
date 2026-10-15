function [SIM_clean, import_summary] = import_caddis_raw( ...
    source_root, processing_root, cfg)
% IMPORT_CADDIS_RAW Recreate Behapy inputs from shared raw 465/560 streams.
%
% The figure configuration identifies fixed historical fit coefficients and
% manually reviewed rejection intervals. Keeping those values with the code
% makes the public analysis independent of the private Behapy package and
% nonlinear-optimizer version.

    requiredFields = {'joint_fit_parameters_file', ...
        'rejected_intervals_file', 'behapy_downsample_factor'};
    for index = 1:numel(requiredFields)
        assert(isfield(cfg,requiredFields{index}), ...
            'Configuration is missing cfg.%s.', requiredFields{index});
    end

    parameterTable = readtable(cfg.joint_fit_parameters_file, ...
        'TextType', 'string');
    rejectionTable = readtable(cfg.rejected_intervals_file, ...
        'TextType', 'string');
    parameterTable.Subject = padSubject(parameterTable.Subject);
    rejectionTable.Subject = padSubject(rejectionTable.Subject);

    if ~isfolder(source_root)
        error('cADDis source folder not found: %s',source_root);
    end
    if ~isfolder(processing_root), mkdir(processing_root); end

    SIM_clean = struct();
    rows = cell(0,5);
    for index = 1:height(cfg.summary_mapping)
        subject = string(cfg.summary_mapping.Subject(index));
        treatment = string(cfg.summary_mapping.Treatment(index));
        treatmentFolder = resolveTreatmentFolder(source_root,treatment);
        subjectFolder = fullfile(treatmentFolder,subject);
        inputFile = fullfile(subjectFolder, ...
            'sub-' + subject + '_photometry.parquet');
        if ~isfile(inputFile)
            rows(end+1,:) = {subject,treatment,0,NaN, ...
                "missing subject photometry Parquet"}; %#ok<AGROW>
            continue
        end

        raw = parquetread(inputFile);
        names = string(raw.Properties.VariableNames);
        timeName = findName(names,"time_s");
        signalName = findSuffix(names,"_465nm");
        controlName = findSuffix(names,"_560nm");
        time = double(raw.(timeName));
        channels = double(raw{:, {signalName,controlName}});
        [downTime,downChannels] = behapyDecimate( ...
            time,channels,cfg.behapy_downsample_factor);

        subjectRejections = rejectionTable( ...
            rejectionTable.Subject == subject,:);
        for rowIndex = 1:height(subjectRejections)
            if ismember('EndInclusive', ...
                    subjectRejections.Properties.VariableNames) && ...
                    ~toLogicalScalar(subjectRejections.EndInclusive(rowIndex))
                rejected = downTime >= subjectRejections.StartTimeSec(rowIndex) & ...
                    downTime < subjectRejections.EndTimeSec(rowIndex);
            else
                rejected = downTime >= subjectRejections.StartTimeSec(rowIndex) & ...
                    downTime <= subjectRejections.EndTimeSec(rowIndex);
            end
            downChannels(rejected,:) = NaN;
        end

        parameterRow = find(parameterTable.Subject == subject,1);
        if isempty(parameterRow)
            error('No joint-fit parameters found for subject %s.',subject);
        end
        p = parameterTable(parameterRow,:);
        signalFit = doubleExp(downTime,p.SignalA1,p.SignalA2, ...
            p.SignalB1,p.SignalB2,p.SignalC);
        controlFit = doubleExp(downTime,p.ControlA1,p.ControlA2, ...
            p.ControlB1,p.ControlB2,p.ControlC);
        signalDelta = downChannels(:,1) - signalFit;
        controlDelta = downChannels(:,2) - controlFit;
        signalDFF = signalDelta ./ signalFit;
        controlDFF = controlDelta ./ controlFit;
        controlDFFFit = controlDFF .* p.Beta + p.FitC;
        simultaneous = signalFit .* (1 + controlDFFFit);
        difference = downChannels(:,1) - simultaneous;
        differenceZ = (difference - mean(difference,'omitnan')) ./ ...
            std(difference,'omitnan');

        clean = table(downTime,downChannels(:,1),downChannels(:,2), ...
            signalFit,controlFit,signalDelta,controlDelta,signalDFF, ...
            controlDFF,controlDFFFit,simultaneous,difference,differenceZ, ...
            'VariableNames',cfg.clean_column_names);
        field = matlab.lang.makeValidName('s' + subject);
        SIM_clean.(field) = clean;
        stepSec = median(diff(downTime));
        rows(end+1,:) = {subject,treatment,height(clean),stepSec,"imported"}; %#ok<AGROW>
    end

    import_summary = cell2table(rows,'VariableNames', ...
        {'Subject','Treatment','RowsImported','StepSec','Status'});
    save(fullfile(processing_root,'clean_SIM_data.mat'), ...
        'SIM_clean','import_summary','-v7.3');
end

function [timeOut,dataOut] = behapyDecimate(timeIn,dataIn,factor)
    filterOrder = 20 * factor;
    coefficients = fir1(filterOrder,1/factor,hamming(filterOrder+1));
    filtered = upfirdn(dataIn,coefficients,1,factor);
    outputCount = ceil(size(dataIn,1)/factor);
    delayRows = filterOrder/(2*factor);
    firstRow = delayRows + 1;
    dataOut = filtered(firstRow:firstRow+outputCount-1,:);
    timeOut = timeIn(1:factor:end);
    timeOut = timeOut(1:outputCount);
end

function values = doubleExp(time,a1,a2,b1,b2,c)
    values = a1.*exp(-b1.*time) + a2.*exp(-b2.*time) + c;
end

function name = findName(names,requested)
    index = find(strcmpi(names,requested),1);
    if isempty(index), error('Column %s was not found.',requested); end
    name = char(names(index));
end

function name = findSuffix(names,suffix)
    index = find(endsWith(lower(names),lower(suffix)),1);
    if isempty(index), error('No column ending in %s was found.',suffix); end
    name = char(names(index));
end

function subjects = padSubject(subjects)
    subjects = string(subjects);
    for index = 1:numel(subjects)
        subjects(index) = pad(subjects(index),6,'left','0');
    end
end

function value = toLogicalScalar(value)
    if islogical(value)
        return
    elseif isnumeric(value)
        value = value ~= 0;
    else
        value = any(strcmpi(strtrim(string(value)),["true","1","yes"]));
    end
end

function folder = resolveTreatmentFolder(root,treatment)
% Resolve treatment directories without relying on case-insensitive disks.
entries = dir(root);
matches = entries([entries.isdir] & strcmpi({entries.name},char(treatment)));
if isempty(matches)
    folder = fullfile(root,char(treatment));
else
    folder = fullfile(root,matches(1).name);
end
end
