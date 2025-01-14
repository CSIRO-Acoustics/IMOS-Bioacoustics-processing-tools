function sample_data = correct_sound_speed(sample_data, varargin)
% Apply sound speed and sound absorption corrections to BASOOP data.
%
% Usage:
% sample_data = correct_sound_speed(sample_data) - correct sample data
%   using Coppen's sound speed formula and Francois and Garrison sound
%   absorption formula.
% sample_data = correct_sound_speed(..., 'Coppens') use Coppen's speed
% sample_data = correct_sound_speed(..., 'Mackenzie') use Mackenzie's speed
% sample_data = correct_sound_speed(..., 'GSW') use Gibbs seawater speed
% sample_data = correct_sound_speed(..., 'Francois') use Francois and
%   Garrison absorption
% sample_data = correct_sound_speed(..., 'Doonan') use Doonan's absorption
% sample_data = correct_sound_speed(..., 'pH', ph) use ph in Francois
% sample_data = correct_sound_speed(..., channel) specify data channel
%   (deprecated)
%
% sample_data is an IMOS toolbox data structure.
%
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
COPPENS = 0;
MACKENZIE = 1;
GSW = 2;
FRANCOIS = 0;
DOONAN = 1;

speed_formula = COPPENS;
absorption_formula = FRANCOIS;
channel = '38';
pH = 8.2;

if isempty(sample_data)
    error('No data to correct');
end

for k = 1:length(varargin)
    if ischar(varargin{k})
        if strcmpi(varargin{k}, 'coppens')
            speed_formula = COPPENS;
        elseif strcmpi(varargin{k}, 'mackenzie')
            speed_formula = MACKENZIE;
        elseif strcmpi(varargin{k}, 'gsw')
            speed_formula = GSW;
        elseif strcmpi(varargin{k}, 'teos-10')
            speed_formula = GSW;
            
        elseif strcmpi(varargin{k}, 'francois')
            absorption_formula = FRANCOIS;
        elseif strcmpi(varargin{k}, 'doonan')
            absorption_formula = DOONAN;
            
        elseif strcmpi(varargin{k}, 'ph')
            pH = varargin{++k};
            
        else
            channel = varargin{k};
        end
        
    else    
        channel = num2str(varargin{k});
    end
end

% identify dimensions and variables used in processing
evfiled = [];
tempv = [];
salv = [];
latv = [];
lonv = [];
svv = [];
pcv = [];
depthv = [];
asvv = [];
usvv = [];
upcv = [];
ssv = [];
absv = [];


for k = 1:length(sample_data.dimensions)
    if strcmpi(sample_data.dimensions{k}.name, 'DEPTH')
        depthd = k;
    end
    if strcmpi(sample_data.dimensions{k}.name, 'EV_FILENAME')
        evfiled = k;
    end
end

for k = 1:length(sample_data.variables)
    if strcmpi(sample_data.variables{k}.name, 'temperature')
        tempv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'salinity')
        salv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'latitude')
        latv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'longitude')
        lonv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'sv')
        svv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'Sv_pcnt_good')
        pcv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'mean_depth')
        depthv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'mean_range')
        if isempty(depthv); depthv = k; end
    end
    if strcmpi(sample_data.variables{k}.name, 'uncorrected_Sv_pcnt_good')
        upcv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'uncorrected_sv')
        usvv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'abs_corrected_sv')
        asvv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'sound_speed')
        ssv = k;
    end
    if strcmpi(sample_data.variables{k}.name, 'absorption')
        absv = k;
    end
    
    % support deprecated channels
    if strcmpi(sample_data.variables{k}.name, ['sv_' channel])
        svv = k;
    end
    if strcmpi(sample_data.variables{k}.name, ['Sv_pcnt_good_' channel])
        pcv = k;
    end
    if strcmpi(sample_data.variables{k}.name, ['mean_depth_' channel])
        depthv = k;
    end
    if strcmpi(sample_data.variables{k}.name, ['mean_range_' channel])
        if isempty(depthv); depthv = k; end
    end
    if strcmpi(sample_data.variables{k}.name, ['uncorrected_percent_good_' channel])
        upcv = k;
    end
    if strcmpi(sample_data.variables{k}.name, ['uncorrected_Sv_pcnt_good_' channel])
        upcv = k;
    end
    if strcmpi(sample_data.variables{k}.name, ['uncorrected_sv_' channel])
        usvv = k;
    end
