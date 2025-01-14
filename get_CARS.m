function sample_data = get_CARS(sample_data, depth_offset)
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
% temperature and salinity haved dimensions TIME, DEPTH.
% These are profiles interpolated from synTS data in space and time to the 
% position given by TIME, LATITUDE, LONGITUDE and DEPTH (+ depth_offset).

% uses CARSpath get_clim_profs

if nargin < 2
    depth_offset = 0;
end


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
        depths = length(sample_data.dimensions{k}.data);
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
end

% update history
nowj = (now - datenum([1970 1 1])) * 86400000;              % now in ms since 1970
timezone = java.util.TimeZone.getDefault().getOffset(nowj); % timezone offset in ms  
nowt = now - timezone / 86400000;                           % now UTC in days       
comment = [datestr(nowt, 'yyyy-mm-ddTHH:MM:SSZ') ' '...
    getenv('USER') getenv('UserName') ...
    ' Inferred temperature and salinity read from CARS'  ...
    ' refer: http://www.cmar.csiro.au/cars/ '];
if isfield(sample_data, 'history') && ~isempty(sample_data.history);
    comment = sprintf('%s\n%s', sample_data.history, comment);
end
sample_data.date_modified = nowt;
sample_data.history = comment;

% create temperature and slanity in sample_data
len = length(sample_data.dimensions{timed}.data);
if tempv == 0
    tempv = length(sample_data.variables) + 1;
    salv = tempv + 1;
end

sample_data.variables{tempv}.name = 'temperature';
sample_data.variables{tempv}.dimensions(1) = timed;
sample_data.variables{tempv}.dimensions(2) = depthd;
sample_data.variables{tempv}.data = zeros(depths, len);
sample_data.variables{tempv}.source = 'CARS';

sample_data.variables{salv}.name = 'salinity';
sample_data.variables{salv}.dimensions(1) = timed;
sample_data.variables{salv}.dimensions(2) = depthd;
sample_data.variables{salv}.data = zeros(depths, len);
sample_data.variables{salv}.source = 'CARS';

% get time, latitude and longitude from sample_data
t = sample_data.dimensions{timed}.data;
d = sample_data.dimensions{depthd}.data;
x = sample_data.variables{lonv}.data;
x(x<0) = x(x<0) + 360;
y = sample_data.variables{latv}.data;

if isempty(which('get_clim_profs'))
    CARSpath();
end

[year,~,~] = datevec(t(1));
doy = mod(t - datenum(year,1,1), 365);

[temp, ~] = get_clim_profs('t', x, y, d + depth_offset, doy, 'CARS');
[sal, ~]  = get_clim_profs('s', x, y, d + depth_offset, doy, 'CARS');

sample_data.variables{tempv}.data = temp';
sample_data.variables{salv}.data = sal';



