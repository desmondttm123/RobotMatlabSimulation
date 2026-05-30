%% ro2_config.m - RO2 Simulation Configuration
% Defines all parameters for the RO2 single-antenna material density
% classification experiment.
%
% Geometry: 200mm x 200mm x 200mm terrain block
% Antenna: single downward-facing sensor at (0, 0, 30mm)
% Task: classify 12 material density classes from raw RSSI

cfg = struct();

%% Frequency
cfg.freq = 2.45e9;              % Hz (2.45 GHz ISM band)
cfg.c = 3e8;                    % speed of light (m/s)
cfg.lambda = cfg.c / cfg.freq;  % wavelength (~122.4 mm)

%% Antenna Setup (single sensor, downward-facing)
cfg.antenna_x = 0;             % mm
cfg.antenna_y = 0;             % mm
cfg.antenna_z = 30;            % mm (height above ground plane)
cfg.tilt_angle = 90;           % degrees (90 = straight down)

% RX array: 4x4 grid spread across the terrain surface (wide footprint)
% Each RX samples a different region of the 200x200mm terrain below
cfg.array_width = 160;         % mm (spread across terrain for spatial diversity)
cfg.array_height = 160;        % mm
cfg.nCols = 4;                 % columns in RX grid
cfg.nRows = 4;                 % rows in RX grid
cfg.nRX = cfg.nCols * cfg.nRows;  % 16 RX elements
cfg.nTotal = cfg.nRX + 1;     % 16 RX + 1 TX

%% Antenna gains
cfg.G_tx = 2.0;                % dBi
cfg.G_rx = 2.0;                % dBi

%% RF channel model
cfg.pattern_loss_off_boresight = 25;  % dB (off-boresight attenuation)
cfg.pattern_loss_boresight = 0;       % dB (boresight = downward)
cfg.noise_std = 0.05;                 % dB (RSSI measurement noise)

%% Power levels
cfg.low_power_range = [-4, -2];    % dBm (low TX power)
cfg.high_power_range = [0, 2];     % dBm (high TX power)

%% Terrain Geometry
cfg.terrain_x_range = [-100, 100];    % mm (X: -100 to +100)
cfg.terrain_y_range = [-100, 100];    % mm (Y: -100 to +100)
cfg.terrain_z_top = -10;             % mm (top of terrain)
cfg.terrain_z_bottom = -210;         % mm (bottom of terrain)
cfg.terrain_size = [200, 200, 200];  % mm [x, y, z]

%% Layer Structure
% Cover layer: Z = -10 to -20 mm (10mm thick)
cfg.cover_thickness = 10;            % mm
cfg.cover_z_top = -10;              % mm
cfg.cover_z_bottom = -20;           % mm

% Bulk layer: Z = -20 to -210 mm (190mm thick)
cfg.bulk_z_top = -20;              % mm
cfg.bulk_z_bottom = -210;          % mm
cfg.bulk_thickness = 190;           % mm

%% Material Properties
% Cover materials (top layer)
cfg.cover_materials = struct();
cfg.cover_materials.tile.name = 'Tile';
cfg.cover_materials.tile.er = 6.0;        % relative permittivity
cfg.cover_materials.tile.sigma = 0.01;    % conductivity (S/m)

cfg.cover_materials.concrete_slab.name = 'ConcreteSlab';
cfg.cover_materials.concrete_slab.er = 4.5;
cfg.cover_materials.concrete_slab.sigma = 0.006;

% Bulk materials (main body)
cfg.bulk_materials = struct();
cfg.bulk_materials.cement.name = 'Cement';
cfg.bulk_materials.cement.er = 4.0;       % dry cement
cfg.bulk_materials.cement.sigma = 0.008;

cfg.bulk_materials.soil.name = 'Soil';
cfg.bulk_materials.soil.er = 12.0;        % moist soil
cfg.bulk_materials.soil.sigma = 0.03;

% Void properties (air pockets)
cfg.void_er = 1.0;
cfg.void_sigma = 0.0;

%% Void Generation
cfg.void_size = 5;                  % mm (5x5x5 cubes)
cfg.variation_pct = 2;              % ±2% material property variation

%% Density Classes
% Cement with tile top (6 classes)
cfg.cement_classes = struct();
cfg.cement_classes.labels = {'Cement 800', 'Cement 900', 'Cement 1000', ...
                             'Cement 1100', 'Cement 1200', 'Cement 1300'};
cfg.cement_classes.mass_g = [800, 900, 1000, 1100, 1200, 1300];
cfg.cement_classes.density_gcm3 = [1.33, 1.50, 1.67, 1.83, 2.00, 2.17];

% Soil with concrete/gravel slab top (6 classes)
cfg.soil_classes = struct();
cfg.soil_classes.labels = {'Soil 700', 'Soil 900', 'Soil 1100', ...
                           'Soil 1300', 'Soil 1500', 'Soil 1700'};
cfg.soil_classes.mass_g = [700, 900, 1100, 1300, 1500, 1700];
cfg.soil_classes.density_gcm3 = [0.35, 0.45, 0.55, 0.65, 0.74, 0.84];

% Combined class list (all 12)
cfg.all_labels = [cfg.cement_classes.labels, cfg.soil_classes.labels];
cfg.n_classes = length(cfg.all_labels);

%% Dataset Generation
cfg.n_samples_per_class = 200;      % samples per density class
cfg.n_total_samples = cfg.n_classes * cfg.n_samples_per_class;  % 2400
cfg.rng_seed_sim = 123;            % simulation RNG seed
cfg.rng_seed_split = 42;           % train/test split RNG seed

%% Train/Test Split
cfg.test_fraction = 0.2;           % 80/20 split

%% MLP Architecture
cfg.mlp_layers = [128, 64, 32];    % hidden layer sizes
cfg.mlp_iter_limit = 2000;         % max iterations
cfg.mlp_grad_tol = 1e-7;           % gradient tolerance

%% Output paths (relative to RO2 root)
cfg.path_data_raw = 'data/raw';
cfg.path_data_processed = 'data/processed';
cfg.path_models = 'models';
cfg.path_results = 'results';
cfg.path_figures_setup = 'figures/setup';
cfg.path_figures_dataset = 'figures/dataset';
cfg.path_figures_training = 'figures/training';
cfg.path_figures_cm = 'figures/confusion_matrices';

fprintf('RO2 config loaded: %d classes, %d samples/class, %d total.\n', ...
    cfg.n_classes, cfg.n_samples_per_class, cfg.n_total_samples);
