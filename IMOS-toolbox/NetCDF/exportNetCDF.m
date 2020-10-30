function filename = exportNetCDF( sample_data, dest, mode )
%EXPORTNETCDF Export the given sample data to a NetCDF file.
%
% Export the given sample and calibration data to a NetCDF file. The file is 
% saved to the given destination directory. The file name is generated by the
% genIMOSFileName function.
%
% Inputs:
%   sample_data - a struct containing sample data for one process level.
%   dest        - Destination directory to save the file.
%   mode        - Toolbox data type mode.
%
% Outputs:
%   filename    - String containing the absolute path of the saved NetCDF file.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributors: Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Gordon Keith <gordon.keith@csiro.au>
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
  narginchk(3, 3);

  if ~isstruct(sample_data), error('sample_data must be a struct'); end
  if ~ischar(dest),          error('dest must be a string');        end

  % check that destination is a directory
  [stat, atts] = fileattrib(dest);
  if ~stat || ~atts.directory || ~atts.UserWrite
    error([dest ' does not exist, is not a directory, or is not writeable']);
  end
  % generate the filename
  filename = genIMOSFileName(sample_data, 'nc');
  filename = [dest filesep filename];
  
  compressionLevel = 1; % it seems the compression level 1 gives the best ration size/cpu
  fid = netcdf.create(filename, 'NETCDF4');
  if fid == -1, error(['Could not create ' filename]); end
  
  % we don't want the API to automatically pre-fill with FillValue, we're
  % taking care of it ourselves and avoid 2 times writting on disk
  netcdf.setFill(fid, 'NOFILL');
  
  dateFmt = readProperty('exportNetCDF.dateFormat');
  qcSet   = str2double(readProperty('toolbox.qc_set'));
  qcType  = imosQCFlag('', qcSet, 'type');
  qcDimId = [];
  
  try  
    %
    % the file is created in the following order
    %
    % 1. global attributes
    % 2. dimensions / coordinate variables
    % 3. variable definitions
    % 4. data
    % 
    globConst = netcdf.getConstant('NC_GLOBAL');

    %
    % global attributes
    %
    globAtts = sample_data;
    globAtts = rmfield(globAtts, 'meta');
    globAtts = rmfield(globAtts, 'variables');
    globAtts = rmfield(globAtts, 'dimensions');    
    
    % let's add QC information from log
    if ~isempty(sample_data.meta.log)
      globAtts.quality_control_log = cellfun(@(x)(sprintf('%s\n', x)), ...
        sample_data.meta.log, 'UniformOutput', false);
      globAtts.quality_control_log = [globAtts.quality_control_log{:}];
      globAtts.quality_control_log = globAtts.quality_control_log(1:end-1);
    end
    
    putAtts(fid, globConst, [], globAtts, 'global', 'double', dateFmt, mode);
    
    % if the QC flag values are characters, we must define 
    % a dimension to force the maximum value length to 1
    if strcmp(qcType, 'char')
      qcDimId = netcdf.defDim(fid, 'qcStrLen', 1);
    end

    % 
    % define string lengths
    % dimensions and variables of cell type contain strings
    % define stringNN dimensions when NN is a power of 2 to hold strings
    %
    dims = sample_data.dimensions;
    vars = sample_data.variables;
    str(1) = 0;
    for m = 1:length(dims)
        stringlen = 0;
        if iscell(dims{m}.data)
            stringlen = ceil(log2(max(cellfun('length', dims{m}.data)))) + 1; %+1 because we need to take into account the case 2^0 = 1
            str(stringlen) = 1; %#ok<AGROW>
            if isfield(sample_data.dimensions{m}, 'flags')
                sample_data.dimensions{m} = rmfield(sample_data.dimensions{m}, 'flags');
            end
        end
        sample_data.dimensions{m}.stringlen = stringlen;
    end
    for m = 1:length(vars)
        stringlen = 0;
        if iscell(vars{m}.data)
            stringlen = ceil(log2(max(cellfun('length', vars{m}.data)))) + 1; %+1 because we need to take into account the case 2^0 = 1
            str(stringlen) = 1; %#ok<AGROW>
            if isfield(sample_data.variables{m}, 'flags')
                sample_data.variables{m} = rmfield(sample_data.variables{m}, 'flags');
            end
        end
        sample_data.variables{m}.stringlen = stringlen;
    end
    
    stringd = nan(size(str));
    for m = 1:length(str)
        if str(m)
            len = 2 ^ (m-1); %-1 because we need to take into account the case 2^0 = 1
            if len > 1
                stringd(m) = netcdf.defDim(fid, [ 'STRING' int2str(len) ], len);
            end
        end
    end
    
    %
    % dimension and coordinate variable definitions
    %
    dims = sample_data.dimensions;
    nDims = length(dims);
    dimNetcdfType = cell(nDims, 1);
    for m = 1:nDims
          
      dims{m}.name = upper(dims{m}.name);
      
      dimAtts = dims{m};
      dimAtts = rmfield(dimAtts, {'data', 'name'});
      if isfield(dimAtts, 'typeCastFunc'), dimAtts = rmfield(dimAtts, 'typeCastFunc'); end
      if isfield(dimAtts, 'flags'), dimAtts = rmfield(dimAtts, 'flags'); end
      if isfield(dimAtts, 'FillValue_'), dimAtts = rmfield(dimAtts, 'FillValue_'); end % _FillValues for dimensions are not CF
      dimAtts = rmfield(dimAtts, 'stringlen');
      
      % ancillary variables for dimensions are not CF
