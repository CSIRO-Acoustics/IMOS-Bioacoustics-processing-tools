function export_sv(control, ev_filelist)
%function export_sv(EvApp, control, ev_filelist)
% Export Sv from EchoView worksheets to .csv files
%
% Inputs:
%   EvApp       a handle to a COM object of an EchoviewApplication.
%   control     structure containing the following fields:
%       echointegration_directory   name of directory to write .csv files
%                                   in 'echointegration_output'
%       Grid_height                 height of grid to generate
%       Grid_distance               interval of grid to generate
%       export_reference            flag export reference variable?
%       export_reference_variable_name  'HAC Sv %s'
%       export_final                flag export final variable?
%       export_final_variable_name  'Final_%s_cleaned'
%       export_reject               flag export reject variable?
%       export_rejectdata_variable_name 'Reject_%s'      
%       channel                     cell array of channels to export
%   ev_filelist list of worksheets to export from    
% 

    % if these components are moved into the loop below we can have
    % echointegration directory name created for each ev file. Where the ev
    % file is located in the same path this will mean no difference for the
    % output location, however where we have ev files in different
    % directories it allows creation of an echointegration output
    % directory. Comment out next three lines and move into the loop
    % Tim Ryan 25th May 2019
    %[path, ~, ~] = fileparts(ev_filelist{1});
    %[path, ~, ~] = fileparts(path);
    %Echointegration_Output_dir = fullfile(path, control.echointegration_directory);
    %if ~isdir(Echointegration_Output_dir)
    %    mkdir(Echointegration_Output_dir)
    %end
    
    for i=1:length(ev_filelist)        
        % moved these next six lines to be within this loop to allow
        % creation of echointegration_directory for each ev file. Tim Ryan
        % 25th May 2019
        [path, ~, ~] = fileparts(ev_filelist{i}); % set to i to regard each ev file in the list
        [path, ~, ~] = fileparts(path);
        Echointegration_Output_dir = fullfile(path, control.echointegration_directory);
        if ~isdir(Echointegration_Output_dir)
            mkdir(Echointegration_Output_dir)
        end
        if control.verbosity > 1
%             fprintf('%s: Exporting %d of %d\n', datestr(now,'HH:MM:SS'), i, length(ev_filelist));
            fprintf('%s: exporting Echoview files %d of %d to:\n                     %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'), i, length(ev_filelist),Echointegration_Output_dir); % Haris 10 July 2019
        end
        EvFileName = ev_filelist{i};                
        [~, name, ~] = fileparts(EvFileName);
        
        if ~iscell(control.channel)            
            control.channel = {control.channel};
        end
        
        for channel = control.channel
            if control.export_reference
                try
                    reference_variable = sprintf(control.export_reference_variable_name, channel{1});
                    export_var(EvFileName, reference_variable, ...
                        Echointegration_Output_dir, name, ...
                        control.Grid_height, control.Grid_distance, control.verbosity);
                catch excpt     %#ok<NASGU>         % handle legacy variable name
                    export_var(EvFileName, 'HAC Sv 38 kHz', ...
                        Echointegration_Output_dir, name, ...
                        control.Grid_height, control.Grid_distance, control.verbosity);
                end
            end
            if control.export_final
                final_variable = sprintf(control.export_final_variable_name, channel{1});
                export_var(EvFileName, final_variable, ...
                    Echointegration_Output_dir, name, ...
                    control.Grid_height, control.Grid_distance, control.verbosity);
            end
            if control.export_reject
                rejectdata_variable = sprintf(control.export_rejectdata_variable_name, channel{1});
                export_var(EvFileName, rejectdata_variable, ...
                    Echointegration_Output_dir, name, ...
                    control.Grid_height, control.Grid_distance, control.verbosity);
            end
            if control.export_noise
                noise_variable = sprintf(control.export_noise_variable_name, channel{1});
                export_var(EvFileName, noise_variable, ...
                    Echointegration_Output_dir, name, ...
                    control.Grid_height, control.Grid_distance, control.verbosity);
            end
            if control.export_background
                background_variable = sprintf(control.export_background_variable_name, channel{1});
                export_var(EvFileName, background_variable, ...
                    Echointegration_Output_dir, name, ...
                    control.Grid_height, control.Grid_distance, control.verbosity);
            end
            
            % Haris 13/06/2019 to add motion correction factor
            if control.export_motion_correction_factor
                Motion_correction_factor = sprintf(control.export_motion_correction_factor_variable_name, channel{1});
                export_var(EvFileName, Motion_correction_factor, ...
                    Echointegration_Output_dir, name, ...
                    control.Grid_height, control.Grid_distance, control.verbosity);
            end            
        end      
        %try
            
        %catch exception
        %    fprintf('Stopped at %s line %d because of:\n%s\n', ...
        %        exception.stack(1).file, exception.stack(1).line, exception.message);
        %    fprintf('type "dbcont" and press Enter to continue\n');
        %end
    end
