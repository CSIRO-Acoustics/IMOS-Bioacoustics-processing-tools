function data = viz_sv(varargin)
%% About viz_sv
% viz_sv is a 'Matlab' based function to read and visualise IMOS SOOP-BA NetCDF file.
%
% For more information about IMOS SOOP-BA project: http://imos.org.au/facilities/shipsofopportunity/bioacoustic/
%
%% Syntax for usage
%   viz_sv
%   viz_sv(ncfile)
%   viz_sv(ncfile, imagefile)
%   viz_sv(ncfile, imagefile, 'channel', channel)
%   viz_sv(ncfile, imagefile, 'all')
%   viz_sv(ncfile, imagefile, 'depth', [min max])
%   viz_sv(ncfile, imagefile, 'noplots')
%   viz_sv(ncfile, imagefile, 'sun')
%   viz_sv(data_struct,data_array)
%   viz_sv(...,'title',title)
%   viz_sv(...,'location',{start end})
%   viz_sv(...,'channel', channel)
%   viz_sv(...,'range',[min max])
%   viz_sv(...,'depth',[min max])
%   viz_sv(...,'cmap',cmap)
%   viz_sv(...,'image',imagefile)
%   viz_sv(...,'axis',ticktype)
%   viz_sv(...,'ypos',ypos)
%   viz_sv(...,'noplots')
%   viz_sv(...,'sun')
%   viz_sv(...,'csv',filename)
%   viz_sv(...,'inf')
%   viz_sv(...,'sv.csv')
%   viz_sv(data_struct,data_array, title)
%
%% Description
% The viz_sv function reads data from an IMOS_SOOP-BA*.nc file and plots
% the raw and processed Sv values in dB and the percentage good for each
% cell along with a plot of the vessel track and raw and processed NASC.
%
% viz_sv returns a data structure containing the data extracted from the
% NetCDF file. This data structure may be passed to later calls of viz_sv
% to plot other data sets.
%
%% Examples
% If viz_sv is called without arguments or the ncfile argument is not a
% file (e.g. is empty or a directory) the user will be asked to select the
% file to read.
%
% If imagefile is specified and image of the plot will be written to file
% depending on the imagefile argument:
%   [] - no file is written
%   '' - empty string - the plot will be written to a file with the same
%        name and directory as ncfile with a '.png' extension added.
%   dir - if imagefile is a valid directory the image will be written to
%        that directory with the same file name as ncfile with a '.png' 
%        extension added.  
%   '-dformat' - an image of the specified format will be written to a file
%        with the same name as ncfile with a .format extension. See print 
%        for a list of supported formats.
%   filename - anything else is treated as the name of the file to write
%        the image to.
%
% If the 'all' option is specified the data structure returned will contain
% all numeric (float or double) fields of the netCDF file.
%
% If the 'noplots' option is specified the data will be read and returned
% but no plots will be generated on screen - a plot will still be written
% to file if imagefile is specified.
%
% viz_sv(data_struct, data_array) will plot the data in data_array
% according to the axis found in data_struct. data_struct should be the
% output of an earlier viz_sv call (data read from a SOOP-BA NetCDF file).
% data_array may be a field of the data_struct or derived from a field of
% data_struct but must have the dimensions of the data_struct arrays.
%
% title will printed (along with the file name) as part of the plot title,
% e.g. title({data_struct.file ; title}).
%
% channel identifies which channel of a multi-channel (multi-frequency)
% data set is to be displayed. Channel may be either the integer index of
% the channel (1 for first channel), the name of the channel or the
% frequency of the channel (the first channel with that frequency). If the
% channel can not be identified or there is only one channel, the first
% channel is used.
%
% range will set the range for the color bar, e.g. caxis(range). An empty
% range will be replaced by the default Sv range [-84, -48].
%
% depth will limit the range for the vertical axis. An empty range will be
% replaced by the range covering valid (non-NaN) Sv data. A scalar range of
% 0 will go from 0 to cover the valid data. A non-zero scalar range will go
% from 0 to the value given.
%
% cmap will be used as the colourmap for the plot, e.g. colormap(cmap). Use
% of the EK500 colourmap may cause matlab to use coarse colourmaps to
% overcome this explicitly state the number of colours to use e.g. 
% viz_sv(...,'cmap',jet(64))
%
% ticktype is one of 'time', 'lat', 'lon', 'latm', 'lonm'
%
% ypos is the number of graph heights from the bottom of the screen to
% place the plot.
%
% 'sun' will use suncyle to calculate the sunrise and sunset times for each
% interval and add these values to the return structure as data.sun.
% It will also calculate whether each interval is in daylight (data.day).
% If a plot is requested it will draw a line on the plot showing day/night.
% This option requires suncycle.m to be in your path
% http://mooring.ucsd.edu/software/matlab/doc/toolbox/geo/suncycle.html 
% Note: this option is fairly slow.
% Bugs: 'sun' does not yet plot day/night on image files.
%
% 'csv' will write a .csv file of the time, longitude and latitude and
% layer summary indices to the file specified. If the file name is empty
% then '.csv' will be added to the netCDF file name. Requires struct2txt in
% path.
%
% 'inf' will generate MBSystem style .inf files and echoview style .gps.csv
% files for the data.
%
% 'sv.csv' will generate echoview style .sv.csv and .gps.csv files for the
% data. One .sv.csv file will be created for each channel.
%
% The minimum requirements for a data_struct is that it must have two
% fields depth and time containing vectors. data_array must be a 2 or 3 
% dimensional array length(depth) x length(time) [x length(channels)].
%
% Other fields which may be used if present in data_struct are:
%    longitude - vector with same size as time
%    latitude  - vector with same size as time
%    file      - string (usually containing filename) used in title
%    location  - cell array of two strings to label start and end of plot
% 
%% Author and version   
%               Tim Ryan <tim.ryan@csiro.au>
%               Gordon Keith <gordon.keith@csiro.au>
% Contributor:  Haris Kunnath <haris.kunnath@csiro.au>
%               Version: 2.7
%               Date: 2020-10-02

%% Set defaults
TIME = 0;
LAT = 1;
LONG = 2;
INTERVAL = 3;
tickformat = TIME;

DEG = 0;
MIN = 1;
degformat = DEG;
min_sv = -84;
range = 36;
max_sv = min_sv + range;

%% Input arguments to the function
if nargin == 0
    ncfile = '';
    
% If first argument is a data structure plot the second arg
  