end

% load data needed for processing
sso = [];
if isfield(sample_data, 'meta') && isfield(sample_data.meta, 'channels') && ...
        isfield(sample_data.meta.channels, 'data_processing_soundspeed') 
    sso = [sample_data.meta.channels.data_processing_soundspeed ];
end
if isempty(sso)
    % try and find a usable value
    if isfield(sample_data, 'data_processing_soundspeed') && ~isempty(sample_data.data_processing_soundspeed)
        sso = sample_data.data_processing_soundspeed;       
    elseif isfield(sample_data, 'transceiver_soundspeed') && ~isempty(sample_data.transceiver_soundspeed)
        sso = sample_data.transceiver_soundspeed;
    elseif isfield(sample_data,['transceiver_soundspeed_' channel])
        sso = sample_data.(['transceiver_soundspeed_' channel]);
    end
    if ischar(sso)
        sso = str2num(sso); %#ok<ST2NM>
    end
end

sao = [];
if isfield(sample_data, 'meta') && isfield(sample_data.meta, 'channels') && ...
        isfield(sample_data.meta.channels, 'data_processing_absorption')
    sao = [sample_data.meta.channels.data_processing_absorption];
end
if isempty(sao)
    if isfield(sample_data, 'data_processing_absorption') && ~isempty(sample_data.data_processing_absorption)
        sao = sample_data.data_processing_absorption;
    elseif isfield(sample_data, 'transceiver_absorption') && ~isempty(sample_data.transceiver_absorption)
        sao = sample_data.transceiver_absorption;
    elseif isfield(sample_data,['transceiver_absorption_' channel])
        sao = sample_data.(['transceiver_absorption_' channel]);
    end
    if ischar(sao)
        sao = str2num(sao); %#ok<ST2NM>
    end
end

if (isempty(sso) || isempty(sao)) && ~isempty(evfiled)
    % Attempt to read sound speed and absorption from echoview
    % This code makes a number of assumptions 
    evfile = sample_data.dimensions{evfiled}.data{1};
    fprintf('Attempting to get sound speed and absorption settings from %s\n', evfile);
    EvApp = actxserver('EchoviewCom.EvApplication');
    EvFile = EvApp.OpenFile(evfile);
    if isfield(sample_data, 'meta') && isfield(sample_data.meta, 'channels')
        for c = 1:length(sample_data.meta.channels)
            chan = sample_data.meta.channels(c).name;
            vars = EvFile.Variables;
            found = false;
            for v = 1:vars.Count;
                if strfind(vars.Item(v-1).Name, chan)   % if the variable name includes the channel name assume it is for this channel and use its calibration 
                    found = true;
                    break;
                end
            end
            if found
                cal = vars.Item(v-1).Properties.Calibration;
                sso = str2double(cal.Get('SoundSpeed', 0));
                sao(c) = str2double(cal.Get('AbsorptionCoefficient', 0)); %#ok<AGROW>
                fprintf('%s using sound speed %g and absorption %g\n', chan, sso, sao(c));
            end           
        end
    else
        % Do we need to support this deprecated case? if so how?
    end
    EvFile.Close();
    EvApp.Quit();
end


if isempty(sso)
    warning('CORRECT:NO_SOUND_SPEED', 'Transceiver sound speed not found - using 1500 m/s')
    keyboard
    % Added keyboard, don't assume values: fix this issue and proceed - Haris 13/09/2020 
    sso = 1500;
end

if isempty(sao)
    warning('CORRECT:NO_ABSORPTION', 'Transceiver sound absorption not found - using 9.7 dB/km')
    keyboard
    % Added keyboard, don't assume values: fix this issue and proceed - Haris 13/09/2020
    sao = .0097;
end

transducer_depth = [];
if isfield(sample_data, 'meta') && isfield(sample_data.meta, 'channels') && ...
        isfield(sample_data.meta.channels, 'data_processing_transducer_depth')
    transducer_depth = [sample_data.meta.channels.data_processing_transducer_depth];
