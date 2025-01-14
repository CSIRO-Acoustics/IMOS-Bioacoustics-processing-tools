% PATH_PC_OR_NIX   Construct paths appropriately for the type of machine 
%                  being used. 
%  Better than old NIX_PC_PATH because user does not need to provide 
%  full Windows path name for certain Unix discs (provided that info
%  is up to date in this file.) However for Windows this makes it 
%  slower than NIX_PC_PATH.
%
% INPUT: upth  - unix style path, to a directory or a file. 
%                Leave off'/home/'.  Leave off leading '/'
%                unless path does not start with '/home/'
%
% OUTPUT  pth  - complete path
%        slsh  - slash symbol, if want to construct extra paths
%        plat  - 1=PC, 0=Unix, -1=MAC
%
% EG:  pth = path_pc_or_nix('datalib/climatologies/CARS/');
%
% Author:  Jeff Dunn   May 2015   
%          Future custodians:  Roger Scott, Gordon Keith ?
%
% NOTE: If any of the paths are wrong due to my errors or to discs being
%    shifted then please feel free to make corrections!
%
% NOTE: If samba is not running on a machine (so can't see from PC) then you
%    can create a symbolic link in a samba visible directory (on a
%    samba-running  machine)  to the NFS directory you want then samba will 
%    follow the link.  (according to Gordon.)
%
% USAGE: [pth,slsh,plat] = path_pc_or_nix(upth);

function [pth,slsh,plat] = path_pc_or_nix(upth)

cname = computer;
if strncmp(cname,'PC',2)
   plat = 1;

   % Paths as at May 2015
   % 1st server name should be a useful default that might work for unknown 
   % directories.
   
%    dir_server = ...
%        {'datalib',  '\\oa-osm-03-hba.it.csiro.au\OA_OCEANDATA_LIBRARY_MAIN\'; ...
%         'eez_data', '\\fstas2-hba\CSIRO\CMAR\Share\'; ...
%         'netcdf-data', '\\fstas2-hba\CSIRO\CMAR\Project1\'; ...	
%         'argo',     '\\fstas2-hba\CSIRO\CMAR\Project1\'; ...	
%         'UOT',      '\\fstas2-hba\CSIRO\CMAR\Project1\'; ...	
%         'dunn',     '\\fstas2-hba\CMAR-HOME3\'; ...
%         'reg2',     '\\reg2.hba.marine.csiro.au\'; ...
%         'imgjj',    '\\cmar-13-mel.it.csiro.au\OSM\MEL\OA_HOB_SRSMigration\archive\'};
    
    % Haris 22/06/2019 setting path to local 'Q' drive
    dir_server = ...
        {'datalib',  'Q:\Generic_data_sets\climatologies\'; ...
        'eez_data', 'Q:\Generic_data_sets\climatologies\'; ...
        'netcdf-data', '\\fstas2-hba\CSIRO\CMAR\Project1\'; ...
        'argo',     '\\fstas2-hba\CSIRO\CMAR\Project1\'; ...
        'UOT',      '\\fstas2-hba\CSIRO\CMAR\Project1\'; ...
        'dunn',     '\\fstas2-hba\CMAR-HOME3\'; ...
        'reg2',     '\\reg2.hba.marine.csiro.au\'; ...
        'imgjj',    '\\cmar-13-mel.it.csiro.au\OSM\MEL\OA_HOB_SRSMigration\archive\'};
	
   ii = strfind(upth,'/');
   dir1 = upth(1:ii(1)-1);
   dn = find(strcmp(dir1,dir_server(:,1)));
   if isempty(dn)
      dn = 1;
%       disp(['WARNING: path_pc_or_nix does not know name of server for' dir1])
%       disp(['  Crash looming if it is not ' dir_server{dn,2}]);
      
      cars_data_folder = dir_server{dn,2};
      if ~exist(cars_data_folder, 'dir') % Haris 10 July 2019 to crash if data is not in 'Q' drive
          fprintf('CARS data %s not found - check what is the case!\n\n',cars_data_folder);
          return
      end

   end      
   pth = dir_server{dn(1),2};
      
   slsh = '\';
   upth(ii) = slsh;
   pth = [pth upth];
elseif strncmp(cname,'MAC',3)
   plat = -1;
   %disp('Sorry - path_pc_or_nix.m can not build paths for a Mac [but you')
   %disp(' are welcome to add this to the code.]')
   pth = '';
   slsh = '?';
   
   dir_server = ...
       {'datalib',  '/Volumes/'; ...
        'eez_data', '/Volumes/'; ...
        'netcdf-data', '/Volumes/'; ...	
        'argo',     '/Volumes/'; ...	
        'UOT',      '/Volumes/'; ...	
        'dunn',     '/Volumes/'; ...
        'reg2',     '/Volumes/'; ...
        'imgjj',    '/Volumes/'};
	
   ii = strfind(upth,'/');
   dir1 = upth(1:ii(1)-1);
   dn = find(strcmp(dir1,dir_server(:,1)));
   if isempty(dn)
      dn = 1;
      disp(['WARNING: path_pc_or_nix does not know name of server for' dir1])
      disp(['  Crash looming if it is not ' dir_server{dn,2}]);
   end      
   pth = dir_server{dn(1),2};
      
   slsh = '/';
   upth(ii) = slsh;
   pth = [pth upth];
   
else
   % Assuming not a VAX, must be Unix
   plat = 0;
   if upth(1)=='/'       
      pth = upth;
   else
      pth = ['/home/' upth];
   end
   slsh = '/';
end


return

%-----------------------------------------------------------------------------
