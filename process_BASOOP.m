function control = process_BASOOP(control)
%process_BASOOP function to process vessel acoustics transit data
%
% control is a struct containing the settings to control this run.
%
% control can be built a number of ways, including via a GUI application.
%
% control may be the name of a MAT file containing the settings.
%
% Preconditions:
%
% control.template_file must have .ev extension. 
%
% template ev file will have filesets names Vessel_Sv_data (Item(0)) and
% Transit_GPS (Item(1)). 
%
% Transit_GPS file must have been created that contains GPS for the entire
% block of transit data that is being processed. This is essential. We need
% to process raw files in smaller blocks, but we reference the GPS file for
% the entire transit in order to produce echointegration intervals with a
% consistent spacing. This gets around the problem of blocks of files
% having a partial echointegration interval at the end of each block. Post
% processing is required outside of Echoview to remove partial
% echointegration intervals and intervals that have overlapped.  
%
% control.transit_data_files [{Q:\temp\transit_data_files.txt}]
% is cell array of names of files containing lists of transit data files.
%
% Assumes that the WaterColumnAcoustics storage area is mapped to the Q
% drive of the processing PC or files are specified in control.
%
% Author:   Gordon Keith
% Version:  2.0
% Date      2011-09-20
% ${Id:}
%
% Based on process_SOOP by Tim Ryan

% Lines preceded by a comment % ## are the lines that do the actual work for
% that operation. If you want to run the commands from the matlab command
% line look for those comments, everything else is just support.
%
%%
    
    warning('on','all') % keep it on incase it has been set to 'off'
    warning('off','backtrace')
    % Haris 09 July 2019 - keep warning off backtrace, note this is enabled
    % at the end as needed so that other programs will show this. Purpose
    % of this modification is to avoid line information printing on the
    % screen and the screen is getting busy with red lines. If warnings
    % need to be fixed, it is possible to check related functions.

    
    
    control.tstart = tic;        
    % fill in defaults for all fields not provided.       
    control = basoop(control);           
    % record settings used in log
    root_path = fileparts(mfilename('fullpath'));
    save_control = rmfield(control, 'progress');                            % remove references to figure objects
    save_control = rmfield(save_control, 'upload_password'); %#ok<NASGU>    % minimal security
    if isdir(fullfile(root_path, 'log'))
        save(fullfile(root_path, 'log',[datestr(now,'yyyymmdd-HHMMSS') '_' control.platform '_' getenv('USER') getenv('UserName')]), ...
            '-struct', 'save_control');
    end
    platform_path = fullfile(root_path, 'platform');
    % add directory containing process_BASOOP to matlab path
    if isempty(strfind(path,root_path))
        addpath(root_path);
    end    
    % convert control.transit_data_files to cell array for backward
    % compatibility
    if ~iscell(control.transit_data_files)
        tdf = control.transit_data_files;
        control.transit_data_files = [];
        control.transit_data_files = {tdf};
    end    
    % check inputs
    if control.create_ev_files
        if exist(control.template, 'file') ~= 2
            fprintf('\n\n*********************************************************************************************\n');
            fprintf('Template file %s not found in expected location\n', control.template);
            fprintf('Go and find the appropriate template file\n');
            fprintf('************************************************************************************************\n\n\n\n');
            [filename, pathname]= uigetfile('*.ev', 'Please select a template');
            if filename == 0
                error('Template not specified. A valid EchoView template must be given to create EV files.')
            end
            control.template = fullfile(pathname, filename);
        end
        
        for i = 1:length(control.transit_data_files)
            if exist(control.transit_data_files{i}, 'dir') == 7
                files = dir(fullfile(control.transit_data_files{i}, '*.raw'));
                files = {files(:).name};
                files = sort(files);
                if find(control.datalist_file == filesep, 1, 'first')
                    file_list = control.datalist_file;
                else
                    file_list = fullfile(control.transit_data_files{i}, control.datalist_file);
                end
                fid = fopen(file_list, 'w');
                for j = i:length(files); % TODO - check files is sorted
                    fprintf(fid,'%s\n', fullfile(control.transit_data_files{i}, files{j}));
                end
                fclose(fid);
                control.transit_data_files{i} = file_list;
            end
        end
        
        if exist(control.transit_data_files{1}, 'file') ~= 2
            fprintf('\n\n*********************************************************************************************\n');
            fprintf('Data file list %s not found in expected location\n', control.transit_data_files{1});
            fprintf('Go and find the appropriate file\n');
            fprintf('************************************************************************************************\n\n\n\n');
            [filename, pathname]= uigetfile('*.txt','Data file list');
            if filename == 0
                error 'Data file list not specified'
            end
            control.transit_data_files{1} = fullfile(pathname, filename);
        end
        
        if exist(control.transit_gps_file, 'file') ~= 2 && control.time_block > 0
            if control.make_gps
                fid = fopen(control.transit_data_files{1});
                infiles = textscan(fid,'%s');
                fclose(fid);
                outfile = 'temp_transit';                
                [~,infFile,gpsFile,pitchFile,rollFile,~] = getGPS(infiles, outfile, 'existing');
                control.transit_gps_file = gpsFile;
                control.transit_roll_file = rollFile;
                control.transit_pitchFile = pitchFile;
                if isempty(control.voyage_inf)
                    control.voyage_inf = infFile;
                end
            else
                fprintf('\n\n*********************************************************************************************\n');
                fprintf('GPS file %s not found in expected location\n', control.transit_gps_file);
                fprintf('Go and find the appropriate file\n');
                fprintf('************************************************************************************************\n\n\n\n');
                [filename, pathname]= uigetfile('*.csv','GPS file');
                if filename == 0
                    error 'GPS file not specified'
                end
                control.transit_gps_file = fullfile(pathname, filename);
            end
        end
    end    
    merge_file = control.merge_file;
    EvApp = [];
    ev_filelist = control.alt_ev_files;
    ev_files = {};
    Process_output_root_path = '';   
    % verify netcdf file matches selected platform
    if control.read_netcdf       
        pltfm = control.platform;
        pltfm(pltfm == ' ') = '-';
        pltfm(pltfm == '_') = '-';
        pmatch = any(strfind(control.netcdf_file, pltfm));
        
        if isempty(control.update_platform)
            control.update_platform = pmatch;
            
        elseif control.update_platform && ~pmatch
            question = {'Selected platform does not match NetCDF file' ...
                '(File name does not contain platform name)' ...
                'What do you want to do?'};
            answer = questdlg(question, 'Platform does not match ', ...
                'Update platform information', 'Ignore', 'Cancel', 'Cancel');
            if strcmp(answer, 'Cancel')
                error('Selected platform does not match NetCDF file');
            end
            if strcmp(answer, 'Ignore')
                control.update_platform = false;
            else
                control.update_platform = true;
                control.meta.abstract = '<<<';
            end
        end
    else
        control.update_platform = true;
    end
    
    %
    % Read voyage meta data from .inf file.
    %
    % This may require user input to select port where ambiguous and
    % doesn't rely on any other actions so it happens before time consuming
    % processing.
    %
    if control.read_inf
        if exist(control.voyage_inf, 'file') == 2
            control.meta = read_inf(control.meta, control.voyage_inf);
        else
            error('Voyage .inf file not found: %s', control.voyage_inf)
        end
    end    
    %
    % Read echoview calibration settings from .ecs file.
    % 
    % This may require user input to select the calibration and 
    % doesn't rely on any other actions so it happens before time consuming
    % processing.
    %
    if control.read_ecs & control.create_ev_files   % update so that will only proceed if create ev files is checked.      
        if exist(control.calibration_file, 'file') == 2
            % function to check that SourceCal value is matching freq, i.e.
            % T2 is for 38 kHz
            check_ecs(control.calibration_file);
            ecs_cals = read_ecs(control.calibration_file);
            fields = fieldnames(ecs_cals);
            match = true(size(ecs_cals));
            
            % find cal settings for each channel
            % 
            for i = 1:length(control.channel)
                % restrict by frequency if possible
                if isfield(ecs_cals, 'data_processing_frequency')
                    match = control.frequency(i) == [ecs_cals.data_processing_frequency];
                end
                if any(match)
                    cals = ecs_cals(match);
                else
                    cals = ecs_cals;
                end
                
                % ask user if more than one possible.
                if isempty(cals)
                    cal = [];
                    warning('BASOOP:no_cal','No calibration found for channel %s', control.channel{i})
                elseif length(cals) == 1
                    cal = 1;
                elseif isfield(control, 'calibration_name') && ~isempty(control.calibration_name{i})
                    cal = find(strcmp(cals(:).calibration_name,control.calibration_name{i}));
                    if isempty(cal)
                        warning('BASOOP:cal_not_found', 'Specified calibration %s not found for frequency %f in %s', ...
                            control.calibration_name{i}, control.frequency(i), control.calibration_file);
                    end
                else
                    
                    cal = listdlg('ListString', {cals(:).calibration_name}, ...
                        'SelectionMode', 'single', ...
                        'Name', 'Calibration Selection', ...
                        'PromptString', ['Please select calibration source for ' control.channel{i}], ...
                        'ListSize', [400 300]);
                end
                
                % copy calibration to control.meta for channel.
                for f = 1:length(fields)
                    if ~isempty(cals) && ~isempty(cals(cal).(fields{f}))
                        control.meta.channels(i).(fields{f}) = cals(cal).(fields{f});
                    end
                end
                control.meta.channels(i).name = control.channel{i};
                
                if ~isempty(cal)    % remove used cal settings from list of options
                    match(cal) = false;
                end
            end
        else
            error('ecs file not found: %s', control.calibration_file)
        end
    end
        

%%    
%
% Create .ev files from raw files and template.
%
    if control.create_ev_files
%         progress(control, '', [], [], [], control.transit_data_files{1})
        
        [file_sets, Process_output_root_path] = getFileSets(control);

%         progress(control, '', [], [], [], Process_output_root_path)
        
        if control.create_alt_ev_files
            Echoview_file_locations = control.alt_ev_dir;
        else
            Echoview_file_locations = ...
                fullfile(Process_output_root_path, control.worksheet_directory);
        end
        
        control.echoview_file_location = Echoview_file_locations;
        
        progress(control, 'create Echoview files for quality assurance', [], 0, [], ['to ' control.echoview_file_location])
        
        if ~isdir(Echoview_file_locations)
            mkdir(Echoview_file_locations)
        end            

        % Copy over the transit_data_files to the processed output
        % Echoview ev folder
        firstfile = control.transit_data_files{1};
        for i = 1:length(control.transit_data_files)
            [pth,file,ext] = fileparts(control.transit_data_files{i});
            if ~isempty(file) && ~strcmp(pth, Echoview_file_locations)
                if i == 1 || ~strcmp(firstfile, file)
                    copyfile(control.transit_data_files{i}, Echoview_file_locations)
                else
                    % ensure different names for different files
                    copyfile(control.transit_data_files{i}, fullfile(Echoview_file_locations, [control.filesets{i} '_' file ext]));
                end
            end
        end
        
        % Copy and use copies of GPS and motion files
        if ~strncmp(control.transit_gps_file, Echoview_file_locations, length(Echoview_file_locations))
            if copyfile(control.transit_gps_file, Echoview_file_locations)
                [~, t_file, t_ext] = fileparts(control.transit_gps_file);
                control.transit_gps_file = fullfile(Echoview_file_locations, [t_file t_ext]);
            elseif control.time_block > 0
                error 'Could not copy GPS file'
            end
        end
        if control.include_roll && ...
                ~strncmp(control.transit_roll_file, Echoview_file_locations, length(Echoview_file_locations))
            if copyfile(control.transit_roll_file, Echoview_file_locations)
                [~, t_file, t_ext] = fileparts(control.transit_roll_file);
                control.transit_roll_file = fullfile(Echoview_file_locations, [t_file t_ext]);
            else
                keyboard
                error 'Could not copy roll file'
            end
        end
        if control.include_pitch && ...
                ~strncmp(control.transit_pitch_file, Echoview_file_locations, length(Echoview_file_locations))
            if copyfile(control.transit_pitch_file, Echoview_file_locations)
                [~, t_file, t_ext] = fileparts(control.transit_pitch_file);
                control.transit_pitch_file = fullfile(Echoview_file_locations, [t_file t_ext]);
            else
                error 'Could not copy pitch file'
            end
        end
             
        create_start = tic;