end
if isempty(transducer_depth)
    if isfield(sample_data, 'meta') && isfield(sample_data.meta, 'channels') && ...
            isfield(sample_data.meta.channels, 'instrument_transducer_depth') && ...
            ~isempty([sample_data.meta.channels.instrument_transducer_depth])
        transducer_depth = [ sample_data.meta.channels.instrument_transducer_depth];        
    elseif isfield(sample_data, 'data_processing_transducer_depth') && ~isempty(sample_data.data_processing_transducer_depth)
        transducer_depth  = sample_data.data_processing_transducer_depth;
    elseif isfield(sample_data, 'instrument_transducer_depth') && ~isempty(sample_data.instrument_transducer_depth)
        transducer_depth  = sample_data.instrument_transducer_depth;
    elseif isfield(sample_data, 'transducer_depth')
       transducer_depth  = sample_data.transducer_depth;
    elseif isfield(sample_data,['transducer_depth_' channel])
       transducer_depth  = sample_data.(['transducer_depth_' channel]);
    end
    if isempty(transducer_depth)
        warning('CORRECT:NO_DEPTH', 'Transducer depth not found - using 5 m')
        transducer_depth = 5;
    end
    if isfield(sample_data.meta, 'channels')
        for i = 1:length(transducer_depth)
            if i <= length(sample_data.meta.channels)
                sample_data.meta.channels(i).data_processing_transducer_depth = transducer_depth(i);
            end
        end
    else
        sample_data.data_processing_transducer_depth = transducer_depth;
    end
end

freq = [];
if isfield(sample_data, 'meta') && isfield(sample_data.meta, 'channels') && ...
        isfield(sample_data.meta.channels, 'data_processing_frequency')
    freq = [sample_data.meta.channels.data_processing_frequency];
    if isempty(freq) && isfield(sample_data.meta.channels, 'frequency')
        freq = [sample_data.meta.channels.frequency];
    end
    if isempty(freq) && isfield(sample_data.meta.channels, 'instrument_frequency')
        freq = [sample_data.meta.channels.instrument_frequency];
    end
end
if isempty(freq)
    if isfield(sample_data, 'frequency') && ~isempty(sample_data.frequency)
        freq = sample_data.frequency;
    elseif isfield(sample_data, 'data_processing_frequency') && ...
            ~isempty([sample_data.data_processing_frequency])
        freq = [sample_data.data_processing_frequency];
    elseif isfield(sample_data,['frequency_' channel])
        freq = sample_data.(['frequency_' channel]);
    elseif isfield(sample_data, 'instrument_frequency')
        freq = sample_data.instrument_frequency;
    end
    if isempty(freq)
        warning('CORRECT:NO_FREQUENCY', 'Transceiver frequency not found - using 38 kHz')
        keyboard
        % Added keyboard, don't assume values: fix this issue and proceed - Haris 13/09/2020
        freq = 38;
    end
    if isfield(sample_data.meta, 'channels')
        for i = 1:length(freq)
            if i <= length(sample_data.meta.channels)
                sample_data.meta.channels(i).data_processing_frequency = freq(i);
            end
        end
    else
        sample_data.data_processing_frequency = freq;
    end
end
    
if length(sso) < length(freq)
    sso(end+1:length(freq)) = sso(1);
end
if length(sao) < length(freq)
    if max(freq(length(sao)+1:length(freq)) ~= freq(1))
        warning('CORRECT:FREQ','Missing transceiver sound absorption for some frequencies, using dodgy values');
    end
    sao(end+1:length(freq)) = sao(1);
end
if length(transducer_depth) < length(freq)
    % Note we only use transducer_depth(1) in sound speed and absorption
    % corrections, we assume the difference in transducer depths is
    % insignificant for efficiency.
    transducer_depth(end+1:length(freq)) = transducer_depth(1);
end


if ~isempty(latv)
    latitude = sample_data.variables{latv}.data;
end
if ~isempty(lonv)
    longitude = sample_data.variables{lonv}.data;
end

