function summary = summarize_fig3fk_exrai(cfg)
% SUMMARIZE_FIG3FK_EXRAI  Summarize RV-normalized Fig. 3f/k traces.
%
% VG and RG provide the Fig. 3f panels; GR provides the Fig. 3k panel.
% RV is included only in the all-condition quality-control trace figure.

treatments = cfg.analysis.fig3fk.treatments;

% QC trace panels include RV as well, because all sessions are normalised
% to each subject's RV peak. RV is shown for visual mapping/QC only; it is
% not included in the 15-minute VG/RG/GR summary calculations above.
plot_treatments = [treatments, {'RV'}];
intervals = cfg.analysis.fig3fk.intervals;
labels = cfg.analysis.fig3fk.labels;
carry_tail = cfg.analysis.fig3fk.carry_forward_tail;

rows = {};

for tr = 1:numel(treatments)
    treatment = treatments{tr};

    for s = 1:numel(cfg.subjects)
        subject = cfg.subjects{s};
        file = fullfile(cfg.processed_root,treatment,subject, ...
            sprintf('%s_%s_normalized_to_RV.mat',treatment,subject));

        if ~isfile(file)
            warning('Missing %s',file);
            continue;
        end

        S = load(file);
        t = S.t(:);
        y = S.scaled_dRR(:);

        means = nan(1,size(intervals,1));
        auc_total = nan(size(means));
        auc_neg = nan(size(means));
        auc_pos = nan(size(means));

        for k = 1:size(intervals,1)
            [means(k),auc_total(k),auc_neg(k),auc_pos(k)] = ...
                analyse_interval(t,y,intervals(k,:),carry_tail);
        end

        rows(end+1,:) = [{treatment,subject}, ...
            num2cell(means),num2cell(auc_total),num2cell(auc_neg),num2cell(auc_pos)]; %#ok<AGROW>
    end
end

vn = {'Treatment','Subject'};
vn = [vn, strcat('Mean_',matlab.lang.makeValidName(labels)), ...
          strcat('AUC_',matlab.lang.makeValidName(labels)), ...
          strcat('AUCneg_',matlab.lang.makeValidName(labels)), ...
          strcat('AUCpos_',matlab.lang.makeValidName(labels))];

T = cell2table(rows,'VariableNames',vn);

out_dir = fullfile(cfg.summary_root,'fig3fk');
if ~exist(out_dir,'dir'), mkdir(out_dir); end
writetable(T,fullfile(out_dir,'session_summary.csv'));

% Positive AUC wide table
W = table(string(cfg.subjects(:)),'VariableNames',{'Subject'});
for tr = 1:numel(treatments)
    treatment = treatments{tr};
    R = T(strcmp(T.Treatment,treatment),:);
    for k = 1:numel(labels)
        col = ['AUCpos_' matlab.lang.makeValidName(labels{k})];
        outcol = sprintf('%s_%s',treatment,matlab.lang.makeValidName(labels{k}));
        vals = nan(numel(cfg.subjects),1);
        for s = 1:numel(cfg.subjects)
            m = strcmp(string(R.Subject),cfg.subjects{s});
            if any(m), vals(s) = R.(col)(find(m,1)); end
        end
        W.(outcol) = vals;
    end
end
writetable(W,fullfile(out_dir,'positive_auc_by_subject_wide.csv'));

% Wide trace exports for figure source data: one shared time column and one
% normalized trace column per animal, plus a separate group mean/SEM table.
for tr = 1:numel(plot_treatments)
    treatment = plot_treatments{tr};
    t_cells = {}; y_cells = {}; names = {};
    for s = 1:numel(cfg.subjects)
        subject = cfg.subjects{s};
        file = fullfile(cfg.processed_root,treatment,subject, ...
            sprintf('%s_%s_normalized_to_RV.mat',treatment,subject));
        if ~isfile(file), continue; end
        S = load(file,'t','scaled_dRR');
        valid = isfinite(S.t(:)) & isfinite(S.scaled_dRR(:));
        t_cells{end+1} = S.t(valid); %#ok<AGROW>
        y_cells{end+1} = S.scaled_dRR(valid); %#ok<AGROW>
        names{end+1} = matlab.lang.makeValidName(['sub_' subject]); %#ok<AGROW>
    end
    if isempty(t_cells), continue; end
    % Use the same canonical time grid for every treatment.  Samples that
    % are not present in a session remain NaN rather than shifting the
    % treatment's time axis to its available overlap.
    t_common = linspace(-30,45,2000)';
    Y = nan(numel(t_common),numel(t_cells));
    for j = 1:numel(t_cells)
        Y(:,j) = interp1(t_cells{j},y_cells{j},t_common,'linear',NaN);
    end
    trace_export = array2table([t_common Y], ...
        'VariableNames',[{'TimeMin'},names]);
    writetable(trace_export,fullfile(out_dir, ...
        sprintf('%s_normalized_traces_wide.csv',lower(treatment))));
    mean_export = table(t_common,mean(Y,2,'omitnan'), ...
        std(Y,0,2,'omitnan')./sqrt(sum(isfinite(Y),2)), ...
        sum(isfinite(Y),2),'VariableNames',{'TimeMin','Mean_scaled_dRR','SEM','N'});
    writetable(mean_export,fullfile(out_dir, ...
        sprintf('%s_normalized_group_mean.csv',lower(treatment))));
