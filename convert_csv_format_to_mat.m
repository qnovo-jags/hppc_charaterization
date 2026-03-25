clear all; clc; close all;

% --- Processing Configuration ---
doResample = false; 
resampleRate = 1;  

% --- File Configuration ---
filePrefix = 'cell_1_9_'; % Change this to 'cell_1_9_' as needed

temps = {'minus5', '10', '25', '45'}; 

data_path = 'sdi_processed';
mat_path = fullfile(data_path, 'mat');

if ~exist(mat_path, 'dir'), mkdir(mat_path); end


for i = 1:length(temps)
    
    csvBaseName = sprintf('%shppc_data_%sC.csv', filePrefix, temps{i});
    filePath = fullfile(data_path, csvBaseName);
    
    if exist(filePath, 'file')
        rawTable = readtable(filePath);

        % Extract initial SoC from any column containing "soc".
        socColIdx = find(contains(lower(rawTable.Properties.VariableNames), 'soc'), 1);
        initialSoC = NaN;
        if ~isempty(socColIdx)
            socValues = rawTable{:, socColIdx};
            if iscell(socValues) || isstring(socValues)
                socValues = str2double(string(socValues));
            end
            socValues = socValues(isfinite(socValues));
            if ~isempty(socValues)
                initialSoC = socValues(1);
                % Normalize to fraction if SoC is provided in percent.
                if initialSoC > 1
                    initialSoC = initialSoC / 100;
                end
                initialSoC = max(0, min(1, initialSoC));
            end
        end
        
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
        save(saveName, 'tempData', 'initialSoC');
        
        fprintf('Saved: %s (initialSoC = %.6f)\n', baseName, initialSoC);
    end
end