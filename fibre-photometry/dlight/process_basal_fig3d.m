function output = process_basal_fig3d(varargin)
% PROCESS_BASAL_FIG3D  Basal-fluorescence analysis for Fig. 3d.
%
%   - use FPX_zdFF / FPX_time from the processed test-day output
%   - 1-minute moving-mean smoothing
%   - section means:
%       baseline = -10 to 0 min
%       T1       = 5 to 14.9 min
%       T2       = 20 to 29.9 min
%   - changes:
%       T1 - baseline
%       T2 - T1
%   - AUC intervals:
%       baseline = -10 to 0 min
%       T1       = 0 to 15 min
%       T2       = 15 to 30 min
%   - total, positive and negative AUC


p = inputParser;
addParameter(p,'input_mat','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'animal','',@(s)ischar(s)&&~isempty(s));
addParameter(p,'day','test',@ischar);
addParameter(p,'treatment','',@ischar);
addParameter(p,'output_root','',@ischar);
addParameter(p,'smooth_min',1,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'save_figures',false,@islogical);
addParameter(p,'save_mat',true,@islogical);
addParameter(p,'logger',[],@(x)isempty(x)||isa(x,'function_handle'));
parse(p,varargin{:});
args = p.Results;

animal = normalize_id(args.animal);
if isempty(args.logger)
    logf = @(s) fprintf('%s\n',s);
else
    logf = args.logger;
end

if isempty(args.output_root)
    args.output_root = fileparts(args.input_mat);
end
if ~isfile(args.input_mat)
    error('Processed dLight file not found: %s',args.input_mat);
end

L = load(args.input_mat);

% ---------- Select canonical processed trace ----------
[tvec,zvec,trace_source] = choose_time_and_z(L);
if isempty(tvec) || isempty(zvec) || numel(tvec) < 5
    error('No usable z(dFF) trace found in %s.',args.input_mat);
end

tvec = tvec(:);
zvec = zvec(:);

% Ensure matching lengths.
N = min(numel(tvec),numel(zvec));
tvec = tvec(1:N);
zvec = zvec(1:N);

% ---------- Historical Fig. 3d smoothing ----------
% IMPORTANT: the original Fig. 3d code used a fixed 3600-sample
% moving mean:
%     FPX_smooth = movmean(FPX_zdFF,3600);
%
% Although the historical comment described this as approximately 1 minute,
% at the Fig. 3d sampling rate (~101.7 Hz) it corresponds to ~35.4 seconds.
% We preserve the implemented historical calculation here so that existing
% Fig. 3d analyses can be reproduced.
winN = 3600;
z_smooth = movmean(zvec,winN);

% ---------- Historical section means ----------
mean_intervals = [-10 0; 5 14.9; 20 29.9];
mean_labels = {'Baseline','T1','T2'};
section_means = NaN(1,3);

for k = 1:3
    idx = tvec >= mean_intervals(k,1) & tvec <= mean_intervals(k,2);
    section_means(k) = mean(z_smooth(idx),'omitnan');
end

change_T1 = section_means(2) - section_means(1);
change_T2 = section_means(3) - section_means(2);

BasalFluorescence = table( ...
    section_means(1), section_means(2), section_means(3), ...
    'VariableNames', {'Baseline','T1','T2'});

BasalFluorescenceChange = table( ...
    change_T1, change_T2, ...
    'VariableNames', {'ChangeT1','ChangeT2'});

% ---------- Historical AUC intervals ----------
auc_intervals = [-10 0; 0 15; 15 30];
auc_labels = {'Baseline','T1','T2'};

AUC = table('Size',[0 11], ...
    'VariableTypes',repmat({'double'},1,11), ...
    'VariableNames',{'IntervalStart','IntervalEnd','DurationMin', ...
                     'N_Samples','N_Missing','Prop_Missing', ...
                     'TotalArea','PositiveArea','NegativeArea', ...
                     'EffectiveDurationMin','TailMean'});

for k = 1:size(auc_intervals,1)
    sI = auc_intervals(k,1);
    eI = auc_intervals(k,2);

    idx = tvec >= sI & tvec <= eI;
    xseg = tvec(idx);
    yseg = z_smooth(idx);

    if numel(xseg) < 2
        AUC(end+1,:) = {sI,eI,eI-sI,numel(yseg),numel(yseg),1, ...
            NaN,NaN,NaN,0,NaN};
        continue;
    end

    N_Samples = numel(yseg);
    N_Missing = sum(~isfinite(yseg));
    PropMissing = N_Missing / max(1,N_Samples);

    % Match the historical Fig. 3d calculation for valid data.
    yseg_f = fillmissing(yseg,'linear','EndValues','nearest');

    totalArea = trapz(xseg,yseg_f);
    positiveArea = trapz(xseg,max(yseg_f,0));
    negativeArea = trapz(xseg,min(yseg_f,0));

    effectiveDuration = (1-PropMissing)*(eI-sI);

    tailStart = max(sI,eI-10);
    tailIdx = tvec >= tailStart & tvec <= eI;
    tailMean = mean(z_smooth(tailIdx),'omitnan');

    AUC(end+1,:) = {sI,eI,eI-sI,N_Samples,N_Missing,PropMissing, ...
        totalArea,positiveArea,negativeArea,effectiveDuration,tailMean};
end

% ---------- Coverage ----------
Coverage = table( ...
    AUC.IntervalStart, AUC.IntervalEnd, ...
    AUC.DurationMin, AUC.EffectiveDurationMin, ...
    AUC.DurationMin-AUC.EffectiveDurationMin, ...
    100*AUC.EffectiveDurationMin./max(AUC.DurationMin,eps), ...
    'VariableNames',{'IntervalStart','IntervalEnd','DurationMin', ...
                     'CoveredMin','MissingMin','CoveragePct'});

% ---------- Metadata ----------
meta = struct();
meta.figure = 'fig3d';
meta.animal = animal;
meta.day = args.day;
meta.treatment = args.treatment;
meta.trace_source = trace_source;
meta.smooth_samples = winN;
meta.smooth_method = 'movmean';
meta.smooth_note = 'Historical Fig. 3d fixed 3600-sample window';
meta.mean_intervals = mean_intervals;
meta.auc_intervals = auc_intervals;
meta.input_mat = args.input_mat;

% ---------- Save ----------
save_dir = fullfile(args.output_root,args.day,animal);
if ~isfolder(save_dir), mkdir(save_dir); end

% Save aliases explicitly from the local vectors. These aliases are used
% by downstream summary code and prevent MATLAB from expecting
% workspace variables that were not otherwise created.
fpx_time   = tvec; %#ok<NASGU>
fpx_zdFF   = zvec; %#ok<NASGU>
fpx_smooth = z_smooth; %#ok<NASGU>

if args.save_mat
    save(fullfile(save_dir,[args.day,'_',animal,'_basal-fluorescence.mat']), ...
        'fpx_time','fpx_zdFF','fpx_smooth','BasalFluorescence', ...
        'BasalFluorescenceChange','AUC','Coverage','meta','-v7.3');
end

% ---------- Optional figure ----------
if args.save_figures
    f = figure('Visible','off','Units','pixels','Position',[50 50 700 260]);
    plot(tvec,zvec,'Color',[0.65 0.65 0.65]); hold on;
    plot(tvec,z_smooth,'k','LineWidth',1.5);
    xlim([-30 60]); box on;
    xlabel('Time (min)');
    ylabel('z(dFF)');
    title(sprintf('%s | %s | Basal Fluorescence',animal,args.day), ...
        'Interpreter','none','FontWeight','normal');
    legend({'Original','1-min smooth'},'Location','best');
    exportgraphics(f,fullfile(save_dir,'basal-fluorescence.png'),'Resolution',200);
    close(f);
end

output = struct( ...
    'animal',animal, ...
    'day',args.day, ...
    'treatment',args.treatment, ...
    'time',tvec, ...
    'z',zvec, ...
    'z_smooth',z_smooth, ...
    'BasalFluorescence',BasalFluorescence, ...
    'BasalFluorescenceChange',BasalFluorescenceChange, ...
    'AUC',AUC, ...
    'Coverage',Coverage, ...
    'meta',meta);

% Save aliases matching the later figure-analysis convention.
fpx_time = tvec; %#ok<NASGU>
fpx_zdFF = zvec; %#ok<NASGU>
fpx_smooth = z_smooth; %#ok<NASGU>

logf(sprintf('[OK] basal analysis complete: %s | %s',animal,args.day));
end

function [tvec,zvec,source] = choose_time_and_z(L)
tvec = [];
zvec = [];
source = '';

% Preferred new pipeline output.
if isfield(L,'FPX_time') && isfield(L,'FPX_zdFF')
    tvec = L.FPX_time;
    zvec = L.FPX_zdFF;
    source = 'FPX_time / FPX_zdFF';
    return;
end

% Canonical later-pipeline output.
if isfield(L,'fpx_time') && isfield(L,'fpx_primary_z')
    tvec = L.fpx_time;
    zvec = L.fpx_primary_z;
    source = 'fpx_time / fpx_primary_z';
    return;
end

% Common fallback.
if isfield(L,'fpx_time') && isfield(L,'FPX_zdFF')
    tvec = L.fpx_time;
    zvec = L.FPX_zdFF;
    source = 'fpx_time / FPX_zdFF';
    return;
end

if isfield(L,'time_min') && isfield(L,'z')
    tvec = L.time_min;
    zvec = L.z;
    source = 'time_min / z';
end
end

function id = normalize_id(x)
s = regexprep(char(string(x)),'[^0-9]','');
if numel(s) < 6
    s = sprintf('%06s',s);
end
id = s;
end