%         create_progress =@(i,n,file)(progress(control, 'create ev',i, n, create_start, file)); % this progress message is updated as below - Haris 10 July 2019   
        create_progress =@(file)(progress(control, 'create Ev file from',[], 0,[], file));
        EvApp = getEvApp(EvApp, control.EvApp);
        EvApp.LogFileName = fullfile(Echoview_file_locations, 'echoview_log.txt');
        % ##
        ev_filelist = create_ev_files(file_sets, EvApp, control, create_progress);
        control.alt_ev_files = ev_filelist;      

        % Tim and Haris 26 July 2019 - HAC happens as soon as we created ev
        % file - needed for checking the effect of filters while reviewing
        % worksheets.
        [ev_files, Process_output_root_path] = get_ev_files(ev_filelist);
        export_import_HAC(EvApp, ev_files, control, @progress);
        
        % to be done - function to create images from Echoview print
        % echogram for named variables. Tim and Haris 18/10/2019
        % control is passed as this this has all meta information. Note
        % basoop.m might be updated to include settings relevant to this
        % function - for example image resolution
        % call to function print_ev(control, ev_files,Process_output_root_path)                
        
        progress(control, 'create Echoview files for quality assurance', 1,0,[], ev_filelist)
    else
        
        progress(control, 'create Echoview files for quality assurance', -1,0,[], ev_filelist)
    end
        
%%
%
% Determine Process_output_root_path and if needed  ev_files
%
    if control.review_ev_files || control.export_import_HAC || control.export_sv || control.export_sv_fast || control.read_echointegration || ...
            control.merge || control.read_merge 
        if isempty(ev_filelist)
            [file_sets, Process_output_root_path] = getFileSets(control);
            ev_filelist = ['Ev_files_' simrad_date_string(file_sets{1}{1}) '.txt'];
            ev_filelist = fullfile(Process_output_root_path, ...
                control.worksheet_directory, ev_filelist);
        end

        [ev_files, Process_output_root_path] = get_ev_files(ev_filelist);
    end
    
    if isempty(Process_output_root_path) 
        Process_output_root_path = fileparts(control.netcdf_file);
        if strncmp(Process_output_root_path, control.imos_directory, length(control.imos_directory))
            Process_output_root_path = fullfile(Process_output_root_path, 'transit');
        else
            Process_output_root_path = fileparts(Process_output_root_path);
        end
    end
    
    if isempty(Process_output_root_path)
        warning('BASOOP:NO_OUTPUT_ROOT', 'Unable to determine output directory\n')
    end
    
%%
%
% Manual review of worksheets in echoview
%
    if control.review_ev_files
        progress(control, 'review Echoview files for quality assurance', [], 0, [],'processing')
                
        EvApp = getEvApp(EvApp, control.EvApp);
        % ##
        ev_files = review_ev_files(EvApp, ev_files);
        progress(control, 'review Echoview files for quality assurance', 1, 0)
    else
        progress(control, 'review Echoview files for quality assurance', -1)
    end    
    if control.review_ev_images                 
        [imagepath, ~, ~] = fileparts(ev_filelist);
        [imagepath, ~, ~] = fileparts(imagepath);
        Image_Output_dir = fullfile(imagepath, control.images_directory_name);     
        cd(Image_Output_dir);    
        % launch BASOOP viewer        
        BASOOP_viewer
    end
%%
%
% Export worksheets to HAC format then import the HAC worksheets.
%
    if control.export_import_HAC
        progress(control, 'export quality assured raw data to HAC format & import from', [], 0, [],fullfile(Process_output_root_path,control.HAC_directory))
        EvApp = getEvApp(EvApp, control.EvApp);

        export_import_HAC(EvApp, ev_files, control, @progress);
        progress(control, 'export quality assured raw data to HAC format & import', 1, 0, '')
    else
        progress(control, 'export quality assured raw data to HAC format & import', -1)
    end
%%
%
% export Sv values to .csv files - slow processing
    if control.export_sv  & ~control.export_sv_fast    
        progress(control, 'slow export: quality assured data variables to CSV files', [])            
        %EvApp = getEvApp(EvApp, control.EvApp);                
        % ##                   
        %export_sv(EvApp, control, ev_files); 
                
        export_sv(control, ev_files);         
        
        progress(control, 'slow export: quality assured data variables to CSV files', 1, 0)  
    else
        progress(control, 'slow export: quality assured data variables to CSV files', -1)
    end
    
 %  export Sv values to csv from resampled variables - fast processing   
    if control.export_sv_fast  % removed condition of & control.export_sv            
        progress(control, 'fast export: quality assured data variables to CSV files', [])        
        EvApp = getEvApp(EvApp, control.EvApp);

        if isempty(ev_files)
            [ev_files, Process_output_root_path] = get_ev_files(control, ev_filelist);
        end
   
        export_sv_fast(EvApp, control, ev_files); 
        
        progress(control, 'fast export: quality assured data variables to CSV files', 1, 0)  
    else
        progress(control, 'fast export: quality assured data variables to CSV files', -1)
    end

%%
%
% Merge the exported .csv files to a file readable by echoviewParse
% ## Deprecated - only supports single channel
        
    if control.merge
        progress(control, 'merge', [], 0, [], merge_file) 
        
        echointegration_dir = fullfile(Process_output_root_path, control.echointegration_directory);
        
        merge_file = control.merge_file;
        if isempty(fileparts(merge_file))
            merge_file = fullfile(echointegration_dir, merge_file);
        end
    
        % ##
        merge3(echointegration_dir, merge_file, control.channel{1});
        progress(control, 'merge', 1, 0, [], merge_file)   
    else
%         progress(control, 'merge', -1) % Haris 09 July 2019 no need to
%         display if deprecated
    end
%%
% Haris 04 July 2019. Our processing happens as two stages. (1) generate EV
% files, review ev file, export and re-import HAC, and echo integration
% files (2) read those files and create NetCDF. Therefore, ideally the
% program should complete after ev file creation, review, export HAC, and
% echointegration export. After that the user can use these files for
% generating NetCDF. If the user selected any other settings the program
% will continue after CSV export and crash at later stages. To avoid this
% crashing (e.g. in simplified GUI) a condition has been added so that
% after echointegration the program is completed without throwing any
% errors.
    if control.create_ev_files || control.review_ev_files || control.export_import_HAC || control.export_sv  || control.export_sv_fast             
        control.telapsed = toc(control.tstart);
        fprintf('Program completed in: %.1f minutes = %.1f hours\n', (control.telapsed)/60, (control.telapsed)/3600);
        warning('on','all') % enable usual warning message. Backtrace was set to off in the first line
        return
    end
   
%%
% the following steps use the IMOS-toolbox which assumes it is in the
% current directory and the path, so find and change to the IMOS-toolbox
% directory and add the toolbox to the path, if not present.

    imos_path = fileparts(which('imosToolbox'));
    if isempty(imos_path)
        imos_path = fullfile(root_path,'IMOS-toolbox');
    end
    if ~exist(imos_path,'dir')
        warning('BASOOP:NO_IMOS', 'IMOS-toolbox not found\n')
    else
        basoop_dir = cd(imos_path);
    end
    
    if isempty(strfind(path,imos_path))
        addpath(imos_path);
        addpath(fullfile(imos_path, 'NetCDF'));
        addpath(fullfile(imos_path, 'Parser')); 
        addpath(fullfile(imos_path, 'Util')); 
        addpath(fullfile(imos_path, 'IMOS')); 
        addpath(fullfile(imos_path, 'GUI')); 
       
%         imospath=genpath(pwd);
%         imospath=regexprep(imospath, ...
%             [ pathsep '[^' pathsep ']+' filesep '.svn[^' pathsep ']*' ], '');
%         imospath=regexprep(imospath, ...
%             [ pathsep '[^' pathsep ']+' filesep 'Java[^' pathsep ']*' ], '');
%         addpath(imospath);
    end
    
%
% Use IMOS-toolbox echoviewParse to create sample_data from merged .csv
% file
% ## Deprecated - only supports single channel
%
    sample_data =[];
    
    if control.read_merge
        parse_file = control.parse_file;
        if isempty(parse_file)
            if isempty(fileparts(merge_file))
                merge_file = fullfile(Process_output_root_path, control.echointegration_directory, merge_file);
            end
            parse_file = merge_file;
        end
        
        if ~isfield(control.meta, 'transect_id') || ~isempty(control.meta.transect_id)
            transect = fileparts(fileparts(parse_file));
            [transect, control.meta.transect_id] = fileparts(transect);
            if ~isfield(control.meta, 'cruise_id') || ~isempty(control.meta.cruise_id)
                [~,control.meta.cruise_id] = fileparts(transect);
            end
        end
        
        progress(control, 'read merge', [], 0, [], parse_file)
        if control.extended
            sample_data = echoviewParse({parse_file}, control.platform, 'echoview_extend.txt', control.channel{1});
        else
            % ##
            sample_data = echoviewParse({parse_file}, control.platform, '', control.channel{1});
        end
        
        progress(control, 'read merge', 1, 0, [], parse_file)
    end
    
%%
%
% Read echointegration results
%
    if control.read_echointegration        
        progress(control, 'read quality assured echo integration CSV files', [], 0, [], Process_output_root_path)
                 
        if ~isempty(control.echointegration_path)
            echointegration_path = control.echointegration_path;
        else
            echointegration_path = fullfile(Process_output_root_path, control.echointegration_directory);
        end        
        % ##
        
        % figure out whether echointegration was done via fast processing
        % or original standard. The key is that fast processing csv files
        % will have the word 'resampled' in their name. Look for this
        % string, if true then it was fast processed, if not then was
        % standard. Set the control.export_sv_fast accordingly and the
        % function read_echointegration already has code to check what type
        % of processing was done and then take you to the right part of the
        % program. Tim Ryan July 2019         
        exportfiles = ls(echointegration_path);
        % check export type - standard or fast and select appropriate
        % read_echoint... function - Tim Ryan 1/08/2019        
        if sum(~cellfun('isempty',strfind(cellstr(exportfiles),'resample')))>0
            control.export_sv_fast = 1; 
            fprintf('Fast processing was used\n');
            sample_data = read_echointegration_fast(echointegration_path, ev_files, control, @progress);         
        else
            control.export_sv_fast = 0; 
            fprintf('Standard processing was used\n');                            
            sample_data = read_echointegration(echointegration_path, ev_files, control, @progress);
        end                 
        % get grid size from control        
        sample_data.dataset_range_axis_size = control.Grid_height;
        sample_data.dataset_ping_axis_units = 'Distance';
        if mod(control.Grid_distance, 463) == 0   % quarter nautical mile
            sample_data.dataset_ping_axis_size = [num2str(control.Grid_distance/1852) ' Nm'];
        elseif mod(control.Grid_distance, 1000) == 0
            sample_data.dataset_ping_axis_size = [num2str(control.Grid_distance/1000) ' km'];
        else
            sample_data.dataset_ping_axis_size = [num2str(control.Grid_distance) ' m'];
        end
        
       progress(control, 'read quality assured echo integration CSV files', 1, 0, [], Process_output_root_path)
        
        % get data_processing settings from first evfile.        
                
        EvApp = getEvApp(EvApp, control.EvApp);
        
        progress(control, 'read calibration metadata from EV file', [], 0, [],'processing') % Haris on 05 July 2019
        
        if ~isempty(EvApp)
            channel_d = [];
            ev_d = [];
            for i = 1:length(sample_data.dimensions)
                if strcmpi(sample_data.dimensions{i}.name, 'CHANNEL')
                    channel_d = i;
                end
                if strcmpi(sample_data.dimensions{i}.name, 'EV_FILENAME')
                    ev_d = i;
                end
            end
            
            % column 1 is ECS parameter, column 2 is metadata field.
            % ECS parameter may appear more than once. metdata field may be blank.
            % see also read_ecs.m translate.
