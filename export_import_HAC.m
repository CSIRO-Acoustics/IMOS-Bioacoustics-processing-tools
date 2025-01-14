function export_import_HAC(EvApp, ev_filelist, control, progress)
% Export the requested variable from the specified worksheets to HAC files.
%
% Inputs:
%   EvApp       a handle to a COM object of an EchoviewApplication.
%   ev_filelist list of worksheets to export from    
%   control     structure with control settings including:
%           export_HAC - boolean - export HACs?
%           import_HAC - boolean - import HACs?
%           HAC_directory - string - name of directory containing HAC files 'HAC_outputs'
%           HAC - integer vector - HACs to process
%   progress    function to report progress to the user.
%
% Added option to print echograms as this is a convenient place to do this
% while in the process of opening up the ev files to export hacs. 
% will only happen if : settings = default(settings,'create_images', 1); is
% set in basoop.m. Note also other print settings are contained in basoop.m

    if nargin < 4
        progress = [];
    end
    start = tic;
    
    % -- Setup HAC output directory
    [path, ~, ~] = fileparts(ev_filelist{1});
    [path, ~, ~] = fileparts(path);
    
    HAC_Output_dir = fullfile(path, control.HAC_directory);
    if ~isdir(HAC_Output_dir)
        mkdir(HAC_Output_dir)
    end
    
    % -- Setup Image directory
    if control.create_images
        Image_Output_dir = fullfile(path, control.images_directory_name);             
        if ~isdir(Image_Output_dir)
            mkdir([Image_Output_dir '\raw']);
            mkdir([Image_Output_dir '\proc']);
        end
    end

    % -- process each file
    for i=1:length(ev_filelist)
        [~, name, ext] = fileparts(ev_filelist{i});
        EvFile = EvApp.OpenFile(ev_filelist{i});
        if isempty(EvFile)            
            error('Unable to open EV file %s', ev_filelist{i});
        end
        
        EvApp.Minimize; % Haris 25 July 2019 - minimize Echoview window opened
        
        for channel = control.channel
            for hac = control.HAC
                FilesetName = [channel{1} '_HAC' num2str(hac)];
                VarName = [FilesetName '_exp'];

                % export
                if control.export_HAC
                    if ~isempty(progress)
    %                     progress(control, ['export ' FilesetName] , i, length(ev_filelist), start, VarName);
    %                     progress(control, ['export variable ' VarName] , [], 0,[],['to ' HAC_Output_dir]);
                    end

                    try
                        Var = EvFile.Variables.FindByName(VarName);
                        if isempty(Var)
                            Var = EvFile.Variables.FindByName(['HAC' num2str(hac) '_exp']);     % old format
                        end
                        if isempty(Var)
                            warning('HAC:NO_VAR','Cannot find variable %s, skipping HAC %d', VarName, hac)
                            break
                        end
                    catch exception
                        fprintf('Stopped at %s line %d because of:\n%s\n', ...
                            exception.stack(1).file, exception.stack(1).line, exception.message);
                        fprintf('type "dbcont" and press Enter to continue\n');
                        keyboard
                    end
                    try
                        VarAc = Var; %.AsVariableAcoustic;
                    catch exception
                        fprintf('Stopped at %s line %d because of:\n%s\n', ...
                            exception.stack(1).file, exception.stack(1).line, exception.message);
                        fprintf('type "dbcont" and press Enter to continue\n');
                        keyboard
                    end

                    % -- setup the export file name
                    export_file_name = fullfile(HAC_Output_dir, [ name ' ' VarName '.hac']);
                    if control.verbosity > 1
    %                     fprintf('Exporting %s \nfrom variable %s \nfrom ev file %s \n', export_file_name, VarAc.Name, EvFile.FileName)
                        fprintf('                     exporting %s variable from EV file %s                     \n', VarName, [name ext])
                    end
                    try
                        VarAc.ExportHAC(export_file_name,-1,-1, 1); % compressed HAC format
                    catch exception
                        fprintf('Stopped at %s line %d because of:\n%s\n', ...
                            exception.stack(1).file, exception.stack(1).line, exception.message);
                        fprintf('type "dbcont" and press Enter to continue\n');
                        keyboard
                    end
                end

                % import
                if control.import_HAC
                    if ~isempty(progress)
    %                     progress(control, ['import ' FilesetName] , i, length(ev_filelist), start, VarName);
    %                     progress(control, ['import ' name ' ' VarName '_000000.hac'] , [], 0, [],['from ' HAC_Output_dir]);
                    end

                    hac_files = dir(fullfile(HAC_Output_dir, [ name ' ' VarName '_0*.hac']));
                    hac_file_to_add = fullfile(HAC_Output_dir, [ name ' ' VarName '_000000.hac']);
                    if control.verbosity > 1
    %                     fprintf('\nImporting HAC file %d of %d:\n%s \ninto ev fileset: %s\n\n', ...
    %                         i, length(ev_filelist), hac_file_to_add, [name ext]);
                        fprintf('                     importing HAC file %s into EV fileset %s                     \n', [name ' ' VarName '_000000.hac'], [name ext])
                    end
                    if isempty(hac_files)
                        warning('EXPIMP:NOFILE', 'HAC file to import not found: %s',hac_file_to_add);
                    end

                    try
                        fileset = EvFile.Filesets.FindByName(FilesetName);
                        if isempty(fileset)
                            fileset = EvFile.Filesets.FindByName(['HAC' num2str(hac)]);     % old format
                        end

                        % remove existing hacs
                        while  fileset.DataFiles.Count > 0
                             fileset.DataFiles.Remove(fileset.DataFiles.Item(0));
                        end

                        for h = 1:length(hac_files)
                            if ~fileset.DataFiles.Add(fullfile(HAC_Output_dir,hac_files(h).name))
                                warning('EXPIMP:NOTADD', 'File not added - check the name and path is correct: \n%s\n%s', HAC_Output_dir, hac_files(h).name)
                            end
                        end
                    catch exception
                            if isempty(fileset)                            
                                errordlg({'Help program has halted!!!.'
                                    ''
                                    'Trying to import HAC file to a HAC fileset' 
                                    'but most likely this does not exist in the ev file:'
                                    FilesetName
                                    'Check the EV file.' 
                                    'Quit running this program add a HAC fileset as required and re-run'
                                    ''
                                    'or Plan B if your template does not have HAC filesets,' 
                                    're-run the processing but this time'
                                    'uncheck all of the HAC checkboxes'}, ...
                                    'HAC fileset missing')
                            end                                                                              
                            fprintf('Stopped at %s line %d because of:\n%s\n', ...
                                exception.stack(1).file, exception.stack(1).line, exception.message);
                            fprintf('type "dbcont" and press Enter to continue\n');
                            keyboard
                    end
                    fprintf('                     printing echogram images from EV file %s                     \n', [name ext])
                    print_echogram(control,channel,EvFile,Image_Output_dir);
                end
            end
        end
        
        pause(10);
        EvFile.Save;
        try
        EvFile.Close;
        
        catch exception
            % workaround for echoview 7 intermittant crash on close bug
            warning('EI_HAC:EV7_CLOSE', 'Echoview close problem %s', exception.message)
            EvApp = actxserver('EchoviewCom.EvApplication');
        end
        if control.verbosity > 0
            fprintf('                     export to HAC & import into EV fileset completed %d of %d\n',i, length(ev_filelist));
        end
    end
    EvApp.Quit; % Haris 25 July 2019 - Quit EvApp
