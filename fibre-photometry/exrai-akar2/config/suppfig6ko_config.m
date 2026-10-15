function cfg = suppfig6ko_config()
% SUPPFIG6KO_CONFIG Supplemental Fig. 6k-o ExRaiAKAR2 settings.

cfg.figure = 'suppfig6ko';
cfg.figure_label = 'Supplemental Fig. 6k-o';
cfg.sensor = 'ExRaiAKAR2';

cfg.files.panel_k = 'suppfig6k_exrai_raw_channels_045871.csv';
cfg.files.panel_l = 'suppfig6l_exrai_baseline_examples.csv';
cfg.files.panel_m = 'suppfig6m_exrai_rac_repeatability.csv';
cfg.files.panel_m_stats = 'suppfig6m_exrai_icc_summary.csv';
cfg.files.panel_n = 'suppfig6n_exrai_normalisation_examples.csv';
cfg.files.panel_o = 'suppfig6o_exrai_auc_comparison.csv';
cfg.files.panel_o_stats = 'suppfig6o_exrai_variability_statistics.csv';
cfg.files.panel_o_bootstrap = 'suppfig6o_exrai_cv_bootstrap_statistics.csv';

cfg.subjects = {'045871','046139','046140','046141', ...
    '046143','046145','046146'};
cfg.panel_k_subject = '045871';
cfg.panel_l_subjects = {'045871','046141'};
cfg.panel_n_subjects = {'045871','046141'};

cfg.panel_k_treatment = 'RV';
cfg.panel_l_treatment = 'VG';
cfg.panel_m_treatments = {'RV','RG'};
cfg.panel_n_treatment = 'VG';
cfg.panel_o_treatment = 'VG';

cfg.panel_k_window_min = [-5 10];
cfg.panel_l_window_min = [-10 0];
cfg.panel_n_window_min = [-10 30];
cfg.baseline_window_min = [-15 0];
cfg.rac_peak_window_min = [0 15];
cfg.gbr_auc_window_min = [15 30];
cfg.smooth_sec = 30;
cfg.carry_forward_tail = true;
cfg.n_bootstrap_icc = 1000;
cfg.n_bootstrap_variability = 10000;
cfg.random_seed = 1;
end
