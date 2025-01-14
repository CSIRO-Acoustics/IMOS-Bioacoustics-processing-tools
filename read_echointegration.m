function sample_data = read_echointegration( directory, ev_files, control, progress )
    % read_echointegration reads the .csv files exported from echoview and
    % generates an IMOS sample_data structure.
    %
    % This function replaces merge3 and echoviewParse in the old system and
    % draws heavily on the code from each.
    %
    % Inputs:
    %   directory - directory containing the input .csv files, the user will be
    %               asked to provide a value if it not provided or empty.
    %   ev_files -  Not currently used
    %   control -   control structure containing the following fields:
    %           TODO
    %   progress -  function to report progress (optional)
    %
    % Outputs:
    %   sample_data - IMOS data structure containing the data extracted from
    %   the csv files.
    %
    % The .csv file must have at least all of the following columns:
    % Samples
    % Layer 
    % Lat_M 
    % Layer_depth_min 
    % Layer_depth_max 
    % Lat_M 
    % Lon_M 
    % Date_M 
    % Time_M 
    % Height_mean 
    % Depth_mean 
    % EV_filename 
    % Program_version 
    % Sv_mean 
    
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
        'background_noise',         [TIME_D CHANNEL_D];         ...
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
%        vars = vars + 2;        % add signal_noise and background        
        vars = vars + 3;        % add signal_noise, background and motion. Tim and Haris 13/06/2019 to add motion correction factor
    end

    signal_v = vars - 2; 		
    background_v = vars - 1;
    motion_v = vars; % Tim and Haris 13/06/2019 to add motion correction factor
    
    % Columns of interest in integration file with format.
    % A format of '*s' or '*q' means we ignore this field in this file, we
    % ignore as many fields as possible as parsing to numbers is time
    % consuming.

COLUMNS= {
        'Interval'              'd'     'd'     'd'     'd'     'd'   'd'; 
        'Layer'                 'd'     'd'     'd'     'd'     'd'   'd'; 
        'Layer_depth_min'       's'     '*s'    '*s'    '*s'    '*s'  '*s';
        'Layer_depth_max'       's'     '*s'    '*s'    '*s'    '*s'  '*s';
        'Samples'               '*s'    'd'     'd'     '*s'    '*s'  '*s';
        'Good_samples'          '*s'    'd'     'd'     '*s'    '*s'  '*s';
        'Lat_M'                 's'     '*s'    '*s'    '*s'    '*s'  '*s';
        'Lon_M'                 's'     '*s'    '*s'    '*s'    '*s'  '*s';
        'Date_M'                's'     '*s'    '*s'    '*s'    '*s'  '*s';
        'Time_M'                's'     '*s'    '*s'    '*s'    '*s'  '*s';
        'Height_mean'           'f'     '*s'    '*s'    '*s'    '*s'  '*s';
        'Depth_mean'            'f'     '*s'    '*s'    '*s'    '*s'  '*s';
        'EV_filename'           '*q'    '*q'    '*q'    '*s'    '*s'  '*s';
        'Program_version'       '*q'    '*q'    '*q'    '*s'    '*s'  '*s';
        'Sv_mean'               'f'     'f'     '*s'    'f'     's'   'f';
        'Standard_deviation'    'f'     'f'     '*s'    '*s'    '*s'  '*s';
        'Skewness'              'f'     'f'     '*s'    '*s'    '*s'  '*s';
        'Kurtosis'              'f'     'f'     '*s'    '*s'    '*s'  '*s';
        };
       
% This COLUMN definition is prior to addition of motion MOT data    
% Tim and Haris 13/06/2019 to add motion correction factor

