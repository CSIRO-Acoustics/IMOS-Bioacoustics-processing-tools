function [cdata, rdata, tdata, bdata, sdata, mdata] = convert_resample_to_stdcsv(csvfilelist)
% function to convert resampled outputs to standard csv format ready for
% use by process_BASOOP
%
% Tim Ryan 16/05/2017
%      
% new method - get these variable names by looking for strings in
% csvfilelist
%
% Revision 30-10-2019
% added some fairly nasty code to in process_cdata to work out when there
% were rows missing in the interval data. issue is on rare occasions the
% interval by cells doesn't match that of the resampled interval. It means
% that you can have situation where there are two 'resampled' pings of e.g
% 100 m within a cell of 100 m whereas there should be a 1:1 match. 

rawdatafile = cell2mat(csvfilelist(~cellfun('isempty',regexp(csvfilelist,'Raw_Sv'))));               % e.g. D20180818-T083109_Raw_Sv_38kHz_resampled.csv
rawnumsamples = cell2mat(csvfilelist(~cellfun('isempty',regexp(csvfilelist,'Raw_number_samples')))); % e.g. D20180818-T083109_Raw_number_samples_resampled_38kHz.csv
cleandatafile = cell2mat(csvfilelist(~cellfun('isempty',regexp(csvfilelist,'cleaned'))));            % e.g. D20180818-T083109_Final_38kHz_cleaned_resampled.csv
rejectdatafile = cell2mat(csvfilelist(~cellfun('isempty',regexp(csvfilelist,'Reject'))));            % e.g. D20180818-T083109_Reject_number_samples_resampled_38kHz.csv
SNRdatafile = cell2mat(csvfilelist(~cellfun('isempty',regexp(csvfilelist,'Noise'))));                % e.g. D20180818-T083109_Noise_38kHz_resampled.csv
BNdatafile = cell2mat(csvfilelist(~cellfun('isempty',regexp(csvfilelist,'Background'))));            % e.g. D20180818-T083109_Background_38kHz_resampled.csv
MCdatafile = cell2mat(csvfilelist(~cellfun('isempty',regexp(csvfilelist,'Motion'))));                % e.g. D20180818-T083109_Motion_correction_factor_resampled_38kHz.csv
% interval file is used in the function 'process_cdata'                                              % e.g. D20180818-T083109_Raw_Sv_38kHz_resampled_intervals.csv
                                                                                                     % Total 8/8 exported files used

[cdata,interval_idx] = process_cdata(cleandatafile);                     % final cleaned data 
                                                            % 1x14 cell as {Inerval(1), Layer(2), Sv_clean(3), Height_mean(4), Depth_mean(5), Depth_min(6), Depth_max(7)
                                                            %               Ping_date(8), Ping_time(9), Latitude(10), Longitude(11), Standard_deviation(12), Skewness(13), Kurtosis(14)}
                                                            
[rdata] = process_rdata(rawdatafile,rawnumsamples,cdata,interval_idx);  % raw\reference data
                                                            % 1x7 cell as {Inerval(1), Layer(2), Sv_raw(3), Number_Raw_Samples(4), Standard_deviation(5), Skewness(6), Kurtosis(7)}
        
[tdata] = process_tdata(rejectdatafile,cdata,interval_idx);             % number of samples left in clean data
                                                            % 1x3 cell as {Inerval(1), Layer(2), Number_Clean_Samples(3)}

[sdata] = process_sdata(SNRdatafile,cdata,interval_idx);                % singal-to-noise ratio 
                                                            % 1x3 cell as {Inerval(1), Layer(2), singal-to-noise ratio(3)}
                                                            
[bdata] = process_bdata(BNdatafile, cdata,interval_idx);                 % background noise
                                                            % 1x3 cell as {Inerval(1), Layer(2), background noise(3)}
                                                            
[mdata] = process_mdata(MCdatafile, cdata,interval_idx);                 % motion correction factor
                                                            % 1x3 cell as {Inerval(1), Layer(2), motion correction factor(3)}

% here we calculate the height of the cell in terms of number of good
% samples. This is needed for NASC calculations, also for storing
% 'mean_height' variable in the NetCDF.
num_original_samples = double(rdata{4});
num_good_samples = double(tdata{3});

height_mean = double(cdata{4}) .*( num_good_samples./num_original_samples);
cdata{4} = height_mean;

