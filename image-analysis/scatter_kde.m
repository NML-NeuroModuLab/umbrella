function h = scatter_kde(x,y,varargin)
% SCATTER_KDE  Scatter points coloured by their two-dimensional KDE.
%
% This local helper provides the density-coloured scatter plot required by
% DensityPlot.m using the bundled kde2d.m implementation.

x = x(:);
y = y(:);
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);

if numel(x) < 3
    error('At least three finite points are required for a density plot.');
end

marker_size = 10;
marker_filled = false;

index = 1;
while index <= numel(varargin)
    value = varargin{index};
    if (ischar(value) || isstring(value)) && strcmpi(value,'filled')
        marker_filled = true;
        index = index + 1;
    elseif (ischar(value) || isstring(value)) && strcmpi(value,'MarkerSize')
        marker_size = varargin{index+1};
        index = index + 2;
    else
        index = index + 1;
    end
end

[~,density,X,Y] = kde2d([x y]);
point_density = interp2(X,Y,density,x,y,'linear',0);

if marker_filled
    h = scatter(x,y,marker_size,point_density,'filled');
else
    h = scatter(x,y,marker_size,point_density);
end
colormap(gca,'parula');
colorbar;
end
