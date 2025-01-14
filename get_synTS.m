function sample_data = get_synTS(sample_data, depth_offset)
% get_synTS Add inferred temperature and salinity from synTS to an
% IMOS-toolbox sample_data structure.
%
% sample_data must have:
% a TIME and a DEPTH dimension,
% LATITUDE and LONGITUDE variables of TIME dimension,
% the following bounds parameters correctly set:
% time_coverage_start
% time_coverage_end
% geospatial_lon_min
% geospatial_lon_max
% geospatial_lat_min
% geospatial_lat_max
%
% depth_offset is added to the sample_data DEPTH to get the synTS depth
% (sample_data is relative to transducer, synTS is relative to surface).
% 
% The output sample_data will have temperature and salinity variables added.
% temperature and salinity haved dimensions TIME, DEPTH.
% These are profiles interpolated from synTS data in space and time to the 
% position given by TIME, LATITUDE, LONGITUDE and DEPTH (+ depth_offset).

if nargin < 2
    depth_offset = 0;
end

if isempty(which('basoop'))
    if ispc
        settings.synTS_path = { ...
            '\\fstas2-hba\datalib\climatologies\synTS\hindcast13\'; ...
            '\\fstas2-hba\datalib\climatologies\synTS\hindcast06\'; ...
            '\\fstas2-hba\datalib\climatologies\synTS\NRT06\'; ...
            '\\fstas2-hba\datalib\climatologies\synTS\NRT06_v1\'};
    else
        settings.synTS_path = { ...
            '/home/datalib/climatologies/synTS/hindcast13/'; ...
            '/home/datalib/climatologies/synTS/hindcast06/'; ...
            '/home/datalib/climatologies/synTS/NRT06/'; ...
            '/home/datalib/climatologies/synTS/NRT06_v1/'};
    end
else
% directory of synTS files is stored in basoop settings.
settings = basoop();
end

if isempty(sample_data)
    error('sample_data structure not provided')
end

duration = [floor(sample_data.time_coverage_start) ...
    ceil(sample_data.time_coverage_end)];


% read a 3D block of temperature and salinity surrounding the data.
times = 0;
for path = settings.synTS_path'
    % search a ten day window for last file before data.
    % prior to 2006 files are every fourth day, some files may be missing
    for i = 1:10
        dt = datevec(duration(1) - i);
        filename = sprintf('synTS_%4d%0.2d%0.2d.nc', dt(1:3));
        filename = fullfile(path{1}, filename);
        if exist(filename, 'file')
            duration(1) = duration(1) - i;
            break
        end
        %fprintf('File not found, skipping: %s\n', filename);
    end
    
    % search a ten day window for first file after data.
    % prior to 2006 files are every fourth day, some files may be missing
    for i = 1:10
        dt = datevec(duration(2) + i);
        filename = sprintf('synTS_%4d%0.2d%0.2d.nc', dt(1:3));
        filename = fullfile(path{1}, filename);
        if exist(filename, 'file')
            duration(2) = duration(2) + i;
            break
        end
        %fprintf('File not found, skipping: %s\n', filename);
    end
        
    % for each date in duration read data from the file if it exists
    for date = duration(1):duration(2)
        dt = datevec(date);
        filename = sprintf('synTS_%4d%0.2d%0.2d.nc', dt(1:3));
        filename = fullfile(path{1}, filename);
        if exist(filename, 'file')
            ncid=netcdf.open(filename, 'NC_NOWRITE');
            
            % get time
            time_id = netcdf.inqVarID(ncid, 'time');
            nctime = netcdf.getVar(ncid, time_id);
            time_base = strtrim(netcdf.getAtt(ncid, time_id, 'units'));
            if strcmp(' 0.00',time_base(end-4:end))
                time_base = time_base(1:end-5);     % drop timezone
            end
            if strfind(time_base, 'days since') == 1
                nctime = nctime + datenum(time_base(12:end));
            end
            
            % get depth, lat, lon
            depth_id = netcdf.inqVarID(ncid, 'depth');
            depth = netcdf.getVar(ncid, depth_id);
            lat_id = netcdf.inqVarID(ncid, 'lat');
            lat = netcdf.getVar(ncid, lat_id);
            lon_id = netcdf.inqVarID(ncid, 'lon');
            lon = netcdf.getVar(ncid, lon_id);
            
            % find indices of data
            start = find(nctime > sample_data.time_coverage_start, 1);
            endd = find(nctime > sample_data.time_coverage_end, 1);
            west = find(lon > sample_data.geospatial_lon_min, 1);
            east = find(lon < sample_data.geospatial_lon_max, 1, 'last');
            south = find(lat > sample_data.geospatial_lat_min, 1);
            north = find(lat < sample_data.geospatial_lat_max, 1, 'last');
            
            if isempty(west) || isempty(east) || isempty(south) || isempty(north)
                error('SynTS data does not cover region');
            end
            
            % extend bounding box to encompass data
            if isempty(start);      start = 1;          end
            if isempty(endd);       endd = 1;           end
            if start > 1;           start = start - 1;  end
            if endd < length(nctime); endd = endd + 1;  end
            if west > 1;            west = west - 1;    end
            if east < length(lon);  east = east + 1;    end
            if south > 1;           south = south - 1;  end
            if north < length(lat); north = north + 1;  end
                
            ll = [ west south 1 start ];
            ur = [ east north length(depth) endd];
            
            % get temp and sal for bounding box
            temp_id = netcdf.inqVarID(ncid, 'temperature');
            sal_id = netcdf.inqVarID(ncid, 'salinity');
            
            tmp = netcdf.getVar(ncid, temp_id, ll - 1, ur - ll + 1);
            scale = netcdf.getAtt(ncid, temp_id, 'scale_factor');
            offset = netcdf.getAtt(ncid, temp_id, 'add_offset');
            temp = offset + double(tmp) * scale;
            try     % missing_value dropped in new format
                missing = netcdf.getAtt(ncid, temp_id, 'missing_value');
                temp(tmp == missing) = NaN;
            catch
            end
            try
                fill = netcdf.getAtt(ncid, temp_id, '_FillValue');
                temp(tmp == fill) = NaN;
            catch
            end
            
            tmp = netcdf.getVar(ncid, sal_id, ll - 1, ur - ll + 1);
            scale = netcdf.getAtt(ncid, sal_id, 'scale_factor');
            offset = netcdf.getAtt(ncid, sal_id, 'add_offset');
            sal = offset + double(tmp) * scale;
            try
                missing = netcdf.getAtt(ncid, sal_id, 'missing_value');
                sal(tmp == missing) = NaN;
            catch
            end
            try
                fill = netcdf.getAtt(ncid, sal_id, '_FillValue');
                sal(tmp == fill) = NaN;
            catch
            end
            
            % build temperature and salinity from temp and sal
            for i=1:size(temp,4)    % only one in practice so far, but the file format allows multiple
                times = times + 1;
                time(times) = nctime(start + i -1);         %#ok<AGROW>
                temperature(:,:,:,times) = temp(:,:,:,i);   %#ok<AGROW>
                salinity(:,:,:,times) = sal(:,:,:,i);       %#ok<AGROW>
            end
            
            netcdf.close(ncid);
        end
    end
    
    % only get data from one path
    if times > 0
        
        break
    end
end

if times == 0
    error('No synTS data found')
end

%
% interpolate data in time, latitude, longitude
%

lon = lon(west:east);
lat = lat(south:north);

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
    sprintf(' Inferred temperature and salinity read from %s.', path{1}) ...
    ' refer: http://dx.doi.org/10.1016/j.dsr.2010.05.010 ' ...
    'http://www.cmar.csiro.au/cars/ http://www.marine.csiro.au/eez_data/doc/synTS.html '];