end

% Fixed subject colours across all treatment panels.
% This makes it easier to verify that the same animal is being mapped
% correctly between VG, RG and GR.
subject_colours = lines(numel(cfg.subjects));

% Overlay figure
fig = figure('Visible','off','Color','w', ...
    'Units','inches','Position',[1 1 7 11]);
tl = tiledlayout(numel(plot_treatments),1,'TileSpacing','compact','Padding','compact');

for tr = 1:numel(plot_treatments)
    treatment = plot_treatments{tr};
    ax = nexttile(tl); hold(ax,'on'); box(ax,'off');

    Y = [];
    Tref = [];
    for s = 1:numel(cfg.subjects)
        subject = cfg.subjects{s};
        file = fullfile(cfg.processed_root,treatment,subject, ...
            sprintf('%s_%s_normalized_to_RV.mat',treatment,subject));
        if ~isfile(file), continue; end
        S = load(file);
        % interp1 requires finite sample points. The canonical time vector
        % can contain trailing NaNs if a cropped trace is slightly longer
        % than the nominal -30 to +45 min timebase.
        src_t = S.t(:);
        src_y = S.scaled_dRR(:);
        valid = isfinite(src_t) & isfinite(src_y);

        src_t = src_t(valid);
        src_y = src_y(valid);

        if numel(src_t) < 2
            warning('Not enough finite points for %s %s; skipping trace.', ...
                treatment,subject);
            continue;
        end

        % interp1 also requires unique sample points.
        [src_t,ia] = unique(src_t,'stable');
        src_y = src_y(ia);

        if isempty(Tref)
            Tref = src_t;
            Y = nan(numel(Tref),numel(cfg.subjects));
        end

        yi = interp1(src_t,src_y,Tref,'linear',NaN);
        Y(:,s) = yi; %#ok<AGROW>

        plot(ax,Tref,yi, ...
            'LineWidth',0.8, ...
            'Color',subject_colours(s,:), ...
            'DisplayName',subject);
    end

    if ~isempty(Y)
        plot(ax,Tref,mean(Y,2,'omitnan'),'k', ...
            'LineWidth',2.2,'DisplayName','Mean');
    end

    title(ax,treatment);
    xlabel(ax,'Time (min)');
    ylabel(ax,'scaled dR/R');
    xlim(ax,[-10 45]);

    % Subject legend only once (first panel) for mapping/QC.
    if tr == 1
        legend(ax,'Location','best','Interpreter','none');
    end
end

exportgraphics(fig,fullfile(out_dir,'fig3fk_all_conditions_qc.pdf'), ...
    'ContentType','vector');
close(fig);


%% Standard presentation figures
% Figure 1: VG + RG
% Figure 2: GR alone
% Individual animals are grey; group mean is thick black.

%% VG + RG
standard_treatments = {'VG','RG'};

fig_std = figure('Visible','off','Color','w', ...
    'Units','inches','Position',[1 1 7.0 3.6]);

tl_std = tiledlayout(fig_std,1,numel(standard_treatments), ...
    'TileSpacing','compact','Padding','compact');

