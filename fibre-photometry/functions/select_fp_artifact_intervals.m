function intervals = select_fp_artifact_intervals(time,signals,varargin)
% SELECT_FP_ARTIFACT_INTERVALS Interactively review artifact intervals.
%
% intervals = select_fp_artifact_intervals(time,signals)
% intervals = select_fp_artifact_intervals(..., ...
%     'ExistingIntervals',intervals,'SignalLabels',labels, ...
%     'Title','subject 055619','TimeUnit','min')
%
% Click the start and end of each artifact interval, then press Return.
% Existing intervals are shown with dashed boundary lines and are retained.
% An unmatched final click is ignored. The returned K-by-2 matrix can be
% copied into a figure configuration file and applied with
% apply_fp_artifact_intervals.

p = inputParser;
addParameter(p,'ExistingIntervals',zeros(0,2), ...
    @(x)isnumeric(x)&&size(x,2)==2);
addParameter(p,'SignalLabels',{},@(x)iscell(x)||isstring(x));
addParameter(p,'Title','Artifact interval review', ...
    @(x)ischar(x)||isstring(x));
addParameter(p,'TimeUnit','min',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});

assert(isnumeric(time) && isvector(time), ...
    'time must be a numeric vector.');
assert(isnumeric(signals), ...
    'signals must be a numeric vector or matrix.');
time = double(time(:));
if isvector(signals), signals=signals(:); end
assert(size(signals,1)==numel(time), ...
    'signals must have one row per time sample.');

existing = double(p.Results.ExistingIntervals);
if ~isempty(existing)
    assert(all(isfinite(existing),'all') && ...
        all(existing(:,2)>=existing(:,1)), ...
        'ExistingIntervals must contain finite [start end] rows.');
end

labels = cellstr(string(p.Results.SignalLabels));
if isempty(labels)
    labels = arrayfun(@(i)sprintf('Signal %d',i), ...
        1:size(signals,2),'UniformOutput',false);
end
assert(numel(labels)==size(signals,2), ...
    'SignalLabels must contain one label per signal column.');

fig = figure('Color','w','Name','Photometry artifact review');
ax = axes(fig); hold(ax,'on');
colours = lines(size(signals,2));
for i = 1:size(signals,2)
    plot(ax,time,signals(:,i),'Color',colours(i,:));
end
for i = 1:size(existing,1)
    xline(ax,existing(i,1),'k--');
    xline(ax,existing(i,2),'k--');
end
xlabel(ax,sprintf('Time (%s)',char(string(p.Results.TimeUnit))));
ylabel(ax,'Signal');
title(ax,{char(string(p.Results.Title)), ...
    'Click interval start/end pairs; press Return when finished'}, ...
    'Interpreter','none');
legend(ax,labels,'Location','best','Interpreter','none');
box(ax,'off'); drawnow;

disp('Select artifact intervals with pairs of clicks; press Return to finish.');
[x,~] = ginput;
if isvalid(fig), close(fig); end
if mod(numel(x),2)~=0
    warning('Odd number of clicks; the final click was ignored.');
    x = x(1:end-1);
end

if isempty(x)
    newIntervals = zeros(0,2);
else
    pairs = sort(reshape(x,2,[]),1);
    newIntervals = permute(pairs,[2 1]);
end
intervals = sortrows([existing;newIntervals],1);
end