%             calset = {
%                 'AbsorptionCoefficient'     , 'data_processing_absorption';
%                 'AbsorptionCoefficient'     , 'transceiver_absorption';
%                 'EK60SaCorrection'          , 'data_processing_sa_correction';
%                 'Ek60TransducerGain'        , 'data_processing_transceiver_gain';
%                 'Frequency'                 , 'data_processing_frequency';
%                 'MajorAxis3dbBeamAngle'     , 'data_processing_transducer_beam_angle_major';
%                 'MajorAxisAngleOffset'      , '';
%                 'MajorAxisAngleSensitivity' , '';
%                 'MinorAxis3dbBeamAngle'     , 'data_processing_transducer_beam_angle_minor';
%                 'MinorAxisAngleOffset'      , '';
%                 'MinorAxisAngleSensitivity' , '';
%                 'SoundSpeed'                , 'data_processing_soundspeed';
%                 'SoundSpeed'                , 'transceiver_soundspeed';
%                 'TransmittedPower'          , 'data_processing_transceiver_power';
%                 'TransmittedPulseLength'    , 'data_processing_transmit_pulse_length';
%                 'TvgRangeCorrection'        , '';
%                 'TwoWayBeamAngle'           , 'data_processing_transducer_psi';
%                 };

% edit by Haris to match with updated metadata record (17 November 2017)             
            
            calset = {
                'AbsorptionCoefficient'     , 'data_processing_absorption';
                'EK60SaCorrection'          , 'data_processing_Sacorrection';
                'Ek60TransducerGain'        , 'data_processing_on_axis_gain';
                'Frequency'                 , 'data_processing_frequency';
                'MajorAxis3dbBeamAngle'     , 'data_processing_transducer_beam_angle_major';
                'MajorAxisAngleOffset'      , '';
                'MajorAxisAngleSensitivity' , '';
                'MinorAxis3dbBeamAngle'     , 'data_processing_transducer_beam_angle_minor';
                'MinorAxisAngleOffset'      , '';
                'MinorAxisAngleSensitivity' , '';
                'SoundSpeed'                , 'data_processing_soundspeed';
                'TransmittedPower'          , 'data_processing_transceiver_power';
                'TransmittedPulseLength'    , 'data_processing_transmit_pulse_length';
                'TvgRangeCorrection'        , '';
                'TwoWayBeamAngle'           , 'data_processing_transducer_psi';
                };
            
            
            evfilename = sample_data.dimensions{ev_d}.data{1};
            EvFile = EvApp.OpenFile(evfilename);
            
            for ch = 1:length(control.channel)
                varname = sprintf(control.calibration_variable_name, control.channel{ch});
                
                % Edit by Haris on 8 June 2019. For single frequency
                % template, read calibration information from Echoview
                % variable 'Sv_xxkHz' instead of �Final_xxkHz_cleaned�.
                
                % Edit by Haris on 24 September 2019. For all
                % templates,read calibration information from Echoview
                % variable 'Sv_xxkHz' instead of �Final_xxkHz_cleaned�.
    
% % %                 if length(control.channel)==1
% % %                     varname = sprintf('Sv_%s', control.channel{ch});
% % %                 end
                
                varname = sprintf('Sv_%s', control.channel{ch});
                     
                Var = EvFile.Variables.FindByName(varname);
                if isempty(Var)
                    warning('BASOOP:NO_CAL_VAR', 'Calibration variable %s not found', varname);
                    varname = sprintf(control.export_final_variable_name, control.channel{ch});
                    Var = EvFile.Variables.FindByName(varname);
                end
                junkfile = fullfile(echointegration_path, 'ping.csv');
                Var.ExportData(junkfile, 1, 1); % force calibration data for the variable to be populated in echoview
                calibration = Var.AsVariableAcoustic.Properties.Calibration;
                
                % Haris 07/01/2020- For Ex80 data 'Ek60TransducerGain' is
                % not valid, that should be 'TransducerGain'. Replace
                % 'Ek60TransducerGain' with 'TransducerGain' in calset.
                
                if isequal(calibration.Get('TvgRangeCorrection',0),'SimradEK80')
                    warning ('The data is Ex80 format? replacing the field "Ek60TransducerGain" with "TransducerGain" for reading correct calibration metadata')
                    calset = strrep(calset,'Ek60TransducerGain','TransducerGain');
                end
                
                for c = 1:size(calset,1)                     
                    try
                        param = calibration.Get(calset{c,1},0);
                    catch                        
                        keyboard
                    end                         
                    if isempty(param)
                        warning('BASOOP:NO_CAL_EV', 'Calibration parameter %s not set for %s in %s', ...
                            calset{c,1}, varname, evfilename);
                    else
                        try param = str2double(param); catch ; end %#ok<CTCH>
                        if ~isempty(calset{c,2})
                            control.meta.channels(ch).(calset{c,2}) = param;
                        end
                    end
                end
            end
            EvFile.Close;
            EvApp.Quit; % close Echoview            
        end
        progress(control, 'read calibration metadata from EV file', 1, 0, [], '') % Haris on 05 July 2019
        save(fullfile(root_path,'log','sample_data.mat'),'-struct','sample_data'); 
    else
        progress(control, 'read quality assured echo integration CSV files', -1)
    end

%%
%
% Read an existing NetCDF file using IMOS-toolbox netcdfParse
%

    ncfile=control.netcdf_file;
    
    if control.read_netcdf
        
        if ~control.copy_netcdf_metadata && ~isempty(sample_data) 
            if control.read_echointegration
                have_read = ['Echointegration has been read from ' Process_output_root_path];
            else
                have_read =  ['Merge file ' parse_file 'has been read,'];
            end
            question = { have_read ...
                'but you also want to read a NetCDF file ' ...
                control.netcdf_file ...
                'You can''t do both' };
            answer = questdlg(question, 'Skip NetCDF read', ...
                'Discard data', 'Copy NetCDF metadata', 'Skip NetCDF', 'Skip NetCDF');
            if strcmp(answer, 'Discard data')
                sample_data = [];
            end
            if strcmp(answer, 'Copy NetCDF metadata')
                control.copy_netcdf_metadata = true;
            end
        end
        
        if control.copy_netcdf_metadata || isempty(sample_data)
            progress(control, 'read existing NetCDF', [], 0, [], control.netcdf_file)
            try
                % netcdf_file may in fact be a .mat file, 
                % try to load in case it is.
                sample_data_nc = load(control.netcdf_file);
                if isfield(sample_data, 'sample_data')
                    sample_data_nc = sample_data_nc.sample_data;
                end
            catch
                % ##
                sample_data_nc = netcdfParse({control.netcdf_file});
                
                if isfield(sample_data_nc, 'history')
                    try
                        fprintf(sample_data_nc.history);
                    catch
                        % there is a bug here
                        keyboard
                    end
                end
                
                %identify CHANNEL dimension
                channel_d = [];
                for i = 1:length(sample_data_nc.dimensions)
                    if strcmpi(sample_data_nc.dimensions{i}.name, 'CHANNEL')
                        channel_d = i;
                    end
                end
                
                if isempty(channel_d)  % single frequency format BASOOP-2.0
                   
                    if ~isfield(sample_data_nc, 'frequency') && isfield(sample_data_nc, 'instrument_frequency') 
                        sample_data_nc.frequency = sample_data_nc.instrument_frequency;
                    end
                    chanfile = fullfile(platform_path, '_channel.txt');
                    chanAtts = parseNetCDFTemplate(chanfile, struct);
                    chanfields = fieldnames(chanAtts);
                    sample_data_nc.meta.channels.name = [ num2str(sample_data_nc.frequency) 'kHz' ];
                    control.single_format = true;
                    for field = chanfields'
                        fld = field{1};
                        if isfield(sample_data_nc, fld)
                            sample_data_nc.meta.channels.(fld) = sample_data_nc.(fld);
                            sample_data_nc = rmfield(sample_data_nc, fld);
                        else
                            sample_data_nc.meta.channels.(fld) = [];
                        end
                    end
                    
                else    % multi frequency format BASOOP-2.1
                    % check for selected channels
                    nc_channels = sample_data_nc.dimensions{channel_d}.data;
                    if size(nc_channels, 1) ~= size(control.channel, 1)
                        nc_channels = nc_channels';
                    end
                    allfound = 1;
                    for i = length(control.channel):-1:1
                        ch = find(strcmp(control.channel{i}, nc_channels));
                        if isscalar(ch)
                            chidx(i) = ch;
                        else
                            allfound = 0;
                        end
                    end
                    
                    if allfound
                        if length(control.channels) == length(nc_channels)
                            opt2 = 'Use file channels';
                            control.channel = nc_channels;     % use file order 
                            % TODO sort control.meta.channels (ecs data)
                        else
                            opt2 = 'Discard unwanted channels';
                        end
                    else
                        opt2 = 'Cancel'; 
                    end
                    
                    % if selected channels don't match file channels
                    if length(nc_channels) ~= length(control.channel) || ...
                            ~all(strcmp(nc_channels, control.channel))
                                                
                        question = [ 'NetCDF file channels don''t match selected channels' ...
                            ' ' '         NetCDF file: ' nc_channels ...
                            ' ' '         Selected: ' control.channel ...
                            ' ' 'What do you want to do?'];
                        if isempty(control.channel_mismatch)
                            answer = questdlg(question, 'Channel mismatch', ...
                                'Use file channels', opt2, 'Cancel', ...
                                'Use file channels');
                        else
                            answer = control.channel_mismatch;
                        end
                        
                        if strcmp(answer, 'Use file channels')
                            control.channel = nc_channels;
                            % TODO handle control.meta.channels
                        elseif strcmp(answer, 'Discard unwanted channels')
                            sample_data_nc.dimensions{channel_d}.data = control.channel';
                            for i = length(sample_data_nc.variables):-1:1
                               cdim = find(sample_data_nc.variables{i}.dimensions == channel_d);
                                if isempty(cdim)
                                elseif cdim == 1 && length(sample_data_nc.variables{i}.dimensions) == 1
                                    sample_data_nc.variables{i}.data = sample_data_nc.variables{i}.data(chidx);
                                    if isfield(sample_data_nc.variables{i}, 'flags')
                                        sample_data_nc.variables{i}.flags = sample_data_nc.variables{i}.flags(chidx);
                                    end
                                elseif cdim == 3 && length(sample_data_nc.variables{i}.dimensions) == 3
                                    sample_data_nc.variables{i}.data = sample_data_nc.variables{i}.data(:,:,chidx);
                                    if isfield(sample_data_nc.variables{i}, 'flags')
                                        sample_data_nc.variables{i}.flags = sample_data_nc.variables{i}.flags(:,:,chidx);
                                    end
                                else
                                    error('Unsupported data format - channel is dimension %d of %d', ...
                                        cdim, length(sample_data_nc.variables{i}.dimensions));
                                end
                            end
                        else
                            error('File channels do not match selected channels');
                       end
                    end
                    
                    % use the selected channels
                    for c = 1:length(control.channel)
                        sample_data_nc.meta.channels(c).name = ...
                            control.channel{c};
                    end
                    
                    % **********    check *********
                    % move channel variables from variables to
                    % meta.channels
                    % for i = length(sample_data_nc.variables):-1:1
                    % the last value in the nc variables list is
                    % 'frequency' this is getting added twice to the list
                    % of variables and upsets exportNetCDF which doesn't
                    % like to see two variables in the one netcdf file
                    % putting this patch here to reduce the variable by 1
                    % to see if then the reprocessing works for
                    % multifrequency data. TER 4/08/2017
                    for i = length(sample_data_nc.variables)-1:-1:1                        
                        if sample_data_nc.variables{i}.dimensions(1) == channel_d
                            for c = 1:length(sample_data_nc.dimensions{channel_d}.data)
                                val = sample_data_nc.variables{i}.data(c);
                                if iscell(val);     val = val{1} ;  end
                                sample_data_nc.meta.channels(c).(sample_data_nc.variables{i}.name) = val;                                   
                            end
                            sample_data_nc.variables(i) = [];
                        end
                    end
                end
            end
            
            [~, ncfname] = fileparts(control.netcdf_file);
            history = sprintf('%s\n',ncfname);
            if isfield(sample_data_nc, 'history')
                history = sprintf('%s\n%s', sample_data_nc.history, history);
            end
            if isfield(sample_data_nc, 'date_created')
                try
                    history = sprintf('%s %s ', history, datestr(sample_data_nc.date_created, 'yyyy-mm-ddTHH:MM:SSZ'));
                catch
                    history = sprintf('%s %s ', history, sample_data_nc.date_created);
                end
            end
            if isfield(sample_data_nc, 'data_processing_by') && ~isempty(sample_data_nc.data_processing_by)
                history = sprintf('%s by %s ', history, sample_data_nc.data_processing_by);
            end
            if isfield(sample_data_nc, 'data_processing_software_name')
                history = sprintf('%s using %s', history, sample_data_nc.data_processing_software_name);
            else
                if isfield(sample_data_nc.meta.channels, 'data_processing_software_name')
                    dpsn = sample_data_nc.meta.channels(1).data_processing_software_name;
                    history = sprintf('%s using %s', history, dpsn);
                    for i = 2:length(sample_data_nc.meta.channels)
                        if ~strcmp(dpsn, sample_data_nc.meta.channels(i).data_processing_software_name)
                            dpsn = sample_data_nc.meta.channels(i).data_processing_software_name;
                            history = sprintf('%s; %s', history, dpsn);
                        end
                    end
                end
            end
            if isfield(sample_data_nc, 'data_processing_software_version')
                history = sprintf('%s version %s', history, sample_data_nc.data_processing_software_version);
            else
                if isfield(sample_data_nc.meta.channels, 'data_processing_software_version')
                    dpsv = sample_data_nc.meta.channels(1).data_processing_software_version;
                    history = sprintf('%s using %s', history, dpsv);
                    for i = 2:length(sample_data_nc.meta.channels)
                        if ~strcmp(dpsv, sample_data_nc.meta.channels(i).data_processing_software_version)
                            dpsv = sample_data_nc.meta.channels(i).data_processing_software_version;
                            history = sprintf('%s; %s', history, dpsv);
                        end
                    end
                end
            end
        
            if isempty(sample_data)         % =>  ~control.copy_netcdf_metadata
                sample_data = sample_data_nc;
                
                control.channel = { sample_data_nc.meta.channels(:).name };
                
                if isempty(channel_d) && ~control.single_format
                    channel_d = length(sample_data.dimensions) + 1;
                    sample_data.dimensions{channel_d}.name = 'CHANNEL';
                    sample_data.dimensions{channel_d}.data = sample_data.channel;
                end
            else
                
                fields = fieldnames(sample_data_nc);
                for i = 1:length(fields)
                    field = fields{i};
                    if ~isfield(sample_data, field) || isempty(sample_data.(field)) || ...
                            (ischar(sample_data.(field)) && sample_data.(field)(1) == '(' && sample_data.(field)(end) == ')')
                        sample_data.(field) = sample_data_nc.(field);
                    end
                end                
                nchan = length(sample_data_nc.meta.channels);
                if ~isfield(sample_data.meta, 'channels')
                    sample_data.meta.channels(nchan) = struct();
                end
                
                fields = fieldnames(sample_data_nc.meta.channels);
                for c = 1:nchan
                    for i = 1:length(fields)
                        field = fields{i};
                        if ~isfield(sample_data.meta.channels, field) || isempty(sample_data.meta.channels(c).(field)) || ...
                                (ischar(sample_data.meta.channels(c).(field)) && sample_data.meta.channels(c).(field)(1) == '(' && sample_data.meta.channels(c).(field)(end) == ')')
                            sample_data.meta.channels(c).(field) = sample_data_nc.meta.channels(c).(field);
                        end
                    end
                end
           end
            
            sample_data.history = history;
           
            date = java.util.Date();
            timezone = date.getTimezoneOffset() / 24 / 60;
            sample_data.date_modified = now - timezone;
            sample_data.meta.log = {};
            progress(control, 'read existing NetCDF', 1, 0, [], control.netcdf_file)
        end
    end
    
