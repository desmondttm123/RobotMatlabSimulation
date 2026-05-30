%% 02_config_ro2_simulation.m - Load and display RO2 configuration
% Loads ro2_config and prints a summary of all parameters.

fprintf('=== RO2 Configuration ===\n');

% Load config
ro2_config;

% Print summary
fprintf('\n--- Antenna ---\n');
fprintf('  Position: (%.0f, %.0f, %.0f) mm\n', cfg.antenna_x, cfg.antenna_y, cfg.antenna_z);
fprintf('  Tilt: %.0f deg (downward)\n', cfg.tilt_angle);
fprintf('  Array: %dx%d = %d RX + 1 TX\n', cfg.nCols, cfg.nRows, cfg.nRX);
fprintf('  PCB: %.0fx%.0f mm\n', cfg.array_width, cfg.array_height);

fprintf('\n--- Terrain ---\n');
fprintf('  Size: %.0f x %.0f x %.0f mm\n', cfg.terrain_size(1), cfg.terrain_size(2), cfg.terrain_size(3));
fprintf('  X: [%.0f, %.0f] mm\n', cfg.terrain_x_range(1), cfg.terrain_x_range(2));
fprintf('  Y: [%.0f, %.0f] mm\n', cfg.terrain_y_range(1), cfg.terrain_y_range(2));
fprintf('  Z: [%.0f, %.0f] mm\n', cfg.terrain_z_top, cfg.terrain_z_bottom);
fprintf('  Cover: %.0f mm (Z=%.0f to %.0f)\n', cfg.cover_thickness, cfg.cover_z_top, cfg.cover_z_bottom);
fprintf('  Bulk: %.0f mm (Z=%.0f to %.0f)\n', cfg.bulk_thickness, cfg.bulk_z_top, cfg.bulk_z_bottom);

fprintf('\n--- Materials ---\n');
fprintf('  Cement cover: Tile (er=%.1f, sigma=%.3f)\n', ...
    cfg.cover_materials.tile.er, cfg.cover_materials.tile.sigma);
fprintf('  Soil cover: ConcreteSlab (er=%.1f, sigma=%.3f)\n', ...
    cfg.cover_materials.concrete_slab.er, cfg.cover_materials.concrete_slab.sigma);
fprintf('  Cement bulk: (er=%.1f, sigma=%.3f)\n', ...
    cfg.bulk_materials.cement.er, cfg.bulk_materials.cement.sigma);
fprintf('  Soil bulk: (er=%.1f, sigma=%.3f)\n', ...
    cfg.bulk_materials.soil.er, cfg.bulk_materials.soil.sigma);
fprintf('  Voids: (er=%.1f, sigma=%.3f), size=%dmm cubes\n', ...
    cfg.void_er, cfg.void_sigma, cfg.void_size);

fprintf('\n--- Density Classes ---\n');
fprintf('  Cement: ');
fprintf('%s ', cfg.cement_classes.labels{:});
fprintf('\n  Soil:   ');
fprintf('%s ', cfg.soil_classes.labels{:});
fprintf('\n  Total: %d classes\n', cfg.n_classes);

fprintf('\n--- Dataset ---\n');
fprintf('  Samples/class: %d\n', cfg.n_samples_per_class);
fprintf('  Total samples: %d\n', cfg.n_total_samples);
fprintf('  Features: %d raw RSSI (16 RX x 2 power levels)\n', cfg.nRX * 2);

fprintf('\nConfiguration OK.\n');
