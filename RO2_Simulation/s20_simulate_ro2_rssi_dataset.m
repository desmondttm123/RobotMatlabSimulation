%% 20_simulate_ro2_rssi_dataset.m - Generate raw RSSI data for all classes
% Simulates RF reflection from layered terrain with voids.
%
% Model: Two-ray (direct + reflected) with Fresnel coefficients
%   - TX at (0, 0, 30mm) facing downward
%   - 16 RX elements in 4x4 grid at z=30mm
%   - Each RX sees a different local region of the terrain below it
%   - The local void content in the bulk below each RX's footprint
%     determines the effective bulk permittivity for that measurement
%   - This gives spatial diversity: different void patterns produce
%     different RSSI profiles across the array
%   - Two TX power levels per measurement (low + high)
%
% Output: 32 raw RSSI features per sample (16 RX x 2 power levels)

fprintf('=== RO2 RSSI Dataset Generation ===\n');
tic;

% Setup
if ~exist('ro2_root','var'), ro2_root=pwd; addpath('config'); end
ro2_config;

%% Load geometry
geom_file = fullfile(ro2_root, cfg.path_data_raw, 'ro2_geometry.mat');
if ~exist(geom_file, 'file')
    error('Geometry not found. Run s10_generate_ro2_geometry.m first.');
end
load(geom_file, 'all_geometry', 'bulk_nx', 'bulk_ny', 'bulk_nz', 'total_cells');
n_samples = length(all_geometry);
fprintf('Loaded %d geometry samples.\n', n_samples);

%% Compute antenna element positions
% TX at center, RX in 4x4 grid on 40x40mm PCB, all at z=30mm facing down
dx_rx = cfg.array_width / (cfg.nCols - 1);
dy_rx = cfg.array_height / (cfg.nRows - 1);

rx_pos = zeros(cfg.nRX, 3);
idx = 1;
for row = 1:cfg.nRows
    for col = 1:cfg.nCols
        rx_pos(idx, 1) = cfg.antenna_x - cfg.array_width/2 + (col-1) * dx_rx;
        rx_pos(idx, 2) = cfg.antenna_y - cfg.array_height/2 + (row-1) * dy_rx;
        rx_pos(idx, 3) = cfg.antenna_z;
        idx = idx + 1;
    end
end
tx_pos = [cfg.antenna_x, cfg.antenna_y, cfg.antenna_z];

fprintf('TX at (%.1f, %.1f, %.1f) mm\n', tx_pos);
fprintf('RX array: %d elements, spacing: %.1f x %.1f mm\n', cfg.nRX, dx_rx, dy_rx);

%% Physical constants
c = cfg.c;
f = cfg.freq;
lambda_m = c / f;
lambda_mm = lambda_m * 1000;
omega = 2 * pi * f;
eps0 = 8.854e-12;

%% Precompute void grid for spatial lookup
% Each RX element's reflection point on the surface determines which
% column of voids it "sees" in the bulk below.
% The reflection point for TX->surface->RX is approximately the midpoint
% of TX and RX projected onto the surface (at near-normal incidence).
%
% Map each reflection point to a column of void cells in the 3D grid
% and compute local void fraction for that column.

% Grid cell size in X and Y
cell_dx = 200 / bulk_nx;  % ~3.03 mm per cell
cell_dy = 200 / bulk_ny;

% Reflection point for each RX (midpoint of TX and RX projected on surface)
refl_pts = zeros(cfg.nRX, 2);
for ri = 1:cfg.nRX
    refl_pts(ri, 1) = (tx_pos(1) + rx_pos(ri, 1)) / 2;  % X
    refl_pts(ri, 2) = (tx_pos(2) + rx_pos(ri, 2)) / 2;  % Y
end

% Map reflection points to grid column indices
% Terrain goes from -100 to +100 in X and Y
col_ix = max(1, min(bulk_nx, floor((refl_pts(:,1) - cfg.terrain_x_range(1)) / cell_dx) + 1));
col_iy = max(1, min(bulk_ny, floor((refl_pts(:,2) - cfg.terrain_y_range(1)) / cell_dy) + 1));

% Footprint radius (how many cells around reflection point contribute)
footprint_radius = 3;  % cells (~9mm radius)

fprintf('Footprint radius: %d cells (%.1f mm)\n', footprint_radius, footprint_radius * cell_dx);

%% Preallocate output
n_features = cfg.nRX * 2;
rssi_data = zeros(n_samples, n_features);

%% Preallocate output
n_features = cfg.nRX * 2;
rssi_data = zeros(n_samples, n_features);
metadata = table();

fprintf('Simulating %d samples x %d features...\n', n_samples, n_features);