%%

    % use user provided meta data
    if ~isempty(sample_data)
        
        % find dimensions
        channel_d = [];
        ev_d = [];
        for i = 1:length(sample_data.dimensions)
            if strcmpi(sample_data.dimensions{i}.name, 'TIME')
                time_d = i;
            end
            if strcmpi(sample_data.dimensions{i}.name, 'DEPTH')
                depth_d = i;
            end
            if strcmpi(sample_data.dimensions{i}.name, 'CHANNEL')
                channel_d = i;
            end
            if strcmpi(sample_data.dimensions{i}.name, 'EV_FILENAME')
                ev_d = i;
            end
        end
        
        
        fields = fieldnames(sample_data);
        for field = fields'
            fld = field{1};
            if ischar(sample_data.(fld)) && ...
                    strncmp(sample_data.(fld), 'Reference to non-existent field', 31)
                sample_data.(fld) = '';
            end
        end
        
        sample_data.meta.facility_code = control.facility;
        
        % platform metadata
        if control.update_platform
            sample_data = getAttributes(sample_data, ...
                fullfile(platform_path, [ control.platform '_attributes.txt' ]), control.update_platform);
            
            for c = 1:length(control.channel)
                chan = control.channel{c};
                sample_data.meta.channels(c).name = chan;
                chanfile = fullfile(platform_path, [ control.platform '_' chan '.txt' ]);
                if exist(chanfile, 'file') == 2
                    chanatt = getAttributes(sample_data.meta.channels(c), chanfile, control.update_platform);
                    fields = fieldnames(chanatt);
                    for f = 1:length(fields)
                        sample_data.meta.channels(c).(fields{f}) = chanatt.(fields{f});
                    end
                else
                    warning('BASOOP:NOMETA', 'Metadata file not found: %s', chanfile);
                end
            end
        end
        
        % user provided extra metadata
        if control.read_meta && exist(control.metadata_file, 'file') == 2
            extras = parseNetCDFTemplate(control.metadata_file,sample_data);
            fields = fieldnames(extras);
            for field = fields'
                fld = field{1};
                if ~isempty(extras.(fld))
                    control.meta.(fld) = extras.(fld);
                end
            end
        end
        
        sample_data.meta.level = 2;
        if isfield(sample_data, 'vessel_name') && ~isfield(sample_data, 'ship_name')
            sample_data.ship_name = sample_data.vessel_name;
        end
        if isfield(sample_data, 'vessel_callsign') && ~isfield(sample_data, 'ship_callsign')
            sample_data.ship_callsign = sample_data.vessel_callsign;
        end
        if isfield(sample_data, 'ship_name')
            sample_data.meta.site_name = sample_data.ship_name;
            sample_data.meta.site_id = sample_data.ship_name;
            deployment_id = [sample_data.ship_name ...
                datestr(sample_data.dimensions{time_d}.data(1),' yyyymmdd') ...
                datestr(sample_data.dimensions{time_d}.data(end),'-yyyymmdd')];
            deployment_id(deployment_id == ' ') = '_';
            sample_data.deployment_id = deployment_id;
            % Edit by Haris on 23 January 2019: AODN uses this
            % deployment_id as the unique identifier for data management.
            % Currently, for vessels Antarctic Chieftain and Antarctic
            % Discovery the deployment_id is same for 18 and 38 kHz data
            % because these two vessels are providing seperate raw files
            % for 18 & 38 kHz.This means the global attribute
            % 'deployment_id' is not unique for a given transect with 18 &
            % 38 kHz data. A condition has been added for these two vessels
            % for appending frequency information with 'deployment_id'.
            % This modification is necessary to manage and store our data
            % at AODN. This modification was done based on the request from
            % AODN.
            % Adding vessel Tokatu on 8 October 2019.
            
            if isequal(sample_data.platform_code,'VKAD') | isequal(sample_data.platform_code,'VJT6415') | isequal(sample_data.platform_code,'ZMTK') % checking Discovery, Chieftain, Tokatu
                sample_data.deployment_id = strcat(deployment_id,'_',num2str(sample_data.frequency));
            end            
        end        
        
        if isfield(sample_data.meta, 'depth') && ~isempty(sample_data.meta.depth)
        elseif isfield(sample_data.meta, 'channels') && isfield(sample_data.meta.channels, 'frequency') 
            sample_data.meta.depth = [sample_data.meta.channels(:).frequency];
        elseif isfield(sample_data, 'instrument_frequency')
            sample_data.meta.depth = sample_data.instrument_frequency;
        elseif isfield(sample_data, 'frequency') 
            sample_data.meta.depth = sample_data.frequency;
        elseif isfield(sample_data, ['frequency_' control.channel{1}])
            sample_data.meta.depth = sample_data.(['frequency_' control.channel{1}]);
        end
        
        if isfield(sample_data.meta, 'channels') && isfield(sample_data.meta.channels, 'instrument_transceiver_model') 
            sample_data.meta.instrument_model = sample_data.meta.channels(1).instrument_transceiver_model;
        elseif isfield(sample_data, 'instrument_transceiver_model')
            sample_data.meta.instrument_model = sample_data.instrument_transceiver_model;
        elseif isfield(sample_data, 'transceiver_model')
            sample_data.meta.instrument_model = sample_data.transceiver_model;
        elseif isfield(sample_data, ['transceiver_model_' control.channel{1}])
            sample_data.meta.instrument_model = sample_data.(['transceiver_model_' control.channel{1}]);
        end
        
        if isfield(control.meta, 'channels')
            chans = control.meta.channels;
            fields = fieldnames(chans);
            for i = 1:length(chans)
                for field = fields'
                    fld = field{1};
                    if ~isempty(chans(i).(fld))
                        sample_data.meta.channels(i).(fld) = chans(i).(fld);
                    end
                end               
            end
            control.meta = rmfield(control.meta, 'channels');
        end
        
        fields = fieldnames(control.meta);
        for field = fields'
            fld = field{1};
            if ~isempty(control.meta.(fld))
                if strcmp(fld,'history')    % timestamp and append history rather than replace
                    nowj = (now - datenum([1970 1 1])) * 86400000;              % now in ms since 1970
                    timezone = java.util.TimeZone.getDefault().getOffset(nowj); 
                    nowt = now - timezone / 86400000;
                    comment = [datestr(nowt, 'yyyy-mm-ddTHH:MM:SSZ') ' ' getenv('USER') getenv('UserName') ' ' control.meta.(fld)];
                    if isfield(sample_data,fld)
                        comment = [sample_data.(fld) '\n' comment];         %#ok<AGROW>
                    end
                    sample_data.(fld) = comment;
                elseif strcmp(control.meta.(fld),'<<<')     % erase
                    if isfield(sample_data, fld)
                        sample_data = rmfield(sample_data, fld);
                    end
                else
                    sample_data.(fld) = control.meta.(fld);
                end
            end
        end
        
        % software version information
        sample_data.toolbox_version = 'unknown';
        toolbox_version = '';
        toolbox =  which('imosToolbox');
        if ~isempty(toolbox)
            try
                fid = fopen(toolbox, 'rt');
                line = fgetl(fid);
                while ischar(line) && isempty(toolbox_version)
                    toolbox_version = ...
                        regexp(line,'toolboxVersion\s*=.*''(.+)''', 'tokens');
                    line = fgetl(fid);
                end
                fclose(fid);
                if ~isempty(toolbox_version)
                    sample_data.toolbox_version = toolbox_version{1}{1};
                end
            catch exception
                warning('BASOOP:Toolbox_version', ...
                    'Can''t get toolbox version: %s', exception.message)
            end
        end
        
        if ~isfield(sample_data, 'echoview_version')
            if isfield(sample_data.meta, 'channels') && isfield(sample_data.meta.channels, 'echoview_version')
                sample_data.echoview_version = sample_data.meta.channels(1).echoview_version;
            else
                sample_data.echoview_version = 'unknown';
                if isfield(sample_data, 'processing_software_version')
                    sample_data.echoview_version = sample_data.processing_software_version;
                end
            end
        end
        
        sample_data.matlab_version = version;
        
        % edit by Haris to keep spelling consistency 17 November 2017
        software = [ ...
            'process_BASOOP; ' ...
            'Matlab; ' ...
            'IMOS toolbox; ' ...
            'Echoview' ];
