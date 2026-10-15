%% BATCH_PROCESSING_SUPPFIG3EH
% Process Hab3 fits, test-day traces, and GCaMP transient detection.

clear; clc;
sensor_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(sensor_root);
addpath(fullfile(sensor_root,'config'));
addpath(fullfile(sensor_root,'functions'));
cfg = suppfig3eh_config();

fprintf('Supplemental Fig. 3e-h GCaMP analysis\n');
fprintf('Source: %s\nOutput: %s\n',cfg.data_root,cfg.output_root);

%% Subject-specific Hab3 bleach fits
for k = 1:numel(cfg.sessions)
    session = cfg.sessions(k);
    fprintf('\n[Hab3 %d/%d] %s\n',k,numel(cfg.sessions),session.subject);
    process_gcamp_session(session,cfg,'hab3');
end

%% Test-day processing and transient detection
for k = 1:numel(cfg.sessions)
    session = cfg.sessions(k);
    fprintf('\n[Test %d/%d] %s/%s\n', ...
        k,numel(cfg.sessions),session.group,session.subject);
    processed = process_gcamp_session(session,cfg,'test');
    detect_gcamp_transients(processed.file,session,cfg);
end

fprintf('\nSupplemental Fig. 3e-h preprocessing complete.\n');
