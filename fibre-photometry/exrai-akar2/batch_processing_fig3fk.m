%% BATCH_PROCESSING_FIG3FK
% Preprocess all VG, RG, GR, and RV sessions used for Fig. 3f/k.

clear; clc;

script_root = fileparts(mfilename('fullpath'));
addpath(script_root);
paths = exrai_paths('fig3fk');
if isempty(paths.tdt_sdk_root) || ~isfolder(paths.tdt_sdk_root)
    error('Set paths.tdt_sdk_root in exrai_paths.m before preprocessing.');
end
addpath(genpath(paths.tdt_sdk_root));
cfg = fig3fk_config(paths.project_root);

if ~exist(cfg.processed_root,'dir'), mkdir(cfg.processed_root); end
log_dir = fullfile(cfg.processed_root,'logs');
if ~exist(log_dir,'dir'), mkdir(log_dir); end
log_csv = fullfile(log_dir,'batch_log.csv');

if ~isfile(log_csv)
    fid = fopen(log_csv,'w');
    fprintf(fid,'timestamp,treatment,subject,raw_folder,status,note\n');
    fclose(fid);
end

n_ok = 0; n_fail = 0;

for i = 1:numel(cfg.sessions)
    treatment = cfg.sessions(i).treatment;
    subject   = cfg.sessions(i).subject;
    raw_folder = cfg.sessions(i).raw_folder;

    raw_path = fullfile(cfg.raw_root,treatment,raw_folder);
    fprintf('\n=== %s | %s ===\n',treatment,subject);

    if ~exist(raw_path,'dir')
        write_log(log_csv,treatment,subject,raw_folder,'fail', ...
            ['Missing folder: ' raw_path]);
        n_fail = n_fail + 1;
        continue;
    end

    fit_mode = 'baseline';
    F = cfg.processing.full_fit_sessions;
    if ~isempty(F)
        tf = strcmp({F.treatment},treatment) & strcmp({F.subject},subject);
        if any(tf), fit_mode = 'full'; end
    end

    try
        process_exrai_session(subject,treatment,raw_folder,cfg,'fit_mode',fit_mode);

        expected = fullfile(cfg.processed_root,treatment,subject, ...
            sprintf('%s_%s_outputs_preprocessing.mat',treatment,subject));

        if isfile(expected)
            write_log(log_csv,treatment,subject,raw_folder,'ok',['Saved: ' expected]);
            n_ok = n_ok + 1;
        else
            write_log(log_csv,treatment,subject,raw_folder,'fail', ...
                'Expected MAT file was not found.');
            n_fail = n_fail + 1;
        end
    catch ME
        write_log(log_csv,treatment,subject,raw_folder,'fail', ...
            sprintf('%s: %s',ME.identifier,ME.message));
        n_fail = n_fail + 1;
    end
end

fprintf('\nBatch complete: %d ok, %d failed\n',n_ok,n_fail);

function write_log(log_csv,treatment,subject,raw_folder,status,note)
ts = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
fid = fopen(log_csv,'a');
if fid > 0
    fprintf(fid,'%s,%s,%s,%s,%s,"%s"\n', ...
        ts,treatment,subject,raw_folder,status,strrep(note,'"','""'));
    fclose(fid);
end
fprintf('[%s] %s | %s | %s | %s\n',ts,treatment,subject,status,note);
end