%         software = [ ...
%             'process_BASOOP; ' ...
%             'matlab; ' ...
%             'IMOS toolbox; ' ...
%             'EchoView' ];
        sample_data.data_processing_software_name = software;
        sample_data.data_processing_software_version = [ ...
            control.version '; ' ...
            version '; ' ...
            sample_data.toolbox_version '; ' ...
            sample_data.echoview_version ];
        
        if isfield(sample_data.meta, 'channels')
            for i = 1:length(sample_data.meta.channels)
                sample_data.meta.channels(i).data_processing_software_name = sample_data.data_processing_software_name;
                if isfield(sample_data.meta.channels, 'echoview_version') && ~isempty(sample_data.meta.channels(i).echoview_version)
                    sample_data.echoview_version = sample_data.meta.channels(i).echoview_version;
                end
                sample_data.meta.channels(i).data_processing_software_version = [ ...
                    control.version '; ' ...
                    version '; ' ...
                    sample_data.toolbox_version '; ' ...
                    sample_data.echoview_version ];
            end
        end
    end
    
%%
%
% Apply time offset correction in post processing.
%
% Time offset correction is normalling done by applying the time offset to
% the fileset in EchoView.
%

    if control.posttime
        % ##
        sample_data.dimensions{time_d}.data = sample_data.dimensions{time_d}.data + control.time_offset(1) / 86400;
        
        % force recalculation of 'day' if time is adjusted.
        for i = 1:length(sample_data.variables)
            if strcmp('day', sample_data.variables{i}.name)
                sample_data.variables(i) = [];
                control.layer_indices = true;
                break
            end
        end
        
        nowj = (now - datenum([1970 1 1])) * 86400000;              % now in ms since 1970
        timezone = java.util.TimeZone.getDefault().getOffset(nowj);
        nowt = now - timezone / 86400000;
        sgn=sprintf('%+f',control.time_offset(1));
        message = sprintf('%s %s%s Time correction of %s%s applied in post processing. ', ...
            datestr(nowt, 'yyyy-mm-ddTHH:MM:SSZ'), getenv('USER'), getenv('UserName'), ...
            sgn(1),datestr(abs(control.time_offset(1)) / 86400,'HH:MM:SS'));
        if isfield(sample_data, 'history')
            sample_data.history = sprintf('%s\n%s', sample_data.history, message);
        else
            sample_data.history = message;
        end
    end
    
%%
%
% Read synthetic temperature and salinity from CARS data and include in
% data set.
%
    if control.synTS
        progress(control, 'read climatology data (synTS)', [], 0, [],'processing')
        try
            % ##
            sample_data = get_synTS(sample_data);
            
            if control.sound_speed
                % create variables for correct_sound_speed to store intermediate
                % results
                v = length(sample_data.variables);
                for i = v:-1:1
                    if strcmp(sample_data.variables{i}.name, 'salinity');
                        break
                    end
                end
            end
        catch e
            warning('BASOOP:SYNTS', 'synTS not available: %s', e.message);
        end
        
        progress(control, 'read climatology data (synTS)', 1, 0, [], '')
    else
        progress(control, 'read climatology data (synTS)', -1)
    end
    
    
%%
%
% Read CSIRO Atlas of Regional Seas for climatology data
%
    if control.CARS & ~isempty(sample_data)        
        progress(control, 'read climatology data (CARS)', [], 0, [],'processing')
        
        sample_data = get_climate(sample_data);
        progress(control, 'read climatology data (CARS)', 1, 0, [], '')
%         fprintf('CARS was used as synTS was not available for this region\n');
    else
       progress(control, 'read climatology data (CARS)', -1) 
    end
    
%%
%
% Read Net primary production data
%
    if control.npp & ~isempty(sample_data)
        progress(control, 'read net primary production data (NPP)', [], 0, [],'processing')
        
        try
            sample_data = get_npp(sample_data,control.npp_path);
        catch e
            warning('BASOOP:NPP', 'NPP not available, check folder Q:\Generic_data_sets\primary_production: %s', e.message);
        end
        
        progress(control, 'read net primary production data (NPP)', 1, 0, [], '')
    else
        progress(control, 'read net primary production data (NPP)', -1) 
    end
    
    
%%
%
% Apply sound speed and absorption corrections to the data set.
%
    if control.sound_speed & ~isempty(sample_data)
        progress(control, 'apply secondary corrections for sound speed & absorption', [], 0, [],'processing')
        % ##        
        sample_data = correct_sound_speed(sample_data, control.soundspeed_formula, control.soundabsorption_formula);
        progress(control, 'apply secondary corrections for sound speed & absorption', 1, 0, [], '')
    else
        progress(control, 'apply secondary corrections for sound speed & absorption', -1)
    end

%%
% Earlier, extract indices calculation was executing before manual data cleaning.
% Ideally, it should happen after manual data cleaning. And indices calculation should use Sv data after manual cleaning.
% The function Zap has been placed here
%
% allow user to manually reject data
    if control.zap & ~isempty(sample_data)
        progress(control, 'manual data cleaning', [], 0, [],'processing')
        sample_data = zap(sample_data);
        progress(control, 'manual data cleaning', 1, 0, [], '')
    else
       progress(control, 'manual data cleaning', -1) 
    end
%%
%
% Extract indices
%

    if control.layer_indices && ~isempty(sample_data)
        
        progress(control, 'calculate summary metrics (epipelagic, upper mesopelagic, lower mesopelagic & diurnal sun cycle)', [], 0, [],'processing')
       
        depth_data = sample_data.dimensions{depth_d}.data;
        
        % find sv and layer variables
        layer_v = zeros(size(control.layername));
        day_v = [];
        sv_v = [];
        
        for i = 1:length(sample_data.variables)
            for j = 1:length(layer_v)
                if strcmpi(sample_data.variables{i}.name, control.layername{j})
                    layer_v(j) = i;
                end
            end
            if strcmp(sample_data.variables{i}.name, 'Sv')
                sv_v = i;
            end
            if strcmp(sample_data.variables{i}.name, 'Sv_38') && isempty(sv_v)
                sv_v = i;
            end
            if strcmp(sample_data.variables{i}.name, 'LATITUDE')
                lat_v = i;
            end
            if strcmp(sample_data.variables{i}.name, 'LONGITUDE')
                lon_v = i;
            end
            if strcmp(sample_data.variables{i}.name, 'day')
                day_v = i;
            end
        end
        
        % populate summary layers
        % 2019 07 30 GJK remove values with too few pixels.
        for i = 1:length(layer_v)
            if layer_v(i) == 0
                layer_v(i) = length(sample_data.variables) + 1;
            end
            inrange = control.layers(i,1) < depth_data & depth_data < control.layers(i, 2);
            sample_data.variables{layer_v(i)}.name = control.layername{i};
%  Haris 13 Septemebr 2019. Comment try catch lines. This is failing
%  because data is not created so far and the code is asking to create
%  'flag' based on the size of data. This should happen after creating the
%  data. Therfore, placing flag calculation inside the following 'if else
%  end' statement (single+multi-freq data). Gordon implemented flagging of
%  summary metrics on 2019 07 30 and wasn't tested.
% % %             try
% % %                sample_data.variables{layer_v(i)}.flags = ones(size(sample_data.variables{layer_v(i)}.data)) * 2;
% % %             catch
% % %                keyboard
% % %             end

            if isempty(channel_d)
                sample_data.variables{layer_v(i)}.dimensions = time_d;
                sample_data.variables{layer_v(i)}.data = 10*log10(nanmean(sample_data.variables{sv_v}.data(:,inrange),2));
                sample_data.variables{layer_v(i)}.flags = ones(size(sample_data.variables{layer_v(i)}.data)) * 2;
                count_cells = sum(~isnan(sample_data.variables{sv_v}.data(:,inrange)),2);
                sample_data.variables{layer_v(i)}.data(count_cells < control.min_layer_cells) = NaN;
                sample_data.variables{layer_v(i)}.flags(count_cells < control.min_layer_cells) = 3;
            else
                sample_data.variables{layer_v(i)}.dimensions = [time_d channel_d];
                for c = 1:length(sample_data.dimensions{channel_d}.data)
                    sample_data.variables{layer_v(i)}.data(:,c) = ...
                        10*log10(nanmean(sample_data.variables{sv_v}.data(:,inrange,c),2));
                    sample_data.variables{layer_v(i)}.flags(:,c) = ones(size(sample_data.variables{layer_v(i)}.data(:,c))) * 2; 
                    count_cells = sum(~isnan(sample_data.variables{sv_v}.data(:,inrange,c)),2);
                    sample_data.variables{layer_v(i)}.data(count_cells < control.min_layer_cells, c) = NaN;
                    sample_data.variables{layer_v(i)}.flags(count_cells < control.min_layer_cells, c) = 3;
                end
            end
% % % 			sample_data.variables{layer_v(i)}.flags = ones(size(sample_data.variables{layer_v(i)}.data)) * 2;      
        end
        
        if isempty(day_v)
            dsrn = 'DSRN'; %#ok<NASGU>
            day_v = length(sample_data.variables) + 1;
            
            time = sample_data.dimensions{time_d}.data;
            latitude = sample_data.variables{lat_v}.data;
            longitude = sample_data.variables{lon_v}.data;
            intervals=length(time);
            period=zeros(intervals,1);
            
            % determine time of day for each interval
            % within an hour of sunrise is R
            % within an hour of sunset is S
            % day is D
            % night is N
            
            for i=1:intervals;
                rs = suncycle(latitude(i), longitude(i), time(i));
                hour = mod(time(i),1) * 24;
                diff = abs(hour - rs);
                if diff(1) < 1 || diff(1) > 23
                    period(i) = 3;
                elseif diff(2) < 1 || diff (2) > 23
                    period(i) = 2;
                elseif rs(1) < rs(2)
                    if hour < rs(1) || hour > rs(2)
                        period(i) = 4;
                    else
                        period(i) = 1;
                    end
                else
                    if hour < rs(2) || hour > rs(1)
                        period(i) = 1;
                    else
                        period(i) = 4;
                    end
                end
            end
            sample_data.variables{day_v}.name = 'day';
            sample_data.variables{day_v}.dimensions = time_d;
%           sample_data.variables{day_v}.units = '1 - Day, 2 - Sunset +/- 1 hr, 3 - Sunrise +/- 1 hr, 4 - Night';
% The unit is defined in the 'imosParameters.txt' available in IMOS
% toolbox. Haris 06 June 2018
            sample_data.variables{day_v}.data = period;
            sample_data.variables{day_v}.flags = zeros(size(period));
        end
        
       progress(control, 'calculate summary metrics (epipelagic, upper mesopelagic, lower mesopelagic & diurnal sun cycle)', 1, 0, [], '')
    else
       progress(control, 'calculate summary metrics (epipelagic, upper mesopelagic, lower mesopelagic & diurnal sun cycle)', -1) 
    end
    
