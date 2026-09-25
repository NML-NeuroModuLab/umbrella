function cfg = fig2bd_config(animal,condition)
% FIG2BD_CONFIG  Configuration for the Fig. 2b-d dLight traces.

animal = char(string(animal));
condition = upper(char(string(condition)));

cfg.figure = 'fig2bd';
cfg.figure_label = 'Fig. 2b-d';
cfg.signal_stream = 'C465';
cfg.reference_stream = 'C405';
cfg.raw_start_s = 16;
cfg.target_fs = 100;

cfg.hab3.lowpass_hz = 20;
cfg.hab3.bleach_smoothing_window = 5000;
cfg.hab3.fit_trim_start = 6000;
cfg.hab3.fit_trim_end = 6000;

cfg.test.lowpass_hz = 20;
cfg.test.target_fs = 100;
cfg.test.baseline_fit_smoothing_window = 500;
cfg.test.fpx_time_range = [-30 30];
cfg.test.sync_epoc = 'PrtC';
cfg.test.use_bleach_correction = true;

switch animal
    case '043897'
        cfg.hab3.raw_finish_note = 14;
        cfg.hab3.start_point_405 = [300 -0.003 30 -0.3];
        cfg.hab3.start_point_465 = [300 -0.003 30 -0.3];
        cfg.hab3.timestamps.baseline = [2 32];
        cfg.hab3.timestamps.t1 = [33 48];
        cfg.hab3.timestamps.t2 = [49 64];

    case '043898'
        cfg.hab3.raw_finish_note = 20;
        cfg.hab3.start_point_405 = [230 -0.003 30 -0.3];
        cfg.hab3.start_point_465 = [230 -0.003 30 -0.3];
        cfg.hab3.timestamps.baseline = [3 33];
        cfg.hab3.timestamps.t1 = [34 49];
        cfg.hab3.timestamps.t2 = [53 68];

    case '043899'
        cfg.hab3.raw_finish_note = 22;
        cfg.hab3.start_point_405 = [200 -0.003 30 -0.3];
        cfg.hab3.start_point_465 = [170 -0.003 30 -0.3];
        cfg.hab3.timestamps.baseline = [3 33];
        cfg.hab3.timestamps.t1 = [34 49];
        cfg.hab3.timestamps.t2 = [50 65];

    otherwise
        error('No Fig. 2b-d configuration found for animal %s.',animal);
end

switch condition
    case 'HAB3'
        cfg.condition = 'hab3';

    case {'VG','RG','RV'}
        cfg.condition = condition;
        cfg.test.timestamps.baseline = [3 33];
        cfg.test.timestamps.t1 = [34 49];
        cfg.test.timestamps.t2 = [50 65];

        switch animal
            case {'043897','043898'}
                cfg.test.raw_finish_note = 18;
                if strcmp(animal,'043897') && strcmp(condition,'RG')
                    cfg.test.use_bleach_correction = false;
                elseif strcmp(animal,'043898') && strcmp(condition,'VG')
                    cfg.test.use_bleach_correction = false;
                end
            case '043899'
                cfg.test.lowpass_hz = 10;
                switch condition
                    case 'VG'
                        cfg.test.raw_finish_note = 17;
                    case 'RG'
                        cfg.test.raw_finish_note = 16;
                    case 'RV'
                        cfg.test.raw_finish_note = 17;
                end
        end

    otherwise
        error('Unsupported Fig. 2b-d condition %s.',condition);
end
end
