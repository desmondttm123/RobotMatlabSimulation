%% VisualizeRandomTerrain.m - Comprehensive terrain randomization visualization
% Shows the randomized bumpy terrain properties in a multi-panel figure:
%   Row 1: Permittivity (εr) variation along track per terrain
%   Row 2: Conductivity (σ) variation along track per terrain
%   Row 3: Surface height bumps along track per terrain
%   Row 4: 3D surface profile with height colormap and object markers
%
% Uses the same parameters as TrackSimulation_Bumpy.m (±2%, 100mm chunks)

clear; close all; clc;
rng(123); % reproducible (same seed as simulation)

%% Add parent path for SimConfig
addpath('..');
SimConfig;

%% Terrain chunk parameters (matching TrackSimulation_Bumpy.m)
chunk_size = 100;           % mm (100mm x 100mm per chunk)
variation_pct = 2;          % ±2% property variation
surface_z_max = 10;         % mm (surface height range: 0 to 10mm)

%% Track dimensions
track_y_start = cfg.track_y_start;   % 0 mm
track_y_end = cfg.track_y_end;       % 20000 mm
track_width = cfg.track_width;       % 1500 mm

n_chunks_y = (track_y_end - track_y_start) / chunk_size;  % 200
n_chunks_x = track_width / chunk_size;                     % 15

%% Object locations
obj_y_centers = cfg.obj_y_centers;
obj_y_half = cfg.obj_y_half;

%% Generate randomized terrain for each base type
fprintf('=== Randomized Terrain Visualization ===\n');
fprintf('Track: %d mm, Chunks: %d x %d (%.0f mm each)\n', ...
    track_y_end - track_y_start, n_chunks_y, n_chunks_x, chunk_size);
fprintf('Property variation: +/-%d%% of base values\n', variation_pct);
fprintf('Surface height: 0 to %d mm\n\n', surface_z_max);

y_centers = linspace(track_y_start + chunk_size/2, track_y_end - chunk_size/2, n_chunks_y);
x_centers = linspace(-track_width/2 + chunk_size/2, track_width/2 - chunk_size/2, n_chunks_x);

terrains = cfg.terrains;

for ti = 1:3
    base_er = terrains(ti).er;
    base_sigma = terrains(ti).sigma;
    
    % Random εr for each chunk (±2% of base, normal distribution clipped)
    er_grid = base_er + base_er * (variation_pct/100) * randn(n_chunks_y, n_chunks_x);
    er_grid = max(er_grid, base_er * (1 - variation_pct/100));
    er_grid = min(er_grid, base_er * (1 + variation_pct/100));
    terrains(ti).er_grid = er_grid;
    
    % Effective εr along track (average across X at each Y position)
    terrains(ti).er_along_track = mean(er_grid, 2)';
    
    % Random σ for each chunk (±2% of base)
    sigma_grid = base_sigma + base_sigma * (variation_pct/100) * randn(n_chunks_y, n_chunks_x);
    sigma_grid = max(sigma_grid, base_sigma * (1 - variation_pct/100));
    sigma_grid = min(sigma_grid, base_sigma * (1 + variation_pct/100));
    terrains(ti).sigma_grid = sigma_grid;
    terrains(ti).sigma_along_track = mean(sigma_grid, 2)';
    
    % Random surface heights (0 to 10mm per chunk)
    height_grid = rand(n_chunks_y, n_chunks_x) * surface_z_max;
    
    % Zero out heights over objects
    for oi = 1:length(obj_y_centers)
        oc = obj_y_centers(oi);
        for iy = 1:n_chunks_y
            for ix = 1:n_chunks_x
                if abs(x_centers(ix)) <= cfg.obj_x_half && abs(y_centers(iy) - oc) <= obj_y_half
                    height_grid(iy, ix) = 0;
                end
            end
        end
    end
    terrains(ti).height_grid = height_grid;
    terrains(ti).height_along_track = mean(height_grid, 2)';
    
    fprintf('  %s: er = %.2f +/- %.4f, sigma = %.5f +/- %.6f S/m\n', ...
        terrains(ti).name, base_er, std(terrains(ti).er_along_track), ...
        base_sigma, std(terrains(ti).sigma_along_track));
    fprintf('           Surface height range: [%.2f, %.2f] mm\n', ...
        min(height_grid(:)), max(height_grid(:)));
end

%% Create visualization figure (4 rows x 3 columns)
figure('Name', 'Randomized Terrain Visualization', 'Position', [50 50 1600 1100], 'Visible', 'off');

