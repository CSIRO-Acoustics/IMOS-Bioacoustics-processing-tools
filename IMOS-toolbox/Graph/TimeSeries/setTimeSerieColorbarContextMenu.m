function hMenu = setTimeSerieColorbarContextMenu(var)
%SETTIMESERIECOLORBARCONTEXTMENU returns a context menu for colorbar 
% specific to variables.
%
% This function is used for defining the colorbar context menus of each
% axis 2D displayed.
%
% Inputs:
%   var         - The variable structure from sample_data.variables{k} if 
%               it is the k_th variable.
%
% Outputs:
%   hMenu       - Handle to the context menu.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(1, 1);

if ~isstruct(var), error('var must be a struct'); end

hMenu = [];

% let's handle the case we have multiple same param distinguished by "_1",
% "_2", etc...
iLastUnderscore = strfind(var.name, '_');
if iLastUnderscore > 0
    iLastUnderscore = iLastUnderscore(end);
    if length(var.name) > iLastUnderscore
        if ~isnan(str2double(var.name(iLastUnderscore+1:end)))
            var.name = var.name(1:iLastUnderscore-1);
        end
    end
end

switch upper(var.name(1:4))
    case {'UCUR', 'VCUR', 'WCUR', 'ECUR', 'VEL1', 'VEL2', 'VEL3', 'VEL4'} % 0 centred parameters
        colormap(r_b);
        cbCLimRange('', '', 'auto, 0 centred', var.data);
        
        % Define a context menu
        hMenu = uicontextmenu;
        
        % Define callbacks for context menu items that change linestyle
        hcb11 = 'colormap(r_b)';
        hcb13 = 'colormapeditor';
        
        % Define the context menu items and install their callbacks
        mainItem1 = uimenu(hMenu, 'Label', 'Colormaps');
        uimenu(mainItem1, 'Label', 'r_b (default)', 'Callback', hcb11);
        uimenu(mainItem1, 'Label', 'other',         'Callback', hcb13);
        
        mainItem2 = uimenu(hMenu, 'Label', 'Color range');
        uimenu(mainItem2, 'Label', 'full, 0 centred',                           'Callback', {@cbCLimRange, 'full, 0 centred', var.data});
        uimenu(mainItem2, 'Label', 'auto, 0 centred [0 +/-2*stdDev] (default)', 'Callback', {@cbCLimRange, 'auto, 0 centred', var.data});
        uimenu(mainItem2, 'Label', 'manual',                                    'Callback', {@cbCLimRange, 'manual', var.data});
        
    case {'CDIR', 'SSWD'} % directions
        colormap(rkbwr);
        cbCLimRange('', '', 'direction [0; 360]', var.data);
        
        % Define a context menu
        hMenu = uicontextmenu;
        
        % Define callbacks for context menu items that change linestyle
        hcb11 = 'colormap(rkbwr)';
        hcb13 = 'colormapeditor';
        
        % Define the context menu items and install their callbacks
        mainItem1 = uimenu(hMenu, 'Label', 'Colormaps');
        uimenu(mainItem1, 'Label', 'rkbwr (default)', 'Callback', hcb11);
        uimenu(mainItem1, 'Label', 'other',         'Callback', hcb13);
        
        mainItem2 = uimenu(hMenu, 'Label', 'Color range');
        uimenu(mainItem2, 'Label', 'direction [0; 360] (default)',  'Callback', {@cbCLimRange, 'direction [0; 360]', var.data});
        uimenu(mainItem2, 'Label', 'manual',                        'Callback', {@cbCLimRange, 'manual', var.data});
        
    case 'PERG' % percentages
        colormap(parula);
        cbCLimRange('', '', 'percent [0; 100]', var.data);
        
        % Define a context menu
        hMenu = uicontextmenu;
        
        % Define callbacks for context menu items that change linestyle
        hcb11 = 'colormap(parula)';
        hcb12 = 'colormap(jet)';
        hcb13 = 'colormapeditor';
        
        % Define the context menu items and install their callbacks
        mainItem1 = uimenu(hMenu, 'Label', 'Colormaps');
        uimenu(mainItem1, 'Label', 'parula (default)',  'Callback', hcb11);
        uimenu(mainItem1, 'Label', 'jet',               'Callback', hcb12);
        uimenu(mainItem1, 'Label', 'other',             'Callback', hcb13);
        
        mainItem2 = uimenu(hMenu, 'Label', 'Color range');
        uimenu(mainItem2, 'Label', 'percent [0; 100] (default)',  'Callback', {@cbCLimRange, 'percent [0; 100]', var.data});
        uimenu(mainItem2, 'Label', 'manual',                      'Callback', {@cbCLimRange, 'manual', var.data});
        
    case {'CSPD', 'VDEN', 'VDEV', 'VDEP', 'VDES'} % [0; oo[ paremeters
        colormap(parula);
        cbCLimRange('', '', 'auto from 0', var.data);
        
        % Define a context menu
        hMenu = uicontextmenu;
        
        % Define callbacks for context menu items that change linestyle
        hcb11 = 'colormap(parula)';
        hcb12 = 'colormap(jet)';
        hcb13 = 'colormapeditor';
        
        % Define the context menu items and install their callbacks
        mainItem1 = uimenu(hMenu, 'Label', 'Colormaps');
        uimenu(mainItem1, 'Label', 'parula (default)',  'Callback', hcb11);
        uimenu(mainItem1, 'Label', 'jet',               'Callback', hcb12);
        uimenu(mainItem1, 'Label', 'other',             'Callback', hcb13);
        
        mainItem2 = uimenu(hMenu, 'Label', 'Color range');
        uimenu(mainItem2, 'Label', 'full',                                      'Callback', {@cbCLimRange, 'full', var.data});
        uimenu(mainItem2, 'Label', 'full from 0',                               'Callback', {@cbCLimRange, 'full from 0', var.data});
        uimenu(mainItem2, 'Label', 'auto [mean +/-2*stdDev]',                   'Callback', {@cbCLimRange, 'auto', var.data});
        uimenu(mainItem2, 'Label', 'auto from 0 [0; mean +2*stdDev] (default)', 'Callback', {@cbCLimRange, 'auto from 0', var.data});
        uimenu(mainItem2, 'Label', 'manual',                                    'Callback', {@cbCLimRange, 'manual', var.data});
        
    case {'SSWV'} % [0; oo[ paremeter with special jet_w colormap
        % let's apply a colormap like jet but starting from white
        load('jet_w.mat', '-mat', 'jet_w');
        colormap(jet_w);
        cbCLimRange('', '', 'auto from 0', var.data);
        
        % Define a context menu
        hMenu = uicontextmenu;
        
        % Define callbacks for context menu items that change linestyle
        hcb11 = 'load(''jet_w.mat'', ''-mat'', ''jet_w''); colormap(jet_w)';
        hcb12 = 'colormap(parula)';
        hcb13 = 'colormap(jet)';
        hcb14 = 'colormapeditor';
        
        % Define the context menu items and install their callbacks
        mainItem1 = uimenu(hMenu, 'Label', 'Colormaps');
        uimenu(mainItem1, 'Label', 'jet_w (default)',   'Callback', hcb11);
        uimenu(mainItem1, 'Label', 'parula',            'Callback', hcb12);
        uimenu(mainItem1, 'Label', 'jet',               'Callback', hcb13);
        uimenu(mainItem1, 'Label', 'other',             'Callback', hcb14);
        
        mainItem2 = uimenu(hMenu, 'Label', 'Color range');
        uimenu(mainItem2, 'Label', 'full',                                      'Callback', {@cbCLimRange, 'full', var.data});
        uimenu(mainItem2, 'Label', 'full from 0',                               'Callback', {@cbCLimRange, 'full from 0', var.data});
        uimenu(mainItem2, 'Label', 'auto [mean +/-2*stdDev]',                   'Callback', {@cbCLimRange, 'auto', var.data});
        uimenu(mainItem2, 'Label', 'auto from 0 [0; mean +2*stdDev] (default)', 'Callback', {@cbCLimRange, 'auto from 0', var.data});
        uimenu(mainItem2, 'Label', 'manual',                                    'Callback', {@cbCLimRange, 'manual', var.data});
        
    otherwise
        colormap(parula);
        cbCLimRange('', '', 'full', var.data);
        
        % Define a context menu
        hMenu = uicontextmenu;
        
        % Define callbacks for context menu items that change linestyle
        hcb11 = 'colormap(parula)';
        hcb12 = 'colormap(jet)';
        hcb13 = 'colormap(r_b)';
        hcb14 = 'colormapeditor';
        
        % Define the context menu items and install their callbacks
        mainItem1 = uimenu(hMenu, 'Label', 'Colormaps');
        uimenu(mainItem1, 'Label', 'parula (default)',  'Callback', hcb11);
        uimenu(mainItem1, 'Label', 'jet',               'Callback', hcb12);
        uimenu(mainItem1, 'Label', 'r_b',               'Callback', hcb13);
        uimenu(mainItem1, 'Label', 'other',             'Callback', hcb14);
        
        mainItem2 = uimenu(hMenu, 'Label', 'Color range');
        uimenu(mainItem2, 'Label', 'full (default)',                    'Callback', {@cbCLimRange, 'full', var.data});
        uimenu(mainItem2, 'Label', 'full from 0',                       'Callback', {@cbCLimRange, 'full from 0', var.data});
        uimenu(mainItem2, 'Label', 'full, 0 centred',                   'Callback', {@cbCLimRange, 'full, 0 centred', var.data});
        uimenu(mainItem2, 'Label', 'auto [mean +/-2*stdDev]',           'Callback', {@cbCLimRange, 'auto', var.data});
        uimenu(mainItem2, 'Label', 'auto from 0 [0; mean +2*stdDev]',   'Callback', {@cbCLimRange, 'auto from 0', var.data});
        uimenu(mainItem2, 'Label', 'auto, 0 centred [0 +/-2*stdDev]',   'Callback', {@cbCLimRange, 'auto, 0 centred', var.data});
        uimenu(mainItem2, 'Label', 'manual',                            'Callback', {@cbCLimRange, 'manual', var.data});
        
end

end

% Callback function for CLim range
function cbCLimRange(src,eventdata, cLimMode, data)

CLim = NaN(1, 2);

switch cLimMode
    case 'full'
        CLim = [min(min(min(data))), max(max(max(data)))];
        
    case 'full from 0'
        maxVal = max(max(max(data)));
        CLim = [0, maxVal];
        
    case 'full, 0 centred'
        maxVal = max(abs([min(min(min(data))), max(max(max(data)))]));
        CLim = [-maxVal, maxVal];
        
    case 'direction [0; 360]'
        CLim = [0, 360];
        
    case 'percent [0; 100]'
        CLim = [0, 100];
    
    case 'auto'
        iNan = isnan(data);
        data = data(~iNan);
        clear iNan
        meanData = mean(data);
        stdDev = std(data);
        clear data
        CLim = [meanData - 2*stdDev, meanData + 2*stdDev];

    case 'auto from 0'
        iNan = isnan(data);
        data = data(~iNan);
        clear iNan
        meanData = mean(data);
        stdDev = std(data);
        clear data
        CLim = [0, meanData + 2*stdDev];
        
    case 'auto, 0 centred'
        iNan = isnan(data);
        data = data(~iNan);
        clear iNan
        % let's compute a pseudo standard deviation around 0 as we are
        % displaying current values symetrically around 0
        stdDev = sqrt(mean((data - 0).^2));
        clear data
        CLim = [-2*stdDev, 2*stdDev];
        
    case 'manual'
        CLimCurr = get(gca, 'CLim');
        prompt = {['{\bf', sprintf('Colorbar range :}\n\nmin value :')],...
            'max value :'};
        def                 = {num2str(CLimCurr(1)), num2str(CLimCurr(2))};
        dlg_title           = 'Set the colorbar range';
        
        options.Resize      = 'on';
        options.WindowStyle = 'modal';
        options.Interpreter = 'tex';
        
        answ = inputdlg( prompt, dlg_title, 1, def, options );
        if ~isempty(answ)
            CLim = [str2double(answ{1}), str2double(answ{2})];
        else
            CLim = CLimCurr;
        end
        
    otherwise
        % do nothing
        return;
        
end

if CLim(1) == CLim(2), CLim(2) = CLim(1) + 1; end % CLim must be increasing

set(gca, 'CLim', CLim);

end