end
  

function print_echogram(control, channel,EvFile,Image_Output_dir)    
% function to print echograms for raw and processed variables to allow easy
% review of large datasets. 
% Tim Ryan and Haris Kunnath 22/10/2109

    % variables that we want to print are specified in basoop.m
    var_raw = control.image_var_raw;
    var_proc = control.image_var_proc;
    % return com objects for these variables.
    VarRaw = EvFile.Variables.FindByName(cell2mat(strrep(var_raw, '%s',channel)));
    VarProc = EvFile.Variables.FindByName(cell2mat(strrep(var_proc, '%s',channel)));

    % Setup variable to display how you like. Settings are held in basoop.m
    % set ranges according to frequency
    if isequal(channel,{'18kHz'})
        VarRaw.Properties.Display.UpperLimit = control.image_min_range_18;
        VarRaw.Properties.Display.LowerLimit = control.image_max_range_18;
    elseif isequal(channel,{'38kHz'})
        VarRaw.Properties.Display.UpperLimit = control.image_min_range_38;
        VarRaw.Properties.Display.LowerLimit = control.image_max_range_38;
    elseif isequal(channel,{'70kHz'})
        VarRaw.Properties.Display.UpperLimit = control.image_min_range_70;
        VarRaw.Properties.Display.LowerLimit = control.image_max_range_70;
    elseif isequal(channel,{'120kHz'})
        VarRaw.Properties.Display.UpperLimit = control.image_min_range_120;
        VarRaw.Properties.Display.LowerLimit = control.image_max_range_120;
    else isequal(channel,{'200kHz'})
        VarRaw.Properties.Display.UpperLimit = control.image_min_range_200;
        VarRaw.Properties.Display.LowerLimit = control.image_max_range_200;
    end
    if isequal(channel,{'18kHz'})
        VarProc.Properties.Display.UpperLimit = control.image_min_range_18;
        VarProc.Properties.Display.LowerLimit = control.image_max_range_18;
    elseif isequal(channel,{'38kHz'})
        VarProc.Properties.Display.UpperLimit = control.image_min_range_38;
        VarProc.Properties.Display.LowerLimit = control.image_max_range_38;
    elseif isequal(channel,{'70kHz'})
        VarProc.Properties.Display.UpperLimit = control.image_min_range_70;
        VarProc.Properties.Display.LowerLimit = control.image_max_range_70;
    elseif isequal(channel,{'120kHz'})
        VarProc.Properties.Display.UpperLimit = control.image_min_range_120;
        VarProc.Properties.Display.LowerLimit = control.image_max_range_120;
    else isequal(channel,{'200kHz'})
        VarProc.Properties.Display.UpperLimit = control.image_min_range_200;
        VarProc.Properties.Display.LowerLimit = control.image_max_range_200;
    end

    % set up the display ranges
    VarRaw.Properties.Display.ColorMinimum = control.image_min_Sv;
    VarRaw.Properties.Display.ColorRange = control.image_max_Sv - control.image_min_Sv;
    VarProc.Properties.Display.ColorMinimum = control.image_min_Sv;
    VarProc.Properties.Display.ColorRange = control.image_max_Sv - control.image_min_Sv;

    % set up the print dimensions
    image_horiz_dim=control.images_horizontal_dim;
    image_vertical_dim=control.images_vertical_dim;
    no_pings = VarRaw.MeasurementCount;
    start_ping = 0; j=1;
    while start_ping < no_pings
        % export first ping in each image to get date/time/lat/lon to
        % embedd in the file name.
        VarRaw.ExportData([Image_Output_dir '\pingtime.txt'],start_ping+1,start_ping+1); % HK-25/11/2019 changing to 'Image_Output_dir' from pwd
