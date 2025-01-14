function check_ecs(ecs_file)
% function to check whether the channels in the ecs file match those of the
% recorded data. If not will write over the existing ecsfile to ensure that
% channels match frequency.
% Preconditions
% 
% Channel sequence : 18, 38, 70, 120, 200 is needed to harmonize with
% Echoview IMOS template v1.26 or higher. If other frequencies come in to the IMOS template then
% suggest they get added above the 200 kHz with 12 kHz next followed by 333kHz.
% The code below supports this sequence. 
%
%
% If Echoview or users mess with the default formatting of the ecs file
% this might utility might crash. If so it will need to be adjusted to
% suit, or user should return to standard echoview format. If standard
% echoview format for the ecs file changes then you will definately have to
% mod this code, but shouldn't be too hard. This code is based on the
% example file below. 


% Tim Ryan
% 25/11/2019
% % % 
% % % #========================================================================================#
% % % #              ECHOVIEW CALIBRATION SUPPLEMENT (.ECS) FILE (Ex60_Ex70_EK15)              #
% % % #                                11/03/2019 21:19:59.8010                                #
% % % #========================================================================================#
% % % #       +----------+   +-----------+   +----------+   +-----------+   +----------+       #
% % % #       | Default  |-->| Data File |-->| Fileset  |-->| SourceCal |-->| LocalCal |       #
% % % #       | Settings |   | Settings  |   | Settings |   | Settings  |   | Settings |       #
% % % #       +----------+   +-----------+   +----------+   +-----------+   +----------+       #
% % % # - Settings to the right override those to their left.                                  #
% % % # - See the Help file page "About calibration".                                          #
% % % #========================================================================================#
% % % 
% % % Version 1.00
% % % 
% % % 
% % % #========================================================================================#
% % % #                                    FILESET SETTINGS                                    #
% % % #========================================================================================#
% % % 
% % % # SoundSpeed = # (meters per second) [1400.00..1700.00]
% % % # TvgRangeCorrection = # [None, BySamples, SimradEx500, SimradEx60, BioSonics, Kaijo, PulseLength, Ex500Forced, SimradEK80, Standard]
% % % # TvgRangeCorrectionOffset = # (samples) [-10000.00..10000.00]
% % % 
% % % 
% % % #========================================================================================#
% % % #                                   SOURCECAL SETTINGS                                   #
% % % #========================================================================================#
% % % 
% % % SourceCal T2
% % %     # AbsorptionCoefficient = 0.0097853 # (decibels per meter) [0.0000000..100.0000000]
% % %     # EK60SaCorrection = 0.0000 # (decibels) [-99.9900..99.9900]
% % %     # Ek60TransducerGain = 25.9000 # (decibels) [1.0000..99.0000]
% % %     # Frequency = 38.00 # (kilohertz) [0.01..10000.00]
% % %     # MajorAxis3dbBeamAngle = 7.20 # (degrees) [0.00..359.99]
% % %     # MajorAxisAngleOffset = 0.00 # (degrees) [-9.99..9.99]
% % %     # MajorAxisAngleSensitivity = 27.156000 # [0.100000..100.000000]
% % %     # MinorAxis3dbBeamAngle = 7.24 # (degrees) [0.00..359.99]
% % %     # MinorAxisAngleOffset = 0.00 # (degrees) [-9.99..9.99]
% % %     # MinorAxisAngleSensitivity = 23.518000 # [0.100000..100.000000]
% % %     # SoundSpeed = 1493.89 # (meters per second) [1400.00..1700.00]
% % %     # TransmittedPower = 2000.00000 # (watts) [1.00000..30000.00000]
% % %     # TransmittedPulseLength = 2.048 # (milliseconds) [0.001..50.000]
% % %     # TvgRangeCorrection = SimradEx60 # [None, BySamples, SimradEx500, SimradEx60, BioSonics, Kaijo, PulseLength, Ex500Forced, SimradEK80, Standard]
% % %     # TwoWayBeamAngle = -20.100000 # (decibels re 1 steradian) [-99.000000..-1.000000]
% % % 
% % % SourceCal T1
% % %      AbsorptionCoefficient = 0.001600 # (decibels per meter) [0.0000000..100.0000000]
% % %      EK60SaCorrection = -0.67 # (decibels) [-99.9900..99.9900]
% % %      Ek60TransducerGain = 23.16000 # (decibels) [1.0000..99.0000]
% % %      Frequency = 18.00 # (kilohertz) [0.01..10000.00]
% % %      MajorAxis3dbBeamAngle = 11.7 # (degrees) [0.00..359.99]
% % %     # MajorAxisAngleOffset = 0.00 # (degrees) [-9.99..9.99]
% % %     # MajorAxisAngleSensitivity = 13.900000 # [0.100000..100.000000]
% % %      MinorAxis3dbBeamAngle = 11.8 # (degrees) [0.00..359.99]
% % %     # MinorAxisAngleOffset = 0.00 # (degrees) [-9.99..9.99]
% % %     # MinorAxisAngleSensitivity = 13.900000 # [0.100000..100.000000]
% % %      SoundSpeed = 1500 # (meters per second) [1400.00..1700.00]
% % %     # TransmittedPower = 2000.00000 # (watts) [1.00000..30000.00000]
% % %     # TransmittedPulseLength = 2.048 # (milliseconds) [0.001..50.000]
% % %     # TvgRangeCorrection = SimradEx60 # [None, BySamples, SimradEx500, SimradEx60, BioSonics, Kaijo, PulseLength, Ex500Forced, SimradEK80, Standard]
% % %      TwoWayBeamAngle = -16.050000 # (decibels re 1 steradian) [-99.000000..-1.000000]
% % % 


