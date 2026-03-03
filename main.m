
clear all; clc; close;

%% Load the HPPC Test Data

import simscape.battery.parameters.*

% --- Selection ---
cellID = '1_8'; % Change to '1_9' here to switch cells
filePrefix = sprintf('cell_%s_', cellID);

data_path = 'sdi_processed/mat';

% Define your common settings
commonArgs = {"TimeVariable", "time (s)", ...
              "VoltageVariable", "voltage (V)", ...
              "CurrentVariable", "current (A)", ...
              "Capacity", 51.82056, ...
              "InitialSOC", 0.0, ...
              "ValidPulseDurationRange", [15, 35], ...
              "CurrentOnThreshold", 0.1, ... % Increased slightly to avoid noise
              "CurrentSignConvention", "negativeDischarge"}; 

% --- Load -5C ---
fname_m5 = fullfile(data_path, sprintf('%shppc_minus5degC_processed.mat', filePrefix));
load(fname_m5); % Loads 'tempData'
hppcExpMinus5degC = hppcTest(tempData, commonArgs{:}, ...
    Temperature=repmat(268.15, height(tempData), 1));
clear tempData;

% --- Load 10C ---
fname_10 = fullfile(data_path, sprintf('%shppc_10degC_processed.mat', filePrefix));
load(fname_10); 
hppcExp10degC = hppcTest(tempData, commonArgs{:}, ...
    Temperature=repmat(283.15, height(tempData), 1));
clear tempData;

% --- Load 25C ---
fname_25 = fullfile(data_path, sprintf('%shppc_25degC_processed.mat', filePrefix));
load(fname_25); 
hppcExp25degC = hppcTest(tempData, commonArgs{:}, ...
    Temperature=repmat(298.15, height(tempData), 1));
clear tempData;

% --- Load 45C ---
fname_45 = fullfile(data_path, sprintf('%shppc_45degC_processed.mat', filePrefix));
load(fname_45); 
hppcExp45degC = hppcTest(tempData, commonArgs{:}, ...
    Temperature=repmat(318.15, height(tempData), 1));
clear tempData;

% --- Create the Suite ---
% Note: Suite expects Temp in Kelvin if the tests are in Kelvin
hppcSuite = hppcTestSuite([hppcExpMinus5degC; hppcExp10degC; hppcExp25degC; hppcExp45degC], ...
    Temperature=[268.15; 283.15; 298.15; 318.15]);

fprintf('--- Suite Summary for Cell %s ---\n', cellID);
disp(hppcSuite.SuiteSummary)

%% Plot and visualize
% 
% 
disp(hppcExp25degC.TestSummary)

plot(hppcExp25degC)

% plotPulse(hppcExp25degC)

%% Modify breakpoints

% 1. Define the 2-RC Model Structure

NumRCPairs = 2;
myEcm = ecm(NumRCPairs);

myEcm.ModelParameterTables = ["ResistanceSOCBreakpoints", "ResistanceCurrentBreakpoints", "ResistanceTemperatureBreakpoints"];

myEcm.SOCBreakpoints = simscape.Value([0, 0.05, 0.15, 0.25, 0.40, 0.50, 0.60, 0.70, 0.85, 1], "1");
myEcm.ResistanceSOCBreakpoints = simscape.Value([0, 0.05, 0.15, 0.25, 0.40, 0.50, 0.60, 0.70, 0.85, 1], "1");
myEcm.ResistanceCurrentBreakpoints = simscape.Value([24.75, 49.5, 74.25, 99], "A");

% myEcm.ResistanceTemperatureBreakpoints = 273.15 + [25]; % MATLAB will convert these to Kelvin
% myEcm.TemperatureBreakpoints = 273.15 + [25];

myEcm.TemperatureBreakpoints = simscape.Value(273.15 + [-5, 10, 25, 45], "K");
myEcm.ResistanceTemperatureBreakpoints = simscape.Value(273.15 + [-5, 10, 25, 45], "K"); % MATLAB will convert these to Kelvin

batteryEcm = fitECM(hppcSuite, ...
                    ECM=myEcm, ...
                    SegmentToFit="relaxation", ...
                    FittingMethod="curvefit", ...
                    TimeStep=1); 

disp(batteryEcm.TestParameterTables)

%%

% 1. Extract the values from the fitted model
% R0_data will be a 3D matrix: [SOC_index, Temp_index, Current_index]
R0_data = batteryEcm.ModelParameterTables.R0.Value; 
soc_axis = batteryEcm.ResistanceSOCBreakpoints.Value;
curr_axis = batteryEcm.ResistanceCurrentBreakpoints.Value;
temp_axis = batteryEcm.ResistanceTemperatureBreakpoints.Value;

% 2. Pick a temperature index to visualize (e.g., 25°C)
% Let's find the index closest to 298.15K
[~, temp_idx] = min(abs(temp_axis - 298.15));

% 3. Extract the 2D slice for that temperature
% Slice syntax: R0_slice(SOC, Current)
R0_slice = squeeze(R0_data(:, temp_idx, :));

% 4. Create the Plot
figure('Color', 'w');
surf(curr_axis, soc_axis, R0_slice);

% Formatting
xlabel('Current (A)');
ylabel('SOC (unitless)');
zlabel('R0 Resistance (Ohm)');
title(sprintf('R0 Surface at %g K', temp_axis(temp_idx)));
colorbar;
grid on;
view(45, 30); % Adjust angle for better perspective


%% Plot RC Model parameters

batteryEcm.plotModelParameters();

%% Simulate and plot tuned ECM on a selected pulse

plot(batteryEcm, 1)

%% Simulate the Fit hppc data

simulateHPPCTest(batteryEcm, hppcExp45degC)


%% Custom pulse fit


NumRCPairs = 2;
myEcm = ecm(NumRCPairs);

% % 1. Extract the table for the specific pulse
% pulseIndex = 33;
% pulseData = hppcExpMinus5degC.TestSummary.HPPCData{pulseIndex};

% % 2. Identify the column names (Standard HPPCData names are 'Current' and 'Voltage')
% batteryEcm = fitECM(pulseData(:,1:2), ...
%     SegmentToFit = "loadAndRelaxation", ...
%     FittingMethod="curvefit"); % Force start point match); 

batteryEcm = fitECM(hppcExp25degC, ...
    SegmentToFit = "relaxation", ...
    FittingMethod="curvefit"); % Force start point match); 

batteryEcm.plotModelParameters();

% % 3. Display and Plot
% disp(batteryEcm);
% plot(batteryEcm);
% 
% % To see the R and C values calculated for this specific pulse:
% disp(batteryEcm.ModelParameterTables);