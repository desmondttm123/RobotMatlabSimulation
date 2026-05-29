%% VisualizeRandomTerrain.m - Show randomized terrain chunks + surface bumps
% Divides the 20m track into 10,000 chunks, each with slightly different
% terrain properties (±5% of base εr and σ). Also generates random surface
% height variation (bumps of ±2mm amplitude).
%
% Run this FIRST to inspect the terrain before running the full experiment.

clear; close all; clc;
rng(123); % reproducible randomness

%% Base terrain parameters (same as original SimConfig)
terrains(1).name = 'DrySand';     terrains(1).er = 3.5;   terrains(1).sigma = 0.001;
terrains(2).name = 'GrassySoil';  terrains(2).er = 15.0;  terrains(2).sigma = 0.05;
terrains(3).name = 'Rocks';       terrains(3).er = 7.0;   terrains(3).sigma = 0.005;

%% Track and chunk parameters
track_length = 20000;       % mm (20 meters)
n_chunks = 10000;           % number of terrain chunks
chunk_size = track_length / n_chunks;  % 2mm per chunk
variation_pct = 5;          % ±5% variation from base

% Surface bump parameters
bump_amplitude_mm = 2.0;    % max bump height ±2mm
bump_spatial_freq = 0.005;  % spatial frequency (cycles/mm) - controls smoothness
n_bump_harmonics = 20;      % number of random sine components

%% Generate randomized terrain for each base type
fprintf('=== Randomized Terrain Generation ===\n');
fprintf('Track: %d mm, Chunks: %d (%.1f mm each)\n', track_length, n_chunks, chunk_size);
fprintf('Property variation: ±%d%% of base values\n', variation_pct);
fprintf('Surface bumps: ±%.1f mm amplitude\n\n', bump_amplitude_mm);

chunk_centers = linspace(chunk_size/2, track_length - chunk_size/2, n_chunks);

for ti = 1:3
    base_er = terrains(ti).er;
    base_sigma = terrains(ti).sigma;
    
    % Random εr for each chunk (±5% of base, normal distribution clipped)
    er_variation = base_er * (variation_pct/100) * randn(1, n_chunks);
    er_variation = max(min(er_variation, base_er*variation_pct/100), -base_er*variation_pct/100);
    terrains(ti).chunk_er = base_er + er_variation;
    
    % Random σ for each chunk (±5% of base)
    sigma_variation = base_sigma * (variation_pct/100) * randn(1, n_chunks);
    sigma_variation = max(min(sigma_variation, base_sigma*variation_pct/100), -base_sigma*variation_pct/100);
    terrains(ti).chunk_sigma = base_sigma + sigma_variation;
    
    % Random surface height variation (smooth bumps using sum of sines)
    surface_height = zeros(1, n_chunks);
    for h = 1:n_bump_harmonics
        freq = bump_spatial_freq * (0.5 + rand()) * h / n_bump_harmonics;
        phase = 2*pi*rand();
        amp = bump_amplitude_mm * (1/h) * (0.5 + rand());  % decreasing amplitude for higher freqs
        surface_height = surface_height + amp * sin(2*pi*freq*chunk_centers + phase);
    end
    % Normalize to ±bump_amplitude_mm
    surface_height = surface_height / max(abs(surface_height)) * bump_amplitude_mm;
    terrains(ti).surface_height = surface_height;
    
    fprintf('  %s: εr = %.2f ± %.3f, σ = %.4f ± %.5f S/m\n', ...
        terrains(ti).name, base_er, std(terrains(ti).chunk_er), ...
        base_sigma, std(terrains(ti).chunk_sigma));
    fprintf('           Surface height range: [%.2f, %.2f] mm\n', ...
        min(surface_height), max(surface_height));
end

%% Object locations (same as original)
obj_y_centers = [3200, 8500, 14100, 18000];
obj_y_half = 150;  % mm

%% Create visualization figure
figure('Name', 'Randomized Terrain Visualization', 'Position', [50 50 1600 1000], 'Visible', 'off');

