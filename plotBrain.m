function plotBrain(regions, values, cm, varargin)
% PLOTBRAIN Create simple line-art SVG brain plots.
%
% PLOTBRAIN(REGIONS, VALUES, CM) creates brain plot with regions having
% colors as specified by the REGIONS and VALUES vectors with a colormap
% defined by the matrix CM. Colormap CM can have any number of rows, but
% must have exactly 3 columns.
%
% PLOTBRAIN(REGIONS, VALUES, CM, ...) creates brain plots with additional
% optional arguments:
% 'limits'     Two element vector [cmin cmax]. cmin and cmax are assigned
%              to the first and last color in the colormap.
%              - default: [min(values) max(values)]
% 'viewer'     A logical indicating whether the created figure will be opened 
%              in web viewer.
%              - default: true
% 'savePath'   A char array with location and first part of the output file name.
%              File name will be: ['savePath'_ATLASNAME.svg]
%              - default: temporary dir, deleted afterwards.
% 'scaling'    A scalar specifying scaling of image. Original scaling is very 
%              large, but smaller scalings show small white lines
%              - default: '0.1' (10%)
% 'atlas'      Atlas that is being used:
%              'aparc'            - Desikan-Killiany atlas
%              'aparc_aseg'       - Desikan-Killiany atlas + subcortical ASEG
%                                   segmentation
%              'lausanne120'      - 120 regions Cammoun sub-parcellation of
%                                   the Desikan-Killiany atlas
%              'lausanne120_aseg' - 120 regions Cammoun sub-parcellation +
%                                   subcortical ASEG segmentation
%              'lausanne250'      - 250 regions Cammoun sub-parcellation
%              'wbb47'            - 39 regions combined Walker-von Bonin and Bailey
%                                   parcellation atlas of the macaque
%              - default: 'lausanne120'

% PARSE INPUT
% Parse and validate required input variables
assert(iscellstr(regions), ...
    'Variable REGIONS must be a cell array of character vectors');
assert(isnumeric(values), 'Variable VALUES must be numeric.');
regions = regions(:); 
assert(isvector(regions) && isvector(values) && ...
    numel(regions) == numel(values), ...
    'Variables REGIONS and VALUES must have the same size.');
assert(isnumeric(cm) && (size(cm,2) == 3), ...
    'Colormap CM must be a numeric matrix with exactly 3 columns.');

% Parse and validate optional arguments
while ~isempty(varargin)
    if numel(varargin) == 1
        error('plotBrain:missingOptions', ...
            'Optional arguments must come in pairs.');
    end
    
    switch lower(varargin{1})
        case 'limits'
            assert(isnumeric(varargin{2}), (numel(varargin{2}) == 2), ...
                'Variable LIMITS must be a 2 element vector.');
            values_min = varargin{2}(1);
            values_max = varargin{2}(2);
        case 'viewer'
            assert(numel(varargin{2}) == 1, ...
                'Variable VIEWER must be a scalar.');
            viewer = varargin{2}>0;
        case 'savepath'
            assert(ischar(varargin{2}), ...
                'Variable SAVEPATH must be char array.');
            save_file = varargin{2};
        case 'scaling'
            assert(isnumeric(varargin{2}), ...
                'Variable SCALING must be a scalar > 0 and <= 1.');
            assert((varargin{2} > 0) & (varargin{2} <= 1), ...
                'Variable SCALING must be a scalar > 0 and <= 1.');
            scaling = varargin{2};     
        case 'atlas'
            assert(ischar(varargin{2}), ...
                'Variable ATLAS must be char array.');
            atlas = lower(varargin{2});            
    end
    
    varargin(1:2) = [];
    
end

% Set default values for optional input arguments
if ~exist('save_file', 'var')
    tmpDir = tempdir;
    tmpDir = [tmpDir 'matlab_plot_surface_' num2str(randi(10000))];
    mkdir(tmpDir);
    save_file = [tmpDir '/plot'];
end

if ~exist('values_min', 'var')
    values_min = nanmin(values);
    values_max = nanmax(values);
end

if ~exist('viewer', 'var')
    viewer = true;
end

if ~exist('scaling', 'var')
    scaling = 0.1;
end

if ~exist('atlas', 'var')
    atlas = 'lausanne120';
end

% INITIALIZE
cb_path = [save_file '_cb.png'];
combined_svg_path = [save_file '_' atlas '.svg'];
original_svg_path = fullfile(strrep(which(mfilename),[mfilename '.m'],''), ...
    'atlases', [atlas '_template.svg']);

assert(exist(original_svg_path, 'file') > 0, ...
    'Atlas reference SVG not found (%s).', original_svg_path);