elseif isstruct(varargin{1})
    data = varargin{1};
    plotdata = varargin{2};
    time = data.time;
    depth = data.depth;
    if isfield(data,'latitude')
        latitude = data.latitude;
    else
        latitude = zeros(size(time));
    end
    if isfield(data, 'longitude')
        longitude = data.longitude;
    else
        longitude = zeros(size(time));
    end
    
    if size(plotdata,1) ~= length(depth) || size(plotdata,2) ~= length(time)
        error('Data array size (%d x %d) does not match axis size (%d x %d)', ...
            size(plotdata,1), size(plotdata,2), length(depth), length(time));
    end
    
    filename = '';
    ttle = '';
    chn = '';
    range = [floor(min(min(min(plotdata)))) ceil(max(max(max(plotdata)))) ];
    if range(1) == -Inf ; range(1) = -100; end
    if range(2) ==  Inf ; range(2) =  100; end
    if range(1) == range(2) ; range(2) = range(2) + 1; end
    drange = [data.depth(1) data.depth(end)];
    location = {'' ''};
    imagefile = [];
    cmap = [];
    channel = 1;
    ypos = 2;
    plt = true;
    sun = false;
    write_csv = false;
    csv_file = '';
    inf_file = false;
    sv_csv = false;
    
    if isfield(data, 'file')        
        fullpath = strsplit(data.file,'\');
        filename = fullpath{end};
    end
    if isfield(data, 'location')
        location = data.location;
    end
    if isfield(data, 'grid_distance')
        grid_distance = data.grid_distance;
    else
        grid_distance = '1 km';
    end
    
    if nargin == 3
        ttle = varargin{3};
    else
        arg = 2;
        while  arg < nargin
            arg = arg + 1;
            if strcmpi('title', varargin{arg})
                arg = arg+1;
                ttle = varargin{arg};
            elseif strncmpi('location', varargin{arg},3)
                arg = arg+1;
                location = varargin{arg};
            elseif strcmpi('range', varargin{arg})
                if arg < nargin && isnumeric(varargin{arg+1})
                    arg = arg+1;
                    range = varargin{arg};
                else
                    range = [];
                end
                if isempty(range)
                    range = [min_sv, max_sv];
                end
            elseif strcmpi('depth', varargin{arg})
                if arg < nargin && isnumeric(varargin{arg+1})
                    arg = arg+1;
                    drange = varargin{arg};
                else
                    drange = [];
                end
            elseif strncmpi('image', varargin{arg},5)
                arg = arg+1;
                imagefile = varargin{arg};
            elseif strcmpi('cmap', varargin{arg})
                arg = arg+1;
                cmap = varargin{arg};
            elseif strncmpi('channel', varargin{arg},2)
                arg = arg+1;
                channel = varargin{arg};
            elseif strncmpi('ypos', varargin{arg},2)
                arg = arg+1;
                ypos = varargin{arg};
            elseif strncmpi('noplots', varargin{arg},3)
                plt = false;
            elseif strncmpi('sun', varargin{arg},3)
                sun = true;
            elseif strncmpi('csv', varargin{arg},3)
                write_csv = true;
                if arg < nargin
                    arg = arg + 1;
                    csv_file = varargin{arg};
                end
            elseif strncmpi('inf', varargin{arg},3)
                inf_file = true;
            elseif strncmpi('sv.csv', varargin{arg},2)
                sv_csv = true;
            elseif strcmpi('axis', varargin{arg})
                arg = arg+1;
                form = varargin{arg};
                if strncmpi(form, 'lat',3)
                    tickformat = LAT;
                elseif strncmpi(form, 'lon',3)
                    tickformat = LONG;
                elseif strncmpi(form, 'int',3)
                    tickformat = INTERVAL;
                end
                if max(form == 'm') || max(form == 'M')
                    degformat = MIN;
                end
            end
        end
    end    
    % Do we need sun data
  
    if sun 
        if isfield(data,'day')
            daynight = -(data.day - 4) / 3; % data.day 1=day 4=night; daynight 1=day 0=night 
        else
            % calculate whether sun is above horizon
            data.sun=zeros(length(data.time),2);
            for itvl=1:length(data.time)
                data.sun(itvl,:)=suncycle(data.latitude(itvl), data.longitude(itvl), data.time(itvl));
            end
            hour = mod(data.time,1) * 24;
            daynight = xor(min(data.sun,[],2) < hour & hour < max(data.sun,[],2), ...
                data.sun(:,1) > data.sun(:,2));
            data.day = 4 - 3 * daynight; % data.day 1=day 4=night; daynight 1=day 0=night
        end
    else
        daynight = [];
    end
    
    % select a single channel to plot
    if ndims(plotdata) == 3
        chn = channel;
        if ischar(channel) && isfield(data, 'channels')
            channel=strtrim(channel);
            for c=1:length(data.channels)
                if strcmpi(channel,data.channels{c})
                    channel = c;
                    break;
                end
            end
        end
        if ischar(channel)
            channel = str2double(channel);
        end
        
        if channel > length(data.channels) && isfield(data, 'frequency')
            channel=strtrim(channel);
            for c=1:length(data.frequency)
                if channel == data.frequency(c)
                    channel = c;
                    break;
                end
            end
        end
        
        if isnan(channel) || channel > size(plotdata,3) || channel < 1 || mod(channel,1) ~= 0
            fprintf('Using channel 1\n');
            channel = 1;
        end
        
        plotdata = plotdata(:,:,channel);
        if isfield(data, 'channels')
            chn = data.channels{channel};
        end
    end
    
    % determine range of valid data, if requested
    if length(drange) < 2
        if drange > 0
            drange = [0 drange];
        else
            if isfield(data, 'Sv')
                dptdata = data.Sv(:,:,channel);
            else
                dptdata = plotdata;
            end
            hasdata = any(isfinite(dptdata),2);
            if isempty(drange)
                drange(1) = depth(find(hasdata,1, 'first'));
            end
            drange(2) = depth(find(hasdata,1, 'last'));
            if isempty(drange)
                error('No valid data to plot');
            end
        end
    end
    
    % trim data to selected depth range
    if drange(end) < depth(end) || drange(1) > depth(1)
        select = depth >= drange(1) & depth <= drange(end);
        plotdata = plotdata(select,:);
    end
    
    if plt
        echogram(plotdata, ypos, { [filename ' ' chn];  ttle }, location, range, cmap, daynight);
    end
    
    if ischar(imagefile)
        write_echogram(plotdata, imagefile, filename, chn, ttle, location, range, cmap);
    end
    
    if write_csv
        csv(data, csv_file)
    end
    
    if inf_file
        info(data);
    end
    
    if sv_csv
        svcsv(data);
    end
    return
    
% first arg is not a struct - it is an ncfile to plot

else
    ncfile = varargin{1};
end

if nargin < 2
    imagefile = [];
else
    imagefile = varargin{2};
end

channel = '';
all_data = false;
plots = true;
sun = false;
write_csv = false;
csv_file = '';
inf_file = false;
sv_csv = false;
dpthrange = [-Inf Inf];

arg = 2;
while arg < nargin
    arg = arg + 1;
    if strcmpi('channel', varargin{arg})
        arg = arg + 1;
        channel = varargin{arg};
    end
    if strcmpi('all', varargin{arg})
        all_data = true;
    end
    if strncmpi('noplots', varargin{arg},3)
        plots = false;
    end
    if strncmpi('sun', varargin{arg},3)
        sun = true;
    end
    if strncmpi('csv', varargin{arg},3)
        write_csv = true;
        if arg < nargin
            arg = arg + 1;
            csv_file = varargin{arg};
        end
    end
    if strncmpi('inf', varargin{arg},3)
        inf_file = true;
    end
    if strncmpi('sv.csv', varargin{arg},2)
        sv_csv = true;
    end
    if strcmpi('depth', varargin{arg})
        if arg < nargin && isnumeric(varargin{arg+1})
            arg = arg + 1;
            dpthrange = varargin{arg};
            if isscalar(dpthrange) && dpthrange > 0
                dpthrange = [0 dpthrange];      %#ok<AGROW>
            end
        else
            dpthrange = [];
        end
    end
end

% Ask user for NetCDF file if not provided
if exist(ncfile, 'file') ~= 2
    [filename, pathname] = uigetfile(...
        {'*.nc' '*.nc NetCDF file'; '*' 'All files'}, ...
        'IMOS-SOOP-BA NetCDF file', ncfile);
    if isequal(filename,0)
        error('NetCDF filename required');
    end
    ncfile = fullfile(pathname,filename);
end

% View NetCDF in Echoview

% Haris 12/07/2019 - Implementing Tim's 'nc2ev' created EV file viewing
% option.
% Haris 30/09/2020 - comment above option because there are some bugs with
% EV file viewing option.
%{
if plots
    try
        ques = questdlg('Do you want to view NetCDF in Echoview?','View in Echoview?','Yes','No','Yes');
        if isequal(ques,'Yes')
            [dir_root, file] = fileparts(ncfile);
            ev_dir = strcat(dir_root,'\echoview_ascii\');
            ev_file_name = dir(fullfile(ev_dir,'*.ev'));
            if exist(ev_dir, 'dir') && ~isempty(ev_file_name)
                if numel(ev_file_name) == 1
                    ev_file_open = strcat(ev_dir,ev_file_name.name);
                    winopen(ev_file_open)
                else
                    cd (ev_dir)
                    file = uigetfile('*.ev','Select an ev file to open'); % select ev file
                    ev_file_open = strcat(ev_dir,file);
                    winopen(ev_file_open)
                    cd (dir_root)
                end
            else
                uiwait(msgbox('Analyst not created an EV file for you.','NetCDF in Echoview','warn'))
            end
        end
    catch
        msgbox('It looks like Echoview unable to open the EV file in "echoview_ascii" folder. Check your Echoview version and update if needed.','NetCDF view in Echoview','error')
    end

    uiwait(msgbox('Click OK to continue with Matlab plots.'))
end
%}

if ischar(imagefile) && isempty(imagefile) && isempty(channel)
    imagefile = [ncfile '.png'];
end

% Open the netcdf file
if exist(ncfile, 'file') ~= 2
    fprintf('\n-----------------------------------------------------\n');
    fprintf('\nnetcdf file %s \ncannot be found, check location\n',ncfile);
    fprintf('\n-----------------------------------------------------\n');
else
    ncid = netcdf.open(ncfile, 'NC_NOWRITE');
    data.file = ncfile;
    [~, filename, ~] = fileparts(ncfile);
    
    try
        location{1} = netcdf.getAtt(ncid, ...
            netcdf.getConstant('NC_GLOBAL'), 'transit_start_locality');
    catch e     %#ok<NASGU>
        location{1} = '';
    end
    try
        location{2} = netcdf.getAtt(ncid, ...
            netcdf.getConstant('NC_GLOBAL'), 'transit_end_locality');
    catch e     %#ok<NASGU>
        location{2} = '';
    end
    data.location = location;
    
    try 
        grid_distance = netcdf.getAtt(ncid, ...
            netcdf.getConstant('NC_GLOBAL'), 'dataset_ping_axis_size');
    catch e     %#ok<NASGU>
        grid_distance = '1 km';
    end
    data.grid_distance = grid_distance;
    
%% Read data variabes    
    try
        latitude = getNetcdfVar(ncid, 'LATITUDE');
        data.latitude = latitude;
        longitude = getNetcdfVar(ncid, 'LONGITUDE');
        data.longitude = longitude;
        
        try
            depthid =  netcdf.inqVarID(ncid, 'DEPTH');
        catch e     %#ok<NASGU>
            depthid =  netcdf.inqVarID(ncid, 'RANGE');
        end
        depth = netcdf.getVar(ncid, depthid);
        data.depth = depth;
        timeid =  netcdf.inqVarID(ncid, 'TIME');
        time = netcdf.getVar(ncid, timeid);
        try
            time_base = netcdf.getAtt(ncid, timeid, 'units');
            if strncmpi(time_base, 'days since', 10)
                time = time + datenum(time_base(12:31));
            end
        catch e     %#ok<NASGU>
            time = time + datenum([1950 01 01]);
        end
        data.time = time;
        
        try        
            svid = netcdf.inqVarID(ncid, 'Sv');
            try                
                bnid  = netcdf.inqVarID(ncid, 'background_noise');  % identfier for background noise. TER 14/11/16
            catch
                bnid = -1;
            end
            try
                snrid = netcdf.inqVarID(ncid, 'signal_noise');  % identfier for signal to noise. TER 14/11/16
            catch
                snrid = -1;
            end
            try
                motid = netcdf.inqVarID(ncid, 'motion_correction_factor');  % identfier for motion correction factor. Haris 14/06/2019
            catch
                motid = -1;
            end
            qcid = netcdf.inqVarID(ncid, 'Sv_quality_control');
            pgid = netcdf.inqVarID(ncid, 'Sv_pcnt_good');
            svrawid = netcdf.inqVarID(ncid,'Sv_unfilt');
        catch e     %#ok<NASGU>
            % support old variable names
            if isempty(channel)
                channel = '38';
            end
            svid = netcdf.inqVarID(ncid, ['Sv_' channel]);
            qcid = netcdf.inqVarID(ncid, ['Sv_' channel '_quality_control']);
            pgid = netcdf.inqVarID(ncid, ['Sv_pcnt_good_' channel]);
            svrawid = netcdf.inqVarID(ncid,['Sv_unfilt_' channel]);
        end
            
        % TER 14/11/16 - signal to noise added
        % check, template versions prior to about June 2016 would not be outputting SNR and BN data
        % these next 10 lines will prevent program crashing on earlier
        % versions of netCDF's that do not have SNR and BN
        
        data.sv = getNetcdfVar(ncid, svid);
        data.qc = netcdf.getVar(ncid, qcid);
        data.pg = getNetcdfVar(ncid, pgid);
        data.svraw = getNetcdfVar(ncid,svrawid);
        if bnid > 0
            try
                data.background_noise = getNetcdfVar(ncid,bnid); % add background noise to data variable. TER 14/11/16
            catch bn_e
                % continue on, no background noise vector present
                fprintf('%s\n',bn_e.message)
            end
        end
        if snrid > 0
            try
                data.snr = getNetcdfVar(ncid,snrid); % add signal-to-noise to data variable. TER 14/11/16
            catch snr_e
                % continue on, no snr matrix present.
                fprintf('%s\n',snr_e.message)
            end
        end        
        if motid > 0
            try
                data.motion_correction_factor = getNetcdfVar(ncid,motid); % add motion correction factor to data variable. Haris 14/06/2019
            catch mot_e
                % continue on, no motion correction factor matrix present.
                fprintf('%s\n',mot_e.message)
            end
        end
 
    catch exception        
        warning('VIZ_SV:BAD_READ', [ 'Unable to read Sv: ' exception.message ])
    end

    if ndims(data.sv) == 3
        try
            data.frequency = getNetcdfVar(ncid, 'frequency');
            channels = getNetcdfVar(ncid, 'CHANNEL')';
            for c = size(channels,1):-1:1
                ch = channels(c,:);
                ch(ch == 0) = [];
                data.channels{c} = strtrim(ch);
            end
        catch
            try
                data.frequency = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'), 'frequency');
                data.channels = {netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'), 'channel')};
            catch
                if ~isfield(data, 'frequency')
                    data.frequency = zeros(size(data.sv,3),1);
                end
                data.channels = cellstr(num2str(data.frequency));
            end
        end
        
        if ischar(channel)
            channel=strtrim(channel);
            for c=1:length(data.channels)
                if strcmpi(channel,data.channels{c})
                    channel = c;
                    break;
                end
            end
        end
        
        if isempty(channel)
            channel = 1:length(data.channels);
        end
            
        if ischar(channel)
            channel = str2double(channel);
        end
        
        if max(channel) > length(data.channels)
            for c=1:length(data.frequency)
                channel(channel == data.frequency(c)) = c;
            end
        end
        
    else
        channel = 1;
        try
            data.frequency = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'), 'frequency');
            data.channels = {netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'), 'channel')};
        catch
            if ~isfield(data, 'frequency')
                data.frequency = 38;
            end
            data.channels = {''};    
        end
    end
    
% Get all data variables, if requested
    if all_data
        [~,nvars,~,~] = netcdf.inq(ncid);
        for varid = 0:nvars-1
            [varname,xtype,~,~] = netcdf.inqVar(ncid,varid);
            if xtype == netcdf.getConstant('NC_FLOAT') || ...
                    xtype == netcdf.getConstant('NC_DOUBLE') || ...
                    xtype == netcdf.getConstant('NC_SHORT')
                if ~isfield(data, varname)
                     data.(varname) = getNetcdfVar(ncid,varid);
                end
            end
        end
    end
    
% Read temperature, salinity, and intermediate results if present
    try
        data.temperature = getNetcdfVar(ncid,'temperature' );
        data.salinity = getNetcdfVar(ncid, 'salinity');
        
        % read intermediate results if present in file
        data.soundspeed = getNetcdfVar(ncid, 'sound_speed');
        data.soundabsorption = getNetcdfVar(ncid, 'absorption') * 1000;
        
        data.abs_sv =  getNetcdfVar(ncid, 'abs_corrected_sv');
        data.abs_Sv = 10 * log10(data.abs_sv);
        
        data.uncorrected_sv = getNetcdfVar(ncid, 'uncorrected_Sv');
        data.uncorrected_sv(data.qc>2)=NaN;
        data.uncorrected_Sv = 10 * log10(data.uncorrected_sv);
        
        data.history = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'), 'history');
    catch e     %#ok<NASGU>
    end
    
% Read summary layer metrics if available
    try
        data.epipelagic = getNetcdfVar(ncid, 'epipelagic');
        data.upper_mesopelagic = getNetcdfVar(ncid, 'upper_mesopelagic');
        data.lower_mesopelagic = getNetcdfVar(ncid, 'lower_mesopelagic');
        data.day = getNetcdfVar(ncid, 'day');
    catch e %#ok<NASGU>
    end
    
    netcdf.close(ncid);

    if ndims(data.sv) == 3
        fields = fieldnames(data);
        for f = 1:length(fields)
            if ndims(data.(fields{f})) == 3
                data.(fields{f}) = shiftdim(data.(fields{f}),1);
            end
        end
    end
    
    try
        % Ignore bad data
        data.sv(data.qc>2)=NaN;
        
        % convert to dB
        data.Sv = 10 * log10(data.sv);
        data.Svraw = 10 * log10(data.svraw);
        
        % calculate NASC
        data.mean_Sv = 10*log10(nmean(data.sv));
        data.NASC = 4*pi*1852*1852*10.^(data.mean_Sv./10)*1200; 
        
        data.mean_Svraw = 10*log10(nmean(data.svraw));
        data.NASCraw = 4*pi*1852*1852*10.^(data.mean_Svraw./10)*1200;     
    catch exception
        warning('VIZ_SV:BAD_SV', [ 'Unable to compute Sv ' exception.message])
    end
    
    if sun
        if isfield(data,'day')
            daynight = -(data.day - 4) / 3;  % data.day 1=day 4=night; daynight 1=day 0=night
        else
            % calculate whether sun is above horizon
            data.sun=zeros(length(data.time),2);
            for itvl=1:length(data.time)
                data.sun(itvl,:)=suncycle(data.latitude(itvl), data.longitude(itvl), data.time(itvl));
            end
            hour = mod(data.time,1) * 24;
            daynight = xor(min(data.sun,[],2) < hour & hour < max(data.sun,[],2), ...
                data.sun(:,1) > data.sun(:,2));
            data.day = 4 - 3 * daynight; % data.day 1=day 4=night; daynight 1=day 0=night
        end
    else
        daynight = [];
    end
      
    if write_csv
        csv(data, csv_file);
    end
    
    if inf_file
        info(data);
    end
    
    if sv_csv
        svcsv(data);
    end
    
    imagefig = [];   

    for c = 1: length(channel)
        chann = channel(c);
        
        % determine range of valid data, if requested
        drange = dpthrange;
        if length(drange) < 2
            hasdata = any(isfinite(data.Sv(:,:,chann)),2);
            if isempty(drange)
                drange(1) = depth(find(hasdata,1, 'first'));
            end
            drange(2) = depth(find(hasdata,1, 'last'));
            if isempty(drange)
                error('No valid data to plot');
            end
        end
        
        % trim data to selected depth range
        select = depth >= drange(1) & depth <= drange(end);
        
        % pull the data out on a per-channel basis
        Sv = data.Sv(select,:,chann);
        pg = data.pg(select,:,chann);
        Svraw = data.Svraw(select,:,chann);
        NASC = data.NASC(:,:,chann);
        NASCraw = data.NASCraw(:,:,chann);
     
        % TER 14/11/16 - signal to noise added check, template versions
        % prior to about June 2016 would not be outputting SNR and BN data
        % these next 10 lines will prevent program crashing on earlier
        % versions of netCDF's that do not have SNR and BN
        
        if isfield(data,'snr') 
            snr = data.snr(:,:,chann);           
        end
        
        if isfield(data,'background_noise')
            if exist('channels') % we have mfreq data (TER)
                bn = data.background_noise(chann,:);
            else
                bn = data.background_noise(:,chann);
            end       
        end
        
        if isfield(data,'motion_correction_factor') % Added motion correction factor Haris 14/06/2019
            mot = data.motion_correction_factor(:,:,chann);           
        end
        % -----------------------------------------------
        ttle = [filename ' ' data.channels{chann}];  
        
        % If second argument was given write Sv image to file
        if ischar(imagefile)
            if c == length(channel)
                write_echogram(Sv, imagefile, ncfile, data.channels{chann}, 'Sv mean (dB re 1 m-1)', ...
                    location, [min_sv max_sv], EK500colourmap(), imagefig);
            else
                imagefig = write_echogram(Sv, '-', ncfile, data.channels{chann}, 'Sv mean (dB re 1 m-1)', ...
                    location, [min_sv max_sv], EK500colourmap(), imagefig);
            end            
        end
        
% Finish if no plots are wanted.
        if ~plots
            continue
        end
  
%% Plot 'processed', 'unprocessed' Sv data, and percentage of Sv retained (%)
        
        idx = strfind(data.channels{chann},'k');
        ttlenew = data.channels{chann}(1:idx-1);
        
        echogram(Sv, 3.1, strcat(ttlenew,' kHz:',' processed mean {\itS_v} (dB re 1 m^2 m^-^3)'), ...
            location, [min_sv max_sv], [], daynight);
        
        echogram(Svraw, 2.1, strcat(ttlenew,' kHz:',' unprocessed mean {\itS_v} (dB re 1 m^2 m^-^3)'), ...
            location, [min_sv max_sv], [], daynight)
        
        echogram(pg, 1.1, strcat(ttlenew,' kHz:',' percentage of {\itS_v} retained (%)'), location, [0 100], jet(256),'');
                
%% Plot signal-to-noise ratio

% TER 14/11/16
        if exist('snr','var')
            echogram(snr, 0.1, strcat(ttlenew,' kHz:',' signal-to-noise-ratio (dB re 1)'),location,[0 40], jet(256),''); % signal to noise ratio
        end

%% Plot motion correction factor

% Haris 14/06/2019 - uncomment if needed
%         if exist('mot')
%             echogram(mot,0.1,strcat(ttlenew,' kHz:',' motion correction factor (%)'),location,[0 20],jet(256),''); % motion correction factor
%         end
    end
    
    if plots

%% Plot echointegration NASC values

% Haris 15/06/2019 to plot on single figure

        if length(channel) == 1 % single frequency
            figure;
            hold on; box on; grid on
            plot(data.time,data.NASC,'Color','#77AC30','LineWidth',1);
            plot(data.time,data.NASCraw,'Color','#A2142F','LineWidth',1);
            legend('Processed NASC', 'Raw NASC','Orientation','horizontal','Location','best');
            xlabel('Time (UTC)')
            datetick('x',19)
            ylabel({'NASC'; '(m^2 nmi^-^2)'});
            title(strcat(ttlenew,' kHz:',' NASC ({\its_v} integrated between 0�1200 m)'))
            p=get(0,'ScreenSize');
            set(gcf,'Position',[50 50 p(3)*0.75 p(4)*0.25])
            zoom(gcf, 'reset');
            if max(data.NASC) > 0
                ylim([0, max(data.NASC)]);
            end
            xlim([min(data.time) max(data.time)])
        else % multi-frequency
            figure;            
            p=get(0,'ScreenSize'); % Set figure size    
            set(gcf,'Position',[50 50 p(3)*0.75 p(4)*0.60])
            for n = 1: length(channel)
                chann_n = channel(n);
                subplot(length(channel),1,chann_n)
                plot(data.time,data.NASC(:,:,chann_n),'Color','#77AC30','LineWidth',1);
                hold on; box on; grid on
                plot(data.time,data.NASCraw(:,:,chann_n),'Color','#A2142F','LineWidth',1);
                if n == max(length(channel)) % keep legend for last panel only
                    xlabel('Time (UTC)')
                    legend('Processed NASC', 'Raw NASC','Orientation','horizontal','Location','best');
                end
                datetick('x',19)
                ylabel({'NASC'; '(m^2 nmi^-^2)'});
                idx = strfind(data.channels{chann_n},'k');
                ttlenew_MF = data.channels{chann_n}(1:idx-1);
                title(strcat(ttlenew_MF,' kHz:',' NASC ({\its_v} integrated between 0�1200 m)'))
                if max(data.NASC(:,:,chann_n)) > 0
                    ylim([0, max(data.NASC(:,:,chann_n))]);
                end
                xlim([min(data.time) max(data.time)])                        
            end            
        end

% same plot with distance - only for checking purpose and referencing to EV files

        if length(channel) == 1 % single frequency
            figure;
            hold on; box on; grid on
            plot(data.NASC,'Color','#77AC30','LineWidth',1);
            legend('Processed NASC','Location','best');
            xlabel('GPS distance (m)');            
            ylabel({'NASC'; '(m^2 nmi^-^2)'});
            title(strcat(ttlenew,' kHz:',' NASC ({\its_v} integrated between 0�1200 m)'))
            p = get(0,'ScreenSize');
            set(gcf,'Position',[50 50 p(3)*0.75 p(4)*0.25])
            zoom(gcf, 'reset');
            if max(data.NASC) > 0
                ylim([0, max(data.NASC)]);
            end
            xlim([1 length(data.NASC)])
        else % multi-frequency
            figure;            
            p = get(0,'ScreenSize'); % Set figure size    
            set(gcf,'Position',[50 50 p(3)*0.75 p(4)*0.60])
            for n = 1: length(channel)
                chann_n = channel(n);
                subplot(length(channel),1,chann_n)
                plot(data.NASC(:,:,chann_n),'Color','#77AC30','LineWidth',1);
                box on; grid on
                if n == max(length(channel)) % keep legend for last panel only
                    xlabel('GPS distance (m)');
                    legend('Processed NASC','Location','best');
                end          
                ylabel({'NASC'; '(m^2 nmi^-^2)'});
                idx = strfind(data.channels{chann_n},'k');
                ttlenew_MF = data.channels{chann_n}(1:idx-1);
                title(strcat(ttlenew_MF,' kHz:',' NASC ({\its_v} integrated between 0�1200 m)'))
                if max(data.NASC(:,:,chann_n)) > 0
                    ylim([0, max(data.NASC(:,:,chann_n))]);
                end
                xlim([1 length(data.NASC(:,:,chann_n))])
            end            
        end

%% Plot background noise per interval

% TER 14/11/16. Modified by Haris on 05 February 2019 to plot as a single figure for all channels 

        if isfield(data, 'background_noise')
            figure;
            plot(data.time, data.background_noise','.','MarkerSize',10);        
            title('Background noise level', 'Interpreter', 'none')
            xlabel('Time (UTC)')
            ylabel({'Background noise';'dB re 1 W'})
            datetick('x',19)
            p = get(0,'ScreenSize');
            set(gcf,'Position',[50 50 p(3)*0.75 p(4)*0.25])
            xlim([min(data.time) max(data.time)])
            legend(data.channels,'Orientation','horizontal','Location','best')
            grid on
        end

%% Plot motion correction factor, box plot or line plot

% Haris 15/06/2019

        if exist('mot')
            
            depth_bin = floor(depth./100)*100;
            
            if length(channel) == 1 % & ~all(isnan(mot)) % single frequency, uncomment ~all(isnan(mot)) if plot is not needed
                if license('test','statistics_toolbox') % try box plot
                    figure;                    
                    boxplot(mot', depth_bin, 'orientation','horizontal');
                    xlabel('Correction (%)')
                    ylabel('Depth (m)')
                    title({strcat(ttlenew,' kHz'); 'Motion correction factor'})
                    set(gca,'YDir','reverse')
                    box on; grid on
                else % if box plot is not available
                    warning('No box plot for motion correction factor')
                    figure;
                    plot(mot,depth);
                    xlabel('Correction (%)')
                    ylabel('Depth (m)')
                    title({strcat(ttlenew,' kHz'); 'Motion correction factor'})
                    set(gca,'YDir','reverse')
                    box on; grid on
                end
            end
            
            if length(channel) > 1 % & ~all(isnan(mot)) % multi frequency, uncomment ~all(isnan(mot)) if plot is not needed
                if license('test','statistics_toolbox') % try box plot
                    figure;
                    p = get(0,'ScreenSize'); % Set figure size
                    set(gcf,'Position',[p(3)/3 p(4)/3 p(3)*0.4 p(4)*0.5])
                    for m = 1: length(channel)
                        chann_m = channel(m);
                        subplot(1,length(channel),chann_m)
                        boxplot(data.motion_correction_factor(:,:,chann_m)', depth_bin, 'orientation','horizontal');
                        xlabel('Correction (%)')
                        if m == 1
                            ylabel('Depth (m)')
                        end
                        idx = strfind(data.channels{chann_m},'k');
                        ttlenew_MF = data.channels{chann_m}(1:idx-1);
                        title({strcat(ttlenew_MF,' kHz'); 'Motion correction factor'})
                        set(gca,'YDir','reverse')
                        hold on; box on; grid on
                    end  
                else % if box plot is not available
                    warning('No box plot for motion correction factor')
                    figure;
                    p = get(0,'ScreenSize'); % Set figure size
                    set(gcf,'Position',[p(3)/3 p(4)/3 p(3)*0.4 p(4)*0.5])
                    for m = 1: length(channel)
                        chann_m = channel(m);
                        subplot(1,length(channel),chann_m)
                        plot(data.motion_correction_factor(:,:,chann_m), depth);
                        xlabel('Correction (%)')
                        if m == 1
                            ylabel('Depth (m)')
                        end                        
                        idx = strfind(data.channels{chann_m},'k');
                        ttlenew_MF = data.channels{chann_m}(1:idx-1);
                        title({strcat(ttlenew_MF,' kHz'); 'Motion correction factor'})
                        set(gca,'YDir','reverse')
                        hold on; box on; grid on
                    end     
                end
            end
        end
        
%% Plot summary layer metrics

% Haris modified- 22 December 2018. Now plotting with time and modified
% condition. Updated on 30 April 2019.

        if isfield(data, 'lower_mesopelagic') && isfield(data, 'day')
            
            figure
            p = get(0,'ScreenSize'); % Set figure size
            set(gcf,'Position',[50 50 p(3)*0.75 p(4)*0.6])
            try % yyaxis right option is introduced in R2016a
                subplot(3,1,1)
                plot(data.time,data.epipelagic','LineWidth',1)                
                datetick('x',19)
                ylabel({'Mean {\itS_v}'; '(dB re 1 m^2 m^-^3)'})
                title('Epipelagic layer (20-200 m)')
                hold on
                
                yyaxis right
                b2 = plot(data.time,data.day,'LineWidth',1);
                datetick('x',19)                
                ylabel('Diurnal sun cycle')
                legend(b2,'1-Day o 2-Sunset+/-1 hr o 3-Sunrise+/-1 hr o 4-Night','Location','best')
                grid on; box on
                xlim([min(data.time) max(data.time)])
                ylim([0 5])
            catch % color will not match with rest of the subplots
                warning('Try using Matlab version R2016a or later for better display of summary metrics plot')
                subplot(3,1,1)
                [hAx,hLine1,hLine2] = plotyy(data.time,data.epipelagic',data.time,data.day);
                datetick('x',19)                
                xlim(hAx(1),[min(data.time) max(data.time)]) % should be same limit
                xlim(hAx(2),[min(data.time) max(data.time)]) % should be same limit
                ylabel(hAx(1),{'Mean {\itS_v}'; '(dB re 1 m^2 m^-^3)'}) % left y-axis
                ylabel(hAx(2),'Diurnal sun cycle') % right y-axis
                legend(hLine2,'1-Day o 2-Sunset+/-1 hr o 3-Sunrise+/-1 hr o 4-Night','Location','best')
                grid on; box on
            end
                                  
            subplot(3,1,2)
            plot(data.time,data.upper_mesopelagic','LineWidth',1)            
            datetick('x',19)
            ylabel({'Mean {\itS_v}'; '(dB re 1 m^2 m^-^3)'})
            title('Upper mesopelagic layer (200-400 m)')
            grid on; box on
            xlim([min(data.time) max(data.time)])
            
            subplot(3,1,3)
            plot(data.time,data.lower_mesopelagic','LineWidth',1)
            legend(data.channels,'Orientation','horizontal','Location','best')         
            xlabel('Time (UTC)')
            datetick('x',19)
            ylabel({'Mean {\itS_v}'; '(dB re 1 m^2 m^-^3)'})
            title('Lower mesopelagic layer (400-800 m)')
            grid on; box on
            xlim([min(data.time) max(data.time)])
        end
        
% Haris- same plots with distance - only for checking purpose and referencing to EV files
        if isfield(data, 'lower_mesopelagic')
            figure
            p = get(0,'ScreenSize'); % Set figure size
            set(gcf,'Position',[50 50 p(3)*0.75 p(4)*0.6])
            subplot(3,1,1)
            plot(data.epipelagic','LineWidth',1)            
            ylabel({'Mean {\itS_v}'; '(dB re 1 m^2 m^-^3)'})
            title('Epipelagic layer (20-200 m)')
            xlim([1 length(data.epipelagic)])
            hold on
            grid on; box on
            
            subplot(3,1,2)
            plot(data.upper_mesopelagic','LineWidth',1)            
            ylabel({'Mean {\itS_v}'; '(dB re 1 m^2 m^-^3)'})
            xlim([1 length(data.upper_mesopelagic)])
            title('Upper mesopelagic layer (200-400 m)')
            grid on; box on
            
            subplot(3,1,3)
            plot(data.lower_mesopelagic','LineWidth',1)
            legend(data.channels,'Orientation','horizontal','Location','best')         
            xlabel('GPS distance (m)');
            ylabel({'Mean {\itS_v}'; '(dB re 1 m^2 m^-^3)'})
            xlim([1 length(data.lower_mesopelagic)])
            title('Lower mesopelagic layer (400-800 m)')
            grid on; box on
        end

%% Plot voyage track

% Haris - 20 June 2018. Plot voyage track on globe without using mapping toolbox
% based on: https://au.mathworks.com/matlabcentral/answers/350195-how-can-you-plot-lines-of-latitude-and-longitude-on-a-globe-without-using-the-mapping-toolbox

        figure % Plot voyage track on globe 
        p = get(0,'ScreenSize'); % Set figure size
        set(gcf,'Position',[p(3)/3 p(4)/3 p(3)*0.54 p(4)*0.5])
                
        R = 6371; % earth radius in km
        latspacing = 10;
        lonspacing = 20;

        % lines of longitude:
        [lon1,lat1] = meshgrid(-180:lonspacing:180,linspace(-90,90,300));
        [x1,y1,z1] = sph2cart(lon1*pi/180,lat1*pi/180,R);
        subplot(1,2,1)
        plot3(x1,y1,z1,'-','color',0.8*[1 1 1])
        hold on

        % lines of latitude:
        [lat2,lon2] = meshgrid(-90:latspacing:90,linspace(-180,180,300));
        [x2,y2,z2] = sph2cart(lon2*pi/180,lat2*pi/180,R);
        plot3(x2,y2,z2,'-','color',0.8*[1 1 1])
        axis equal tight off
            
        [X,Y,Z] = sphere(100);
        surf(X*R*.99,Y*R*.99,Z*R*.99,'facecolor','w','edgecolor','none')
        
        % Coastline data is predefined to avoid dependency
        coastlat = [-83.830002,-84.330002,-84.500000,-84.669998,-84.919998,-85.419998,-85.419998,-85.580002,-85.330002,-84.830002,-84.500000,-84,-83.500000,-83,-82.500000,-82,-81.500000,-81.169998,-81,-80.919998,-80.669998,-80.330002,-80,-79.669998,-79.250000,-78.830002,-78.747818,-78.665421,-78.582809,-78.500000,-78.480568,-78.460754,-78.440567,-78.419998,-78.500000,-78.169998,-78.169998,-78.080002,-77.830002,-77.500000,-77.169998,-77,-77.169998,-77.580002,-77.830002,-77.669998,-77.250000,-76.750000,-76.330002,-75.919998,-75.830002,-75.580002,-75.750000,-75.419998,-75.250000,-75,-74.750000,-74.750000,-75,-75.419998,-75.750000,-76,-76,-75.669998,-75.169998,-74.669998,-74.330002,-74.330002,-73.830002,-73.250000,-73.250000,-73.750000,-74,-73.580002,-73.603729,-73.626648,-73.648735,-73.669998,-73.671219,-73.671623,-73.671219,-73.669998,-73.710052,-73.750069,-73.790054,-73.830002,-73.915771,-74.001038,-74.085785,-74.169998,-74.294998,-74.419998,-74.544998,-74.669998,-74.795731,-74.920982,-75.045746,-75.169998,-75.192856,-75.213806,-75.232864,-75.250000,-75,-74.500000,-74.375015,-74.250015,-74.125015,-74,-73.917694,-73.835258,-73.752693,-73.669998,-74,-74.500000,-75,-75.169998,-74.669998,-74.500000,-74,-74,-74.330002,-74.669998,-75.080002,-75.080002,-74.919998,-74.919998,-74.580002,-74.580002,-74.750000,-75,-74.750000,-74.330002,-74,-73.750000,-73.500000,-73.580002,-73.419998,-73.080002,-73.250000,-72.750000,-72.669998,-73,-72.919998,-73.330002,-73.080002,-73.419998,-73.750000,-73.750000,-73.419998,-73.080002,-72.919998,-72.500000,-72.169998,-72.108353,-72.046135,-71.983345,-71.919998,-71.878166,-71.835884,-71.793159,-71.750000,-72,-72,-71.830002,-72.080002,-72.419998,-72.580002,-72.750000,-72.919998,-72.919998,-72.919998,-73.080002,-72.919998,-72.830002,-72.919998,-73,-73.250000,-72.830002,-72.419998,-72.580002,-72.830002,-73,-73.500000,-73.419998,-73.330002,-73.169998,-73.080002,-72.830002,-72.330002,-71.830002,-71.500000,-70.919998,-70.419998,-70.419998,-70,-69.419998,-69.419998,-69.080002,-68.830002,-68.500000,-68.080002,-67.750000,-67.419998,-67.750000,-67.750000,-67.330002,-66.919998,-66.669998,-67.080002,-67,-67.330002,-66.830002,-66.580002,-66.250000,-65.919998,-65.500000,-65.080002,-65.169998,-64.750000,-64.669998,-64.250000,-64,-63.830002,-63.580002,-63.580002,-63.330002,-63.250000,-63.580002,-63.580002,-63.642956,-63.705612,-63.767960,-63.830002,-63.830547,-63.830730,-63.830547,-63.830002,-64.419998,-64.330002,-64,-64.500000,-64.330002,-64.669998,-65,-65.419998,-65.750000,-66.080002,-66.500000,-66.250000,-66.500000,-66.919998,-66.919998,-67.330002,-67.830002,-67.892754,-67.955338,-68.017754,-68.080002,-68.142639,-68.205185,-68.267639,-68.330002,-68.435135,-68.540184,-68.645142,-68.750000,-68.750000,-69.080002,-69.669998,-70.169998,-70.169998,-70.580002,-70.919998,-71.169998,-71.580002,-72,-72.330002,-72.669998,-72.753128,-72.835838,-72.918137,-73,-73.082550,-73.165070,-73.247551,-73.330002,-73.419998,-73.750000,-74.330002,-74.669998,-75.080002,-75.169998,-75.669998,-76.080002,-76.500000,-77,-77.169998,-77.080002,-77.080002,-77.250000,-77.580002,-77.919998,-78.250000,-78.500000,-78.750000,-78.830002,-78.830002,-78.830002,-78.750000,-78.330002,-77.830002,-77.500000,-77.169998,-76.830002,-76.500000,-76.080002,-75.669998,-75.330002,-74.750000,-74.419998,-74.080002,-73.750000,-73.419998,-73.080002,-72.919998,-72.830002,-72.580002,-72.250000,-71.919998,-71.669998,-71.330002,-71.250000,-71.580002,-71.250000,-71,-71.169998,-71.419998,-71.830002,-71.830002,-71.790665,-71.750885,-71.710663,-71.669998,-71.607559,-71.545074,-71.482559,-71.419998,-71.335060,-71.250076,-71.165054,-71.080002,-71.017555,-70.955078,-70.892555,-70.830002,-70.810356,-70.790482,-70.770355,-70.750000,-70.750000,-71,-71.330002,-71.330002,-71.250000,-70.669998,-70.419998,-70.250000,-70.419998,-70.669998,-71,-71.250000,-71.500000,-71.250000,-70.919998,-70.580002,-70.330002,-70.330002,-70.080002,-70.080002,-70.169998,-70.080002,-70.080002,-70.169998,-70.169998,-70.169998,-70.169998,-70.169998,-70.330002,-70.419998,-70.580002,-70.419998,-70.169998,-70.169998,-69.919998,-69.830002,-69.580002,-69.500000,-69.500000,-69,-68.669998,-68.580002,-68.919998,-69.330002,-69.500000,-69.580002,-70.080002,-69.669998,-69.500000,-69.169998,-68.830002,-68.500000,-68.169998,-67.830002,-67.750000,-67.750000,-67.750000,-67.580002,-67.669998,-67.419998,-67.419998,-67.830002,-67.580002,-67,-66.500000,-66.250000,-65.919998,-65.830002,-65.919998,-66.250000,-66.419998,-66.669998,-66.750000,-66.919998,-67,-67.169998,-67.500000,-67.330002,-67.580002,-67.669998,-67.500000,-67.580002,-67.750000,-67.830002,-67.830002,-67.669998,-68.169998,-68.169998,-68.580002,-69,-69.169998,-69.580002,-70.080002,-70.500000,-70.419998,-70.080002,-69.750000,-69.580002,-69.669998,-69.830002,-69.500000,-69.169998,-69.080002,-68.500000,-68.250000,-68,-67.830002,-67.330002,-67.169998,-67,-66.830002,-66.669998,-66.750000,-66.750000,-66.669998,-66.500000,-66.580002,-66.580002,-66.580002,-66.500000,-66.669998,-66.500000,-66.669998,-66.500000,-66.580002,-66.419998,-66.419998,-66.080002,-65.830002,-65.919998,-66.080002,-66.250000,-66.500000,-66.580002,-66.830002,-66.580002,-66.669998,-66.419998,-66.080002,-65.919998,-65.830002,-65.750000,-66,-66.330002,-66.500000,-66.750000,-66.830002,-66.830002,-66.669998,-66.669998,-66.419998,-66.750000,-66.750000,-66.500000,-66.580002,-66.250000,-66.250000,-66.500000,-66.919998,-67,-67.169998,-66.919998,-66.330002,-66.080002,-66.169998,-66.080002,-66.169998,-66.080002,-66.330002,-66.330002,-66.500000,-66.580002,-66.669998,-66.750000,-67,-66.830002,-67,-67.500000,-67.580002,-67.500000,-67.500000,-67.830002,-68.250000,-68.419998,-68.250000,-68.500000,-68.330002,-68.669998,-68.580002,-68.580002,-69.080002,-69.330002,-69,-69.080002,-69.250000,-69.500000,-69.669998,-70.080002,-70.500000,-70.830002,-70.580002,-70.169998,-70.080002,-70.580002,-70.580002,-70.500000,-70.830002,-71.169998,-71.500000,-71.169998,-71.750000,-71.750000,-72,-72.500000,-72.830002,-73.169998,-73.250000,-73.669998,-74.080002,-74.169998,-74.500000,-74.830002,-75.169998,-75.669998,-76.080002,-76.500000,-76.919998,-77.330002,-77.750000,-78,-78.105576,-78.210770,-78.315582,-78.419998,-78.441284,-78.461708,-78.481285,-78.500000,-78.750000,-79.169998,-79.669998,-80,-80.500000,-81,-81.500000,-81.919998,-82.419998,-82.830002,-82.830002,-83.250000,-83.500000,-83.500000,-83.830002,NaN,-77.580002,-77.080002,-77.330002,-77.419998,-77.669998,-77.580002,NaN,-78.750000,-78.750000,-79.080002,-79.500000,-79.919998,-80.250000,-79.830002,-79.330002,-79.080002,-78.750000,NaN,-76.580002,-76.169998,-76.232872,-76.295502,-76.357880,-76.419998,-76.503151,-76.585869,-76.668159,-76.750000,-76.580002,NaN,-71.080002,-71.080002,-71,-70.919998,-70.830002,-70.580002,-70.080002,-69.580002,-69.080002,-68.919998,-68.830002,-69.419998,-70,-70.500000,-71,-71.500000,-71.919998,-72.330002,-72.580002,-72.669998,-72.580002,-72.250000,-72.169998,-71.830002,-71.669998,-71.330002,-71.080002,NaN,-70.580002,-70.250000,-70,-69.750000,-69.919998,-70.250000,-70.500000,-70.580002,-70.580002,NaN,-64.798996,-64.763367,-64.691940,-64.563293,-64.441841,-64.334740,-64.562935,-64.755997,-64.798996,NaN,-64.541351,-64.256035,-64.099403,-64.085098,-64.248779,-64.541351,NaN,-63.250000,-63,-63.105453,-63.210606,-63.315456,-63.419998,-63.440655,-63.460873,-63.480656,-63.500000,-63.250000,NaN,-62.232025,-62.126762,-62.007484,-61.957989,-61.985928,-62.077095,-62.161507,-62.232025,NaN,-62.788345,-62.689720,-62.668785,-62.506897,-62.457500,-62.478474,-62.569904,-62.675510,-62.788345,NaN,-60.630001,-60.330002,-60.423199,-60.515934,-60.608204,-60.700001,-60.683739,-60.666649,-60.648735,-60.630001,NaN,0,0.67000002,1,1.2500000,1.6700000,1.7500000,2.1700001,2.6700001,2.6700001,3.2500000,3.6700001,4,4.5000000,5,5.5000000,6.1700001,6.5799999,7,7.4200001,8,8.3299999,8.3299999,8.7500000,9,9,8.5799999,8.3299999,8.3299999,8.1700001,7.8299999,7.7475381,7.6650510,7.5825381,7.5000000,7.4375525,7.3750696,7.3125520,7.2500000,7.1700001,7.7500000,7.7500000,8.0799999,8.2500000,8.3299999,8.1700001,8.4200001,8.5000000,9,9.3299999,9.6700001,10,9.6700001,9.8299999,9.9200001,10.330000,10.750000,11.170000,11.500000,11.830000,12.250000,12.580000,12.685040,12.790054,12.895041,13,13.000041,13.000055,13.000041,13,13.105042,13.210056,13.315042,13.420000,13.420000,13.170000,13.170000,13.170000,13.420000,13.420000,13.670000,13.920000,13.920000,14.080000,14.330000,14.670000,15,15.420000,15.670000,15.920000,16.080000,16.170000,16.170000,15.920000,15.670000,15.830000,16,16.080000,16.330000,16.580000,16.670000,16.920000,17.080000,17.250000,17.670000,17.670000,18,18,18.080000,18.330000,18.750000,19.080000,19.330000,19.830000,20.330000,20.580000,20.830000,21.170000,21.500000,21.750000,22.420000,22.750000,23.170000,23.500000,24,24.330000,24.670000,25.250000,25.500000,25.750000,26,26.330000,26.670000,26.670000,27,27.420000,27.420000,27.920000,28,28.500000,29,29.500000,29.920000,30.250000,30.750000,31.170000,31.330000,31.580000,31.500000,31.750000,31.420000,31,30.580000,30.170000,29.830000,29.580000,29.170000,28.750000,28.330000,27.830000,27.500000,27,26.500000,26,25.500000,25.170000,24.830000,24.830000,24.670000,24.250000,24.250000,23.750000,23.330000,22.830000,23.500000,23.830000,24.250000,24.580000,24.830000,25.170000,25.670000,26.170000,26.420000,26.750000,26.750000,27,27.170000,27.500000,27.830000,27.750000,28,28.420000,28.750000,29.080000,29.500000,29.670000,30.250000,30.330000,30.330000,30.750000,31,31.250000,31.580000,32,32.500000,33,33.419998,33.750000,33.750000,34.080002,34.080002,34.250000,34.419998,34.580002,35.080002,35.580002,36,36.330002,36.580002,37,37,37.330002,37.750000,37.500000,37.919998,38.080002,38.169998,37.919998,38,38,38.330002,38.580002,38.919998,39.330002,39.669998,40,40.250000,40.500000,41,41.500000,42,42.330002,42.830002,43.419998,44,44.500000,45,45.419998,45.830002,46.169998,46.169998,46.330002,46.669998,47,47.500000,47.919998,48.169998,48.419998,48.169998,48.169998,48.169998,47.919998,47.500000,47.669998,47.500000,48,48.105087,48.210117,48.315090,48.419998,48.460022,48.500027,48.540020,48.580002,48.685089,48.790119,48.895088,49,49.250000,49.750000,49.500000,49.750000,50.080002,50.419998,50.669998,50.830002,51.169998,51.500000,51.830002,52.330002,52.580002,53.169998,53.419998,53.919998,54.169998,54.419998,54.919998,54.750000,55,55.330002,55.330002,55.750000,56.080002,56.080002,56.250000,55.830002,55.250000,54.669998,55.080002,55.330002,55.580002,55.919998,56.330002,56.250000,56.750000,57.080002,56.919998,57.250000,57.580002,57.250000,57,57.419998,57.919998,58.250000,58.669998,58.250000,58.250000,57.919998,57.419998,56.830002,56.169998,56.169998,56.750000,57.250000,57.669998,58.169998,58.419998,58.750000,59.169998,59.419998,59.919998,59.669998,59.750000,60,60,60,60.250000,60.580002,60.830002,60.830002,61,60.419998,59.919998,59.919998,59.580002,59.250000,59.169998,59.500000,59.669998,60.169998,60.750000,60.919998,60.919998,61.002674,61.085232,61.167675,61.250000,61.250389,61.250519,61.250389,61.250000,60.919998,60.580002,60.080002,59.669998,59.419998,59.080002,58.919998,58.500000,58.169998,57.830002,57.419998,57,56.669998,56.419998,56,55.830002,55.580002,55.419998,55.169998,55,54.669998,54.330002,54.580002,55,55.250000,55.669998,55.919998,56,56,56.500000,56.830002,57.250000,57.580002,58.169998,58.750000,58.669998,58.750000,58.419998,58.919998,58.919998,58.750000,59.169998,59.500000,60.080002,59.669998,59.669998,60.080002,60.580002,61.080002,61.500000,62.169998,62.669998,63,63.250000,63,63.419998,63.500000,64,64.419998,64.419998,64.830002,64.669998,64.419998,64.580002,64.500000,64.669998,65,65.330002,65.419998,65.460205,65.500275,65.540207,65.580002,65.685608,65.790817,65.895615,66,66.250000,66.500000,66.500000,66.080002,66.080002,66.419998,66.830002,67.169998,67.669998,67.980003,68.330002,68.830002,68.919998,69.080002,69.449997,69.919998,70.330002,70.419998,70.830002,70.830002,70.870003,71.330002,71.129997,70.870003,70.870003,70.480003,70.480003,70.470001,70.220001,70.220001,70,70.080002,70.080002,69.830002,69.620003,69.580002,69.320000,69,68.750000,69.169998,69.500000,69.580002,69.379997,69.669998,69.980003,70.250000,69.830002,70,70.580002,70.080002,70.080002,69.580002,69.419998,70,69.419998,69.370003,69.830002,69.830002,69.470001,69.220001,69,68.970001,68.720001,68.300003,68.169998,67.830002,67.830002,67.669998,67.830002,68,67.750000,67.580002,68,68.250000,68.580002,68.750000,68.900002,68.349998,68.029999,67.750000,67.580002,67.580002,67.669998,68.250000,68.580002,69,69.330002,69.830002,69.330002,68.750000,68.379997,67.820000,67.500000,67.980003,68,68.500000,69,69.419998,69.830002,70.419998,70.970001,71.500000,71.750000,72.250000,72.669998,73.169998,73.580002,74,74.169998,74.019997,73.830002,73.580002,73.580002,73.169998,72.750000,72.750000,72.580002,72.250000,71.919998,71.419998,71,70.669998,70.169998,69.750000,69.500000,69.080002,68.580002,69.250000,68.750000,68.330002,67.830002,67.250000,67.419998,67.830002,68.169998,68.750000,69.330002,69.830002,69.830002,69.669998,69.330002,69.199997,68.580002,68.580002,68.330002,67.830002,67.580002,67,66.580002,66.169998,66.330002,66.580002,66.500000,66.169998,65.500000,65,64.500000,64,64,63.419998,62.919998,62.750000,62.580002,62.080002,61.919998,61.500000,61,60.580002,60.169998,59.580002,59.080002,58.669998,58.750000,58.669998,58.669998,58.080002,57.669998,57.250000,56.919998,57.080002,57.250000,56.919998,56.750000,56.419998,56.315254,56.210339,56.105255,56,55.957840,55.915455,55.872841,55.830002,55.669998,55.250000,55.250000,55.250000,55,54.250000,53.830002,53.419998,52.919998,52.500000,52.080002,51.750000,51.330002,51,51.330002,51.669998,52.169998,52.669998,53.169998,53.169998,53.750000,54.169998,54.580002,54.830002,55.169998,55.580002,56,56.669998,57.250000,57.669998,58.250000,58.419998,58.750000,59.080002,59.169998,59.580002,60,60.500000,60.750000,61.169998,61.272541,61.375057,61.477543,61.580002,61.642731,61.705307,61.767731,61.830002,62.250000,62.500000,62.419998,62.250000,62.250000,62.419998,62.169998,61.830002,61.830002,61.580002,61.250000,61,61,60.919998,60.500000,60.080002,59.580002,59.250000,58.830002,58.750000,58.169998,58.419998,58.750000,59,59.419998,59.750000,60,60.330002,60,59.500000,59,58.500000,58,57.669998,57.330002,57.080002,56.750000,56.250000,55.919998,55.919998,55.669998,55.250000,55.169998,54.830002,54.750000,54.687695,54.625256,54.562695,54.500000,54.418034,54.335712,54.253033,54.169998,54.148277,54.126038,54.103275,54.080002,53.669998,53.669998,53.169998,52.750000,52.080002,51.830002,51.500000,51.419998,51.169998,50.830002,50.500000,50.169998,50.169998,50.080002,50.250000,50.250000,50.250000,50.330002,50.250000,50.250000,50.250000,50.080002,50.080002,49.750000,49.330002,49.330002,48.919998,48.580002,48.169998,47.830002,47.500000,47.169998,46.830002,47,47.330002,47.669998,48.080002,48.419998,48.669998,48.830002,49.080002,49.169998,49.250000,49.080002,48.830002,48.500000,48.250000,48.080002,48.080002,47.580002,47.750000,47.330002,46.750000,46.750000,46.250000,46.080002,45.750000,45.669998,45.830002,45.750000,46.169998,46.580002,47,46.830002,46.330002,46.247868,46.165489,46.082867,46,45.917786,45.835381,45.752785,45.669998,45.500000,45.169998,45,44.750000,44.500000,44.500000,44.169998,43.830002,43.500000,43.750000,44.169998,44.580002,44.919998,45.080002,45.419998,45.330002,45.669998,45.669998,45.330002,45.169998,45.169998,44.830002,44.580002,44.419998,44.250000,44.419998,44,43.830002,43.669998,43.500000,43.169998,42.830002,42.580002,42.330002,42.169998,41.750000,41.790001,42.020000,41.669998,41.500000,41.669998,41.500000,41.750000,41.419998,41.250000,41.250000,41.250000,41.080002,41.080002,40.830002,40.500000,40.330002,39.830002,39.330002,39,39.330002,39.500000,39,38.855141,38.710186,38.565140,38.419998,38.357552,38.295067,38.232552,38.169998,37.750000,37.250000,37.169998,37.669998,38,38,38.250000,38.419998,38.830002,39.169998,39.500000,39.330002,39,38.500000,38.169998,38.250000,37.919998,37.500000,37.169998,37.169998,36.830002,36.500000,36.110001,35.849998,36.209999,36.169998,36.080002,35.919998,35.919998,35.919998,35.580002,35.330002,35.330002,35,35,34.750000,34.669998,34.330002,34,33.919998,33.669998,33.330002,33,32.669998,32.419998,32,31.500000,31,30.500000,30,30,29.500000,29,28.500000,28.170000,27.580000,27,26.420000,25.830000,25.330000,25.170000,25.080000,25.500000,25.830000,26.330000,26.750000,27.080000,27.165005,27.250006,27.335005,27.420000,27.545017,27.670023,27.795017,27.920000,27.897573,27.875097,27.852573,27.830000,28.170000,28.580000,29.080000,29.170000,29.750000,30.080000,30,29.750000,29.670000,30.080000,30.250000,30.250000,30.500000,30.420000,30.330000,30.330000,30.670000,30.420000,30.500000,30.500000,30.250000,30.500000,30.080000,30,30.080000,30.080000,29.830000,29.670000,29.500000,29.170000,29,29.250000,29.330000,29.170000,29.080000,29.170000,29.500000,29.830000,29.580000,29.670000,29.830000,29.750000,29.750000,29.670000,29.420000,29.830000,29.790077,29.750103,29.710077,29.670000,29.565044,29.460058,29.355043,29.250000,29.187580,29.125107,29.062580,29,28.750000,28.670000,28.330000,28,27.670000,27.170000,26.670000,26.170000,25.750000,25.330000,24.830000,24.330000,23.830000,23.330000,22.830000,22.420000,21.920000,21.580000,21.250000,20.830000,20.500000,20.170000,19.670000,19.250000,19.250000,18.830000,18.670000,18.500000,18.170000,18.170000,18.330000,18.420000,18.670000,18.580000,18.420000,18.580000,18.830000,19.080000,19.250000,19.670000,20,20.420000,21,21.170000,21.250000,21.330000,21.500000,21.580000,21.500000,21.500000,21.330000,20.920000,20.500000,20,19.875004,19.750004,19.625004,19.500000,19.500000,19.500000,19.500000,19.500000,19.375004,19.250004,19.125004,19,18.420000,17.920000,18.330000,17.500000,17,16.330000,16,15.830000,15.580000,15.830000,15.670000,15.750000,15.920000,15.830000,15.920000,15.830000,15.750000,15.330000,15.170000,15,14.250000,13.830000,13.250000,12.750000,12.170000,11.670000,11.250000,10.830000,10.420000,10.420000,10,9.6700001,9.4200001,9,9,8.7500000,8.9200001,9.0799999,9.2500000,9.5799999,9.5799999,9.4200001,9.3299999,9,8.6700001,8.3299999,7.8299999,8.5799999,9,9.4200001,9.5000000,10,10.500000,10.830000,11,10.920000,11.250000,11.170000,11.420000,11.670000,11.670000,11.830000,12.170000,12.420000,12.330000,12.080000,11.670000,11.500000,11,10.580000,10.250000,9.7500000,9.4200001,9,9.1700001,9.7500000,10.330000,10.920000,11.080000,11.250000,11.500000,11.920000,12.170000,11.500000,11.500000,11.420000,11.170000,10.750000,10.420000,10.500000,10.500000,10.500000,10.580000,10.580000,10.330000,10.170000,10.080000,10.250000,10.670000,10.670000,10.670000,10.670100,10.670134,10.670100,10.670000,10.627704,10.585272,10.542704,10.500000,10.170000,9.7500000,9.8299999,9.6700001,9.5000000,9,8.4200001,8.5799999,8.2500000,7.9200001,7.5799999,7.1700001,6.7500000,6.8299999,6.5000000,6.2500000,5.9200001,5.8299999,5.8299999,5.8299999,5.9200001,5.9200001,5.8299999,5.6700001,5.5799999,5.4200001,5.1700001,4.8299999,4.5000000,4.2500000,3.7500000,3.1700001,2.5000000,1.8300000,1.7500000,1,0.50000000,0.17000000,-0.17000000,-0.67000002,-1.2500000,-1,-1.6700000,-1,-0.41999999,-0.17000000,-0.25000000,-0.17000000,-0.33000001,-1,-1,-1.4200000,-1.5800000,-0.82999998,-0.67000002,-0.67000002,-1,-1.1700000,-1.3300000,-1.6700000,-1.5000000,-1.9200000,-2.3299999,-2.8299999,-2.6700001,-2.4200001,-2.5000000,-2.7500000,-2.7500000,-3,-3,-2.8299999,-2.8299999,-3.1700001,-3.5000000,-3.8299999,-4.1700001,-4.5000000,-4.7500000,-5.0799999,-5.1700001,-5.1700001,-5.0799999,-5.2500000,-5.8299999,-6.4200001,-7,-7.5000000,-8.1700001,-8.6700001,-9.1700001,-9.5799999,-10,-10.420000,-10.750000,-11,-11.500000,-12,-12.580000,-13,-13.330000,-14,-14.500000,-15,-15.500000,-16,-16.580000,-17.170000,-17.670000,-18,-18.500000,-19,-19,-19.500000,-20,-20.500000,-21,-21.500000,-22,-22.250000,-22.500000,-22.920000,-22.920000,-23,-23,-22.920000,-23,-23.330000,-23.330000,-23.830000,-23.670000,-24,-24.170000,-24.580000,-25,-25.420000,-25.830000,-26.330000,-27,-27.500000,-28,-28.500000,-28.670000,-28.670000,-29,-29.500000,-30,-30.500000,-31,-31.500000,-31.830000,-32.169998,-32.500000,-33,-33.500000,-33.830002,-34.169998,-34.500000,-34.750000,-34.830002,-34.750000,-34.830002,-34.669998,-34.419998,-34.419998,-34,-34.330002,-34.669998,-35,-35.330002,-35.830002,-36.250000,-36.330002,-36.830002,-36.830002,-37.330002,-37.750000,-38.169998,-38.419998,-38.580002,-38.750000,-38.830002,-38.919998,-39,-39,-38.750000,-39.169998,-39.500000,-39.830002,-40.330002,-40.580002,-40.919998,-41.169998,-41.169998,-41,-40.750000,-40.812595,-40.875126,-40.937595,-41,-41.125023,-41.250031,-41.375023,-41.500000,-42.080002,-42.330002,-42.080002,-42.580002,-42.830002,-42.830002,-42.500000,-42.500000,-42.830002,-43,-43.330002,-43.669998,-44,-44.500000,-44.669998,-45,-45,-45.250000,-45.500000,-46,-46.500000,-46.830002,-47.169998,-47.169998,-47.500000,-48,-48.330002,-48.669998,-49,-49.500000,-50,-50.169998,-50.500000,-51,-51.419998,-51.830002,-52.330002,-52.250000,-52.250000,-52.250000,-52.500000,-52.500000,-52.750000,-53.250000,-53.750000,-53.830002,-53.669998,-53.419998,-53.169998,-52.830002,-52.750000,-53.169998,-53.419998,-53.169998,-52.919998,-52.669998,-52.580002,-52.169998,-52.419998,-52.250000,-51.750000,-51.830002,-51.500000,-51,-51.330002,-51.393047,-51.455734,-51.518051,-51.580002,-51.477589,-51.375114,-51.272587,-51.169998,-50.669998,-50.750000,-50.750000,-50.419998,-50,-50.750000,-50.169998,-50.107590,-50.045116,-49.982586,-49.919998,-49.897701,-49.875267,-49.852703,-49.830002,-49.419998,-49.169998,-48.580002,-48.169998,-47.830002,-47.750000,-48.330002,-47.830002,-47.419998,-46.830002,-46.830002,-46.669998,-46.919998,-46.580002,-46.169998,-45.919998,-45.830002,-45.580002,-45.250000,-45,-44.580002,-44.169998,-43.830002,-44.169998,-44.169998,-44.419998,-44.669998,-45,-45.169998,-45.500000,-45,-44.669998,-44.419998,-44.169998,-43.750000,-43.419998,-43,-42.330002,-42.290051,-42.250069,-42.210052,-42.169998,-42.127552,-42.085068,-42.042549,-42,-41.917549,-41.835068,-41.752552,-41.669998,-41.627705,-41.585270,-41.542702,-41.500000,-41.830002,-41.750000,-41.419998,-41,-40.580002,-40,-39.500000,-39,-38.580002,-38.169998,-37.750000,-37.169998,-37.169998,-37.169998,-36.669998,-36.500000,-36,-35.500000,-35,-34.500000,-34,-33.669998,-33.169998,-32.500000,-32.169998,-31.830000,-31.330000,-30.750000,-30.250000,-30,-29.330000,-29,-28.500000,-28,-27.500000,-27,-26.330000,-25.750000,-25.420000,-25,-24.500000,-24,-23.500000,-23,-23,-22.500000,-22,-21.500000,-21,-20.500000,-20,-19.330000,-18.750000,-18.250000,-17.830000,-17.670000,-17.250000,-17,-16.670000,-16.580000,-16.250000,-15.830000,-15.750000,-15.330000,-15,-14.670000,-14.170000,-13.670000,-13,-12.500000,-12.170000,-11.830000,-11.330000,-10.830000,-10.170000,-10.170000,-9.6700001,-9.1700001,-8.6700001,-8.1700001,-7.8299999,-7.2500000,-6.8299999,-6.5000000,-6.2500000,-6,-5.6700001,-5.1700001,-4.6700001,-4.2500000,-3.8299999,-3.5000000,-3.3299999,-2.8299999,-2.5000000,-2.5000000,-3,-2.5000000,-2.3299999,-2.1700001,-1.6700000,-1,-0.82999998,-0.33000001,0,NaN,66.080002,66.129997,66.250000,66,65.750000,65.580002,65,65,65.330002,65.669998,65.330002,64.830002,65.370003,65.820000,65.669998,66.080002,66.419998,66.330002,66.353714,66.376617,66.398712,66.419998,66.482834,66.545448,66.607834,66.669998,66.919998,67.080002,66.750000,66.580002,66.370003,66.080002,NaN,61.169998,60.830002,60.830002,61,60.919998,61.250000,61.419998,61.580002,62.080002,62.330002,62.353298,62.376064,62.398300,62.419998,62.482578,62.545105,62.607578,62.669998,62.670914,62.671219,62.670914,62.669998,62.830002,62.830002,62.669998,62.419998,62.080002,62,62.169998,62.419998,62.419998,62.169998,62.085228,62.000305,61.915226,61.830002,61.810383,61.790512,61.770382,61.750000,61.419998,61.169998,61.169998,NaN,58.669998,58.580002,58.919998,59.080002,59.080002,59.122997,59.165661,59.207996,59.250000,59.292740,59.335323,59.377743,59.419998,59.419998,59.669998,59.669998,59.250000,59,58.669998,NaN,56.330002,56.580002,57,57.419998,57.669998,58.169998,57.750000,57.667580,57.585106,57.502579,57.419998,57.315083,57.210110,57.105080,57,56.917545,56.835064,56.752548,56.669998,56.330002,NaN,53.330002,53,52.500000,52.250000,51.919998,51.919998,51.419998,51.580002,51.169998,50.750000,50.330002,50.500000,51.169998,51.580002,52.169998,52.669998,53.169998,53.669998,53.750000,53.750000,53.330002,NaN,46.669998,46.669998,46.919998,46.500000,46.750000,47,47.419998,47.419998,47.080002,46.750000,46.830002,46.419998,46.419998,46.669998,46.750000,46.500000,46.500206,46.500271,46.500206,46.500000,46.605049,46.710068,46.815052,46.919998,47.330002,47.580002,47.919998,47.919998,48.250000,48.750000,48.750000,49,48.669998,48.419998,48.080002,47.830002,47.830002,47.669998,47.330002,47,46.669998,NaN,44.580002,44.665459,44.750614,44.835461,44.919998,44.815052,44.710068,44.605049,44.500000,44.417503,44.335007,44.252506,44.169998,43.580002,43.169998,42.750000,42.169998,42.045090,41.920116,41.795090,41.669998,41.670143,41.670193,41.670143,41.669998,41.830002,42.169998,42.750000,43.250000,43.669998,44.080002,44.500000,44.919998,45.169998,45.669998,45.670204,45.670273,45.670204,45.669998,45.627644,45.585194,45.542645,45.500000,45.330002,45,44.419998,43.919998,43.580002,43.919998,44.080002,43.580002,43.580002,43.080002,43.330002,43.919998,44.419998,44.830002,45.169998,44.750000,44.500000,44.582588,44.665119,44.747589,44.830002,44.977703,45.125271,45.272705,45.419998,45.919998,46.080002,46.169998,46.169998,46.250000,46.250000,45.919998,45.919998,46,45.919998,45.750000,45.750000,45.419998,45,44.580002,NaN,45.830002,45.830002,45.919998,45.500000,45.669998,45.830002,NaN,41.750000,41.500000,41.500000,41.580002,41.830002,42,42.250000,42.500000,42.830002,42.830002,42.830002,42.580002,42.669998,42.580002,42.250000,42,42,41.750000,NaN,43.250000,43.169998,43.330002,43.330002,43.250000,43.330002,43.500000,44,44.330002,44.169998,43.919998,44,43.919998,43.830002,43.669998,43.250000,NaN,0.079999998,-0.33000001,-0.75000000,-1.0800000,-0.92000002,-0.67000002,-0.41999999,0.079999998,NaN,-41.830002,-42,-42.330002,-42.669998,-43,-43.419998,-43.330002,-42.669998,-42.330002,-41.830002,NaN,-52.580002,-53,-53.330002,-53.669998,-54,-54.250000,-54.500000,-54.669998,-54.669998,-54.919998,-55,-55,-55.250000,-55.250000,-55.669998,-55.419998,-55.500000,-55.330002,-55,-55.169998,-55,-54.669998,-54.669998,-54.419998,-54.419998,-54.080002,-54.080002,-53.830002,-53.580002,-53.330002,-53.250000,-53,-52.750000,-53,-53.250000,-53.580002,-53.830002,-54,-54.169998,-53.669998,-54.169998,-54.190086,-54.210114,-54.230083,-54.250000,-54.125004,-54.000008,-53.875004,-53.750000,-53.687939,-53.625587,-53.562939,-53.500000,-53.330002,-53.500000,-53.330002,-52.830002,-52.830002,-52.580002,-52.669998,-52.580002,NaN,-51.830002,-52,-51.750000,-51.419998,-51.330002,-51.500000,-51.330002,-51.500000,-51.830002,-52,-52.250000,-52.330002,-52.080002,-52,-52.250000,-51.830002,NaN,-54,-54.080002,-54.330002,-54.580002,-54.919998,-54.500000,-54.250000,-54,NaN,10,10.170000,10.580000,10.670000,10.750000,10.250000,10,10,NaN,18.170000,18.330000,18.500000,18.420000,18.330000,18.170000,17.830000,17.830000,17.920000,17.750000,17.830000,18.170000,18.170000,NaN,21.770000,21.980000,21.820000,21.747513,21.675016,21.602512,21.530001,21.505060,21.480082,21.455061,21.430000,21.469999,21.600000,21.770000,NaN,21.830000,22,22.330000,22.580000,22.830000,22.920000,23,23.170000,23.170000,23,23,22.830000,22.670000,22.330000,22.330000,22.170000,21.920000,21.670000,21.500000,21.170000,21.080000,21,20.580000,20.670000,20.580000,20.250000,20.250000,20.080000,20.080000,20,19.830000,19.830000,19.920000,19.920000,19.830000,19.830235,19.830313,19.830235,19.830000,19.892532,19.955044,20.017532,20.080000,20.330000,20.670000,20.670000,21,21.420000,21.580000,21.500000,21.670000,21.750000,22,22,22.080000,22.330000,22.500000,22.580000,22.670000,22.420000,22.170000,22.170000,22.085016,22.000021,21.915016,21.830000,21.830246,21.830328,21.830246,21.830000,NaN,18.330000,18.580000,18.500000,18.330000,18.330000,18.392586,18.455116,18.517588,18.580000,18.685087,18.790117,18.895088,19,19.330000,19.670000,19.670000,19.670000,19.920000,19.920000,19.670000,19.830000,19.830000,19.750000,19.670000,19.330000,19.330000,19.080000,18.920000,18.500000,18.080000,18.420000,18.420000,18.250000,18.170000,18.420000,18.250000,18,17.580000,18.080000,18.170000,18.080000,18.170000,18.170000,18,18.330000,NaN,18,18.500000,18.500000,18.500000,18.250000,18,18,17.920000,18,NaN,16.368876,16.281084,16.458225,16.502964,16.471733,16.367208,16.265434,16.177479,16.236788,16.038425,15.954261,16.068899,16.329487,16.368876,NaN,14.548387,14.855312,14.965632,14.961621,14.780305,14.540425,14.548387,NaN,25.170000,25.170000,24.670000,24.330000,24.247538,24.165051,24.082539,24,23.917517,23.835024,23.752518,23.670000,24.170000,24.580000,24.830000,25.170000,NaN,20.920000,21.170000,21.080000,21.330000,20.920000,20.920000,NaN,26.565067,26.591459,26.800030,26.746765,26.747498,26.603350,26.625160,26.475895,26.565067,NaN,26.887417,26.932390,26.909651,26.553053,26.288774,26.260998,25.878109,25.848993,25.995365,26.119013,26.183361,26.270609,26.437401,26.553743,26.615993,26.852219,26.887417,NaN,25.564178,25.563662,25.489418,25.297565,25.148275,25.049494,24.752029,24.640400,24.746243,24.797119,24.839926,24.919060,25.018141,25.132404,25.256622,25.423887,25.564178,NaN,24.684805,24.631353,24.145220,24.170549,24.126799,24.218735,24.489990,24.516300,24.684805,NaN,23.692522,23.371677,23.162100,23.130779,22.905905,22.856956,23.065800,23.143841,23.354691,23.619373,23.692522,NaN,22.738977,22.561037,22.315899,22.250759,22.316050,22.380600,22.470383,22.560038,22.734215,22.854620,22.696627,22.738977,NaN,40.580002,40.830002,40.919998,41,41.169998,41,40.750000,40.669998,40.580002,NaN,49.830002,49.830002,49.750000,49.580002,49.419998,49.080002,49.080002,49.169998,49.330002,49.580002,49.830002,NaN,46.669998,46.919998,46.580002,46.419998,46.419998,46.500000,46.250000,45.919998,46.169998,46.419998,46.669998,NaN,62.169998,62.580002,62.750000,62.750000,62.669998,62.250000,62.169998,NaN,62.330002,62.330002,61.919998,61.500000,61.750000,62.330002,NaN,56.250000,56.580002,56.330002,55.750000,56.169998,55.919998,55.920254,55.920341,55.920254,55.919998,56.022827,56.125439,56.227829,56.330002,56.250000,NaN,53,53.169998,53.080002,52.669998,52.830002,53,NaN,47.919998,48.169998,48.500000,48.580002,49,49.500000,50.080002,50.580002,51,51.330002,51.580002,51.580002,51.080002,50.580002,50.250000,49.750000,50.080002,49.919998,49.669998,49.330002,49.419998,49.419998,49.419998,49.250000,48.830002,48.500000,48.580002,48.080002,47.750000,47.580002,48,48.080002,47.580002,47.669998,47.169998,46.669998,46.669998,47.080002,46.830002,47.330002,47.419998,47.330002,46.830002,46.919998,47.169998,47.500000,47.580002,47.580002,47.580002,47.669998,47.500000,47.919998,NaN,63.669998,64.080002,64.669998,65.250000,65.669998,66.080002,65.580002,65.169998,64.830002,64.500000,64.080002,63.830002,63.419998,63.750000,64,64,63.669998,63.250000,63.169998,63.669998,63.669998,NaN,67.669998,68.250000,68.250000,67.919998,67.500000,67.250000,67.169998,67.669998,NaN,71.750000,72.330002,72.750000,73.169998,73.580002,73.830002,73.830002,73.823387,73.816177,73.808380,73.800003,73.733498,73.666328,73.598488,73.529999,73.250000,72.830002,72.419998,72,71.669998,72.080002,72.500000,73,73.419998,73.750000,73.830002,73.580002,73.129997,72.669998,72.169998,72.169998,72.470001,72.470001,72.800003,72.699997,72.500000,72.580002,72.250000,71.750000,71.669998,71.419998,70.830002,70.500000,70.375359,70.250481,70.125359,70,69.895096,69.790123,69.685097,69.580002,69.478241,69.375984,69.273232,69.169998,69.128464,69.086288,69.043465,69,68.500000,68.080002,68.080002,67.669998,67.330002,67,66.669998,66.080002,65.669998,65.500000,65,65.330002,65.919998,66.419998,66.419998,65.750000,65.250000,64.830002,64.500000,64,63.580002,62.919998,62.919998,63.250000,63.580002,63.830002,63.419998,63.080002,62.669998,62.330002,61.919998,62,62.169998,62.419998,62.669998,62.830002,63,63.330002,63.750000,64,64.169998,64.419998,64.500000,64.250000,64.250000,64.250000,64.669998,65.080002,65.169998,65.500000,65.330002,65.330002,65.669998,66.169998,66.500000,66.919998,67.002762,67.085350,67.167763,67.250000,67.355064,67.460091,67.565063,67.669998,68.169998,68.500000,69,68.669998,69.330002,69.830002,70.250000,69.750000,69.580002,70,69.919998,70.080002,70.080002,70.419998,70.830002,71.330002,71.750000,NaN,73.750000,73.830002,73.779999,73.580002,73.169998,72.870003,72.980003,72.830002,72.980003,73.419998,73.750000,NaN,75,75.550003,75.550003,75.199997,74.669998,74.820000,75,NaN,77.029999,76.919998,76.650002,76.650002,76.370003,76.320442,76.270584,76.220436,76.169998,76.122597,76.075127,76.027596,75.980003,75.910789,75.841042,75.770775,75.699997,75.580002,75.820000,75.720001,75.720001,75.470001,75.080002,74.669998,74.500000,74.750000,74.419998,74.419998,74.470001,74.529999,74.750000,75.250000,75.669998,76.080002,76.330002,76.250000,76.669998,77.029999,NaN,80,80.449997,80.800003,81.250000,81.250000,80.800003,80.500000,80.419998,80.357689,80.295250,80.232689,80.169998,80.065071,79.960091,79.855072,79.750000,79.720886,79.691177,79.660881,79.629997,79.250000,79,78.529999,78.169998,78.169998,78.529999,78.980003,79.330002,79.720001,80,NaN,81.500000,81.919998,81.919998,81.919998,82.129997,82.330002,82.580002,82.919998,83.050003,82.980003,83.080002,83.080002,82.919998,82.800003,82.550003,82.419998,82.199997,81.949997,81.669998,81.419998,80.949997,80.580002,80.199997,79.720001,79.500000,79,78.500000,78,77.919998,77.580002,77.250000,76.830002,76.419998,76.169998,76.169998,76.500000,76.330002,76.419998,76.250000,76.330002,76.419998,76.830002,77.129997,77.160484,77.190643,77.220482,77.250000,77.292847,77.335464,77.377853,77.419998,77.830002,77.854462,77.877625,77.899475,77.919998,77.983818,78.046768,78.108833,78.124207,78.139526,78.154793,78.169998,78.206497,78.242958,78.279388,78.315788,78.461067,78.605812,78.750000,78.780624,78.810837,78.840630,78.870003,78.965103,79.060143,79.155106,79.250000,79.699997,79.870003,80.419998,80.250000,80.470001,80.629997,80.919998,80.800003,80.800003,80.669998,80.669998,81,81.500000,NaN,79.900002,80.169998,79.750000,79.900002,NaN,79.199997,79.379997,79.379997,79.199997,79.199997,78.879997,78.480003,78.129997,78.080002,78.480003,78.900002,78.550003,78.300003,78,77.970001,77.919998,77.750000,78.169998,78.169998,78.300003,78.529999,78.830002,79,79.199997,NaN,77.669998,77.830002,77.800003,77.570000,77.349998,77.470001,77.669998,NaN,77.669998,77.750000,77.430000,77.080002,77.180000,77.669998,NaN,76.580002,76.629997,76.370003,76,76.419998,76.699997,76.669998,76.379997,76,75.580002,75.070000,75.070000,75.629997,75.419998,75.830002,76.169998,76.580002,NaN,75.120003,75.470001,75.129997,75.120003,NaN,72.919998,73.070000,73.029999,73.500000,73.830002,74,73.919998,74.129997,74.005196,73.880264,73.755196,73.629997,73.515450,73.400597,73.285446,73.169998,73.123405,73.076210,73.028404,72.980003,72.419998,71.830002,71.669998,71.330002,71.830002,72.250000,72.250000,72.629997,72.919998,NaN,78.250000,78.500000,78.580002,78.379997,78.199997,78.169998,78.300003,78.250000,NaN,77.919998,78.080002,77.750000,77.699997,77.919998,NaN,77.750000,77.870003,78.019997,78.022888,78.025513,78.027885,78.029999,77.917511,77.805016,77.692513,77.580002,77.330002,77.419998,77.750000,NaN,75.580002,75.900002,76.129997,75.750000,75.480003,75.580002,NaN,76.250000,76.500000,76.879997,77.150002,77.330002,77.300003,77.580002,77.330002,77.080002,76.720001,76.300003,76.500000,76.169998,75.830002,75.919998,75.870003,76.250000,NaN,75.250000,75.669998,75.669998,76.129997,76.470001,76.419998,76.169998,75.919998,75.570000,75.554085,75.537109,75.519081,75.500000,75.582672,75.665230,75.747673,75.830002,75.897522,75.965034,76.032524,76.099998,76.137817,76.175430,76.212822,76.250000,76.332710,76.415283,76.497711,76.580002,76.800003,76.330002,76.019997,75.870003,75.470001,75.029999,74.949997,75,74.800003,74.529999,74.419998,74.500000,74.720001,74.919998,75.250000,74.970001,75.129997,75.250000,NaN,71.599998,72.029999,72.300003,72.580002,72.830002,73.019997,73.300003,73.300003,72.720001,73.080002,72.849998,73,72.669998,73.169998,73.669998,73.699997,73.419998,73.050003,72.580002,72.169998,71.629997,71.629997,71.050003,70.669998,70.400002,70.220001,69.750000,69.669998,69.300003,69,68.870003,69.150002,69.500000,69.169998,69,68.750000,68.650002,68.580002,69.250000,69.250000,69.500000,70.120003,70.169998,70.169998,70.419998,70.699997,70.669998,70.750000,71.029999,71.370003,71.599998,NaN,72.080002,72.500000,72.980003,73.500000,74.080002,74.250000,74.500000,74.250000,74.250000,73.830002,73.500000,73.199997,72.919998,72.580002,71.919998,71.419998,71.330002,71.080002,71.669998,72.080002,NaN,55.337139,55.371967,55.220909,54.897488,54.718967,54.747952,54.870407,54.861805,55.099033,55.146122,55.337139,NaN,52.919998,53,52.830002,52.750000,52.919998,NaN,51.713287,51.760422,51.886799,51.913162,51.866077,51.746857,51.713287,NaN,51.669998,51.919998,51.750000,51.669998,NaN,52.072304,52.090660,52.202759,52.271770,52.418468,52.174305,52.072304,NaN,52.750000,53.500000,53.580002,53.330002,53.169998,52.750000,NaN,53.330002,53.669998,54,54,53.700001,53.500000,53.330002,NaN,63.669998,63.669998,63.419998,63.330002,63.080002,63.419998,63.330002,63.669998,NaN,60.169998,60.250000,60.330002,60.250000,60,59.830002,59.919998,60.169998,NaN,57.250000,57.750000,58.080002,58.419998,58.169998,58.108124,58.045830,57.983120,57.919998,57.897686,57.875244,57.852684,57.830002,57.500000,57.330002,57,56.750000,57.250000,NaN,54.169998,54.080002,54.080002,53.580002,53.080002,52.750000,52.500000,52,52.419998,52.830002,53.330002,53.580002,54.169998,NaN,50.669998,50.830002,50.580002,50.419998,50.250000,49.750000,49.330002,48.919998,48.500000,48.330002,48.500000,48.750000,49,49,49.250000,49.419998,49.669998,49.919998,50.169998,50.669998,NaN,78.169998,78.580002,78.750000,79.019997,79.199997,79.750000,80.080002,80.080002,80.081978,80.082642,80.081978,80.080002,80.192726,80.305305,80.417732,80.529999,80.919998,81.180000,81.129997,81.419998,81.750000,82.080002,82.330002,82,82.470001,82.419998,82.830002,83.199997,83.419998,83.650002,83.580002,83.550003,83.250000,82.980003,82.849998,82.780579,82.710762,82.640572,82.570000,82.508514,82.446335,82.383499,82.320000,82.220001,82.229057,82.237083,82.244064,82.250000,82.205559,82.160736,82.115547,82.070000,82.074524,82.076035,82.074524,82.070000,81.972504,81.875000,81.777496,81.680000,81.750000,82.029999,82.029999,82.080002,81.800003,81.629997,81.370003,80.919998,81.080002,81.320000,81.580002,81.480003,81.800003,81.680000,81.590607,81.500793,81.410591,81.320000,81.179306,81.037376,80.894249,80.750000,80.419998,79.970001,79.529999,79.129997,78.830002,78.419998,77.919998,77.580002,77.080002,76.750000,76.919998,76.669998,76.300003,76.199997,75.699997,75.199997,74.669998,74.669998,74.669998,74.250000,74,73.830002,73.470001,73.419998,73.250000,73.200317,73.150414,73.100311,73.050003,73.017960,72.985611,72.952957,72.919998,72.419998,72.080002,72.300003,72.500000,72.169998,71.830002,71.419998,71,70.500000,70.419998,70.580002,71,71.330002,71.169998,70.669998,70.419998,70.169998,70.419998,70.169998,70.148315,70.126091,70.103317,70.080002,69.997734,69.915314,69.832733,69.750000,69.750000,69.419998,69.080002,68.830002,68.580002,68.419998,68.169998,68.169998,67.919998,67.500000,67.080002,66.669998,66.330002,66,65.669998,65.669998,65.500000,65.080002,65.169998,64.500000,64,63.500000,63,62.669998,62,61.500000,61,60.500000,60,59.830002,60.169998,60.169998,60.580002,60.750000,60.830002,61.419998,61.919998,62.500000,62.830002,63.580002,64,64.330002,64.919998,65.500000,66,66.500000,67,67.580002,68.169998,68.580002,68.580002,69.330002,69.919998,69.470001,69.300003,69.669998,70.250000,70.830002,70.800003,70.500000,71,71.169998,71.169998,71.750000,71.419998,71.419998,71.680000,72.169998,72.580002,73.169998,73.580002,74,74.500000,74.970001,75.320000,75.669998,75.820000,76.169998,76.169998,76.129997,75.919998,76.129997,76.379997,76.599998,76.800003,77.019997,77.250000,77.349998,77.580002,77.919998,77.870003,78.169998,NaN,65.500000,65.830002,66.169998,66.169998,66.419998,66.330002,66,65.419998,65.419998,65.580002,66.080002,65.830002,66.080002,66.169998,66,66.169998,66.500000,66.250000,66.330002,65.750000,65.500000,64.919998,64.419998,64.169998,63.830002,63.750000,63.419998,63.580002,63.830002,63.831982,63.832645,63.831982,63.830002,63.935360,64.040482,64.145363,64.250000,64.375214,64.500282,64.625214,64.750000,64.750000,65.080002,65.165352,65.250465,65.335350,65.419998,65.460274,65.500366,65.540276,65.580002,65.419998,65.500000,NaN,70.894814,71.017418,71.150528,71.152145,70.990669,70.922333,70.907082,70.806465,70.894814,NaN,75.400002,75.050003,75,75.400002,NaN,0,0.50000000,0.92000002,1.0800000,1.5000000,1.9200000,2.5000000,3.0799999,3.5000000,3.9200001,4,4.5000000,4.5000000,4.4200001,4.4200001,4.3299999,4.2500000,4.2500000,4.5799999,5.2500000,5.9200001,6.3299999,6.5000000,6.5000000,6.4200001,6.4200001,6.3299999,6.3299999,6.1700001,5.8299999,5.8299999,5.5000000,5.2500000,5.1700001,5,4.7500000,5,5.0799999,5.2500000,5.2500000,5.1700001,5.0799999,5,4.6700001,4.5799999,4.2500000,4.3299999,4.5000000,4.9200001,5.2500000,5.5799999,6.0799999,6.4200001,6.8299999,7.0799999,7.3299999,7.8299999,8.2500000,8.2500000,8.6700001,9.1700001,9.5799999,10,10.250000,10.670000,11.080000,11.250000,11.920000,11.830000,12.080000,12.330000,12.920000,13.420000,14,14.500000,14.750000,15,15.420000,15.830000,16.500000,17,17.500000,18,18.500000,19,19.500000,19.830000,20.330000,20.750000,20.750000,21.080000,21.580000,22.080000,22.330000,22.750000,23.420000,23.830000,24.250000,24.670000,25.250000,25.670000,26.170000,26.420000,26.670000,27,27.500000,27.920000,28,28.250000,28.670000,28.920000,29.330000,29.750000,30.330000,30.670000,31.500000,31.750000,32.169998,32.500000,32.830002,32.830002,33.250000,33.500000,33.669998,34,34.419998,34.830002,35.250000,35.750000,35.830002,35.500000,35.169998,35.250000,35.250000,35.330002,35.080002,35.169998,35.419998,35.750000,35.830002,35.919998,36.250000,36.500000,36.580002,36.669998,36.830002,36.830002,36.919998,36.919998,36.830002,36.669998,36.669998,36.750000,37,36.830002,37,36.830002,36.919998,37.169998,37.250000,37.169998,36.669998,36.919998,36.500000,36.330002,35.750000,35.580002,35.169998,34.750000,34.419998,34.169998,33.750000,33.580002,33.669998,33.250000,33,32.830002,32.830002,32.750000,32.669998,32.419998,32.250000,32.250000,31.750000,31.500000,31.250000,31.170000,31,30.670000,30.330000,30.250000,30.420000,30.670000,31.080000,31.500000,31.582521,31.665028,31.747520,31.830000,31.915047,32.000061,32.085045,32.169998,32.580002,32.750000,32.830002,32.750000,32.580002,32.169998,32.080002,31.920000,31.920000,31.500000,31.580000,31.500000,31.420000,31.250000,31.080000,31.080000,31.080000,30.830000,30.920000,31.170000,31.420000,31.500000,31.420000,31.080000,30.920000,30.690121,30.460159,30.230120,30,29.957544,29.915058,29.872543,29.830000,29.727545,29.625059,29.522543,29.420000,29,28.580000,28.170000,27.830000,27.420000,27.080000,26.670000,26.170000,25.750000,25.250000,24.830000,24.330000,24,23.580000,23.250000,22.750000,22.500000,22.250000,22.080000,21.500000,21.080000,20.750000,20.250000,19.670000,19.250000,18.670000,18.420000,18.420000,18,17.580000,17.080000,16.500000,16,15.580000,15.500000,15,14.750000,14.580000,14.080000,13.670000,13.250000,12.830000,12.420000,11.920000,11.670000,11.420000,11.080000,10.670000,10.420000,10.330000,10.500000,10.750000,10.670000,10.750000,11.080000,11.080000,11.250000,11.170000,11.170000,11.330000,11.500000,11.920000,11.750000,11,10.420000,10,9.4200001,8.9200001,8.5000000,8.1700001,7.6700001,7.2500000,6.7500000,6.3299999,5.7500000,5.4200001,5.0799999,4.5799999,4.1700001,3.7500000,3.4200001,3,2.5799999,2.2500000,1.9200000,1.7500000,1.4200000,1,0.75000000,0.75000000,0.41999999,0,-0.41999999,-0.92000002,-1.2500000,-1.7500000,-2.0799999,-2.5000000,-2.4200001,-3,-3.5799999,-4.1700001,-4.5799999,-5.0799999,-5.5799999,-6.0799999,-6.5799999,-7.0799999,-7.5799999,-8.1700001,-8.8299999,-9.4200001,-9.9200001,-10.170000,-10.500000,-11,-12.500000,-12,-12.420000,-13,-13,-13.580000,-14.080000,-14.670000,-15.170000,-15.580000,-16,-16.330000,-16.750000,-17.080000,-17.170000,-17.330000,-17.500000,-17.920000,-18.330000,-18.830000,-19,-19.420000,-19.670000,-20,-20.500000,-20.830000,-21.420000,-22.080000,-22.500000,-23.080000,-23.500000,-24,-24.500000,-24.750000,-24.920000,-24.920000,-25.170000,-25.330000,-25.500000,-26.080000,-26.250000,-26.580000,-27,-27.500000,-28.080000,-28.580000,-28.830000,-29.170000,-29.580000,-30,-30.500000,-30.920000,-31.330000,-31.670000,-32,-32.419998,-32.750000,-33,-33.330002,-33.669998,-33.750000,-33.750000,-34,-34,-34.250000,-34.169998,-34.169998,-34,-34.169998,-34.080002,-34.169998,-34.419998,-34.419998,-34.500000,-34.750000,-34.750000,-34.419998,-34.080002,-34.250000,-33.830002,-33.419998,-32.830002,-32.830002,-32.580002,-32,-31.420000,-31,-30.580000,-30,-29.580000,-29,-28.580000,-28.250000,-27.830000,-27.500000,-27,-26.420000,-26.420000,-25.920000,-25.500000,-25,-24.420000,-24,-23.500000,-22.920000,-22.500000,-22.080000,-21.670000,-21.250000,-20.830000,-20.250000,-19.750000,-19.250000,-18.830000,-18.500000,-17.920000,-17.420000,-17,-16.500000,-16,-15.500000,-15,-14.500000,-13.920000,-13.330000,-12.920000,-12.670000,-12.250000,-12.250000,-11.830000,-11.250000,-10.670000,-10.330000,-9.9200001,-9.4200001,-9.1700001,-8.6700001,-8.1700001,-7.7500000,-7.2500000,-6.7500000,-6.4200001,-6,-5.7500000,-5.3299999,-4.9200001,-4.5000000,-4.0799999,-3.7500000,-3.4200001,-3.0799999,-2.7500000,-2.2500000,-1.8300000,-1.3300000,-0.82999998,-0.50000000,0,NaN,30,30.920000,31.250000,31,31.080000,31.170000,31.500000,32,32.500000,33,33.500000,34.080002,34.500000,35,35.669998,36,36.330002,36.669998,36.919998,36.580002,36.580002,36.830002,36.500000,36.169998,36.169998,36.169998,36,36.169998,36.500000,36.750000,36.830002,36.419998,36.169998,36.330002,36.750000,36.750000,37,37,37.000198,37.000263,37.000198,37,37.082584,37.165115,37.247585,37.330002,37.392639,37.455185,37.517639,37.580002,37.919998,38.080002,38.250000,38.580002,38.330002,38.419998,38.669998,39.250000,39.500000,39.419998,40,40.250000,40.580002,40.500000,40.830002,40.919998,40.830002,40.919998,40.669998,40.669998,40.419998,40.169998,40.169998,40.580002,40,39.580002,39.250000,38.919998,38.669998,38.500000,38.169998,38.169998,38,38.169998,37.580002,37.919998,38,38.330002,38.299999,38.330002,38.750000,39.250000,39.580002,40,40.250000,40.750000,41.330002,41.750000,42,42.330002,42.580002,43,43.419998,43.500000,43.750000,44,44.330002,44.580002,45,45.330002,45,44.830002,44.830002,45.080002,45.419998,45.669998,45.750000,45.500000,45.500000,45.169998,44.919998,44.580002,44.250000,43.919998,43.669998,43.419998,43,42.580002,42.330002,42.080002,41.830002,41.830002,41.500000,41.330002,41.080002,40.830002,40.580002,40.169998,39.830002,39.919998,40.250000,40.330002,40.500000,40.500000,40.169998,39.669998,39.419998,39,38.830002,38.419998,38.169998,37.919998,37.919998,38.169998,38.580002,38.830002,39.250000,39.669998,40,40.169998,40.580002,40.669998,40.919998,41.250000,41.250000,41.500000,41.919998,42.330002,42.330002,42.669998,43.080002,43.500000,44,44.080002,44.080002,44.250000,44.330002,44.169998,43.830002,43.669998,43.419998,43.080002,43,43.250000,43.330002,43.500000,43.250000,43,42.500000,41.919998,41.669998,41.330002,41.169998,41,40.419998,39.919998,39.500000,39.080002,38.997700,38.915268,38.832699,38.750000,38.667770,38.585358,38.502769,38.419998,38.080002,37.669998,37.669998,37.169998,36.750000,36.750000,36.750000,36.750000,36.750000,36.669998,36.500000,36.080002,36.250000,36.750000,37,37.250000,37.250000,37.080002,37.169998,37.080002,37.500000,38,38.500000,38.500000,38.830002,39.330002,39.669998,40.250000,40.750000,41.169998,41.669998,42,42.419998,43,43.250000,43.330002,43.330002,43.750000,43.500000,43.500000,43.580002,43.500000,43.330002,43.500000,43.419998,43.330002,43.419998,43.669998,44.250000,44.669998,45.250000,45.830002,46.250000,46.500000,46.750000,47,47.330002,47.500000,47.580002,47.830002,47.830002,48,48.500000,48.580002,48.750000,48.830002,48.500000,48.500000,48.580002,48.580002,49.169998,49.669998,49.669998,49.250000,49.330002,49.250000,49.669998,49.830002,49.919998,50.080002,50.500000,50.830002,51,51.250000,51.419998,51.750000,52.080002,52.419998,52.830002,52.919998,52.419998,52.250000,52.500000,52.750000,52.830002,53.250000,53.419998,53.419998,53.419998,53.669998,53.669998,53.500000,53.830002,54.080002,54.330002,54.500000,54.830002,55.330002,55.580002,56,56.500000,56.830002,57.080002,57.169998,57.500000,57.580002,57.250000,56.830002,56.500000,56.500000,56.169998,56,55.500000,55,54.750000,54.500000,54.250000,53.919998,53.919998,53.919998,54.169998,54.330002,54.419998,54.669998,54.330002,54.169998,54,53.919998,54.169998,54.250000,54.580002,54.750000,54.830002,54.330002,54.330002,54.500000,54.919998,55.169998,55.669998,56.169998,56.750000,57.080002,57.580002,57.669998,57.419998,57.080002,57,57.250000,57.750000,58.250000,58.250000,58.330002,58.750000,59.169998,59.419998,59.500000,59.580002,59.419998,59.419998,59.669998,60,59.958210,59.915947,59.873207,59.830002,59.935123,60.040165,60.145126,60.250000,60.169998,60.580002,60.580002,60.419998,60.250000,60.080002,60,60.169998,60.419998,60.669998,61,61.500000,62,62.500000,63,63.419998,63.919998,64.330002,64.330002,64.830002,65,65.500000,65.830002,65.750000,65.750000,65.830002,65.500000,65.330002,65.080002,64.750000,64.500000,64.169998,63.830002,63.580002,63.330002,63,62.500000,62.250000,61.750000,61.250000,60.830002,60.500000,60.169998,59.830002,59.580002,59.330002,59.169998,58.919998,58.580002,58.580002,58.250000,57.750000,57.330002,56.750000,56.169998,56.169998,56.169998,55.750000,55.419998,55.419998,55.419998,55.750000,56.169998,56.500000,56.919998,57.419998,58,58.500000,59.080002,59.330002,59,59,58.580002,58.250000,58,58.080002,58.330002,58.580002,59,59.330002,59.330002,59.250000,59.580002,59.919998,60.330002,60.750000,60.855019,60.960026,61.065022,61.169998,61.252621,61.335163,61.417622,61.500000,61.582573,61.665100,61.747574,61.830002,61.915379,62.000507,62.085384,62.169998,62.500000,62.919998,63,63.330002,63.750000,63.500000,63.919998,64.330002,64.919998,65.250000,65.750000,66.169998,66.580002,67,67.419998,67.830002,68.330002,68.250000,68.169998,67.830002,68.250000,68.250000,68.293488,68.336327,68.378494,68.419998,68.482689,68.545250,68.607689,68.669998,68.732956,68.795609,68.857956,68.919998,69.250000,68.750000,69,68.669998,68.752953,68.835609,68.917961,69,69.020187,69.040245,69.060181,69.080002,69.419998,69.580002,70.080002,70.080002,70.250000,70.669998,70.919998,70.669998,71,71.169998,70.580002,70.919998,70.500000,71.080002,70.919998,70.669998,70.419998,70.080002,70.103317,70.126091,70.148315,70.169998,70.085823,70.001099,69.915817,69.830002,69.750000,69.750000,69.919998,69.750000,69.419998,69.330002,69.169998,68.919998,68.580002,68.250000,68,67.669998,67.250000,66.750000,66.419998,66.169998,66.080002,66.250000,66.330002,66.419998,66.669998,66.830002,66.915497,67.000664,67.085503,67.169998,67.045197,66.920265,66.795197,66.669998,66.419998,66,65.500000,65.080002,64.580002,64.330002,63.919998,63.919998,63.919998,64.419998,64.419998,64.830002,65.169998,65.080002,64.830002,64.669998,64.580002,65.080002,65.185158,65.290207,65.395157,65.500000,65.582924,65.665565,65.747925,65.830002,66.080002,66.419998,66.330002,66.169998,66.500000,67,67.169998,67.669998,68.250000,68.669998,68.500000,68.500000,68.250000,67.830002,67.750000,67.645195,67.540260,67.435196,67.330002,67.290482,67.250641,67.210480,67.169998,66.830002,66.830002,66.830002,67.080002,67.669998,67.830002,68.080002,68.330002,68.500000,68.750000,69,68.500000,68.169998,68.500000,68.580002,68.500000,68.830002,69,68.419998,68.330002,68.669998,68.750000,69,69.330002,69.669998,69.919998,70.169998,70.500000,70.080002,69.750000,69.669998,69.330002,69.250000,69.250000,69,68.830002,68.500000,68.250000,68.750000,69,69.500000,69.669998,70,70.419998,70.830002,71.250000,71.580002,72,72.500000,72.919998,73.330002,73.373032,73.415710,73.458031,73.500000,73.417610,73.335152,73.252609,73.169998,73.107552,73.045067,72.982552,72.919998,72.858543,72.796387,72.733536,72.669998,72.584999,72.500000,72.415001,72.330002,72.227577,72.125107,72.022583,71.919998,71.815170,71.710228,71.605171,71.500000,71.395355,71.290466,71.185349,71.080002,70.955002,70.830002,70.705002,70.580002,70.455002,70.330002,70.205002,70.080002,69.935005,69.790009,69.645004,69.500000,69.375000,69.250000,69.125000,69,68.895554,68.790733,68.685547,68.580002,68.580002,68.169998,67.750000,67.330002,67,66.669998,66.250000,66.500000,66.830002,67.250000,67.669998,68.250000,68.750000,68.812965,68.875618,68.937965,69,69.021362,69.041817,69.061363,69.080002,69.669998,70.169998,70.580002,71,71.330002,71.830002,72,72.330002,72.669998,72.919998,73.080002,72.750000,72.250000,71.830002,71.330002,71.169998,71.169998,71,71.250000,71.500000,71.919998,72.080002,71.830002,72,72.083344,72.166122,72.248344,72.330002,72.392761,72.455353,72.517769,72.580002,72.330002,72.330002,72.080002,71.669998,71.710762,71.751015,71.790764,71.830002,71.935211,72.040276,72.145210,72.250000,72.419998,72.919998,73.500000,73.580002,73.669998,73.830002,73.919998,74.330002,74.669998,75,75.330002,75.580002,75.750000,76.080002,76.080002,76.080002,76.144409,76.207558,76.269424,76.330002,76.247543,76.165054,76.082542,76,76.045380,76.088852,76.130394,76.169998,76.252563,76.335091,76.417564,76.500000,76.500000,77,77.419998,77.750000,77.668884,77.586830,77.503868,77.419998,77.336189,77.251572,77.166168,77.080002,77.081093,77.081459,77.081093,77.080002,77.060806,77.041069,77.020805,77,76.875427,76.750565,76.625420,76.500000,76.500740,76.500984,76.500740,76.500000,76.750000,76.750000,76.669998,76.500000,76.169998,75.750000,75.250000,74.919998,74.500000,74.169998,73.750000,73.580002,73.169998,73.169998,73.330002,73.500000,73.500000,73.562698,73.625267,73.687698,73.750000,73.812698,73.875259,73.937698,74,73.830002,73.669998,73.669998,73.500000,73.669998,73.750000,73.580002,73.580002,73.169998,73,72.919998,73,73.330002,73.669998,73.669998,73.419998,73.250000,72.750000,72.250000,71.830002,71.330002,70.919998,70.750000,70.750000,71.080002,71.500000,71.919998,71.500000,71.330002,71.580002,71.669998,71.500000,71.580002,71.561241,71.541656,71.521240,71.500000,71.605118,71.710159,71.815125,71.919998,72.250000,72.500000,72.500000,72.830002,72.750000,72.669998,72.580002,72.330002,72.330002,72.169998,71.669998,71.419998,71.419998,71.169998,70.830002,70.919998,70.919998,71.080002,71,71,70.919998,70.669998,70.565056,70.460075,70.355057,70.250000,70.145134,70.040176,69.935127,69.830002,69.768234,69.705971,69.643227,69.580002,69.580002,69.669998,69.580002,69.419998,69.669998,70,69.830002,69.580002,69.580002,69.250000,69.080002,68.750000,68.830002,69.080002,69.500000,70.080002,70,69.919998,69.830002,69.830002,69.580002,69.419998,69.169998,69.080002,69.080002,68.750000,68.419998,68.169998,67.830002,67.500000,67.080002,67.080002,66.919998,66.500000,66.395607,66.290802,66.185600,66.080002,66.017845,65.955460,65.892845,65.830002,65.500000,65.500000,65,64.669998,64.250000,64.419998,64.750000,65,65.419998,65.580002,65.419998,65.500000,65.919998,66.330002,66,65.669998,65.169998,65.050003,65.050003,64.919998,64.669998,64.750000,64.330002,64.330002,64,63.500000,63,62.669998,62.250000,62.500000,62.500000,62.250000,62.080002,61.750000,61.669998,61.330002,61,60.669998,60.419998,60.419998,59.919998,60.250000,60.500000,60.580002,60.419998,60.169998,59.750000,60.330002,60.169998,59.830002,60,59.830002,59.419998,59,58.580002,58.169998,57.750000,57.919998,57.669998,57.250000,56.830002,56.669998,56.169998,56,56.250000,56.080002,55.669998,55.169998,54.750000,54.500000,54.500000,54.580002,54.419998,54.080002,53.580002,53.169998,53.169998,52.830002,52.250000,51.669998,51.250000,50.919998,51.250000,51.669998,52.169998,52.750000,53.330002,53.919998,54.330002,54.830002,55.250000,55.830002,56.330002,56.830002,57,57.419998,57.750000,57.750000,58,58.419998,58.830002,58.830002,59.250000,59.669998,60.080002,60.419998,60.669998,60.830002,61.169998,61.750000,62.250000,62.500000,62.669998,62.500000,62.080002,61.669998,61.580002,61.250000,60.919998,60.580002,60.919998,61.250000,61.395172,61.540230,61.685173,61.830002,61.790470,61.750626,61.710468,61.669998,61.830002,61.750000,61.580002,61.169998,60.750000,60.419998,60,59.500000,59.500000,59.419998,59.357582,59.295113,59.232582,59.169998,59.148487,59.126316,59.103485,59.080002,59.169998,59,58.830002,58.830002,59.080002,59.330002,59.580002,59.500000,59.580002,59.750000,59.669998,59.419998,59.250000,59.330002,59.250000,59.419998,59.169998,59.330002,59.330002,59.330002,59.250000,59,58.669998,58.419998,58.080002,57.750000,57.500000,57.500000,57.169998,56.830002,56.330002,55.919998,55.580002,55.169998,54.919998,54.669998,54.500000,54.580002,54.169998,53.750000,54.169998,54.250000,53.830002,53.747589,53.665119,53.582588,53.500000,53.543159,53.585880,53.628162,53.669998,54.169998,54.169998,54,53.750000,53.500000,53.250000,52.830002,52.419998,52.169998,51.830002,51.419998,51,50.500000,50.500000,50,49.419998,49,48.500000,48,47.500000,47.080002,46.500000,46.080002,45.669998,45.250000,44.750000,44.330002,43.919998,43.419998,43.169998,42.830002,42.669998,42.919998,43.250000,43.250000,43,42.580002,42.580002,42.250000,42.080002,41.580002,41.330002,40.830002,40.669998,40.669998,40.330002,40.080002,39.919998,39.897701,39.875267,39.852699,39.830002,39.767525,39.705032,39.642525,39.626892,39.611263,39.595631,39.580002,39.559383,39.538765,39.518143,39.497524,39.415031,39.332523,39.250000,39.187702,39.125267,39.062698,39,38.669998,38.250000,37.919998,37.500000,37,36.500000,36,35.580002,35.169998,34.919998,34.830002,34.669998,34.330002,34.830002,35.330002,35.750000,36.330002,36.919998,37,37.419998,37.750000,37.669998,38.080002,38.080002,38.500000,38.919998,39.419998,39.580002,39.669998,39.830002,39.750000,39.580002,39.419998,39.080002,38.830002,38.750000,39.169998,39.500000,39.750000,40,40.419998,40.830002,40.919998,40.580002,40.169998,40,39.750000,39.419998,39.169998,39.080002,39.250000,38.919998,38.580002,38.250000,38.250000,38,37.750000,37.330002,37.080002,37.080002,37.330002,37.580002,37.750000,37.500000,37.419998,37.419998,37.397697,37.375263,37.352695,37.330002,37.205048,37.080067,36.955048,36.830002,37,36.750000,36.580002,36.169998,35.919998,35.580002,35.250000,34.830002,34.580002,34.330002,33.830002,33.419998,33,32.580002,32.419998,32.080002,31.670000,31.670000,31.670000,31.250000,30.920000,30.830000,30.670000,30.420000,30.330000,30.170000,30.250000,30.080000,30,29.750000,29.170000,29.170000,28.670000,28.420000,28.170000,28.170000,27.830000,27.420000,27,26.670000,26.750000,26.330000,26,25.580000,25.250000,25,24.580000,24.580000,24.580000,24.250000,24,23.670000,23.420000,23.080000,22.830000,22.750000,22.670000,22.670000,22.250000,22.670000,22.170000,22.500000,22,21.830000,21.750000,21.500000,21.420000,21.250000,20.920000,20.500000,20.330000,20.330000,20.750000,21,21.420000,21.420000,21.670000,21.670000,21.500000,21.500000,21.250000,21,20.670000,20.250000,19.920000,19.500000,19,18.420000,18.080000,17.750000,17.330000,16.920000,16.500000,16.170000,15.750000,15.330000,14.750000,14.250000,13.750000,13.250000,12.830000,12.170000,11.750000,11.420000,11.170000,10.920000,10.670000,10.420000,10.420000,9.8299999,9.8299999,9.4200001,9.3299999,9,8.6700001,9.0799999,9.5799999,9.7050076,9.8300104,9.9550076,10.080000,10.122571,10.165094,10.207571,10.250000,10.580000,10.580000,10.920000,11.330000,11.750000,12.080000,12.250000,12.670000,12.670000,12.750000,13.330000,13.500000,13.330000,12.750000,12.080000,11.670000,11.170000,10.830000,10.250000,9.6700001,9.1700001,9.2500000,9.2500000,8.5799999,8.2500000,7.7500000,7.1700001,6.9200001,6.8299999,6.4200001,6.0799999,5.7500000,5.4200001,4.9200001,4.4200001,3.9200001,3.4200001,2.9200001,2.5799999,2,1.4200000,1.4200000,1.6700000,1.9200000,2.1700001,2.5000000,2.8299999,3.3299999,3.7500000,4.2500000,4.7500000,5.0799999,5.6700001,5.6700001,6.0799999,6.6700001,7,7.3299999,7.8299999,8.2500000,8.0799999,8.5000000,9,9.5799999,10.170000,10.670000,11,11.420000,11.920000,12.500000,13.080000,13.670000,14.250000,14.750000,15.330000,15.830000,16.330000,16.750000,16.920000,16.580000,16.330000,16.080000,15.750000,15.750000,15.750000,15.830000,16.080000,16.580000,17.170000,17.750000,18.330000,18.830000,18.830000,19.250000,19.500000,19.920000,19.920000,20.250000,20.670000,21.080000,21.500000,21.920000,22.330000,22.750000,22.420000,22.170000,21.830000,21.750000,21.670000,21.580000,21.500000,22.080000,21.750000,21.580000,21.420000,21.420000,21.080000,20.750000,20.330000,19.920000,19.750000,19.670000,19.330000,19,18.580000,18.250000,18.080000,17.830000,17.420000,17.170000,17,16.580000,16.330000,16.250000,16.170000,15.750000,15.830000,15.420000,15,14.420000,13.830000,13.250000,12.670000,12.170000,11.750000,11.250000,11.250000,10.830000,10.250000,10.250000,9.7500000,9.2500000,9.1700001,8.9200001,8.3299999,8.0799999,8.2500000,8.5799999,9,9.5799999,10.170000,10.670000,11.170000,11.580000,12,12.420000,13,13.500000,14,14.500000,15,15.500000,16,16.420000,17,17.500000,18.080000,18.080000,18.670000,19,19.250000,19.750000,20.250000,20.830000,21.250000,21.670000,22.170000,22.250000,21.830000,21.250000,20.920000,20.750000,20.750000,21,21.420000,21.750000,22.250000,22.250000,22.420000,22.920000,22.750000,22.750000,23.080000,23.500000,23.750000,23.920000,24.330000,24.750000,24.750000,25,25.330000,25.420000,25.330000,25.250000,25.170000,25.250000,25.420000,25.250000,25.250000,25.170000,25.080000,25.170000,25.250000,25.330000,25.330000,25.420000,25.580000,25.670000,25.750000,26.250000,26.670000,27,27,26.830000,26.670000,26.420000,26.670000,26.580000,26.920000,26.920000,27,27.420000,27.670000,27.830000,28.250000,28.750000,29.250000,29.830000,30.170000,30,30.250000,30.500000,30,29.580000,29.420000,29.250000,28.750000,28.250000,27.830000,27.420000,27,26.670000,26.250000,25.830000,25.420000,25.170000,25.580000,26,26.080000,25.750000,25.750000,25.250000,24.750000,24.250000,24.250000,24,23.920000,24.170000,24.170000,24.080000,24.170000,24.580000,24.920000,25.250000,25.580000,25.830000,26.170000,26.080000,25.830000,25.330000,24.750000,24.330000,24,23.750000,23.670000,23.500000,23.080000,22.670000,22.420000,21.920000,21.420000,21.420000,21.170000,20.830000,20.420000,20.420000,20,19.500000,19.080000,18.920000,18.830000,18.580000,18.080000,17.920000,17.830000,17.670000,17.170000,16.920000,17,16.920000,16.670000,16.500000,16.250000,15.920000,15.580000,15.420000,15.250000,15.080000,14.920000,14.750000,14.500000,14.080000,14.080000,13.920000,13.920000,13.580000,13.330000,13.250000,13.330000,13.330000,13,12.830000,12.750000,12.670000,12.750000,13.250000,13.750000,14,14.580000,15.170000,15.670000,16.080000,16.500000,17,17.500000,17.750000,18.170000,18.670000,19.170000,19.670000,20.080000,20.250000,20.580000,20.580000,20.920000,21.500000,21.920000,22.250000,22.750000,23.250000,23.750000,24.080000,24.330000,24.830000,25.330000,25.830000,26.170000,26.670000,27.170000,27.580000,28,28,28.500000,29,29.500000,28.920000,28.330000,27.920000,27.750000,28.080000,28.420000,28.750000,29.080000,29.580000,29.580000,30,NaN,74.080002,74.330002,74.500000,74.419998,74.080002,NaN,40.330002,40.330002,40.330002,40.330002,40.330002,40.330002,40.580002,40.669998,41,41,40.919998,40.669998,40.330002,NaN,14.080000,13.750000,13.330000,13.080000,12.750000,12.500000,12.750000,12.920000,13.420000,13.420000,13.500000,13.830000,14.170000,14.250000,14.080000,NaN,-2.0799999,-2.7500000,-2.3299999,-2.5000000,-2.5000000,-2.1700001,-2.0799999,-1.7500000,-1.3300000,-0.75000000,-0.41999999,0.079999998,0.25000000,0.25000000,0.17000000,-0.17000000,-0.75000000,-1.1700000,-1.5800000,-2.0799999,NaN,-6,-6.5000000,-7,-7.4200001,-8.0799999,-8.5799999,-8.7500000,-8.2500000,-7.7500000,-7.1700001,-6.8299999,-6.5000000,-6.4175320,-6.3350420,-6.2525315,-6.1700001,-6.0650105,-5.9600139,-5.8550105,-5.7500000,-5.6050043,-5.4600058,-5.3150043,-5.1700001,-4.5799999,-4,-3.3299999,-4,-4.5000000,-5,-5.5799999,-6,NaN,-12.170000,-12.580000,-13,-13.420000,-13.750000,-14.170000,-14.080000,-14.500000,-13.830000,-13.420000,-12.830000,-12.250000,-12.105010,-11.960012,-11.815009,-11.670000,-11.522534,-11.375046,-11.227534,-11.080000,-10.580000,-9.9200001,-9.5799999,-9.8299999,-10.830000,-11,-11.750000,-12.170000,NaN,42.500000,42.080002,41.669998,41.330002,41.169998,41.080002,41.169998,41.080002,41.330002,41.580002,41.830002,42,41.919998,41.919998,42,41.669998,41.669998,41.250000,41.250000,41,41.080002,40.919998,41,41.080002,41,41.080002,41.419998,41.669998,42,42.330002,42.330002,42.750000,42.919998,43.169998,43.419998,43.669998,44.080002,44.330002,44.419998,44.580002,44.750000,45.080002,45.080002,45,45.080002,44.830002,44.750000,44.500000,44.330002,44.580002,45,45.169998,45.330002,45.750000,45.919998,46.169998,46,46.250000,46.580002,46.580002,46.580002,46.580002,46.169998,45.830002,45.669998,45.169998,44.830002,44.669998,44.330002,43.919998,43.419998,43.330002,42.830002,42.500000,NaN,45.919998,45.750000,45.419998,45.250000,45.419998,45.419998,45.330002,45.830002,46.250000,46.419998,46.669998,46.669998,47,47.080002,47.250000,47.169998,47.080002,46.750000,46.669998,46.419998,46.080002,45.919998,NaN,44.750000,44.419998,44.250000,43.750000,43.419998,43,42.500000,42.080002,41.830002,41.419998,41,40.580002,40.540272,40.500362,40.460270,40.419998,40.397701,40.375271,40.352703,40.330002,40,39.500000,39.169998,39.169998,38.580002,38.080002,37.580002,37.419998,37.330002,37.080002,36.750000,36.580002,36.750000,36.919998,36.830002,37.169998,37.169998,37.830002,38.500000,39.080002,39.169998,39.580002,40,40,40.330002,40.830002,40.669998,40.669998,41,41.330002,41.669998,42.080002,42,41.669998,41.250000,41.750000,41.855007,41.960011,42.065006,42.169998,42.272594,42.375126,42.477596,42.580002,42.642525,42.705032,42.767525,42.830002,42.830002,43.169998,43.669998,44.169998,44.330002,44.580002,44.580002,44.500000,44.500000,45,45.082775,45.165367,45.247776,45.330002,45.352959,45.375614,45.397961,45.419998,45.169998,45.250000,45.250000,45.500000,45.919998,46.419998,46.830002,47.169998,47.169998,47.169998,47.250000,46.830002,46.750000,46.580002,46.330002,46.250000,45.919998,46.080002,45.669998,45.169998,44.750000,NaN,45,44.500000,44.250000,43.669998,43.669998,43.669998,43.500000,43.669998,44.169998,44.669998,44.750000,45,45.330002,45.750000,46,46.419998,46.750000,46.500000,46.669998,46.500000,46.169998,46.330002,45.919998,45.919998,45.830002,45.419998,45,NaN,45.580002,45.250000,44.919998,45.669998,46,46.169998,46.419998,46.580002,46.419998,46.480000,46.330002,46.419998,46.750000,46.750000,46.580002,46.669998,46.580002,46.669998,46.750000,46.669998,46.750000,46.419998,46.169998,45.580002,NaN,51.580002,51.330002,51.500000,51.669998,52.169998,52.500000,52.669998,53,53.500000,54,54.500000,55.080002,55.580002,55.750000,55.500000,55.169998,54.750000,54.330002,53.919998,53.500000,53.080002,52.750000,52.500000,52.169998,51.830002,51.750000,51.580002,NaN,61.080002,60.750000,60.330002,59.919998,59.919998,60.169998,60.169998,60.500000,60.830002,61.169998,61.330002,61.580002,61.580002,61.330002,61.080002,NaN,61.750000,61.500000,61.330002,60.919998,60.919998,61.080002,61.419998,61.669998,62,62.419998,62.669998,62.830002,62.580002,62.500000,62.169998,62.169998,61.750000,NaN,-21.920000,-21.330000,-20.920000,-20.500000,-20,-19.580000,-19,-18.580000,-18,-18,-17.420000,-16.920000,-16.170000,-16.170000,-15.920000,-15.750000,-15.500000,-15.250000,-14.750000,-14.750000,-14.330000,-14.080000,-13.580000,-13.500000,-13.330000,-12.920000,-12.420000,-12,-12.500000,-13,-13.580000,-14.170000,-14.920000,-15.420000,-15.920000,-15.500000,-16.330000,-16.750000,-17,-17.420000,-17.420000,-18,-18.500000,-19.080000,-19.580000,-20.080000,-20.500000,-20.920000,-21.330000,-21.750000,-22.170000,-22.580000,-23,-23.420000,-23.750000,-24.250000,-24.670000,-25.170000,-25.080000,-25.250000,-25.500000,-25.580000,-25.330000,-25,-24.500000,-23.920000,-23.250000,-22.830000,-22.330000,-21.920000,NaN,-21,-20.920000,-21.170000,-21.330000,-21.330000,-21,NaN,-20.500000,-20,-20.170000,-20.500000,-20.500000,NaN,12.420000,12.670000,12.580000,12.500000,12.250000,12.250000,12.420000,NaN,-48.830002,-48.669998,-49,-49.250000,-49.169998,-49.080002,-49.419998,-49.419998,-49.669998,-49.500000,-49.669998,-49.250000,-48.830002,NaN,11.562831,11.821190,12.737682,12.750914,12.612169,11.562831,NaN,12.997019,13.161057,13.407540,13.489984,13.471362,13.187242,12.997019,NaN,2.3663483,2.5132217,2.7189283,2.8555582,2.8823874,2.6184011,2.3663483,NaN,1.3300000,1.5000000,1,0.57999998,1,1.3300000,NaN,-1,-0.92000002,-1.6700000,-1.7500000,-1.5000000,-1,NaN,8.0799999,8.5000000,9,9.4200001,9.8299999,9.5000000,9,8.5000000,8,7.5799999,7,6.5000000,6.1700001,6,6,6.4200001,7.0799999,7.5000000,8.0799999,NaN,19.330000,19.580000,19.920000,20,20,20,19.670000,19.330000,18.830000,18.500000,18.250000,18.250000,18.500000,18.920000,19.330000,NaN,23.670000,24.170000,24.580000,25,25.250000,25.080000,24.580000,24.080000,23.500000,23,22.580000,22,22.420000,22.580000,23.170000,23.670000,NaN,33.250000,33.500000,33.830002,33.919998,33.669998,33.669998,33.250000,32.830002,32.419998,31.920000,31.420000,31.080000,31.250000,31.670000,32.080002,32.330002,32.750000,33.080002,32.750000,32.750000,33.250000,NaN,33.419998,33.669998,34,33.919998,34.250000,34.330002,34.169998,33.830002,33.580002,33.250000,33.500000,33.330002,33.080002,32.750000,32.919998,33.419998,NaN,34.330002,34.500000,34.750000,35.080002,35.500000,35.500000,35.580002,35.669998,35.750000,35.500000,35.669998,36.080002,36.419998,36.830002,37.250000,37.500000,37.080002,36.750000,37,37.169998,37.169998,37.419998,37.830002,38.080002,38.580002,39,39.419998,39.919998,40.330002,40.669998,41.169998,40.919998,40.919998,41.169998,41.169998,41.500000,41.330002,41,40.580002,40.169998,39.669998,39.080002,38.750000,38.330002,38.330002,38.080002,37.580002,37,36.750000,36.169998,35.750000,35.750000,35.500000,35.169998,34.919998,35.500000,35.250000,35.250000,34.580002,35.080002,34.580002,34.580002,35,34.669998,34.330002,33.919998,33.419998,33.500000,33.919998,34.330002,34.750000,34.750000,34.830002,34.580002,34.500000,34.330002,34.250000,33.919998,34,33.919998,34.330002,NaN,42.580002,42.919998,43.250000,43.169998,43.169998,43.419998,43.750000,44,44.330002,44.750000,45.250000,45.500000,45.169998,44.750000,44.750000,44.500000,44.169998,44,43.919998,44.250000,43.750000,43.580002,43.330002,43.419998,43.169998,42.919998,43,42.669998,42.330002,42,42.250000,42.580002,42.500000,42.330002,42.500000,42.500000,42.250000,42.080002,41.830002,41.669998,41.419998,42,42.250000,42.580002,NaN,26.079590,26.318262,26.563335,26.871492,26.827274,26.738194,26.418993,26.122478,26.079590,NaN,28.078142,28.115788,28.266502,28.373316,28.498936,28.442738,28.078142,NaN,43.956451,44.523075,44.450336,43.956451,NaN,44.419998,45,45.330002,45.250000,45.500000,45.080002,44.750000,44.419998,NaN,45.669998,46.080002,46.250000,45.750000,45.669998,NaN,50.270000,50.419998,50.750000,50.500000,50.200001,50,50.270000,NaN,54.830002,55.169998,55,54.580002,54.830002,NaN,58.500000,59,59.169998,58.919998,58.500000,NaN,53.330002,53.580002,53.642548,53.705067,53.767548,53.830002,53.935047,54.040066,54.145050,54.250000,54.270138,54.290184,54.310139,54.330002,54,53.500000,53,52.500000,52,51.500000,51,50.500000,50,49.500000,49.080002,49.330002,49.330002,49.330002,49.080002,48.750000,48.330002,47.830002,47.500000,47.250000,46.919998,46.750000,46.250000,46.580002,46.669998,46.419998,45.919998,46.580002,47,47.580002,48,48.500000,48.750000,49.080002,49.500000,50,50.500000,51,51.419998,51.750000,52.250000,52.750000,53.330002,NaN,71,70.830002,71.120003,71.529999,71.529999,71.440346,71.350456,71.260338,71.169998,71.104042,71.037056,70.969032,70.900002,71,NaN,73.500000,73.830002,73.919998,73.500000,73.169998,73.250000,73.500000,NaN,74.250000,74.250000,74,73.919998,74.250000,NaN,75.580002,75.419998,75.330002,75.169998,74.750000,74.750000,75.080002,75.580002,NaN,75.250000,75.919998,76.169998,75.750000,76.169998,75.830002,75.830002,75.669998,75.419998,75.080002,74.830002,75,74.830002,74.669998,74.750000,75.250000,NaN,77.919998,78.330002,78.830002,79.250000,79.419998,79.169998,78.830002,78.330002,78.169998,78.169998,77.919998,NaN,80.080002,80.500000,80.919998,81.250000,81,80.937798,80.875397,80.812798,80.750000,80.687569,80.625084,80.562569,80.500000,80.417595,80.335121,80.252594,80.169998,80,79.917740,79.835320,79.752739,79.669998,79.565132,79.460175,79.355133,79.250000,78.830002,78.750000,78.919998,79.080002,79.500000,79.669998,80.080002,NaN,71.580002,71.705002,71.830002,71.955002,72.080002,72.143051,72.205742,72.268059,72.330002,72.415031,72.500038,72.585030,72.669998,72.701332,72.732651,72.763962,72.795258,72.826546,72.857819,72.889091,72.920341,73.045258,73.169998,73.233025,73.295700,73.358025,73.419998,73.502609,73.585144,73.667610,73.750000,74.169998,74.750000,75.080002,75.330002,75.330002,75.580002,75.919998,76.250000,76.250000,76.419998,76.750000,77,76.830002,76.330002,76.080002,75.830002,75.669998,75.330002,75,74.580002,74.169998,73.750000,73.330002,72.919998,72.500000,72,71.500000,71.080002,70.998413,70.916214,70.833405,70.750000,70.707787,70.665382,70.622787,70.580002,70.669998,70.830002,70.915504,71.000671,71.085503,71.169998,71.273163,71.375885,71.478172,71.580002,NaN,68.750000,69.250000,69.580002,69.250000,68.919998,68.750000,NaN,80.666672,80.674561,80.848717,80.937996,81.059013,81.268684,81.160622,81.042694,80.894043,80.774010,80.666672,NaN,80.391472,80.702095,80.824654,80.868927,80.800056,80.808655,80.896675,80.670044,80.557137,80.400421,80.488281,80.391472,NaN,79.872078,79.925812,79.982048,80.115242,80.277893,80.238792,80.181267,79.934357,79.872078,NaN,80.452332,80.427750,80.342857,80.198997,80.037498,80.104271,80.452332,NaN,80.800003,81.029999,81.029999,81.419998,81.750000,81.330002,81,80.800003,80.629997,80.800003,NaN,80.250000,80.500000,80.445274,80.390358,80.335266,80.279999,80.273415,80.266220,80.258415,80.250000,NaN,80.550003,80.900002,80.750000,80.550003,80.779999,80.669998,80.400002,80.120003,80.050003,80.169998,80.419998,80.419998,80.550003,NaN,79.750000,79.830002,79.669998,80.029999,79.919998,80.250000,80.500000,80.169998,80.419998,80.250000,80.250000,80.169998,79.870003,79.419998,79.169998,79.330002,79.699997,79.169998,78.830002,78.419998,78.080002,77.750000,77.250000,77.419998,77.919998,78.180000,78.629997,78.419998,78.029999,77.500000,77,76.500000,77.019997,77.500000,77.949997,78.018150,78.085876,78.153160,78.220001,78.221191,78.221588,78.221191,78.220001,78.699997,79.330002,79.750000,NaN,62.080002,62.299999,62.369999,62,62.080002,NaN,59.948502,60.077919,60.222084,60.386475,60.517910,60.298336,60.168674,59.948502,NaN,58.859596,58.939911,59.039680,59.190880,59.212067,58.982201,58.873478,58.859596,NaN,57.580002,57.830002,58.169998,58.500000,58,57.580002,NaN,55.470001,55.580002,55.369999,55.049999,55.049999,55.470001,NaN,55.700001,55.900002,56.099998,56.000019,55.900024,55.800018,55.700001,55.642628,55.585171,55.527630,55.470001,55.279999,55.130001,55.200001,55.700001,NaN,54.830002,54.919998,54.830002,54.669998,54.580002,54.830002,NaN,57.500000,57.779999,57.930000,57.700001,57.279999,57.080002,57.500000,NaN,58.330002,58.619999,58.500000,58.299999,58.099998,58.330002,NaN,58.880001,59.080002,58.830002,58.720001,58.880001,NaN,50.080002,50.419998,50.750000,51.169998,51.169998,51.169998,51.580002,51.330002,51.580002,51.669998,51.580002,51.642525,51.705032,51.767525,51.830002,51.892776,51.955368,52.017776,52.080002,52.250000,52.750000,52.750000,53.080002,53.330002,53.250000,53.330002,53.750000,54.169998,54.169998,54.500000,54.919998,54.750000,54.580002,54.665085,54.750111,54.835083,54.919998,55.065128,55.210171,55.355129,55.500000,55.582626,55.665173,55.747627,55.830002,55.830002,55.419998,55.750000,55.750000,56.080002,56.500000,56.330002,56.669998,57.169998,57.169998,57.419998,57.580002,57.419998,57.750000,58.080002,58.500000,58.500000,58.580002,58.330002,58,57.580002,57.669998,57.669998,57.669998,57.330002,57,56.580002,56.250000,56,56,55.830002,55.830002,55.500000,55,54.580002,54.419998,54,53.669998,53.419998,53.080002,52.830002,52.669998,52.919998,52.919998,52.750000,52.419998,52,51.750000,51.330002,51.250000,50.830002,50.669998,50.669998,50.750000,50.500000,50.669998,50.580002,50.169998,50.330002,50,50.080002,NaN,52.169998,52.169998,52.669998,53.169998,53.169998,53.500000,53.750000,53.919998,54.250000,54.250000,54.250000,54.500000,54.669998,55.080002,55.250000,55.169998,55.080002,54.750000,54.250000,53.919998,53.500000,53,52.580002,52.169998,52.080002,51.750000,51.580002,51.500000,51.750000,52.169998,NaN,42.500000,42.669998,43,42.500000,42.169998,41.830002,41.330002,41.750000,42.080002,42.500000,NaN,40.919998,40.830002,40.919998,41.250000,40.830002,40.419998,40,39.580002,39.169998,39.169998,38.830002,39.169998,39.669998,40.169998,40.580002,40.919998,NaN,37.919998,38.169998,38.169998,38,38,38.080002,38.250000,37.830002,37.330002,37,36.669998,36.750000,37.080002,37.169998,37.500000,37.500000,37.919998,NaN,37.750000,38.080002,38.250000,38.080002,37.830002,37.330002,37.419998,37,36.419998,36.750000,36.419998,36.750000,36.750000,37,37.419998,37.750000,NaN,35.169998,35.580002,35.500000,35.330002,35.419998,35.299999,35.330002,35.080002,35.250000,34.970001,34.930000,34.900002,35.080002,35.169998,35.169998,NaN,35,35.080002,35.250000,35.330002,35.419998,35.580002,35.169998,34.919998,34.919998,34.700001,34.580002,34.669998,35,NaN,39.580002,39.919998,39.669998,39.270000,39.500000,39.580002,NaN,36.169998,36.450001,36.080002,35.880001,36.169998,NaN,39.007397,39.047951,39.205967,39.103626,39.146931,39.217728,39.274357,39.377464,39.355274,39.136604,39.007397,NaN,38.257084,38.600403,38.567787,38.416481,38.284145,38.257084,NaN,38.512291,38.416687,38.383915,38.399979,38.465508,38.577908,38.512291,NaN,37.697292,37.738205,37.782978,37.924656,37.862782,37.895947,37.788044,37.697292,NaN,28.330000,28.379999,28.580000,28.170000,28,28.330000,NaN,28,28.170000,28.080000,27.830000,27.750000,28,NaN,28.833157,28.941154,29.043455,29.147875,29.137163,29.041817,28.833157,NaN,28.188606,28.359945,28.641903,28.455679,28.338778,28.188606,NaN,3.3299999,3.7500000,3.5799999,3.2500000,3.3299999,NaN,-34.169998,-33.580002,-33.500000,-33.250000,-32.919998,-32.330002,-31.750000,-31.420000,-31,-30.500000,-30,-29.500000,-29.080000,-28.580000,-28.080000,-27.670000,-27,-26.670000,-26.170000,-26.580000,-25.670000,-26.080000,-26.080000,-26.420000,-25.830000,-25.420000,-25,-24.420000,-23.920000,-23.500000,-23.080000,-22.670000,-22.250000,-21.830000,-22.330000,-21.920000,-21.670000,-21.500000,-21.080000,-20.830000,-20.670000,-20.670000,-20.670000,-20.330000,-20.330000,-20,-20,-19.830000,-19.750000,-19.420000,-19.080000,-18.580000,-18.170000,-18.170000,-17.830000,-17.420000,-17,-16.500000,-17.080000,-17.500000,-17,-16.670000,-16.170000,-16.420000,-16,-15.500000,-15.080000,-14.670000,-14.670000,-14.330000,-14.250000,-13.920000,-14,-14.420000,-14.750000,-15.250000,-14.920000,-14.920000,-15.250000,-14.830000,-14.500000,-14.080000,-13.670000,-13.580000,-13.580000,-13.170000,-12.750000,-12.330000,-12.330000,-12.330000,-12.205021,-12.080028,-11.955021,-11.830000,-11.727537,-11.625050,-11.522537,-11.420000,-11.460143,-11.500192,-11.540144,-11.580000,-11.920000,-12,-12.170000,-12.330000,-12.170000,-12.580000,-12.080000,-12.420000,-12.830000,-13.330000,-13.330000,-13.830000,-14.250000,-14.580000,-15,-15.330000,-15.500000,-16,-16,-16.330000,-16.580000,-16.830000,-16.830000,-17,-17.420000,-17.830000,-17.750000,-17.500000,-17,-16.580000,-16.080000,-15.580000,-15.080000,-14.580000,-14.080000,-13.580000,-13,-12.670000,-12.170000,-11.830000,-11.250000,-10.830000,-11.080000,-11.670000,-12.170000,-12.670000,-13.250000,-13.750000,-14.330000,-14.500000,-14.330000,-14.670000,-15,-15,-15.500000,-16,-16.580000,-17,-17.330000,-17.830000,-18.330000,-18.670000,-19,-19.330000,-19.420000,-19.830000,-20.170000,-20.420000,-20.830000,-21.080000,-21.420000,-21.920000,-22.420000,-22.080000,-22.420000,-22.670000,-23.170000,-23.580000,-23.920000,-24.080000,-24.580000,-25.080000,-25.500000,-26.080000,-26.080000,-26.500000,-27.080000,-27.580000,-28.170000,-28.670000,-29,-29.500000,-30,-30.580000,-31,-31.500000,-31.920000,-32.330002,-32.750000,-33,-33.419998,-33.830002,-34.330002,-34.919998,-35.250000,-35.750000,-36.250000,-36.750000,-37.169998,-37.580002,-37.830002,-37.830002,-37.919998,-38.080002,-38.419998,-38.419998,-38.669998,-39.169998,-38.919998,-38.669998,-38.250000,-38.419998,-37.830002,-38.250000,-38.500000,-38.830002,-38.669998,-38.419998,-38.330002,-38.250000,-38.419998,-38.080002,-38,-37.669998,-37.330002,-37,-36.750000,-36.330002,-35.919998,-35.580002,-35.669998,-35.419998,-35,-34.669998,-34.250000,-34.750000,-34.750000,-35.169998,-35.169998,-35.250000,-35,-34.830002,-34.500000,-34,-33.580002,-32.830002,-33.169998,-33.669998,-33.919998,-34.250000,-34.580002,-35,-34.580002,-34.169998,-33.750000,-33.250000,-33,-32.580002,-32.330002,-32.169998,-32,-32,-31.750000,-31.580000,-31.580000,-31.580000,-31.580000,-31.580000,-31.670000,-31.830000,-32.080002,-32.169998,-32.250000,-32.169998,-32.330002,-32.669998,-32.830002,-33,-33.500000,-33.830002,-33.830002,-33.830002,-33.830002,-33.830002,-33.830002,-33.919998,-34,-34.419998,-34.419998,-34.750000,-35,-35,-35,-35,-34.830002,-34.330002,-34.169998,NaN,-11.830000,-11.330000,-11.500000,-11.330000,-11.580000,-12,-11.830000,-11.830000,NaN,-35.919998,-35.750000,-35.669998,-35.919998,-36.169998,-36.169998,-35.919998,NaN,-40.669998,-40.830002,-41.169998,-41.169998,-41,-40.830002,-41,-41.500000,-42,-42.169998,-42.580002,-43.080002,-42.830002,-43.169998,-43.580002,-43.500000,-43.250000,-42.919998,-42.500000,-42.169998,-41.750000,-41.169998,-40.669998,NaN,-36.921432,-37.013824,-36.949623,-36.788486,-36.706081,-36.787884,-37.024902,-37.426277,-37.898804,-37.964458,-37.935249,-37.705379,-37.565189,-37.660568,-37.864277,-38.534275,-38.612968,-38.927704,-39.002041,-39.044811,-39.146229,-39.282467,-39.456154,-39.693077,-39.791309,-40.134537,-41.173149,-41.457249,-41.614918,-41.429008,-41.313484,-40.596809,-40.353436,-40.181389,-39.806709,-39.463078,-39.261368,-39.196835,-38.712940,-38.449120,-38.102776,-37.943024,-37.714756,-37.523201,-37.131695,-36.879608,-36.786057,-36.449959,-36.403111,-36.137440,-35.973015,-36.318542,-36.381416,-36.377792,-35.343845,-35.291740,-35.171700,-35.038254,-34.760109,-34.437622,-34.418064,-34.463402,-34.406933,-34.535267,-34.617863,-34.860382,-34.994087,-34.927326,-34.940552,-35.159733,-35.341850,-35.355145,-35.272354,-35.285645,-35.359615,-35.522106,-35.738503,-35.750603,-35.824627,-35.898689,-35.864883,-36.233055,-36.375332,-36.366734,-36.562893,-36.553856,-36.592037,-36.671444,-36.724110,-36.803658,-36.856396,-36.921432,NaN,-45.919998,-45.419998,-45.080002,-44.750000,-44.419998,-44.080002,-44,-43.669998,-43.330002,-43,-42.669998,-42.250000,-41.830002,-41.669998,-41.330002,-40.919998,-40.669998,-40.669998,-40.919998,-41.330002,-41.169998,-40.919998,-41.250000,-41.330002,-41.830002,-42.169998,-42.580002,-43,-43.169998,-43.500000,-43.750000,-43.750000,-44.080002,-44.330002,-44.669998,-45.080002,-45.500000,-45.919998,-46.250000,-46.500000,-46.669998,-46.500000,-46.419998,-46.169998,-46.250000,-46.169998,-45.919998,NaN,-47.330002,-46.669998,-47,-47.330002,NaN,5.6700001,5.6700001,5.3299999,5.3299999,5.2500000,4.9200001,4.5000000,4.0799999,4.0799999,3.7500000,3.5000000,3.1700001,2.6700001,2.1700001,2.2500000,1.7500000,1.6700000,1.1700000,1.0800000,0.57999998,0.57999998,0.17000000,-0.25000000,-0.67000002,-1,-1,-1.6700000,-1.9200000,-2.3299999,-2.3299999,-2.6700001,-3,-3.5000000,-4.1700001,-4.6700001,-5.2500000,-5.7500000,-5.5000000,-5.5000000,-5.5000000,-5.7500000,-5.5799999,-5.0799999,-4.7500000,-4.2500000,-3.8299999,-3.5000000,-3.1700001,-2.5799999,-2.0799999,-1.6700000,-1.0800000,-0.67000002,-0.25000000,0.079999998,0.33000001,1,1.5000000,1.8300000,2.1700001,2.4200001,2.9200001,3.3299999,3.7500000,3.8299999,4.3299999,4.7500000,5.1700001,5.6700001,NaN,-6.6700001,-6.3299999,-5.8299999,-6,-5.8299999,-5.9200001,-6.1700001,-6.2500000,-6.6700001,-6.7500000,-6.7500000,-6.8299999,-6.8299999,-6.3299999,-6.3299999,-6.5799999,-6.7500000,-6.8299999,-7.0799999,-7.5000000,-7.6700001,-7.5799999,-7.6700001,-8.1700001,-8.5799999,-8.5000000,-8.3299999,-8.1700001,-8.3299999,-8.1700001,-8.1700001,-8.0799999,-8,-7.7500000,-7.6700001,-7.6700001,-7.7500000,-7.6700001,-7.4200001,-7.3299999,-7.2500000,-7,-6.7500000,-6.6700001,NaN,-8.7399998,-8.3900003,-8.2500000,-8.1700001,-8.4099998,-8.7399998,NaN,-8.4110470,-8.3151369,-8.2385025,-8.1411238,-8.0469370,-8.0263233,-8.2045126,-8.1341209,-8.1775513,-8.2454967,-8.4523001,-8.2404766,-8.2229395,-8.3230343,-8.5166016,-8.4976616,-8.5448475,-8.7266922,-8.6348457,-8.6123552,-8.6409388,-8.7109280,-8.7943754,-8.7547894,-8.6307592,-8.6052217,-8.8526182,-8.8352709,-9.0462837,-9.0278111,-9.0882730,-9.0616369,-8.9773884,-8.8501873,-8.7288713,-8.6145573,-8.4295826,-8.4982643,-8.6251144,-8.6928034,-8.5719604,-8.5626955,-8.4766350,-8.4110470,NaN,-8.2171469,-8.3771772,-8.4804726,-8.7889194,-8.7721758,-8.9187975,-8.8424740,-8.9682970,-8.9854021,-8.7701921,-8.7537460,-8.4983110,-8.3880625,-8.2920265,-8.2122087,-8.2638912,-8.5106297,-8.6480007,-8.6523781,-8.5188379,-8.4761457,-8.5570879,-8.5031328,-8.4050694,-8.1727457,-8.0966759,-8.0496292,-8.0744686,-7.9754505,-7.9936333,-8.0806189,-8.2171469,NaN,-8.4803019,-8.3706894,-8.2522860,-8.2499104,-8.3513479,-8.4803019,NaN,-8.8850689,-8.8290844,-8.6812506,-8.4805346,-8.3283491,-8.2826900,-8.3790684,-8.8850689,NaN,-8.4200001,-8.0799999,-8.1226034,-8.1651373,-8.2076035,-8.2500000,-8.2926655,-8.3352203,-8.3776655,-8.4200001,NaN,-7.9200001,-7.5799999,-7.5000000,-7.9200001,-7.9200001,NaN,-9.4200001,-9.3299999,-9.3299999,-9.5799999,-10,-10.250000,-9.9200001,-9.7500000,-9.7500000,-9.4200001,NaN,-10.330000,-9.6700001,-9.3299999,-9.1700001,-9,-8.6700001,-8.5000000,-8.4200001,-8.3299999,-8.3299999,-8.6700001,-8.9200001,-9.0799999,-9.2500000,-9.5799999,-10.080000,-10.250000,-10.330000,NaN,-7.9200001,-7.4200001,-7.0799999,-7.5799999,-7.9200001,NaN,-6.9200001,-6.3299999,-5.8299999,-5.4200001,-5.9200001,-6.5000000,-6.9200001,NaN,-1.9200000,-1.5800000,-1.5000000,-2,-2.4200001,-2.5000000,-3,-2.6199999,-2.2500000,-2,-1.9200000,NaN,-3.0799999,-2.5000000,-2.6700001,-3.1700001,-3.0799999,NaN,-7.1794734,-7.1300364,-6.9800358,-6.9038091,-6.9218135,-6.8552661,-6.8919911,-7.1635327,-7.1794734,NaN,1,1.5800000,2,1.7500000,1.6700000,1.5800000,2.2500000,2.8299999,2.9200001,3,3.3299999,3.7500000,4.0799999,4.0799999,4.6700001,4.9200001,4.9200001,5.3299999,5.8299999,6.2500000,6.5799999,7,6.7500000,6.4200001,5.9200001,5.7500000,5.4200001,5.1700001,5,4.8299999,4.4200001,4.2500000,3.6700001,3.2500000,2.7500000,2.3299999,2,1.5800000,1.2500000,0.92000002,0.82999998,0.82999998,0.50000000,0,0,-0.57999998,-1,-1.3300000,-1.7500000,-2.2500000,-2.9200001,-3.4200001,-3.6700001,-3.9200001,-4.0799999,-3.6700001,-3.3299999,-3.4200001,-3.0799999,-3.3299999,-3.3299999,-3.5000000,-2.7500000,-2.9200001,-3,-2.9200001,-2.3299999,-1.7500000,-1.2500000,-0.75000000,-0.41999999,0.079999998,0.41999999,1,NaN,-2.8299999,-2.4200001,-1.9200000,-1.3300000,-0.92000002,-0.57999998,-0.079999998,0.41999999,0.75000000,0.75000000,1.3300000,1.1700000,1.0800000,1,0.82999998,0.92000002,0.92000002,1.1700000,1.5000000,1.7500000,1.7500000,1.5000000,1.0800000,0.57999998,0.41999999,0.33000001,0.50000000,0.50000000,0.50000000,0.50000000,0.41999999,0.50000000,0.41999999,-0.079999998,-0.67000002,-0.92000002,-1.3300000,-1.3300000,-0.92000002,-0.92000002,-0.75000000,-0.57999998,-0.92000002,-0.92000002,-1.3300000,-1.6700000,-1.9200000,-2.4200001,-2.7500000,-3.1700001,-3.5000000,-3.5000000,-3.8299999,-4.3299999,-4.7500000,-5.3299999,-5.6700001,-5.3299999,-4.5799999,-4.8299999,-4.6700001,-4.0799999,-3.8299999,-3.4200001,-3,-2.6700001,-2.6700001,-3,-3.5000000,-4,-4.5000000,-5,-5.5000000,-5.5799999,-5.5799999,-5.1700001,-4.5799999,-4,-3.5000000,-3.5000000,-2.8299999,NaN,1.0800000,1.5000000,1.9200000,2.1700001,1.7500000,1.3300000,1.5800000,1.0800000,0.82999998,0.50000000,0.50000000,0,-0.41999999,-0.92000002,-0.57999998,-0.17000000,0.25000000,0.67000002,0.77250153,0.87500209,0.97750163,1.0800000,NaN,-3.2500000,-3.0799999,-3.1700001,-3.5799999,-3.8299999,-3.6700001,-3.2500000,NaN,-3.1700001,-2.8299999,-2.8299999,-2.7500000,-3,-3,-3.4200001,-3.8299999,-3.5799999,-3.4200001,-3.3299999,-3.4200001,-3.1700001,NaN,-1.9717121,-1.9359668,-1.7305844,-1.6838264,-1.7835393,-1.8991468,-1.9717121,NaN,-1.6700000,-1.3300000,-1.6700000,-1.6700336,-1.6700449,-1.6700336,-1.6700000,NaN,-0.17000000,0,-0.25000000,-0.41999999,-0.17000000,NaN,-0.67000002,-0.67000002,-1.0800000,-1.1700000,-0.67000002,NaN,-1.3300000,-0.82999998,-0.82999998,-0.67000002,-0.33000001,-0.33000001,-0.67000002,-0.67000002,-1.3300000,-1.8300000,-2.3299999,-2.5000000,-3,-3.3299999,-3.3299999,-2.9200001,-2.5799999,-2.1700001,-2.0799999,-1.6700000,-1.4200000,-1.6700000,-2,-2.1700001,-2.3299999,-2.3299999,-2.5799999,-2.7500000,-2.9200001,-3.0799999,-3.3299999,-3.4200001,-3.6700001,-3.6700001,-3.9200001,-4.2500000,-4.5000000,-4.9200001,-5.5000000,-5.5799999,-5.9200001,-5.8299999,-6.1700001,-6.6700001,-6.7500000,-6.8299999,-7.2500000,-7.7500000,-8,-8.5799999,-9.0799999,-9,-9.4200001,-9.5799999,-9.5800476,-9.5800629,-9.5800476,-9.5799999,-9.6650171,-9.7500229,-9.8350172,-9.9200001,-9.9600496,-10.000066,-10.040050,-10.080000,-10.170000,-10.580000,-10.670000,-10.330000,-10.250000,-10.170000,-10.080000,-10.080000,-10,-9.6700001,-9.3299999,-8.9200001,-8.5000000,-8,-7.9200001,-7.6700001,-7.5000000,-7.5000000,-7.9200001,-8.1700001,-8.3299999,-8.7500000,-9,-9.2500000,-9.0799999,-9.0799999,-9,-8.6700001,-8.3299999,-8,-8.0799999,-8.0799999,-8.3299999,-8.3299999,-7.7500000,-7.3299999,-7.2500000,-6.7500000,-6.7500000,-6.1700001,-5.5799999,-5.2500000,-5,-4.8299999,-4.5799999,-4.4200001,-4.3299999,-4.0799999,-3.8299999,-3.5000000,-4,-4,-3.5799999,-3.2500000,-2.9200001,-2.8299999,-2.6700001,-2.7500000,-2.5000000,-2.5000000,-2,-2.1700001,-2.2500000,-2.2500000,-2,-1.5800000,-1.5000000,-1.3300000,NaN,16.250000,16.080000,16.580000,17.170000,17.580000,18,18.500000,18.580000,18.330000,18.250000,18.500000,17.920000,17.420000,17.335051,17.250067,17.165051,17.080000,16.955013,16.830017,16.705013,16.580000,16.170000,15.750000,15.750000,15.250000,14.580000,14.080000,13.920000,14.170000,14.170000,14,13.750000,13.670000,13.330000,12.920000,12.830000,13,13.580000,13.830000,13.500000,13.080000,13.670000,13.920000,13.580000,13.750000,14.170000,14.500000,14.750000,14.420000,14.750000,15.250000,15.670000,16.250000,NaN,8.4200001,8.9200001,9.2500000,9.6700001,10,10.500000,11.250000,10.500000,10.080000,9.9200001,9.4200001,9.0799999,8.7500000,8.4200001,NaN,13.420000,13.420000,13.330000,13,12.500000,12.170000,12.500000,13,13.420000,NaN,12.500000,12.420000,12.500000,12.080000,11.670000,11.080000,11.080000,10.670000,10.250000,10.170000,10.750000,10.830000,11.420000,11.330000,11.435009,11.540012,11.645009,11.750000,11.812582,11.875110,11.937583,12,12.500000,NaN,10.500000,10.920000,11.420000,11.830000,11.750000,11.500000,11.500000,10.920000,10.830000,10.420000,10.670000,11.080000,10.580000,10.170000,10.080000,9.6700001,9.5799999,9.9200001,9.5799999,9.7500000,9.2500000,9,9.3299999,9.4350166,9.5400219,9.6450167,9.7500000,9.8125467,9.8750620,9.9375467,10,10.420000,10.580000,10.500000,NaN,7.1700001,7.7500000,8,8.1700001,8.5000000,8.6700001,8.5000000,8.0799999,8.4200001,8.5000000,9,8.8299999,9.0799999,9.7500000,9.7500000,9.3299999,8.8299999,8.2500000,7.6700001,7.2500000,6.8299999,6.3299999,6.9200001,7.3299999,7,6.7500000,6.4200001,6.0799999,5.5799999,5.9200001,5.9200001,6.1700001,6.4200001,7,7.3299999,7.5799999,7.7500000,7.4200001,7.3299999,7.7500000,7.6700001,7.2500000,6.8299999,7.1700001,NaN,-5.5000000,-5.5799999,-5.5799999,-5.5000000,-5.5000000,-5.5000000,-4.9200001,-4.9200001,-4.1700001,-4.1700001,-4.6700001,-5,-5.5799999,-5.5799999,-6,-6.2500000,-6.2500000,-6.2500000,-6.1700001,-5.8299999,-5.7500000,-5.5000000,NaN,-2.2157667,-2.1872468,-2.1378863,-1.9867182,-1.9660025,-2.0770741,-2.2157667,NaN,-3.7363453,-4.1665597,-4.2837763,-4.6066051,-4.7454619,-4.7895365,-4.5577283,-4.2550659,-3.7363453,NaN,-3.4572217,-3.4508758,-3.0493569,-2.8361616,-2.7610548,-3.1060345,-3.3567128,-3.4318306,-3.4572217,NaN,-5.4200001,-5.5000000,-6.1700001,-6.5799999,-6.8299999,-6.5000000,-6,-5.4200001,NaN,-7.3080416,-7.3462715,-7.2619190,-6.7943072,-6.6768589,-6.8291655,-7.1162319,-7.3080416,NaN,-8.5310268,-8.5126076,-8.3321571,-8.2924633,-8.2996302,-8.0290079,-7.9699330,-7.9971528,-8.4167299,-8.5310268,NaN,-8.4731197,-7.8870869,-7.6792393,-7.5588923,-7.9647593,-8.2692528,-8.3581371,-8.4731197,NaN,-9.5151434,-9.1630964,-8.9218845,-8.5725803,-8.4711256,-8.4528770,-8.5359926,-9.5151434,NaN,-9.2500000,-9.3299999,-9.6700001,-9.9200001,-9.8299999,-9.8299999,-9.5000000,-9.2500000,NaN,-10.170000,-10.330000,-10.750000,-10.670000,-10.170000,NaN,-15.661796,-14.799587,-14.717137,-14.825510,-15.199539,-15.180332,-14.990297,-15.471173,-15.534534,-15.585616,-15.661796,NaN,-15.920000,-16.420000,-16.500000,-15.920000,NaN,-20.250000,-20.500000,-20.750000,-21.170000,-21.500000,-21.670000,-22,-22.330000,-22.330000,-22,-21.750000,-21.500000,-21.250000,-20.830000,-20.250000,NaN,-43.770000,-43.799999,-44.169998,-43.900002,-43.770000,NaN,-18,-17.580000,-17.330000,-17.330000,-17.580000,-18,-18.170000,-18.170000,-18,NaN,-16.580000,-16.420000,-16.170000,-16.500000,-16.670000,-16.670000,-16.920000,-16.580000,NaN,-17.469999,-17.530001,-17.830000,-17.730000,-17.469999,NaN,22.030001,22.219999,22.219999,21.900000,21.900000,22.030001,NaN,21.580000,21.719999,21.299999,21.299999,21.580000,NaN,21.213406,21.160763,21.042439,21.101700,21.213406,NaN,20.950001,20.900000,20.969999,20.730000,20.620001,20.570000,20.780001,20.950001,NaN,20.270000,20.150000,20.049999,19.920000,19.680000,19.520000,19.330000,19.270000,19.129999,18.930000,19.080000,19.350000,19.770000,19.950001,20.270000];
        coastlon = [-180,-178,-174,-170,-166,-163,-158,-152,-146,-147,-151,-153.50000,-153,-154,-154,-154,-154.50000,-153,-150,-146.50000,-145.50000,-148,-150,-152.50000,-155,-157,-157.25542,-157.50719,-157.75536,-158,-157.66580,-157.33273,-157.00079,-156.67000,-154.50000,-154.50000,-154.50000,-156.67000,-158,-158.33000,-158.67000,-157,-154,-153,-150.50000,-148,-146,-146,-146.33000,-146.67000,-144,-142,-140.67000,-140,-138.33000,-136.67000,-135.50000,-133,-132,-130.83000,-129.67000,-128,-127,-126.83000,-126.33000,-125.50000,-124.50000,-124.50000,-123.33000,-123.67000,-122.33000,-121.33000,-120,-120,-119.58419,-119.16723,-118.74915,-118.33000,-117.91502,-117.50000,-117.08498,-116.67000,-116.58561,-116.50082,-116.41561,-116.33000,-116.65982,-116.99306,-117.32978,-117.67000,-117.67000,-117.67000,-117.67000,-117.67000,-117.34308,-117.01085,-116.67319,-116.33000,-115.66772,-115.00352,-114.33755,-113.67000,-112.33000,-112.50000,-112.54350,-112.58631,-112.62848,-112.67000,-112.49999,-112.33167,-112.16502,-112,-111.50000,-111,-110.33000,-108.67000,-108.50000,-109.50000,-109.50000,-108.33000,-108,-108.50000,-107.50000,-106,-104.50000,-104.50000,-104.50000,-102.67000,-101.33000,-100,-99.500000,-101.33000,-100.67000,-101.50000,-101.50000,-100,-99,-100,-101.33000,-102.50000,-101.33000,-101.50000,-99.669998,-98.500000,-98,-97.500000,-97.500000,-96.330002,-96,-96,-97.500000,-98.500000,-99.669998,-100.00586,-100.33948,-100.67085,-101,-100.70552,-100.41235,-100.12051,-99.830002,-98.330002,-98.330002,-97,-95.669998,-95.669998,-94,-92.250000,-90.500000,-88.750000,-87,-85.500000,-84.330002,-83,-81.250000,-79.500000,-78.500000,-78.669998,-78,-76.500000,-75,-74,-74.500000,-73,-71.500000,-70,-68.500000,-67.500000,-67,-67,-67.500000,-67.500000,-68,-68,-68.500000,-68.500000,-67.330002,-66.669998,-67.330002,-66.830002,-66.830002,-67.500000,-67.500000,-68.500000,-69.250000,-69.330002,-68.669998,-67.830002,-67.669998,-67,-66.330002,-66.330002,-65.500000,-65.830002,-65,-64,-64,-63,-62.669998,-61.669998,-61.500000,-61,-59.669998,-58.830002,-58.830002,-58,-57.169998,-56.669998,-57.330002,-57.538609,-57.748146,-57.958607,-58.169998,-57.940002,-57.709999,-57.479996,-57.250000,-57.330002,-58.169998,-58.669998,-59,-59.669998,-60.500000,-61.330002,-62,-62.169998,-62.330002,-62.669998,-63.500000,-64,-63.669998,-64.669998,-65.330002,-65.500000,-65.333855,-65.166801,-64.998856,-64.830002,-64.953979,-65.078636,-65.203972,-65.330002,-65.206741,-65.082329,-64.956757,-64.830002,-63.669998,-62.669998,-62.330002,-62,-62,-61.500000,-61.669998,-61,-60.830002,-61.669998,-60.830002,-61,-60.711578,-60.420456,-60.126602,-59.830002,-59.913792,-59.998383,-60.083782,-60.169998,-61.500000,-61,-60.669998,-61.669998,-61.669998,-63,-63,-63.669998,-65.500000,-67.330002,-65,-62.500000,-60,-57.669998,-56,-53.669998,-51.669998,-49.330002,-47.669998,-44,-41,-41,-38.500000,-36.330002,-35,-33.330002,-31.670000,-30,-28.330000,-27,-26,-24,-23.670000,-22.330000,-20.670000,-19.330000,-17.670000,-16.330000,-14.670000,-13.500000,-12.330000,-11.330000,-11.170000,-12,-12.170000,-11.500000,-11,-10.500000,-9.7500000,-9,-8.6700001,-8.5000000,-8.5000000,-8.2056446,-7.9125228,-7.6206393,-7.3299999,-7.4158363,-7.5011115,-7.5858307,-7.6700001,-7.5838804,-7.4985142,-7.4138904,-7.3299999,-7.4158082,-7.5010743,-7.5858035,-7.6700001,-7.4593706,-7.2491584,-7.0393672,-6.8299999,-5.8299999,-5.8299999,-6,-4.5000000,-3,-3,-3.3299999,-2.5000000,-1.6700000,-1,-1.5000000,-0.67000002,0,1.3300000,2.6700001,3.5000000,4.6700001,6.3299999,7.3299999,8.6700001,10,11.330000,12.670000,14.330000,15.670000,15.670000,17,18.330000,20,21.500000,23,24.670000,25.330000,27,28.330000,30,31.330000,32,33.500000,33.330002,33.500000,34.330002,35,36,37,38.330002,38.669998,39.330002,39.830002,39.830002,40,41.330002,42,43.330002,44.500000,46,46,47,48.169998,48.500000,49.330002,49.830002,50.500000,50.169998,50.500000,51.500000,52.169998,53.669998,55.169998,56,57.169998,57.169998,56.330002,57,58,59,59.330002,60.669998,61.669998,62.669998,63.669998,65,66.330002,67.669998,68.669998,69.500000,69.500000,69.500000,70,70.500000,69.500000,69.830002,69.830002,70.669998,71.669998,71,72.330002,73.500000,74.500000,75.500000,76.169998,77.169998,78,78.330002,79,80.500000,81.669998,82.500000,83.669998,85,86.330002,87.669998,88.500000,89.669998,91,92,93,94,94,95,96,97,97.669998,98.500000,99.330002,100,100.67000,101.50000,102.67000,104,105,106,107,108,109,109.50000,110.33000,110.67000,110.67000,111.67000,112.67000,113.67000,114.50000,115.50000,116.50000,117.67000,119,120.33000,121.50000,121.50000,122.50000,123.33000,124.33000,124.83000,125.83000,126.50000,127,127.67000,128.33000,129,129.50000,130,130,130.83000,132,133.33000,134.33000,135.33000,136.33000,137.33000,138.33000,139.33000,140.50000,142,142.50000,143.33000,144.33000,144.33000,145,146,146,146.83000,147,148.33000,149,150.33000,151,151.50000,152.67000,154.33000,155,156,156.50000,157.50000,158.67000,160,161,161,161.17000,161.67000,162.17000,162.33000,163.33000,163.17000,164.67000,166,167.33000,168.67000,170,170.17000,171,171,170.17000,170.50000,169.67000,168.50000,167,167,166.67000,165.33000,165.33000,164.33000,163,162.67000,162.67000,163,163.33000,163.67000,163.67000,164.67000,164.99380,165.32332,165.65868,166,165.50259,165.00342,164.50253,164,161.50000,160,160,160,160.33000,160.33000,161,162.33000,164,166,166,168.50000,171.50000,176,180,NaN,166.33000,166.67000,168.17000,169.67000,168.17000,166.33000,NaN,-164,-161.67000,-160.67000,-160,-160,-161.67000,-163.67000,-163.67000,-163,-164,NaN,-150.17000,-148.17000,-147.92334,-147.67447,-147.42337,-147.17000,-147.49651,-147.82697,-148.16145,-148.50000,-150.17000,NaN,-76.169998,-74.669998,-73,-71.830002,-71,-70.669998,-71,-71.500000,-71.669998,-71.169998,-70.330002,-69.669998,-69.330002,-68.830002,-68.500000,-68.330002,-68.500000,-68.830002,-70,-71.500000,-73,-73.330002,-74.330002,-75,-76,-76.500000,-76.169998,NaN,-76.169998,-75.669998,-75.750000,-74.500000,-73.669998,-73.750000,-74,-75,-76.169998,NaN,-63.663330,-64.027328,-64.148842,-64.004364,-63.648201,-63.283825,-63.040352,-63.454205,-63.663330,NaN,-62.591366,-62.458946,-62.478111,-62.252499,-62.115147,-62.591366,NaN,-56.500000,-55.830002,-55.624752,-55.418011,-55.209766,-55,-55.249474,-55.499302,-55.749477,-56,-56.500000,NaN,-58.740822,-58.752163,-58.580429,-57.944485,-57.824783,-57.820793,-58.047646,-58.740822,NaN,-60.233433,-60.302536,-60.780682,-60.773098,-60.326569,-60.034283,-59.960518,-59.950951,-60.233433,NaN,-46.330002,-46,-45.752140,-45.502857,-45.252144,-45,-45.333035,-45.665722,-45.998051,-46.330002,NaN,-80.080002,-80,-79.330002,-78.830002,-79,-78.580002,-78.669998,-78.330002,-77.750000,-77.500000,-77.169998,-77.500000,-77.330002,-77.419998,-77.419998,-77.500000,-77.419998,-77.750000,-78.169998,-78.419998,-78.169998,-78.500000,-78.750000,-79.169998,-79.500000,-79.750000,-80.080002,-80.080002,-80.500000,-80.419998,-80.314941,-80.209915,-80.104942,-80,-80.125053,-80.250069,-80.375053,-80.500000,-80.919998,-81,-81.500000,-81.750000,-82.250000,-82.750000,-83,-83.250000,-83.750000,-83.669998,-84,-84.580002,-84.830002,-85.169998,-85.330002,-85.669998,-85.830002,-85.750000,-85.750000,-86.169998,-86.580002,-87,-87.330002,-87.414894,-87.499855,-87.584892,-87.669998,-87.584999,-87.500000,-87.415001,-87.330002,-87.414894,-87.499855,-87.584892,-87.669998,-87.669998,-87.830002,-88.419998,-88.830002,-89.330002,-89.750000,-90,-90.500000,-91,-91.500000,-92,-92.330002,-92.750000,-93.169998,-93.419998,-93.830002,-94.250000,-94.669998,-95.169998,-95.669998,-96.250000,-96.830002,-97.419998,-98,-98.500000,-99,-99.500000,-100,-100.50000,-101,-101.58000,-101.58000,-102,-102.25000,-102.83000,-103.50000,-103.83000,-104.33000,-104.92000,-105.33000,-105.67000,-105.33000,-105.50000,-105.17000,-105.17000,-105.50000,-105.67000,-106,-106.42000,-106.75000,-107.17000,-107.58000,-108,-108.33000,-109,-109.42000,-109.42000,-109.25000,-109.50000,-109.75000,-110,-110.58000,-110.58000,-110.58000,-111.17000,-111.67000,-112.17000,-112.42000,-112.75000,-112.83000,-113.08000,-113.08000,-113.50000,-113.83000,-114.17000,-114.75000,-114.83000,-114.75000,-114.58000,-114.67000,-114.42000,-114,-113.67000,-113.25000,-112.92000,-112.75000,-112.33000,-112,-111.50000,-111.33000,-111,-111,-110.67000,-110.67000,-110.83000,-110.58000,-110.17000,-109.75000,-109.42000,-110,-110.33000,-110.83000,-111.25000,-111.67000,-112.33000,-112.08000,-112.08000,-112.33000,-112.83000,-113.17000,-113.58000,-114,-114.33000,-114.50000,-115,-114.42000,-114,-114,-114.33000,-114.67000,-115.17000,-115.67000,-115.75000,-116,-116,-116,-116.33000,-116.33000,-116.58000,-116.75000,-117.08000,-117.25000,-117.50000,-118,-118.33000,-118.42000,-118.75000,-119.25000,-119.83000,-120.58000,-120.58000,-121.08000,-121.42000,-121.92000,-121.83000,-121.83000,-122.17000,-122.42000,-122.50000,-122.08000,-122.33000,-122.17000,-122.50000,-122.50000,-123,-123,-122.92000,-123.33000,-123.67000,-123.75000,-123.75000,-124,-124.33000,-124.33000,-124.08000,-124,-124.17000,-124.42000,-124.50000,-124.25000,-124.08000,-124,-124,-123.83000,-123.92000,-123.92000,-123.17000,-123.92000,-124,-124.08000,-124.33000,-124.58000,-124.75000,-124.67000,-123.83000,-123.17000,-123.17000,-122.58000,-123,-122.58000,-122.50000,-122.25000,-122.33199,-122.41432,-122.49699,-122.58000,-122.54009,-122.50013,-122.46010,-122.42000,-122.50198,-122.58431,-122.66698,-122.75000,-123.17000,-123.17000,-123.75000,-124.33000,-124.92000,-125.50000,-126.25000,-127,-127.75000,-127.75000,-128.17000,-128.42000,-129.17000,-129.75000,-130.33000,-130.75000,-130.17000,-130.42000,-130.08000,-130.75000,-131.33000,-131.75000,-131.75000,-132.08000,-132,-132.50000,-133,-132.58000,-132.08000,-132.08000,-132.50000,-133.08000,-133.42000,-133.67000,-133.67000,-134.17000,-134.33000,-133.83000,-133,-133.42000,-133.75000,-134,-134.50000,-134.50000,-134.75000,-134.67000,-135,-135.17000,-135.67000,-135,-135,-134.75000,-134.75000,-134.75000,-135.17000,-135.50000,-136.17000,-136.50000,-137.25000,-137.92000,-138.67000,-139.50000,-139.67000,-140.25000,-141.08000,-142,-143,-144,-145,-146,-146.67000,-147.50000,-148.33000,-148.17000,-148.67000,-149.50000,-150.17000,-150.92000,-151.92000,-151.42000,-151.92000,-151.42000,-151.33000,-150.42000,-150.42000,-150.29597,-150.17131,-150.04597,-149.92000,-150.10750,-150.29500,-150.48250,-150.67000,-151.67000,-152.25000,-152.50000,-153.08000,-153.83000,-154.08000,-153.33000,-153.83000,-154.33000,-155.25000,-156.17000,-156.67000,-157.67000,-158.42000,-158.75000,-159.58000,-160.50000,-161.42000,-162,-162.83000,-163.67000,-164.75000,-164.92000,-163.92000,-162.92000,-162.33000,-161.42000,-160.50000,-160.50000,-159.92000,-159,-158.33000,-157.67000,-157.50000,-157.42000,-158,-158.67000,-158.92000,-159.58000,-161,-161.58000,-161.92000,-161.67000,-162.17000,-163,-163.83000,-164.33000,-164.92000,-165.25000,-166,-165.50000,-164.83000,-164.67000,-163.92000,-163,-162.25000,-161,-160.75000,-161.25000,-161.25000,-161,-161.92000,-162.67000,-163.67000,-164.92000,-166.33000,-166.67000,-166.33000,-167.25000,-167.39433,-167.53911,-167.68433,-167.83000,-167.58305,-167.33408,-167.08307,-166.83000,-165.75000,-164.67000,-163.83000,-163.75000,-162.17000,-161.75000,-162.50000,-163.50000,-164,-165.25000,-166.17000,-166,-164.83000,-163.50000,-163,-162.67000,-161.58000,-160.42000,-159,-159,-157.58000,-156.33000,-154.83000,-154.33000,-152.50000,-151.50000,-150.33000,-149,-147.50000,-146.17000,-145.08000,-144,-142.83000,-141.83000,-141,-139.50000,-138.33000,-137.33000,-136,-135.92000,-135.17000,-134.17000,-133.33000,-132.58000,-131.17000,-129.83000,-129.42000,-128.50000,-128,-126.67000,-126.67000,-126.17000,-125.33000,-124.42000,-124.33000,-123.50000,-123,-121.33000,-120.25000,-118.83000,-117.50000,-116,-114.67000,-114.08000,-115.08000,-115.33000,-114.17000,-113,-111.58000,-110.25000,-109.25000,-108.17000,-107.83000,-109,-108.25000,-106.92000,-105.67000,-104.58000,-103,-101.75000,-100,-100,-98.750000,-98.669998,-98,-99.580002,-98.580002,-97.919998,-96.419998,-95.580002,-96.919998,-96.830002,-95.830002,-95.500000,-95.169998,-94.250000,-94.669998,-94,-95.669998,-96.750000,-96.250000,-95.830002,-95,-95,-95,-95.250000,-95.580002,-95.169998,-93.169998,-91.169998,-90.169998,-90.669998,-90.669998,-91.330002,-91.919998,-93.080002,-94,-93.500000,-94.169998,-93.500000,-92.669998,-91.919998,-91.330002,-92.419998,-91.330002,-90.669998,-89.919998,-88.919998,-88,-88,-88.169998,-87.250000,-86.500000,-86.500000,-85.419998,-85.419998,-85.500000,-85.500000,-84.250000,-82.919998,-82.750000,-81.330002,-81.330002,-81.330002,-82.419998,-82.419998,-81.169998,-81.419998,-82.669998,-83.750000,-85.080002,-85.500000,-86.750000,-86,-87,-87,-87.750000,-88.500000,-90,-90.669998,-90.580002,-91.580002,-92.500000,-92.500000,-93.169998,-93.669998,-94.169998,-94.419998,-94.669998,-94.750000,-94.750000,-94.419998,-93.750000,-93.080002,-93.080002,-92.669998,-92.669998,-92.330002,-92.330002,-91.750000,-91,-90,-89,-88.080002,-87.933807,-87.788414,-87.643814,-87.500000,-87.331947,-87.164268,-86.996948,-86.830002,-86,-85,-84,-83,-82.169998,-82.419998,-82.169998,-82.169998,-82.330002,-81.669998,-81.250000,-80.750000,-80.419998,-79.750000,-79.830002,-79,-78.419998,-78.830002,-78.830002,-78.830002,-78.919998,-79.169998,-79.500000,-78.750000,-78,-77.250000,-76.750000,-76.750000,-77,-77.169998,-77.500000,-78.080002,-78.669998,-78.580002,-77.919998,-77.419998,-77.419998,-77.580002,-78.080002,-77.750000,-77.688110,-77.625816,-77.563118,-77.500000,-77.644119,-77.788826,-77.934120,-78.080002,-78.080002,-77.419998,-76.419998,-75.500000,-74.830002,-73.669998,-72.919998,-72.250000,-72.250000,-71.500000,-71.750000,-71,-70.250000,-69.500000,-69.669998,-69.419998,-69.500000,-69.500000,-69,-68.419998,-67.750000,-66.750000,-66.419998,-65.669998,-65.250000,-65.580002,-65.169998,-64.669998,-64.330002,-63.830002,-63.250000,-62.830002,-62.330002,-61.830002,-61.830002,-61.330002,-61.750000,-61.750000,-61.330002,-61.330002,-60.500000,-60.330002,-59.250000,-58.919998,-58,-57.874424,-57.749233,-57.624424,-57.500000,-57.708752,-57.916664,-58.123749,-58.330002,-58.079597,-57.829456,-57.579590,-57.330002,-57.250000,-56.500000,-55.830002,-56,-55.669998,-56.169998,-56.830002,-57.830002,-58.669998,-59.080002,-59.500000,-60,-60.919998,-61.669998,-62.169998,-62.830002,-63.419998,-64,-64.750000,-65.419998,-66,-66.750000,-66.750000,-67.169998,-67.330002,-68,-68.669998,-69.250000,-69.669998,-70,-70.419998,-70.750000,-71.169998,-70.500000,-70.080002,-69.669998,-69.250000,-68.669998,-68,-67.419998,-66.750000,-66,-65.250000,-64.580002,-64.250000,-64.250000,-64.830002,-65.330002,-66.330002,-65.669998,-64.830002,-65,-64.919998,-64.919998,-64.580002,-64,-63.250000,-62.580002,-62,-61.500000,-61.500000,-61,-60.669998,-60.419998,-60.500000,-60.331745,-60.163994,-59.996746,-59.830002,-59.978157,-60.125874,-60.273155,-60.419998,-61,-61.169998,-62,-63,-63.669998,-64.169998,-64.500000,-65,-65.500000,-66,-66.169998,-65.919998,-65.330002,-64.919998,-64.250000,-64.919998,-64.830002,-64.830002,-65.580002,-66.250000,-67,-67,-67.500000,-68,-68.580002,-68.830002,-69.169998,-69.750000,-70.250000,-70.250000,-70.580002,-70.830002,-70.750000,-71,-70.669998,-70.500000,-70,-70.040001,-69.930000,-70.669998,-70.669998,-71.080002,-71.330002,-71.500000,-72,-72.500000,-73,-73.500000,-73.500000,-74,-74.330002,-74,-74.169998,-74.500000,-75,-75.250000,-75.580002,-75.419998,-75.314362,-75.209145,-75.104362,-75,-75.062660,-75.125214,-75.187660,-75.250000,-75.580002,-75.750000,-76,-75.830002,-75.669998,-76,-75.919998,-76.330002,-76.169998,-76.169998,-76,-76.419998,-76.580002,-76.500000,-76.419998,-76.919998,-76.330002,-76.419998,-76.419998,-76.419998,-76,-75.830002,-75.660004,-75.529999,-75.910004,-76,-76.330002,-76.750000,-76.250000,-75.830002,-75.830002,-76,-76.330002,-76.830002,-76.330002,-76.580002,-77.169998,-77.580002,-78,-78.419998,-78.919998,-79.169998,-79.500000,-80,-80.500000,-81,-81.250000,-81.500000,-81.419998,-81.330002,-81.330002,-81.080002,-80.919998,-80.580002,-80.580002,-80.330002,-80.080002,-80.080002,-80.169998,-80.419998,-80.669998,-81.080002,-81.250000,-81.669998,-81.919998,-82.169998,-82.500000,-82.519951,-82.539940,-82.559952,-82.580002,-82.540138,-82.500183,-82.460136,-82.419998,-82.502548,-82.585068,-82.667549,-82.750000,-82.750000,-82.669998,-82.830002,-83.080002,-83.500000,-83.919998,-84.419998,-84.830002,-85.330002,-85.500000,-86,-86,-86.330002,-86.830002,-87.330002,-87.830002,-88,-88.250000,-88.750000,-89.169998,-89.669998,-90.169998,-90.419998,-90.080002,-89.669998,-89.250000,-89.330002,-89.580002,-89.580002,-89.080002,-89.250000,-89.500000,-89.830002,-90.169998,-90.750000,-91.250000,-91.330002,-91.830002,-92.250000,-92.750000,-93.250000,-93.830002,-93.830002,-94.250000,-94.750000,-94.750000,-94.832596,-94.915131,-94.997597,-95.080002,-95.017303,-94.954742,-94.892303,-94.830002,-94.915154,-95.000206,-95.085152,-95.169998,-95.500000,-96,-96.500000,-97,-97.330002,-97.419998,-97.250000,-97.250000,-97.169998,-97.419998,-97.580002,-97.750000,-97.750000,-97.750000,-97.750000,-97.919998,-97.750000,-97.250000,-97.419998,-97.250000,-97,-96.669998,-96.419998,-96.169998,-96.169998,-95.830002,-95.330002,-94.830002,-94.500000,-94.169998,-93.580002,-93,-92.419998,-91.830002,-91.830002,-91.250000,-91.330002,-91,-90.669998,-90.669998,-90.500000,-90.419998,-90.330002,-90,-89.500000,-89,-88.500000,-88,-87.580002,-87.080002,-86.830002,-86.830002,-87.250000,-87.419998,-87.440048,-87.460060,-87.480049,-87.500000,-87.500000,-87.500000,-87.500000,-87.500000,-87.520042,-87.540062,-87.560043,-87.580002,-87.669998,-87.919998,-88.169998,-88.250000,-88.250000,-88.500000,-89,-88.580002,-88.169998,-87.580002,-87,-86.500000,-86,-85.500000,-85,-84.669998,-84.250000,-83.830002,-83.419998,-83.250000,-83.250000,-83.500000,-83.500000,-83.500000,-83.669998,-83.669998,-83.830002,-83.669998,-83.419998,-83.419998,-83.169998,-82.750000,-82.330002,-82.169998,-81.750000,-81.419998,-80.830002,-80.330002,-79.830002,-79.580002,-79.080002,-78.669998,-78.250000,-77.830002,-77.500000,-77.169998,-76.750000,-76.750000,-76.250000,-76,-75.580002,-75.580002,-75.500000,-75.250000,-74.830002,-74.419998,-74.169998,-73.500000,-73,-72.669998,-72.669998,-72.250000,-72,-71.669998,-71.330002,-71.169998,-71.419998,-71.919998,-71.669998,-71.500000,-71.750000,-72,-71.750000,-71.669998,-71.080002,-71.080002,-71.419998,-71.419998,-71,-70.580002,-70.169998,-70.330002,-69.919998,-69.750000,-69.330002,-68.830002,-68.419998,-68.330002,-68.169998,-67.580002,-67,-67,-66.580002,-66.169998,-66,-65.580002,-65,-64.500000,-64,-63.419998,-62.750000,-62.605000,-62.459999,-62.314999,-62.169998,-62.377586,-62.585114,-62.792587,-63,-62.669998,-62.330002,-62,-61.580002,-61,-60.830002,-61,-60.250000,-59.669998,-59.169998,-58.669998,-58.500000,-58.580002,-58.169998,-57.669998,-57.330002,-57.080002,-56.500000,-56,-56,-55.500000,-55,-54.500000,-54,-53.669998,-53.250000,-52.750000,-52.330002,-51.830002,-51.500000,-51,-51,-50.669998,-50.500000,-49.919998,-50,-50.419998,-50.750000,-51.169998,-51.330002,-51.419998,-50.830002,-50.580002,-50.419998,-50.419998,-50,-49.500000,-49,-48.419998,-48.580002,-48.580002,-48.750000,-48.500000,-48.169998,-47.830002,-47.250000,-46.669998,-46.169998,-45.500000,-45.330002,-44.830002,-44.669998,-44.419998,-44.580002,-44,-43.500000,-43,-42.500000,-42,-41.500000,-41,-40.500000,-40,-39.500000,-39,-38.500000,-38.169998,-37.830002,-37.330002,-37,-36.500000,-36.500000,-36,-35.419998,-35.169998,-35,-34.830002,-34.750000,-34.830002,-35.080002,-35.330002,-35.580002,-36,-36.250000,-36.750000,-37,-37.330002,-37.580002,-38,-38.419998,-38.919998,-39,-39.080002,-39,-39,-38.919998,-39.080002,-39.169998,-39.169998,-39.500000,-39.580002,-39.580002,-39.580002,-39.669998,-40.169998,-40.330002,-40.830002,-41,-41,-41.500000,-42,-42,-42.500000,-43,-43.500000,-44,-44.669998,-44.500000,-45,-45.419998,-45.750000,-46.330002,-46.830002,-47.250000,-47.750000,-48.169998,-48.580002,-48.580002,-48.580002,-48.500000,-48.580002,-48.750000,-49,-49,-49.419998,-49.830002,-50.169998,-50.330002,-50.669998,-51,-51.500000,-52,-52.419998,-52.580002,-53,-53.500000,-53.580002,-54,-54.500000,-55,-55.669998,-56.250000,-56.830002,-57.169998,-57.830002,-58.330002,-58.500000,-58.330002,-57.500000,-57.169998,-57.419998,-57.169998,-56.750000,-56.669998,-56.669998,-57,-57.419998,-57.580002,-58.169998,-58.669998,-59.330002,-60,-60.500000,-61.250000,-62,-62.250000,-62.330002,-62,-62.169998,-62.419998,-62.250000,-62.330002,-63,-63.830002,-64.330002,-64.830002,-64.914757,-64.999680,-65.084763,-65.169998,-65.127747,-65.085327,-65.042747,-65,-65,-64.500000,-63.750000,-63.580002,-63.669998,-64.169998,-64.500000,-64.500000,-65,-64.330002,-65,-65.250000,-65.169998,-65.169998,-65.580002,-65.580002,-66.169998,-66.830002,-67.169998,-67.500000,-67.419998,-67,-66.500000,-65.750000,-65.669998,-65.830002,-66.330002,-67,-67.500000,-67.669998,-67.830002,-68.500000,-69,-69.169998,-69,-68.830002,-68.330002,-69,-69,-69.500000,-69.580002,-70,-70.750000,-70.919998,-70.919998,-71.250000,-72,-72.250000,-71.330002,-71.080002,-71.500000,-72,-72.500000,-73.169998,-73.500000,-73.500000,-74,-74.169998,-74.500000,-75,-75,-74.330002,-74.169998,-74.330002,-74.500000,-74.706650,-74.913864,-75.121651,-75.330002,-75.246948,-75.164261,-75.081947,-75,-74.830002,-74.500000,-74.500000,-74.669998,-74.500000,-75.330002,-75.330002,-75.247177,-75.164574,-75.082176,-75,-75.125175,-75.250237,-75.375175,-75.500000,-75.419998,-75.580002,-75.419998,-75.419998,-75.330002,-74.919998,-74.500000,-74.500000,-74.419998,-74,-74.500000,-75,-75.500000,-75.500000,-74.750000,-75,-74.500000,-74.669998,-74.500000,-74.330002,-74.500000,-74.250000,-73.830002,-73.500000,-73.500000,-73.669998,-73.580002,-73.830002,-73.669998,-73.580002,-73.330002,-73.419998,-73,-73.169998,-72.830002,-73,-72.750000,-72.750000,-72.687378,-72.624840,-72.562378,-72.500000,-72.562622,-72.625168,-72.687622,-72.750000,-72.687256,-72.624680,-72.562256,-72.500000,-72.625244,-72.750328,-72.875244,-73,-73.169998,-73.580002,-73.750000,-73.830002,-73.669998,-73.669998,-73.250000,-73.330002,-73.419998,-73.419998,-73.669998,-73.500000,-73.080002,-73.080002,-73.080002,-72.830002,-72.669998,-72.500000,-72.169998,-71.919998,-71.830002,-71.580002,-71.669998,-71.330002,-71.500000,-71.500000,-71.580002,-71.669998,-71.580002,-71.250000,-71.330002,-71.500000,-71.250000,-71.169998,-70.919998,-70.919998,-70.580002,-70.750000,-70.500000,-70.500000,-70.580002,-70.500000,-70.500000,-70.500000,-70.500000,-70.250000,-70.169998,-70.080002,-70.169998,-70.169998,-70.080002,-70.250000,-70.330002,-70.330002,-70.830002,-71.169998,-71.500000,-72,-72.500000,-72.830002,-73.500000,-74,-74.500000,-75.169998,-75.500000,-75.830002,-76.250000,-76.169998,-76.500000,-76.669998,-77,-77.169998,-77.500000,-77.669998,-78.169998,-78.169998,-78.330002,-78.500000,-78.669998,-79,-79.500000,-79.669998,-80,-80.330002,-80.830002,-81.169998,-80.830002,-81.169998,-81.330002,-81.330002,-80.830002,-80.330002,-80,-79.830002,-79.669998,-80.080002,-80.169998,-80.580002,-80.919998,-80.750000,-80.750000,-80.919998,-80.500000,-80.500000,-80.080002,NaN,-125.08000,-123.58000,-122,-121,-122,-122.75000,-123.25000,-121.75000,-121.58000,-120.67000,-120.50000,-121,-119.33000,-120,-118.42000,-118.08000,-117.67000,-119.08000,-119.43404,-119.78873,-120.14405,-120.50000,-120.31391,-120.12688,-119.93892,-119.75000,-118.92000,-120,-121.33000,-122.67000,-123.83000,-125.08000,NaN,-117,-116,-115.25000,-114.42000,-113.92000,-113.75000,-112.92000,-112.17000,-111.75000,-110.92000,-110.64812,-110.37582,-110.10311,-109.83000,-109.91447,-109.99928,-110.08447,-110.17000,-109.87750,-109.58500,-109.29250,-109,-110,-110.75000,-111.58000,-111.92000,-112.42000,-113.08000,-113.83000,-114.17000,-115.33000,-115.08000,-114.93378,-114.78838,-114.64379,-114.50000,-114.68787,-114.87549,-115.06287,-115.25000,-115.33000,-115.83000,-117,NaN,-111.25000,-110.33000,-110,-109.25000,-108.25000,-108.04327,-107.83603,-107.62827,-107.42000,-107.56445,-107.70927,-107.85445,-108,-108.58000,-109.17000,-109.67000,-110.17000,-110.67000,-111.25000,NaN,-103.08000,-102.17000,-102.17000,-102.17000,-101.58000,-102.08000,-102.50000,-102.58306,-102.66575,-102.74806,-102.83000,-102.74680,-102.66406,-102.58179,-102.50000,-102.56291,-102.62555,-102.68791,-102.75000,-103.08000,NaN,-99.250000,-98.919998,-98.669998,-98.169998,-98.169998,-97.419998,-97.330002,-96.830002,-96.919998,-97,-97,-96.419998,-96.169998,-96.580002,-97,-97.250000,-97.580002,-97.830002,-98.419998,-99,-99.250000,NaN,-92.080002,-91.580002,-90.919998,-90.500000,-89.750000,-89,-88.250000,-87.750000,-88.419998,-88.419998,-87.750000,-87.330002,-86.669998,-85.830002,-85,-85,-84.875000,-84.750000,-84.625000,-84.500000,-84.562134,-84.624512,-84.687134,-84.750000,-84.669998,-85,-85,-85.750000,-86.169998,-86.500000,-87.330002,-88.080002,-88.419998,-89.080002,-89.419998,-89.830002,-89.830002,-90.500000,-91,-91.580002,-92.080002,NaN,-88,-87.813324,-87.626106,-87.438332,-87.250000,-87.312843,-87.375450,-87.437836,-87.500000,-87.520088,-87.540115,-87.560081,-87.580002,-87.750000,-87.919998,-87.830002,-87.830002,-87.747017,-87.664352,-87.582016,-87.500000,-87.394997,-87.290001,-87.184998,-87.080002,-86.669998,-86.419998,-86.250000,-86.330002,-86.500000,-86.500000,-86.250000,-86.080002,-85.330002,-85,-84.875000,-84.750000,-84.625000,-84.500000,-84.394760,-84.289680,-84.184761,-84.080002,-83.580002,-83.330002,-83.330002,-83.830002,-83.830002,-83.419998,-82.919998,-82.669998,-82.669998,-82.419998,-81.750000,-81.750000,-81.500000,-81.330002,-81.500000,-80.919998,-80.080002,-79.997849,-79.915466,-79.832855,-79.750000,-79.874031,-79.998711,-80.124031,-80.250000,-80.750000,-81.669998,-82.330002,-83,-83.669998,-84.169998,-84,-84.830002,-85.250000,-85.750000,-86.750000,-87,-87.330002,-87.669998,-88,NaN,-83.080002,-82.330002,-81.750000,-81.919998,-82.419998,-83.080002,NaN,-83.500000,-82.830002,-82.250000,-81.669998,-81.080002,-80.500000,-79.830002,-79.250000,-78.830002,-79.500000,-80.169998,-80.500000,-80.919998,-81.500000,-81.830002,-82.500000,-83.080002,-83.500000,NaN,-79.750000,-79.250000,-78.580002,-78,-77.419998,-76.830002,-76.169998,-76.250000,-76.080002,-76.669998,-77,-77.669998,-78.169998,-78.830002,-79.419998,-79.750000,NaN,-91.419998,-91.080002,-90.830002,-91.169998,-91.500000,-91.169998,-91.500000,-91.419998,NaN,-74,-73.419998,-73.330002,-73.669998,-73.500000,-73.750000,-74.330002,-74.169998,-74.169998,-74,NaN,-68.750000,-68.250000,-68.169998,-68,-67.419998,-66.750000,-66.330002,-65.830002,-65.169998,-65.250000,-65.669998,-66.500000,-67.330002,-68.169998,-68,-68.669998,-69.330002,-69.830002,-70,-70.500000,-71.169998,-72,-72,-72,-72.500000,-72.669998,-73.330002,-73.330002,-73.830002,-73.500000,-74,-74.500000,-74.669998,-74,-73.330002,-72.500000,-72.080002,-71.330002,-71,-70.500000,-70.330002,-70.247620,-70.165161,-70.082619,-70,-70.020180,-70.040237,-70.060181,-70.080002,-69.891670,-69.703888,-69.516670,-69.330002,-69.419998,-70.169998,-70.419998,-70.250000,-69.750000,-69.500000,-69.169998,-68.750000,NaN,-61.169998,-60.500000,-60.169998,-60.500000,-59.669998,-59,-58.330002,-57.750000,-57.750000,-58.500000,-58.830002,-59.500000,-59.669998,-60,-60.500000,-61.169998,NaN,-38,-37,-36.250000,-35.830002,-36,-36.580002,-37.250000,-38,NaN,-61.830002,-61.500000,-61.500000,-61.669998,-61,-61,-61.250000,-61.830002,NaN,-78.330002,-78.250000,-77.830002,-77.330002,-76.830002,-76.419998,-76.250000,-76.580002,-76.919998,-77.250000,-77.669998,-78,-78.330002,NaN,-83.070000,-82.870003,-82.650002,-82.612442,-82.574928,-82.537445,-82.500000,-82.582542,-82.665054,-82.747543,-82.830002,-83.050003,-82.949997,-83.070000,NaN,-84.830002,-84.330002,-84.330002,-84,-83.500000,-83,-82.500000,-82,-81.500000,-81,-80.500000,-80.080002,-79.669998,-79.330002,-78.830002,-78.330002,-77.830002,-77.419998,-77,-76.500000,-76,-75.580002,-75.669998,-75.330002,-74.830002,-74.500000,-74.250000,-74.169998,-74.169998,-74.669998,-75,-75.500000,-76,-76.500000,-77,-77.167503,-77.334999,-77.502502,-77.669998,-77.607574,-77.545097,-77.482574,-77.419998,-77.080002,-77.250000,-78,-78.500000,-78.580002,-78.750000,-79.250000,-79.750000,-80.169998,-80.500000,-81.250000,-81.750000,-82.080002,-81.580002,-82.250000,-82.750000,-83.080002,-83.419998,-84,-84.042580,-84.085098,-84.127579,-84.169998,-84.334999,-84.500000,-84.665001,-84.830002,NaN,-74.500000,-74.169998,-73.669998,-73.250000,-72.750000,-72.645111,-72.540154,-72.435112,-72.330002,-72.434807,-72.539742,-72.644806,-72.750000,-72.750000,-73,-73,-73.500000,-73.169998,-72.580002,-72,-71.669998,-71,-70.500000,-69.919998,-69.750000,-69.169998,-69.580002,-68.750000,-68.330002,-68.669998,-69,-69.500000,-70.080002,-70.580002,-70.580002,-71.080002,-71.080002,-71.419998,-71.830002,-72.330002,-72.750000,-73.169998,-73.669998,-73.830002,-74.500000,NaN,-67.169998,-67.169998,-66.580002,-66,-65.669998,-65.919998,-66.330002,-66.750000,-67.169998,NaN,-61.751938,-61.552059,-61.543957,-61.494724,-61.427563,-61.391785,-61.189819,-61.463997,-61.594345,-61.566128,-61.691929,-61.760193,-61.790493,-61.751938,NaN,-60.951080,-61.141327,-61.121338,-60.978741,-60.830997,-60.749863,-60.951080,NaN,-78.250000,-78,-77.750000,-77.750000,-77.687378,-77.624840,-77.562378,-77.500000,-77.542580,-77.585106,-77.627579,-77.669998,-77.919998,-78.419998,-78.169998,-78.250000,NaN,-73.669998,-73.500000,-73.169998,-73,-73.169998,-73.669998,NaN,-78.788040,-78.680023,-78.575752,-78.522217,-77.900017,-77.869293,-78.237938,-78.725670,-78.788040,NaN,-77.870705,-77.772308,-77.553215,-77.044395,-76.967758,-77.127869,-77.183792,-77.240105,-77.385902,-77.225426,-77.262589,-77.220886,-77.237236,-77.145256,-77.319855,-77.577332,-77.870705,NaN,-76.707924,-76.647621,-76.614021,-76.279778,-76.118546,-76.097282,-76.164520,-76.131683,-76.209763,-76.289970,-76.194336,-76.204651,-76.135490,-76.183838,-76.296646,-76.749283,-76.707924,NaN,-75.723358,-75.620346,-75.297928,-75.366516,-75.505318,-75.438606,-75.591408,-75.687988,-75.723358,NaN,-75.297142,-75.078094,-75.025642,-74.937355,-74.808800,-74.847206,-74.963882,-75.207672,-75.149353,-75.331413,-75.297142,NaN,-73.857986,-73.808182,-73.956940,-74.165382,-74.149857,-74.036385,-74.016289,-73.894684,-74.273178,-74.347702,-74.027000,-73.857986,NaN,-74,-73.919998,-73.330002,-72.830002,-72.330002,-72,-72.669998,-73.330002,-74,NaN,-64.419998,-63.750000,-63.080002,-62.500000,-62,-61.669998,-62.250000,-62.919998,-63.500000,-63.750000,-64.419998,NaN,-64.250000,-64,-63.919998,-63.330002,-62.750000,-62,-62.500000,-62.500000,-63.330002,-63.919998,-64.250000,NaN,-83.669998,-83.330002,-82.580002,-81.919998,-81.919998,-82.830002,-83.669998,NaN,-80.080002,-79.250000,-79.330002,-79.750000,-80.169998,-80.080002,NaN,-80,-79.169998,-78.919998,-79.169998,-79.169998,-79.500000,-79.644997,-79.790001,-79.934998,-80.080002,-79.916313,-79.751762,-79.586319,-79.419998,-80,NaN,-82,-81.419998,-81,-80.750000,-81.419998,-82,NaN,-59.330002,-58.919998,-58.419998,-58.750000,-58.419998,-57.919998,-57.669998,-57.250000,-57,-56.669998,-56,-55.500000,-55.750000,-56.169998,-56.500000,-56.830002,-56.080002,-55.500000,-55.919998,-55.330002,-54.669998,-54,-54,-53.500000,-54,-53.750000,-53,-53.750000,-53.919998,-53.669998,-53.330002,-53,-53.250000,-52.750000,-52.919998,-53.080002,-53.669998,-53.669998,-54.169998,-53.919998,-54.419998,-54.830002,-55.330002,-55.919998,-55.419998,-55.419998,-56.080002,-56.830002,-57.580002,-58.419998,-59.169998,-59.330002,NaN,-87.169998,-86.169998,-86.419998,-86.250000,-86,-85,-84.669998,-83.669998,-82.500000,-81.750000,-81.250000,-80.250000,-81.169998,-82,-82.830002,-83.580002,-84.169998,-84.830002,-85.750000,-85.830002,-87.169998,NaN,-77.250000,-76.500000,-75.330002,-74.830002,-75,-75.669998,-76.830002,-77.250000,NaN,-90,-90,-89.580002,-89.080002,-88,-87,-85.419998,-85.064529,-84.709358,-84.354507,-84,-84.379524,-84.756027,-85.129517,-85.500000,-86.080002,-86.500000,-86.419998,-86.330002,-85.330002,-85.669998,-85.580002,-85.500000,-84.330002,-82.919998,-81.669998,-81.169998,-81.500000,-80.830002,-81.169998,-81.169998,-80.169998,-79,-77.830002,-76.830002,-75.750000,-74.330002,-74,-74,-72.419998,-71.250000,-69.750000,-68.330002,-68.118698,-67.909958,-67.703735,-67.500000,-67.606575,-67.712090,-67.816559,-67.919998,-67.623314,-67.329437,-67.038345,-66.750000,-67.084427,-67.417580,-67.749443,-68.080002,-68.080002,-66.750000,-65.169998,-64.250000,-63.169998,-62.169998,-61.419998,-62.080002,-62.330002,-63.500000,-63.830002,-65,-65.500000,-67.169998,-67.169998,-67.419998,-66.830002,-65.750000,-65.080002,-65,-64.250000,-64.500000,-65.750000,-66.830002,-67.750000,-68.919998,-68.500000,-67.750000,-66.919998,-66.169998,-66.169998,-67.169998,-68.080002,-69,-69.330002,-70.330002,-71.080002,-71.919998,-71.919998,-72.750000,-73.669998,-74.669998,-75.750000,-76.500000,-78,-78,-78.580002,-78.250000,-77.669998,-77.500000,-76,-74.669998,-73.669998,-74.580002,-73.750000,-73,-72.834206,-72.667282,-72.499214,-72.330002,-72.413879,-72.498497,-72.583870,-72.669998,-73,-74.250000,-75,-76.169998,-75.830002,-77.500000,-78.080002,-79,-79.830002,-81.330002,-82.330002,-84.330002,-85.750000,-87.330002,-88.250000,-89,-90,NaN,-80.500000,-79.250000,-77.830002,-76.750000,-76.419998,-76.580002,-78.169998,-79.169998,-80.500000,-80.830002,-80.500000,NaN,-96.580002,-95.669998,-94.500000,-93.750000,-93.750000,-95.330002,-96.580002,NaN,-96.169998,-94.330002,-93,-91.250000,-90.750000,-90.477104,-90.206146,-89.937111,-89.669998,-89.796257,-89.921669,-90.046249,-90.169998,-89.809830,-89.453125,-89.099854,-88.750000,-86.750000,-84.830002,-83.080002,-81.580002,-79.830002,-79.830002,-80.419998,-82.169998,-83.669998,-84.750000,-86.500000,-88.169998,-90,-92,-92.169998,-91.830002,-92.169998,-93.250000,-95.080002,-96.250000,-96.169998,NaN,-95,-95,-93.750000,-93.580002,-92,-91.330002,-90.250000,-88,-87.788506,-87.579704,-87.373550,-87.169998,-87.298920,-87.425179,-87.548843,-87.669998,-87.228737,-86.789963,-86.353706,-85.919998,-85.919998,-87.250000,-88.080002,-89.250000,-92,-93.330002,-93.669998,-93.169998,-93.830002,-95,NaN,-90.500000,-89,-86.669998,-86.669998,-86.669998,-85,-82.580002,-80.750000,-76.830002,-74.500000,-72.500000,-69.750000,-67.169998,-64.419998,-62.919998,-61.169998,-61.169998,-62.500000,-64.250000,-64.330002,-66.750000,-68.830002,-70,-71.500000,-74,-75,-75,-75.830002,-78,-77.669998,-79.250000,-77.750000,-79,-81,-81,-81.580002,-82.669998,-84,-85.169998,-87.750000,-89.500000,-89.500000,-88.169998,-87.879524,-87.587692,-87.294518,-87,-87.247528,-87.496696,-87.747520,-88,-88,-87.398376,-86.794426,-86.188263,-85.580002,-86.072273,-86.569695,-87.072266,-87.198715,-87.325485,-87.452583,-87.580002,-87.485748,-87.390923,-87.295517,-87.199524,-86.809586,-86.409859,-86,-85.647827,-85.293762,-84.937813,-84.580002,-84.723740,-84.869942,-85.018669,-85.169998,-85.169998,-86.669998,-85.830002,-83.669998,-82.500000,-79.580002,-77.669998,-80.669998,-83.500000,-85.500000,-88.250000,-90,-90.500000,NaN,-99.500000,-98.830002,-97.669998,-99.500000,NaN,-106.33000,-105.67000,-104.25000,-103,-101.42000,-100,-100,-99.580002,-98.580002,-98.169998,-98,-95.830002,-95.419998,-95.830002,-97.169998,-98.830002,-100,-100.83000,-102.17000,-104.17000,-105,-104.17000,-105.92000,-106.33000,NaN,-97,-95,-92.500000,-92.330002,-93.169998,-95.169998,-97,NaN,-105.67000,-104.75000,-104.58000,-104,-105.33000,-105.67000,NaN,-105,-104,-103,-102,-101.92000,-101.25000,-99.500000,-98,-98,-97.830002,-98.330002,-100.58000,-101.50000,-103,-104,-104.25000,-105,NaN,-104.75000,-104.25000,-103.58000,-104.75000,NaN,-102.92000,-102,-100.50000,-101.42000,-101.25000,-100.17000,-98.830002,-97.750000,-97.578682,-97.409943,-97.243736,-97.080002,-97.335083,-97.586731,-97.835022,-98.080002,-97.724625,-97.371155,-97.019615,-96.669998,-96.250000,-96.419998,-97.830002,-99,-99.919998,-100.92000,-102,-102.33000,-102.92000,NaN,-113.75000,-113,-110.75000,-108.92000,-109.58000,-111,-112,-113.75000,NaN,-115.50000,-114.25000,-114.08000,-114.83000,-115.50000,NaN,-113.58000,-112.25000,-111.08000,-110.81017,-110.54022,-110.27016,-110,-110.04367,-110.08655,-110.12865,-110.17000,-111.75000,-113.25000,-113.58000,NaN,-119.50000,-118.92000,-117.75000,-118.08000,-118.50000,-119.50000,NaN,-124.17000,-122.75000,-121.67000,-120.50000,-119.33000,-117.67000,-116.75000,-115.50000,-116.58000,-116.17000,-117.50000,-118.92000,-119.50000,-120.58000,-121.92000,-123.08000,-124.17000,NaN,-117.75000,-117.17000,-117.17000,-116.42000,-115.75000,-114.33000,-112.75000,-112,-111.42000,-110.91826,-110.41763,-109.91819,-109.42000,-109.58222,-109.74628,-109.91219,-110.08000,-110.01838,-109.95618,-109.89339,-109.83000,-110.05817,-110.28755,-110.51817,-110.75000,-110.56583,-110.37947,-110.19087,-110,-109.17000,-108.58000,-107,-105.67000,-106,-106.17000,-107.42000,-109.50000,-110.67000,-111.67000,-112.75000,-114,-114.50000,-113.25000,-114.25000,-115.25000,-116.33000,-117.75000,NaN,-119,-118.83000,-118,-118,-117,-115.75000,-114.83000,-113.67000,-113.25000,-111.92000,-110.83000,-109.58000,-108,-107.42000,-106.58000,-105,-104.17000,-104.67000,-105.50000,-105.17000,-104.58000,-104.58000,-104.75000,-103.75000,-102.33000,-100.67000,-100.83000,-102,-101.50000,-102.58000,-103.83000,-105.08000,-106,-107.08000,-108.42000,-110,-111.67000,-113.08000,-113.75000,-115.17000,-116.42000,-116.75000,-115.50000,-114,-112.67000,-114,-115.42000,-117.08000,-118.08000,-117.75000,-119,NaN,-125.25000,-124.67000,-124,-123.75000,-124.42000,-122.67000,-121.17000,-119.42000,-117.58000,-116.58000,-115.08000,-116.50000,-117.83000,-119.25000,-119.67000,-120.58000,-121.75000,-123.08000,-123.83000,-125.25000,NaN,165.68594,166.22919,166.17490,166.64885,166.61436,166.47490,166.44250,166.29825,165.99333,166.02260,165.68594,NaN,172.50000,172.83000,173.33000,172.92000,172.50000,NaN,-177.91907,-178.23126,-178.30067,-178.17793,-177.90681,-177.80429,-177.91907,NaN,-176.92000,-176.75000,-176.33000,-176.92000,NaN,-174.18573,-174.37958,-174.54735,-174.30161,-174.34758,-173.98396,-174.18573,NaN,-169.17000,-168.50000,-168,-168,-168.33000,-169.17000,NaN,-167.67000,-167.17000,-167.17000,-166.42000,-166.42000,-167,-167.67000,NaN,-171.75000,-170.50000,-169.83000,-168.83000,-169.83000,-170.75000,-171.75000,-171.75000,NaN,-167.42000,-166.75000,-166.08000,-165.50000,-165.50000,-166.17000,-166.83000,-167.42000,NaN,-154.83000,-153.92000,-153.25000,-152.50000,-152.08000,-152.31120,-152.54161,-152.77121,-153,-152.87477,-152.74969,-152.62477,-152.50000,-152.25000,-153.08000,-153.42000,-154.08000,-154.83000,NaN,-133.08000,-132.33000,-131.67000,-132,-131.67000,-131.83000,-131.33000,-131,-131.83000,-132.25000,-132.50000,-133,-133.08000,NaN,-128.33000,-127.92000,-127.17000,-126.25000,-125.50000,-125,-124.42000,-123.67000,-123.17000,-123.67000,-124.25000,-125,-125,-125.50000,-125.92000,-126.50000,-126.42000,-127.08000,-127.75000,-128.33000,NaN,-73,-72.330002,-70.330002,-68.669998,-65.669998,-64.500000,-65,-65,-65.667412,-66.334999,-67.002586,-67.669998,-67.447845,-67.220573,-66.988022,-66.750000,-65,-63.750000,-61.830002,-61.250000,-62,-59.330002,-54.500000,-51.250000,-50.500000,-47.330002,-46.500000,-44,-39.500000,-36,-31.500000,-27.330000,-24.830000,-24,-21.670000,-21.240444,-20.819050,-20.405630,-20,-20.555950,-21.102850,-21.640823,-22.170000,-25.580000,-26.245491,-26.912436,-27.580666,-28.250000,-28.651779,-29.049013,-29.441740,-29.830000,-28.705425,-27.580000,-26.454575,-25.330000,-25.330000,-25.330000,-25.330000,-25.330000,-23.670000,-23.670000,-23.670000,-21.670000,-21.330000,-22,-23.670000,-24.830000,-22.500000,-20.750000,-19.500000,-18.170000,-16.420000,-13.250000,-12.842430,-12.443393,-12.052657,-11.670000,-12.366874,-13.041944,-13.696049,-14.330000,-15.830000,-17.170000,-18.080000,-18.500000,-19.500000,-19.170000,-19.670000,-18.830000,-18.170000,-18.420000,-20.330000,-21.420000,-21.500000,-20,-19.420000,-19.420000,-20.080000,-20.080000,-18.830000,-19.250000,-21.500000,-20.330000,-20.330000,-21.580000,-22.170000,-22.379297,-22.587391,-22.794291,-23,-22.748611,-22.498146,-22.248608,-22,-21.750000,-22,-23.330000,-24.580000,-23.670000,-22.580000,-21.750000,-21.750000,-21.830000,-23.080000,-24,-24.250000,-24.500000,-25.500000,-25.250000,-26.330000,-26.330000,-25.080000,-23.750000,-23.436489,-23.123642,-22.811474,-22.500000,-22.669485,-22.837639,-23.004473,-23.170000,-23.170000,-24.250000,-25.250000,-26.250000,-27.500000,-28.750000,-30,-31.330000,-32.169998,-33,-33.419998,-33.919998,-34.750000,-35.669998,-37,-38.500000,-39.669998,-40,-41,-40.419998,-40.500000,-40.750000,-41.500000,-42.419998,-42,-42.500000,-42.750000,-42.830002,-43.250000,-43.919998,-45.169998,-45.169998,-45.750000,-46.669998,-48,-49,-49.500000,-50.080002,-50.330002,-51.250000,-51.330002,-52,-52,-52.419998,-53.500000,-53.500000,-53.750000,-53.669998,-53.330002,-52.580002,-51,-50.750000,-51.250000,-52.169998,-53.669998,-54.830002,-54.580002,-54.250000,-52.830002,-51.250000,-51.580002,-52.750000,-52.750000,-53.330002,-54,-55.250000,-55.750000,-55.330002,-55.830002,-55.500000,-55.669998,-56.500000,-56.500000,-57.500000,-58.330002,-58.330002,-60,-61.669998,-63.419998,-65.330002,-66.580002,-68.500000,-69.500000,-68.750000,-70.250000,-71.169998,-70,-68.419998,-70,-70.330002,-71.669998,-73,NaN,-24.330000,-23.750000,-23.670000,-23,-23,-22.250000,-21.500000,-21.420000,-21.420000,-20.330000,-20.250000,-19.670000,-19.250000,-18.250000,-17.580000,-16.830000,-16.250000,-15.670000,-14.750000,-14.670000,-13.670000,-13.670000,-14.500000,-15.830000,-16.750000,-17.670000,-18.750000,-20,-21,-21.437479,-21.875000,-22.312521,-22.750000,-22.564610,-22.377823,-22.189625,-22,-22.143019,-22.287348,-22.433001,-22.580000,-24,-22.830000,-22.644306,-22.457413,-22.269314,-22.080000,-22.246731,-22.413973,-22.581730,-22.750000,-23.580000,-24.330000,NaN,-9.0540400,-8.5061646,-8.3080521,-7.9248972,-8.0049992,-8.2556238,-8.6083593,-9.0474310,-9.0540400,NaN,-18.830000,-17.920000,-18.830000,-18.830000,NaN,9.3299999,9.3299999,9.5799999,9.2500000,9.5000000,9.6700001,9.7500000,9.9200001,9.5799999,9.3299999,8.9200001,8.8299999,8.4200001,8,7.5000000,7,6.5000000,6,5.4200001,5.2500000,5,4.5000000,4,3.4200001,2.8299999,2.3299999,1.8300000,1.8300000,1.2500000,1,0.33000001,-0.25000000,-0.67000002,-1.0800000,-1.5800000,-2,-2.5799999,-3.0799999,-3.8299999,-4.3299999,-4.7500000,-5.3299999,-5.9200001,-6.3299999,-6.9200001,-7.4200001,-7.8299999,-8.3299999,-8.9200001,-9.4200001,-9.8299999,-10.330000,-11,-11.420000,-11.920000,-12.420000,-12.920000,-13.080000,-13.080000,-13.170000,-13.250000,-13.580000,-14,-14.420000,-14.670000,-15,-15.420000,-15.500000,-15.920000,-16.330000,-16.750000,-16.750000,-16.670000,-16.750000,-17,-17.420000,-17,-16.750000,-16.420000,-16.420000,-16.250000,-16.080000,-16,-16,-16.170000,-16.500000,-16.170000,-16.170000,-16.580000,-16.580000,-17,-16.920000,-16.830000,-16.500000,-16.250000,-16,-15.750000,-15.420000,-15,-14.750000,-14.580000,-14.420000,-14.170000,-13.670000,-13.420000,-13.250000,-12.920000,-12.170000,-11.500000,-11.170000,-10.580000,-10.170000,-9.8299999,-9.5799999,-9.8299999,-9.8299999,-9.5000000,-9.2500000,-9.2500000,-8.8299999,-8.8299999,-8.5000000,-8,-7.4200001,-6.8299999,-6.5799999,-6.3299999,-6.1700001,-5.9200001,-5.4200001,-5.1700001,-4.5000000,-4.0799999,-3.4200001,-3,-2.4200001,-1.9200000,-1.2500000,-1,-0.50000000,0,0.50000000,1,1.7500000,2.4200001,2.9200001,3.4200001,3.8299999,4.4200001,5,5.3299999,5.3299999,5.8299999,6.2500000,7,7.4200001,8.1700001,8.6700001,9.0799999,9.5799999,10.080000,10.330000,11,10.750000,10.420000,10.580000,10.920000,11,10.750000,10.330000,10,10.080000,10.500000,10.920000,11.080000,11.670000,12.170000,12.830000,13.580000,14.170000,14.750000,15.330000,15.330000,15.330000,15.580000,16.080000,16.670000,17.500000,18.170000,18.670000,19.170000,19.580000,19.920000,20.080000,20,19.957613,19.915152,19.872614,19.830000,19.892326,19.954769,20.017326,20.080000,20.670000,21.250000,21.830000,22.500000,23.080000,23.170000,23.750000,24.330000,24.920000,25.170000,25.750000,26.330000,26.920000,27.330000,27.830000,28.420000,28.420000,29,29.500000,30,30.580000,31.170000,31.830000,31.750000,32.150002,32.253231,32.355968,32.458221,32.560001,32.517422,32.454895,32.392422,32.330002,32.392693,32.455254,32.517689,32.580002,32.669998,32.919998,33.250000,33.580002,33.669998,33.919998,34,34.330002,34.500000,34.750000,35,35.250000,35.580002,35.500000,35.580002,35.830002,36.169998,36.580002,36.919998,36.919998,37.250000,37.250000,37.169998,37.250000,37.330002,37.580002,38.080002,38.080002,38.580002,38.830002,39.080002,39.169998,39.250000,39.500000,39.830002,40.080002,40.669998,41.169998,41.580002,42.080002,42.419998,42.830002,43.250000,43.419998,42.919998,43.250000,43.580002,43.919998,44.250000,44.750000,45.250000,45.750000,46.330002,46.830002,47.419998,48,48.500000,49,49,49.580002,50.169998,50.580002,51.169998,51.080002,51,50.750000,50.750000,50.419998,50.169998,49.919998,49.750000,49.500000,49.250000,49.080002,48.919998,48.500000,48.169998,47.919998,47.669998,47.250000,46.919998,46.500000,46.169998,45.750000,45.330002,44.830002,44.419998,44,43.580002,43.580002,43.169998,42.919998,42.419998,42.080002,41.750000,41.500000,41.080002,40.669998,40.250000,40.250000,39.919998,39.580002,39.330002,39.080002,38.919998,38.750000,39.169998,39.580002,39.330002,39.330002,39.419998,39.669998,39.830002,40.169998,40.500000,40.500000,40.419998,40.500000,40.500000,40.419998,40.419998,40.580002,40.580002,40.750000,40.669998,40.419998,40.080002,39.750000,39.250000,38.919998,38.250000,37.830002,37.330002,37,36.669998,36.250000,35.830002,35.500000,35.169998,34.750000,34.669998,35,35.169998,35.330002,35.500000,35.500000,35.419998,35.500000,35.250000,34.919998,34.419998,34.419998,33.750000,33.419998,32.919998,32.580002,32.919998,32.919998,32.919998,32.750000,32.580002,32.419998,32,31.500000,31.250000,30.920000,30.670000,30.420000,30,29.580000,29.250000,28.830000,28.500000,28.080000,27.500000,27.080000,26.580000,26,25.750000,25.080000,24.750000,24.250000,24.250000,23.670000,23.250000,22.670000,22.080000,21.750000,21.080000,20.500000,20.170000,19.580000,19.170000,18.750000,18.420000,18.420000,18.250000,17.830000,18.080000,18.330000,18.250000,17.920000,17.580000,17.330000,17.170000,16.920000,16.750000,16.420000,15.920000,15.670000,15.330000,15.250000,15.080000,15.080000,14.920000,14.830000,14.830000,14.580000,14.500000,14.500000,14.420000,14.500000,14.330000,13.920000,13.750000,13.420000,13.250000,12.920000,12.670000,12.420000,12.080000,11.830000,11.750000,11.750000,11.830000,11.830000,12.080000,12.170000,12.330000,12.500000,12.670000,13,13.420000,13.670000,13.670000,13.830000,13.920000,13.830000,13.580000,13.330000,13.170000,13,13.420000,13.250000,13,12.920000,12.670000,12.420000,12.330000,12.170000,12.170000,11.920000,11.580000,11.330000,11,10.670000,10.330000,9.8299999,9.5000000,9.1700001,9,8.7500000,9.2500000,9.3299999,NaN,32.580002,32.169998,32.330002,32.669998,33.250000,34,34.330002,34.669998,34.830002,35,35.250000,35.500000,35.830002,35.750000,35.750000,35.919998,35.750000,36.080002,36,35.500000,35.169998,34.500000,34.080002,33.580002,33.580002,33.169998,32.750000,32.250000,32,31.250000,30.670000,30.500000,29.750000,29.250000,28.580000,28,28.170000,27.670000,27.545000,27.420000,27.295000,27.170000,27.252230,27.334641,27.417229,27.500000,27.395264,27.290352,27.185263,27.080000,27.170000,26.750000,26.250000,26.330000,26.670000,26.920000,26.750000,26.670000,26.830000,26,26.170000,26.170000,26.580000,26.080000,25.750000,25.170000,24.750000,24.250000,24,23.500000,23.750000,23.580000,23.080000,22.580000,22.500000,22.830000,23.170000,23.330000,23.670000,24.080000,24.170000,24.170000,24.580000,24,24,23.500000,22.920000,22.580000,21.830000,21.080000,20.670000,20.330000,20.080000,19.750000,19.330000,19.330000,19.420000,19.500000,19,18.500000,17.920000,17.330000,16.580000,16,15.750000,15.170000,15.170000,14.920000,14.830000,14.170000,14.080000,13.750000,13.750000,13.500000,13.420000,13.580000,13.080000,12.580000,12.170000,12.080000,12.330000,12.170000,12.250000,12.670000,13.080000,13.580000,13.830000,13.920000,14.170000,14.670000,15.250000,16.080000,15.830000,16.330000,16.920000,17.420000,17.920000,18.420000,18.250000,17.920000,17.830000,17.330000,16.920000,16.920000,16.670000,16.500000,17,17,16.500000,16.500000,16.170000,16,15.670000,15.670000,15.830000,16.080000,16,15.750000,15.670000,15,14.750000,14.420000,14,13.580000,12.920000,12.420000,12,11.500000,11,10.920000,10.420000,10.170000,10.080000,9.5000000,9.5000000,9.1700001,8.6700001,8.2500000,8,7.4200001,6.8299999,6.4200001,5.8299999,5.2500000,4.5799999,4,3.5799999,3,3.0799999,3.1700001,2.6700001,2.0799999,1.5000000,1,0.50000000,0,-0.33000001,-0.25000000,-0.12456354,0.00058124162,0.12543540,0.25000000,0.10449973,-0.040666334,-0.18549924,-0.33000001,-0.67000002,-0.82999998,-1.3300000,-1.8300000,-2.1700001,-2.1700001,-2.7500000,-3.3299999,-3.9200001,-4.5000000,-5,-5.5000000,-6,-6.3299999,-6.5000000,-7,-7.4200001,-7.8299999,-8.3299999,-8.9200001,-8.7500000,-8.7500000,-8.6700001,-9.0799999,-9.3299999,-9.2500000,-8.9200001,-8.8299999,-8.6700001,-8.5799999,-8.7500000,-8.8299999,-8.7500000,-9.1700001,-8.9200001,-8.3299999,-8.3299999,-8,-7.2500000,-6.5799999,-5.8299999,-5.0799999,-4.4200001,-3.5799999,-2.7500000,-2.1700001,-1.6700000,-1.4200000,-1.2500000,-1.1700000,-1.0800000,-1,-1.2500000,-1.7500000,-2,-1.9200000,-2.3299999,-2.5000000,-3.1700001,-3.7500000,-4.2500000,-4.6700001,-4.7500000,-4.1700001,-3.6700001,-3,-2.6700001,-2.6700001,-2,-1.4200000,-1.5800000,-1.9200000,-1.3300000,-1.0800000,-0.57999998,0,0.17000000,0.57999998,1.0800000,1.5000000,1.5800000,1.7500000,2.3299999,3,3.5799999,4,4.3299999,4.5799999,4.7500000,5.0799999,5.0799999,5.5000000,5.9200001,5.9200001,5.5000000,5.5000000,6.0799999,7,7,7.3299999,8,8.5000000,8.5799999,9,8.6700001,9,8.6700001,8.6700001,8.1700001,8.0799999,8.0799999,8.2500000,8.6700001,9.4200001,9.8299999,10.500000,10.500000,10.250000,10.250000,10.830000,10.830000,10.170000,9.7500000,9.4200001,10,10,10.920000,10.750000,11.330000,11.330000,11.830000,12.250000,12.920000,13.330000,13.670000,13.250000,13.830000,14.330000,15.170000,16,16.670000,17.500000,18.330000,18.670000,19.250000,19.750000,20,20.750000,21.080000,21,21,21.330000,21.670000,22.420000,22.920000,23.250000,23.830000,24.330000,24.330000,24.330000,24.330000,23.750000,23.500000,23.500000,24.170000,25,25.920000,26.830000,27.920000,28.330000,29.170000,29.420958,29.671280,29.920963,30.170000,30.065998,29.961336,29.856005,29.750000,29.080000,28.330000,27.170000,26.250000,25.330000,24.420000,23.500000,22.580000,22.080000,21.330000,21.330000,21.670000,21.250000,21.170000,21.580000,22.420000,23.250000,24.080000,24.080000,24.670000,25.330000,25.330000,24.500000,23.830000,23.170000,22.420000,22,21.420000,21.500000,21,21.670000,21,20.670000,19.830000,19.170000,18.420000,17.750000,17.420000,17.330000,17.170000,17.250000,17.920000,18.580000,18.830000,18.580000,18,18.330000,17.580000,16.830000,16.830000,16.670000,16.670000,16.500000,16.330000,15.920000,15.330000,14.670000,14.170000,14.250000,13.670000,13,13,12.670000,12.920000,12.330000,12,11.670000,11.330000,11.080000,10.580000,10.250000,9.7500000,9,8.5000000,7.6700001,6.8299999,6,5.5799999,5.6700001,6.1700001,6.1700001,5.4200001,5.2500000,5.5799999,5.0799999,5,4.9579191,4.9155612,4.8729224,4.8299999,4.9341726,5.0388937,5.1441684,5.2500000,5.1681590,5.0858812,5.0031629,4.9200001,5.1059337,5.2929072,5.4809275,5.6700001,6.3299999,7,8,8.5000000,8.9200001,9.5000000,10.080000,10.670000,11.330000,12.170000,12.580000,13,13.330000,13.830000,14.670000,15,16.170000,15,14,12.920000,13.670000,13.670000,14.000631,14.332517,14.665644,15,14.856205,14.711610,14.566210,14.420000,14.645583,14.872441,15.100578,15.330000,16.170000,15.920000,16.580000,16.670000,16.894968,17.121616,17.349955,17.580000,17.435396,17.290529,17.145395,17,17,18.080000,18.920000,20.170000,21.500000,22.330000,23.330000,24.250000,24.830000,25.670000,25.580000,26.580000,26.830000,27.750000,29.080000,30.170000,31.170000,30,29.688526,29.376358,29.063511,28.750000,29.066330,29.380095,29.691313,30,31.250000,31.250000,32.080002,33.080002,33.080002,34.500000,35.830002,37,38,39,40,40.919998,41.250000,41.250000,40.580002,39.500000,38.330002,37.250000,36.250000,35.330002,34.330002,33.169998,32.942406,32.713215,32.482418,32.250000,32.397240,32.542969,32.687218,32.830002,33.669998,34.669998,34.669998,34.669998,34.669998,35.750000,36.750000,38,38,38,37.250000,36.500000,36.919998,37.750000,38.669998,39.500000,40.669998,40.169998,40.046486,39.921989,39.796501,39.669998,39.875523,40.082355,40.290512,40.500000,41.500000,42.169998,43.169998,43.919998,44.500000,44.500000,43.830002,44.169998,44.169998,43.250000,44.500000,45.669998,46.250000,46.669998,45.500000,45.353062,45.207428,45.063080,44.919998,45.148636,45.376514,45.603638,45.830002,46.330002,47.330002,47.330002,48.169998,48.169998,49.080002,50.169998,51,52.080002,53,53.919998,54,54.830002,55.169998,56.169998,57.250000,58.169998,59.080002,59.080002,59.830002,59.830002,60.500000,61.080002,60.500000,60.169998,59.169998,58.580002,59.080002,60.169998,61.750000,63,64.080002,65.080002,65.080002,66,67.080002,67.750000,68.580002,69.080002,68.330002,67.830002,66.919998,66.919998,67.330002,66.830002,67,68.250000,68.750000,68.919998,69.500000,70.080002,70.350464,70.622284,70.895462,71.169998,71.296814,71.422401,71.546799,71.669998,71.584084,71.498787,71.414093,71.330002,71.708961,72.085281,72.458961,72.830002,72.830002,72.830002,72.830002,72.830002,72.725784,72.622726,72.520805,72.419998,72.270035,72.121727,71.975060,71.830002,72.043427,72.254547,72.463394,72.669998,72.669998,72.669998,72.669998,72.669998,72.669998,72.669998,72.669998,72.669998,72.647034,72.624382,72.602036,72.580002,72.580002,72.580002,72.580002,72.580002,72.833557,73.084724,73.333527,73.580002,73.580002,73.169998,73.169998,72.500000,71.830002,70.500000,71.580002,72.500000,73.500000,74,74.830002,74.500000,74.580002,74.808052,75.037399,75.268051,75.500000,75.106094,74.711441,74.316063,73.919998,73.669998,73.830002,74.330002,73.830002,73.169998,73.750000,74.669998,75.169998,75.080002,74.169998,74.500000,75.500000,75.750000,75.330002,75.330002,76.919998,76.919998,78.500000,78,76.580002,76.080002,76.919998,77.750000,78.330002,78.001953,77.670952,77.336975,77,77.185562,77.372414,77.560555,77.750000,78.500000,79.500000,80.580002,81.580002,81.890511,82.202354,82.515518,82.830002,82.667786,82.503731,82.337814,82.169998,80.830002,80.830002,80.330002,82,83.750000,85.250000,87,86.500000,86.580002,87.500000,88.669998,90.580002,92.169998,93.250000,94.750000,94.750000,95.304985,95.865005,96.430023,97,96.916046,96.833069,96.751060,96.669998,97.351250,98.036766,98.726402,99.419998,99.316856,99.212486,99.106880,99,101,101,102.50000,104.08000,104.58984,105.09309,105.58978,106.08000,105.61347,105.15300,104.69853,104.25000,104.68748,105.12500,105.56252,106,106.37669,106.75227,107.12672,107.50000,107.22243,106.95000,106.68256,106.42000,106.77248,107.12500,107.47752,107.83000,108.17000,109.58000,111.17000,112.42000,113.50000,113.83000,113.67000,112.50000,111,109.67000,108.33000,107.17000,106.50000,107.58000,108.83000,110.17000,110.17000,110.00436,109.83749,109.66937,109.50000,109.66561,109.83247,110.00060,110.17000,111.17000,112,113,113.67000,114.83000,115.92000,117.25000,118.67000,118.50000,120,122,123.33000,122.83000,123,124.83000,126.92000,128.58000,129.83000,129.50000,128.75000,129.42000,130.33000,131.25000,131.25000,132,132.25000,132.58000,133.50000,134.42000,135,135.83000,136.67000,138.58000,138.97873,139.37666,139.77376,140.17000,140.04707,139.92278,139.79709,139.67000,139.33000,139.75000,141.17000,140.67000,142.42000,143.83000,145.25000,146.83000,148.50000,149.83000,150,150.67000,151.58000,152.42000,152.42000,153.50000,154.58000,156,157.50000,157.50000,158.83000,159.67000,159.75378,159.83670,159.91878,160,159.87309,159.74748,159.62312,159.50000,159.79509,160.08846,160.38008,160.67000,162.25000,164,165.67000,167,167.67000,168.25000,169.42000,169.17000,168.25000,168.33000,169.33000,169.58000,170.42000,171,170.58000,170.58000,172,173.33000,174.67000,176.17000,177.42000,178.67000,179.75000,180,180,180.92000,181.83000,183.08000,184.17000,185,185.50000,186.83000,188.33000,189.17000,189.42314,189.67418,189.92313,190.17000,189.98112,189.79317,189.60612,189.42000,188.92000,187.83000,187.83000,187.25000,187,186,184.92000,184.17000,184,183,182.33000,181.50000,181.17000,181,180.08000,180.75000,180.33000,180,180,179.58000,178.67000,177.50000,177.50000,178.33000,178.58000,178.83000,179.25000,179.67000,179,178.17000,177,176.25000,175.33000,174.58000,173.83000,173.08000,172.33000,171.50000,170.67000,170.67000,170.33000,169.83000,169.17000,168.25000,167.50000,166.83000,166.17000,166.17000,165.33000,164.75000,164.17000,163.33000,163.17000,162.92000,162.33000,161.92000,162.08000,162.58000,163.17000,162.67000,162.67000,163.08000,163.25000,162.83000,162.42000,161.92000,161.58000,161.67000,162.08000,161.67000,161.67000,161.17000,160.42000,159.92000,159.83000,159.92000,159.17000,158.58000,158.42000,157.92000,157.33000,156.67000,156.50000,156.50000,156.42000,156.08000,156,155.83000,155.67000,155.50000,155.42000,155.50000,155.75000,156,156.67000,157,156.83000,157.50000,158.25000,159,159.67000,159.67000,160.08000,160.92000,161.58000,161.92000,162.67000,163.50000,163.75000,163.92000,164.08000,164.75000,164.42000,163.25000,162.92000,162.92000,162.25000,161.67000,161,160.17000,159.92000,159.83000,159.95326,160.07767,160.20325,160.33000,160.12169,159.91393,159.70670,159.50000,158.83000,157.92000,156.92000,156.33000,155.75000,155,154.50000,154.17000,154.17000,154.83000,154.91547,155.00063,155.08546,155.17000,154.87692,154.58423,154.29192,154,153.33000,152.92000,152,151.33000,151.08000,151.67000,151.33000,150.83000,150.17000,149.50000,149,148.92000,148.83000,148.17000,147.42000,146.50000,145.92000,145.58000,144.67000,143.67000,142.67000,142,141.67000,141,140.58000,140.25000,139.67000,139.67000,139,138.50000,137.92000,137.25000,136.58000,135.92000,135.17000,135.25000,135.92000,136.67000,136.67000,136.67000,137.08000,137.67000,137.67000,137.58450,137.49933,137.41451,137.33000,137.55931,137.78908,138.01930,138.25000,138.83000,139.50000,140.17000,140.25000,140.75000,141.33000,141.08000,141.08000,141.33000,141.08000,140.75000,140.50000,140.42000,140.42000,140.50000,140.50000,140.33000,140.17000,139.50000,139,138.50000,138.25000,137.92000,137.50000,136.92000,136.33000,135.67000,135.50000,135,134.33000,133.75000,133.08000,132.33000,132.33000,131.75000,131.50000,131.17000,130.83000,130.67000,130.08000,129.58000,129.67000,129.67000,129.25000,129.25000,128.75000,128.25000,127.83000,127.70488,127.57983,127.45488,127.33000,127.37261,127.41515,127.45762,127.46822,127.47882,127.48941,127.50000,127.48933,127.47866,127.46800,127.45735,127.41480,127.37235,127.33000,127.45533,127.58044,127.70533,127.83000,128.25000,128.50000,128.83000,129.17000,129.33000,129.42000,129.42000,129.33000,129.08000,128.50000,127.75000,127.17000,126.58000,126.33000,126.33000,126.75000,126.50000,126.17000,126.75000,126.58000,126.08000,125.33000,124.75000,124.75000,125,125.17000,125.42000,125.08000,124.67000,124.08000,123.50000,123,122.42000,122.08000,121.58000,121.17000,121.67000,121.33000,121.50000,121.92000,122.25000,121.92000,121.25000,120.83000,120.42000,119.92000,119.42000,119.25000,119,118.42000,118,117.67000,117.58000,117.92000,117.92000,118.33000,118.83000,118.92000,119.33000,119.75000,120,120.33000,120.83000,121.17000,121.58000,122.08000,122.20511,122.33015,122.45512,122.58000,122.51719,122.45459,122.39219,122.33000,122,121.50000,120.83000,120.67000,120.17000,119.67000,119.42000,119.17000,119.75000,120.33000,120.50000,120.67000,120.83000,120.92000,121.25000,121.67000,121.83000,121.83000,121.25000,121.83000,121.92000,121.50000,121.17000,120.92000,120.42000,120.75000,121.33000,121.67000,122.08000,122,121.92000,121.67000,121.50000,121.58000,121.42000,121.08000,120.83000,120.58000,120.33000,120,119.67000,119.75000,119.67000,119.42000,119.17000,118.83000,118.67000,118.17000,118.17000,118.17000,117.83000,117.42000,117,116.50000,116,115.50000,115,114.50000,114.17000,113.67000,113.50000,113.08000,113,112.50000,112,111.50000,110.92000,110.42000,110.25000,110.50000,110.25000,109.92000,109.75000,109.67000,109.75000,109.42000,109,108.50000,108,108,107.58000,107.08000,106.67000,106.42000,105.92000,105.75000,105.58000,105.92000,106.33000,106.42000,106.83000,107.17000,107.67000,108.08000,108.42000,108.83000,109,109.17000,109.25000,109.25000,109.25000,109.17000,109.17000,109,108.50000,108.08000,107.67000,107.25000,106.67000,106.67000,106.67000,106.33000,105.83000,105.42000,105,104.83000,104.83000,104.87245,104.91493,104.95745,105,104.87505,104.75007,104.62505,104.50000,104.25000,103.67000,103.25000,103,102.83000,102.58000,102.25000,101.83000,101.42000,100.92000,100.92000,100.42000,100,99.919998,99.919998,99.750000,99.580002,99.330002,99.169998,99.169998,99.330002,99.830002,99.830002,99.919998,100.25000,100.42000,100.58000,100.92000,101.50000,101.83000,102.25000,102.67000,103.08000,103.42000,103.42000,103.42000,103.42000,103.42000,103.75000,104.08000,104.25000,103.50000,103.17000,102.75000,102.25000,101.92000,101.42000,101.33000,100.92000,100.58000,100.67000,100.42000,100.33000,100.33000,100.33000,100.08000,99.750000,99.419998,99.080002,98.669998,98.419998,98.250000,98.250000,98.500000,98.500000,98.500000,98.750000,98.750000,98.500000,98.750000,98.580002,98.250000,98.080002,97.919998,97.830002,97.750000,97.580002,97.250000,96.919998,96.750000,96.250000,95.830002,95.500000,95.080002,95.080002,94.750000,94.250000,94.419998,94.580002,94.500000,94.330002,94.169998,93.830002,93.580002,93.750000,93.500000,93.169998,92.919998,92.500000,92.169998,92,91.919998,91.750000,91.419998,90.919998,90.580002,90.250000,89.750000,89.250000,88.750000,88.330002,88.169998,88,87.580002,87.080002,87.080002,86.919998,87,86.750000,86.419998,85.919998,85.500000,85.080002,84.830002,84.500000,84.080002,83.669998,83.330002,83,82.580002,82.330002,82.250000,82,81.500000,81.169998,81,80.419998,80.169998,80.080002,80.169998,80.250000,80.330002,80.250000,80,79.750000,79.750000,79.750000,79.830002,79.830002,79.330002,79,79,78.580002,78.169998,78,77.580002,77.169998,76.830002,76.500000,76.330002,76.169998,76,75.830002,75.580002,75.250000,75,74.830002,74.669998,74.500000,74.419998,74.080002,73.750000,73.500000,73.330002,73.250000,73.169998,73,73,72.830002,73,72.830002,72.669998,72.750000,72.830002,72.580002,72.500000,72.580002,72.330002,72.169998,72.080002,71.669998,71.169998,70.580002,70.080002,69.669998,69.330002,69.080002,69.669998,70.169998,70.330002,69.750000,69.169998,68.669998,68.330002,67.919998,67.419998,67.330002,67.169998,67.169998,66.830002,66.580002,66.080002,65.580002,65.169998,64.669998,64.250000,63.830002,63.500000,62.919998,62.419998,61.830002,61.169998,60.750000,60.169998,59.669998,59.169998,58.580002,58,57.330002,57.169998,57.080002,56.750000,56.250000,55.750000,55.330002,54.750000,54.330002,53.830002,53.500000,53.500000,53,52.580002,52.169998,51.500000,51.250000,51.080002,50.669998,50.330002,50,49.580002,49.250000,48.919998,48.580002,48.330002,47.750000,48.169998,48.330002,48.580002,48.830002,49.250000,49.669998,50.080002,50.250000,50.169998,50.500000,50.669998,51,51.080002,51.330002,51.580002,51.580002,51.669998,51.580002,51.250000,51.669998,51.830002,52.419998,52.750000,53.250000,53.830002,54.250000,54.500000,55,55.330002,55.669998,56.080002,56.250000,56.500000,56.419998,56.419998,56.419998,56.830002,57.250000,57.750000,58.250000,58.830002,59.080002,59.419998,59.830002,59.580002,59.330002,59.330002,59,58.750000,58.500000,58.080002,57.830002,57.750000,57.919998,57.500000,57.080002,56.750000,56.580002,56.330002,55.919998,55.419998,55.250000,54.830002,54.419998,53.919998,53.419998,52.919998,52.419998,52.250000,52.250000,51.750000,51.250000,50.750000,50.250000,49.669998,49.169998,48.830002,48.830002,48.330002,47.830002,47.419998,47.080002,46.580002,46.080002,45.669998,45.419998,44.919998,44.419998,43.919998,43.500000,43.169998,43.250000,43.080002,42.919998,42.750000,42.669998,42.750000,42.669998,42.419998,42.080002,41.750000,41.500000,41.250000,41,40.750000,40.330002,39.669998,39.500000,39.500000,39.169998,39.080002,39,39.080002,39,38.750000,38.419998,38,37.500000,37.250000,37.080002,36.750000,36.419998,36.080002,35.750000,35.500000,35.169998,34.669998,34.830002,35,35,34.669998,34.419998,34.419998,34.169998,33.750000,33.419998,33.250000,33,32.750000,32.750000,32.580002,NaN,112.83000,111.58000,112.08000,113.33000,112.83000,NaN,26.580000,27.170000,27.750000,27.750000,28.420000,29,28.920000,29.420000,28.830000,28.170000,27.420000,27.080000,26.580000,NaN,13.080000,13.330000,13.500000,13.830000,13.920000,14.170000,14.580000,15.080000,15.250000,14.750000,14.170000,14.170000,13.920000,13.420000,13.080000,NaN,31.670000,31.830000,32.250000,32.750000,33.419998,33.830002,33.250000,33.580002,33.919998,34.080002,34.250000,34,33.500000,33,32.419998,31.830000,31.670000,31.830000,31.750000,31.670000,NaN,29.250000,29.500000,29.830000,30.330000,30.580000,30.500000,31.080000,31,30.750000,30.500000,30.580000,30.170000,30.064949,29.959932,29.854950,29.750000,29.812536,29.875048,29.937536,30,29.957468,29.914959,29.872469,29.830000,29.670000,29.420000,29.330000,29.080000,29.250000,29.080000,29.330000,29.250000,NaN,34.080002,34.169998,34.330002,34.330002,34.669998,34.750000,35.080002,35.330002,35.250000,34.919998,34.830002,34.830002,34.872570,34.915092,34.957569,35,34.917370,34.834827,34.752373,34.669998,34.580002,34.500000,34.080002,34,34.250000,34.250000,34.419998,34.080002,NaN,27.500000,27.920000,28.080000,28.580000,29.170000,29.830000,30.500000,31.080000,31.580000,32.080002,32.580002,33.250000,33.830002,34.500000,35,35.330002,36,36.330002,36.750000,37.250000,37.669998,38.169998,38.750000,39.330002,39.919998,40.500000,41.080002,41.580002,41.669998,41.419998,41.419998,41.250000,41,40.330002,39.830002,39.500000,39,38.500000,38,37.669998,37.250000,37,36.669998,36.080002,35.580002,35.080002,34.580002,34.250000,33.750000,33.419998,33.580002,33.250000,32.669998,33.080002,33.750000,33.169998,32.580002,31.830000,32.080002,31.420000,30.830000,30.830000,30.580000,30.170000,29.580000,29.670000,29.500000,29,28.670000,28.670000,28.580000,28,27.920000,27.500000,NaN,34.419998,34.750000,35,35.500000,36.080002,36.669998,37.330002,37.750000,38.250000,37.919998,37.669998,38.169998,38.750000,39.330002,39,38.419998,37.580002,36.830002,36.080002,35.419998,35,34.419998,NaN,46.669998,46.669998,47.080002,47.419998,47.419998,47.419998,47.830002,48.250000,48.669998,49,49.169998,49.669998,49.815258,49.960346,50.105259,50.250000,50.124874,49.999832,49.874874,49.750000,49.419998,49.250000,49.169998,48.750000,48.830002,48.919998,49,49.500000,50.169998,50.330002,51,51.580002,52.419998,53.169998,53.919998,54,54,53.750000,53.750000,54,53.580002,53.419998,53.500000,52.750000,52.669998,52.919998,53.500000,54.169998,54.750000,54.330002,53.919998,53.669998,53,52.669998,52.750000,52.419998,52.397610,52.375149,52.352612,52.330002,52.414585,52.499447,52.584583,52.669998,52.627628,52.585171,52.542629,52.500000,51.830002,51.330002,51.169998,50.750000,50.169998,50.250000,50.919998,51.419998,51.419998,51.169998,51.314369,51.459160,51.604370,51.750000,51.937275,52.124702,52.312279,52.500000,53.080002,53.669998,54.250000,53.919998,53.830002,53.669998,53.169998,52.580002,52.080002,51.419998,50.919998,50.169998,49.500000,48.919998,49,48.500000,48.250000,47.580002,47.330002,47,46.669998,NaN,58.169998,58.169998,58.330002,58.330002,59,59.669998,59.830002,60.500000,61.080002,61.080002,61.500000,61.830002,61.500000,61,61,61.330002,61.669998,61,60.750000,60.080002,60.080002,59.750000,59.500000,59,58.669998,58.580002,58.169998,NaN,73.419998,73.830002,74.080002,74.250000,74.169998,74.750000,75.169998,76,76.830002,77.330002,78,78.750000,79.250000,78.750000,78.330002,77.830002,77.330002,76.830002,76.080002,75.250000,74.750000,74.169998,73.669998,73.419998,NaN,103.58000,104.50000,105.25000,105.92000,106.25000,107,107.83000,108.33000,109,109.42000,109.50000,109.67000,109.92000,109.50000,109.25000,109.17000,108.83000,108.50000,108.17000,107.58000,107,106.58000,106.08000,105.67000,105.25000,104.50000,103.58000,NaN,30,30.580000,30.920000,31.080000,31.500000,31.750000,32.500000,32.830002,32.830002,32.500000,31.830000,31.420000,30.750000,30.170000,30,NaN,34.500000,34.830002,35.500000,35.500000,36,36.419998,36.419998,36,35.750000,35.830002,35.250000,34.500000,34.830002,35.330002,35.330002,34.669998,34.500000,NaN,43.250000,43.580002,43.919998,44.080002,44.419998,44.500000,44.250000,44.250000,44,44,43.919998,44.250000,44.500000,44.919998,45.419998,45.919998,46.419998,46.830002,47.250000,47.669998,47.580002,47.919998,47.830002,48.330002,48.750000,48.830002,48.830002,49.250000,49.580002,49.830002,49.919998,50.169998,50.330002,50.419998,50.080002,49.669998,49.750000,49.669998,49.419998,49.419998,49.419998,49.330002,49.250000,49,48.830002,48.669998,48.500000,48.419998,48.250000,48.080002,47.919998,47.830002,47.750000,47.669998,47.500000,47.330002,47.169998,46.830002,46.419998,45.919998,45.500000,45,44.580002,44.169998,43.750000,43.669998,43.580002,43.330002,43.250000,43.250000,NaN,55.169998,55.580002,55.830002,55.750000,55.330002,55.169998,NaN,57.330002,57.500000,57.750000,57.750000,57.330002,NaN,53.330002,53.669998,54.169998,54.580002,54.080002,53.669998,53.330002,NaN,68.830002,69,69.330002,69.669998,70,70.580002,70.419998,70,69.830002,69.500000,68.919998,69.169998,68.830002,NaN,92.680725,92.531227,92.753311,92.914330,92.965225,92.680725,NaN,92.867722,92.827248,92.883194,92.979454,93.064552,93.076912,92.867722,NaN,96.407074,96.080315,95.809090,95.848045,95.973999,96.255836,96.407074,NaN,97.250000,97.500000,98,98,97.580002,97.250000,NaN,98.750000,99,99.419998,99.080002,98.830002,98.750000,NaN,79.750000,79.830002,79.919998,80.169998,80,80.580002,80.919998,81.250000,81.500000,81.830002,81.830002,81.669998,81.250000,80.669998,80.250000,80,79.830002,79.750000,79.750000,NaN,108.67000,109.08000,109.58000,110,110.50000,111,111,110.67000,110.50000,110.17000,109.67000,109.25000,108.75000,108.67000,108.67000,NaN,120.17000,120.50000,120.75000,121.08000,121.58000,121.92000,121.92000,121.67000,121.50000,121.33000,121,120.83000,120.67000,120.33000,120.17000,120.17000,NaN,129.50000,130,130.42000,130.92000,131.08000,131.58000,131.67000,131.92000,131.67000,131.42000,131.33000,130.75000,130.17000,130.17000,130.17000,130.50000,130.50000,130.25000,130.17000,129.75000,129.50000,NaN,132.25000,132.67000,132.83000,133.33000,133.58000,134.08000,134.58000,134.67000,134.33000,134.08000,133.75000,133.25000,133.08000,132.92000,132.42000,132.25000,NaN,130.92000,131.42000,131.83000,132.33000,132.75000,133.25000,134,134.67000,135.25000,135.67000,136,136,136.33000,136.67000,136.75000,137.17000,137,137,137.58000,138.17000,138.17000,138.58000,138.83000,139.33000,139.50000,139.83000,140,140,140,140,140.33000,140.67000,141.08000,141.08000,140.75000,140.83000,141.42000,141.33000,141.42000,141.75000,141.92000,141.83000,141.50000,141.50000,141.08000,140.92000,141,140.92000,140.67000,140.58000,140.75000,140.75000,140.42000,140.33000,139.75000,139.83000,139.58000,139.08000,138.83000,138.67000,138.08000,137.25000,136.75000,136.50000,136.75000,136.17000,135.75000,135.42000,135.17000,135.17000,135.50000,134.92000,134.50000,133.92000,133.50000,132.92000,132.33000,132,131.50000,130.92000,130.92000,NaN,139.83000,140.42000,140.33000,140.75000,141.25000,141.33000,141.25000,141.58000,141.67000,141.75000,141.50000,141.92000,142.33000,142.67000,142.67000,143,143.58000,144.17000,144.67000,145.33000,145,145.25000,145.25000,145.83000,145.33000,144.75000,144.17000,143.67000,143.33000,143.25000,142.50000,141.83000,141.33000,140.92000,140.67000,140.33000,140.25000,140.67000,141.08000,140.50000,140,140,139.75000,139.83000,NaN,127.66799,127.65637,127.81740,128.30327,128.34015,128.34779,127.96155,127.79272,127.66799,NaN,129.29555,129.24274,129.23155,129.29333,129.52495,129.72638,129.29555,NaN,145.44214,146.07005,146.39491,145.44214,NaN,146.92000,147.42000,147.92000,148.33000,148.83000,148.17000,147.50000,146.92000,NaN,149.50000,150,150.50000,149.83000,149.50000,NaN,155.17000,155.67000,156.08000,156.08000,155.83000,155.17000,155.17000,NaN,137.25000,137.50000,138.08000,137.58000,137.25000,NaN,163.33000,163.67000,164.25000,164.42000,163.33000,NaN,141.75000,142.25000,142.31223,142.37463,142.43723,142.50000,142.43797,142.37563,142.31297,142.25000,142.35484,142.45979,142.56485,142.67000,142.92000,143,143.17000,143.17000,143.08000,143.33000,143.50000,143.67000,143.92000,144.17000,144.33000,143.75000,143.25000,143.25000,142.92000,142.83000,142.58000,142.50000,142.67000,143,143.08000,143.42000,143.42000,143,142.58000,142.25000,142,141.75000,142,142,142.17000,142,141.83000,142,142.08000,142.08000,142,142.08000,142,141.67000,141.67000,141.83000,141.75000,NaN,180,178.83000,178.67000,180,181.75000,181.96040,182.16887,182.37538,182.58000,182.13800,181.69901,181.26300,180.83000,180,NaN,140.58000,141,142.25000,143.50000,143.50000,141.58000,140.58000,NaN,140.17000,141,141,140.33000,140.17000,NaN,146.50000,147.33000,149.25000,151,150.50000,149.25000,147.25000,146.50000,NaN,137.17000,137.50000,139,141,142,143.25000,144,145,145,144,142.83000,142,140.50000,139.25000,138.08000,137.17000,NaN,99.330002,99.830002,100.58000,101.25000,102.33000,103.92000,105,105,103.17000,101,99.330002,NaN,91.169998,92.669998,93.169998,95.580002,96.419998,96.695534,96.967339,97.235466,97.500000,97.372505,97.246696,97.122536,97,97.148712,97.294907,97.438644,97.580002,99.250000,99.485580,99.717392,99.945503,100.17000,99.997505,99.828400,99.662598,99.500000,99.830002,98.330002,96.750000,94.669998,93.830002,91.830002,91.169998,NaN,51.669998,51.669998,51.669998,51.669998,51.669998,51.937252,52.206329,52.477242,52.750000,52.688377,52.626175,52.563385,52.500000,52.545643,52.591442,52.637409,52.683533,52.729820,52.776276,52.822891,52.869675,53.058479,53.250000,53.517063,53.786076,54.057049,54.330002,54.206825,54.082443,53.956841,53.830002,54.919998,55.750000,55.750000,57.500000,57.500000,58.169998,59.250000,61.169998,63.169998,65.169998,66,67.750000,69.080002,68.830002,67.250000,65.500000,63.830002,62.250000,60.750000,59.830002,58.669998,57.830002,57,56.169998,55.580002,55.500000,55.750000,56.330002,56.669189,57.005577,57.339176,57.669998,57.481312,57.293415,57.106312,56.919998,55.330002,53.830002,53.583221,53.334309,53.083241,52.830002,52.544598,52.256157,51.964638,51.669998,NaN,48.750000,48.500000,49.169998,50.330002,50,48.750000,NaN,63.248936,62.947983,63.144978,63.367226,64.308342,64.742432,65.141998,65.364555,65.234703,64.840904,63.248936,NaN,59.648144,59.456367,59.579586,59.789795,60.406391,61.367126,61.993614,62.217430,61.858395,61.205341,60.756351,59.648144,NaN,56.639359,56.542294,56.069351,56.100079,56.299641,57.028126,57.043949,56.925987,56.639359,NaN,57.508308,58.450150,59.002480,58.613926,57.728737,57.640331,57.508308,NaN,54.250000,54.830002,56.500000,56.500000,58.500000,58.830002,57.669998,58.500000,56.330002,54.250000,NaN,53.169998,54,54.254272,54.505669,54.754234,55,54.541481,54.083603,53.626427,53.169998,NaN,44.500000,47,48,48,50.330002,51.169998,50,50,48.419998,47,47,45.669998,44.500000,NaN,11,13.830000,15.500000,16.330000,18,18,20,21,23,24.830000,24.830000,27,27,25.670000,23.830000,20.920000,18.750000,19,21.500000,22.170000,23.170000,24.830000,22.670000,20.830000,21.670000,20.670000,20.250000,19,18.920000,18.080000,17.330000,17,15.170000,14,13.670000,14.016616,14.367127,14.721575,15.080000,14.602531,14.125000,13.647469,13.170000,11.670000,11,11,NaN,-7.4200001,-7.2500000,-6.3299999,-6.9200001,-7.4200001,NaN,-1.3834395,-1.4489599,-1.4066745,-1.4821186,-1.2856836,-1.2275578,-1.0810091,-1.3834395,NaN,-3.0374002,-3.2808065,-3.4012024,-3.3346920,-3.1567438,-2.9256713,-2.9666162,-3.0374002,NaN,-7.2500000,-7,-7,-6.1700001,-6.4200001,-7.2500000,NaN,9.7500000,10.280000,10.750000,10.700000,10.080000,9.7500000,NaN,11.080000,11.750000,12.420000,12.460310,12.500412,12.540308,12.580000,12.477049,12.374399,12.272050,12.170000,12.420000,11.830000,11.250000,11.080000,NaN,11,11.580000,12.080000,11.830000,11.330000,11,NaN,18.080000,18.420000,19.170000,18.750000,18.750000,18.250000,18.080000,NaN,21.830000,22.330000,23.170000,22.670000,22.170000,21.830000,NaN,22.330000,22.500000,23,22.420000,22.330000,NaN,-5.5799999,-5,-4.5000000,-4.0799999,-3.5000000,-3,-2.6700001,-3.3299999,-3.8299999,-4.3299999,-5,-5.0423241,-5.0847650,-5.1273236,-5.1700001,-5.0231166,-4.8758225,-4.7281175,-4.5799999,-4.0799999,-4.0799999,-4.6700001,-4.3299999,-4.5000000,-3.5799999,-3,-3,-2.6700001,-3.1700001,-3.5799999,-3.2500000,-4,-4.7500000,-4.8319817,-4.9143071,-4.9969792,-5.0799999,-4.9786158,-4.8764935,-4.7736244,-4.6700001,-4.7718530,-4.8741355,-4.9768505,-5.0799999,-5.0799999,-5.5799999,-5.5799999,-6.1700001,-5.5000000,-5.4200001,-6,-6,-5.5799999,-6.2500000,-6.6700001,-6.3299999,-5.8299999,-5.7500000,-5.3299999,-5,-4.0799999,-3.1700001,-3,-3.8299999,-4.1700001,-3.4200001,-2.7500000,-1.9200000,-1.8300000,-2.0799999,-2.4200001,-2.8299999,-3.3299999,-2.6700001,-2,-2,-1.6700000,-1.5000000,-1.1700000,-0.50000000,-0.25000000,-0.079999998,0.17000000,0.33000001,0,0.25000000,0.57999998,1,1.5800000,1.8300000,1.5800000,1,0.57999998,1.4200000,0.92000002,0.079999998,-0.67000002,-1.4200000,-2.0799999,-2.8299999,-3.5000000,-3.6700001,-4.5000000,-5.0799999,-5.5799999,NaN,-10.330000,-9.7500000,-9.5000000,-9,-9.5000000,-10,-9.5000000,-10,-9.7500000,-9.0799999,-8.5000000,-8.1700001,-8.6700001,-8.2500000,-7.5000000,-6.7500000,-6.0799999,-5.7500000,-5.5799999,-6.2500000,-6.0799999,-6,-6.1700001,-6.3299999,-7.2500000,-8,-8.7500000,-9.5799999,-10.080000,-10.330000,NaN,8.6700001,9.1700001,9.4200001,9.4200001,9.5000000,9.3299999,9.1700001,8.6700001,8.5799999,8.6700001,NaN,8.1700001,8.4200001,8.7500000,9.2500000,9.6700001,9.7500000,9.7500000,9.6700001,9.5000000,9.0799999,8.7500000,8.3299999,8.4200001,8.4200001,8.1700001,8.1700001,NaN,12.330000,12.750000,13.250000,13.670000,14.250000,15,15.670000,15.330000,15.170000,15.330000,15.170000,14.500000,14.170000,13.670000,13,12.670000,12.330000,NaN,21.080000,21.330000,21.830000,22.330000,22.830000,23.170000,22.670000,22.830000,23.080000,22.670000,22.330000,22.080000,21.670000,21.500000,21.580000,21.080000,NaN,23.500000,23.580000,24.170000,24.250000,24.750000,25.170000,25.750000,25.750000,26.250000,26.170000,25.500000,24.830000,24.500000,24,23.500000,NaN,32.250000,32.750000,33,33.419998,33.919998,34.500000,33.919998,34.080002,33.669998,33.500000,33,32.419998,32.250000,NaN,2.2500000,2.9200001,3.4200001,3.0799999,2.7300000,2.2500000,NaN,27.670000,28.250000,28.080000,27.750000,27.670000,NaN,26.421621,26.329967,26.212252,26.029953,25.900337,25.858942,25.889624,26.303318,26.383131,26.509672,26.421621,NaN,26.000242,25.813082,26.017820,26.178562,26.088400,26.000242,NaN,-28.159765,-28.029388,-28.192963,-28.473545,-28.536633,-28.490150,-28.159765,NaN,-25.254848,-25.789749,-25.825817,-25.813961,-25.488266,-25.234943,-25.167929,-25.254848,NaN,-16.830000,-16.500000,-16.170000,-16.330000,-16.580000,-16.830000,NaN,-15.800000,-15.670000,-15.370000,-15.330000,-15.670000,-15.800000,NaN,-13.738705,-13.787071,-13.766937,-13.541560,-13.428255,-13.412160,-13.738705,NaN,-14.209541,-14.182261,-13.961255,-13.898086,-13.933837,-14.209541,NaN,8.5000000,8.6700001,8.9200001,8.7500000,8.5000000,NaN,115.17000,115.17000,115.58000,115.83000,115.75000,115.83000,115.83000,115.58000,115.42000,115.17000,115,115,114.92000,114.58000,114.17000,114.17000,113.92000,113.50000,113.33000,113.83000,113.50000,113.75000,113.75000,114.17000,114.17000,113.92000,113.67000,113.50000,113.42000,113.83000,113.83000,113.67000,113.83000,114.08000,114.33000,114.58000,115.08000,115.50000,115.83000,116.25000,116.75000,117.25000,117.75000,118.25000,118.75000,119.17000,119.75000,120.33000,120.92000,121.33000,121.67000,121.92000,122.33000,122.33000,122.25000,122.17000,122.58000,123,123.25000,123.50000,123.92000,123.58000,123.75000,124.33000,124.58000,124.67000,125.17000,125.25000,125.92000,126.08000,126.58000,126.83000,127.42000,127.83000,128.17000,128.17000,128.67000,129.08000,129.67000,129.83000,129.33000,129.75000,129.92000,130.42000,130.42000,130.25000,130.50000,131.08000,131.75000,132.42000,132.48259,132.54512,132.60759,132.67000,132.58490,132.49988,132.41490,132.33000,132.49742,132.66490,132.83243,133,133.50000,134.08000,134.67000,135.25000,135.83000,136.08000,136.50000,137,136.67000,136.58000,136,136,136,135.75000,135.58000,136,136.42000,136.58000,137.33000,137.75000,138.08000,138.67000,138.67000,139.17000,139.42000,140,140.50000,141,141,141.25000,141.50000,141.58000,141.67000,141.58000,141.58000,141.67000,141.75000,141.75000,141.75000,142.08000,142.08000,142.42000,142.83000,142.92000,143.08000,143.33000,143.58000,143.58000,143.75000,144.08000,144.58000,144.92000,145.33000,145.33000,145.33000,145.50000,145.50000,145.83000,146.08000,146.17000,146.08000,146.33000,146.42000,147,147.50000,147.83000,148.33000,148.83000,148.83000,149.17000,149.33000,149.50000,149.75000,150,150.42000,150.83000,150.83000,151,151.33000,151.83000,152.17000,152.58000,152.83000,153.08000,153.08000,153.08000,153.17000,153.33000,153.50000,153.67000,153.50000,153.42000,153.33000,153.08000,153.08000,152.92000,152.75000,152.50000,152.25000,151.83000,151.50000,151.33000,151.08000,150.83000,150.58000,150.25000,150.17000,150,150,149.92000,149.42000,148.75000,148.17000,147.83000,147.25000,147.25000,146.83000,146.42000,146,145.58000,145.50000,145,144.83000,144.42000,144,143.50000,143.08000,142.67000,142.25000,141.75000,141.42000,141.17000,140.67000,140.25000,139.92000,139.75000,139.92000,139.67000,139.33000,138.83000,138.17000,138.42000,138.58000,138.42000,138.08000,137.92000,137.92000,137.75000,137.33000,136.92000,137,137.42000,137.50000,137.58000,137.92000,137.83000,137.50000,137.25000,136.75000,136.33000,135.92000,135.67000,135.42000,135.25000,135,134.83000,134.17000,134.33000,133.92000,133.42000,132.83000,132.25000,131.83000,131.33000,130.83000,130.33000,129.67000,129.67000,129.08000,128.58000,128,127.50000,126.92000,126.25000,125.83000,125.25000,124.75000,124.08000,124,123.58000,123.08000,122.58000,121.92000,121.33000,120.75000,120.08000,119.75000,119.42000,119,118.58000,118.33000,117.75000,117.17000,116.67000,116.08000,115.67000,115.17000,NaN,130.08000,130.33000,130.75000,131.33000,131.50000,131,130.67000,130.08000,NaN,136.58000,136.83000,137.42000,138.08000,137.58000,136.83000,136.58000,NaN,144.83000,145.50000,146.17000,146.75000,147.33000,148,148.33000,148.33000,148.33000,148.17000,148,147.92000,147.50000,147.17000,146.83000,146.25000,145.75000,145.50000,145.33000,145.25000,145,144.83000,144.83000,NaN,175.18901,175.52013,175.53358,175.44466,175.48058,175.75864,175.89690,176.01027,177.02853,177.25839,177.42522,177.73706,178.13823,178.46703,178.49715,178.31409,177.83994,177.82748,177.77208,177.24406,177.05565,176.93449,176.94547,177.06219,177.06259,176.70338,175.92203,175.58119,175.27380,174.89191,174.76491,175.12189,175.29733,175.28041,174.80734,173.95357,173.77315,173.80620,174.56561,174.64946,174.60986,174.64391,174.81117,174.82228,174.61176,174.65239,174.60092,174.23610,174.28772,174.11028,173.83867,174.10678,174.12810,174.05267,173.23621,173.23676,173.11743,173.12076,172.98090,172.63596,172.70975,172.80241,173.02428,173.06192,172.99442,173.17114,173.35213,173.35954,173.47733,174.02635,174.07925,174.16315,174.22922,174.31305,174.30292,174.40526,174.62242,174.54584,174.51370,174.55339,174.37411,174.78976,174.80663,174.69916,174.91733,174.60602,174.59598,174.84828,174.79503,175.19966,175.12350,175.18901,NaN,166.50000,166.83000,167.08000,167.58000,167.92000,168.33000,168.83000,169.50000,170,170.50000,171.08000,171.33000,171.50000,172,172.17000,172.17000,172.58000,172.58000,173.08000,173.17000,173.50000,173.83000,173.92000,174.33000,174.33000,174,173.58000,173.25000,172.83000,172.75000,173.08000,172.42000,172,171.42000,171.25000,171.08000,170.92000,170.58000,170.17000,169.67000,169,168.33000,167.83000,167.58000,167.25000,166.75000,166.50000,NaN,167.58000,168,168.25000,167.58000,NaN,95.330002,95.919998,96.330002,96.919998,97.580002,98,98.250000,98.580002,98.580002,99,99.500000,100,100.33000,100.75000,101.25000,101.75000,102.25000,102.67000,103.08000,103,103.42000,103.83000,103.75000,103.50000,103.83000,104.42000,104.58000,104.92000,105.08000,105.58000,105.92000,106.17000,105.92000,105.92000,105.92000,105.83000,105.75000,105.33000,104.92000,104.92000,104.75000,104.42000,104,103.50000,102.83000,102.42000,102.25000,101.75000,101.33000,100.92000,100.83000,100.50000,100.42000,100,99.830002,99.250000,99.080002,98.830002,98.830002,98.330002,97.830002,97.669998,97.250000,96.919998,96.580002,96.080002,95.669998,95.419998,95.330002,NaN,105.50000,105.83000,106.08000,106.67000,107.08000,107.42000,107.92000,108.42000,108.67000,109.08000,109.58000,110.08000,110.50000,110.83000,110.83000,111.33000,111.92000,112.42000,112.75000,112.83000,113.42000,113.92000,114.42000,114.42000,114.42000,114,113.58000,113.08000,112.50000,112,111.50000,111,110.50000,110,109.58000,109,108.58000,108,107.58000,107,106.50000,106.58000,106,105.50000,NaN,115.25000,114.70000,114.66000,115.25000,115.66000,115.25000,NaN,118.02806,117.80023,117.77113,117.78201,117.89159,118.02868,118.20986,118.34115,118.49058,118.53816,118.53801,118.68399,118.82256,118.92444,118.93816,119.01688,119.04507,119.03831,118.89791,118.76206,118.70125,118.73455,118.36439,118.30132,118.34040,118.30289,118.07381,117.94427,117.40164,117.24517,117.11122,116.93965,116.80444,116.77352,116.83315,116.79523,117.07780,117.61865,117.66089,117.91784,117.99767,118.12435,118.14438,118.02806,NaN,123.12189,122.81408,122.82875,122.15325,122.01051,121.81964,121.42661,121.28008,121.14025,120.61040,119.97549,119.87721,119.88632,120.05154,120.36526,120.66817,121.24595,121.42947,121.57211,121.70924,122.08563,122.26042,122.45721,122.42648,122.84325,122.89603,122.85657,122.75675,122.82258,123.02674,123.11948,123.12189,NaN,123.55663,123.37527,123.52563,123.86489,123.88664,123.55663,NaN,116.41458,115.95900,116.12578,116.13262,116.23606,116.44192,116.65556,116.41458,NaN,124.33000,124.50000,124.66745,124.83493,125.00245,125.17000,124.96007,124.75009,124.54007,124.33000,NaN,125.83000,126,126.67000,126.42000,125.83000,NaN,119,119.50000,120,120.50000,120.92000,120.42000,120,119.67000,119.17000,119,NaN,123.50000,123.67000,123.92000,124.33000,124.83000,125.08000,125.67000,126.25000,126.75000,127.25000,126.92000,126.42000,125.92000,125.42000,124.92000,124.50000,124,123.50000,NaN,131.17000,131.25000,131.58000,131.58000,131.17000,NaN,134.08000,134.08000,134.25000,134.50000,134.67000,134.50000,134.08000,NaN,105.25000,105.50000,106,106.25000,106.42000,106.75000,106.67000,106,106,105.75000,105.25000,NaN,107.67000,107.75000,108.33000,108.08000,107.67000,NaN,113.05882,112.93040,112.83998,113.00318,113.14203,113.79539,113.95089,113.63936,113.05882,NaN,108.92000,109.08000,109.50000,110,110.58000,111.08000,111.33000,111.50000,112,112.58000,113.08000,113.33000,113.75000,113.75000,114.25000,114.75000,115.42000,115.42000,116,116.17000,116.67000,117,117.25000,117.75000,117.75000,118.25000,118.75000,119.25000,118.75000,118.25000,118.58000,117.92000,117.83000,117.50000,117.75000,118.08000,117.83000,118.25000,118.67000,119,118.42000,117.92000,117.67000,117.50000,117.50000,117.42000,117.17000,116.75000,116.33000,116.67000,116.33000,116.17000,115.67000,115.17000,114.75000,114.67000,114.33000,113.83000,113.25000,112.83000,112.33000,111.83000,111.75000,111.42000,110.92000,110.33000,110.25000,110.08000,110.08000,109.75000,109.25000,109.25000,109,108.92000,NaN,118.83000,119.17000,119.33000,119.33000,119.50000,119.83000,119.83000,119.92000,120,120.67000,120.92000,121.42000,122,122.50000,122.92000,123.33000,123.92000,124.42000,124.75000,125,125,125.25000,125,124.58000,124,123.50000,123,122.50000,122,121.42000,121,120.67000,120.33000,120.08000,120.08000,120.58000,120.67000,121.17000,121.58000,122.08000,122.58000,123.17000,123.50000,122.92000,122.50000,122.08000,121.50000,121.92000,122.17000,122.42000,122.08000,122.08000,122.50000,122.83000,123.17000,123.17000,122.67000,122.33000,122.33000,122,121.58000,121.67000,121.17000,120.92000,121.08000,121.08000,120.67000,120.25000,120.42000,120.42000,120.42000,120.33000,120.42000,119.92000,119.50000,119.42000,119.58000,119.67000,119.50000,119,118.83000,NaN,127.33000,127.50000,127.58000,128,127.83000,128.08000,128.67000,128.67000,128.25000,128.50000,128,127.92000,128,128.42000,127.92000,127.58000,127.67000,127.58000,127.51750,127.45501,127.39250,127.33000,NaN,126,126.50000,127,127.17000,126.83000,126.33000,126,NaN,127.92000,128.25000,128.92000,129.50000,129.92000,130.42000,130.75000,130.75000,130.25000,129.42000,128.92000,128.50000,127.92000,NaN,124.61553,124.50847,124.54877,124.70154,125.19090,125.37168,124.61553,NaN,127.33000,127.58000,128.17000,127.96000,127.75000,127.54000,127.33000,NaN,130.33000,130.75000,131.25000,130.75000,130.33000,NaN,135.33000,135.92000,136.25000,135.83000,135.33000,NaN,130.83000,131.25000,131.25000,131.83000,132.17000,132.83000,133.25000,133.92000,134.17000,134,134.17000,134.58000,134.75000,135.17000,135.58000,135.83000,136.08000,136.50000,137,137.25000,137.92000,138.42000,139,139.50000,140,140.42000,141,141.50000,142,142.42000,143,143.50000,144,144,144.50000,145,145.42000,145.75000,145.75000,146.25000,146.83000,147.42000,147.83000,147.83000,147.42000,147,147.17000,147.67000,148.17000,148.25000,148.58000,149.25000,149.08000,149.58000,149.68500,149.78999,149.89500,150,149.93755,149.87506,149.81255,149.75000,149.85497,149.95995,150.06496,150.17000,150.75000,150.58000,150,149.75000,149.25000,148.67000,148.08000,148.08000,147.58000,147.42000,147,146.50000,146.25000,146,145.58000,145,144.67000,144.17000,143.83000,143.58000,143.17000,143.33000,143.17000,142.58000,142,141.50000,141,140.58000,140.25000,140,139.42000,138.83000,138.25000,137.67000,138,138.25000,138.75000,138.58000,138.58000,138.42000,138.17000,137.83000,137.33000,136.75000,136.17000,135.58000,135,134.58000,134.08000,133.67000,133.25000,132.83000,132.75000,132.67000,132.25000,131.92000,132.17000,132.67000,133.08000,133.67000,133.83000,133.25000,132.75000,132.25000,131.83000,131.83000,131.42000,130.83000,NaN,119.83000,120.33000,120.33000,120.50000,120.33000,120.50000,120.67000,121.08000,121.50000,121.92000,122.33000,122.17000,122.17000,122.25262,122.33515,122.41761,122.50000,122.45741,122.41489,122.37241,122.33000,122,121.58000,121.58000,121.42000,121.67000,121.83000,122.25000,122.58000,122.92000,123.33000,123.92000,123.58000,123.75000,124.17000,123.83000,123.42000,123.08000,122.58000,122.67000,122.67000,122.17000,121.75000,121.25000,120.67000,120.67000,121,120.67000,120.58000,120.08000,120,119.92000,119.83000,NaN,117.25000,117.50000,117.92000,118.42000,118.75000,119.17000,119.50000,119.67000,119.17000,118.83000,118.58000,118.17000,117.92000,117.25000,NaN,120.42000,120.83000,121.25000,121.58000,121.58000,121.17000,120.92000,120.75000,120.42000,NaN,124.33000,124.75000,125.25000,125.50000,125.50000,125.67000,125,125,125.25000,124.75000,124.75000,124.42000,124.42000,124.83000,124.87245,124.91494,124.95745,125,124.87508,124.75011,124.62508,124.50000,124.33000,NaN,121.92000,122,122.08000,121.92000,122.50000,122.58000,123.17000,123.08000,123.50000,123.42000,123.83000,124,124,124,124.50000,124.50000,124,123.75000,123.50000,123.17000,123.33000,123,122.67000,122.60756,122.54507,122.48256,122.42000,122.52244,122.62492,122.72744,122.83000,122.83000,122.50000,121.92000,NaN,122,122.08000,122.33000,122.83000,123.08000,123.50000,123.83000,123.92000,124.25000,124.67000,124.83000,125.17000,125.50000,125.42000,125.42000,126,126.33000,126.33000,126.58000,126.58000,126.33000,126.17000,126,125.75000,125.50000,125.33000,125.58000,125.75000,125.42000,125.08000,124.75000,124.33000,124,124,124.25000,124,123.58000,123.25000,122.92000,122.83000,122.50000,122.25000,122.08000,122,NaN,148.25000,148.83000,149.42000,150,150.42000,150.83000,151.25000,151.67000,151.50000,152.25000,152.42000,152.08000,152,151.58000,151.17000,150.67000,150.17000,149.67000,149.17000,148.83000,148.33000,148.25000,NaN,147.19809,146.71855,146.59590,146.75699,147.09242,147.36635,147.19809,NaN,152.46805,153.06102,153.09235,153.04886,152.95467,152.88103,152.72334,152.72090,152.46805,NaN,152.02249,151.93800,151.30389,151.07172,151.14638,151.62180,152.06683,152.08412,152.02249,NaN,154.67000,155.08000,155.58000,156,155.50000,155.17000,154.83000,154.67000,NaN,157.40843,157.30496,157.03313,156.48753,156.47874,156.88623,157.13939,157.40843,NaN,157.84911,157.69815,157.55157,157.46236,157.30003,157.36214,157.43719,157.56998,157.88452,157.84911,NaN,159.78310,158.72592,158.55373,158.60579,159.16772,159.74144,159.83916,159.78310,NaN,161.28508,160.88991,160.83386,160.66780,160.67760,160.80261,160.90369,161.28508,NaN,159.50000,160.25000,160.83000,160.50000,160.08000,159.67000,159.42000,159.50000,NaN,161.25000,162,162.33000,161.75000,161.25000,NaN,166.77623,166.55884,166.57800,166.71307,166.84460,166.98627,167.06303,167.23775,167.20045,166.91267,166.77623,NaN,167.33000,167.92000,167.50000,167.33000,NaN,164.25000,164.75000,165.33000,165.67000,166,166.50000,166.83000,167.17000,166.67000,166.17000,165.75000,165.42000,165,164.58000,164.25000,NaN,-176.83000,-176.17000,-176.58000,-176.50000,-176.83000,NaN,177.33000,177.42000,177.75000,178.25000,178.67000,178.67000,178.17000,177.75000,177.33000,NaN,178.58000,179.17000,179.83000,179.67000,179.92000,179.33000,178.75000,178.58000,NaN,-149.58000,-149.33000,-149.17000,-149.50000,-149.58000,NaN,-159.82001,-159.58000,-159.30000,-159.38000,-159.62000,-159.82001,NaN,-158.28000,-157.98000,-157.67000,-158.12000,-158.28000,NaN,-157.21269,-156.71635,-156.85754,-157.30046,-157.21269,NaN,-156.67999,-156.47000,-156.28000,-155.98000,-156.20000,-156.42999,-156.47000,-156.67999,NaN,-155.88000,-155.63000,-155.37000,-155.13000,-155.02000,-154.80000,-155,-155.30000,-155.52000,-155.64999,-155.92000,-155.88000,-156.05000,-155.87000,-155.88000];
        
        [xtmp,ytmp,ztmp] = sph2cart(deg2rad(coastlon),deg2rad(coastlat),R);
        plot3(xtmp,ytmp,ztmp,'b','linewidth', 0.85)% plot coastline
        
        [xtmpn,ytmpn,ztmpn] = sph2cart(deg2rad(data.longitude),deg2rad(data.latitude),R);
        plot3(xtmpn,ytmpn,ztmpn,'r','linewidth', 1.25)% plot voyage track
        
        % Set azimuth and elevation for southern ocean
        view(-153, -36);
        title({filename; 'Platform track'}, 'FontSize',9, 'Interpreter', 'none');
        
        % Standard plot (as subplot)
        subplot(1,2,2)
        hold on; box on; grid on
        plot(data.longitude,data.latitude,'r.');
        
        % midnight positions
        begin = floor(time(1));
        fin = floor(time(end)) - begin;
        
        lt = zeros(fin, 1);
        ln = zeros(fin, 1);
        
        for d = 1:fin
            midnight = find(time >= begin + d, 1);
            lt(d) = data.latitude(midnight);
            ln(d) = data.longitude(midnight);
            text(ln(d), lt(d), datestr(time(midnight), 'yyyy-mm-dd'));
        end
        plot(ln, lt, '+');
        
        xlabel('Longitude (degrees)');
        ylabel('Latitude (degrees)');        
        
        lat = median(data.latitude);
        set(gca, 'DataAspectRatio', [1 cosd(lat) 1 ]);
    end
end
%% Function for generating echogram plots of the dataset as an image

    function echogram(dataset, position, ttle, location, range, cmap, sun)
    %   echogram plots the dataset as an image.
    %   INPUTS
    %   dataset     2D data to plot (if more than 2D only first slice is
    %               plotted)
    %   position    number of plot heights from bottom of screen to place
    %               plot
    %   ttle        Title of plot
    %   location    String array of labels for start and end of plot
    %   range       Range of colortable used to display data.
    %   cmap        Colormap used to display data [EK500colourmap]
    %   sun         Optional vector drawn on image, usually 1 = day 0 = night
        
        screen = getScreen();        
        [dheight, dwidth] = size(dataset);
        if screen(3) - screen(1) < dwidth + 100
            ll = { location{1}, '2 -->' };
            if nargin < 6
                cmap=EK500colourmap();
            end
            swidth=screen(3) - screen(1) - 200;
            page=0;
            while page * swidth < dwidth
                dstart = page * swidth + 1;
                page = page + 1;
                dend = page * swidth;
                if dend >= dwidth
                    dend = dwidth;
                    ll{2} = location{2};
                end
                ds=dataset(:,dstart:dend,1);
                if nargin < 7 || isempty(sun)
                    sn = [];
                else
                    sn = sun(dstart:dend);
                end
                echogram(ds, position, ttle, ll, range, cmap, sn)
                set(gcf, 'User', dstart-1);                
                ticks(gcf);
                
                ll ={ ['<-- ' num2str(page)], [num2str(page + 2) ' -->']};               
            end
            
            return
        end
        
        figure
        drawnow     % need to draw figure before setting position on dual screen systems
        
        imagesc(dataset(:,:,1), range)
        if nargin < 6 || isempty(cmap)
            colormap(EK500colourmap())
        else
            colormap(cmap)
        end
        
        if nargin > 6 && ~isempty(sun)
            % plot sun between 1/4 and 3/4 height of image.
            hold on
            yl = ylim;
            scl = 0.5 * (yl(1) - yl(2)) / (max(sun) - min(sun));
            off = yl(2) + 0.25 * (yl(1) - yl(2)) - min(sun) * scl;
            plot(sun * scl + off, 'r')            
        end
        
        set(zoom,'ActionPostCallback',@ticks)
        set(pan,'ActionPostCallback',@ticks)
        
        if tickformat == LAT
            xlabel('Latitude')
        elseif tickformat == LONG
            xlabel('Longitude')
        elseif tickformat == INTERVAL
            xlabel(['Distance (' grid_distance ')'])
        else
            xlabel('Time (UTC)')
        end
        
        ylabel('Depth (m)')  
        title(ttle, 'Interpreter','tex','FontSize',11); % Haris 30/09/2020 changed Interpreter to 'tex' and defined font size         
        colorbar;
        
        % fit figure on "screen"
        % calculate image size
        left = 80;
        bot  = 50;
        width = dwidth + 2 * left;
        height = dheight + 2 * bot;
        base = 100 + floor(position * 1.4 * height);
        set(gcf, 'Position',  [screen(1) base width height]);
        pos = get(gcf, 'Position');
        
        text(0, -10, location{1});
        text(dwidth, -10, location{2}, 'HorizontalAlignment', 'right');
        
        % keep figure from going over top of screen
        opos = get(gcf, 'OuterPosition');
        above = opos(2) + opos(4) - screen(4);
        if above > 0
            pos(2) = pos(2) - above;
            set(gcf, 'Position', pos);
        end
        
        % if figure is too wide for screen
        if screen(3) - screen(1) < width
            left = (screen(3) - screen(1) - opos(3) + pos(3) - dwidth) / 2;
            if left < 30
                left = 30;
            end
        end
        
        % set image to one pixel per cell
        set(gca, 'Units', 'pixels');
        set(gca, 'Position', [left, bot, dwidth, dheight]);
        set(gca, 'Units', 'normalized');
        
        button_panel = uibuttongroup(gcf, ...
            'SelectionChangeFcn', @xFormat, ...
            'Units',        'pixels', ...
            'Position',     [0 0 600 20]);
        
        uicontrol(button_panel, ...
            'Style',        'radiobutton', ...
            'TooltipString', 'Show time across X axis', ...
            'Tag',          'time', ...
            'String',       'Time', ...
            'Value',        tickformat == TIME, ...
            'User',         TIME, ...
            'Units',        'pixels', ...
            'Position',     [0 0 100 20]);
        uicontrol(button_panel, ...
            'Style',        'radiobutton', ...
            'TooltipString', 'Show latitude across X axis', ...
            'Tag',          'latitude', ...
            'String',       'Latitude', ...
            'Value',        tickformat == LAT && degformat == DEG, ...
            'User',         LAT, ...
            'Units',        'pixels', ...
            'Position',     [100 0 100 20]);
        uicontrol(button_panel, ...
            'Style',        'radiobutton', ...
            'TooltipString', 'Show longitude across X axis', ...
            'Tag',          'longitude', ...
            'String',       'Longitude', ...
            'Value',        tickformat == LONG && degformat == DEG, ...
            'User',         LONG, ...
            'Units',        'pixels', ...
            'Position',     [200 0 100 20]);
        uicontrol(button_panel, ...
            'Style',        'radiobutton', ...
            'TooltipString', 'Show latitude across X axis in deg:min', ...
            'Tag',          'lat:min', ...
            'String',       'Lat (d:m)', ...
            'Value',        tickformat == LAT && degformat == MIN, ...
            'User',         LAT, ...
            'Units',        'pixels', ...
            'Position',     [300 0 100 20]);
        uicontrol(button_panel, ...
            'Style',        'radiobutton', ...
            'TooltipString', 'Show longitude across X axis in deg:min', ...
            'Tag',          'long:min', ...
            'String',       'Long (d:m)', ...
            'Value',        tickformat == LONG && degformat == MIN, ...
            'User',         LONG, ...
            'Units',        'pixels', ...
            'Position',     [400 0 100 20]);
        uicontrol(button_panel, ...
            'Style',        'radiobutton', ...
            'TooltipString', 'Show distance number across X axis', ...
            'Tag',          'distance', ...
            'String',       'Distance', ...
            'Value',        tickformat == INTERVAL, ...
            'User',         INTERVAL, ...
            'Units',        'pixels', ...
            'Position',     [500 0 100 20]);
        
        % update axis
        ticks(gcf)
    end

    function [EK500cmap]=EK500colourmap()
    % EK500colourmap is the colour map used by EK500
    
        EK500cmap = [255   255   255   % white
            159   159   159   % light grey
            95    95    95   % grey
            0     0   255   % dark blue
            0     0   127   % blue
            0   191     0   % green
            0   127     0   % dark green
            255   255     0   % yellow
            255   127     0   % orange
            255     0   191   % pink
            255     0     0   % red
            166    83    60   % light brown
            120    60    40]./255;  % dark brown
    end

    function xFormat(panel,event)
    % Callback used when the user selects a different X axis label
    
        tickformat = get(event.NewValue, 'User');
        
        if tickformat == LAT
            xlabel('Latitude')
        elseif tickformat == LONG
            xlabel('Longitude')
        elseif tickformat == INTERVAL
            xlabel(['Distance (' grid_distance ')'])
        else
            xlabel('Time (UTC)')
        end
        
        tag = get(event.NewValue, 'Tag');
        if length(tag) > 3 && strcmp(tag(end-2:end), 'min')
            degformat = MIN;
        else
            degformat = DEG;
        end
        
        fig = get(panel, 'Parent');
        ticks(fig, event)
    end

    function ticks(figure,~)
    % Callback used to draw tick marks    
        caxes=get(figure,'CurrentAxes');
        
        % depth ticks
        ytick=get(caxes,'YTick');
        
        set(caxes,'YTickLabel',depth(floor(ytick)));
        
        offset = 0;
        x_lim=get(caxes,'XLim');
        set(caxes,'Units','Pixels');
        pos = get(caxes, 'Position');
        width = pos(3);
        user = get(figure, 'User');
        if ~isempty(user) && isfloat(user)
            offset = user;
        end
        x_lim = x_lim + offset;
        
        %
        % Label X axis using latitude or longitude
        %
        if tickformat == LAT || tickformat == LONG
            
            if tickformat == LONG
                ticker = longitude;
            else
                ticker = latitude;
            end
            
            ticker = ticker(ceil(x_lim(1)):floor(x_lim(2)));
            mint = min(ticker);
            maxt = max(ticker);
            trange = (maxt - mint)/width*100;
            if degformat == MIN
                if trange > 2       % more than 2 degrees per 100 pixels
                    tock = 1;       % show whole degrees 
                elseif trange > .5  % more than 1 degree per 200 pixels
                    tock = 4;       % show 15 minutes
                elseif trange > .05
                    tock = 12;      % show 5 minutes
                else
                    tock = 60;      % show minutes
                end
            else
                if trange > 10      % more than 1 degree per 10 pixels
                    tock = .1;      % show every 10 degrees
                elseif trange > 5   % more than 1 degree per 20 pixels
                    tock = .2;      % show every 5 degrees
                elseif trange > 1   % more than 1 degree per 100 pixels
                    tock = 1;       % show each degree
                elseif trange > .5  % more than 1 degree per 200 pixels
                    tock = 2;       % show half degrees
                else
                    tock = 10;      % show tenth degrees
                end
            end
            
            tickedge = floor(ticker * tock);
            tk=tickedge;
            tk(end) = [];
            tickedge(1) = [];
            xtick = find(tk ~= tickedge);
            xtick = xtick + 1;
            xlabels = num2str(ticker(xtick),'%4.0f');
            if tock > 1
                if degformat == MIN
                    xdeg = round(ticker(xtick)*60)/60;
                    xmin = xdeg - fix(xdeg);
                    xmin = abs(xmin) * 60;
                    colon= char(ones(length(xmin),1) * ':');
                    xlabels = [ num2str(fix(xdeg)) colon num2str(xmin, '%02.0f') ];
                else
                    if tock <= 10
                        xlabels = num2str(ticker(xtick),'%6.1f');
                    else
                        xlabels = num2str(ticker(xtick),'%7.2f');
                    end
                end
            end
            xtick = xtick + ceil(x_lim(1));
            
        elseif tickformat == INTERVAL
            xtick = 0:max(1,10^(floor((log10((x_lim(2) - x_lim(1))/width*2000))-1))):x_lim(2);
            xlabels = xtick;

        else
            %
            % Label X Axis using Time
            %
            
            start=time(ceil(x_lim(1)));
            finish=time(floor(x_lim(2)));
            
            len=(finish-start)/width*100;
            if len < .01
                format = 15;    % 'HH:MM'
                tock=96;        % quarter hour
            elseif len < .05
                format = 15;    % 'HH:MM'
                tock=24;        % hour
            elseif len < .2
                format = 'yyyy-mm-dd HH:MM';
                tock=4;         % 6 hr
            else
                format=29;      % 'yyyy-mm-dd'
                tock=1;         % day
            end           
            
            xtock=(ceil(start*tock):1:finish*tock)/tock;
            if isempty(xtock); xtock = start; end
            xtick(length(xtock))=0;
            for i=1:length(xtock)
                xtick(i)=find(time>=xtock(i),1);
            end
            
            xtick(diff(xtick) == 0) = [];
            xlabels = datestr(time(xtick), format);
        end
        
        set(caxes,'XTick',xtick - offset);
        set(caxes,'XTickLabel',xlabels);
    end

    function fig = write_echogram(dataset, imagefile, file, channel, ttle, location, range, cmap, fig)
    % write_echogram writes the echogram to an image file.
    
    % Haris 24 January 2019 - modified: The 'PNG' image file had issues with
    % width, height, and font sizes. This was creating an image file with
    % overlapping fonts that were out of the image box.
    % Some lines below have been modified to write an image for better display. 
    % Original code is commented i.e. not deleted.
    
        [~, name, ext] = fileparts(file);
        
        % size figure to hold full data set
        dotspercell = 1;
        resolution = 300;
        fontsize = 1200 * dotspercell / resolution;
        dwidth = size(dataset,2);
        wdth = dwidth*dotspercell/resolution;
        hght = size(dataset,1)*dotspercell/resolution;
%         left = 0.5 + 50 / resolution;
%         bot  = 4 * fontsize / 72;
%         width = wdth + 2 * left;
%         height = hght + 2 * bot;
        left = 0.2 + 50 / resolution;
        bot  = 5.5 * fontsize / 72;
        width = wdth + 2.8 * left;
        height = hght + 2 * bot;
        
        if nargin < 9 || isempty(fig)
            fig = figure;
        else
            figure(fig)
            oldpos = get(fig, 'Position');
            dheight = height;
            height = dheight + oldpos(4);
            set(fig, 'Position', [0, 0.5, width, height ] );
            children = get(fig, 'Children');
            for i = length(children):-1:1
                if ~strcmp(get(children(i), 'Tag'), 'Colorbar')
                    set(children(i), 'Units', 'inches');
                    chpos = get(children(i), 'Position');
                    chpos(2) = chpos(2) + dheight;
                    set(children(i), 'Position',chpos);
                end
            end
        end
        
        set(fig, 'Units', 'inches');
        set(fig, 'Position', [0, 0.5, width, height ] );
        
        set(fig, 'PaperUnits', 'inches');
        set(fig, 'PaperSize', [width height]);
        set(fig, 'PaperPositionMode', 'manual');
        set(fig, 'PaperPosition', [0 0 width height]);
        
        ax = axes('Units', 'inches', 'FontSize', fontsize, 'Position', [left, bot, wdth, hght]); % Haris-the fontsize set here is not holding after colormap
        imagesc(dataset, range);

        if isempty(cmap)
            colormap(ax, EK500colourmap)
        else
            colormap(ax, cmap)
        end
        
        set(ax,'FontSize',5); % Haris- added to set fontsize
        
        if tickformat == LAT
            xlabel('Latitude')
        elseif tickformat == LONG
            xlabel('Longitude')
        elseif tickformat == INTERVAL
            xlabel(['Distance (' grid_distance ')'])
        else
%             xlabel('TIME (UTC)')
            xlabel('Time (UTC)','FontSize', 6)
        end
        
%         ylabel('Depth (m)')
        ylabel('Depth (m)','FontSize', 6)
        
        % Haris 2020-04-21: to add condition for controlling font size of
        % title. Earlier for small transects title was out of the image box.
        
        if dwidth <= 1000
            fontsize = 2.5;
        else 
            fontsize = 5;
        end
        
        if iscell(ttle)
%             title(ttle, 'Interpreter','none')
            title(ttle, 'Interpreter','none','FontSize', fontsize)
        else
%             title({ [ name ext ' ' channel ] ;  ttle }, 'Interpreter','none')
            name_n = name;
            name_n(name_n == '_') = '-'; % Haris- replace '_' with '-' for Interpreter
            title({[ name_n ext ' ' channel ];'Mean {\itS_v} (dB re 1 m^2 m^-^3)'},'FontSize', fontsize) % Haris - for better display of symbol and unit
        end
        step = 10^ceil(log10((range(2) - range(1)) / 6));
        if (range(2) - range(1)) / step < 1.5
            step = step / 5;
        elseif (range(2) - range(1)) / step < 3
            step = step / 2;
        end
        
        colorbar('EastOutside', 'peer', ax, 'FontSize', fontsize, 'YTick', step * ceil(range(1)/step):step:range(2)); % For text - color bar
        set(ax, 'Position', [left, bot, wdth, hght]);
        text(0, -15, location{1}, 'FontSize', fontsize); % For text - transect start
        text(dwidth, -15, location{2}, 'HorizontalAlignment', 'right', 'FontSize', fontsize); % For text - transect end       
        
        ticks(fig)
        drawnow;
        
        if strcmp(imagefile, '-')
            % don't write file or close figure
        else
            driver = '-dpng';
            
            if ~isempty(channel)
                channel = ['_' channel];
            end
            
            % does image file end in a '?'
            ask = 0;
            if ~isempty(imagefile) && imagefile(end) == '?'
                ask = 1;
                imagefile = imagefile(1:end-1);
            end
            % is an empty character string
            if isempty(imagefile)
                imagefile = [ file channel '.png' ];
            end
            % is a driver
            if imagefile(1) == '-' && imagefile(2) == 'd'
                driver = imagefile;
                imagefile = [ file channel '.' imagefile(3:end) ];
            end
            % is a directory
            if isdir(imagefile)
                imagefile = fullfile(imagefile, [ name ext channel '.png' ]);
            end
            % ask the user if the image file ended in ?
            if ask
                [imagefile, ipath] = uiputfile(imagefile);
                if imagefile == 0
                    return
                end
                imagefile = fullfile(ipath, imagefile);
            end
            
            print(fig, driver, imagefile, ['-r' num2str(resolution)]);
            
            close;
        end
    end

    function vardata = getNetcdfVar(ncid, vid)
    % read a variable from netcdf
        if ischar(vid)
            vid = netcdf.inqVarID(ncid, vid);
        end
        vardata = netcdf.getVar(ncid, vid);
        try
            vfill = netcdf.getAtt(ncid, vid, '_FillValue');
            vardata(vardata == vfill) = NaN;
        catch 
        end
    end

    function nmean = nmean(data)
    % calculate mean ignoring NaN values
        nan = isnan(data);
        data(nan) = 0;
        count = sum(~nan);
        count(count==0) = NaN;      % prevent divide by 0
        nmean = sum(data)./count;
    end

    function screen = getScreen()
    % calculate plottable area of screen, this gets hairy for multiple monitors
    % returns [left top width height]
        screen = get(0, 'ScreenSize');
        
        mpos = get(0,'MonitorPosition');
        if ispc
            screen(1) = min(mpos(:,1));
            screen(3) = max(mpos(:,3));
        elseif isunix
            screen(1) = min(mpos(:,1));
            screen(3) = max(mpos(:,1) + mpos(:,3));
        elseif ismac
        end
    end

%% Function for generating *.sv.csv and *.gps.csv file from data structure
    
    function svcsv(data)
    % generate .sv.csv and .gps.csv file from data structure
        [path,name,ext] = fileparts(data.file);
        
        ns = length(data.depth);
        h = (data.depth(end) - data.depth(1)) / (ns-1);
        srange = sprintf('%g, %g, %g', data.depth(1) - h/2, data.depth(end) + h/2, ns);

        if isfield(data, 'channels')
            for s = length(data.channels):-1:1
                sv(s) = fopen(fullfile(path,[name ext '_' data.channels{s} '.sv.csv']),'w');
            end
        else
            sv = fopen(fullfile(path,[name ext '.sv.csv']),'w');
        end
        for s = 1 : length(sv)
            fprintf(sv(s), 'Ping_date, Ping_time, Ping_milliseconds, Range_start, Range_stop, Sample_count,\n');
        end
        
        gps = fopen(fullfile(path,[name ext '.gps.csv']),'w');
        fprintf(gps,'GPS_date, GPS_time, GPS_milliseconds, Latitude, Longitude\n');
        for i=1 : length(data.time)
            timestr = datestr(data.time(i), 'yyyy-mm-dd,HH:MM:SS,FFF');
            fprintf(gps,timestr);
            fprintf(gps,'%s,%g,%g\n', timestr, data.latitude(i), data.longitude(i));
            for s = 1 : length(sv)
                fprintf(sv(s), '%s, %s', timestr, srange);
                fprintf(sv(s), ', %g', data.Sv(:,i,s));
                fprintf(sv(s), '\n');
            end
        end
        fclose(gps);
        for s = 1 : length(sv)
            fclose(sv(s));
        end
    end

%% Function for generating *.csv file from summary layer metrics 
    
    function csv(data, file)
    % generate .csv file from summary indices
        csv.Time = datestr(data.time, 'yyyy-mm-dd HH:MM:SS');
        csv.Longitude = data.longitude;
        csv.Latitude = data.latitude;
        if isfield(data, 'day')
            dsrn = 'DSRN';
            csv.Daylight = dsrn(data.day)';
        end
        for layer = {'epipelagic', 'upper_mesopelagic', 'lower_mesopelagic'}
            if isfield(data, layer)
                if isfield(data, 'channels') && length(data.channels) > 1
                    for i = 1 : length(data.channels)
                        field = sprintf('%s_%s', layer{1}, data.channels{i});
                        csv.(field) = data.(layer{1})(i,:);
                    end
                end
            end
        end
        if isempty(file)
            file = [data.file '.csv'];
        end
        struct2txt(csv, file);
    end

%% Function for generating *.inf and *.gps.csv files from data structure
    
    function info(data)
    % generate .inf and .gps.csv file from data structure
        [path,name,ext] = fileparts(data.file);
        
        gps = fopen(fullfile(path,[name ext '.gps.csv']),'w');
        fprintf(gps,'GPS_date,GPS_time,GPS_milliseconds,Latitude,Longitude\n');
        for i=1:length(data.time)
            fprintf(gps,datestr(data.time(i), 'yyyy-mm-dd,HH:MM:SS,FFF,'));
            fprintf(gps,'%g,%g\n', data.latitude(i), data.longitude(i));
        end
        fclose(gps);
        
        inf = fopen(fullfile(path,[name ext '.inf']),'w');
        fprintf(inf,'\nData File:     ');
        fprintf(inf, [name ext]);
        
        % Haris 24/04/2020- added vessel name to the INF.
        ship_name = ncreadatt(data.file, '/', 'ship_name');
        fprintf(inf,'\n\nVessel: %s\n', ship_name);
        
        fprintf(inf,'\nIntervals: %d\n', length(data.time));
        
        distance = length(data.time)/1000;   
        scale = data.grid_distance;
        if scale(end) == 'm'
            scale(end) = [];
            if scale(end) == 'k'
                scale(end) = [];
                distance = distance * 1000;
            end
            if scale(end) == 'N'
                scale(end) = [];
                distance = distance * 1852;
            end
        end
        try
            distance = distance * str2double(scale);
        catch
            distance = distance * 1000; % if unparsable assume 1km
        end
        
        duration = (data.time(end) - data.time(1)) * 24;
        speed = distance / duration;
        fprintf(inf,'\nNavigation Totals:\nTotal Time:         % 9.4f hours\n', duration);
        fprintf(inf,'Total Track Length: % 9.4f km\n', distance);
        fprintf(inf,'Average Speed:    % 9.4f km/hr (%.4f knots)\n', speed, speed / 1.852);
    
        fprintf(inf,'\nStart of Data:\nTime:  ');
        fprintf(inf,datestr(data.time(1),'yyyy-mm-dd HH:MM:SS.FFF'));
        dv=datevec(data.time(1));
        dv(2:6)=0;
        fprintf(inf,'  JD%d\n',floor(data.time(1) - datenum(dv)));
        fprintf(inf,'Lon:  % 9.4f    Lat: % 9.4f\n', data.longitude(1), data.latitude(1));
        
        fprintf(inf,'\nEnd of Data:\nTime:  ');
        fprintf(inf,datestr(data.time(end),'yyyy-mm-dd HH:MM:SS.FFF'));
        dv=datevec(data.time(end));
        dv(2:6)=0;
        fprintf(inf,'  JD%d\n',floor(data.time(end) - datenum(dv)));
        fprintf(inf,'Lon:  % 9.4f    Lat: % 9.4f\n', data.longitude(end), data.latitude(end));
        
        fprintf(inf,'\nLimits\n');
        fprintf(inf,'Minimum Longitude:     % 9.4f   Maximum Longitude:     % 9.4f\n', ...
            min(data.longitude), max(data.longitude));
        fprintf(inf,'Minimum Latitude:      % 9.4f   Maximum Latitude:      % 9.4f\n', ...
            min(data.latitude), max(data.latitude));
        
        fclose(inf);
    end
end