for ti = 1:3
    base_er = terrains(ti).er;
    base_sigma = terrains(ti).sigma;
    
    % --- Row 1: Permittivity variation along track ---
    subplot(4, 3, ti);
    plot(y_centers/1000, terrains(ti).er_along_track, '-', 'Color', [0.2 0.5 0.8], 'LineWidth', 0.8);
    hold on;
    yline(base_er, 'r--', 'LineWidth', 1.5);
    yline(base_er * (1 + variation_pct/100), 'r:', 'LineWidth', 1);
    yline(base_er * (1 - variation_pct/100), 'r:', 'LineWidth', 1);
    % Mark object locations
    for oi = 1:length(obj_y_centers)
        patch([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)+obj_y_half, ...
               obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)-obj_y_half]/1000, ...
              [min(ylim), min(ylim), max(ylim), max(ylim)], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    xlabel('Track Position (m)');
    ylabel('\epsilon_r');
    title(sprintf('%s - Permittivity (base=%.1f)', terrains(ti).name, base_er));
    grid on;
    
    % --- Row 2: Conductivity variation along track ---
    subplot(4, 3, 3 + ti);
    plot(y_centers/1000, terrains(ti).sigma_along_track * 1000, '-', 'Color', [0.8 0.3 0.2], 'LineWidth', 0.8);
    hold on;
    yline(base_sigma * 1000, 'b--', 'LineWidth', 1.5);
    yline(base_sigma * (1 + variation_pct/100) * 1000, 'r:', 'LineWidth', 1);
    yline(base_sigma * (1 - variation_pct/100) * 1000, 'r:', 'LineWidth', 1);
    for oi = 1:length(obj_y_centers)
        patch([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)+obj_y_half, ...
               obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)-obj_y_half]/1000, ...
              [min(ylim), min(ylim), max(ylim), max(ylim)], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    xlabel('Track Position (m)');
    ylabel('\sigma (mS/m)');
    title(sprintf('%s - Conductivity (base=%.1f mS/m)', terrains(ti).name, base_sigma*1000));
    grid on;
    
    % --- Row 3: Surface height profile ---
    subplot(4, 3, 6 + ti);
    plot(y_centers/1000, terrains(ti).height_along_track, '-', 'Color', [0.1 0.6 0.3], 'LineWidth', 0.8);
    hold on;
    yline(surface_z_max/2, 'k--', 'LineWidth', 0.5);
    for oi = 1:length(obj_y_centers)
        patch([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)+obj_y_half, ...
               obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)-obj_y_half]/1000, ...
              [0, 0, surface_z_max, surface_z_max], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    xlabel('Track Position (m)');
    ylabel('Height (mm)');
    title(sprintf('%s - Surface Bumps (0-%dmm)', terrains(ti).name, surface_z_max));
    ylim([-0.5, surface_z_max + 0.5]);
    grid on;
end

% --- Row 4: 3D surface visualization (DrySand as example) ---
subplot(4, 3, [10, 11, 12]);

[X_grid, Y_grid] = meshgrid(x_centers/1000, y_centers/1000);
surface_Z = terrains(1).height_grid;

surf(X_grid, Y_grid, surface_Z, 'EdgeColor', 'none', 'FaceAlpha', 0.9);
hold on;

% Mark objects as red patches on surface
for oi = 1:length(obj_y_centers)
    obj_x = [-cfg.obj_x_half, cfg.obj_x_half, cfg.obj_x_half, -cfg.obj_x_half]/1000;
    obj_y = ([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)-obj_y_half, ...
              obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)+obj_y_half])/1000;
    patch(obj_x, obj_y, [surface_z_max+1, surface_z_max+1, surface_z_max+1, surface_z_max+1], ...
        'r', 'FaceAlpha', 0.5, 'EdgeColor', 'r', 'LineWidth', 1.5);
end

colormap(gca, parula);
cb = colorbar; cb.Label.String = 'Surface Height (mm)';
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Height (mm)');
title('3D Surface Profile (DrySand) - Red = buried objects');
view([-35, 25]);
grid on;

sgtitle(sprintf('Randomized Terrain: %d chunks, +/-%d%% property variation, 0-%dmm surface bumps', ...
    n_chunks_y * n_chunks_x, variation_pct, surface_z_max), 'FontSize', 13, 'FontWeight', 'bold');

% Save combined figure
output_dir = 'Results';
savefig(gcf, fullfile(output_dir, 'RandomizedTerrain.fig'));
exportgraphics(gcf, fullfile(output_dir, 'RandomizedTerrain.png'), 'Resolution', 150);
close(gcf);
fprintf('\nCombined visualization saved: %s\n', fullfile(output_dir, 'RandomizedTerrain.png'));

%% === INDIVIDUAL FIGURES ===
fprintf('\nGenerating individual figures...\n');

terrain_names = {terrains(1).name, terrains(2).name, terrains(3).name};