%% Main simulation loop
for si = 1:n_samples
    if mod(si, 500) == 0
        fprintf('  Sample %d/%d (%.1f%%)\n', si, n_samples, 100*si/n_samples);
    end
    
    geom = all_geometry(si);
    rng(geom.seed);
    
    % Determine material properties for this sample
    if strcmp(geom.material_group, 'cement')
        cover_er_base = cfg.cover_materials.tile.er;
        cover_sigma_base = cfg.cover_materials.tile.sigma;
        bulk_er_base = cfg.bulk_materials.cement.er;
        bulk_sigma_base = cfg.bulk_materials.cement.sigma;
    else
        cover_er_base = cfg.cover_materials.concrete_slab.er;
        cover_sigma_base = cfg.cover_materials.concrete_slab.sigma;
        bulk_er_base = cfg.bulk_materials.soil.er;
        bulk_sigma_base = cfg.bulk_materials.soil.sigma;
    end
    
    % Apply global +/-2% variation
    var_factor_cover = 1 + (cfg.variation_pct/100) * randn();
    var_factor_bulk = 1 + (cfg.variation_pct/100) * randn();
    cover_er = cover_er_base * var_factor_cover;
    cover_sigma = cover_sigma_base * abs(var_factor_cover);
    bulk_er = bulk_er_base * var_factor_bulk;
    bulk_sigma = bulk_sigma_base * abs(var_factor_bulk);
    
    % Build 3D void occupancy grid for this sample
    void_grid = false(bulk_nx, bulk_ny, bulk_nz);
    if geom.n_voids > 0
        void_grid(geom.void_indices) = true;
    end
    
    % Compute LOCAL void fraction for each RX footprint column
    local_vf = zeros(cfg.nRX, 1);
    for ri = 1:cfg.nRX
        % Get cells within footprint around this RX's reflection point
        cx = col_ix(ri); cy = col_iy(ri);
        ix_range = max(1, cx-footprint_radius):min(bulk_nx, cx+footprint_radius);
        iy_range = max(1, cy-footprint_radius):min(bulk_ny, cy+footprint_radius);
        
        local_block = void_grid(ix_range, iy_range, :);
        local_vf(ri) = sum(local_block(:)) / numel(local_block);
    end
    
    % Compute RSSI for each RX at two power levels
    feature_idx = 0;
    for pwr_level = 1:2
        if pwr_level == 1
            P_tx = cfg.low_power_range(1) + diff(cfg.low_power_range) * rand();
        else
            P_tx = cfg.high_power_range(1) + diff(cfg.high_power_range) * rand();
        end
        
        for rx_idx = 1:cfg.nRX
            feature_idx = feature_idx + 1;
            rx = rx_pos(rx_idx, :);
            
            % Local effective bulk properties based on void fraction below this RX
            vf_local = local_vf(rx_idx);
            eff_bulk_er = bulk_er * (1 - vf_local) + cfg.void_er * vf_local;
            eff_bulk_sigma = bulk_sigma * (1 - vf_local);
            
            % Direct path (TX to RX, off-boresight)
            d_direct_mm = norm(tx_pos - rx);
            d_direct_m = d_direct_mm / 1000;
            
            % Reflected path via cover surface (z = -10mm)
            tx_image = [tx_pos(1), tx_pos(2), 2*cfg.cover_z_top - tx_pos(3)];
            d_reflected_mm = norm(tx_image - rx);
            d_reflected_m = d_reflected_mm / 1000;
            
            % Incidence angle
            h_tx = tx_pos(3) - cfg.cover_z_top;
            h_rx = rx(3) - cfg.cover_z_top;
            horiz_dist = norm(tx_pos(1:2) - rx(1:2));
            theta_i = atan2(horiz_dist, h_tx + h_rx);
            
            % Fresnel at air/cover interface
            eps_cover = cover_er - 1j * cover_sigma / (omega * eps0);
            sin_t = sin(theta_i); cos_t = cos(theta_i);
            sqrt_cover = sqrt(eps_cover - sin_t^2);
            Gamma_TE = (cos_t - sqrt_cover) / (cos_t + sqrt_cover);
            Gamma_TM = (eps_cover * cos_t - sqrt_cover) / (eps_cover * cos_t + sqrt_cover);
            Gamma_cover = (Gamma_TE + Gamma_TM) / 2;
            
            % Fresnel at cover/bulk interface
            eps_bulk = eff_bulk_er - 1j * eff_bulk_sigma / (omega * eps0);
            sqrt_bulk = sqrt(eps_bulk - sin_t^2);
            Gb_TE = (sqrt_cover - sqrt_bulk) / (sqrt_cover + sqrt_bulk);
            Gb_TM = (eps_bulk * sqrt_cover - eps_cover * sqrt_bulk) / ...
                     (eps_bulk * sqrt_cover + eps_cover * sqrt_bulk);
            Gamma_bulk = (Gb_TE + Gb_TM) / 2;
            
            % Cover transmission and attenuation
            T_cover = 1 - abs(Gamma_cover)^2;
            cover_path_m = 2 * cfg.cover_thickness / (cos(theta_i) * 1000);
            alpha_cover = cover_sigma / (2 * sqrt(cover_er)) * sqrt(377);
            cover_atten = exp(-alpha_cover * cover_path_m);
            
            % Phase shift through cover (round trip)
            k_cover = 2 * pi * f * sqrt(cover_er) / c;
            phase_cover = 2 * k_cover * (cfg.cover_thickness / 1000) / cos(theta_i);
            
            % Total reflection (coherent multi-layer)
            Gamma_total = Gamma_cover + T_cover * Gamma_bulk * cover_atten * exp(-1j * phase_cover);
            
            % FSPL
            FSPL_direct = 20 * log10(4 * pi * d_direct_m / lambda_m);
            FSPL_reflected = 20 * log10(4 * pi * d_reflected_m / lambda_m);
            reflection_loss = -20 * log10(abs(Gamma_total) + 1e-10);
            
            % Power
            P_direct_lin = 10^((-FSPL_direct + cfg.G_tx + cfg.G_rx - ...
                            cfg.pattern_loss_off_boresight) / 10);
            P_reflected_lin = 10^((-FSPL_reflected - reflection_loss + ...
                              cfg.G_tx + cfg.G_rx - cfg.pattern_loss_boresight) / 10);
            
            % Coherent sum
            phase_diff = 2 * pi * (d_reflected_mm - d_direct_mm) / lambda_mm;
            P_total_lin = abs(P_direct_lin + P_reflected_lin * exp(1j * phase_diff));
            P_total_dB = 10 * log10(P_total_lin + 1e-30);
            
            % Final RSSI
            noise = cfg.noise_std * randn();
            rssi_data(si, feature_idx) = P_tx + P_total_dB + noise;
        end
    end