% We need synTS temperature and salinity, if not found then try getting
% them.
if isempty(tempv)
    try
        sd = get_synTS(sample_data, transducer_depth(1));
        source = 'interpolated synTS';
    catch e     %#ok<NASGU>
        % Use CARS data if we can't get synTS (CARS has wider coverage)
        sd = get_CARS(sample_data, transducer_depth(1));
        source = 'CARS';
    end
    salv = length(sd.variables);
    tempv = salv - 1;
    if ~strcmpi(sd.variables{tempv}.name, 'temperature')
        error('Inferred temperature not found');
    end
    if ~strcmpi(sd.variables{salv}.name, 'salinity')
        error('Inferred salinity not found');
    end
    temp = sd.variables{tempv}.data;
    sal = sd.variables{salv}.data;
    
else
    % get synTS data
    temp = sample_data.variables{tempv}.data;
    sal = sample_data.variables{salv}.data;
    if isfield(sample_data.variables{tempv}, 'source') && ~isempty(sample_data.variables{tempv}.source)
        source = sample_data.variables{tempv}.source;
    else
        source = 'see history';
    end
    
    % if sample_data already has temperature and salinity then also record
    % sound speed, absorption and absorption (but not depth) corrected Sv.
    if isempty(asvv)
        asvv = length(sample_data.variables) + 1;
        sample_data.variables{asvv}.name = 'abs_corrected_sv';
        sample_data.variables{asvv}.dimensions = sample_data.variables{svv}.dimensions;
        sample_data.variables{asvv}.data = NaN(size(sample_data.variables{svv}.data));
    end
    if isempty(ssv)
        ssv = length(sample_data.variables) + 1;
        sample_data.variables{ssv}.name = 'sound_speed';
        sample_data.variables{ssv}.dimensions = sample_data.variables{tempv}.dimensions;
        sample_data.variables{ssv}.data = NaN(size(sample_data.variables{tempv}.data));
    end
    if isempty(absv)
        absv = length(sample_data.variables) + 1;
        sample_data.variables{absv}.name = 'absorption';
        sample_data.variables{absv}.dimensions = sample_data.variables{svv}.dimensions;
        sample_data.variables{absv}.data = NaN(size(sample_data.variables{svv}.data));
    end
end

% corrections are applied to uncorrected data,
% if uncorrected data variables are not found assume the data is
% uncorrected and save a copy as uncorrected data.
if isempty(usvv)
    usvv = length(sample_data.variables) + 1;
    sample_data.variables{usvv} = sample_data.variables{svv};
    sample_data.variables{usvv}.name = [ 'uncorrected_' sample_data.variables{svv}.name ];
end
if isempty(upcv)
    upcv = length(sample_data.variables) + 1;
    sample_data.variables{upcv} = sample_data.variables{pcv};
    sample_data.variables{upcv}.name = [ 'uncorrected_' sample_data.variables{pcv}.name ];
end

% extend one layer in either direction to allow interpolation near
% boundaries
depth = sample_data.dimensions{depthd}.data;
if size(depth,1) == 1
    depth = depth';
end
xdepth = [0; depth; 2 * depth(end) - depth(end-1); 2*depth(end)];

% calculate soundspeed profiles from synTS
if speed_formula == MACKENZIE
    ss = soundspeed_mackenzie(depth + transducer_depth(1), temp, sal);
elseif speed_formula == GSW
    ss = soundspeed_gsw(depth + transducer_depth(1), temp, sal, latitude, longitude);
else

    ss = soundspeed_coppens(depth + transducer_depth(1), temp, sal, latitude);
end

if ~isempty(ssv)
    sample_data.variables{ssv}.data = ss;
end

xss = [ss(:,1) ss ss(:,end) ss(:,end)];
xss(isnan(xss)) = 1500;             % dummy value where there is no data (CARS below bottom)

% build array of travel time to reach each depth and cumulative absorption to
% each depth for synTS data
tt = zeros(size(xss));

for d = 2 : length(xdepth)
    tt(:,d) = tt(:,d - 1) + ...
        (xdepth(d) - xdepth(d-1)) .* 2 ./ (xss(:,d) + xss(:,d - 1)); 