% In atlases with region names that partly overlap (e.g. region FE and FEE)
% ensure that only the full name is selected.
switch atlas
    case 'aparc'
        regions = strcat(regions, '_');        
    case 'aparc_aseg'
        regions = strcat(regions, '_');    
    case 'wbb47'
        regions = strcat(regions, '_');   
end

% COLORING
% cut-off values at values_min and values_max
values(values<values_min) = values_min;
values(values>values_max) = values_max;

n_color = size(cm,1);
if length(unique(values)) > 1
    
    %normalize values to between 0 and 1
    values_norm = (values-values_min)./(values_max - values_min);
    
    % project values to colormap
    values_color = round(values_norm*(n_color-1))+1;
    coloring = cm(values_color,:);
    
else
    % if only one value is specified, pick one color
    coloring = cm(repmat(n_color, [length(values) 1]), :);
end

% write cm as hex rgb code
coloring_rgb = cell(size(coloring,1),1);
for i = 1:size(coloring,1)
    red = coloring(i,1);
    green = coloring(i,2);
    blue = coloring(i,3);
    htmlcolor = strcat('#', ...
        dec2hex(round(255*red), 2), ...
        dec2hex(round(255*green), 2), ...
        dec2hex(round(255*blue), 2));
    coloring_rgb(i,1) = cellstr(htmlcolor);
end

% CREATE SVG
writeBrainSVG(original_svg_path, combined_svg_path, regions, coloring_rgb);

% CERATE COLORBAR PNG
cm2(:,1,:) = cm;
cm2 = repmat(cm2, [ 1 200 1]);
cm2 = flipud(cm2);
imwrite(cm2,cb_path);

% The browser used to view the figures needs full file names (i.e.
% /User/ME/Desktop instead of ~/Desktop).
cb_path = dir(cb_path);
cb_path = fullfile(cb_path.folder, cb_path.name);

% UPDATE SVG
% replace values and path to colorbar
fi = fopen(combined_svg_path,'r');
fo = fopen([combined_svg_path '.tmp'],'w');

% adjust height, colorbar and min/max values in generated SVG
while ~feof(fi)
    tline = fgets(fi);
    
    % Set path to the colorbar image
    tline = strrep(tline, 'colorbarpath', cb_path);
    
    % Set min and max values
    tline = strrep(tline, 'minvalue', sprintf('%0.4g', values_min));
    tline = strrep(tline, 'maxvalue', sprintf('%0.4g', values_max));
    
    % Set scaling
    tline = strrep(tline, 'height="1756mm"', ...
        sprintf('height="%fmm"', scaling*1756));
    tline = strrep(tline, 'width="4224.5mm"', ...
        sprintf('width="%fmm"', scaling*4224.5));    
    
    fwrite(fo,tline);
    
end

fclose(fo);
fclose(fi);
movefile([combined_svg_path '.tmp'], combined_svg_path);

% Expand file name to view the figure in the browser
combined_svg_path = dir(combined_svg_path);
combined_svg_path = fullfile(combined_svg_path.folder, combined_svg_path.name);

% VIEWER
if viewer
    web(combined_svg_path, '-new');
    
    if exist('tmpDir', 'var')
        pause(2);
        rmdir(tmpDir, 's');
    end
end

end


function writeBrainSVG(inname, outname, ID_list, coloring)
% WRITEBRAINSVG Create SVG with updated fill attributes.
%
% WRITEBRAINSVG(INNAME, OUTNAME, ID_LIST, COLORING) Create a new SVG file
% called OUTNAME based on the original SVG INNAME where the fill attribute
% of the elements with IDs in the ID_LIST are updated according to the colors in
% COLORING.

% initialize
fi = fopen(inname,'r');
fo = fopen(outname,'w');
if fo == -1
    error('plotBrain:writeBrainSVG:cannotwrite', ...
            'Cannot write file: %s', outname);
end
tline = fgets(fi);

while ischar(tline)
    
    % find whether any element from ID_list is on this line.
    ID_selected = ~cellfun(@(x) ~contains(tline, x), ...
        ID_list(:,1));
    
    if any(ID_selected)
        if ~isempty(coloring(ID_selected))
            
            % Update the fill attribute.
            position = strfind(tline, 'fill=');
            tline = [tline(1:position+5) coloring{ID_selected}, ...
                tline(position+13:end)];
            
        end
        
        fwrite(fo, tline);
        
    else
        
        % Otherwise, copy the line with no modifications.
        fwrite(fo,tline);
        
    end
    
    tline = fgets(fi);
    
end


fclose(fo);
fclose(fi);

end