for ti = 1:3
    % --- Row 1: Permittivity variation along track ---
    subplot(4, 3, ti);
    plot(chunk_centers/1000, terrains(ti).chunk_er, '.', 'MarkerSize', 1, 'Color', [0.2 0.4 0.8]);
    hold on;
    yline(terrains(ti).er, 'r--', 'LineWidth', 1.5);
    % Mark objects
    for oi = 1:length(obj_y_centers)
        patch([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)+obj_y_half, ...
               obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)-obj_y_half]/1000, ...
              [min(terrains(ti).chunk_er), min(terrains(ti).chunk_er), ...
               max(terrains(ti).chunk_er), max(terrains(ti).chunk_er)], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    xlabel('Track Position (m)');
    ylabel('\epsilon_r');
    title(sprintf('%s - Permittivity (base=%.1f)', terrains(ti).name, terrains(ti).er));
    grid on;
    
    % --- Row 2: Conductivity variation along track ---
    subplot(4, 3, 3 + ti);
    plot(chunk_centers/1000, terrains(ti).chunk_sigma * 1000, '.', 'MarkerSize', 1, 'Color', [0.8 0.3 0.2]);
    hold on;
    yline(terrains(ti).sigma * 1000, 'b--', 'LineWidth', 1.5);
    for oi = 1:length(obj_y_centers)
        patch([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)+obj_y_half, ...
               obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)-obj_y_half]/1000, ...
              [min(terrains(ti).chunk_sigma)*1000, min(terrains(ti).chunk_sigma)*1000, ...
               max(terrains(ti).chunk_sigma)*1000, max(terrains(ti).chunk_sigma)*1000], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    xlabel('Track Position (m)');
    ylabel('\sigma (mS/m)');
    title(sprintf('%s - Conductivity (base=%.1f mS/m)', terrains(ti).name, terrains(ti).sigma*1000));
    grid on;
    
    % --- Row 3: Surface height profile ---
    subplot(4, 3, 6 + ti);
    plot(chunk_centers/1000, terrains(ti).surface_height, '-', 'Color', [0.1 0.6 0.3], 'LineWidth', 0.5);
    hold on;
    yline(0, 'k--');
    for oi = 1:length(obj_y_centers)
        patch([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)+obj_y_half, ...
               obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)-obj_y_half]/1000, ...
              [-bump_amplitude_mm, -bump_amplitude_mm, bump_amplitude_mm, bump_amplitude_mm], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    xlabel('Track Position (m)');
    ylabel('Height (mm)');
    title(sprintf('%s - Surface Bumps (±%.1f mm)', terrains(ti).name, bump_amplitude_mm));
    ylim([-bump_amplitude_mm*1.3, bump_amplitude_mm*1.3]);
    grid on;
end

% --- Row 4: 3D surface visualization (one terrain as example) ---
subplot(4, 3, [10, 11, 12]);
% Show a 3D view of the terrain surface with color = εr
x_range = linspace(-750, 750, 50);  % X positions across track width
y_range = chunk_centers(1:100:end);   % subsample Y for visualization
[X_grid, Y_grid] = meshgrid(x_range, y_range);

% Generate 2D surface using terrain 1 (DrySand) height + some X variation
surface_Z = zeros(size(X_grid));
for yi = 1:length(y_range)
    chunk_idx = round(y_range(yi) / chunk_size) + 1;
    chunk_idx = min(chunk_idx, n_chunks);
    base_h = terrains(1).surface_height(chunk_idx);
    % Add some X variation (smaller amplitude)
    x_bump = 0.5 * bump_amplitude_mm * sin(2*pi*x_range/300 + chunk_idx*0.1);
    surface_Z(yi, :) = base_h + x_bump;
end

surf(X_grid/1000, Y_grid/1000, surface_Z, 'EdgeColor', 'none', 'FaceAlpha', 0.9);
hold on;
% Mark objects as red patches on surface
for oi = 1:length(obj_y_centers)
    obj_x = [-250, 250, 250, -250]/1000;
    obj_y = ([obj_y_centers(oi)-obj_y_half, obj_y_centers(oi)-obj_y_half, ...
              obj_y_centers(oi)+obj_y_half, obj_y_centers(oi)+obj_y_half])/1000;
    patch(obj_x, obj_y, [3 3 3 3], 'r', 'FaceAlpha', 0.5, 'EdgeColor', 'r');
end
colormap(gca, parula);
cb = colorbar; cb.Label.String = 'Surface Height (mm)';
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Height (mm)');
title('3D Surface Profile (DrySand) - Red = buried objects');
view([-35, 25]);
grid on;

sgtitle(sprintf('Randomized Terrain: %d chunks, ±%d%% property variation, ±%.1fmm surface bumps', ...
    n_chunks, variation_pct, bump_amplitude_mm), 'FontSize', 13, 'FontWeight', 'bold');

% Save
output_dir = 'Results';
savefig(gcf, fullfile(output_dir, 'RandomizedTerrain.fig'));
exportgraphics(gcf, fullfile(output_dir, 'RandomizedTerrain.png'), 'Resolution', 150);
close(gcf);
fprintf('\nVisualization saved: %s\n', fullfile(output_dir, 'RandomizedTerrain.png'));

% Also save the terrain data for use by the simulation
save(fullfile(output_dir, 'TerrainData.mat'), 'terrains', 'chunk_centers', 'chunk_size', ...
    'n_chunks', 'variation_pct', 'bump_amplitude_mm');
fprintf('Terrain data saved: %s\n', fullfile(output_dir, 'TerrainData.mat'));
