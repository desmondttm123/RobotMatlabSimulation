%% 10_generate_ro2_geometry.m - Build terrain geometry and void placement
% For each density class, generates random void placements inside the bulk
% material to achieve the target density.
%
% Geometry:
%   Cover layer: Z = -10 to -20 mm (10mm, no voids)
%   Bulk layer:  Z = -20 to -210 mm (190mm, voids placed here)
%   Voids: 3mm x 3mm x 3mm cubes, non-overlapping
%
% The void fraction is computed from target density vs. solid density.
% Output: geometry data saved to data/raw/

fprintf('=== RO2 Geometry Generation ===\n');

% Setup
if ~exist('ro2_root','var'), ro2_root=pwd; addpath('config'); end
ro2_config;

rng(cfg.rng_seed_sim);

%% Bulk volume discretization
% Divide bulk into 3mm grid cells
bulk_nx = floor(200 / cfg.void_size);  % 200/3 = 66 cells in X
bulk_ny = floor(200 / cfg.void_size);  % 66 cells in Y
bulk_nz = floor(cfg.bulk_thickness / cfg.void_size);  % 190/3 = 63 cells in Z
total_cells = bulk_nx * bulk_ny * bulk_nz;

fprintf('Bulk grid: %d x %d x %d = %d possible void cells (3mm each)\n', ...
    bulk_nx, bulk_ny, bulk_nz, total_cells);

%% Compute void fractions for each class
% void_fraction = 1 - (target_density / solid_density)
% where solid_density is the density with zero voids

% Cement solid density (no voids): use max density class as reference
cement_solid_density = max(cfg.cement_classes.density_gcm3);  % 2.17 g/cm³
soil_solid_density = max(cfg.soil_classes.density_gcm3);      % 0.84 g/cm³

fprintf('\nSolid densities (reference):\n');
fprintf('  Cement: %.2f g/cm³\n', cement_solid_density);
fprintf('  Soil: %.2f g/cm³\n', soil_solid_density);

%% Generate geometry for all classes
all_geometry = struct();
sample_idx = 0;

for class_idx = 1:cfg.n_classes
    if class_idx <= 6
        % Cement classes
        label = cfg.cement_classes.labels{class_idx};
        target_density = cfg.cement_classes.density_gcm3(class_idx);
        target_mass = cfg.cement_classes.mass_g(class_idx);
        material_group = 'cement';
        void_fraction = 1 - (target_density / cement_solid_density);
    else
        % Soil classes
        soil_idx = class_idx - 6;
        label = cfg.soil_classes.labels{soil_idx};
        target_density = cfg.soil_classes.density_gcm3(soil_idx);
        target_mass = cfg.soil_classes.mass_g(soil_idx);
        material_group = 'soil';
        void_fraction = 1 - (target_density / soil_solid_density);
    end
    
    % Clamp void fraction
    void_fraction = max(0, min(void_fraction, 0.95));
    target_n_voids = round(void_fraction * total_cells);
    
    fprintf('\nClass %d: %s (density=%.2f, void_frac=%.3f, target_voids=%d)\n', ...
        class_idx, label, target_density, void_fraction, target_n_voids);
    
    for s = 1:cfg.n_samples_per_class
        sample_idx = sample_idx + 1;
        
        % Random seed for this sample (reproducible)
        sample_seed = cfg.rng_seed_sim * 1000 + sample_idx;
        rng(sample_seed);
        
        % Generate random void positions (non-overlapping by random permutation)
        all_cell_indices = randperm(total_cells);
        void_indices = all_cell_indices(1:target_n_voids);
        
        % Convert linear indices to 3D grid coordinates
        [vx, vy, vz] = ind2sub([bulk_nx, bulk_ny, bulk_nz], void_indices);
        
        % Convert to mm coordinates (relative to terrain origin)
        void_positions_mm = zeros(target_n_voids, 3);
        void_positions_mm(:,1) = cfg.terrain_x_range(1) + (vx(:)-1) * cfg.void_size;
        void_positions_mm(:,2) = cfg.terrain_y_range(1) + (vy(:)-1) * cfg.void_size;
        void_positions_mm(:,3) = cfg.bulk_z_top - (vz(:)-1) * cfg.void_size;  % Z goes downward
        
        % Actual achieved density
        actual_void_fraction = target_n_voids / total_cells;
        if class_idx <= 6
            actual_density = cement_solid_density * (1 - actual_void_fraction);
        else
            actual_density = soil_solid_density * (1 - actual_void_fraction);
        end
        
        % Store geometry
        all_geometry(sample_idx).sample_id = sample_idx;
        all_geometry(sample_idx).class_idx = class_idx;
        all_geometry(sample_idx).label = label;
        all_geometry(sample_idx).material_group = material_group;
        all_geometry(sample_idx).target_density = target_density;
        all_geometry(sample_idx).actual_density = actual_density;
        all_geometry(sample_idx).target_mass = target_mass;
        all_geometry(sample_idx).void_fraction = actual_void_fraction;
        all_geometry(sample_idx).n_voids = target_n_voids;
        all_geometry(sample_idx).void_indices = void_indices;
        all_geometry(sample_idx).seed = sample_seed;
    end
    
    fprintf('  Generated %d samples (actual density: %.3f g/cm³)\n', ...
        cfg.n_samples_per_class, actual_density);
end

%% Save geometry data
output_file = fullfile(ro2_root, cfg.path_data_raw, 'ro2_geometry.mat');
save(output_file, 'all_geometry', 'cfg', 'bulk_nx', 'bulk_ny', 'bulk_nz', 'total_cells', ...
    'cement_solid_density', 'soil_solid_density', '-v7.3');
fprintf('\nGeometry saved: %s\n', output_file);
fprintf('Total samples: %d\n', sample_idx);
fprintf('=== Geometry Generation Complete ===\n');
