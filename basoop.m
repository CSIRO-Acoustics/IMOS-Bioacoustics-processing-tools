function settings = basoop(values)
% basoop returns a structure containing all the hard coded values
% used by the IMOS BASOOP application.
%
% If an input structure is provided fields will be copied from it in
% preference to the default values.

settings = struct([]);

    if nargin > 0
        if ischar(values)
            try 
                settings = load(values);
            catch e
                settings = read(values);
            end
        elseif isstruct(values)
            settings = struct(values);
        end
    end
    
    settings(1).version = '2.5 $Id: basoop.m 1439 2019-11-26 22:13:08Z  $';
    
    % read string settings from default setting file, 
    if exist('default_settings.txt', 'file') == 2
        settings = read('default_settings.txt', settings);
    end

    % options marked with a %GUI comment are updated by the GUI in start_process
    
    settings = default(settings, 'facility',           'SOOP-BA');
    settings = default(settings, 'upload_site',        'incoming.aodn.org.au');     % FTP server for upload to imos site
    settings = default(settings, 'upload_dir',         'BA');                       % directory on FTP server to upload files to
    settings = default(settings, 'upload_user',        '');                         % user name on ftp server
    settings = default(settings, 'upload_password',    '');                         % password on ftp server - leave blank, program will ask user
    
    % echoview configuration
    settings = default(settings, 'EvApp',           'EchoviewCom.EvApplication');
    settings = default(settings, 'EvPath',          'C:\Program Files\Myriax\Echoview\Echoview4\');     % deprecated
    
    % echoview virtual variables
    settings = default(settings, 'base_variable_name',      'Sv_38kHz');
    settings = default(settings, 'resample_variable_name',  'Sv 38 kHz resample for DSL convolution');
    
    % export to csv variables - slow - standard echointegration by cells      
    settings = default(settings, 'export_reference_variable_name',       'HAC Sv %s'); 
    settings = default(settings, 'export_final_variable_name',       'Final_%s_cleaned');
    settings = default(settings, 'export_rejectdata_variable_name',       'Reject_%s');
    settings = default(settings, 'export_noise_variable_name', 'Noise_%s');
    settings = default(settings, 'export_background_variable_name', 'Background_%s');
    settings = default(settings, 'export_motion_correction_factor_variable_name', 'Motion_correction_factor_%s'); % Haris 13/06/2019 to add motion correction factor
    
    % export to csv variables - fast - export from resampled variable
    settings = default(settings, 'export_reference_variable_name_fast',       'Raw_Sv_%s_resampled');	                
    settings = default(settings, 'export_final_variable_name_fast',       'Final_%s_cleaned_resampled');	        
    settings = default(settings, 'export_rejectdata_variable_name_fast',       'Reject_number_samples_resampled_%s');
    settings = default(settings, 'export_rawnumsamples_variable_name_fast',       'Raw_number_samples_resampled_%s');	        	        
    settings = default(settings, 'export_noise_variable_name_fast', 'Noise_%s_resampled');
    settings = default(settings, 'export_background_variable_name_fast', 'Background_%s_resampled');    
    settings = default(settings, 'export_reference_variable_name_fast_intervals', 'Raw_Sv_%s_resampled_intervals' );    
    settings = default(settings, 'export_motion_correction_factor_variable_name_fast', 'Motion_correction_factor_resampled_%s'); % Tim to add motion correction factor to fast processing export
        
    % data export resolution settings
    settings = default(settings, 'calibration_variable_name', settings.export_final_variable_name); % variable to read Calibration properties
    settings = default(settings, 'upper_DSL_line',       'upper DSL line');
    settings = default(settings, 'Grid_height',       10);                  %GUI    
    settings = default(settings, 'Grid_distance',     1000);                %GUI    
    settings = default(settings, 'soundspeed_formula', 'Mackenzie');        %GUI    
    settings = default(settings, 'soundabsorption_formula', 'Francois');    %GUI    
    settings = default(settings, 'filesets', {'Vessel_sv_data', '12kHz'});

    % print echogram parameters
    settings = default(settings, 'create_images', 1); 
    settings = default(settings, 'images_directory_name', 'Images'); 
    settings = default(settings, 'images_horizontal_dim', 1920); 
    settings = default(settings, 'images_vertical_dim', 600); 
    settings = default(settings, 'image_Grid_height',       100);        
    settings = default(settings, 'image_Grid_distance',     1000);       
    settings = default(settings, 'image_var_raw',     'HAC Sv %s');               
    settings = default(settings, 'image_var_proc',     'Reject_%s');              
    settings = default(settings, 'image_min_Sv',    -76);                
    settings = default(settings, 'image_max_Sv',    -40);                
    settings = default(settings, 'image_min_range_18',   0);                
    settings = default(settings, 'image_max_range_18',   1200);               
    settings = default(settings, 'image_min_range_38',   0);                
    settings = default(settings, 'image_max_range_38',   1200);               
    settings = default(settings, 'image_min_range_70',   0);                
    settings = default(settings, 'image_max_range_70',   1200);               
    settings = default(settings, 'image_min_range_120',   0);                
    settings = default(settings, 'image_max_range_120',   1200);               
    settings = default(settings, 'image_min_range_200',   0);                
    settings = default(settings, 'image_max_range_200',   1200);               
    settings = default(settings, 'image_fileformat',   'png');               

    if ispc
        % basedir is used as the starting point for the data directory
        % structure
        settings = default(settings, 'basedir',             'Q:\'); 
        basedir = settings.basedir;
        
%       basedir = 'V:\science\bioacoustics\Vessel_EK60\'; % onboard Investigator 
        settings = default(settings, 'template',            fullfile(basedir, 'IMOS_echoview_templates'));	%GUI
        settings = default(settings, 'dataview_dir',        'Q:\');
%       settings = default(settings, 'dataview_dir',      'Z:\software\dataview');
%       settings = default(settings, 'dataview_cmd',      'java -Xmx2000m -jar dataview.jar');
%       settings = default(settings, 'dataview_cmd',       '"C:\Program Files (x86)\Java\jre6\bin\javaw.exe" -jar -Xmx1500m Z:\software\dataview\dataview.jar');
%       settings = default(settings, 'dataview_cmd',        'javaw.exe -jar -Xmx1500m Z:\software\dataview\basoop.jar'); % 26/04/2017 - changed to -Xmx1200m as issue with running 32 bit on 64 bit machine or some such nonsense. tim ryan. 
%       settings = default(settings, 'dataview_cmd',        'javaw.exe -jar -Xmx1200m Z:\software\dataview\basoop.jar');
        settings = default(settings, 'dataview_cmd',        'javaw.exe -jar -Xmx1200m Q:\Software\java\dataview\basoop.jar'); % Haris 24/06/2019 setting path to 'Q' drive
%       settings = default(settings, 'dataview_cmd',        'javaw.exe -jar -Xmx1500m Z:\software\dataview\basoop.jar');
        settings = default(settings, 'dataview_cmd',        'javaw.exe -jar -Xmx1500m Q:\Software\java\dataview\basoop.jar'); % Not sure why it is needed - Haris
        settings = default(settings, 'transit_data_files',  'Q:\Rawdata');	%GUI
        settings = default(settings, 'transit_gps_file',    'Q:\Rawdata');	%GUI
        settings = default(settings, 'transit_pitch_file',  'Q:\Rawdata');	%GUI
        settings = default(settings, 'transit_roll_file',   'Q:\Rawdata');	%GUI
        settings = default(settings, 'processed_directory', 'Q:\Processed_data');
        settings = default(settings, 'alt_ev_dir',          'Q:\Processed_data');	%GUI
        settings = default(settings, 'alt_ev_files',        'Q:\Processed_data');	%GUI
        settings = default(settings, 'worksheet_directory', 'Echoview_worksheets');
        settings = default(settings, 'HAC_directory',       'HAC_outputs');
        settings = default(settings, 'echointegration_directory', 'echointegration_output');
        settings = default(settings, 'echointegration_path', '');
        settings = default(settings, 'merge_config',        'echoview_config.txt');	
        settings = default(settings, 'merge_file',          'merge.csv');	%GUI
        settings = default(settings, 'parse_file',          '');            %GUI
        settings = default(settings, 'netcdf_file',         'Q:\Processed_data\NetCDF\IMOS\');	%GUI           
%       settings = default(settings, 'calibration_file',    'Z:\echoview_worksheet\SupplementaryCalibrationFiles\');	%GUI
        settings = default(settings, 'calibration_file',    'Q:\Calibration_ecs_files\');	%GUI
%     	settings = default(settings, 'sst_path',            '\\fstas1-hba\CSIRO\CMAR\Project1\toolbox\local\csirolib\;\\fstas2-hba\CSIRO\CMAR\Share\eez_data\software\matlab\');
        settings = default(settings, 'sst_path',            '\\fstas1-hba\CSIRO\CMAR\Project1\toolbox\local\csirolib\;Q:\IMOS_BASOOP\eez_data\software\matlab'); % Haris 22/06/2019 changing windows path to 'Q' drive
%     	settings = default(settings, 'synTS_path',          { ...
%             '\\fstas2-hba\datalib\climatologies\synTS\hindcast13\'; ...
%             '\\fstas2-hba\datalib\climatologies\synTS\hindcast06\'; ...
%             '\\fstas2-hba\datalib\climatologies\synTS\NRT06\'; ...
%             '\\fstas2-hba\datalib\climatologies\synTS\NRT06_v1\'});
        settings = default(settings, 'synTS_path',          { ...
            '\\oa-osm-03-hba.it.csiro.au\OA_OCEANDATA_LIBRARY_MAIN\climatologies\synTS\hindcast13\'; ...
            '\\oa-osm-03-hba.it.csiro.au\OA_OCEANDATA_LIBRARY_MAIN\climatologies\synTS\hindcast06\'; ...
            '\\oa-osm-03-hba.it.csiro.au\OA_OCEANDATA_LIBRARY_MAIN\climatologies\synTS\NRT06\'; ...
            '\\oa-osm-03-hba.it.csiro.au\OA_OCEANDATA_LIBRARY_MAIN\climatologies\synTS\NRT06_v1\'}); % Haris 22/06/2019 changing windows path to new network drive
%       settings = default(settings, 'npp_path',            'Z:\Generic_data_sets\Primary_production');
        settings = default(settings, 'npp_path',            'Q:\Generic_data_sets\primary_production'); % Haris 22/06/2019 to change folder from 'Z' drive to 'Q' drive
        settings = default(settings, 'zip_command',       '"C:\Program Files\7-Zip\7z.exe" a -r ');
        
                                                % XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                                                % XXXXXXXXXXXX-----UNIX-----XXXXXXXXXXXX
                                                % XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
        
    else    % options involving echoview don't work under unix
        % basedir is used as the starting point for the data directory
        % structure
        settings = default(settings, 'basedir',             'Q:');  % Q: is a symbolic link to the directory normally mapped as Q:\ in windows.
        basedir = settings.basedir;
        settings = default(settings, 'template',            fullfile(basedir, 'IMOS_echoview_templates'));	%GUI
        settings = default(settings, 'dataview_dir',        '/home/acoustics/swath/software/dataview');
        settings = default(settings, 'dataview_cmd',        'dataview');
        settings = default(settings, 'calibration_file',    'Z:/echoview_worksheet/SupplementaryCalibrationFiles/');	%GUI
    	settings = default(settings, 'sst_path',            '/home/toolbox/local/csirolib:/home/eez_data/software/matlab');
    	settings = default(settings, 'synTS_path',          { ...
            '/home/datalib/climatologies/synTS/hindcast13/'; ...
            '/home/datalib/climatologies/synTS/hindcast06/'; ...
            '/home/datalib/climatologies/synTS/NRT06/'; ...
            '/home/datalib/climatologies/synTS/NRT06_v1/'});
%       settings = default(settings, 'npp_path',            'Z:/generic_data_sets/primary_production');
        settings = default(settings, 'npp_path',            'Q:/Generic_data_sets/primary_production'); % unix path - Haris 22/06/2019 to change folder from 'Z' drive to 'Q' drive
        settings = default(settings, 'zip_command',       'zip -r');
    end
    
    % defind processing and temporary directory structures
    settings = default(settings, 'procdir', fullfile(basedir, 'Processed_data'));
    settings = default(settings, 'tempdir', fullfile(basedir, 'temp'));
    procdir = settings.procdir;
    tempdir = settings.tempdir;
    
    settings = default(settings, 'transit_data_files',  fullfile(tempdir, 'transit_gps_datalist.txt'));	%GUI
    settings = default(settings, 'transit_gps_file',    fullfile(tempdir, 'transit_gps.gps.csv'));	%GUI
    settings = default(settings, 'transit_pitch_file',  'Q:\IMOS_echoview_templates\template\motion\transit_gps.pitch.csv');	%GUI
    settings = default(settings, 'transit_roll_file',   'Q:\IMOS_echoview_templates\template\motion\transit_gps.roll.csv');	%GUI
    settings = default(settings, 'processed_directory', procdir);
    settings = default(settings, 'alt_ev_dir',          procdir);	%GUI
    settings = default(settings, 'alt_ev_files',        procdir);	%GUI
    settings = default(settings, 'worksheet_directory', 'Echoview_worksheets');
    settings = default(settings, 'HAC_directory',       'HAC_outputs');
    settings = default(settings, 'echointegration_directory', 'echointegration_output');
    settings = default(settings, 'echointegration_path', '');
    settings = default(settings, 'datalist_file',       'datalist.txt');        % file to write datalist to for directory
    settings = default(settings, 'merge_config',        'echoview_config.txt');
    settings = default(settings, 'merge_file',          'merge.csv');	%GUI
    settings = default(settings, 'parse_file',          '');            %GUI
    settings = default(settings, 'netcdf_file',         fullfile(procdir, 'NetCDF','IMOS'));	%GUI
    settings = default(settings, 'voyage_inf',          fullfile(basedir, 'Rawdata'));	%GUI
    settings = default(settings, 'metadata_file',       '');
    settings = default(settings, 'priority_metadata',   'priority.txt');
    settings = default(settings, 'netcdf_directory',    fullfile(procdir, 'NetCDF', 'IMOS'));
    settings = default(settings, 'ex_netcdf_directory', fullfile(procdir, 'NetCDF', 'CSIRO'));
    settings = default(settings, 'imos_directory',      fullfile(procdir, 'NetCDF', 'IMOS'));
    
    % processing controls
    settings = default(settings, 'make_gps', 1);
    settings = default(settings, 'create_ev_files', 0, 1);                  %GUI
    settings = default(settings, 'overwrite_ev_files', 1, 1);               %GUI - popup
    settings = default(settings, 'skip_ev_files', 0, 1);                  	%GUI
    settings = default(settings, 'review_ev_files', 0, 1);                	%GUI
    settings = default(settings, 'export_import_HAC', 0, 1);              	%GUI
    settings = default(settings, 'export_HAC', 1, 1);                     	%GUI
    settings = default(settings, 'import_HAC', 1, 1);                     	%GUI
    settings = default(settings, 'export_sv', 0, 1);                     	%GUI
    settings = default(settings, 'export_sv_fast', 0, 1);                   %GUI
    settings = default(settings, 'fast_processing', 1, 1);                  %GUI
    settings = default(settings, 'read_echointegration', 0, 1);             %GUI
    settings = default(settings, 'merge', 0, 1);                          	% deprecated
    settings = default(settings, 'read_merge', 0, 1);                     	% deprecated
    settings = default(settings, 'read_netcdf', 0, 1);                    	%GUI
    settings = default(settings, 'copy_netcdf_metadata', 0, 1);                      	
    settings = default(settings, 'read_ecs', 1, 1);                      	%GUI
    settings = default(settings, 'read_inf', 0, 1);                       	%GUI
    settings = default(settings, 'read_meta', 0, 1);                       	%GUI
    settings = default(settings, 'synTS', 1, 1);                         	%GUI
    settings = default(settings, 'CARS', 1, 1);                         	%GUI
    settings = default(settings, 'npp', 1, 1);                              %GUI
    settings = default(settings, 'sound_speed', 1, 1);                    	%GUI
    settings = default(settings, 'netcdf', 0, 1);                         	%GUI
    settings = default(settings, 'alt_netcdf', 0, 1);                       %GUI
    settings = default(settings, 'extended', 0, 1);                      	%GUI
    settings = default(settings, 'matlab_view', 0, 1);                   	%GUI
    settings = default(settings, 'zap', 0, 1);                            	%GUI
    settings = default(settings, 'viz', 0, 1);                            	%GUI
    settings = default(settings, 'preserve_ncfilename', 1, 1);            
    settings = default(settings, 'png', 0, 1);        
    settings = default(settings, 'make_imos', 0, 1);                        %GUI
    settings = default(settings, 'raw_echoview', 1, 1);                     %GUI
    settings = default(settings, 'raw_datalist', 0, 1);                     %GUI
    settings = default(settings, 'raw_none', 0, 1);                         %GUI   
    settings = default(settings, 'imos_upload', 0, 1);                      %GUI
    
    settings = default(settings, 'detect_seafloor', 0, 1);                  %GUI
    settings = default(settings, 'detect_upper_DSL', 0, 1);                 %GUI
    settings = default(settings, 'detect_fixed', 0, 1);                     %GUI
    settings = default(settings, 'fixed_layer', 500);                       %GUI
    settings = default(settings, 'fixed_lines', 0);                         % HK 26/11/2119- adding settings.fixed_lines for later use in create_ev_files.m
    settings = default(settings, 'create_alt_ev_files', 0, 1);            	%GUI
    settings = default(settings, 'include_pitch', 0, 1);                  	%GUI
    settings = default(settings, 'include_roll', 0, 1);                   	%GUI
    settings = default(settings, 'use_alt_ev_files', 0, 1);               	%GUI
    settings = default(settings, 'export_reference', 1, 1);               	%GUI
    settings = default(settings, 'export_final', 1, 1);                    	%GUI                             
    settings = default(settings, 'export_reject', 1, 1);                   	%GUI                              
    settings = default(settings, 'export_background', 1, 1);                %GUI 
    
    settings = default(settings, 'export_motion_correction_factor', 1, 1);  %GUI  % Haris 13/06/2019 to add motion correction factor
    settings = default(settings, 'export_noise', 1, 1);                   	%GUI                              
    settings = default(settings, 'review_metadata', 0, 1);                  %GUI   
    settings = default(settings, 'review_ev_images', 0, 1);                 %GUI   
    
    settings = default(settings, 'review_priority_metadata', 0, 1);         %GUI       
    settings = default(settings, 'overwrite', 1, 1);                              
    settings = default(settings, 'single_format', 1, 1);                    %GUI 
    settings = default(settings, 'update_platform', 0, 0);                  
    settings = default(settings, 'posttime', 0, 1);                  
        
    settings = default(settings, 'max_depth', 1200);                           
    settings = default(settings, 'min_good', 0);                           
    settings = default(settings, 'accept_good', 50);                           

    settings = default(settings, 'platform', '');                           %GUI
    settings = default(settings, 'frequency', 38);                          %GUI
    settings = default(settings, 'time_block', 24);                         %GUI
    
    settings = default(settings, 'layer_indices', true);
    settings = default(settings, 'layers', [20 200; 200 400; 400 800]);
    settings = default(settings, 'layername', {'epipelagic' 'upper_mesopelagic' 'lower_mesopelagic'});
    settings = default(settings, 'min_layer_cells', 5);                     % If there are less cells in the layer make it NAN. 2019 07 30 GJK
    
    settings = default(settings, 'verbosity', 2);
    settings = default(settings, 'channel_mismatch', []);
    
    settings = default(settings, 'frequencies', [18; 38; 70; 120; 200; 333; 12]); 
    
    channels = cell(size(settings.frequencies));
    for f = 1:length(settings.frequencies)
        channels{f} = [ num2str(settings.frequencies(f)) 'kHz'];
    end    
    settings = default(settings, 'channels', channels);
    try
        settings = default(settings, 'channel', settings.channels(2));
    catch
        keyboard
    end
    
    % list of HAC numbers process.
%     settings = default(settings, 'HAC', 1:5);                               % deprecated
    settings = default(settings, 'HAC', 1);                               %GUI
    
    % Adjustments
    settings = default(settings, 'time_offset', 0);
    
    % Callback functions
    settings = default(settings, 'progress', []);
    
    % meta data is an empty IMOS toolbox sample_data structure
    % add expected fields so we can use IMOS's viewMetadata rather than
    % write our own.
    if ~isfield(settings, 'meta')
        if exist('metadata.txt', 'file') == 2
            settings.meta = read('metadata.txt');
            settings.meta = rmfield(settings.meta, 'readfrom');
        end
        settings.meta.dimensions = {};
        settings.meta.variables = {};
        settings.meta.meta = {};
        settings.meta.transit_start_locality = '';
        settings.meta.transit_end_locality = '';
    end
    
    settings.meta.data_processing_by = [getenv('USER') getenv('username') ...
        ' on ' getenv('HOSTNAME') getenv('computername') ' ' computer...
        ' at ' datestr(now,'yyyy-mm-ddTHH:MM:SS') ' local'];
    settings.meta.data_processing_software_version = settings.version;
    
    function s = default(s, field, value, nonempty)
    % assign a value to field of structure if it does not exist or if it is
    % empty and must be nonempty.
        if (nargin < 4)
            nonempty = 0;
        end
        % set field to value if it does not already have a value.
        if ~isfield(s, field) || (nonempty && isempty(s.(field)))
            s.(field) = value;
        end
    end

    function s = read(file,s)
        % read fields from a text file with each line consisting of a
        % field name and value surrounded by white space, values may be
        % enclosed in double quotes (").
        
        s.readfrom = file;
        
        try
            fid = fopen(file, 'rt');
            if fid == -1, return; end
            
            params = textscan(fid, '%s%q%*[^\n]', ...
                'commentStyle', '%');
            fclose(fid);
        catch e
            if fid ~= -1, fclose(fid); end
            rethrow(e);
        end

        fields = params{1};
        vals = params{2};
        for i=1:length(fields)
            val = vals{i};
            num = str2double(val);
            if ~isnan(num);     val = num;      end
            s = default(s,  fields{i}, val);
        end
    end
end