% % % %     COLUMNS= {
% % % %         'Interval'              'd'     'd'     'd'     'd'     'd';
% % % %         'Layer'                 'd'     'd'     'd'     'd'     'd';
% % % %         'Layer_depth_min'       's'     '*s'    '*s'    '*s'    '*s';
% % % %         'Layer_depth_max'       's'     '*s'    '*s'    '*s'    '*s';
% % % %         'Samples'               '*s'    'd'     'd'     '*s'    '*s';
% % % %         'Good_samples'          '*s'    'd'     'd'     '*s'    '*s';
% % % %         'Lat_M'                 's'     '*s'    '*s'    '*s'    '*s';
% % % %         'Lon_M'                 's'     '*s'    '*s'    '*s'    '*s';
% % % %         'Date_M'                's'     '*s'    '*s'    '*s'    '*s';
% % % %         'Time_M'                's'     '*s'    '*s'    '*s'    '*s';
% % % %         'Height_mean'           'f'     '*s'    '*s'    '*s'    '*s';
% % % %         'Depth_mean'            'f'     '*s'    '*s'    '*s'    '*s';
% % % %         'EV_filename'           '*q'    '*q'    '*q'    '*s'    '*s';
% % % %         'Program_version'       '*q'    '*q'    '*q'    '*s'    '*s';
% % % %         'Sv_mean'               'f'     'f'     '*s'    'f'     's';
% % % %         'Standard_deviation'    'f'     'f'     '*s'    '*s'    '*s';
% % % %         'Skewness'              'f'     'f'     '*s'    '*s'    '*s';
% % % %         'Kurtosis'              'f'     'f'     '*s'    '*s'    '*s';
% % % %         };

    % columns in COLUMNS matrix
    CLN = 2;
    RAW = 3;
    CNT = 4;
    S2N = 5;
    BGD = 6;    
    MOT = 7; % Tim and Haris 13/06/2019 to add motion correction factor
    
    % rows in COLUMNS matrix
    INTRVAL      = 1;
    LAYER        = 2;
    LAYER_MIN    = 3;
    LAYER_MAX    = 4;
    SAMPLES      = 5;
    GOOD_SAMPLES = 6;
    LATITUDE     = 7;
    LONGITUDE    = 8;
    DATE         = 9;
    TIME         = 10;
    MEAN_HEIGHT  = 11;
    MEAN_DEPTH   = 12;
    EV_FILE      = 13;
    EV_VERSION   = 14;
    SV_MEAN      = 15;
    SV_SD        = 16;
    SV_SKEW      = 17;
    SV_KURT      = 18;

    % Ask the user for the directory to use
    if isempty(directory)
        directory = uigetdir('Q:\Processed_data');
    end

    % ensure the IMOS toolbox is in the Path - needed for parseNetCDFTemplate
    % this should not be necessary if called from process_BASOOP
    if isempty(which('imosToolbox'))
        addpath(genpath(fileparts(mfilename('fullpath'))));
    end

    start = tic;

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
    sample_data.variables{end}.name = VARIABLES{MOTION_CORRECTION_FACTOR,1}; % 13/06/2019 Tim and Haris 13/06/2019 to add motion correction factor
    sample_data.variables{end}.dimensions = VARIABLES{MOTION_CORRECTION_FACTOR,2};

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
    %evvar       = cell(BGD,1);
    evvar       = cell(MOT,1); % Tim and Haris 13/06/2019 to add motion correction factor
    filename    = cell(size(evvar));
    fid         = ones(size(evvar)) * -1;
    header      = cell(size(evvar));
    lastheader  = cell(size(evvar));
    format      = cell(size(evvar));
    
    for f = 1:length(ev_files)
        [~, prefix] = fileparts(ev_files{f});        
        for channel = 1:length(control.channel)
                                    
            if ~control.export_sv_fast % standard processing
                evvar{CLN} = sprintf(control.export_final_variable_name, control.channel{channel});
                evvar{RAW} = sprintf(control.export_reference_variable_name, control.channel{channel});
                evvar{CNT} = sprintf(control.export_rejectdata_variable_name, control.channel{channel});
                evvar{S2N} = sprintf(control.export_noise_variable_name, control.channel{channel});
                evvar{BGD} = sprintf(control.export_background_variable_name, control.channel{channel});
                evvar{MOT} = sprintf(control.export_motion_correction_factor_variable_name, control.channel{channel}); % Tim and Haris 13/06/2019 to add motion correction factor
            end
            
            if ~control.export_sv_fast % standard processing
                %for v = CLN:BGD
                for v = CLN:MOT % Tim and Haris 13/06/2019 to add motion correction factor
                    filename{v} = fullfile(directory, [ prefix '_' evvar{v} '.csv' ]);
                end
            end
            
            % -------------------- standard processing routine   ------------------            
            if ~control.export_sv_fast % standard processing
                if ~isempty(progress)
                    progress(control, 'read echointegration' , f, length(ev_files), ...
                        start, [prefix '_' evvar{CLN}]); %#ok<NOEFF>
                end

                if exist(filename{RAW},'file') ~= 2          
                    %keyboard
                    keyboard
                    warning('READ:FALLBACK', 'CSV file not found: %s\n trying old filename', filename{RAW});
                    filename{RAW} = fullfile(directory, [prefix 'HAC Sv 38 kHz.csv']); % support for deprecated names
                end

                %for v = CLN:BGD
                for v = CLN:MOT % Tim and Haris 13/06/2019 to add motion correction factor
                    
                    fid(v) = fopen(filename{v}, 'rt');
                    if fid(v) < 0
                        if  v < S2N
                            if exist(filename{v}, 'file')
                                error('Unable to open file %s', filename{v});
                            else
                                error('CSV file does not exist: %s', filename{v});                             
                            end
                        end
                        header{v} = '';
                    else
                        header{v} = fgetl(fid(v));
                        if isequal(header{v}, -1)
                            error('CSV file empty: %s', filename{v});
                        end
                        header{v} = trim(header{v});
                        if isempty(header{v})
                            error('CSV file header missing: %s', filename{v});
                        end
                       
                        if ~strcmp(header{CLN}, header{v})
                            warning('READ:HEADER', 'Header line mismatch for %s', filename{v});
                        end
                    end
                    if ~strcmp(header{v}, lastheader{v})
                        if ~isempty(lastheader{v})
                            warning('READ:HEADER_CHANGE', 'Header line change in %s', filename{v});
                        end
                        lastheader{v} = header{v};

                        % get columns from header

                        fields = strtrim(regexp(header{v}, ',', 'split'));
                        if v == CLN
                            col_ev_file = find(strcmp(COLUMNS{EV_FILE,1},fields),1);
                            col_ev_version = find(strcmp(COLUMNS{EV_VERSION,1},fields),1);
                        end
                        columns = nan(size(COLUMNS,1),1);
                        try
                        for i = 1:size(columns,1)
                            if ~isempty(COLUMNS{i,v}) && COLUMNS{i,v}(1) ~= '*'
                                colmn = find(strcmp(COLUMNS{i,1},fields),1);
                                if ~isempty(colmn)
                                    columns(i) = colmn;
                                end
                            end
                        end
                        catch
                            keyboard
                        end

                        [cols, clmidx] = sort(columns);

                        format{v} = '';

                        dcols = [cols(1); diff(cols)];
                        dcols(isnan(dcols))=[];
                        for i = 1:length(dcols)
                            for j = 2:dcols(i)
                                format{v} = sprintf('%s%%*q', format{v});
                            end
                            format{v} = sprintf('%s%%%s', format{v}, COLUMNS{clmidx(i),v});
                        end
                        format{v} = sprintf('%s%%*[^\\n]', format{v});

                        switch v
                            case CLN
                                % #ok<*FNDSB>
                                intrval     = find(cols == columns(INTRVAL),1);
                                layer       = find(cols == columns(LAYER),1);
                                layer_min   = find(cols == columns(LAYER_MIN),1);
                                layer_max   = find(cols == columns(LAYER_MAX),1);
                                latitude    = find(cols == columns(LATITUDE),1);
                                longitude   = find(cols == columns(LONGITUDE),1);
                                date        = find(cols == columns(DATE),1);
                                time        = find(cols == columns(TIME),1);
                                mean_height = find(cols == columns(MEAN_HEIGHT),1);
                                mean_depth  = find(cols == columns(MEAN_DEPTH),1);

                                sv_mean     = find(cols == columns(SV_MEAN),1);
                                sv_sd       = find(cols == columns(SV_SD),1);
                                sv_skew     = find(cols == columns(SV_SKEW),1);
                                sv_kurt     = find(cols == columns(SV_KURT),1);
                                if isnan(columns(LAYER)) ;       error('Layer column not found in %s', filename{v}) ;            end
                                if isnan(columns(LAYER_MIN)) ;   error('Layer_depth_min column not found in %s', filename{v}) ;  end
                                if isnan(columns(LAYER_MAX)) ;   error('Layer_depth_max column not found in %s', filename{v}) ;  end
                                if isnan(columns(LATITUDE)) ;    error('Lat_M column not found in %s', filename{v}) ;            end
                                if isnan(columns(LONGITUDE)) ;   error('Lon_M column not found in %s', filename{v}) ;            end
                                if isnan(columns(DATE)) ;        error('Date_M column not found in %s', filename{v}) ;           end
                                if isnan(columns(TIME)) ;        error('Time_M column not found in %s', filename{v}) ;           end
                                if isnan(columns(MEAN_HEIGHT)) ; error('Height_mean column not found in %s', filename{v}) ;      end
                                if isnan(columns(MEAN_DEPTH)) ;  error('Depth_mean column not found in %s', filename{v}) ;       end
                                if isempty(col_ev_file) ;        error('EV_filename column not found in %s', filename{v}) ;      end
                                if isempty(col_ev_version) ;     error('Program_version column not found in %s', filename{v}) ;  end
                                if isnan(columns(SV_MEAN)) ;     error('Sv_mean column not found in %s', filename{v}) ;          end
                                if control.extended
                                    if isnan(columns(SV_SD)) ;       error('Standard_deviation column not found in %s', filename{v}) ; end
                                    if isnan(columns(SV_SKEW)) ;     error('Skewness column not found in %s', filename{v}) ;         end
                                    if isnan(columns(SV_KURT)) ;     error('Kurtosis column not found in %s', filename{v}) ;         end
                                end

                            case RAW
                                rsv_mean    = find(cols == columns(SV_MEAN),1);
                                rsv_sd      = find(cols == columns(SV_SD),1);
                                rsv_skew    = find(cols == columns(SV_SKEW),1);
                                rsv_kurt    = find(cols == columns(SV_KURT),1);
                                rsamples    = find(cols == columns(SAMPLES) | cols == columns(GOOD_SAMPLES),1);
                                if isnan(columns(SAMPLES)) && isnan(columns(GOOD_SAMPLES));     error('Samples column not found in %s', filename{v}) ;          end

                            case CNT
                                tsamples    = find(cols == columns(SAMPLES) | cols == columns(GOOD_SAMPLES),1);
                                if isnan(columns(SAMPLES)) && isnan(columns(GOOD_SAMPLES));     error('Samples column not found in %s', filename{v}) ;          end

                            case S2N
                                ssv_mean    = find(cols == columns(SV_MEAN),1);

                            case BGD
                                bsv_mean    = find(cols == columns(SV_MEAN),1);
                            case MOT
                                mot_mean    = find(cols == columns(SV_MEAN),1); % Tim and Haris 13/06/2019 to add motion correction factor
                        end
                    end

                end            
                % pre-read ev file and version

                lineev = fgetl(fid(CLN));
                frewind(fid(CLN));
                fgetl(fid(CLN));
            
                % read files into memory
                
                cdata = textscan(fid(CLN),format{CLN},'Delimiter',',');
                idx = find(cdata{2}~=0); % kick out layer 0 rows (Tim Ryan 02/07/2019
                for i=1:length(cdata); cdata{i}=cdata{i}(idx); end                                    
                                
                rdata = textscan(fid(RAW),format{RAW},'Delimiter',',');
                idx = find(rdata{2}~=0);% kick out layer 0 rows (Tim Ryan 02/07/2019
                for i=1:length(rdata);rdata{i}=rdata{i}(idx); end                                    
                                                                
                tdata = textscan(fid(CNT),format{CNT},'Delimiter',','); 
                idx = find(tdata{2}~=0);% kick out layer 0 rows (Tim Ryan 02/07/2019
                for i=1:length(tdata); tdata{i}=tdata{i}(idx); end                                                    

                if ~feof(fid(CLN)) || ~feof(fid(RAW)) || ~feof(fid(CNT))
                    warning('READ:SHORT','Incomplete read of file')
                    keyboard
                end
                
                fclose(fid(CLN));
                fclose(fid(RAW));
                fclose(fid(CNT));
                
                if fid(MOT) < 0         % Tim and Haris 13/06/2019 to add motion correction factor
                    mdata = {[], []};
                else
                    mdata = textscan(fid(MOT),format{MOT},'Delimiter',','); 
                    if ~feof(fid(MOT))
                        warning('READ:SHORT','Incomplete read of file')
                        keyboard
                    end
                    fclose(fid(MOT)); 
                end   
                
                if fid(S2N) < 0
                    sdata = {[], []};
                else
                    sdata = textscan(fid(S2N), format{S2N},'Delimiter',',');
                    if ~feof(fid(S2N))
                        warning('READ:SHORT','Incomplete read of file')
                        keyboard
                    end
                    fclose(fid(S2N));
                end   
                if fid(BGD) < 0
                    bdata = {[], []};
                else
                    bdata = textscan(fid(BGD), format{BGD},'Delimiter',',');
                    if ~feof(fid(BGD))
                        warning('READ:SHORT','Incomplete read of file')
                        keyboard
                    end
                    fclose(fid(BGD));
                    bvalid = cellfun(@(x) x(1) ~= '9',bdata{bsv_mean});
                    for i = 1:length(bdata)
                        bdata{i}(~bvalid) = [];
                    end
                end
                
                % EV file and version
                fieldsev = strtrim(regexp(lineev, ',', 'split'));
                ev_filename = strtrim(fieldsev{col_ev_file});
                if ~isempty(ev_filename) && ev_filename(1) == '"' && ev_filename(end) == '"'
                    ev_filename([1 end]) = [];
                end        
                ev_ver = fieldsev{col_ev_version};
                if ~isempty(ev_ver) && ev_ver(1) == '"' && ev_ver(end) == '"'
                    ev_ver([1 end]) = [];
                end
                
            end 
            
            if ~any(strcmp(ev_filename, sample_data.dimensions{EV_FILE_D}.data))
                sample_data.dimensions{EV_FILE_D}.data{end+1} = ev_filename;
            end
                        
            if ~any(strcmp(ev_ver, sample_data.dimensions{EV_VERSION_D}.data))
                sample_data.dimensions{EV_VERSION_D}.data{end+1} = ev_ver;
            end  
            
            % data
            % note: intervals may start at 0 so we add 1 to all interval
            % numbers as matlab indexes from 1.            
            [ccells,cidx] = sortrows([cdata{intrval}+1 cdata{layer}]);
            [rcells,ridx] = sortrows([rdata{intrval}+1 rdata{layer}]);
            [tcells,tidx] = sortrows([tdata{intrval}+1 tdata{layer}]);
            [scells,sidx] = sortrows([sdata{intrval}+1 sdata{layer}]);
            [bcells,bidx] = sortrows([bdata{intrval}+1 bdata{layer}]);
            [mcells,midx] = sortrows([mdata{intrval}+1 mdata{layer}]); % Tim and Haris 13/06/2019 to add motion correction factor
            
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
                        end
                    end
                end
            end

            if channel == 1
                % preallocate sufficient space for data from this file
                intx = zeros(mxint,1);
                intx(mnint:mxint) = 1:mxint-mnint +1;

                if lastint > mxint
                    
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
            bi = i;
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
                    bi = bi + 1;
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

function line = trim(line)
    % Remove UTF-8 Byte Order Mark (ef bb bf) from header line if present
    %

    if  strncmp(line, ['' 239 187 191], 3)          % UTF-8 - used by EchoView 4 & 5
        line = line(4:end);
    end

    line=strtrim(line);

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
