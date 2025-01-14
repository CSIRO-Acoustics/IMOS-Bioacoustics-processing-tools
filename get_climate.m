function sample_data = get_climate(sample_data, depth_offset, ts_only)
% Add temperature and salinity data from the CARS data set to an
% IMOS-toolbox sample_data structure.
% 
% sample_data must have:
% a TIME and a DEPTH dimension,
% LATITUDE and LONGITUDE variables of TIME dimension,
%
% depth_offset is added to the sample_data DEPTH to get the synTS depth
% (sample_data is relative to transducer, CARS is relative to surface).
% 
% The output sample_data will have temperature and salinity variables added.
% If ts_only is not provided or not true oxygen, nitrogen, phosphate and
% silicate are also added.
% temperature and salinity haved dimensions TIME, DEPTH.
% These are profiles interpolated from synTS data in space and time to the 
% position given by TIME, LATITUDE, LONGITUDE and DEPTH (+ depth_offset).

if nargin < 2
    depth_offset = 0;
end

if nargin <3
    ts_only = false;
end

if isempty(which('get_clim_profs'))
    CARSpath;
end

properties = { ...
    't' 'CARS_temperature' ; ...
    's' 'CARS_salinity' ; ...
    'o' 'CARS_oxygen' ; ...
    'n' 'CARS_nitrate' ; ...
    'p' 'CARS_phosphate' ; ...
    'si' 'CARS_silicate' };
TEMP = 1;
SALT = 2;

if ts_only
    properties = properties(1:2,:);
end

props = size(properties,1);
vars = zeros(props,1);

% identify time, latitude and longitude in sample_data
timed = 0;
depthd = 0;
latv = 0;
lonv = 0;
tempv = 0;
salv = 0;
for k = 1:length(sample_data.dimensions)
    if strcmp(sample_data.dimensions{k}.name, 'TIME')
        timed = k;
    end
    if strcmp(sample_data.dimensions{k}.name, 'DEPTH')
        depthd = k;
    end
end
for k = 1:length(sample_data.variables)
    if strcmp(sample_data.variables{k}.name, 'LATITUDE')
        latv = k;
    end
    if strcmp(sample_data.variables{k}.name, 'LONGITUDE')
        lonv = k;
    end
    if strcmp(sample_data.variables{k}.name, 'temperature')
        tempv = k;
    end
    if strcmp(sample_data.variables{k}.name, 'salinity')
        salv = k;
    end
    for i = 1:props
        if strcmp(sample_data.variables{k}.name, properties{i,2})
            vars(i) = k;
        end
    end
end

% get time, latitude and longitude from sample_data
t=sample_data.dimensions{timed}.data;
[year,~,~] = datevec(t(1));
doy = mod(t - datenum(year,1,1), 365);
d = sample_data.dimensions{depthd}.data + depth_offset;
x = sample_data.variables{lonv}.data;
x(x<0) = x(x<0) + 360;
y = sample_data.variables{latv}.data;

% update history
nowj = (now - datenum([1970 1 1])) * 86400000;              % now in ms since 1970
timezone = java.util.TimeZone.getDefault().getOffset(nowj); % timezone offset in ms  
nowt = now - timezone / 86400000;                           % now UTC in days       
comment = [datestr(nowt, 'yyyy-mm-ddTHH:MM:SSZ') ' '...
    getenv('USER') getenv('UserName') ...
    ' Environmental variables read from CARS'  ...
    ' refer: http://www.cmar.csiro.au/cars/ '];
if isfield(sample_data, 'history') && ~isempty(sample_data.history);
    comment = sprintf('%s\n%s', sample_data.history, comment);
end
sample_data.date_modified = nowt;
sample_data.history = comment;

% Get climate variables
for i = 1:props
    if vars(i) == 0
        vars(i) = length(sample_data.variables) + 1;
    end
    sample_data.variables{vars(i)}.name = properties{i,2};
    sample_data.variables{vars(i)}.dimensions(1) = timed;
    sample_data.variables{vars(i)}.dimensions(2) = depthd;
    sample_data.variables{vars(i)}.source = 'CARS';
    sample_data.variables{vars(i)}.data = ...
        get_clim_profs(properties{i,1}, x, y, d, doy, 'CARS')';
end

% If temperature and salinity don't exist copy CARS_temperature and
% CARS_salinity.

if tempv == 0
    tempv = length(sample_data.variables) + 1;
    sample_data.variables{tempv} = sample_data.variables{vars(TEMP)};
    sample_data.variables{tempv}.name = 'temperature';
end
if salv == 0
    salv = length(sample_data.variables) + 1;
    sample_data.variables{salv} = sample_data.variables{vars(SALT)};
    sample_data.variables{salv}.name = 'salinity';
end
        