%%
%
% Final user edit of metadata
% Automatically populated fields have values.
%

    if ~isempty(sample_data)        
        if ~strcmp(pwd,imos_path) && exist(imos_path,'dir')
            cd(imos_path);
        end         
        
        sample_data = finaliseData(sample_data, ev_files,0,sample_data.toolbox_version);
        % remove FillValues_ for cell data
        for k=1:length(sample_data.dimensions)
            if iscell(sample_data.dimensions{k}.data) && isfield(sample_data.dimensions{k}, 'FillValue_')
                sample_data.dimensions{k} = rmfield(sample_data.dimensions{k}, 'FillValue_');
            end
        end
        for k=1:length(sample_data.variables)
            if iscell(sample_data.variables{k}.data) && isfield(sample_data.variables{k}, 'FillValue_')
                sample_data.variables{k} = rmfield(sample_data.variables{k}, 'FillValue_');
            end
        end
        
        % remove channel attributes from global attributes
        if isfield(sample_data.meta, 'channels')
            chanAtts = fieldnames(sample_data.meta.channels);
            for f = 1:length(chanAtts)
                if isfield(sample_data, chanAtts{f})
                    if length(sample_data.meta.channels) == 1 && ...
                            ~isempty(sample_data.(chanAtts{f})) && ...
                            (isempty(sample_data.meta.channels.(chanAtts{f})) || ...
                            control.update_platform)
                        sample_data.meta.channels.(chanAtts{f}) = sample_data.(chanAtts{f});
                    end
                    sample_data = rmfield(sample_data, chanAtts{f});
                end
            end
        end
        
        % duplicate ICES fields from IMOS values
        sample_data.northlimit = sample_data.geospatial_lat_max;
        sample_data.southlimit = sample_data.geospatial_lat_min;
        sample_data.eastlimit = sample_data.geospatial_lon_max;
        sample_data.westlimit = sample_data.geospatial_lon_min;
        sample_data.units = 'signed decimal degrees';
        sample_data.uplimit = sample_data.geospatial_vertical_min;
        sample_data.downlimit = sample_data.geospatial_vertical_max;
        sample_data.zunits = 'm';
        % To add ICES transect attributes- Haris 05 June 2018
        sample_data.transect_start_time = datestr(sample_data.time_coverage_start,'yyyy-mm-ddTHH:MM:SSZ');
        sample_data.transect_end_time = datestr(sample_data.time_coverage_end,'yyyy-mm-ddTHH:MM:SSZ');
        sample_data.transect_westlimit = sample_data.geospatial_lon_min;
        sample_data.transect_eastlimit = sample_data.geospatial_lon_max;
        sample_data.transect_southlimit = sample_data.geospatial_lat_min;
        sample_data.transect_northlimit = sample_data.geospatial_lat_max;
    end   
    
% Haris 25/06/2019 to automatically populate metadata fields.
% Specifically author information, motion correction, and calibration date for multi-frequency data.
% Tim 30-06-2019. Tim put Haris's code in if statement so that this only
% happens i sample_data is not empty. 
    if ~isempty(sample_data)
        name_a = sample_data.data_processing_by(1:3); % reading ID of analyst, note Ryan's name is predefined    
        if isequal(name_a,'kun') | isequal(name_a,'Kun') % Haris
            sample_data.author = 'Haris Kunnath';
            sample_data.author_email = 'Haris.Kunnath@csiro.au';
            sample_data.creator = 'Haris Kunnath';
            sample_data.contributor = 'Haris Kunnath';    
        elseif isequal(name_a,'nau') | isequal(name_a,'Nau') % Amy
            sample_data.author = 'Amy Nau';
            sample_data.author_email = 'Amy.Nau@csiro.au';
            sample_data.creator = 'Amy Nau';
            sample_data.contributor = 'Amy Nau'; 
        elseif isequal(name_a,'rya') | isequal(name_a,'Rya') % Tim
            sample_data.author = 'Tim Ryan';
            sample_data.author_email = 'Tim.Ryan@csiro.au';
            sample_data.creator = 'Tim Ryan';
            sample_data.contributor = 'Tim Ryan';
        elseif isequal(name_a,'boy') | isequal(name_a,'Boy') % Matt
            sample_data.author = 'Matt Boyd';
            sample_data.author_email = 'Matt.Boyd@csiro.au';
            sample_data.creator = 'Matt Boyd';
            sample_data.contributor = 'Matt Boyd';
        elseif isequal(name_a,'klo') | isequal(name_a,'Klo') % Rudy
            sample_data.author = 'Rudy Kloser';
            sample_data.author_email = 'Rudy.Kloser@csiro.au';
            sample_data.creator = 'Rudy Kloser';
            sample_data.contributor = 'Rudy Kloser';
        elseif isequal(name_a,'dow') | isequal(name_a,'Dow') % Ryan, defined in text file do nothing
        else
            keyboard
            % New Analyst, try to add details and proceed. Note metadata is the
            % data of data, very important stuff.
        end

        if isequal(sample_data.data_processing_motion_correction,'Yes') % only if applied otherwise it should not be there
            sample_data.data_processing_motion_correction_description = 'Dunford, A. J. 2005. Correcting echo-integration data for transducer motion. The Journal of the Acoustical Society of America, 118: 2121-2123.';
        end

        if length(sample_data.meta.channels)>1 & ~control.read_netcdf % It was overwriting cal date if NetCDF is provided
            for h = 1:length(sample_data.meta.channels)
                sample_data.meta.channels(h).calibration_date = save_control.meta.calibration_date;
            end
        end
    end
% Haris correction on 25/06/2019 ends here.
    
    if control.review_priority_metadata
        progress(control, 'review priority metadata', [], 0, [],'processing')
        % ##
        sample_metadata = struct();
        if exist(fullfile(root_path, control.priority_metadata), 'file') == 2
            sample_metadata = parseNetCDFTemplate(fullfile(root_path, control.priority_metadata), sample_data);
        elseif exist(control.priority_metadata, 'file') == 2
            sample_metadata = parseNetCDFTemplate(control.priority_metadata, sample_data);        
        elseif exist(fullfile(root_path, control.priority_metadata), 'file') == 7
            mf = dir(fullfile(control.priority_metadata, '*.txt'));
            for i = 1:length(mf)
                sample_metadata = parseNetCDFTemplate(fullfile(control.priority_metadata, mf(i).name), sample_data);
            end
        end
               
        fields = fieldnames(sample_metadata);
        for c=1:length(sample_data.meta.channels)
            sample_metadata.meta.channels(c).name = sample_data.meta.channels(c).name;
        end
        for f = 1:length(fields)
            if isfield(sample_data, fields{f}) && ~isempty(sample_data.(fields{f})) && ...
                    (isempty(sample_metadata.(fields{f})) || sample_data.(fields{f})(1) ~= '(' || sample_data.(fields{f})(end) ~= ')')
                sample_metadata.(fields{f}) = sample_data.(fields{f});
            end
            if isfield(sample_data.meta.channels, fields{f})
                for c=1:length(sample_data.meta.channels)
                    sample_metadata.meta.channels(c).(fields{f}) = sample_data.meta.channels(c).(fields{f});
                end
                sample_metadata = rmfield(sample_metadata, fields{f});
            end
        end       
        
        % add fields review_metadata expects to remove
        sample_metadata.variables = [];
        sample_metadata.dimensions = [];
        
        sample_metadata = review_metadata(sample_metadata);
        
        fields = fieldnames(sample_metadata.meta.channels);
        for f = 1:length(fields)
            for c=1:length(sample_data.meta.channels)
                sample_data.meta.channels(c).(fields{f}) = sample_metadata.meta.channels(c).(fields{f});
            end
        end
        
        sample_metadata = rmfield(sample_metadata, 'meta');
        sample_metadata = rmfield(sample_metadata, 'variables');
        sample_metadata = rmfield(sample_metadata, 'dimensions');
        
        fields = fieldnames(sample_metadata);
        for f = 1:length(fields)
            sample_data.(fields{f}) = sample_metadata.(fields{f});
        end
        
        if isfield(sample_data, 'ship_name')
            sample_data.meta.site_name = sample_data.ship_name;
            sample_data.meta.site_id = sample_data.ship_name;
        end
        progress(control, 'review priority metadata', 1, 0, [], '')
    else
        progress(control, 'review priority metadata', -1)
    end
    
    if control.review_metadata
        progress(control, 'review all metadata', [], 0, [],'processing')
        % ##
        sample_data = review_metadata(sample_data);
        if isfield(sample_data, 'ship_name')
            sample_data.meta.site_name = sample_data.ship_name;
            sample_data.meta.site_id = sample_data.ship_name;
        end
        sample_data = finaliseData(sample_data, ev_files,0,sample_data.toolbox_version);
        progress(control, 'review all metadata', 1, 0, [], '')
    else
        progress(control, 'review all metadata', -1)
    end
    
%%        
%
% drop to matlab command prompt to allow review of data
%
    if control.matlab_view
        progress(control, 'review sample data in Matlab workspace', [], 0, [],'processing')
        fprintf('Review sample_data\ntype return to continue\n');
        keyboard
        progress(control, 'review sample data in Matlab workspace', 1, 0, [], '')
    else
        progress(control, 'review sample data in Matlab workspace', -1)
    end
    
    
    control.sample_data = sample_data;
    
%%
%
% Write IMOS format NetCDF file.
%
    if control.netcdf    

        if isempty(sample_data)
            error('No data to save to NetCDF');
        end
        if ~control.alt_netcdf || isempty(control.netcdf_directory) 
            if control.read_netcdf
                control.netcdf_directory = fileparts(control.netcdf_file);
            else
                control.netcdf_directory = Process_output_root_path;
            end
        end
        
        progress(control, 'export NetCDF to', [], 0, [], control.netcdf_directory)
        
        % Convert channel attributes to variables
        if control.single_format && length(control.channel) == 1
            if isfield(sample_data.meta, 'channels')
                if isfield(sample_data.meta.channels,'name')
                    sample_data.meta.channels = rmfield(sample_data.meta.channels,'name');
                end
                fields = fieldnames(sample_data.meta.channels);
                for f = 1:length(fields)
                    sample_data.(fields{f}) = sample_data.meta.channels.(fields{f});
                end              
                sample_data.meta = rmfield(sample_data.meta, 'channels');
            end
%             sample_data.Conventions = 'CF-1.6,IMOS-1.3,ICES_SISP_3-1.00,SOOPBA-2.0';
            sample_data.Conventions = 'CF-1.6,IMOS-1.4,ICES_SISP_4-1.10,SOOP-BA-2.3'; % if updating change the same field for multi-frequency provided at the end of 'if' statement
        else
            if isfield(sample_data.meta, 'channels')
                fields = fieldnames(sample_data.meta.channels);
                vars = length(sample_data.variables);
                                
                x=0;
                for f = 1:length(fields)
                    cdata = {sample_data.meta.channels(:).(fields{f})};
                    cchar = any(cellfun(@ischar,cdata));
                    cempty = cellfun(@isempty,cdata);
                    if ~all(cempty) % we have some data
                        x=x+1;
                        sample_data.variables{vars+x}.name = fields{f};
                        sample_data.variables{vars+x}.dimensions = channel_d;
                        if any(cempty)
                            if cchar
                                cdata(cempty) = {''};
                            else
                                cdata(cempty) = {nan};
                            end
                        end
                        if ~cchar
                            try
                                cdata = [cdata{:}];
                            catch 
                                warning('BASOOP:bad_channel_metadata', 'Error in metadata for field %s ', fields{f})
                            end
                            sample_data.variables{vars+x}.FillValue_ = -99999;
                        end
                        
                        sample_data.variables{vars+x}.data = cdata;
                    end
                end
            end
