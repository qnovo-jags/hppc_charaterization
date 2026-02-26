clear all; clc; close all;

% FIX: Use curly braces {} to create a Cell Array of strings
temps = {'minus5', '10', '25', '45'}; 

% --- Processing Configuration ---
doResample = true; 
resampleRate = 1;  

% --- File Configuration ---
filePrefix = 'cell_1_9_'; % Change this to 'cell_1_9_' as needed

% fileNames = {'hppc_data_minus5C.csv', 'hppc_data_10C.csv', 'hppc_data_25C.csv', 'hppc_data_45C.csv'};
temps = {'minus5', '10', '25', '45'}; 

data_path = 'sdi_processed';
mat_path = fullfile(data_path, 'mat');

if ~exist(mat_path, 'dir'), mkdir(mat_path); end


for i = 1:length(temps)
    
    csvBaseName = sprintf('%shppc_data_%sC.csv', filePrefix, temps{i});
    filePath = fullfile(data_path, csvBaseName);
    
    if exist(filePath, 'file')
        rawTable = readtable(filePath);
        
        if doResample
            % Normalize time and create timetable
            timeDuration = seconds(rawTable.Time_s_ - rawTable.Time_s_(1));
            tt = table2timetable(rawTable(:, {'SEVolt__V_', 'SECurr__A_'}), 'RowTimes', timeDuration);
            
            % Resample V (linear) and I (previous)
            tt_v = retime(tt(:, 'SEVolt__V_'), 'regular', 'linear', 'TimeStep', seconds(resampleRate));
            tt_i = retime(tt(:, 'SECurr__A_'), 'regular', 'previous', 'TimeStep', seconds(resampleRate));
            tt_resampled = [tt_v, tt_i];
            
            tempData = table();
            tempData.("time (s)") = seconds(tt_resampled.Time); 
            tempData.("voltage (V)") = tt_resampled.SEVolt__V_;
            tempData.("current (A)") = tt_resampled.SECurr__A_;
        else
            tempData = table();
            tempData.("time (s)") = rawTable.Time_s_;
            tempData.("voltage (V)") = rawTable.SEVolt__V_;
            tempData.("current (A)") = rawTable.SECurr__A_;
        end
        
        tempData = rmmissing(tempData);
        
        % --- Updated Save Logic with Prefix ---
        baseName = sprintf('%shppc_%sdegC_processed.mat', filePrefix, temps{i});
        saveName = fullfile(mat_path, baseName);
        save(saveName, 'tempData');
        
        fprintf('Saved: %s\n', baseName);
    end
end