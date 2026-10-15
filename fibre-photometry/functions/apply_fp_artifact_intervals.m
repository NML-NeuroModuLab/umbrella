function [signalsOut, artifactMask] = apply_fp_artifact_intervals( ...
    time,signals,intervals,varargin)
% APPLY_FP_ARTIFACT_INTERVALS Apply reviewed artifact intervals to signals.
%
% [signalsOut,artifactMask] = apply_fp_artifact_intervals( ...
%     time,signals,intervals)
% [signalsOut,artifactMask] = apply_fp_artifact_intervals( ...
%     ..., 'Method','mask'|'nan'|'interpolate')
%
% Inputs
%   time       N-element time vector. Units must match intervals.
%   signals    N-by-M signal matrix. A single row or column vector is also
%              accepted.
%   intervals  K-by-2 matrix containing inclusive [start end] intervals.
%
% Methods
%   mask         Return signals unchanged and provide artifactMask.
%   nan          Replace artifact samples with NaN (default).
%   interpolate  Linearly interpolate artifact samples only when valid data
%                bracket them. Leading and trailing artifacts remain NaN.
%
% Time is never shortened or shifted. This preserves event alignment and
% makes the returned mask suitable for excluding samples from model fits.

p = inputParser;
addParameter(p,'Method','nan',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});
method = lower(char(string(p.Results.Method)));
validMethods = {'mask','nan','interpolate'};
assert(any(strcmp(method,validMethods)), ...
    'Method must be mask, nan, or interpolate.');

assert(isnumeric(time) && isvector(time), ...
    'time must be a numeric vector.');
assert(isnumeric(signals), ...
    'signals must be a numeric vector or matrix.');
assert(isnumeric(intervals) && size(intervals,2)==2, ...
    'intervals must be a numeric K-by-2 matrix.');

time = double(time(:));
wasRowVector = isvector(signals) && isrow(signals);
if isvector(signals)
    signals = signals(:);
end
assert(size(signals,1)==numel(time), ...
    'signals must have one row per time sample.');

if ~isempty(intervals)
    assert(all(isfinite(intervals),'all'), ...
        'Artifact interval boundaries must be finite.');
    assert(all(intervals(:,2)>=intervals(:,1)), ...
        'Each artifact interval must have end >= start.');
end

artifactMask = false(size(time));
for i = 1:size(intervals,1)
    artifactMask = artifactMask | ...
        (time>=intervals(i,1) & time<=intervals(i,2));
end

signalsOut = double(signals);
switch method
    case 'mask'
        % No signal mutation; use artifactMask to exclude samples.
    case 'nan'
        signalsOut(artifactMask,:) = NaN;
    case 'interpolate'
        for channel = 1:size(signalsOut,2)
            y = signalsOut(:,channel);
            valid = ~artifactMask & isfinite(time) & isfinite(y);
            y(artifactMask) = NaN;
            if nnz(valid)>=2
                y(artifactMask) = interp1(time(valid),y(valid), ...
                    time(artifactMask),'linear',NaN);
            end
            signalsOut(:,channel) = y;
        end
end

if wasRowVector
    signalsOut = signalsOut.';
end
end
