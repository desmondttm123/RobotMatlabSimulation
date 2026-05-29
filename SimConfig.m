%% SimConfig.m - Shared simulation parameters
% Edit this file to change parameters for both QuickView and TrackSimulation.
% Run this script (or call it from other scripts) to load 'cfg' into workspace.

cfg = struct();

%% Frequency
cfg.freq = 2.45e9;              % Hz

%% Sensor Array
cfg.arrayWidth = 100;           % mm (PCB width)
cfg.arrayHeight = 100;          % mm (PCB height)
cfg.nCols = 4;                  % columns in RX grid
cfg.nRows = 8;                  % rows in RX grid
cfg.tilt_angle = 45;            % degrees (tilt toward ground)
cfg.sensor_z = 95.26;           % mm (height above ground)
cfg.sensor1_x = -90;            % mm (Sensor 1 X position)
cfg.sensor2_x = 90;             % mm (Sensor 2 X position)

%% Track
cfg.track_y_start = 0;          % mm
cfg.track_y_end = 20000;        % mm (20 meters)
cfg.track_y_step = 10;          % mm (step size)
cfg.track_width = 1500;         % mm (total ground width in X)

%% Objects (voids embedded in ground)
cfg.obj_x_half = 250;           % mm (half-width in X, so 500mm total)
cfg.obj_y_half = 150;           % mm (half-length in Y, so 300mm total)
cfg.obj_z_top = -30;            % mm (top of object below ground surface)
cfg.obj_z_bottom = -150;         % mm (bottom of object)
cfg.obj_er = 1.0;               % relative permittivity (air/void)
cfg.obj_sigma = 0;              % conductivity S/m (air)
cfg.obj_y_centers = [3200, 8500, 14100, 18000];  % mm (Y positions)
cfg.obj_names = {'Object 1', 'Object 2', 'Object 3', 'Object 4'};

%% Terrain definitions
cfg.terrains(1).name = 'DrySand';     cfg.terrains(1).er = 3.5;   cfg.terrains(1).sigma = 0.001;
cfg.terrains(2).name = 'GrassySoil';  cfg.terrains(2).er = 15.0;  cfg.terrains(2).sigma = 0.05;
cfg.terrains(3).name = 'Rocks';       cfg.terrains(3).er = 7.0;   cfg.terrains(3).sigma = 0.005;

%% Power levels (dBm)
cfg.low_power_range = [-4, -2];     % Low power TX range
cfg.high_power_range = [0, 2];      % High power TX range

%% Antenna gains (dBi)
cfg.G_tx = 2.0;
cfg.G_rx = 2.0;

%% RF channel model parameters
cfg.pattern_loss_direct = 25;   % dB (off-boresight loss for direct LOS path)
cfg.pattern_loss_reflected = 0; % dB (reflected path aligned with boresight)
cfg.noise_std = 0.05;           % dB (RSSI measurement noise std dev)

%% Robot STL
cfg.robot_stl_path = '3D/RhinoV2Low.stl';
cfg.robot_y_offset = -500;      % mm
cfg.robot_z_offset = 150;       % mm

%% Output directory (all results go here)
cfg.output_dir = 'Results';
if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end
