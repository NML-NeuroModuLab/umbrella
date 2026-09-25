function output = process_exrai_session(subject,treatment,raw_folder,cfg,varargin)
% PROCESS_EXRAI_SESSION
% ExRai-AKAR2 preprocessing with timestamps/artifacts read from cfg.

p = inputParser;
p.addParameter('fit_mode','baseline',@(x) any(strcmpi(x,{'baseline','full'})));
p.parse(varargin{:});
fit_mode = lower(p.Results.fit_mode);

raw_root = fullfile(cfg.raw_root,treatment,raw_folder);
save_dir = fullfile(cfg.processed_root,treatment,subject);
if ~exist(save_dir,'dir'), mkdir(save_dir); end

session_idx = find(strcmp({cfg.sessions.treatment},treatment) & ...
                   strcmp({cfg.sessions.subject},subject),1,'first');
if isempty(session_idx)
    error('No config entry for %s %s.',treatment,subject);
end
session_cfg = cfg.sessions(session_idx);

if exist('TDTbin2mat','file') ~= 2
    error('TDTbin2mat was not found on the MATLAB path.');
end

FPdata = TDTbin2mat(raw_root,'TYPE',{'streams','epocs'});
prefix = upper(session_cfg.stream);
if ~ismember(prefix, {'A','B'})
    error('Invalid stream assignment "%s" for %s %s.', ...
        session_cfg.stream,treatment,subject);
end
fprintf('  Streams: %s* (from config)\n',prefix);

fn405 = sprintf('%s405',prefix);
fn465 = sprintf('%s465',prefix);
fn560 = sprintf('%s560',prefix);

if ~isfield(FPdata.streams,fn405) || ~isfield(FPdata.streams,fn465)
    error('Required 405/465 streams were not found for prefix %s.',prefix);
end
has560 = isfield(FPdata.streams,fn560);

orig_fs = FPdata.streams.(fn465).fs;
n_samples = numel(FPdata.streams.(fn465).data);
time_full = (1:n_samples)' ./ orig_fs;

ind1 = find(time_full > cfg.processing.start_s,1,'first');
if isempty(ind1), ind1 = 1; end
ind2 = n_samples;

time_cropped_min = time_full(ind1:ind2)./60;
raw_405 = double(FPdata.streams.(fn405).data(ind1:ind2));
raw_465 = double(FPdata.streams.(fn465).data(ind1:ind2));
if has560
    raw_560 = double(FPdata.streams.(fn560).data(ind1:ind2));
else
    raw_560 = [];
end

LP_405 = lowpass(raw_405,cfg.processing.lowpass_hz,orig_fs);
LP_465 = lowpass(raw_465,cfg.processing.lowpass_hz,orig_fs);
if ~isempty(raw_560)
    LP_560 = lowpass(raw_560,cfg.processing.lowpass_hz,orig_fs);
else
    LP_560 = [];
end

down_fac = max(1,round(orig_fs/cfg.processing.target_fs));
fs = orig_fs/down_fac;
numEl = ceil(numel(LP_465)/down_fac);

down_405 = nan(numEl,1);
down_465 = nan(numEl,1);
down_560 = nan(numEl,1);

for i = 1:numEl
    a = (i-1)*down_fac + 1;
    b = min(a+down_fac-1,numel(LP_465));
    down_405(i) = median(LP_405(a:b),'omitnan');
    down_465(i) = median(LP_465(a:b),'omitnan');
    if ~isempty(LP_560), down_560(i) = median(LP_560(a:b),'omitnan'); end
end

if numel(time_cropped_min) >= 1+down_fac
    dt_min = median(diff(time_cropped_min(1:down_fac:end)),'omitnan');
else
    dt_min = 1/(fs*60);
end
down_time = (0:numEl-1)'.*dt_min + time_cropped_min(1);

% Artifact regions come directly from config.
artifact_regions = session_cfg.artifacts;
if ~isempty(artifact_regions)
    if size(artifact_regions,2) ~= 2
        error('Artifacts must be N x 2 [start_min end_min].');
    end
    for r = 1:size(artifact_regions,1)
        mask = down_time >= artifact_regions(r,1) & down_time <= artifact_regions(r,2);
        down_405(mask) = NaN;
        down_465(mask) = NaN;
        if ~isempty(raw_560), down_560(mask) = NaN; end
    end
end

% Timestamp windows come directly from config.
W = session_cfg.timestamps;
ts = [W.base_start W.base_end W.t1_start W.t1_end W.t2_start W.t2_end];
use_timestamp_crop = all(isfinite(ts));

if use_timestamp_crop
    i_bs  = first_idx(down_time,W.base_start);
    i_be  = first_idx(down_time,W.base_end);
    i_t1s = first_idx(down_time,W.t1_start);
    i_t1e = first_idx(down_time,W.t1_end);
    i_t2s = first_idx(down_time,W.t2_start);
    i_t2e = first_idx(down_time,W.t2_end);
