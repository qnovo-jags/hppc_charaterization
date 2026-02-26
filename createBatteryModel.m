% Create Simulink Model
% Create and open a Simulink model. Define the name of your model and use the open_system function.
modelname = "batteryModel";
open_system(new_system(modelname));

% This example programmatically adds all the blocks required to simulate the battery module model. To add these blocks, define their block paths as variables in your workspace.
batteryBlockPath = strcat(modelname,"/","Battery01");
electricalRefBlockPath = strcat(modelname,"/","ElectricalReference");
solverConfigBlockPath = strcat(modelname,"/","Solver");
currentSourceBlockPath = strcat(modelname,"/","Controlled Current Source");

% Add the blocks to the model using the add_block function.
add_block("batt_lib/Cells/Battery Equivalent Circuit",batteryBlockPath,position=[190,100,340,250],ShowName="off");
add_block("fl_lib/Electrical/Electrical Elements/Electrical Reference",electricalRefBlockPath,position=[215,320,235,340],orientation="down",ShowName="off");
add_block("nesl_utility/Solver Configuration",solverConfigBlockPath,position=[50,280,90,320],ShowName="off");
add_block("fl_lib/Electrical/Electrical Sources/DC Current Source",currentSourceBlockPath,position=[50,150,80,200],orientation="down",i0=num2str(-27),ShowName="off");

% Get the handles to the block ports and connect all blocks.
batteryBlockPortHandles = get_param(batteryBlockPath,"PortHandles");
electricalRefBlockPortHandles = get_param(electricalRefBlockPath,"PortHandles");
solverConfigBlockPortHandles = get_param(solverConfigBlockPath,"PortHandles");
currentSourceBlockPortHandles = get_param(currentSourceBlockPath,"PortHandles");

add_line(modelname,batteryBlockPortHandles.RConn,currentSourceBlockPortHandles.RConn,autorouting="smart");
add_line(modelname,batteryBlockPortHandles.LConn,currentSourceBlockPortHandles.LConn,autorouting="smart");
add_line(modelname,batteryBlockPortHandles.RConn,electricalRefBlockPortHandles.LConn,autorouting="smart");
add_line(modelname,batteryBlockPortHandles.RConn,solverConfigBlockPortHandles.RConn,autorouting="smart");

% Copyright 2024 The MathWorks, Inc.