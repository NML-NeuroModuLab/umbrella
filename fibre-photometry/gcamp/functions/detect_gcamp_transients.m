function output = detect_gcamp_transients(processed_file,session,cfg)
% DETECT_GCAMP_TRANSIENTS Detect GCaMP events using the historical rule.

X = load(processed_file,'FPX_zdFF','FPX_time','analysis_indices');
trace = X.FPX_zdFF(:);
time = X.FPX_time(:);
first = X.analysis_indices.base_start;
last = X.analysis_indices.base_end;
assert(first>=1&&last<=numel(trace)&&last>=first, ...
    'Historical threshold interval is invalid for %s.',session.subject);

threshold_trace = trace(first:last);
baseline_mad = mad(threshold_trace,1);
prominence_threshold = cfg.processing.transient_mad_multiplier*baseline_mad;
[peaks,locations,widths,prominences] = findpeaks(trace,time, ...
    'MinPeakDistance',cfg.processing.transient_min_distance_min, ...
    'MinPeakProminence',prominence_threshold);
widths = widths*60;
keep = widths<=cfg.processing.transient_max_halfwidth_s;
peaks = peaks(keep);
locations = locations(keep);
widths = widths(keep);
prominences = prominences(keep);

peak_table = table(locations,prominences,widths,peaks, ...
    'VariableNames',{'time_min','prominence_zdff','halfwidth_s','peak_zdff'});
edges = cfg.processing.summary_bin_edges_min;
[counts,~,bins] = histcounts(locations,edges);
labels = edges(2:end)';
mean_prominence = zeros(numel(labels),1);
mean_halfwidth_s = zeros(numel(labels),1);
for k = 1:numel(labels)
    in_bin = bins==k;
    if any(in_bin)
        mean_prominence(k) = mean(prominences(in_bin));
        mean_halfwidth_s(k) = mean(widths(in_bin));
    end
end
minute_summary = table(labels,counts(:),mean_prominence,mean_halfwidth_s, ...
    'VariableNames',{'time_min','transient_count','mean_prominence_zdff', ...
    'mean_halfwidth_s'});
base_count = mean(counts(cfg.processing.summary_rows.baseline));
t1_count = mean(counts(cfg.processing.summary_rows.t1));
t2_count = mean(counts(cfg.processing.summary_rows.t2));
section_summary = table(string(session.subject),string(session.group), ...
    base_count,t1_count,t2_count,baseline_mad,prominence_threshold, ...
    'VariableNames',{'subject','group','baseline_transients_per_min', ...
    't1_transients_per_min','t2_transients_per_min','baseline_mad', ...
    'prominence_threshold'});

save_dir = fileparts(processed_file);
output_file = fullfile(save_dir, ...
    ['test_' session.group '_' session.subject '_transients.mat']);
save(output_file,'peak_table','minute_summary','section_summary', ...
    'baseline_mad','prominence_threshold','threshold_trace');
writetable(peak_table,fullfile(save_dir,'detected_transients.csv'));
writetable(minute_summary,fullfile(save_dir,'transients_per_minute.csv'));

if cfg.processing.save_figures
    fig = figure('Visible','off','Color','w','Units','inches', ...
        'Position',[1 1 8 3]);
    plot(time,trace,'Color',[0.15 0.65 0.9]); hold on;
    plot(locations,peaks,'v','MarkerSize',4,'MarkerFaceColor',[0.9 0.2 0.2], ...
        'MarkerEdgeColor','none');
    xlabel('Time (min)'); ylabel('z dF/F');
    title(sprintf('%s | %s | detected GCaMP transients', ...
        session.group,session.subject),'Interpreter','none');
    xlim(cfg.processing.fpx_time_range_min); box off;
    exportgraphics(fig,fullfile(save_dir,'transient_detection.pdf'), ...
        'ContentType','vector');
    close(fig);
end

output = struct('file',output_file,'peak_table',peak_table, ...
    'minute_summary',minute_summary,'section_summary',section_summary);
end