else
    warning('Incomplete timestamps for %s %s; using uncropped trace.',treatment,subject);
end

if strcmp(fit_mode,'full')
    valid_all = isfinite(down_405) & isfinite(down_465);
    idx = find(valid_all);
    if isempty(idx)
        fit_i1 = 1; fit_i2 = numel(down_time);
    else
        fit_i1 = idx(1); fit_i2 = idx(end);
    end
else
    if use_timestamp_crop
        fit_i1 = i_bs; fit_i2 = i_be;
    else
        fit_i1 = first_idx(down_time,1);
        fit_i2 = first_idx(down_time,31);
    end
end

B405 = down_405(fit_i1:fit_i2);
B465 = down_465(fit_i1:fit_i2);
valid = isfinite(B405) & isfinite(B465);

if nnz(valid) >= 2
    fit_coeff = polyfit(B405(valid),B465(valid),1);
else
    fit_coeff = [1 0];
end

fit_405 = fit_coeff(1).*down_405 + fit_coeff(2);
ratio = down_465 ./ fit_405;
base_ratio = mean(ratio(fit_i1:fit_i2),'omitnan');
dRR = (ratio-base_ratio)./base_ratio;

base_dRR = dRR(fit_i1:fit_i2);
base_mean = mean(base_dRR,'omitnan');
base_std = std(base_dRR,'omitnan');
if isfinite(base_std) && base_std > 0
    zdRR = (dRR-base_mean)./base_std;
else
    zdRR = dRR-base_mean;
end

fpx_dRR = dRR;
fpx_zdRR = zdRR;
fpx_time = down_time;
fpx_405 = down_405;
fpx_465 = down_465;
fpx_fit405 = fit_405;
fpx_ratio = ratio;
fpx_sample_rate = fs;

if use_timestamp_crop
    fpx_dRR  = [dRR(i_bs:i_be); dRR(i_t1s:i_t1e); dRR(i_t2s:i_t2e)];
    fpx_zdRR = [zdRR(i_bs:i_be); zdRR(i_t1s:i_t1e); zdRR(i_t2s:i_t2e)];
    fpx_405  = [down_405(i_bs:i_be); down_405(i_t1s:i_t1e); down_405(i_t2s:i_t2e)];
    fpx_465  = [down_465(i_bs:i_be); down_465(i_t1s:i_t1e); down_465(i_t2s:i_t2e)];
    fpx_fit405 = [fit_405(i_bs:i_be); fit_405(i_t1s:i_t1e); fit_405(i_t2s:i_t2e)];
    fpx_ratio = [ratio(i_bs:i_be); ratio(i_t1s:i_t1e); ratio(i_t2s:i_t2e)];

    sample_duration = 1/(fs*60);
    fpx_time = (-30 + sample_duration : sample_duration : 45)';
    L = numel(fpx_dRR);
    if numel(fpx_time) > L
        fpx_time = fpx_time(1:L);
    elseif numel(fpx_time) < L
        fpx_time(end+1:L,1) = NaN;
    end
end

if cfg.processing.save_figures
    fig = figure('Visible','off','Color','w');
    plot(fpx_time,fpx_dRR,'k-');
    xlabel('Time (min)'); ylabel('dR/R');
    title(sprintf('%s | %s | cropped dRR',treatment,subject),'Interpreter','none');
    xlim([-30 45]); box off;
    exportgraphics(fig,fullfile(save_dir,'dRR_fp-cropped.png'),'Resolution',200);
    close(fig);
end

output.subject = subject;
output.treatment = treatment;
output.raw_folder = raw_folder;
output.stream_prefix = prefix;
output.configured_stream = session_cfg.stream;
output.fit_mode = fit_mode;
output.fit_indices = [fit_i1 fit_i2];
output.fit_coeff = fit_coeff;
output.artifact_regions = artifact_regions;
output.timestamps = W;
output.dRR = dRR;
output.zdRR = zdRR;
output.fpx_dRR = fpx_dRR;
output.fpx_zdRR = fpx_zdRR;
output.fpx_405 = fpx_405;
output.fpx_465 = fpx_465;
output.fpx_fit405 = fpx_fit405;
output.fpx_ratio = fpx_ratio;
output.fpx_time = fpx_time;
output.fpx_sample_rate = fpx_sample_rate;

if cfg.processing.save_mat
    save(fullfile(save_dir,sprintf('%s_%s_outputs_preprocessing.mat', ...
        treatment,subject)),'-struct','output');
end
end

function idx = first_idx(t,val)
idx = find(t >= val,1,'first');
if isempty(idx), idx = numel(t); end
end