for tr = 1:numel(standard_treatments)
    treatment = standard_treatments{tr};
    ax = nexttile(tl_std);
    hold(ax,'on');
    box(ax,'off');

    Y = [];
    Tref = [];

    for s = 1:numel(cfg.subjects)
        subject = cfg.subjects{s};

        file = fullfile(cfg.processed_root,treatment,subject, ...
            sprintf('%s_%s_normalized_to_RV.mat',treatment,subject));

        if ~isfile(file)
            continue;
        end

        S = load(file);

        src_t = S.t(:);
        src_y = S.scaled_dRR(:);

        valid = isfinite(src_t) & isfinite(src_y);
        src_t = src_t(valid);
        src_y = src_y(valid);

        if numel(src_t) < 2
            continue;
        end

        [src_t,ia] = unique(src_t,'stable');
        src_y = src_y(ia);

        if isempty(Tref)
            Tref = src_t;
            Y = nan(numel(Tref),numel(cfg.subjects));
        end

        yi = interp1(src_t,src_y,Tref,'linear',NaN);
        Y(:,s) = yi; %#ok<AGROW>

        plot(ax,Tref,yi, ...
            'Color',[0.80 0.80 0.80], ...
            'LineWidth',0.6);
    end

    if ~isempty(Y)
        mu = mean(Y,2,'omitnan');
        plot(ax,Tref,mu,'k','LineWidth',2.2);
    end

    title(ax,treatment,'FontWeight','bold');
    xlabel(ax,'Time (min)');
    ylabel(ax,'scaled dR/R');
    xlim(ax,[-10 45]);
    ylim(ax,[-0.5 2.5])

    set(ax,'FontName','Arial','FontSize',10,'Layer','top');
end

standard_pdf = fullfile(out_dir,'fig3f_VG_RG.pdf');
exportgraphics(fig_std,standard_pdf,'ContentType','vector');
close(fig_std);

fprintf('VG/RG figure saved: %s\n',standard_pdf);

%% GR alone
treatment = 'GR';

fig_gr = figure('Visible','off','Color','w', ...
    'Units','inches','Position',[1 1 3.6 3.6]);

ax = axes(fig_gr);
hold(ax,'on');
box(ax,'off');

Y = [];
Tref = [];

for s = 1:numel(cfg.subjects)
    subject = cfg.subjects{s};

    file = fullfile(cfg.processed_root,treatment,subject, ...
        sprintf('%s_%s_normalized_to_RV.mat',treatment,subject));

    if ~isfile(file)
        continue;
    end

    S = load(file);

    src_t = S.t(:);
    src_y = S.scaled_dRR(:);

    valid = isfinite(src_t) & isfinite(src_y);
    src_t = src_t(valid);
    src_y = src_y(valid);

    if numel(src_t) < 2
        continue;
    end

    [src_t,ia] = unique(src_t,'stable');
    src_y = src_y(ia);

    if isempty(Tref)
        Tref = src_t;
        Y = nan(numel(Tref),numel(cfg.subjects));
    end

    yi = interp1(src_t,src_y,Tref,'linear',NaN);
    Y(:,s) = yi; %#ok<AGROW>

    plot(ax,Tref,yi, ...
        'Color',[0.80 0.80 0.80], ...
        'LineWidth',0.6);
end

if ~isempty(Y)
    mu = mean(Y,2,'omitnan');
    plot(ax,Tref,mu,'k','LineWidth',2.2);
end

title(ax,'GR','FontWeight','bold');
xlabel(ax,'Time (min)');
ylabel(ax,'scaled dR/R');
xlim(ax,[-10 45]);
ylim(ax,[-0.5 3])

set(ax,'FontName','Arial','FontSize',10,'Layer','top');

gr_pdf = fullfile(out_dir,'fig3k_GR.pdf');
exportgraphics(fig_gr,gr_pdf,'ContentType','vector');
close(fig_gr);

fprintf('GR figure saved: %s\n',gr_pdf);

fprintf('VG/RG/GR 15-minute summary complete.\n');

summary = struct( ...
    'session_summary',T, ...
    'positive_auc_by_subject',W, ...
    'intervals',intervals, ...
    'labels',{labels});
end

function [m,A,Aneg,Apos] = analyse_interval(t,y,range,carry_tail)
mask = t >= range(1) & t <= range(2) & isfinite(t) & isfinite(y);
if nnz(mask) < 2
    [m,A,Aneg,Apos] = deal(NaN);
    return;
end

tx = t(mask);
yx = y(mask);
[tx,ia] = unique(tx,'stable');
yx = yx(ia);

if carry_tail && tx(end) < range(2)
    dt = median(diff(tx),'omitnan');
    if isfinite(dt) && dt > 0
        tail_t = (tx(end)+dt:dt:range(2))';
        if ~isempty(tail_t)
            ymean = mean(yx,'omitnan');
            tx = [tx;tail_t];
            yx = [yx;repmat(ymean,numel(tail_t),1)];
        end
    end
end

m = mean(yx,'omitnan');
seg = 0.5*(yx(1:end-1)+yx(2:end)).*diff(tx);
A = sum(seg,'omitnan');
Aneg = sum(min(seg,0),'omitnan');
Apos = sum(max(seg,0),'omitnan');
end
