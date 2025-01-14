function sample_data =  zap( sample_data, channel, interval, layer )
% zap - remove selected cells from the Sv data.
% zap works in either programmatic or UI mode.
% 
% In programatic mode four parameters are passed:
%   sample_data     sample_data structure to edit
%   channel         channel number to flag
%   interval        intervals to flag
%   layer           layers for flag.
%
% If anything other than four parameters is passed then user interface (UI)
% mode is enabled to allow the user to select cells from a plot of the Sv
% data to remove.
%
% When cells are removed the sv and percent good values are set to 0 and
% the action is recorded in sample_data.edits.
%
% The UI version calls to programmatic version to remove selected cells.

% identify relevant parts of sample_data
svv = [];
pcv = [];

for i = 1:length(sample_data.dimensions)
    if strcmp('TIME', sample_data.dimensions{i}.name)
        time = sample_data.dimensions{i}.data;
        break;
    end
end
for i = [5 1:length(sample_data.variables)];
    if strcmp('Sv', sample_data.variables{i}.name)
        svv = i;
        break;
    end
end

for i = [7 1:length(sample_data.variables)];
    if strcmp('Sv_pcnt_good', sample_data.variables{i}.name)
        
        pcv = i;
        break;
    end
end

if nargin == 4
    % programmatic mode
    % Zero the range of data selected and record this in the edits field.
    %
    % Edited at line 57 and 60 to replace '0' as 'nan'
    % Earlier, '0' was used to flag data. Which means 'valid min' is 'bad data' in linear domain.
    % Now 'nan' is used and they are correctly replaced with the fill value defined in IMOS toolbox as expected.
    % If fill value is correctly defined while creating NetCDF,this attribute information is be used by 'ncread' command
    % and matlab automatically convert 'fill values' as 'nan' upon import.
    % Haris 25 June 2018.
    
    if ismatrix(sample_data.variables{svv}.data)
        sample_data.variables{svv}.data(interval, layer) = nan;
        sample_data.variables{pcv}.data(interval, layer) = 0;
    else
        sample_data.variables{svv}.data(interval, layer, channel) = nan;
        sample_data.variables{pcv}.data(interval, layer, channel) = 0;
    end
    if isfield(sample_data, 'edits')
        prev = sprintf('%s\n',sample_data.edits);
    else
        prev = '';
    end
    sample_data.edits = [prev datestr(now,'yyyymmdd-HHMMSS') ' ' getenv('USER') getenv('UserName') ...
        ' flagged ' getrange(interval) '; ' getrange(layer) '; ' getrange(channel)];
    
