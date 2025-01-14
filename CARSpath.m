function CARSpath
% This function tries to include all the path items needed to be able to
% read CARS data. 

if isempty(which('get_clim_profs'))
    if exist('/home/eez_data/software/matlab/', 'file') == 7
        cars_path = '/home/eez_data/software/matlab/';
%     elseif exist('\\fstas2-hba\CSIRO\CMAR\Share\eez_data\software\matlab', 'file') == 7
%         cars_path = '\\fstas2-hba\CSIRO\CMAR\Share\eez_data\software\matlab';
    
    % Haris 22/06/2019 commented above to use code from local drive - only
    % for windows.
    
    elseif isempty(strfind(path,'eez_data'))
        fprintf('\nLooks like eez data toolbox is not in the path, trying to add..\n')        
        cars_path = 'Q:\IMOS_BASOOP\eez_data\software\matlab';        
    else
%         error('Can''t find get_clim_profs. Please map a drive to \\fstas2-hba\CSIRO\CMAR\Share')
        error('Can''t find get_clim_profs. Add path Q:\IMOS_BASOOP\eez_data\software\matlab')
    end
    addpath(cars_path);
end
