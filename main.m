
clear all; clc; close;

%% Load the HPPC Test Data

import simscape.battery.parameters.*

% --- Selection ---
cellID = '1_8'; % Change to '1_9' here to switch cells

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

% User-provided OCV curve (SOC fraction vs OCV in volts)
ocvCurvePath = 'sdi_processed/rev1_ocv_curve.csv';
ocvCurve = readtable(ocvCurvePath);
ocvCurve = ocvCurve(:, {'SoC_fraction', 'OCV_V'});
ocvCurve = sortrows(ocvCurve, 'SoC_fraction');
ocvCurve.SoC_fraction = max(0, min(1, ocvCurve.SoC_fraction));

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

disp(hppcSuite.SuiteSummary)

testsForPlot = [hppcExpMinus5degC, hppcExp10degC, hppcExp25degC, hppcExp45degC];
plotTempsK = [268.15, 283.15, 298.15, 318.15];
for k = 1:numel(testsForPlot)
    figure('Name', sprintf('HPPC %.2f K', plotTempsK(k)));
    plot(testsForPlot(k));
end

%% Modify breakpoints

% 1. Define the 2-RC Model Structure
NumRCPairs = 2;
myEcm = ecm(NumRCPairs);

% Choose the HPPC source to fit.
% Valid values: "hppcExpMinus5degC", "hppcExp10degC", "hppcExp25degC", "hppcExp45degC", "hppcSuite"
choose_hppc_name = "hppcExp25degC"; % Change this value to select which HPPC test to fit against

switch choose_hppc_name
    case "hppcExpMinus5degC"
        choose_hppc = hppcExpMinus5degC;
        fitTempsK = [268.15];
    case "hppcExp10degC"
        choose_hppc = hppcExp10degC;
        fitTempsK = [283.15];
    case "hppcExp25degC"
        choose_hppc = hppcExp25degC;
        fitTempsK = [298.15];
    case "hppcExp45degC"
        choose_hppc = hppcExp45degC;
        fitTempsK = [318.15];
    case "hppcSuite"
        choose_hppc = hppcSuite;
        fitTempsK = [268.15, 283.15, 298.15, 318.15];
    otherwise
        error('Unsupported choose_hppc_name: %s', choose_hppc_name);
end

myEcm.ModelParameterTables = ["ResistanceSOCBreakpoints", "ResistanceCurrentBreakpoints", "ResistanceTemperatureBreakpoints"];

myEcm.SOCBreakpoints = simscape.Value([0, 0.05, 0.15, 0.25, 0.40, 0.50, 0.60, 0.70, 0.85, 1], "1");
myEcm.ResistanceSOCBreakpoints = simscape.Value([0, 0.05, 0.15, 0.25, 0.40, 0.50, 0.60, 0.70, 0.85, 1], "1");
myEcm.ResistanceCurrentBreakpoints = simscape.Value([24.75, 49.5, 74.25, 99], "A");
myEcm.ResistanceTemperatureBreakpoints = simscape.Value(fitTempsK, "K");
myEcm.TemperatureBreakpoints = simscape.Value(fitTempsK, "K");

% 2. Fit the ECM to the chosen HPPC test
batteryEcm = fitECM(choose_hppc, ...
                    ECM=myEcm, ...
                    SegmentToFit="relaxation", ...
                    FittingMethod="curvefit", ...
                    TimeStep=1); 

disp(batteryEcm.TestParameterTables)

runIsolatedPlotCall(@() batteryEcm.plotModelParameters(), "ECM Model Parameters");

if choose_hppc_name == "hppcSuite"
    % simulateHPPCTest expects a single hppcTest; run once per temperature test.
    testsForSim = [hppcExpMinus5degC, hppcExp10degC, hppcExp25degC, hppcExp45degC];
    for k = 1:numel(testsForSim)
        fprintf('Simulating suite member %d/%d at %.2f K\n', k, numel(testsForSim), fitTempsK(k));
        figure('Name', sprintf('Simulation %.2f K', fitTempsK(k)), 'NumberTitle', 'off');
        hold off;
        simulateHPPCTest(batteryEcm, testsForSim(k));
    end
else
    figure('Name', sprintf('Simulation %.2f K', fitTempsK(1)), 'NumberTitle', 'off');
    hold off;
    simulateHPPCTest(batteryEcm, choose_hppc);
end


%% Helper function 

function newFigs = runIsolatedPlotCall(plotFcn, baseName)
% Run a plotting call and tag figures created by this call only.
    figsBefore = findall(groot, 'Type', 'figure');
    plotFcn();
    drawnow;
    figsAfter = findall(groot, 'Type', 'figure');
    newFigs = setdiff(figsAfter, figsBefore);

    if isempty(newFigs)
        return;
    end

    newFigs = flipud(newFigs(:));
    for i = 1:numel(newFigs)
        if strlength(baseName) > 0
            if numel(newFigs) == 1
                thisName = baseName;
            else
                thisName = sprintf('%s (%d)', baseName, i);
            end
            set(newFigs(i), 'Name', thisName, 'NumberTitle', 'off');
        end
    end
end
