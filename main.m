
clear all; clc; close;

%% Load the HPPC Test Data

import simscape.battery.parameters.*

% --- Selection ---
cellID = '1_9'; % Change to '1_9' here to switch cells

switch cellID
    case '1_8'
        Capacity = 52.11744; % mAh
    case '1_9'
        Capacity = 51.82056; % mAh
    otherwise
        error('Unsupported cellID: %s. Supported values are ''1_8'' and ''1_9''.', cellID);
end

filePrefix = sprintf('cell_%s_', cellID);
data_path = 'sdi_processed/mat';

% % User-provided OCV curve (SOC fraction vs OCV in volts)
% ocvCurvePath = 'sdi_processed/rev1_ocv_curve.csv';
% ocvCurve = readtable(ocvCurvePath);
% ocvCurve = ocvCurve(:, {'SoC_fraction', 'OCV_V'});
% ocvCurve = sortrows(ocvCurve, 'SoC_fraction');
% ocvCurve.SoC_fraction = max(0, min(1, ocvCurve.SoC_fraction));

% Build shared HPPC parser args, injecting initialSoC loaded per file.
buildCommonArgs = @(initialSoC) {"TimeVariable", "time (s)", ...
                                 "VoltageVariable", "voltage (V)", ...
                                 "CurrentVariable", "current (A)", ...
                                 "Capacity", Capacity, ...
                                 "InitialSOC", initialSoC, ...
                                 "ValidPulseDurationRange", [20, 35], ...
                                 "CurrentOnThreshold", 0.1, ... % Increased slightly to avoid noise
                                 "CurrentSignConvention", "negativeDischarge"}; 

% --- Load -5C ---
fname_m5 = fullfile(data_path, sprintf('%shppc_minus5degC_processed.mat', filePrefix));
data_m5 = load(fname_m5, 'tempData', 'initialSoC');
assert(isfield(data_m5, 'initialSoC') && isfinite(data_m5.initialSoC), ...
    'Missing valid initialSoC in %s. Re-run convert_csv_format_to_mat.m.', fname_m5);
args_m5 = buildCommonArgs(data_m5.initialSoC);
hppcExpMinus5degC = hppcTest(data_m5.tempData, args_m5{:}, ...
    Temperature=repmat(268.15, height(data_m5.tempData), 1));

% --- Load 10C ---
fname_10 = fullfile(data_path, sprintf('%shppc_10degC_processed.mat', filePrefix));
data_10 = load(fname_10, 'tempData', 'initialSoC');
assert(isfield(data_10, 'initialSoC') && isfinite(data_10.initialSoC), ...
    'Missing valid initialSoC in %s. Re-run convert_csv_format_to_mat.m.', fname_10);
args_10 = buildCommonArgs(data_10.initialSoC);
hppcExp10degC = hppcTest(data_10.tempData, args_10{:}, ...
    Temperature=repmat(283.15, height(data_10.tempData), 1));

% --- Load 25C ---
fname_25 = fullfile(data_path, sprintf('%shppc_25degC_processed.mat', filePrefix));
data_25 = load(fname_25, 'tempData', 'initialSoC');
assert(isfield(data_25, 'initialSoC') && isfinite(data_25.initialSoC), ...
    'Missing valid initialSoC in %s. Re-run convert_csv_format_to_mat.m.', fname_25);
args_25 = buildCommonArgs(data_25.initialSoC);
hppcExp25degC = hppcTest(data_25.tempData, args_25{:}, ...
    Temperature=repmat(298.15, height(data_25.tempData), 1));

% --- Load 45C ---
fname_45 = fullfile(data_path, sprintf('%shppc_45degC_processed.mat', filePrefix));
data_45 = load(fname_45, 'tempData', 'initialSoC');
assert(isfield(data_45, 'initialSoC') && isfinite(data_45.initialSoC), ...
    'Missing valid initialSoC in %s. Re-run convert_csv_format_to_mat.m.', fname_45);
args_45 = buildCommonArgs(data_45.initialSoC);
hppcExp45degC = hppcTest(data_45.tempData, args_45{:}, ...
    Temperature=repmat(318.15, height(data_45.tempData), 1));

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
choose_hppc = hppcExpMinus5degC; % Choose the HPPC test to fit

myEcm.ModelParameterTables = ["ResistanceSOCBreakpoints", "ResistanceCurrentBreakpoints", "ResistanceTemperatureBreakpoints"];

myEcm.SOCBreakpoints = simscape.Value([0, 0.05, 0.15, 0.25, 0.40, 0.50, 0.60, 0.70, 0.85, 1], "1");
myEcm.ResistanceSOCBreakpoints = simscape.Value([0, 0.05, 0.15, 0.25, 0.40, 0.50, 0.60, 0.70, 0.85, 1], "1");
myEcm.ResistanceCurrentBreakpoints = simscape.Value([24.75, 49.5, 74.25, 99], "A");

myEcm.ResistanceTemperatureBreakpoints = simscape.Value([268.15, 283.15, 298.15, 318.15], "K");
myEcm.TemperatureBreakpoints = simscape.Value([268.15, 283.15, 298.15, 318.15], "K");
% myEcm.ResistanceTemperatureBreakpoints = simscape.Value([298.15], "K");
% myEcm.TemperatureBreakpoints = simscape.Value([298.15], "K");

% 2. Fit the ECM to the chosen HPPC test
batteryEcm = fitECM(choose_hppc, ...
                    ECM=myEcm, ...
                    SegmentToFit="relaxation", ...
                    FittingMethod="curvefit", ...
                    TimeStep=1); 

disp(batteryEcm.TestParameterTables)

% batteryEcm.plotModelParameters();

simulateHPPCTest(batteryEcm, choose_hppc);