end

function export_var(EvFileName, vname, dir, fname, height, distance, verbosity)
    COLUMNS= {
%    'Interval';        % This export variable is not user accessible
%    'Layer';           % This export variable is not user accessible
    'Layer_depth_min';
    'Layer_depth_max';
    'Samples' ;         % Deprecated - old version of echoview.
    'Good_samples';
    'Lat_M';
    'Lon_M';
    'Date_M';
    'Time_M';
    'Height_mean';
    'Depth_mean';
    'EV_filename';
    'Program_version';
    'Sv_mean';
    'Standard_deviation';
    'Skewness';
    'Kurtosis';
    };
    EvApp=[];
    EvApp = getEvApp(EvApp);
    %if isempty(EvApp)
     %   fprintf('Active X\n');
        %EvApp = actxserver('EchoviewCom.EvApplication');
    %end

    try
        EvFile = EvApp.OpenFile(EvFileName);
    catch exception
        fprintf('Stopped at %s line %d because of:\n%s\n', ...
            exception.stack(1).file, exception.stack(1).line, exception.message);
        fprintf('type "dbcont" and press Enter to continue\n');
    end
    if isempty(EvFile)
        error('Unable to open %s', EvFileName);
    end
    
    % Haris 22 July 2019 - Minimize Echoview window opened
    EvApp.Minimize;
    
    EvFile.Properties.Export.EmptyCells = 1;
    for i = 1:size(COLUMNS,1);
        try
            EvFile.Properties.Export.Variables.Item(COLUMNS{i,1}).Enabled = 1;
        catch e
            % warning('EXPORT:COL', 'Column %s, message %s', COLUMNS{i,1}, e.message);
        end
    end
    Var = EvFile.Variables.FindByName(vname);
    if isempty(Var)
        %          fprintf('Couldnt find variable %s \n', vname)
        warning('couldnt find variable: %s', vname) % Haris 10 July 2019 making it as a warning
        %keyboard
        if isempty(Var)
            %              fprintf('Skipping export of not found variable %s \n', vname)
            warning('skipping export of not found variable: %s', vname)
            return
        end
    end
    VarAc = Var.AsVariableAcoustic;
    VarAc.Properties.Grid.SetDepthRangeGrid(1, height);
    VarAc.Properties.Grid.SetTimeDistanceGrid(5, distance);
    export_file_name = fullfile(dir, [fname '_' vname '.csv']);
    
    if verbosity > 1
        %         fprintf('exporting %s to \n%s\n', vname, export_file_name);
        fprintf('                     exporting variable %s as %d m X %d m cells\n',vname,height,distance); % Haris 10 July 2019
    end
    if VarAc.ExportIntegrationByCellsAll(export_file_name);
        if verbosity > 1
            %             fprintf('Done %s_%s.csv\n',fname,vname);
            fprintf('                     exporting variable %s completed\n',vname);
        end
    else
        fprintf('Echointegration failed\n');
    end
    EvFile.Close;
    EvApp.Quit;
end



function EvApp = getEvApp(EvApp)
    % Returns a handle to a COM object of an EchoviewApplication.
    %
    % If the input EvApp is empty new ActiveX server is created, otherwise it
    % is reused.
    %
    % echoview is the active X command to run echoview
    % 'EchoviewCom.EvApplication'

    if isempty(EvApp)
        try
            EvApp = actxserver('EchoviewCom.EvApplication');
            nopen = EvApp.EvFiles.Count;
            if nopen > 0
                error('EchoView already open');
            end
        catch e
            EvApp = [];
            fprintf('Couldn''t create ActiveX server for echoview\n%s\n', e.message);
        end
    end
end