%             sample_data.Conventions = 'CF-1.6,IMOS-1.3,ICES_SISP_3-1.00,SOOPBA-2.1';
            sample_data.Conventions = 'CF-1.6,IMOS-1.4,ICES_SISP_4-1.10,SOOP-BA-2.3';
        end
        
        % remove fields starting with '(' and ending with ')', these are
        % used to pass comments to the user.
        fields = fieldnames(sample_data);
        for f = 1:length(fields)
            if ~isempty(sample_data.(fields{f})) && ischar(sample_data.(fields{f})) && ...
                    sample_data.(fields{f})(1) == '('  && sample_data.(fields{f})(end) == ')';
                sample_data.(fields{f}) = [];
            end
        end
        
        % genIMOSFileName will keep most of the existing file name if it
        % finds it
        if ~control.preserve_ncfilename && isfield(sample_data.meta, 'file_name')
            sample_data.meta = rmfield(sample_data.meta, 'file_name');
        end
        
        if ispc && length(control.netcdf_directory) > 128
            warning('BASOOP:LONG_FILENAME', 'Directory path is long %d characters, filename may be too long', length(control.netcdf_directory));
        end
        
        % Haris 16 July 2019 - move existing files to a new folder
        % 'previous_NetCDF'. It is confusing to see many NetCDFs in the
        % processed data folder. It is likely to pick old NetCDF for
        % packaging. To avoid this confusion moving pre-exisiting NetCDF
        % and related files to the folder 'previous_NetCDF'.
        dir_info = dir(control.netcdf_directory);
        file_flag = ~[dir_info.isdir];
        file_name = dir_info(file_flag);
        
        if ~isempty(file_name) && ~exist([control.netcdf_directory '\previous_NetCDF'], 'dir')
            mkdir([control.netcdf_directory '\previous_NetCDF']);
        end
        if ~isempty(file_name)
            for i = 1: numel(file_name)
                movefile(fullfile(file_name(i).folder,file_name(i).name),[control.netcdf_directory '\previous_NetCDF']);
            end
        end
        % Haris correction on 16 July 2019 ends here.
              
        try
        % ##                
        
        ncfile = exportNetCDF(sample_data, control.netcdf_directory, 'timeSeries');
       
        control.netcdf_output = ncfile;
        catch exception
            ncfile = fullfile(control.netcdf_directory, genIMOSFileName(sample_data, 'nc'));
            if ispc && length(ncfile) > 255
                msgbox({'You are reading this message because the GUI automatically generated'
                    'filepath has exceeded the windows limit of 260 characters.' ; ''
                    'A workaround is to check the "to" box and specify a shorter directory path'
                    'then manually move the netcdf to the right location' ; ''
                    'program will have crashed!'})
                error('Filename too long (%d characters): %s', length(ncfile), ncfile)
            end
            rethrow(exception)
        end        

        viz_sv(ncfile,'','inf','noplot'); % Haris 16 July 2019 - make create image file as a mandatory step when export NetCDF is done
        
        progress(control, 'export NetCDF', 1, 0, [], ncfile)       
        
        % Run NetCDF checker 
        
        progress(control, 'checking NetCDF metadata compliance', [], 0, [],'processing')      
               
        netcdf_checker(ncfile); % run netcdf checker to see if file is BASOOP 2.3 compliant. Added 05-June-2018
        
        progress(control, 'checking NetCDF metadata compliance', 1, 0, [], '')
        
        % Generate EV file to view NetCDF data
        
        try
            progress(control, 'process to view NetCDF in Echoview', [], 0, [],'processing') % start progress message
            
            nc2ev(ncfile);
            
            progress(control, 'process to view NetCDF in Echoview', 1, 0, [], '') % end progress message
        catch
            progress(control, 'process to view NetCDF in Echoview', -1) % skipped or failed progress message
%             fprintf('Process to generate ev file to view netCDF data failed\n');
        end
        
        % Haris 11 July 2019 - copied message box from netcdf_checker and
        % placed here as it confuse user with other message from nc2ev
        messages = ['\n============ Switch to Matlab Command Window =============\n',...
                    '==== Check the section "checking NetCDF metadata compliance" ===\n\n',...
             '(1)  If you see messages about global attributes, repackage NetCDF defining that.\n\n',... 
             '(2)  If you see messages about variable attributes, most likely that variable is not written to the file!! check what is happening.\n\n',... 
             '(3)  If NPP variable is missing, check NPP data folder "Q > Generic_data_sets > primary_production".\n\n',...
             '(4)  If not solving, check "imosParameters.txt" file located in the IMOS toolbox, but edit with caution.\n\n',...
            '====================================================\n'];                
        h = msgbox(sprintf(messages),'Results of NetCDF checker');
        set(h, 'position', [100 100 410 330]); %makes box bigger
        ah = get( h, 'CurrentAxes' );
        ch = get( ah, 'Children' );
        set( ch, 'FontSize', 12); %makes text bigger
        uiwait(h)
    else
        control.netcdf_output = [];
        progress(control, 'export NetCDF', -1)
    end
    

    % finished with IMOS-toolbox
%     cd (basoop_dir)
    cd ..
    
    % Haris - 13 August 2019. Above cd (basoop_dir) is taking user to IMOS
    % toolbox. Commenting not to deal with IMOS toolbox folder.
    % process_BASOOP now takes user to the folder 'echoview_ascii' putting
    % 'cd ..' to take back to the folder where NetCDF is created.
    
    %%
    %
    % visualize echograms and create .png of  from netcdf file.
    %
    if control.viz
        progress(control, 'visualise NetCDF', [], 0, [], ncfile)

%         data = viz_sv(ncfile,'','sun','depth',0,'inf'); % Haris 16 July 2019 - do not create image file it is already created in the export NetCDF stage.
        viz_sv(ncfile);
        
% Haris 05 July 2019 - commented below parts, because viz_sv now provides
% below figures and I think it is not needed to repeat here. The screen is
% getting busy with same figures.
        
        % Sv v depth