function [cdata,interval_idx] = process_cdata(cleandatafile)
    % final cleaned data    
    warning off;
    try
        csvdata= readtable(cleandatafile,'header',0,'Delimiter', ','); % HK 2019-09-04 defining Delimiter as ',' to fix reading ',' as data value
    catch
        csvdata= readtable(cleandatafile,'VariableNamesLine',1,'Delimiter', ','); % to work with Matlab R2020a due to behaviour change
    end
    warning on;  
    
    csvdata.Properties.VariableNames(1) = {'Ping_index'}; % fix up the annoying UTF-8 byte order that is screwing up Ping_index
    % chuck out any replicated rows (occasionally happens in Echoview10
    % from outout of resample operator. May be fixed in future versions
    % but for now do filtering here
    [ai, bi] = unique(csvdata(1:end,2:end),'rows');
    csvdata = csvdata(bi,:);                                        
    
    % matrix and vector dimensions
    [m,n] = size(csvdata);
    p = csvdata.Sample_count(1); % number of Sv columns
         
    % Ping index - i.e. read intervals
    a = (strrep(cleandatafile, 'cleaned_resampled','resampled_intervals'));
    interval_file = (strrep(a,'Final_','Raw_Sv_'));                         % e.g. D20180818-T083109_Raw_Sv_38kHz_resampled_intervals.csv
    warning off;
    intervaldata = readtable(interval_file,'DatetimeType','text');
    
    % rows with Sv mean of 9999 need to be gone. 
    idx = intervaldata.Sv_mean~=9999;
    intervaldata = intervaldata(idx,:);
    % sort rows. Tim ryan 28.10.2019
    intervaldata = sortrows(intervaldata,'Interval');
    csvdata = sortrows(csvdata,'Ping_index');    
    % need to check if there are missing rows on either interval or csv
    % data
    % interval data
        Time = char(intervaldata.Time_M);
        Date = num2str(intervaldata.Date_M);            
        space = char(ones(length(intervaldata.Lat_M),1)*32); 
        intervaldata_DateNum = datenum([Date space Time],'yyyymmdd Hh:MM:SS.FFF');

        % csv data
        Date = datestr(csvdata.Ping_date,'yyyymmdd');
        Time = datestr((csvdata.Ping_time),'HH:MM:SS');
        Millisec = num2str(floor(csvdata.Ping_milliseconds),'%03.f');
        space = char(ones(length(csvdata.Latitude),1)*32);            
        dot = char(ones(length(csvdata.Latitude),1)*46);            
        csvdata_DateNum = datenum([Date space Time dot Millisec],'yyyymmdd HH:MM:SS.FFF');
                
        [val,interval_idx,csvdata_bi]=intersect(csvdata_DateNum, intervaldata_DateNum);
        [m,~]=size(csvdata);
        if ~isequal(length(interval_idx),m)
%             fprintf('Warning mismatch between interval and csv data. %d rows removed\n',m-length(interval_idx));
            warning('Mismatch between interval and csv data, %d missing data intervals removed',m-length(interval_idx)) 
        end    
        % create new matrics with equal match between interval and csv data
                        
        intervaldata = intervaldata(csvdata_bi,:);
        csvdata = csvdata(interval_idx,:);                              
   
    %%% - Now we have interval data and csvdata with same number of rows we
    %%%  can proceed
        
    warning on; 
    Ping_index = intervaldata.Interval;
    Ping_index = repmat(Ping_index,1,p);
    Ping_index = reshape(Ping_index',1,[]);
        
    % reshape to create vectors of the data
    % Sv data goes from Var 15 to 'end'
    csvdata.Var14(csvdata.Var14<-999) = NaN; % first colummn null values so set to NaN
    
    % Sv first column - identify when Sv columns first start.     
    varnames = csvdata.Properties.VariableNames;
    i=1;
    while i<length(varnames)    
        a = strfind(varnames{i},'Var');
        if ~isempty(a)
            Sv_first_col = i;
            break
        end
        i=i+1;
    end    
    Svdata = table2array(csvdata(:,Sv_first_col:end));
    Sv_mean = reshape(Svdata',1,[]);
    Sv_mean(Sv_mean<-998) = NaN; % set -999 to NaN
        
    % Layer
    [m,~]=size(csvdata);
    Layer = int32(1:1:p);
    Layer = repmat(Layer,1,m);
    Layer = reshape(Layer',1,[]);
        
    % Depth mean min and max vectors
    vert_res = (csvdata.Depth_stop(1) - csvdata.Depth_start(1)) / csvdata.Sample_count(1);    
    Depth_mean = csvdata.Depth_start + vert_res/2 : vert_res : csvdata.Depth_stop;    
    Depth_mean = repmat(Depth_mean,1,m);
    Depth_mean = reshape(Depth_mean',1,[]);
    Depth_min = Depth_mean - vert_res/2;
    Depth_min = cellstr(num2str(Depth_min')); % convert to array of strings - not sure why but subsequent code in read_echointegrat_fast is looking for this
    Depth_max = Depth_mean + vert_res/2;
    Depth_max = cellstr(num2str(Depth_max')); % convert to array of strings - not sure why but subsequent code in read_echointegrat_fast is looking for this
        
    % Height mean vector
    Height_mean = repmat(Depth_mean(2) - Depth_mean(1),1,m * p);
        
    % Ping date
    Ping_date = repmat(csvdata.Ping_date,1,p);
    Ping_date = reshape(Ping_date',1,[])';
    Ping_date = cellstr(num2str(yyyymmdd(Ping_date)));
    
    % Ping time
    Ping_time = csvdata.Ping_time + milliseconds(csvdata.Ping_milliseconds);
    Ping_time.Format = 'hh:mm:ss.SSS';
    Ping_time = repmat(Ping_time,1,p);
    Ping_time = cellstr(reshape(Ping_time',1,[]));
    
    % Latitude
    Latitude = csvdata.Latitude;
    Latitude = repmat(Latitude',p,1);
    Latitude = reshape(Latitude,1,[])';
    Latitude = cellstr(num2str(Latitude));
    
    % Longitude
    Longitude = csvdata.Longitude;
    Longitude = repmat(Longitude',p,1);
    Longitude = reshape(Longitude,1,[])';
    Longitude = cellstr(num2str(Longitude));
    
    % Skew, Kurtosis, Stdev placeholders
    % These variables get written to NetCDF only if 'Extended' option in
    % GUI is selected, this option is for internal purpose only, not for
    % IMOS.
    Skew = ones(length(Latitude),1)*NaN;
    Kurtosis = ones(length(Latitude),1)*NaN;
    Stdev = ones(length(Latitude),1)*NaN;
        
    cdata = [{Ping_index'} {Layer'} {Sv_mean'} {Height_mean'} {Depth_mean'} {Depth_min}, ...
        {Depth_max} {Ping_date} {Ping_time'} {Latitude} {Longitude}, ...
        {Stdev} {Skew} {Kurtosis}];
    
function [rdata] = process_rdata(rawdatafile, rawnumsamples, cdata,interval_idx)
    % takes raw data file and pulls out Sv values. then extracts number of
    % good samples from rawnumsamples file. adds columns from cdata as
    % needed to match original structure that Gordon used.    
    Sv_raw = extract_datavals(rawdatafile,interval_idx); % call to function
    Sv_raw(Sv_raw<-998) = NaN; % kick out bad data values (e.g. -9.9e37);
    No_Raw_Samples = extract_datavals(rawnumsamples,interval_idx);
    No_Raw_Samples(No_Raw_Samples<-998) = NaN; % kick out bad data values (e.g. -9.9e37);
    rdata = [cdata{1} cdata{2} {Sv_raw'} {int32(No_Raw_Samples)'} cdata{12} cdata{13} cdata{14}];
        
function [mdata] = process_mdata(rawdatafile,cdata,interval_idx)
    % motion correction factor
    mc_dbdiff = extract_datavals(rawdatafile,interval_idx); % call to function
    mc_dbdiff(mc_dbdiff<-998) = NaN; % kick out bad data values (e.g. -9.9e37);
    mdata = [cdata{1} cdata{2} {mc_dbdiff'}];
        
function [tdata] = process_tdata(rejectdatafile,cdata,interval_idx)
    % pull out number of samples left in clean data plus first two columns of cdata
    No_Clean_Samples = extract_datavals(rejectdatafile,interval_idx); % call to function
    No_Clean_Samples(No_Clean_Samples<-998) = NaN; % kick out bad data values (e.g. -9.9e37);
    tdata = [cdata{1} cdata{2} {int32(No_Clean_Samples)'}];

function [sdata] = process_sdata(SNRdatafile,cdata,interval_idx)
    % pull out SNR data data plus first two columns of cdata
    SNR = extract_datavals(SNRdatafile,interval_idx); % call to function
    SNR(SNR<-998) = NaN; % kick out bad data values (e.g. -9.9e37);
    sdata = [cdata{1} cdata{2} {SNR'}];
        
function [bdata] = process_bdata(BNdatafile,cdata,interval_idx)
    % pull out BN data plus first two columns of cdata
    BN = extract_datavals(BNdatafile,interval_idx); % call to function
    BN(BN<-998) = NaN; % kick out bad data values (e.g. -9.9e37);
    BN = cellstr(num2str(BN'));
    bdata = [cdata{1} cdata{2} {BN}];

function datavals = extract_datavals(datafilename,interval_idx)  
    warning off; 
    try
        csvdata = readtable(datafilename, 'header',0,'Delimiter', ','); % HK 2019-09-04 defining Delimiter as ',' to fix reading ',' as data value
    catch
        csvdata = readtable(datafilename,'VariableNamesLine',1,'Delimiter', ','); % to work with Matlab R2020a due to behaviour change
    end
    
    % chuck out any replicated rows (occasionally happens in Echoview10
    % from outout of resample operator. May be fixed in future versions but
    % for now do filtering here    
    [ai, bi] = unique(csvdata(1:end,2:end),'rows');      
    [m,n] = size(csvdata);
    if isequal(length(bi), m)
        % do nothing
    else        
       fprintf('Warning %d non unique rows removed\n',m - length(bi)); 
    end    
    csvdata = csvdata(bi,:);                    
    csvdata = csvdata(interval_idx,:); % ensure intervals and csvdata have same number of rows            
    warning on;
    
    varnames = csvdata.Properties.VariableNames;
    i=1;
    while i<length(varnames)    
        a = strfind(varnames{i},'Var');
        if ~isempty(a)
            data_first_col = i;
            break
        end
        i=i+1;
    end                    
    
    %data_first_col = 14; % first column of the Sv data vector in each row
    datavals = table2array(csvdata(:,data_first_col:end));
    datavals = reshape(datavals',1,[]);
    datavals(datavals<-998) = NaN; % set -999 to NaN      
