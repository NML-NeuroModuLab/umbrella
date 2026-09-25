function summary = ActivityPlot(data_folder)
% ACTIVITYPLOT  Plot and count classified neurons inside polygon regions.
%
% summary = ActivityPlot(data_folder)

if nargin < 1 || isempty(data_folder)
    data_folder = pwd;
end
if ~isfolder(data_folder)
    error('Data folder not found: %s',data_folder);
end

files = dir(fullfile(data_folder,'*.txt'));
file_names = {files.name};
poly_files = file_names(contains(file_names,'_pVLS'));
point_files = file_names(contains(file_names,'_taSPNs'));

if isempty(poly_files)
    error('No polygon files containing "_pVLS" were found in %s.',data_folder);
end

D1SH = [];
D1DD = [];
D2SH = [];
D2DD = [];

for file_index = 1:numel(poly_files)
polygon_name = poly_files{file_index};
nameLoc = strfind(polygon_name,'_pVLS');
fileName = polygon_name(1:nameLoc(1)-1);

matches = point_files(startsWith(point_files,[fileName '_taSPNs']));
if numel(matches) ~= 1
    error('Expected one _taSPNs file for %s; found %d.',fileName,numel(matches));
end

polygon_file = fullfile(data_folder,polygon_name);
points_fileGFP = fullfile(data_folder,matches{1});


polyfid = fopen(polygon_file);
pointsfiGFP = fopen(points_fileGFP);




C = textscan(polyfid, '%f%f', 'delimiter', '\t', 'headerlines', 1);
px = C{1};
py = C{2};


C = textscan(pointsfiGFP, '%f%f%f%f%f', 'delimiter', '\t','headerlines', 1);
EGFP = C{3};
x = C{4};
y = C{5}; 


fclose(polyfid);
fclose(pointsfiGFP);


in = inpolygon(x, y, px, py);

xi = x(in);
yi = y(in);
EGFPi = EGFP(in);


% Classification threshold retained from the original analysis.
is_d2 = EGFPi > 30000;
c = repmat([1,0,1],numel(EGFPi),1);
c(is_d2,:) = repmat([0,1,0],nnz(is_d2),1);

figure;
hold on
plot(px, -py, 'k')
scatter(xi, -yi, 10, c, 'fill');
daspect([1 1 1]);
title(fileName)
hold off   




CountD1 = nnz(~is_d2);
CountD2 = nnz(is_d2);

if startsWith(fileName,'SH')
    D1SH(end+1,1) = CountD1; %#ok<AGROW>
    D2SH(end+1,1) = CountD2; %#ok<AGROW>
elseif startsWith(fileName,'DD')
    D1DD(end+1,1) = CountD1; %#ok<AGROW>
    D2DD(end+1,1) = CountD2; %#ok<AGROW>
end
end


%%end

summary = struct( ...
    'D1_SH',D1SH, ...
    'D2_SH',D2SH, ...
    'D1_DD',D1DD, ...
    'D2_DD',D2DD);
end