%         fid = fopen([Image_Output_dir '\pingtime.txt'],'r'); % no predefined directory, just drop it into current directory. HK-25/11/2019 changing to 'Image_Output_dir' from pwd
%         ln=fgetl(fid);ln=fgetl(fid);
%         k = strsplit(ln,', ');        
%         dte = strrep(k{4},'-','');
%         tme = strrep(k{5},':','');
%         datetime = [dte '_' tme];
%         lat = k{7}; lon = k{8};
%         lat = lat(2:7); lon = lon(1:7);
        
        % Haris 27/03/2020 - avoid failing in Echoview 11 due to format
        % change of pingtime.txt. Using readtable now to work for all
        % versions. Previous code is commented above and not deleted.
        try
            csvdata = readtable([Image_Output_dir '\pingtime.txt'],'header',0,'Delimiter', ','); % readtable behavior change in Matlab R2020a
        catch
            csvdata = readtable([Image_Output_dir '\pingtime.txt'],'VariableNamesLine',1,'Delimiter', ',');
        end
                
        % -- end code to catch error if first ping has no gps ----
        if isequal(csvdata.Longitude,999) %  no gps data in the first ping of raw file (first of raw is < first ping of gps.csv. so read first line of date/lat/lon from gps.csv file            
            csvdata = readtable(control.transit_gps_file)  ;  
            csvdata = csvdata(1,:);
            dte = datestr(csvdata.GPS_date,'yyyymmdd');
            tme = datestr(csvdata.GPS_time,'HHMMSS');
        else        
            dte = datestr(csvdata.Ping_date,'yyyymmdd');
            tme = datestr((csvdata.Ping_time),'HHMMSS');
        end
        % -- end code to catch error if first ping has no gps ----        
        datetime = [dte '_' tme];  
        
        lat = strrep(num2str(csvdata.Latitude,10),' ',''); % remove blanks that sometimes occur
        lat = lat(2:7);
        lon = strrep(num2str(csvdata.Longitude,10),' ',''); % remove blanks that sometimes occur
        lon = lon(1:7);
        % Haris 27/03/2020 - changes end here
        
        [~, evfilename] = fileparts(EvFile.FileName); % evfilename
        imagetoprint = [evfilename '_' datetime '_' lat 'S_' lon 'E_' VarRaw.Name '.' control.image_fileformat]; % embed metadata in file name
        imagefullpath = [Image_Output_dir '\raw\' imagetoprint];
        VarRaw.ExportEchogramToImage(imagefullpath,image_vertical_dim,start_ping,start_ping+image_horiz_dim);
        imagetoprint = [evfilename '_' datetime '_' lat 'S_' lon 'E_' VarProc.Name '.' control.image_fileformat]; % embed metadata in file name
        imagefullpath = [Image_Output_dir '\proc\' imagetoprint];
        VarProc.ExportEchogramToImage(imagefullpath,image_vertical_dim,start_ping,start_ping+image_horiz_dim);
        start_ping = start_ping + image_horiz_dim;
        j=j+1;
        fclose('all');
    end
end 