for ti = 1:3
    base_er = terrains(ti).er;
    base_sigma = terrains(ti).sigma;
    tname = terrain_names{ti};
    
    % --- Individual: Permittivity along track ---
    fig = figure('Visible', 'off', 'Position', [100 100 900 350]);
    plot(y_centers/1000, terrains(ti).er_along_track, '-', 'Color', [0.2 0.5 0.8], 'LineWidth', 1);
    hold on;
    yline(base_er, 'r--', 'LineWidth', 1.5);
    yline(base_er * (1 + variation_pct/100), 'r:', 'LineWidth', 1);
    yline(base_er * (1 - variation_pct/100), 'r:', 'LineWidth', 1);
    for oi = 1:length(obj_y_centers)
        patch([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)+obj_y_half, ...
               obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)-obj_y_half]/1000, ...
              [min(ylim), min(ylim), max(ylim), max(ylim)], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    xlabel('Track Position (m)'); ylabel('\epsilon_r');
    title(sprintf('%s - Permittivity Along Track (base=%.1f, +/-%d%%)', tname, base_er, variation_pct));
    grid on; hold off;
    exportgraphics(fig, fullfile(output_dir, sprintf('Permittivity_%s.png', tname)), 'Resolution', 150);
    close(fig);
    
    % --- Individual: Conductivity along track ---
    fig = figure('Visible', 'off', 'Position', [100 100 900 350]);
    plot(y_centers/1000, terrains(ti).sigma_along_track * 1000, '-', 'Color', [0.8 0.3 0.2], 'LineWidth', 1);
    hold on;
    yline(base_sigma * 1000, 'b--', 'LineWidth', 1.5);
    yline(base_sigma * (1 + variation_pct/100) * 1000, 'r:', 'LineWidth', 1);
    yline(base_sigma * (1 - variation_pct/100) * 1000, 'r:', 'LineWidth', 1);
    for oi = 1:length(obj_y_centers)
        patch([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)+obj_y_half, ...
               obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)-obj_y_half]/1000, ...
              [min(ylim), min(ylim), max(ylim), max(ylim)], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    xlabel('Track Position (m)'); ylabel('\sigma (mS/m)');
    title(sprintf('%s - Conductivity Along Track (base=%.1f mS/m, +/-%d%%)', tname, base_sigma*1000, variation_pct));
    grid on; hold off;
    exportgraphics(fig, fullfile(output_dir, sprintf('Conductivity_%s.png', tname)), 'Resolution', 150);
    close(fig);
    
    % --- Individual: Surface height profile ---
    fig = figure('Visible', 'off', 'Position', [100 100 900 350]);
    plot(y_centers/1000, terrains(ti).height_along_track, '-', 'Color', [0.1 0.6 0.3], 'LineWidth', 1);
    hold on;
    yline(surface_z_max/2, 'k--', 'LineWidth', 0.5);
    for oi = 1:length(obj_y_centers)
        patch([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)+obj_y_half, ...
               obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)-obj_y_half]/1000, ...
              [0, 0, surface_z_max, surface_z_max], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    xlabel('Track Position (m)'); ylabel('Height (mm)');
    title(sprintf('%s - Surface Height (0-%dmm)', tname, surface_z_max));
    ylim([-0.5, surface_z_max + 0.5]);
    grid on; hold off;
    exportgraphics(fig, fullfile(output_dir, sprintf('SurfaceHeight_%s.png', tname)), 'Resolution', 150);
    close(fig);
    
    fprintf('  %s: Permittivity, Conductivity, SurfaceHeight saved.\n', tname);
end

% --- Individual: 3D surface profile ---
fig = figure('Visible', 'off', 'Position', [100 100 1100 600]);
[X_grid2, Y_grid2] = meshgrid(x_centers/1000, y_centers/1000);
surf(X_grid2, Y_grid2, terrains(1).height_grid, 'EdgeColor', 'none', 'FaceAlpha', 0.9);
hold on;
for oi = 1:length(obj_y_centers)
    obj_x = [-cfg.obj_x_half, cfg.obj_x_half, cfg.obj_x_half, -cfg.obj_x_half]/1000;
    obj_y_patch = ([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)-obj_y_half, ...
              obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)+obj_y_half])/1000;
    patch(obj_x, obj_y_patch, [surface_z_max+1, surface_z_max+1, surface_z_max+1, surface_z_max+1], ...
        'r', 'FaceAlpha', 0.5, 'EdgeColor', 'r', 'LineWidth', 1.5);
end
colormap(parula); cb = colorbar; cb.Label.String = 'Surface Height (mm)';
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Height (mm)');
title('3D Surface Profile (DrySand) - Red = buried objects');
view([-35, 25]); grid on; hold off;
exportgraphics(fig, fullfile(output_dir, 'SurfaceProfile_3D.png'), 'Resolution', 150);
close(fig);
fprintf('  3D Surface Profile saved.\n');

fprintf('All individual figures saved to %s/\n', output_dir);

% Save terrain data
save(fullfile(output_dir, 'TerrainData.mat'), 'terrains', 'y_centers', 'x_centers', ...
    'chunk_size', 'n_chunks_y', 'n_chunks_x', 'variation_pct', 'surface_z_max');
fprintf('Terrain data saved: %s\n', fullfile(output_dir, 'TerrainData.mat'));
