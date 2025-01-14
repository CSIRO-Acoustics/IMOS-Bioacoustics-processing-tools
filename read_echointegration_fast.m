function sample_data = read_echointegration_fast( directory, ev_files, control, progress )  
    %       
    % read_echointegration_fast reads the .csv files exported from echoview
    % and generates an IMOS sample_data structure.
    % read_echointegration_fast csv files are exported from variables that
    % have been resampled to the final IMOS resolution, e.g. 1000 m x 10 m,
    % 100m x 10m. Outputs from resampled variables are a matrix of values
    % (e.g. Sv, num good samples). Much of the work of this function is to
    % package these outputs so that the output sample_data has the same
    % contents that you get when going by the read_integration.m (standard
    % format echointegration by cells to csv format).
    %
    % The function read_echointegration replaces merge3 and echoviewParse
    % in the old system and draws heavily on the code from each.
    %
    % This function read_echointegration_fast is a modified version of
    % read_echointegration. It is designed to read in
    %
    % Inputs:
    %   directory - directory containing the input .csv files, the user will be
    %               asked to provide a value if it not provided or empty.
    %   ev_files  - Not currently used
    %   control   - control structure containing the following fields:
    %               TODO
    %   progress  - function to report progress (optional)
    %
    % Outputs:
    %   sample_data - IMOS data structure containing the data extracted from
    %   the csv files.
    %
    % The .csv file from the resampled variables are different format to
    % the standard export_echointegration_bycells Notablely each row has a
    % set of interval data (date/time,lat/lon,range start/end followed by
    % the set of sample values from shallowesst to deepest. this makes for
    % a much more compact format. In the standard echointegrationbycells
    % output there is a set of interval data for each of the cell values.
    % So for 0-2000m at 10 m resolution there would be 200 rows of data
    % with the interval data repeating each time. The resampled csv files
    % require special treatment to separate out (and then repeat) the
    % interval data for each of teh sample values.
    % Distance_gps
    % Ping_date
    % Ping_time
    % Ping_milliseconds,
    % Latitude
    % Longitude
    % Depth_start
    % Depth_end
    % Range_start
    % Range_end
    % Sample_count
    % Sample_count is then followed by list of data values of length equalt
    % to the Sample_count value
    %
    % A global interval value is also required. this is not provided in the
    % exported resampled csv files. Instead one resampled variable has a
    % grid set to match the resample resolution. E.g. if the resampled
    % variable is 100m by 10 m, a grid of the same dimensions is sest for
    % the resampled variable. Then an echointegrationbycells is done to
    % produce a standard format data where the second column contains the
    % global interval value. this global interval value is then spliced
    % into the processed data.
    
    if nargin < 3 
        progress = [];
    end
        
    %-------------------------------------------------------------------%
    %-------------------------------------------------------------------%
    % search for 'Tim and Haris 13/06/2019' to see changes made to include
    % motion correction factor. This may be useful to add new variables in
    % future
    %-------------------------------------------------------------------%
    %-------------------------------------------------------------------%
    
    % sample_data.dimensions to create
    DIMENSIONS = { 'TIME', 'DEPTH', 'CHANNEL', 'EV_filename', 'echoview_version'};
    TIME_D          = 1; 
    DEPTH_D         = 2;    
    CHANNEL_D       = 3; 
    EV_FILE_D       = 4;   
    EV_VERSION_D    = 5;
    
    % sample_data.variables to create
    VARIABLES = { ...
        'LATITUDE',                 TIME_D ; ...
        'LONGITUDE',                TIME_D; ...
        'frequency',                CHANNEL_D; ...
        'mean_height',              [TIME_D DEPTH_D CHANNEL_D]; ...
        'mean_depth',               [TIME_D DEPTH_D CHANNEL_D]; ...
        'Sv',                       [TIME_D DEPTH_D CHANNEL_D]; ...
        'Sv_unfilt',                [TIME_D DEPTH_D CHANNEL_D]; ...
        'Sv_pcnt_good',             [TIME_D DEPTH_D CHANNEL_D]; ...
        'Sv_sd',                    [TIME_D DEPTH_D CHANNEL_D]; ...
        'Sv_skew',                  [TIME_D DEPTH_D CHANNEL_D]; ...
        'Sv_kurt',                  [TIME_D DEPTH_D CHANNEL_D]; ...
        'Sv_unfilt_sd',             [TIME_D DEPTH_D CHANNEL_D]; ...
        'Sv_unfilt_skew',           [TIME_D DEPTH_D CHANNEL_D]; ...
        'Sv_unfilt_kurt',           [TIME_D DEPTH_D CHANNEL_D]; ...
        'signal_noise',             [TIME_D DEPTH_D CHANNEL_D]; ...
        'background_noise',         [TIME_D CHANNEL_D]; ...
        'motion_correction_factor', [TIME_D DEPTH_D CHANNEL_D]; % Tim and Haris 13/06/2019 to add motion correction factor
        };
    
    LAT_V                       = 1;  
    LON_V                       = 2;  
    FREQ_V                      = 3;             
    HEIGHT_V                    = 4;   
    DEPTH_V                     = 5;
    SV_V                        = 6;               
    SV_UNFILT_V                 = 7;        
    SV_PCNT_GOOD_V              = 8;
    SV_SD_V                     = 9;            
    SV_SKEW_V                   = 10;         
    SV_KURT_V                   = 11;
    SV_UNFILT_SD_V              = 12;    
    SV_UNFILT_SKEW_V            = 13;  
    SV_UNFILT_KURT_V            = 14;
    SIGNAL_NOISE                = 15;      
    BACKGROUND_NOISE            = 16;  
    MOTION_CORRECTION_FACTOR    = 17; % Tim and Haris 13/06/2019 to add motion correction factor

    dims = length(DIMENSIONS);
    if control.extended
        vars = length(VARIABLES);
    else
        vars = SV_PCNT_GOOD_V;
        vars = vars + 3;        % add signal_noise, background and motion. Tim and Haris 13/06/2019 to add motion correction factor
    end

    signal_v = vars - 2; 		
    background_v = vars - 1;
    motion_v = vars; % Tim and Haris 13/06/2019 to add motion correction factor
    
    % columns in COLUMNS matrix
    CLN = 2;
    RAW = 3;
    CNT = 4;
    S2N = 5;
    BGD = 6;    
    MOT = 7; % Tim and Haris 13/06/2019 to add motion correction factor
    SMP = 8; % added to record the raw number of samples for fast processing TER 16/05/2017

    % Ask the user for the directory to use
    if isempty(directory)
        directory = uigetdir('Q:\Processed_data');
    end

    % ensure the IMOS toolbox is in the Path - needed for parseNetCDFTemplate
    % this should not be necessary if called from process_BASOOP
    if isempty(which('imosToolbox'))
        addpath(genpath(fileparts(mfilename('fullpath'))));
    end

    max_depth = repmat(control.max_depth, size(control.channel));

    % create sample_data
    sample_data.site_code = 'SOOP-BA';
    sample_data.meta.level=2;

    sample_data.meta.instrument_make              = 'Simrad';
    sample_data.meta.instrument_model             = 'ES60';
    sample_data.meta.instrument_serial_no         = '';
    sample_data.meta.instrument_sample_interval   = NaN;
    sample_data.meta.timezone                     = 'UTC';
    sample_data.meta.site_name                    = 'UNKNOWN';

    for k=1:dims
        sample_data.dimensions{k}.name = DIMENSIONS{k};
        sample_data.dimensions{k}.data = [];
    end

    for k=1:vars
        sample_data.variables{k}.name = VARIABLES{k,1};
        sample_data.variables{k}.dimensions = VARIABLES{k,2};
        sample_data.variables{k}.data = [];
    end

    sample_data.variables{end-2}.name = VARIABLES{SIGNAL_NOISE,1};
    sample_data.variables{end-2}.dimensions = VARIABLES{SIGNAL_NOISE,2};
    sample_data.variables{end-1}.name = VARIABLES{BACKGROUND_NOISE,1};
    sample_data.variables{end-1}.dimensions = VARIABLES{BACKGROUND_NOISE,2};
    sample_data.variables{end}.name = VARIABLES{MOTION_CORRECTION_FACTOR,1};        % 13/06/2019 Tim and Haris 13/06/2019 to add motion correction factor
    sample_data.variables{end}.dimensions = VARIABLES{MOTION_CORRECTION_FACTOR,2};  % 13/06/2019 Tim and Haris 13/06/2019 to add motion correction factor

    sample_data.dimensions{CHANNEL_D}.data = control.channel;
    sample_data.variables{FREQ_V}.data = control.frequency;
    sample_data.meta.depth = control.frequency;
           
    cleanvar1 = sprintf(control.export_final_variable_name, control.channel{1});
    sections = dir(fullfile(directory, [ '*' cleanvar1 '.csv']));
    cleanvar2 = sprintf(control.export_final_variable_name_fast, control.channel{1});
    sections2 = dir(fullfile(directory, [ '*' cleanvar2 '.csv']));
    
    if isempty(sections) & isempty(sections2)
        errormsg = '*%s.csv not found in %s\n\n This might be because you have checked a frequency channel\n that is not present in the data set - inspect the GUI!\n';
        error(errormsg,cleanvar1, directory);
    end
    
    if ~isempty(sections)   % standard format files are present, work out ev files from there
        cv1_files = {sections.name};
        tail = length(cleanvar1)+5;
        ev_files = cellfun(@(x) x(1:end-tail),cv1_files, 'UniformOutput',false);
    end
    
    if ~isempty(sections2)   % resample format files present, work out evfiles from there.
        cv2_files = {sections2.name};
        tail = length(cleanvar2)+5;
        ev_files = cellfun(@(x) x(1:end-tail),cv2_files, 'UniformOutput',false);
    end

    % read each file in order
    filecnt = 0;        % number of distinct EV files
    lastint = 0;        % last interval processed
    have_intervals = [];

    % preallocate arrays
    evvar       = cell(MOT,1); % Tim and Haris 13/06/2019 to add motion correction factor
    filename    = cell(size(evvar));
    
    for f = 1:length(ev_files)
        [~, prefix] = fileparts(ev_files{f}); 
        
        for channel = 1:length(control.channel) 
            
            evvar{CLN} = sprintf(control.export_final_variable_name_fast, control.channel{channel});
            evvar{RAW} = sprintf(control.export_reference_variable_name_fast, control.channel{channel});
            evvar{CNT} = sprintf(control.export_rejectdata_variable_name_fast, control.channel{channel});
            evvar{S2N} = sprintf(control.export_noise_variable_name_fast, control.channel{channel});
            evvar{BGD} = sprintf(control.export_background_variable_name_fast, control.channel{channel});
            evvar{MOT} = sprintf(control.export_motion_correction_factor_variable_name_fast, control.channel{channel}); % Tim and Haris 31/07/2019 to add motion correction factor
            evvar{SMP} = sprintf(control.export_rawnumsamples_variable_name_fast, control.channel{channel});

            for v = CLN:SMP
                filename{v} = fullfile(directory, [ prefix '_' evvar{v} '.csv' ]);
            end
            
            % making aligned with other progress messages in process_basoop
            fprintf('                     read quality assured echo integration CSV file: %s (%d/%d)\n',[prefix '_' evvar{CLN}],f, length(ev_files)); 
            
            % Function to convert resampled outputs to standard csv format
            [cdata, rdata, tdata, bdata, sdata,mdata] = convert_resample_to_stdcsv(filename);
            
            fid = fopen([directory '\Echoview_version.txt'],'r'); % Echoview_version will have been exported during the echointegration export stage.
            ev_ver = fgetl(fid);
            fclose(fid);
            
            % find the ev file name. First get the prefix of the csv files.
            k = filename{2};
            bkslsh = strfind(k,'\');
            prefix = k(bkslsh(end)+1:end);
            uscore = strfind(prefix,'_');
            prefix = prefix(1:uscore(1)-1);
            fid = fopen(fullfile(directory, [prefix '.txt']),'r'); % open the txt file which contains the full path to the associated ev file
            ev_filename = fgetl(fid);
            fclose(fid);
            
            % set values for columns selection variables. these are based
            % on the values in each column of cdata, rdata etc
            intrval     = 1;
            layer       = 2;
            sv_mean     = 3; 
            rsv_mean    = 3; 
            ssv_mean    = 3; 
            bsv_mean    = 3; 
            mot_mean    = 3; % Tim and Haris 13/06/2019 to add motion correction factor 
            tsamples    = 3;
            mean_height = 4; 
            rsamples    = 4;
            mean_depth  = 5;
            rsv_sd      = 5;
            layer_min   = 6;
            rsv_skew    = 6;
            layer_max   = 7;
            rsv_kurt    = 7;
            date        = 8;
            time        = 9;
            latitude    = 10;
            longitude   = 11;
            sv_sd       = 12; 
            sv_skew     = 13; 
            sv_kurt     = 14;
           
            if ~any(strcmp(ev_filename, sample_data.dimensions{EV_FILE_D}.data))
                sample_data.dimensions{EV_FILE_D}.data{end+1} = ev_filename;
            end
                        
            if ~any(strcmp(ev_ver, sample_data.dimensions{EV_VERSION_D}.data))
                sample_data.dimensions{EV_VERSION_D}.data{end+1} = ev_ver;
            end            

            % note: intervals may start at 0 so we add 1 to all interval
            % numbers as matlab indexes from 1.                 
            
            [ccells,cidx] = sortrows([cdata{intrval}+1 cdata{layer}]);
            [rcells,ridx] = sortrows([rdata{intrval}+1 rdata{layer}]);
            [tcells,tidx] = sortrows([tdata{intrval}+1 tdata{layer}]);
            [scells,sidx] = sortrows([sdata{intrval}+1 sdata{layer}]);
            [bcells,bidx] = sortrows([bdata{intrval}+1 bdata{layer}]);
            [mcells,midx] = sortrows([mdata{intrval}+1 mdata{layer}]); 
            % Tim and Haris 13/06/2019 to add motion correction factor
        
            mnint=ccells(1, 1);
            mxint=ccells(end, 1);
             
            if mnint <= 0
                error('Interval index < 0. This may mean the gps.csv starts after the data');
            end
            
            clayers = max(ccells(:,2));
            
            layers = max(clayers, length(sample_data.dimensions{DEPTH_D}.data));
            if isempty(sample_data.dimensions{DEPTH_D}.data)
                layer_depth = nan(layers,1);
            else
                layer_depth = [sample_data.dimensions{DEPTH_D}.data
                    nan(layers-length(sample_data.dimensions{DEPTH_D}.data),1)];
            end

            update = false;
            if isempty(layer_min) || isempty(layer_max)
                nlayer = find(isnan(layer_depth));
                layer_depth(nlayer) = nlayer * 10 - 5;
                update = ~isempty(nlayer);
            else
                for i = 1:clayers
                    if isnan(layer_depth(i))
                        cline = cidx(find(ccells(:,2) == i,1,'first'));
                        if ~isempty(cline)
                            layer_depth(i) = (str2double(cdata{layer_min}{cline}) + ...
                                str2double(cdata{layer_max}{cline})) / 2;
                            update = true;
                        else
                            keyboard
                        end
                    end
                end
            end

            if channel == 1
                % preallocate sufficient space for data from this file
                intx = zeros(mxint,1);
                intx(mnint:mxint) = 1:mxint-mnint +1;
                
                if lastint > mxint
                    keyboard
                    error('Interval sequence out of order (check .gps.csv in .ev file): previous %d current %d - %d in %s', ...
                        lastint, mnint, mxint, filename{CLN});
                end
                
                if mnint > lastint && lastint > 0
                    warning('ITEGRATION:GAP', 'Gap in integration intervals between %d and %d at %s', ...
                        lastint, mnint, filename{CLN})
                end
                
                if lastint > mnint
                    pen=lastint;      % keep penultimate record (but replace last one)
                    drop=intx(pen);
                    intx(1:pen) = 0;
                    intx(intx > 0) = intx(intx>0) - drop;   % start newdata from 1
                    if control.verbosity > 1
                        fprintf('                     skipping intervals %d - %d, processing intervals %d - %d\n', ...
                            mnint, pen - 1,lastint,mxint);
                    end
                end

                layers = find(layer_depth < max_depth(channel),1,'last');
                
                newsize=[ max(intx) layers length(control.channel) filecnt ];
                sample_data.dimensions{TIME_D}.newdata = nan(max(intx),1);
                for k=1:vars
                    sample_data.variables{k}.newdata = ...
                        nan([newsize(sample_data.variables{k}.dimensions) 1]);
                end
                new_intervals = nan(1,newsize(TIME_D));
            else
                grow = mxint - length(intx);
                if grow > 0
                    % channel has more intervals than previous channels
                    if control.verbosity > 1
                        fprintf('Channel %d has %d extra intervals\n', channel, grow);
                    end
                    intx(end+1:mxint) = intx(end)+1:intx(end)+grow;
                    growsize = newsize;
                    growsize(TIME_D) = grow;
                    newsize(TIME_D) = newsize(TIME_D) + grow;
                    sample_data.dimensions{TIME_D}.newdata(end+1:end+grow) = NaN;
                    for k=1:vars
                        gdim = find(sample_data.variables{k}.dimensions == TIME_D,1);
                        if ~isempty(gdim)
                            growdata = nan([growsize(sample_data.variables{k}.dimensions) 1]);
                            sample_data.variables{k}.newdata = cat(gdim, ...
                                sample_data.variables{k}.newdata, growdata);
                        end
                    end
                    new_intervals = [new_intervals nan(1,grow)];      %#ok<AGROW>
                end
                grow = find(layer_depth < max_depth(channel),1,'last') - newsize(DEPTH_D);
                if grow > 0
                    % channel has more layers than previous channels
                    if control.verbosity > 1
                        fprintf('Channel %d has %d extra layers\n', channel, grow);
                    end
                    update = true;
                    growsize = newsize;
                    growsize(DEPTH_D) = grow;
                    newsize(DEPTH_D) = newsize(DEPTH_D) + grow;
                    for k=1:vars
                        gdim = find(sample_data.variables{k}.dimensions == DEPTH_D,1);
                        if ~isempty(gdim)
                            growdata = nan([growsize(sample_data.variables{k}.dimensions) 1]);
                            sample_data.variables{k}.newdata = cat(gdim, ...
                                sample_data.variables{k}.newdata, growdata);
                            if ~isempty(sample_data.variables{k}.data)
                                oldsize = size(sample_data.variables{k}.data);
                                oldsize(gdim) = grow;
                                sample_data.variables{k}.data = ...
                                    cat(gdim, sample_data.variables{k}.data, nan(oldsize));
                            end
                        end
                    end
                end
                layers = newsize(DEPTH_D);
            end
            if update
                sample_data.dimensions{DEPTH_D}.data = layer_depth(1:layers);
            end

            c_sv_mean = cdata{sv_mean};
            c_mean_height = cdata{mean_height};
            c_mean_depth = cdata{mean_depth};
            c_sv_sd = cdata{sv_sd};
            c_sv_skew = cdata{sv_skew};
            c_sv_kurt = cdata{sv_kurt};

            r_sv_mean = rdata{rsv_mean};
            r_sv_sd = rdata{rsv_sd};
            r_sv_skew = rdata{rsv_skew};
            r_sv_kurt = rdata{rsv_kurt};
            r_samples = rdata{rsamples};

            t_samples = tdata{tsamples};

            if isempty(ssv_mean)
                s_mean = nan;
            else
                s_mean = sdata{ssv_mean};
            end
                        
            if isempty(bsv_mean)
                b_mean = nan;
            else
                b_mean = bdata{bsv_mean};
            end

            if isempty(mot_mean) % Tim and Haris 13/06/2019 to add motion correction factor
                m_mean = nan;
            else
                m_mean = mdata{mot_mean};
            end
            
            ci = 1;
            ri = 1;
            ti = 1;
            si = 1;
            bi = 2; % bn value for first value is 
            mi = 1; % Tim and Haris 13/06/2019 to add motion correction factor

            cn = size(ccells,1);
            rn = size(rcells,1);
            tn = size(tcells,1);
            sn = size(scells,1);
            bn = size(bcells,1);
            mn = size(mcells,1); % Tim and Haris 13/06/2019 to add motion correction factor
            
            while ci <= cn
                % process data
                % skip intervals without data and intervals without position
                while ci <= cn && (intx(ccells(ci,1)) == 0 || str2double(cdata{latitude}{cidx(ci)}) > 99)
                    ci = ci+1;
                end
                
                if ci > cn
                    break
                end
                
                cinterval = ccells(ci,1);
                ninterval = intx(cinterval);
                if ninterval == 0
                    keyboard
                end
                new_intervals(ninterval) = cinterval;
                cline = cidx(ci);
                
                sample_data.variables{LAT_V}.newdata(ninterval) = ...
                    str2double(cdata{latitude}{cline});
                sample_data.variables{LON_V}.newdata(ninterval) = ...
                    str2double(cdata{longitude}{cline});
                
                if isnan(sample_data.dimensions{TIME_D}.newdata(ninterval))
                    sample_data.dimensions{TIME_D}.newdata(ninterval) = ...
                        datenum([cdata{date}{cline} ' ' cdata{time}{cline}], 'yyyymmdd HH:MM:SS.FFF');
                    
                    if channel == 1
                        lastint = cinterval;
                    elseif cinterval > lastint
                        warning('READ:CHANNEL', 'Channel %d has more intervals than channel 1', channel)
                    end
                end

                while ri <= rn && rcells(ri,1) < cinterval
                    ri = ri + 1;
                end
                if ri > rn || rcells(ri,1) ~= cinterval
                    warning('READ:MISSING_RAW','Raw data is missing interval %d', cinterval)
                end
                while ti <= tn && tcells(ti,1) < cinterval
                    ti = ti + 1;
                end
                if ti > tn || tcells(ti,1) ~= cinterval
                    warning('READ:MISSING_CNT','HAC data is missing interval %d', cinterval)
                end
                while si <= sn && scells(si,1) < cinterval
                    si = si + 1;
                end
                while bi <= bn && bcells(bi,1) < cinterval 
                    bi = bi + 2;
                end

                while mi <= mn && mcells(mi,1) < cinterval % Tim and Haris 13/06/2019 to add motion correction factor
                    mi = mi + 1;
                end                
                if bi <= bn && bcells(bi,1) == cinterval
                    sample_data.variables{background_v}.newdata(ninterval, channel) = ...
                        str2double(b_mean{bidx(bi)});
                end                      
                while ci <= cn
                    
                    while ci <= cn && ccells(ci,2) > layers
                        ci = ci + 1;
                    end
                    if ci > cn || ccells(ci,1) ~= cinterval
                        break
                    end
                    
                    clayer = ccells(ci,2);
                    cline = cidx(ci);
                    
                    while ri <= rn && rcells(ri,1) == cinterval && rcells(ri,2) < clayer
                        ri = ri + 1;
                    end
                    while ti <= tn && tcells(ti,1) == cinterval && tcells(ti,2) < clayer
                        ti = ti + 1;
                    end
                    while si <= sn && scells(si,1) == cinterval && scells(si,2) < clayer
                        si = si + 1;
                    end
                    while mi <= mn && mcells(mi,1) == cinterval && mcells(mi,2) < clayer % Tim and Haris 13/06/2019 to add motion correction factor
                        mi = mi + 1;
                    end

                    if ri > rn || (rcells(ri,1) == cinterval && rcells(ri,2) ~= clayer)
                        warning('READ:MISSING_RAW','Raw data is missing layer %d in interval %d', clayer, cinterval)
                        rawdata = 0;
                        rsv = 0;
                    else
                        rline = ridx(ri);                        
                        rawdata = r_samples(rline);                        
                        rsv =r_sv_mean(rline);
                    end
                    if ti > tn || (tcells(ti,1) == cinterval && tcells(ti,2) ~= clayer)
                        warning('READ:MISSING_CNT','HAC data is missing layer %d in interval %d', clayer, cinterval)
                        cleandata = 0;
                    else
                        tline = tidx(ti);
                        cleandata = t_samples(tline);
                    end

                    % percent good
                    if cleandata > 0
                        pctgood = floor(100 * cleandata / rawdata);
                    else
                        pctgood = 0;
                    end

                    % skip data which doesn't satisfy threshold conditions
                    % added step to disregard data with clayer = 0
                    if isequal(clayer,0)
                        ci = ci +1;
                    else                     
                        if (layer_depth(clayer) > max_depth(channel)) || (pctgood < control.min_good)
                            ci = ci + 1;
                            continue;
                        end
                    end

                    % convert to linear
                    csv = c_sv_mean(cline);
                    if csv == 0
                        csv = 9999;
                    end
                    if csv > 999
                        csv = nan;
                    else
                        csv = 10 ^ (csv / 10);
                    end

                    if rsv == 0
                        rsv = 9999;
                    end
                    if rsv > 999
                        rsv = nan;
                    else
                        rsv = 10 ^ (rsv / 10);
                    end
                    sample_data.variables{HEIGHT_V}.newdata(ninterval, clayer,channel) = ...
                        c_mean_height(cline);
                    sample_data.variables{DEPTH_V}.newdata(ninterval, clayer,channel) = ...
                        c_mean_depth(cline);
                    sample_data.variables{SV_V}.newdata(ninterval, clayer,channel) = csv;
                    sample_data.variables{SV_UNFILT_V}.newdata(ninterval, clayer,channel) = rsv;
                    sample_data.variables{SV_PCNT_GOOD_V}.newdata(ninterval, clayer,channel) = pctgood;

                    if control.extended
                        sample_data.variables{SV_SD_V}.newdata(ninterval, clayer,channel) = ...
                            c_sv_sd(cline);
                        sample_data.variables{SV_SKEW_V}.newdata(ninterval, clayer,channel) = ...
                            c_sv_skew(cline);
                        sample_data.variables{SV_KURT_V}.newdata(ninterval, clayer,channel) = ...
                            c_sv_kurt(cline);
                        sample_data.variables{SV_UNFILT_SD_V}.newdata(ninterval, clayer,channel) = ...
                            r_sv_sd(rline);
                        sample_data.variables{SV_UNFILT_SKEW_V}.newdata(ninterval, clayer,channel) = ...
                            r_sv_skew(rline);
                        sample_data.variables{SV_UNFILT_KURT_V}.newdata(ninterval, clayer,channel) = ...
                            r_sv_kurt(rline);
                    end

                    if si > sn || (scells(si,1) == cinterval && scells(si,2) ~= clayer)
                    else
                        sline = sidx(si);
                        smean = s_mean(sline);
                        if smean == 9999
                            % newdata is already nan
                        else
                            sample_data.variables{signal_v}.newdata(ninterval, clayer,channel) = smean;
                        end
                    end
                    
                    if mi > mn || (mcells(mi,1) == cinterval && mcells(mi,2) ~= clayer) % Tim and Haris 13/06/2019 to add motion correction factor
                    else
                        mline = midx(mi);
                        mmean = m_mean(mline);
                        % Haris 3/01/2020- If motion is not applied this
                        % will be zero. Replace this with NaN so that
                        % 'zero' is not written in the NetCDF. 'Zero' means
                        % transducer orientation has not changed which has
                        % different meaning. This NaN values are now filled
                        % with 'fill values' in the NetCDF.
                        mmean(mmean==0) = NaN; 
                        
                        if mmean == 9999
                            % newdata is already nan
                        else
                            mmean = 100*(10.^(mmean./10))-100 ;
                            sample_data.variables{motion_v}.newdata(ninterval, clayer,channel) = mmean;
                        end
                    end
                    ci = ci + 1;
                end
            end
        end        
        data = ~isnan(sample_data.variables{LAT_V}.newdata);

        new_intervals = new_intervals(data);
        if isempty(new_intervals)
            warning('READ:GPS', 'No GPS data for %s, \nplease check gps.csv and worksheet position filter (max speed)', ...
                filename{CLN})
            overlap = [];
        else
            overlap = find(have_intervals >= new_intervals(1),1);
        end

        if isempty(overlap)
            overlap = length(have_intervals);
        else
            overlap = overlap -1;
        end

        have_intervals = [have_intervals(1:overlap) new_intervals];
        sample_data.dimensions{TIME_D}.data = ...
            vertcat(sample_data.dimensions{TIME_D}.data(1:overlap), sample_data.dimensions{TIME_D}.newdata(data));

        for k=1:vars
            if sample_data.variables{k}.dimensions(1) == TIME_D
                sample_data.variables{k}.data = ...
                    vertcat(sample_data.variables{k}.data(1:overlap,:,:),  sample_data.variables{k}.newdata(data,:,:));
            end
        end
    end

    % clean up
    % drop depths for which there is no layer information
    ddata = ~isnan(sample_data.dimensions{DEPTH_D}.data);
    if ~isempty(find(~ddata,1))
        sample_data.dimensions{DEPTH_D}.data = sample_data.dimensions{DEPTH_D}.data(ddata);
        for k=1:vars
            depth_d = find(sample_data.variables{k}.dimensions == DEPTH_D);
            if ~isempty(depth_d)
                if depth_d == 2
                    sample_data.variables{k}.data = sample_data.variables{k}.data(:,ddata,:);
                else
                    error('Unexpected Depth Dimension - code needs fixing to handle this case');
                end
            end
        end
    end
    
    % Drop echoview version dimension if only one version was used
    if length(sample_data.dimensions{EV_VERSION_D}.data) == 1
        sample_data.(sample_data.dimensions{EV_VERSION_D}.name) = sample_data.dimensions{EV_VERSION_D}.data{1};
        sample_data = rmDimension(sample_data, EV_VERSION_D);
    end

    % Set quality control flags
    % 1 = No_QC_performed
    % 2 = Good_data
    % 4 = Bad_data_that_are_potentially_correctable

    sample_data.dimensions{DEPTH_D}.flags = ones(size(sample_data.dimensions{DEPTH_D}.data));
    sample_data.dimensions{TIME_D}.flags = ones(size(sample_data.dimensions{TIME_D}.data));
    sample_data.variables{LAT_V}.flags = ones(size(sample_data.dimensions{TIME_D}.data));
    sample_data.variables{LON_V}.flags = ones(size(sample_data.dimensions{TIME_D}.data));

    sample_data.variables{SV_V}.flags = ones(size(sample_data.variables{SV_V}.data));
    good = (sample_data.variables{SV_V}.data < 1) & ...
        (sample_data.variables{SV_PCNT_GOOD_V}.data > control.accept_good);
    sample_data.variables{SV_V}.flags(good) = 2;
    sample_data.variables{SV_V}.flags(good) = 2;


    % determine data bounds    
    sample_data = getBounds(sample_data);

    % drop 'newdata' field
    for k=1:length(sample_data.dimensions)
        if isfield(sample_data.dimensions{k}, 'newdata')
            sample_data.dimensions{k} = rmfield(sample_data.dimensions{k}, 'newdata');
        end
    end
    
    for k=1:vars
        if isfield(sample_data.variables{k}, 'newdata')
            sample_data.variables{k} = rmfield(sample_data.variables{k}, 'newdata');
        end
    end

    % convert to single channel format if possible and requested.
    if length(control.channel) == 1 && control.single_format
        sample_data.channel = control.channel{1};
        sample_data.frequency = control.frequency;

        sample_data = rmDimension(sample_data, CHANNEL_D);
    end

end

function sample_data = getBounds(sample_data)
    %GETBOUNDS reads data limits from the data and assigns the corresponding
    % global attributes.

    % set the time range
    mintime = NaN;
    maxtime = NaN;
    time = getVar(sample_data.dimensions, 'TIME');
    if time ~= 0
        mintime = min(sample_data.dimensions{time}.data);
        maxtime = max(sample_data.dimensions{time}.data);
    else
        time = getVar(sample_data.variables, 'TIME');
        if time ~= 0
            mintime = min(sample_data.variables{time}.data);
            maxtime = max(sample_data.variables{time}.data);
        end
    end

    if isempty(mintime)
        error('PARSE:no_data', 'No usable GPS data found in CSV file');
    end
    
    if ~isfield(sample_data, 'time_coverage_start') && ~isnan(mintime)
        sample_data.time_coverage_start = mintime;
    end
    if ~isfield(sample_data, 'time_coverage_end') && ~isnan(maxtime)
        sample_data.time_coverage_end = maxtime;
    end
    
    % set the geographic range
    goodlon = [];
    lon = getVar(sample_data.dimensions, 'LONGITUDE');
    if lon ~= 0
        goodlon = sample_data.dimensions{lon}.data;
    else
        lon = getVar(sample_data.variables, 'LONGITUDE');
        if lon ~= 0
            goodlon = sample_data.variables{lon}.data;
        end
    end
    % force goodlon between -180 and 180
    goodlon = goodlon(goodlon >= -360 & goodlon <= 360);
    goodlon(goodlon < -180) = goodlon(goodlon < -180) + 360;
    goodlon(goodlon > 180) = goodlon(goodlon > 180) - 360;
    
    if ~ isempty(goodlon)
        minlon = min(goodlon);
        maxlon = max(goodlon);
        % if we have data both sides (< 10 degrees) of the date line
        % assume we cross the date line and not 0.
        if (maxlon - minlon > 350)
            minlon = min(goodlon(goodlon > 0));
            maxlon = max(goodlon(goodlon < 0));
        end
        sample_data.geospatial_lon_min = minlon;
        sample_data.geospatial_lon_max = maxlon;
        sample_data.eastlimit = maxlon;
        sample_data.westlimit = minlon;
    end

    goodlat = [];
    lat = getVar(sample_data.dimensions, 'LATITUDE');
    if lat ~= 0
        goodlat = sample_data.dimensions{lat}.data;
    else
        lat = getVar(sample_data.variables, 'LATITUDE');
        if lat ~= 0
            goodlat = sample_data.variables{lat}.data;
        end
    end
    goodlat = goodlat(goodlat >= -90 & goodlat <= 90);
    
    if ~ isempty(goodlat)
        minlat = min(goodlat);
        maxlat = max(goodlat);
        sample_data.geospatial_lat_min = minlat;
        sample_data.geospatial_lat_max = maxlat;
        sample_data.northlimit = maxlat;
        sample_data.southlimit = minlat;
    end
    
    
    % set the depth range
    mindepth = NaN;
    maxdepth = NaN;
    depth = getVar(sample_data.dimensions, 'DEPTH');
    if depth ~= 0
        mindepth = min(sample_data.dimensions{depth}.data);
        maxdepth = max(sample_data.dimensions{depth}.data);
    else
        depth = getVar(sample_data.variables, 'DEPTH');
        if depth ~= 0
            mindepth = min(sample_data.variables{depth}.data);
            maxdepth = max(sample_data.variables{depth}.data);
        end
    end
    
    if ~ isfield(sample_data, 'geospatial_vertical_min') && ~ isnan(mindepth)
        sample_data.geospatial_vertical_min = mindepth;
        sample_data.downlimit = mindepth;
    end
    if ~ isfield(sample_data, 'geospatial_vertical_max') && ~ isnan(maxdepth)
        sample_data.geospatial_vertical_max = maxdepth;
        sample_data.uplimit = maxdepth;
    end

end

function sample_data = rmDimension(sample_data, dim)
    % rmDimension remove dimension.
    %
    % Removes the specified dimension from the sample_data including adjusting
    % the variable dimension indices.
    % Variables without dimension are converted to global attributes.

    sample_data.dimensions(dim) = [];
    
    for k = length(sample_data.variables):-1:1
        sample_data.variables{k}.dimensions = ...
            sample_data.variables{k}.dimensions(sample_data.variables{k}.dimensions ~= dim);
        
        adjust = sample_data.variables{k}.dimensions >= dim;
        sample_data.variables{k}.dimensions(adjust) = sample_data.variables{k}.dimensions(adjust) - 1;
        
        if isempty(sample_data.variables{k}.dimensions)
            if iscell(sample_data.variables{k}.data)
                sample_data.(sample_data.variables{k}.name) = sample_data.variables{k}.data{1};
            else
                sample_data.(sample_data.variables{k}.name) = sample_data.variables{k}.data;
            end
            sample_data.variables(k) = [];
        end
    end
end

