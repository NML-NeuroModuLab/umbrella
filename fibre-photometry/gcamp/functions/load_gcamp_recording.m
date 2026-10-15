function data = load_gcamp_recording(data_folder,varargin)
% LOAD_GCAMP_RECORDING Read one public GCaMP photometry recording.

p = inputParser;
addParameter(p,'ExpectedSubject','',@(x)ischar(x)||isstring(x));
addParameter(p,'ExpectedCondition','',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});
args = p.Results;

data_folder = char(string(data_folder));
source_files = recording_files(data_folder,args.ExpectedSubject);
photometry_file = source_files.photometry;
video_sync_file = source_files.video_sync;
notes_file = source_files.notes;
metadata_file = source_files.metadata;
assert(isfile(photometry_file),'Missing subject photometry: %s',photometry_file);
assert(isfile(video_sync_file),'Missing subject video-sync Parquet: %s',video_sync_file);
assert(isfile(notes_file),'Missing subject notes: %s',notes_file);
assert(isfile(metadata_file),'Missing subject metadata: %s',metadata_file);

metadata = jsondecode(fileread(metadata_file));
check_value(metadata,'subject_id',args.ExpectedSubject,'Subject',false);
check_value(metadata,'condition',args.ExpectedCondition,'Condition',true);
assert(isfield(metadata,'streams')&&~isempty(metadata.streams), ...
    'metadata.json has no stream definitions: %s',metadata_file);

reference_column = find_wavelength(metadata.streams,405);
signal_column = find_wavelength(metadata.streams,465);
photometry = parquetread(photometry_file);
names = photometry.Properties.VariableNames;
assert(ismember('time_s',names),'Missing time_s in %s',photometry_file);
assert(ismember(reference_column,names),'Missing %s.',reference_column);
assert(ismember(signal_column,names),'Missing %s.',signal_column);

time_s = double(photometry.time_s(:));
reference = double(photometry.(reference_column)(:));
signal = double(photometry.(signal_column)(:));
assert(numel(time_s)==numel(reference)&&numel(time_s)==numel(signal), ...
    'Time and stream lengths differ in %s.',photometry_file);
assert(numel(time_s)>=2&&all(isfinite(time_s))&&all(diff(time_s)>0), ...
    'time_s must be finite and strictly increasing.');
fs = 1/median(diff(time_s));

video_sync = parquetread(video_sync_file);
sync_required = {'onset_s','offset_s','value'};
assert(all(ismember(sync_required,video_sync.Properties.VariableNames)), ...
    'Subject video-sync Parquet is missing required columns: %s',video_sync_file);
video_sync.onset_s = double(video_sync.onset_s(:));
video_sync.offset_s = double(video_sync.offset_s(:));
video_sync.value = double(video_sync.value(:));
assert(~isempty(video_sync)&&all(isfinite(video_sync.onset_s))&& ...
    all(diff(video_sync.onset_s)>=0), ...
    'Synchronization onsets must be finite and ordered.');

opts = detectImportOptions(notes_file,'TextType','string');
text_columns = intersect({'subject_id','event_label','note_text'}, ...
    opts.VariableNames,'stable');
if ~isempty(text_columns), opts=setvartype(opts,text_columns,'string'); end
notes = readtable(notes_file,opts);
required = {'onset_s','offset_s','subject_id','event_label','note_text'};
assert(all(ismember(required,notes.Properties.VariableNames)), ...
    'notes.csv is missing required columns: %s',notes_file);

data = struct('folder',data_folder,'time_s',time_s, ...
    'reference',reference,'signal',signal,'fs',fs,'notes',notes, ...
    'video_sync',video_sync,'metadata',metadata, ...
    'reference_column',reference_column, ...
    'signal_column',signal_column);
end

function files = recording_files(folder,subject)
subject = strip(string(subject));
if strlength(subject)==0
    [~,folder_name] = fileparts(folder);
    subject = string(folder_name);
end
prefix = ['sub-' char(subject) '_'];
files = struct( ...
    'photometry',fullfile(folder,[prefix 'photometry.parquet']), ...
    'video_sync',fullfile(folder,[prefix 'video_sync.parquet']), ...
    'notes',fullfile(folder,[prefix 'notes.csv']), ...
    'metadata',fullfile(folder,[prefix 'metadata.json']));
end

function column = find_wavelength(streams,wavelength)
values = [streams.wavelength_nm];
idx = find(values==wavelength,1,'first');
assert(~isempty(idx),'metadata.json has no %d-nm stream.',wavelength);
column = char(string(streams(idx).column_name));
end

function check_value(metadata,field,expected,label,ignore_case)
expected = string(expected);
if strlength(expected)==0, return; end
assert(isfield(metadata,field),'metadata.json has no %s.',field);
actual = string(metadata.(field));
if ignore_case, match=strcmpi(actual,expected);
else, match=strcmp(actual,expected); end
assert(match,'%s mismatch: expected %s, found %s.',label,expected,actual);
end