channel_sequence = [{18}, {38}, {70},{120}, {200}, {333}, {12}];

fid = fopen(ecs_file,'r');
a=0;b=0; j=1; check=1;
while ~feof(fid)
    ln = fgetl(fid);
    if ~isempty(strfind(ln,'SourceCal'))
        channel_id = ln(strfind(ln,'T')+1);
        a = 1;
    end
    if ~isempty(strfind(ln,'Frequency')) && isempty(strfind(ln,'SamplingFrequency')) % nasty way to rat ou the frequency while trying to keep it a bit robust
        ln = ln(1:strfind(ln,'kilohertz'));
        ln = ln(strfind(ln,'=')+1:end);
        ln = ln(1: strfind(ln,'#')-1);
        freq = str2num(strtrim(ln));
        b = 1;
    end
    if isequal(a,1) & isequal(b,1) % we have a match            
            a=0; b=0;            
            for m=1:length(channel_sequence)
                if isequal(freq,channel_sequence{m})
                    new_channel_id{j} = num2str(m);                    
                end
            end                        
            j=j+1;
    end
end
fclose(fid);

% now write back out to the ecs file    
new_ecs_file = [ecs_file(1:end-4) '_new.ecs'];
fid = fopen(ecs_file,'r');        
fid1 = fopen(new_ecs_file,'w+');

i=1;
while ~feof(fid)
    ln = fgetl(fid);
    is_sourcecal = strfind(ln,'SourceCal'); % the word SourceCal has to exisst and be at the start of the line (i.e. that word in the header doesn't count
        
    if isequal(is_sourcecal,1)            
       newline = ['SourceCal T' new_channel_id{i}];
       fprintf(fid1,'%s\n',newline);
       i=i+1;
    else
        fprintf(fid1,'%s\n',ln);
    end
end
fclose('all');

% HK-26/11/2019: Avoid modifying the original ECS file if there is no
% difference between original and new ECS file. Also, warn user if there is
% difference, useful to know ECS file has been modified.

[status,result] = system(['fc ' new_ecs_file ' ' ecs_file]); % only for Windows

if status == 0
    delete (new_ecs_file) % delete this duplicate copy to avoid confusion
else
    file_location = split(ecs_file,'\');
    warning('SourceCal numbering in the ECS file is not matching with template, modifying %s',cell2mat(file_location(end)))
    movefile(new_ecs_file, ecs_file,'f');
end



