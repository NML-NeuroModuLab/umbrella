function output_files = DensityPlot(data_folder,output_folder)
% DENSITYPLOT  Create D1 and D2 spatial density plots from point files.
%
% output_files = DensityPlot(data_folder,output_folder)

if nargin < 1 || isempty(data_folder)
    data_folder = pwd;
end
if nargin < 2 || isempty(output_folder)
    output_folder = data_folder;
end
if ~isfolder(data_folder)
    error('Data folder not found: %s',data_folder);
end
if ~isfolder(output_folder)
    mkdir(output_folder);
end

files = dir(fullfile(data_folder,'*.txt'));
file_names = {files.name};
d1_files = file_names(contains(file_names,'_D1'));
d2_files = file_names(contains(file_names,'_D2'));

if isempty(d1_files)
    error('No D1 point files containing "_D1" were found in %s.',data_folder);
end

output_files = strings(2*numel(d1_files),1);
output_index = 0;

for file_index = 1:numel(d1_files)
d1_name = d1_files{file_index};
nameLoc = strfind(d1_name,'_D1');
fileName = d1_name(1:nameLoc(1)-1);

matches = d2_files(startsWith(d2_files,[fileName '_D2']));
if numel(matches) ~= 1
    error('Expected one _D2 file for %s; found %d.',fileName,numel(matches));
end

D1points_file = fullfile(data_folder,d1_name);
D2points_file = fullfile(data_folder,matches{1});


D1pointsfid = fopen(D1points_file);
D2pointsfid = fopen(D2points_file);


C = textscan(D1pointsfid, '%f%f', 'delimiter', '\t', 'headerlines', 1);
xd1 = C{1};
yd1 = C{2};


C = textscan(D2pointsfid, '%f%f', 'delimiter', '\t', 'headerlines', 1);
xd2 = C{1};
yd2 = C{2};




fclose(D1pointsfid);
fclose(D2pointsfid);

% % % figure
% % % colormap jet
% % % hold on
% % % title(fileName)
% % % [bandwidth,density,X,Y]=kde2d(DataD1);
% % % contour(X,Y,density,50)
% % % %scatter(DataD1(:,1),DataD1(:,2), 10, m, 'fill');
% % % xlim([0 7000])
% % % ylim([-6000 2000])
% % % daspect([1 1 1]);
% % % saveName = [fileName '_Contourplot pSTR D1'];
% % % saveas(gcf,saveName,'epsc')
% % % hold off


figure;
hold on
    
    scatter_kde(xd1, -yd1, 'filled', 'MarkerSize', 10);
    daspect([1 1 1]);
    xlim([0 7000])
    ylim([-6000 2000])
    title(fileName)
    saveName = fullfile(output_folder,[fileName '_Densityplot pSTR D1']);
    saveas(gcf,saveName,'epsc')
    output_index = output_index + 1;
    output_files(output_index) = string([saveName '.eps']);
hold off






% % % figure
% % % hold on
% % % colormap jet
% % % title(fileName)
% % % [bandwidth,density,X,Y]=kde2d(DataD2);
% % % contour(X,Y,density,50), 
% % % 
% % % %scatter(DataD2(:,1),DataD2(:,2), 10, g, 'fill');
% % % xlim([0 7000])
% % % ylim([-6000 2000])
% % % daspect([1 1 1]);
% % % 
% % % saveName = [fileName '_Contourplot pSTR D2'];
% % % saveas(gcf,saveName,'epsc')
% % % hold off

figure;
hold on
    
    scatter_kde(xd2, -yd2, 'filled', 'MarkerSize', 10);
    daspect([1 1 1]);
    xlim([0 7000])
    ylim([-6000 2000])
    title(fileName)
    
    saveName = fullfile(output_folder,[fileName '_Densityplot pSTR D2']);
    saveas(gcf,saveName,'epsc')
    output_index = output_index + 1;
    output_files(output_index) = string([saveName '.eps']);
hold off



end



%%end

end