else
    % manual zap gui
    data = 10 * log10(sample_data.variables{svv}.data);
    
    fig = figure;
    for i = size(data,3):-1:1   % for each channel
        % plot echogram
        subplot(size(data,3),1,i)
        imagesc(data(:,:,i)');
        colormap(EK500colourmap);
        caxis([-84 -48])
        
        % plot cumulative sv
        hold on
        plot(cumplot(sample_data.variables{svv}.data(:,:,i)) .* size(data,2) ,'k-')

        ax(i) = gca;
    end
    
    % button to flag data
    uicontrol(fig, ...
        'Style',        'pushbutton', ...
        'TooltipString', 'Press button then drag mouse to draw box to select data to remove from the dataset', ...
        'String',       'Flag data', ...
        'Callback',     @flag, ...
        'Units',        'pixels', ...
        'Position',     [0 0 100 20]);

    % XTick label format options
    uicontrol(fig, ...
        'Style',        'checkbox', ...
        'TooltipString', 'Show interval number in tick labels', ...
        'String',       'Show interval', ...
        'Tag',          'interval', ...
        'Value',        1, ...
        'Callback',     @label, ...
        'Units',        'pixels', ...
        'Position',     [100 0 100 20]);
    
    uicontrol(fig, ...
        'Style',        'checkbox', ...
        'TooltipString', 'Show date in tick labels', ...
        'String',       'Show date', ...
        'Tag',          'date', ...
        'Value',        0, ...
        'Callback',     @label, ...
        'Units',        'pixels', ...
        'Position',     [200 0 100 20]);
    
    uicontrol(fig, ...
        'Style',        'checkbox', ...
        'TooltipString', 'Show time in tick labels', ...
        'String',       'Show time', ...
        'Tag',          'time', ...
        'Value',        0, ...
        'Callback',     @label, ...
        'Units',        'pixels', ...
        'Position',     [300 0 100 20]);
    
    % Colour range manipulation
    uicontrol(fig, ...
        'Style',        'pushbutton', ...
        'TooltipString', 'Shift color range up', ...
        'String',       '^', ...
        'Callback',     @(~,~) caxis(caxis + 1), ...
        'Units',        'pixels', ...
        'Position',     [400 0 50 20]);
    uicontrol(fig, ...
        'Style',        'pushbutton', ...
        'TooltipString', 'Shift color range down', ...
        'String',       'v', ...
        'Callback',     @(~,~) caxis(caxis - 1), ...
        'Units',        'pixels', ...
        'Position',     [450 0 50 20]);
    uicontrol(fig, ...
        'Style',        'pushbutton', ...
        'TooltipString', 'Expand color range', ...
        'String',       '<>', ...
        'Callback',     @(~,~) caxis(caxis + [0 1]), ...
        'Units',        'pixels', ...
        'Position',     [500 0 50 20]);
    uicontrol(fig, ...
        'Style',        'pushbutton', ...
        'TooltipString', 'Contract color range', ...
        'String',       '><', ...
        'Callback',     @(~,~) caxis(caxis - [0 1]), ...
        'Units',        'pixels', ...
        'Position',     [550 0 50 20]);
   
    % view in echoview
    uicontrol(fig, ...
        'Style',        'pushbutton', ...
        'TooltipString', 'Select point to view in echoview', ...
        'String',       'View worksheet', ...
        'Callback',     @view, ...
        'Units',        'pixels', ...
        'Position',     [600 0 100 20]);

    set(fig, 'Toolbar', 'figure')   % kludge to rbbox working correctly
    set(zoom,'ActionPostCallback',@label)
    set(pan,'ActionPostCallback',@label)
   
    waitfor(fig)
end

    function flag(~,~)
    % Allow the user to draw a box and zero the cells in the box    
        zoom(fig, 'off')
        pan(fig, 'off')
        
        % identify which channel the user clicks on
        waitforbuttonpress
        chl = [];
        for c = 1 : length(ax)
            if isequal(ax(c), gca)
                chl = c;
            end
        end
        if isempty(chl)
            error('Couldn''t recognise graph axes');
        end
                
        % let user define box by dragging mouse
        point0 = get(gca,'CurrentPoint');
        rbbox();
        point1 = get(gca,'CurrentPoint');
        
        % determine intervals and layers selected
        ll = ceil(min(point0,point1));
        ur = floor(max(point0,point1));
        ur = max(ll,ur);
        
        intl = ll(1,1):ur(1,1);
        layr = ll(1,2):ur(1,2);
        
        % draw box around selected cells
        l = intl(1) - 0.5;
        r = intl(end) + 0.5;
        t = layr(1) - 0.5;
        b = layr(end) + 0.5;
        
        hold on
        imagesc(data(:,:,chl)');
        plot([l r r l l], [t t b b t], 'r-', 'LineWidth', 2)
        drawnow
        
        % confirm user wants these cells removed
        answer = questdlg(sprintf('NaN selected %d * %d cells\nIntervals %s\nLayers %s', ...
            length(intl), length(layr), getrange(intl), getrange(layr)), 'NaN cells');
        if strcmp(answer, 'Yes')
            % remove selected cells
            sample_data = zap(sample_data, chl, intl, layr);
            % recalculate and redraw echogram
            data = 10 * log10(sample_data.variables{svv}.data);
            imagesc(data(:,:,chl)');
        end
        
        % redraw cumulative sv
        plot(cumplot(sample_data.variables{svv}.data(:,:,chl)) .* size(data,2),'k-')       
    end

    function label(~,~)
    % Label the XTickMarks with interval, data and time as selected
        in = '';
        dt = '';
        tm = '';
            
        xt = get(gca, 'XTick');
        
        % handle case where user has zoomed in so far some tick marks don't
        % have matching pixels
        labl = find(mod(xt,1) == 0);
        if isempty(labl)    % no tick marks have matching pixels (all inside one pixel)
            set(gca,'XTickLabelMode','auto')
            return
        end
        
        % build labels
        if get(findobj(fig, 'Tag', 'interval'), 'Value')
            in = num2str(xt(labl)');
        end
        if get(findobj(fig, 'Tag', 'date'), 'Value')
            dt = datestr(time(xt(labl)), 'yyyy-mm-dd');
        end
        if get(findobj(fig, 'Tag', 'time'), 'Value')
            tm = datestr(time(xt(labl)), 'HH:MM:SS');
        end
        sp = ' ' * ones(length(labl),1);
        xtls = [in sp dt sp tm];
        
        % label ticks
        if length(xt) == length(labl)
            xtl = xtls;
        else
            % only label ticks that match pixels
            xtl(length(xt),size(xtls,2)) = ' ';
            for l = 1:length(labl)
                xtl(labl(l),:) = xtls(l,:);
            end
        end
        set(gca,'XTickLabel',xtl)
    end
      
    function range = getrange(numbers)
    % format a range of numbers as 'n:m'
        range = num2str(numbers(1));
        for n = 2:length(numbers)
            if numbers(n-1)+1 == numbers(n)
                if range(end) ~= ':';
                    range(end+1) = ':'; %#ok<AGROW>
                end
            else
                if range(end) == ':'
                    range = [range num2str(numbers(n-1))]; %#ok<AGROW>
                end
                range = [range ',' num2str(numbers(n))]; %#ok<AGROW>
            end
        end
        if range(end) == ':'
            range = [range num2str(numbers(end))];
        end
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

    function view(~,~)
        % open an echoview worksheet that contains the interval selected
        
        % wait for user to click on echogram to identify interval to display
        waitforbuttonpress;
        point=get(gca,'CurrentPoint');
        intvl = round(point(1,1));
        
        % identify channel
        chl = [];
        for c = 1 : length(ax)
            if isequal(ax(c), gca)
                chl = c;
            end
        end
        
        % identify ev_filename and channel dimensions in sample_data
        evfiles = {};
        evf = [];
        for k = 1:length(sample_data.dimensions)
            if strcmp('EV_FILENAME', sample_data.dimensions{k}.name)
                evfiles = sample_data.dimensions{k}.data;
                if strncmp('QQ',evfiles{1},2) % fix transposed filenames
                    ef = cell2mat(evfiles);
                    ef = reshape(ef',size(ef));
                    evfiles = cellstr(ef);
                    sample_data.dimensions{k}.data = evfiles;
                end
            end
            if strcmp('CHANNEL', sample_data.dimensions{k}.name)
                channl = sample_data.dimensions{k}.data{chl};
            end
        end
        
        % find last worksheet which starts before selected interval
        dt = ['D' datestr(time(intvl),'yyyymmdd-THHMMSS')];
        for k = 1:length(evfiles)
            evfile = evfiles{k};
            evfile(evfile == '\') = filesep;    % platform independant
            [~,evfile] = fileparts(evfile);
            % is filename less than selected date time lexigraphically
            d = evfile - dt;
            d(~d) = [];
            if d(1) < 0
                evf = k;
            end
        end
        
        if isempty(evf)
            error('Unable to identify evfile for %s', ...
                datestr(time(intvl),'yyyy-mm-dd-HH:MM:SS'));
        end
        
        % open selected evfile in echoview
        fprintf('Opening %s\n', evfiles{evf});
        if ispc
            EvApp = actxserver('EchoviewCom.EvApplication');
            EvFile = EvApp.OpenFile(evfiles{evf});
            if isempty(EvFile)
                warndlg({'Could not open' evfiles{evf} 'in echoview'},'Unable to open worksheet')
            else
                EvVar = EvFile.Variables.FindByName(sprintf('Final_%s_cleaned', channl));
                % EchoView doesn't have the ability to display and control an
                % echogram via COM.
                % View Echogram var
                % goto Time datestr(time(intvl),'yyyy-mm-dd-HH:MM:SS')
                % Possible workaround:
                % export Sv (or resampled to 1 pixels per ping Sv) to CSV then
                % read the CSV to get time -> ping number mapping then
                % EvVar.AsVariableVirtual.ExportEchogramToImage(file, h, s, e)
                % and then open the image in matlab.
            end
        end
        
%         fprintf('type "dbcont" and press Enter to continue\n');
%         keyboard
        
    end

    function cs = cumplot(sv)
        % calculate normalised cumulative sv
        sv(isnan(sv)) = 0;
        sv(isinf(sv)) = 1;
        sm = sum(sv,2);
        cs = cumsum(sm);
        cs = 1 - cs ./ cs(end);        
    end
end