%       if isfield(dims{m}, 'flags') && sample_data.meta.level > 0
%           % add the QC variable (defined below)
%           % to the ancillary variables attribute
%           dimAtts.ancillary_variables = [dims{m}.name '_quality_control'];
%       end

      % create dimension
      did = netcdf.defDim(fid, dims{m}.name, length(dims{m}.data));

      % create coordinate variable and attributes
      if iscell(dims{m}.data)
          dimNetcdfType{m} = 'char';
          vid = netcdf.defVar(fid, dims{m}.name, dimNetcdfType{m}, ...
              [ stringd(dims{m}.stringlen) did ]);
      else
          dimNetcdfType{m} = imosParameters(dims{m}.name, 'type');
          vid = netcdf.defVar(fid, dims{m}.name, dimNetcdfType{m}, did);
      end
      putAtts(fid, vid, dims{m}, dimAtts, lower(dims{m}.name), dimNetcdfType{m}, dateFmt, mode);
      
      % save the netcdf dimension and variable IDs 
      % in the dimension struct for later reference
      sample_data.dimensions{m}.did   = did;
      sample_data.dimensions{m}.vid   = vid;
      
      % ancillary variables for dimensions are not CF
%       if isfield(dims{m}, 'flags') && sample_data.meta.level > 0
%           % create the ancillary QC variable
%           qcvid = addQCVar(...
%               fid, sample_data, m, [qcDimId did], 'dimensions', qcType, dateFmt, mode);
%           sample_data.dimensions{m}.qcvid = qcvid;
%           
%           netcdf.defVarChunking(fid, qcvid, 'CHUNKED', length(dims{m}.flags));
%           
%           netcdf.defVarDeflate(fid, qcvid, true, true, compressionLevel);
%       end
    end
    
    
    %
    % variable (and ancillary QC variable) definitions
    %
    dims = sample_data.dimensions;
    vars = sample_data.variables;
    varNetcdfType = {};
    iVarToRemove = [];
    for m = 1:length(vars)

      varname = vars{m}.name;
      
      % we don't want to output any variable that doesn't have a standard
      % IMOS parameter code in the NetCDF file
      longname = imosParameters(varname, 'long_name');
      if false %strcmp(longname, varname) % by default IMOS parameter code without existing entry has its code for long_name
          iVarToRemove(end+1) = m;
          continue;
      end
      
      % get the dimensions for this variable
      dimIdxs = vars{m}.dimensions;
      nDim = length(dimIdxs);
      dids = NaN(1, nDim);
      dimLen = NaN(1, nDim);
      dimname = cell(1, nDim);
      for n = 1:nDim
          dids(n) = dims{dimIdxs(n)}.did;
          dimLen(n) = length(dims{dimIdxs(n)}.data);
          dimname{n} = dims{dimIdxs(n)}.name;
      end
      
      % reverse dimension order - matlab netcdf.defvar requires 
      % dimensions in order of fastest changing to slowest changing. 
      % The time dimension is always first in the variable.dimensions 
      % list, and is always the slowest changing.
      dids = fliplr(dids);
      dimLen = fliplr(dimLen);
      dimname = fliplr(dimname);
      
      % create the variable
      if iscell(vars{m}.data)
          varNetcdfType{end+1} = 'char';
          if vars{m}.stringlen > 1
              vid = netcdf.defVar(fid, varname, varNetcdfType{end}, ...
                  [ stringd(vars{m}.stringlen) dids ]);
              dimLen = [ 2^(vars{m}.stringlen-1) dimLen];   %#ok<AGROW>
          else
              vid = netcdf.defVar(fid, varname, varNetcdfType{end}, dids);
          end
      else
          varNetcdfType{end+1} = imosParameters(varname, 'type');
          vid = netcdf.defVar(fid, varname, varNetcdfType{end}, dids);
      end
      
      % Setting the chunks as big as possible is optimum for most use
      % cases, at least until the number of dimensions with length > 1 is
      % <= 2. When this number is > 2 then the chunk size is not optimised
      % for a 2D representation (performance in reading not optimised). So 
      % far, the toolbox is not producing any file that would be 
      % interesting to view in 3D.
      greatDim = dimLen > 1;
      optimised = true;
      if sum(greatDim) > 2
          % we look if the variable is TIME, FREQUENCY and DIR dependent. In this
          % case we know that we want the chunk size to be of all FREQUENCY and DIR
          % only for each TIME step. This is the only exception known so
          % far which is faced with ADCP wave data. In all other cases, we
          % don't know what to do and will choose the biggest chunk size
          % possible.
          if sum(greatDim) == 3
              greatDimName = dimname(greatDim);
              if any(strncmpi('TIME', greatDimName, 4)) && ...
                      any(strncmpi('FREQUENCY', greatDimName, 9)) && ...
                      any(strncmpi('DIR', greatDimName, 3))
                  dimLen(1) = 1; % T dimension always comes first
              elseif any(strncmpi('TIME', greatDimName, 4)) && ...
                      any(strncmpi('DEPTH', greatDimName, 5)) && ...
                      any(strncmpi('CHANNEL', greatDimName, 7))
                  dimLen(1) = 1; % channel is first after fliplr
              else
                  optimised = false;
              end
          else
              optimised = false;
          end
      end
      
      if ~optimised
          fprintf('%s\n', ['Warning : in ' filename ', the variable ' ...
              varname ' has been created with a chunk size not ' ...
              'optimised for any 2D representation (slower performance).' ...
              ' Please inform AODN.']);
      end
      
      if ~isempty(dimLen)
          netcdf.defVarChunking(fid, vid, 'CHUNKED', dimLen);
          netcdf.defVarDeflate(fid, vid, true, true, compressionLevel);
      end

      varAtts = vars{m};
      varAtts = rmfield(varAtts, {'data', 'dimensions', 'stringlen', 'name'});
      if isfield(varAtts, 'typeCastFunc'),      varAtts = rmfield(varAtts, 'typeCastFunc');     end
      if isfield(varAtts, 'flags'),             varAtts = rmfield(varAtts, 'flags');            end
      if isfield(varAtts, 'ancillary_comment'), varAtts = rmfield(varAtts, 'ancillary_comment');end
      
      if isfield(vars{m}, 'flags') && sample_data.meta.level > 0 && ~isempty(vars{m}.dimensions) % ancillary variables for coordinate scalar variable is not CF
          % add the QC variable (defined below)
          % to the ancillary variables attribute
          varAtts.ancillary_variables = [varname '_quality_control'];
      end

      % add the attributes
      putAtts(fid, vid, vars{m}, varAtts, 'variable', varNetcdfType{end}, dateFmt, mode);
      
      if isfield(vars{m}, 'flags') && sample_data.meta.level > 0 && ~isempty(vars{m}.dimensions) % ancillary variables for coordinate scalar variable is not CF
          % create the ancillary QC variable
          qcvid = addQCVar(...
              fid, sample_data, m, [qcDimId dids], 'variables', qcType, qcSet, dateFmt, mode);
          
          if ~isempty(dimLen)
              netcdf.defVarChunking(fid, qcvid, 'CHUNKED', dimLen);
              netcdf.defVarDeflate(fid, qcvid, true, true, compressionLevel);
          end
      else
          qcvid = NaN;
      end
    
      % save variable IDs for later reference
      sample_data.variables{m}.vid   = vid;
      sample_data.variables{m}.qcvid = qcvid;
    end

    % we're finished defining dimensions/attributes/variables
    netcdf.endDef(fid);

    % we remove the variables we don't want to output in NetCDF
    sample_data.variables(iVarToRemove) = [];
    
    %
    % coordinate variable (and ancillary variable) data
    %
    dims = sample_data.dimensions;
    for m = 1:length(dims)
      
      % dimension data
      vid     = dims{m}.vid;
      data    = dims{m}.data;
      stringlen = dims{m}.stringlen;
      typeCastFunction = str2func(netcdf3ToMatlabType(dimNetcdfType{m}));
      
      % translate time from matlab serial time (days since 0000-00-00 00:00:00Z)
      % to IMOS mandated time (days since 1950-01-01T00:00:00Z)
      if strcmpi(dims{m}.name, 'TIME')
          data = data - datenum('1950-01-01 00:00:00');
      end
      
      if isnumeric(data)
          iNaNData = isnan(data);
          if any(any(iNaNData))
              fprintf('%s\n', ['Warning : in ' sample_data.toolbox_input_file ...
                  ', there are NaNs in ' dims{m}.name ' dimension (not CF).']);
          end
      end
      
      data = typeCastFunction(data);
      if isnumeric(data)
          netcdf.putVar(fid, vid, data);
      elseif ischar(data)
          if stringlen > 1
              netcdf.putVar(fid, vid, zeros(ndims(data), 1), fliplr(size(data)), data');
          else
              netcdf.putVar(fid, vid, data);
          end
      end
      
      % ancillary variables for dimensions are not CF
%       if isfield(dims{m}, 'flags') && sample_data.meta.level > 0
%           % ancillary QC variable data
%           flags   = dims{m}.flags;
%           qcvid   = dims{m}.qcvid;
%           typeCastFunction = str2func(netcdf3ToMatlabType(qcType));
%           flags = typeCastFunction(flags);
%           netcdf.putVar(fid, qcvid, flags);
%       end
    end

    %
    % variable (and ancillary variable) data
    %
    vars = sample_data.variables;
    for m = 1:length(vars)

      % variable data
      data    = vars{m}.data;
      vid     = vars{m}.vid;
      stringlen = vars{m}.stringlen;
      typeCastFunction = str2func(netcdf3ToMatlabType(varNetcdfType{m}));
      
      % translate time from matlab serial time (days since 0000-00-00 00:00:00Z)
      % to IMOS mandated time (days since 1950-01-01T00:00:00Z)
      if strcmpi(vars{m}.name, 'TIME')
          data = data - datenum('1950-01-01 00:00:00');
      end
      
      % transpose required for multi-dimensional data, as matlab 
      % requires the fastest changing dimension to be first. 
      % of more than two dimensions.
      nDims = length(vars{m}.dimensions);
      if nDims > 1, data = permute(data, nDims:-1:1); end
      
      if isnumeric(data) && isfield(vars{m}, 'FillValue_')
          % replace NaN's with fill value
          data(isnan(data)) = vars{m}.FillValue_;          
      end
      
      data = typeCastFunction(data);
      if isnumeric(data)
          netcdf.putVar(fid, vid, data);
      elseif ischar(data)
          if stringlen > 1
              netcdf.putVar(fid, vid, zeros(ndims(data), 1), fliplr(size(data)), data');
          else
              netcdf.putVar(fid, vid, data);
          end
      end
      
      % ancillary QC variable data
      if isfield(vars{m}, 'flags') && sample_data.meta.level > 0 && ~isempty(vars{m}.dimensions) % ancillary variables for coordinate scalar variable is not CF
          flags   = vars{m}.flags;
          qcvid   = vars{m}.qcvid;
          typeCastFunction = str2func(netcdf3ToMatlabType(qcType));
          flags = typeCastFunction(flags);
          
          if nDims > 1, flags = permute(flags, nDims:-1:1); end
          
          netcdf.putVar(fid, qcvid, flags);
      end
    end

    %
    % and we're done
    %
    netcdf.close(fid);
  
  % ensure that the file is closed in the event of an error
  catch e
    try netcdf.close(fid); catch ex, end
    if exist(filename, 'file'), delete(filename); end
    rethrow(e);
  end
end

function vid = addQCVar(...
  fid, sample_data, varIdx, dims, type, netcdfType, qcSet, dateFmt, mode)
%ADDQCVAR Adds an ancillary variable for the variable with the given index.
%
% Inputs:
%   fid         - NetCDF file identifier
%   sample_data - Struct containing entire data set
%   varIdx      - Index into sample_data.variables, specifying the
%                 variable.
%   dims        - Vector of NetCDF dimension identifiers.
%   type        - either 'dimensions' or 'variables', to differentiate between
%                 coordinate variables and data variables.
%   netcdfType  - The netCDF type in which the flags should be output.
%   dateFmt     - Date format in which date attributes should be output.
%   mode        - Toolbox processing mode.
%
% Outputs:
%   vid         - NetCDF variable identifier of the QC variable that was 
%                 created.
%
  switch(type)
    case 'dimensions'
      var = sample_data.dimensions{varIdx};
      template = 'qc_coord';
    case 'variables'
      var = sample_data.variables{varIdx};
      template = 'qc';
    otherwise
      error(['invalid type: ' type]);
  end
  
  path = readProperty('toolbox.templateDir');
  if isempty(path) || ~exist(path, 'dir')
    path = '';
    if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
    if isempty(path), path = pwd; end
    path = fullfile(path, 'NetCDF', 'template');
  end
  
  varname = [var.name '_quality_control'];
  
  qcAtts = parseNetCDFTemplate(...
    fullfile(path, [template '_attributes.txt']), sample_data, varIdx);
  
  % get qc flag values
  qcFlags = imosQCFlag('', qcSet, 'values');
  nQcFlags = length(qcFlags);
  qcDescs = cell(nQcFlags, 1);
  
  % get flag descriptions
  for k = 1:nQcFlags
    qcDescs{k} = ...
      imosQCFlag(qcFlags(k), qcSet, 'desc');
  end
  
  % if the flag values are characters, turn the flag values 
  % attribute into a string of comma separated characters
  if strcmp(netcdfType, 'char')
    qcFlags(2,:) = ',';
    qcFlags = reshape(qcFlags, 1, numel(qcFlags));
    qcFlags = qcFlags(1:end-1);
    qcFlags = strrep(qcFlags, ',', ', ');
  end
  qcAtts.flag_values = qcFlags;
  
  % turn descriptions into space separated string
  qcDescs = cellfun(@(x)(sprintf('%s ', x)), qcDescs, 'UniformOutput', false);
  qcDescs{end}(end) = [];
  qcAtts.flag_meanings = [qcDescs{:}];
  
  % let's compute percentage of good data over in water data, following 
  % Argo reference table 2a conventions from 
  % http://www.argodatamgt.org/content/download/12096/80327/file/argo-dm-user-manual.pdf
  % p.57
  goodFlags = [imosQCFlag('good', qcSet, 'flag'), ...
      imosQCFlag('probablyGood', qcSet, 'flag'), ...
      imosQCFlag('changed', qcSet, 'flag')];
  notUsedFlags = imosQCFlag('missing', qcSet, 'flag');
  rawFlags = imosQCFlag('raw', qcSet, 'flag');
  
  % we only want to consider flags when data has been collected in position
  switch mode
      case 'profile'
          iInWater = true(size(sample_data.(type){varIdx}.data));
          
      case 'timeSeries'
          % inOutWater test don't apply on dimensions for timeseries data
          if ~strcmp(type, 'variables') || any(strcmp(sample_data.(type){varIdx}.name, {'TIMESERIES', 'PROFILE', 'TRAJECTORY', 'LATITUDE', 'LONGITUDE', 'NOMINAL_DEPTH'}))
              iInWater = true(size(sample_data.(type){varIdx}.data));
          else
              tTime = 'dimensions';
              iTime = getVar(sample_data.(tTime), 'TIME');
              noTime = false;
              if iTime == 0
                  tTime = 'variables';
                  iTime = getVar(sample_data.(tTime), 'TIME');
                  if iTime == 0
                      noTime = true;
                  end
              end
              
              if noTime || isempty(sample_data.time_deployment_start) || isempty(sample_data.time_deployment_end)
                  iInWater = true(size(sample_data.(type){varIdx}.data));
              else
                  iInWater = sample_data.(tTime){iTime}.data >= sample_data.time_deployment_start & ...
                      sample_data.(tTime){iTime}.data <= sample_data.time_deployment_end;
                  if size(sample_data.(type){varIdx}.data, 1) > 1 && size(sample_data.(type){varIdx}.data, 2) > 1
                      iInWater = repmat(iInWater, [1, size(sample_data.(type){varIdx}.data, 2)]);
                  end
                  if size(sample_data.(type){varIdx}.data, 3) > 1
                      iInWater = repmat(iInWater, [1, 1, size(sample_data.(type){varIdx}.data, 3)]);
                  end
              end
          end
  end
  % we don't consider missing value flags
  iMissing = sample_data.(type){varIdx}.flags == notUsedFlags;
try
    flags = sample_data.(type){varIdx}.flags(iInWater & ~iMissing);
   
catch
    keyboard
end
  
  % check if no QC
  iRaw = flags == rawFlags;
  if all(iRaw)
      qcAtts.quality_control_global = ' ';
  else
      nData = numel(flags);
      iGood = false(size(flags));
      for i=1:length(goodFlags)
          iGood = iGood | flags == goodFlags(i);
      end
      
      N = numel(flags(iGood))/nData * 100;
      if N == 100
          qcAtts.quality_control_global = 'A';
      elseif N >= 75 && N < 100
          qcAtts.quality_control_global = 'B';
      elseif N >= 50 && N < 75
          qcAtts.quality_control_global = 'C';
      elseif N >= 25 && N < 50
          qcAtts.quality_control_global = 'D';
      elseif N > 0 && N < 25
          qcAtts.quality_control_global = 'E';
      elseif N == 0
          qcAtts.quality_control_global = 'F';
      end
  end
  
  vid = netcdf.defVar(fid, varname, netcdfType, dims);
  putAtts(fid, vid, var, qcAtts, template, netcdfType, dateFmt, '');
end

function putAtts(fid, vid, var, template, templateFile, netcdfType, dateFmt, mode)
%PUTATTS Puts all the attributes from the given template into the given NetCDF
% variable.
%
% This code is repeated a number of times, so it made sense to enclose it in a
% separate function. Takes all the fields from the given template struct, and 
% writes them to the NetCDF file specified by fid, in the variable specified by
% vid.
%
% Inputs:
%   fid          - NetCDF file identifier
%   vid          - NetCDF variable identifier
%   var          - NetCDF variable/dimension
%   template     - Struct containing attribute names/values.
%   templateFile - name of the template file from where the attributes
%                  originated.
%   netcdfType   - type to use for casting valid_min/valid_max/_FillValue attributes.
%   dateFmt      - format to use for writing date attributes.
%   mode         - Toolbox processing mode.
%  

  % we convert the NetCDF required data type into a casting function towards the
  % appropriate Matlab data type
  qcSet   = str2double(readProperty('toolbox.qc_set'));
  qcType  = imosQCFlag('', qcSet, 'type');
  typeCastFunction = str2func(netcdf3ToMatlabType(netcdfType));
  qcTypeCastFunction = str2func(netcdf3ToMatlabType(qcType));
  
  templateDir = readProperty('toolbox.templateDir');

  % each att is a struct field
  atts = fieldnames(template);
  
  % let's process them in the alphabetical order regardless of the case
  [~, iSort] = sort(lower(atts));
  atts = atts(iSort);
  for k = 1:length(atts)

    name = atts{k};
    val  = template.(name);
    
    if strcmpi(name, 'quality_control_indicator') && isfield(var, 'flags')
        if any(var.flags ~= imosQCFlag('', qcSet, 'min'))
            % if all flag values are equal, add the
            % quality_control_indicator attribute
            minFlag = min(var.flags(:));
            maxFlag = max(var.flags(:));
            if minFlag == maxFlag
                val = minFlag;
            end
            val = qcTypeCastFunction(val);
        end
    end
    
    if isempty(val), continue; end;
    
    type = 'S';
    try 
        type = templateType(templateDir, name, templateFile, mode);
    catch e,
    end
    
    switch type
      case 'D'
          val = datestr(val, dateFmt);
    end
    
    % matlab-no-support-leading-underscore kludge
    if name(end) == '_', name = ['_' name(1:end-1)]; end
    
    if any(strcmpi(name, {'valid_min', 'valid_max', '_FillValue', 'flag_values'}))
        val = typeCastFunction(val);
    end
    
    % add the attribute
    %disp(['  ' name ': ' val]);
    if strcmpi(name, '_FillValue')
        netcdf.defVarFill(fid, vid, false, val); % false means noFillMode == false
    else
        netcdf.putAtt(fid, vid, name, val);
    end
  end
end
