
clear all; clc; close;

%% Load the HPPC Test Data

import simscape.battery.parameters.*

% cell_capacities = {
%     '1-8': 52.11744,
%     '1-9': 51.82056,
% }

% --- Selection ---
cellID = '1_8'; % Change to '1_9' here to switch cells
initialSOC25C = 0.15586; % Assuming tests start at 0% SOC, adjust if needed
initialSOC45C = 0.038521; % Adjust if needed based on test conditions
initialSOC = initialSOC45C; % Change to initialSOC45C if using 45

Capacity = 52.11744; % mAh, adjust if needed based on cellID
filePrefix = sprintf('cell_%s_', cellID);
data_path = 'sdi_processed/mat';

% User-provided OCV curve (SOC fraction vs OCV in volts)
ocvCurvePath = 'sdi_processed/rev1_ocv_curve.csv';
ocvCurve = readtable(ocvCurvePath);
ocvCurve = ocvCurve(:, {'SoC_fraction', 'OCV_V'});
ocvCurve = sortrows(ocvCurve, 'SoC_fraction');
ocvCurve.SoC_fraction = max(0, min(1, ocvCurve.SoC_fraction));

% Define your common settings
commonArgs = {"TimeVariable", "time (s)", ...
              "VoltageVariable", "voltage (V)", ...
              "CurrentVariable", "current (A)", ...
              "Capacity", Capacity, ...
              "InitialSOC", initialSOC, ...
              "ValidPulseDurationRange", [20, 35], ...
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

disp(hppcExp25degC.TestSummary)

plot(hppcExp25degC)

% plotPulse(hppcExp25degC)

%% Modify breakpoints

% 1. Define the 2-RC Model Structure

NumRCPairs = 2;
myEcm = ecm(NumRCPairs);
choose_hppc = hppcExp45degC; % Choose the HPPC test to fit

myEcm.ModelParameterTables = ["ResistanceSOCBreakpoints", "ResistanceCurrentBreakpoints", "ResistanceTemperatureBreakpoints"];

myEcm.SOCBreakpoints = simscape.Value([0, 0.05, 0.15, 0.25, 0.40, 0.50, 0.60, 0.70, 0.85, 1], "1");
myEcm.ResistanceSOCBreakpoints = simscape.Value([0, 0.05, 0.15, 0.25, 0.40, 0.50, 0.60, 0.70, 0.85, 1], "1");
myEcm.ResistanceCurrentBreakpoints = simscape.Value([24.75, 49.5, 74.25, 99], "A");

% myEcm.ResistanceTemperatureBreakpoints = simscape.Value([268.15, 283.15, 298.15, 318.15], "K");
% myEcm.TemperatureBreakpoints = simscape.Value([268.15, 283.15, 298.15, 318.15], "K");
myEcm.ResistanceTemperatureBreakpoints = simscape.Value([298.15], "K");
myEcm.TemperatureBreakpoints = simscape.Value([298.15], "K");

% 2. Fit the ECM to the chosen HPPC test
batteryEcm = fitECM(hppcExp25degC, ...
                    ECM=myEcm, ...
                    SegmentToFit="relaxation", ...
                    FittingMethod="curvefit", ...
                    TimeStep=1); 

disp(batteryEcm.TestParameterTables)

% batteryEcm.plotModelParameters();

simulateHPPCTest(batteryEcm, hppcExp25degC);
