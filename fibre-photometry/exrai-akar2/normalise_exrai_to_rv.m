function normalisation_summary = normalise_exrai_to_rv(cfg, varargin)
% NORMALISE_EXRAI_TO_RV  Scale each treatment to the animal's RV peak.
%
% Each session is smoothed using the configured historical moving-mean
% window before scaling to the peak of the same animal's RV session.

p = inputParser;
addParameter(p,'save_figures',true,@islogical);
addParameter(p,'source_root',cfg.processed_root,@(x) ischar(x) || isstring(x));
addParameter(p,'output_root',cfg.processed_root,@(x) ischar(x) || isstring(x));
addParameter(p,'summary_root',cfg.summary_root,@(x) ischar(x) || isstring(x));
parse(p,varargin{:});
options = p.Results;

subjects = cfg.subjects;
sessions = cfg.sessions;
ref_treatment = cfg.normalisation.reference_treatment;
smooth_sec = cfg.normalisation.smooth_sec;

summary_rows = cell(numel(sessions),5);
rv_peak_map = containers.Map();

%% Find RV peak for each subject
for i = 1:numel(subjects)
    subject = subjects{i};
    file = fullfile(options.source_root,ref_treatment,subject, ...
        sprintf('%s_%s_outputs_preprocessing.mat',ref_treatment,subject));

    if ~isfile(file)
        warning('Missing RV preprocessing file for %s',subject);
        continue;
    end

    S = load(file);
    x = S.fpx_dRR(:);
    t = S.fpx_time(:);

    dt = median(diff(t),'omitnan');
    win = max(3,round((smooth_sec/60)/dt));
    xs = movmean(x,win,'omitnan');

    rv_peak = max(xs,[],'omitnan');
    if isfinite(rv_peak) && rv_peak > 0
        rv_peak_map(subject) = rv_peak;
    else
        warning('Invalid RV peak for %s',subject);
    end
end

%% Scale every session
for i = 1:numel(sessions)
    treatment = sessions(i).treatment;
    subject = sessions(i).subject;

    in_file = fullfile(options.source_root,treatment,subject, ...
        sprintf('%s_%s_outputs_preprocessing.mat',treatment,subject));

    if ~isfile(in_file) || ~isKey(rv_peak_map,subject)
        summary_rows(i,:) = {treatment,subject,'skipped',NaN,''};
        continue;
    end

    S = load(in_file);
    x_raw = S.fpx_dRR(:);
    t = S.fpx_time(:);

    dt = median(diff(t),'omitnan');
    win = max(3,round((smooth_sec/60)/dt));
    x_s = movmean(x_raw,win,'omitnan');

    peak_val = rv_peak_map(subject);
    scaled_dRR = x_s ./ peak_val;

    scaled_zdRR = [];
    baseline_mean = NaN;
    baseline_std = NaN;

    if cfg.normalisation.do_zscore_after_scaling
        bw = cfg.normalisation.baseline_window;
        mask = t >= bw(1) & t <= bw(2);
        baseline_mean = mean(scaled_dRR(mask),'omitnan');
        baseline_std  = std(scaled_dRR(mask),'omitnan');
        if isfinite(baseline_std) && baseline_std > 0
            scaled_zdRR = (scaled_dRR-baseline_mean)./baseline_std;
        end
    end

    out_dir = fullfile(options.output_root,treatment,subject);
    if ~exist(out_dir,'dir'), mkdir(out_dir); end
    out_file = fullfile(out_dir,sprintf('%s_%s_normalized_to_RV.mat', ...
        treatment,subject));

    save(out_file,'scaled_dRR','scaled_zdRR','t','peak_val','win', ...
        'smooth_sec','x_raw','x_s','baseline_mean','baseline_std');

    if options.save_figures
        fig = figure('Visible','off','Color','w');
        plot(t,x_raw,'DisplayName','Original'); hold on;
        plot(t,x_s,'DisplayName','Smoothed');
        plot(t,scaled_dRR,'LineWidth',1.4,'DisplayName','Scaled to RV peak');
        xlabel('Time (min)'); ylabel('dR/R');
        title(sprintf('%s | %s',treatment,subject),'Interpreter','none');
        legend('Location','best'); box off;
        exportgraphics(fig,fullfile(out_dir,sprintf('%s_%s_scaled.png', ...
            treatment,subject)),'Resolution',200);
        close(fig);
    end

    relative_output = fullfile(treatment,subject, ...
        sprintf('%s_%s_normalized_to_RV.mat',treatment,subject));
    summary_rows(i,:) = {treatment,subject,'ok',peak_val,relative_output};
end

T = cell2table(summary_rows,'VariableNames', ...
    {'Treatment','Subject','Status','RV_Peak','OutputFile'});

out_dir = fullfile(options.summary_root,'scaling-to-RV');
if ~exist(out_dir,'dir'), mkdir(out_dir); end
writetable(T,fullfile(out_dir,'rv_normalisation_summary.csv'));

fprintf('RV normalisation complete.\n');
normalisation_summary = T;
end