end


for c = 1:length(freq)
    
% (one way) travel time is depth / sound speed used to calculate depth
xdtime = xdepth / sso(c);
    
if c == 1 || freq(c-1) ~= freq(c)
    if absorption_formula == DOONAN
        sa = soundabsorption_doonan(depth + transducer_depth(1),temp,sal,ss,freq(c));
    else
        sa = soundabsorption_francois(depth + transducer_depth(1),temp,sal,ss,freq(c),pH);
    end
    
    if ~isempty(absv)
        sample_data.variables{absv}.data(:,:,c) = sa;
    end

    dummysa = find(~isnan(sa),1);
    xsa = [sa(:,1) sa sa(:,end) sa(:,end)];
    xsa(isnan(xsa)) = sa(dummysa);          % dummy value for no data areas
    cum_absorption = zeros(size(xsa));
    for d = 2 : length(xdepth)
        cum_absorption(:,d) = cum_absorption(:,d - 1) + ...
            (xdepth(d) - xdepth(d-1)) .* (xsa(:,d) + xsa(:,d - 1)) / 2;
    end
    
    if xsa(1) > 1.1 * sao(c) || xsa(1) * 1.1 < sao(c)
        warning('SOUND:MARGIN', 'Significant difference between calculated sound absorption %g and nominal sound absorption %g for %g kHz', xsa(1), sao(c), freq(c));
    end
end

% Calculate new values:
%
% depth is interpolated from original travel time and 
% synTS travel time -> tsdepth function.
%
% total absorption to each depth (used to correct Sv) is interpolated from
% depth and synTS depth -> absorption function.
%
% final sv is interpolated from corrected sv at the depth layers
%
% keyboard
% for each interval
for t = 1 : size(ss,1)
    time = sample_data.variables{depthv}.data(t,:,c) / sso(c);
    valid = time ~= 0 & ~isnan(time);
    new_depth = interp1(tt(t,:), xdepth, time(valid));
    old_depth = sample_data.variables{depthv}.data(t,valid,c);
    
    if isempty(new_depth)
        new_sv = zeros(size(depth));
        new_pc = zeros(size(depth));
    else
        absorp = interp1(xdepth, cum_absorption(t,:), new_depth);
        ssR = interp1(xdepth, xss(t,:), new_depth);         % sound speed at cell
        ss0 = xss(t,1);                                     % sound speed of first cell, surrogate for sound speed at transducer
        
       
        sv = sample_data.variables{usvv}.data(t,valid,c);
        sv = sv .* (new_depth .* ss0).^2 ./ (old_depth.^2 .* ssR .* sso(c)) ...
            .* 10 .^ (0.2 * (absorp - sao(c) .* old_depth));
        
%         dB = 10 * log10(sample_data.variables{usvv}.data(t,valid));
%         dB = dB ...
%             + 10*log10((new_depth .* ss0).^2 ./ (old_depth.^2 .* ssR .* sso)) ...
%             - 2 * sao(c) .* old_depth + 2 * absorp;
%         sv = 10 .^ (dB / 10);
        
        if length(new_depth) == 1
            xndepth = [0 new_depth 2*new_depth 3*new_depth];
        else
            xndepth = [0 new_depth (2 * new_depth(end) - new_depth(end - 1)) (2 * new_depth(end))];
        end
        xsv = [sv(1) sv sv(end) sv(end)];
        new_sv = interp1(xndepth, xsv, depth);
        
        xlayer_depth = interp1(tt(t,:), xdepth, xdtime);  
        xlayer_depth(end) = 2 * xlayer_depth(end-1);        % Force valid boundary 
        pgood = sample_data.variables{upcv}.data(t,:,c);        
        xpgood = [0 pgood 0 0];
        new_pc = interp1(xlayer_depth, xpgood, depth);
        
        last = find(depth > new_depth(end), 1);
        new_pc(last + 1 : end) = 0;
        new_sv(new_pc == 0) = 0;
    end
    
    if min(new_sv) < 0
        % only possible when spline interpolation used
        fprintf ('Negative Sv %g found in interpolated data', min(new_sv))
        keyboard
    end
    % Below line (at 542) is added to replace '0' with 'nan'.
    % Earlier '0' was representing bad data region also. Which means 'valid min'
    % is 'bad data' in linear domain.
    % Now the 'nan' is correctly replaced with the fill value defined in IMOS toolbox as expected.
    % If fill value is correctly defined while creating NetCDF, this
    % attribute information is be used by 'ncread' command and matlab automatically
    % convert 'fill values' as 'nan' upon import.
    % Haris 21 June 2018
    new_sv(new_sv == 0) = nan; % added on 21 June 2018 
    sample_data.variables{svv}.data(t,:,c) = new_sv;
    sample_data.variables{pcv}.data(t,:,c) = new_pc;
    if ~isempty(asvv)
        svn = NaN(size(valid));
        if ~isempty(new_depth)
            svn(valid) = sv;
        end
        sample_data.variables{asvv}.data(t,:,c) = svn;
    end
