function data = load_dlight_recording(data_folder,varargin)
% LOAD_DLIGHT_RECORDING Load one public dLight photometry recording.
%
% Expected files use the sub-<subject_id>_<type> naming convention.
% Stream columns are resolved from metadata rather than constructed from
% the subject ID, allowing the same loader to support multiple figures.

p = inputParser;
addParameter(p,'ExpectedSubject','',@(x)ischar(x)||isstring(x));
addParameter(p,'ExpectedCondition','',@(x)ischar(x)||isstring(x));
addParameter(p,'SignalStream','',@(x)ischar(x)||isstring(x));
addParameter(p,'ReferenceStream','',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});
args = p.Results;

data_folder = char(string(data_folder));
assert(isfolder(data_folder),'Recording folder not found: %s',data_folder);
source_files = recording_files(data_folder,args.ExpectedSubject);
photometry_file = source_files.photometry;
notes_file = source_files.notes;
metadata_file = source_files.metadata;
assert(isfile(photometry_file),'Missing subject photometry: %s',photometry_file);
assert(isfile(notes_file),'Missing subject notes: %s',notes_file);
assert(isfile(metadata_file),'Missing subject metadata: %s',metadata_file);

metadata = jsondecode(fileread(metadata_file));
assert(isfield(metadata,'streams') && ~isempty(metadata.streams), ...
    'metadata.json has no stream definitions: %s',metadata_file);
check_metadata_value(metadata,'subject_id',args.ExpectedSubject,'Subject');
check_metadata_value(metadata,'condition',args.ExpectedCondition,'Condition',true);

reference_column = find_stream_column( ...
    metadata.streams,args.ReferenceStream,405);
signal_column = find_stream_column(metadata.streams,args.SignalStream,465);
photometry = parquetread(photometry_file);
variables = photometry.Properties.VariableNames;
assert(ismember('time_s',variables), ...
    'photometry.parquet has no time_s column: %s',photometry_file);
assert(ismember(reference_column,variables), ...
    'Reference column %s is absent from photometry.parquet.',reference_column);
assert(ismember(signal_column,variables), ...
    'Signal column %s is absent from photometry.parquet.',signal_column);

time_s = double(photometry.time_s(:));
reference = double(photometry.(reference_column)(:));
signal = double(photometry.(signal_column)(:));
assert(numel(time_s)==numel(reference) && numel(time_s)==numel(signal), ...
    'Photometry time, reference, and signal columns have different lengths.');
assert(numel(time_s)>=2 && all(isfinite(time_s)) && all(diff(time_s)>0), ...
    'Photometry timestamps must be finite and strictly increasing.');

measured_fs = 1/median(diff(time_s));
if isfield(metadata,'sample_rate_hz')
    fs = double(metadata.sample_rate_hz);
    if ~isfinite(fs) || fs<=0 || abs(fs-measured_fs)/measured_fs>1e-4
        warning(['Metadata sample rate (%.9g Hz) differs from the rate ', ...
            'measured from time_s (%.9g Hz). Using the measured rate.'], ...
            fs,measured_fs);
        fs = measured_fs;
    end
else
    fs = measured_fs;
end

note_options = detectImportOptions(notes_file,'TextType','string');
text_columns = intersect({'subject_id','event_label','note_text'}, ...
    note_options.VariableNames,'stable');
if ~isempty(text_columns)
    note_options = setvartype(note_options,text_columns,'string');
end
notes = readtable(notes_file,note_options);
required_notes = {'onset_s','offset_s','subject_id','event_label','note_text'};
assert(all(ismember(required_notes,notes.Properties.VariableNames)), ...
    'notes.csv is missing one or more required columns: %s',notes_file);

data = struct('folder',data_folder,'time_s',time_s, ...
    'reference',reference,'signal',signal,'fs',fs,'notes',notes, ...
    'metadata',metadata,'reference_column',reference_column, ...
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
    'notes',fullfile(folder,[prefix 'notes.csv']), ...
    'metadata',fullfile(folder,[prefix 'metadata.json']));
end

function check_metadata_value(metadata,field,expected,label,ignore_case)
if nargin<5, ignore_case = false; end
expected = string(expected);
if strlength(expected)==0, return; end
assert(isfield(metadata,field),'metadata.json has no %s.',field);
actual = string(metadata.(field));
if ignore_case
    matches = strcmpi(actual,expected);
else
    matches = strcmp(actual,expected);
end
assert(matches,'%s mismatch: expected %s, metadata contains %s.', ...
    label,char(expected),char(actual));
end

function column_name = find_stream_column(streams,source_stream,wavelength)
source_names = string({streams.source_stream});
wavelengths = [streams.wavelength_nm];
idx = [];
if strlength(string(source_stream))>0
    idx = find(strcmpi(source_names,string(source_stream)),1,'first');
end
if isempty(idx)
    idx = find(wavelengths==wavelength,1,'first');
end
assert(~isempty(idx),'metadata.json does not define a %d-nm stream.',wavelength);
column_name = char(string(streams(idx).column_name));
end