end

%% Build metadata table
labels = cell(n_samples, 1);
material_groups = cell(n_samples, 1);
class_indices = zeros(n_samples, 1);
densities = zeros(n_samples, 1);
void_fractions = zeros(n_samples, 1);
n_voids = zeros(n_samples, 1);
masses = zeros(n_samples, 1);
seeds = zeros(n_samples, 1);

for si = 1:n_samples
    labels{si} = all_geometry(si).label;
    material_groups{si} = all_geometry(si).material_group;
    class_indices(si) = all_geometry(si).class_idx;
    densities(si) = all_geometry(si).actual_density;
    void_fractions(si) = all_geometry(si).void_fraction;
    n_voids(si) = all_geometry(si).n_voids;
    masses(si) = all_geometry(si).target_mass;
    seeds(si) = all_geometry(si).seed;
end

metadata = table(labels, material_groups, class_indices, densities, ...
    void_fractions, n_voids, masses, seeds, ...
    'VariableNames', {'Label', 'MaterialGroup', 'ClassIdx', 'Density', ...
                      'VoidFraction', 'NumVoids', 'Mass', 'Seed'});

%% Save dataset
% Feature column names
feature_names = cell(1, n_features);
for pwr = 1:2
    pwr_label = {'Low', 'High'};
    for rx = 1:cfg.nRX
        fi = (pwr-1)*cfg.nRX + rx;
        feature_names{fi} = sprintf('RSSI_%s_RX%02d', pwr_label{pwr}, rx);
    end
end

% Save as .mat
output_mat = fullfile(ro2_root, cfg.path_data_raw, 'ro2_rssi_dataset.mat');
save(output_mat, 'rssi_data', 'metadata', 'feature_names', 'cfg', '-v7.3');

% Save as CSV
rssi_table = array2table(rssi_data, 'VariableNames', feature_names);
full_table = [metadata, rssi_table];
output_csv = fullfile(ro2_root, cfg.path_data_raw, 'ro2_rssi_dataset.csv');
writetable(full_table, output_csv);

elapsed = toc;
fprintf('\nDataset saved:\n  MAT: %s\n  CSV: %s\n', output_mat, output_csv);
fprintf('Dimensions: %d samples × %d features\n', n_samples, n_features);
fprintf('Elapsed: %.1f seconds\n', elapsed);
fprintf('=== RSSI Simulation Complete ===\n');