%         for c = 1:length(data.channels)
%             figure
%             hold on
%             set(gca,'YDir','reverse');
%             color='gcybb';
%             phase = [ 2 3 1 4 0 ];
%             for p = 1:length(phase)
%             if any(data.day == phase(p))
%                 plot(data.Sv(:,data.day == phase(p),c),data.depth,color(p));
%             end
%             end
%             title({ data.file ; ['Sv summary ' data.channels{c}]  }, 'Interpreter', 'none');
%             xlabel('Sv (dB)');
%             ylabel('Depth (m)');
%         end
%         
%         if isfield(data, 'signal_noise');
%             for c = 1:length(data.channels)
%                 viz_sv(data,data.signal_noise, 'channel', c, ...
%                     'title', ['Signal to noise ' data.channels{c} ' (dB)'], ...
%                     'range', [-50 50], 'cmap', jet(100))
%              end
%         end
%         
%         if isfield(data, 'background_noise');
%             figure
%             plot(data.background_noise);
%             title({ data.file ; ['Backgound noise level ' data.channels{c} ' (dB)']}, 'Interpreter', 'none');
%             xlabel('Interval');
%             ylabel('Noise level (dB)');
%         end
        
        progress(control, 'visualise NetCDF', 1, 0, [], '')
    else
        progress(control, 'visualise NetCDF', -1)
    end
    
    %%
    %
    % visualize echograms and create .png of  from netcdf file.
    %
    if control.png || (control.make_imos && exist([ncfile '.png'], 'file') ~=2)
        % ##
        data = viz_sv(ncfile,'','noplots','depth',0);
        % also plot individual channels
        if length(control.channel) > 1
            for i=1:length(control.channel)
                viz_sv(data,data.Sv,'noplots','image','', 'title', 'Sv mean (dB re 1 m-1)', ...
                    'channel',i,'range',[],'depth',0);
            end
        end
    end
    
    %%
    % 
    % build a zip file for IMOS upload
    %
    if control.make_imos
        
        % determine IMOS directory (vessel/transect)
        % Copy netcdf and png files to imos directory, 
        % copy raw files to imos/raw directory
        % create .zip file containing .nc .png and raw/*.raw
        paths = regexp(Process_output_root_path, filesep, 'split');
        if length(paths) > 3
            imos_dir = fullfile(control.imos_directory, paths{end-2}, paths{end-1});
        else
            warning('BASOOP:SHORT_PATH', 'Vessel and transect not found in path %s', Process_output_root_path)
            imos_dir = fullfile(control.imos_directory, 'unknown');
        end
        imos_raw_dir = fullfile(imos_dir, 'Raw');
        
        progress(control, 'generate zip file for IMOS upload', [], 0, [], ['Copying Raw files to ' imos_raw_dir])
        
        if exist(imos_raw_dir, 'dir') ~= 7
            mkdir(imos_dir, 'Raw');
        end
        [nc_dir, nc_name] = fileparts(ncfile);
        if ~strcmp(nc_dir, imos_dir)
            copyfile(ncfile, imos_dir);
            copyfile([ncfile '.png'], imos_dir);
        end
        
        if control.raw_echoview && ~isempty(ev_d)
            evfilelist = sample_data.dimensions{ev_d}.data;
            EvApp = getEvApp(EvApp, control.EvApp);
            EvApp.Minimize;
            for f = 1:length(evfilelist)
                if ~exist(evfilelist{f}, 'file') == 2
                    error('BASOOP:NO_EV', 'Cannot find EV file %s\n referenced in netcdf file %s', ...
                        evfilelist{f}, ncfile) 
                end
                
                EvFile = EvApp.OpenFile(evfilelist{f});
                
                if isempty(EvFile)
                    error('Unable to open EV file %s', evfilelist{f});
                end
                
                for s = 0:EvFile.Filesets.Count - 1
                    Fileset = EvFile.Filesets.Item(s);
                    filecount = Fileset.DataFiles.Count;
                    for d = 0:filecount - 1;
                        FileName = Fileset.DataFiles.Item(d).FileName;
                        [~, fname, ext] = fileparts(FileName);
                        if ~strcmpi(ext, '.hac') && exist(FileName, 'file') == 2 ...
                                && exist(fullfile(imos_raw_dir, [fname ext]), 'file') == 0
                            if control.verbosity > 1
                                progress(control, 'generate zip file for IMOS upload', d, filecount, [], ['Copying ' FileName])
                            end
                            try
                                copyfile(FileName, imos_raw_dir);
                            catch exception
                                warning('BASOOP:COPY_RAW', 'Unable to copy %s\n%s', FileName, exception.message)
                                if exist(fullfile(imos_raw_dir, [fname ext]), 'file') == 7
                                    delete(fullfile(imos_raw_dir, [fname ext]), 'file');
                                    try
                                        copyfile(FileName, imos_raw_dir);
                                    catch
                                    end
                                end
                            end
                        end
                    end
                end
                EvFile.Close();
            end
        end
        
        if control.raw_datalist
            for i = 1:length(control.transit_data_files)
                tdf = control.transit_data_files{i};
                if ~isempty(tdf)
                    fid = fopen(tdf);
                    if fid > 0
                        line = fgetl(fid);
                        while ischar(line);
                            line(line == '\') = filesep;
                            [~, fname, ext] = fileparts(line);
                            if exist(line, 'file') == 2 && exist(fullfile(imos_raw_dir, [fname ext]), 'file') == 0
                                copyfile(line, imos_raw_dir);
                            end
                            line = fgetl(fid);
                        end
                    else
                        warning('BASOOP:OPEN_TDF', 'Unable to open file list %s\n', tdf);
                    end
                    fclose(fid);
                end
            end
        end
        
        % Haris 20-04-2020. Need to keep unique file name for all ancillary
        % files (*.gps.csv, *.pitch.csv, and *.roll.csv). Earlier these
        % ancillary files had inconsistent file names created by analyst
        % during processing. Now unique NetCDF file name is given for all
        % ancillary files to help manage data in the AODN portal.
        
        csv_files = dir(fullfile(imos_raw_dir, '*.csv'));
        
        for i = 1:length(csv_files)
            csv_names = split(csv_files(i).name,'.');
            csv_names_new = char(strcat(ncfname,'.',csv_names(end-1),'.',csv_names(end))); % Assume two dots exist in original file like *.gps.csv
            movefile(fullfile(imos_raw_dir, csv_files(i).name), fullfile(imos_raw_dir, csv_names_new));
        end
        % Haris 20-04-2020 corrections end here.
        
        zipfile = fullfile(imos_dir,[nc_name '.zip']);
        progress(control, 'generate zip file for IMOS upload', [], 0, [], ['Zipping ' zipfile])
        % ##
        if exist(imos_raw_dir, 'dir') == 7
            if isempty(control.zip_command)
                zip(zipfile, {[nc_name '.nc']; [nc_name '.nc.png']; imos_raw_dir}, imos_dir);
                
                progress(control, 'generate zip file for IMOS upload', [], 0, [], 'Clean up')
                rmdir(imos_raw_dir, 's');
            else
                wdir = cd(imos_dir);
                if system([control.zip_command ' ' zipfile ' ' nc_name '.nc ' nc_name '.nc.png Raw']);
                    warning('BASOOP:ZIP', 'Zip command %s failed.', control.zip_command)
                else
                    progress(control, 'generate zip file for IMOS upload', [], 0, [], 'Clean up')
                    rmdir(imos_raw_dir, 's');
                end
                cd(wdir);
            end
            
            progress(control, 'generate zip file for IMOS upload', [], 0, [], zipfile)
        else
            if isempty(control.zip_command)
                zip(zipfile, {[nc_name '.nc']; [nc_name '.nc.png']}, imos_dir);
            else
                wdir = cd(imos_dir);
                if system([system.zip_command zipfile ' ' nc_name '.nc ' nc_name '.nc.png'])
                    warning('BASOOP:ZIP', 'Zip command %s failed.', system.zip_command)
                end
                cd(wdir);
            end
        end
        progress(control, 'generate zip file for IMOS upload', 1, 0, [], '')
        
    else 
        zipfile = '';
        progress(control, 'generate zip file for IMOS upload', -1)
    end
    
    %%
    %
    % upload file to aodn ftp server
    %
    
    if control.imos_upload
        if isempty(zipfile)
            paths = regexp(Process_output_root_path, filesep, 'split');
            if length(paths) > 3
                imos_dir = fullfile(control.imos_directory, paths{end-2}, paths{end-1});
            else
                imos_dir = control.imos_directory;
            end
            [~, nc_name] = fileparts(ncfile);
            zipfile = fullfile(imos_dir,[nc_name '.zip']);
        end
        
        if exist(zipfile, 'file') ~= 2
            error('Can not find file to upload %s', zipfile);
        end
        
        upload_user = control.upload_user;
        upload_password = control.upload_password;
        if isempty(upload_password) || isempty(upload_user)
            progress(control, 'upload zip file to AODN portal', [], 0, [], 'FTP loggin ')
            answer = inputdlg({'AODN user name:' ; 'Password'}, ['Login details for ' control.upload_site], 1, {control.upload_user, ''});
            if isempty(answer)
                error('FTP user name and password required for upload');
            end
            upload_user = answer{1};
            upload_password = answer{2};
        end
        
        ft = [];
        while isempty(ft)
            try
                ft = ftp(control.upload_site, upload_user, upload_password);
            catch exception
                warning('BASOOP:FTP', 'FTP upload failed: %s\n', exception.message)
                answer = inputdlg({'AODN user name:' ; 'Password'}, ['Login details for ' control.upload_site], 1, {control.upload_user, ''});
                if isempty(answer)
                    error('FTP user name and password required for upload');
                end
                upload_user = answer{1};
                upload_password = answer{2};                
            end
        end
        
        try
            binary(ft);
            if ~isempty(control.upload_dir)
                cd(ft, control.upload_dir);
            end
            progress(control, 'upload zip file to AODN portal', [], 0, [], ['FTP upload ' zipfile])            
            mput(ft, zipfile);
            close(ft)
        catch exception
            close(ft)
            error('FTP upload failed: %s\n', exception.message)
        end
        
        progress(control, 'upload zip file to AODN portal', 1, 0, [], '')
    else
        progress(control, 'upload zip file to AODN portal', -1)
    end
    
    
    %%
    %
    % All done!
    %
    % report time taken.
    
% Haris 04 July 2019 'EvApp' is already closed? and no active Echoview
% window. Note Echoview window for reading calibration metadata is closed
% already.

%     if ~isempty(EvApp)
%         EvApp.Quit;
%     end
%     
    control.telapsed = toc(control.tstart);
    
    fprintf('Program completed in: %.1f minutes = %.1f hours\n', (control.telapsed)/60, (control.telapsed)/3600);
    warning('on','all') % enable usual warning message. Backtrace was set to off in the first line
    
    
    
function progress(control, section, i, n, start, message)
% Outputs progress messages to the command prompt and possibly GUI.
%
% Inputs:
%   control     structure containing fields:
%       progress    function to call having the same parameters as this.
%                   May be empty. May be a function that interacts with a
%                   GUI
%   section     name of section being processed, may relate to GUI tags
%   i           current step
%   n           number of steps
%   start       tic at start of process
%   message     text message to display
%
%   if i is empty ignore i and n
%   if i < 0 section is 'skipped'
%   if i > n section is 'completed'
%   if start is not empty and 0<= i <= n display elapsed time
%

if nargin < 2;      section = '';       end
if nargin < 3;      i = [];             end
if nargin < 4;      n = [];             end
if nargin < 5;      start = [];         end
if nargin < 6;      message = [];       end

if control.verbosity > 0
    if isempty(i)
        fprintf('%s: %s %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), section, message);
    elseif i < 0
        fprintf('%s: %s skipped\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), section);
    elseif i <= n
        if control.verbosity > 1
            if isempty(start)
                fprintf('%s: %s processing %d/%d %s\n', ...
                    datestr(now, 'yyyy-mm-dd HH:MM:SS'), section, i, n, message);
            else
                fprintf('%s: %s processing %d/%d elapsed: %s %s\n', ...
                    datestr(now, 'yyyy-mm-dd HH:MM:SS'), section, i, n, ...
                    datestr(toc(start)/86400, 'HH:MM:SS'), message)
            end
        end
    else
        fprintf('%s: %s completed\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), section);
    end
end

if isfield(control, 'progress') && ~isempty(control.progress)
    control.progress(section, start, i, n, message)
end


function EvApp = getEvApp(EvApp, echoview)
% Returns a handle to a COM object of an EchoviewApplication.
%
% If the input EvApp is empty new ActiveX server is created, otherwise it
% is reused.
%
% echoview is the active X command to run echoview
% 'EchoviewCom.EvApplication'

if isempty(EvApp)
    try
        EvApp = actxserver(echoview);
        nopen = EvApp.EvFiles.Count;
        if nopen > 0
            error('EchoView already open');
        end
    catch e
        EvApp = [];
        fprintf('Couldn''t create ActiveX server for echoview\n%s\n', e.message);
    end
end

function output_path = getOutputPath(processed_directory, first_file, last_file, template)
% determine the directory to use as the base for outputting results based
% on the first and last file of the dataset.
%
% Inputs:
%   processed_directory - usually 'Q:\processed_data\'
%   first_file - path of the first .raw file to be included assumed to be
%               Q:\Rawdata\vessel\survey\Ddate-Ttime.raw
%   last_file - path of the last .raw file to be included
%
% Outputs:
%   output_path = processed_directory\vessel\survey\start-end\
%   where vessel, survey, start and end are derived from the path of the
%   first_file and last_file.
    
    [~,tname,~] = fileparts(template);
    
    first_file(first_file == '\') = '/';
    delimiters = strfind(first_file, '/');
    
    if isempty(delimiters)
        error('Can not find directory of file to process: %s\n', first_file)
    end
        
    if length(delimiters) < 3
        warning('BASOOP:BAD_PATH', 'Unable to find vessel and survey in path\nExpected: %s\nGot:      %s\n', ...
            'Q:\Rawdata\Vessel\Survey\file.raw', first_file);
        output_path = 'Could not determine vessel and survey';   % Not an error if result is never used
        return
    end
    
    try
        first_date = '';
        last_date = '';
        first_date = simrad_date_string(first_file);
        last_date = simrad_date_string(last_file);
    catch e     %#ok<NASGU>
    end
    
    output_path = ...
        fullfile(processed_directory, ...                               % Q:\Processed_data
        first_file(delimiters(end-2) + 1:delimiters(end-1) - 1), ...  % vessel
        first_file(delimiters(end-1) + 1:delimiters(end) - 1), ...  % survey
        [first_date '-' last_date],...                                  % Date time range
        tname);                                                         % template name

function Process_output_root_path = getOutputRoot(control)
% Determine the root directory for outputing files
%

if control.use_alt_ev_files
    fid = fopen(control.alt_ev_files);
    fname = fgetl(fid);
    fclose(fid);
    Process_output_root_path = fileparts(fileparts(fname));
else
    [~, Process_output_root_path] = getFileSets(control);
end
        
function [file_sets, Process_output_root_path] = getFileSets(control)
% Determine the location and break up of ev files.
%
% Inputs - a structure containing:
%   control.transit_data_files  Cell array of names of files containing 
%                               lists of data files (ES60 .raw or .ek5)
%   control.time_block          Number of hours for each file set
%   control.processed_directory Name of directory for processed data,
%                               usually 'Q:\processed_data\'
%   control.template            Name of the template used to create
%                               worksheets
%
% Outputs:
%   file_sets                   cell array of cell array of filenames
%   Process_output_root_path    Directory used as the base for processing
%                               this data set.
%
% 

    if exist(control.transit_data_files{1}, 'dir') == 7
        control.transit_data_files{1} = fullfile(control.transit_data_files{1}, control.datalist_file);
    end
    if exist(control.transit_data_files{1}, 'file') ~= 2
        error('Transit data files not found: %s', control.transit_data_files{1});
    end    
    file_sets = generate_filelists(control.transit_data_files,  ...
        control.time_block);
    if isempty(file_sets)
        error('No files found in %s', control.transit_data_files{1});
    end
    Process_output_root_path = getOutputPath(control.processed_directory, ...
        file_sets{1,1}{1}, file_sets{end,1}{end}, control.template);
       
function [ev_files, Process_output_root_path] = get_ev_files(ev_filelist)
% Returns the list of EchoView worksheets (.ev files) for this data set.
%
% Inputs - a structure containing:
%   control.transit_data_files  Cell array of names of files containing 
%                               lists of data files (ES60 .raw or .ek5) *
%   control.time_block          Number of hours for each file set *
%   control.processed_directory Name of directory for processed data,
%                               usually 'Q:\processed_data\' *
%   control.worksheet_directory Name of sub directory holding worksheets,
%                               usually 'Echoview_worksheets'
%   ev_filelist                 Name of file containing list of .ev files
% * - only used if ev_filelist is empty
%
% Outputs:
%   ev_files                    cell array of filenames of .ev files.
%   Process_output_root_path    Directory used as the base for processing
%                               this data set.
%

% read file list
if exist(ev_filelist, 'file') == 2
    fid = fopen(ev_filelist,'r');
    datafilelist = textscan(fid,'%q', ...
        'commentStyle', '#', ...
        'delimiter', '');
    fclose(fid);
    ev_files = datafilelist{1};
    if isempty(ev_files)
        error(['No EV files listed in: ' ev_filelist])
    else
        if isempty(fileparts(ev_files{1}));
            ev_files = fullfile(fileparts(ev_filelist),ev_files);
        end
        Process_output_root_path = fileparts(fileparts(ev_files{1}));
    end
else
    ev_files = {};
    Process_output_root_path = '';
end


function target = getAttributes(target, file, overwrite)
%GETATTRIBUTES reads global attributes from the specified file and adds
% them to sample_data

listing = dir(file);
if length(listing) == 1 && listing(1).isdir == 0
    try
        globAtts = parseNetCDFTemplate(file, target);
        fields = fieldnames(globAtts);
        
        for m = 1:length(fields)
            if overwrite || ~isfield(target, fields{m}) || isempty(target.(fields{m}))
                target.(fields{m}) = globAtts.(fields{m});
            end
        end
    catch e
        warning('PARSE:bad_attr_file', ...
            'Unable to read attributes from %s : %s', file, e.identifier);
    end
end