if isfield(sample_data, 'history') && ~isempty(sample_data.history);
    comment = [ sample_data.history '\n' comment];
end
sample_data.date_modified = nowt;
sample_data.history = comment;

% create temperature and salinity in sample_data
len = length(sample_data.dimensions{timed}.data);
if tempv == 0
    tempv = length(sample_data.variables) +1;
    salv = tempv + 1;
end

sample_data.variables{tempv}.name = 'temperature';
sample_data.variables{tempv}.dimensions(1) = timed;
sample_data.variables{tempv}.dimensions(2) = depthd;
sample_data.variables{tempv}.data = nan(len, depths);
sample_data.variables{tempv}.source = 'interpolated synTS';

sample_data.variables{salv}.name = 'salinity';
sample_data.variables{salv}.dimensions(1) = timed;
sample_data.variables{salv}.dimensions(2) = depthd;
sample_data.variables{salv}.data = nan(len, depths);
sample_data.variables{salv}.source = 'interpolated synTS';

% get time, latitude and longitude from sample_data
t = sample_data.dimensions{timed}.data;
d = sample_data.dimensions{depthd}.data;
x = sample_data.variables{lonv}.data;
y = sample_data.variables{latv}.data;

tmp = [];
sl = [];

temp = zeros(len, length(depth));
salt = zeros(len, length(depth));

% set sample_data temperature and salinity to values interpolated from
% synTS at sample_data time, lat, lon.
lat = single(lat); 	% should already be
lon = single(lon);	% should already be
time = single(time);	% matlab 7.14 requires x,y,z values for interp3 to be the same type
for i = 1:length(depth)
    tmp(:,:,:) = temperature(:,:,i,:);
    temp(:,i) = interp3(lat, lon, time, tmp, y, x, t);
    
    sl(:,:,:) = salinity(:,:,i,:);
    salt(:,i) = interp3(lat, lon, time, sl, y, x, t);
end

% interpolate profiles to depth layers
% if depth layers are relative to a point other than water surface (e.g.
% transducer depth) the profiles are offset.
for i = 1:len
    sample_data.variables{tempv}.data(i,:) = ...
        interp1(depth, temp(i,:), d + depth_offset); 
    sample_data.variables{salv}.data(i,:) = ...
        interp1(depth, salt(i,:), d + depth_offset); 
end
end