end
end

% update history
% % sample_data.data_processing_soundspeed = '';
% % sample_data.data_processing_absorption = '';
% Haris 14/09/2020: we need this information - don't make empty. ICES
% document will be revised.


nowj = (now - datenum([1970 1 1])) * 86400000;              % now in ms since 1970
timezone = java.util.TimeZone.getDefault().getOffset(nowj); % timezone offset in ms  
nowt = now - timezone / 86400000;                           % now UTC in days       
comment = [datestr(nowt, 'yyyy-mm-ddTHH:MM:SSZ') ' '...
    getenv('USER') getenv('UserName') ...
    ' Sound speed '];

if speed_formula == MACKENZIE
    comment = [ comment '(Mackenzie 1981)' ];
    data_processing_soundspeed_description = ...
        ['Sound speed calculated using Mackenzie 1981 from ' ...
        source ' for each cell'];
elseif speed_formula == GSW
    comment = [ comment '(Gibbs SeaWater TEOS-10)' ];
    data_processing_soundspeed_description = ...
        ['Sound speed calculated using the Gibbs SeaWater Toolbox (TEOS-10) from ' ...
        source ' for each cell'];
else
    comment = [ comment '(Coppens 1981)' ];
    data_processing_soundspeed_description = ...
        ['Sound speed calculated using Coppens 1981 from ' ...
        source ' for each cell'];
end

comment = [ comment ' and absorption ' ];

if absorption_formula == DOONAN
    comment = [ comment '(Doonan 2003)' ];
    data_processing_absorption_description = ...
        ['Sound absorption calculated using Doonan 2003 from ' ...
        source ' for each cell'];
else
    comment = [ comment '(Francois and Garrison 1982)' ];
    data_processing_absorption_description = ...
        ['Sound absorption calculated using Francois and Garrison 1982 from ' ...
        source ' for each cell'];
end

comment = [ comment ' corrections applied.'];

if isfield(sample_data, 'history') && ~isempty(sample_data.history);
    comment = [ sample_data.history 10 comment];
end
sample_data.date_modified = nowt;
sample_data.history = comment;

if isfield(sample_data.meta, 'channels')
    for i=1:length(sample_data.meta.channels)
% %         sample_data.meta.channels(i).data_processing_soundspeed = '';
            % Haris 14/09/2020: we need this information - don't make empty. ICES
            % document will be revised.
        sample_data.meta.channels(i).data_processing_soundspeed_description = data_processing_soundspeed_description;
% %         sample_data.meta.channels(i).data_processing_absorption = '';
            % Haris 14/09/2020: we need this information - don't make empty. ICES
            % document will be revised.
        sample_data.meta.channels(i).data_processing_absorption_description = data_processing_absorption_description;
    end
else
% %     sample_data.data_processing_soundspeed = '';
        % Haris 14/09/2020: we need this information - don't make empty. ICES
        % document will be revised.
    sample_data.data_processing_soundspeed_description = data_processing_soundspeed_description;
% %     sample_data.data_processing_absorption = '';
        % Haris 14/09/2020: we need this information - don't make empty. ICES
        % document will be revised.
    sample_data.data_processing_absorption_description = data_processing_absorption_description;
end


