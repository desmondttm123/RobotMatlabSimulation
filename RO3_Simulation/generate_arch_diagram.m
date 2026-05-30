%% generate_arch_diagram.m
% Zoomed-in view of both antenna architectures with ACTUAL ray-traced
% multipath from the Communications Toolbox.
% Produces two side-by-side subplots: Parallel vs Criss-Cross

clear; close all; clc;

addpath('..');
SimConfig;

output_dir = 'Results';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% Antenna geometry (meters for toolbox, mm for plotting)
arrayWidth = cfg.arrayWidth / 1000;
arrayHeight = cfg.arrayHeight / 1000;
nCols = cfg.nCols;
nRows = cfg.nRows;
nRX = nCols * nRows;
nTotal = nRX + 1;
tilt_angle = cfg.tilt_angle;
height_center = cfg.sensor_z / 1000;
sensor1_x = cfg.sensor1_x / 1000;
sensor2_x = cfg.sensor2_x / 1000;

%% Generate local positions (TX at center, RX grid)
dx = arrayWidth / (nCols - 1);
dz = arrayHeight / (nRows - 1);
local_pos = zeros(nTotal, 3);
local_pos(1,:) = [0, 0, 0]; % TX at center
idx = 2;
for row = 1:nRows
    for col = 1:nCols
        local_pos(idx,:) = [-arrayWidth/2 + (col-1)*dx, -arrayHeight/2 + (row-1)*dz, 0];
        idx = idx + 1;
    end
end

theta_rad = deg2rad(tilt_angle);
Rx = [1,0,0; 0,cos(theta_rad),-sin(theta_rad); 0,sin(theta_rad),cos(theta_rad)];
rotated_pos = (Rx * local_pos')';

world_pos1 = rotated_pos;
world_pos1(:,1) = world_pos1(:,1) + sensor1_x;
world_pos1(:,3) = world_pos1(:,3) + height_center;

world_pos2 = rotated_pos;
world_pos2(:,1) = world_pos2(:,1) + sensor2_x;
world_pos2(:,3) = world_pos2(:,3) + height_center;

%% Create terrain STL (small ground plane for ray tracing)
ground_x = 0.5;  % 500mm half-width in meters
ground_y = 0.5;  % 500mm along Y
ground_z = 0.1;  % 100mm depth

V = [-ground_x  -ground_y  0;    ground_x  -ground_y  0;
      ground_x   ground_y  0;   -ground_x   ground_y  0;
     -ground_x  -ground_y -ground_z;  ground_x  -ground_y -ground_z;
      ground_x   ground_y -ground_z; -ground_x   ground_y -ground_z];
F = [1 2 3; 1 3 4;  5 7 6; 5 8 7;
     1 5 6; 1 6 2;  4 3 7; 4 7 8;
     1 4 8; 1 8 5;  2 6 7; 2 7 3];

terrain_stl = fullfile(output_dir, 'terrain_arch_scene.stl');
TR = triangulation(F, V);
stlwrite(TR, terrain_stl);

%% Ray trace using Communications Toolbox
fprintf('Opening siteviewer and computing rays...\n');
viewer = siteviewer("SceneModel", terrain_stl, "ShowOrigin", false);

pm = propagationModel("raytracing", ...
    "CoordinateSystem", "cartesian", ...
    "Method", "sbr", ...
    "SurfaceMaterial", "custom", ...
    "SurfaceMaterialPermittivity", cfg.terrains(1).er, ...
    "SurfaceMaterialConductivity", cfg.terrains(1).sigma);
pm.MaxNumReflections = 3;

% Create TX/RX sites
tx1_site = txsite("cartesian", "AntennaPosition", world_pos1(1,:)', ...
    "TransmitterFrequency", cfg.freq);
tx2_site = txsite("cartesian", "AntennaPosition", world_pos2(1,:)', ...
    "TransmitterFrequency", cfg.freq);

rx1_sites = rxsite.empty;
rx2_sites = rxsite.empty;
for ri = 2:nTotal
    rx1_sites(ri-1) = rxsite("cartesian", "AntennaPosition", world_pos1(ri,:)');
    rx2_sites(ri-1) = rxsite("cartesian", "AntennaPosition", world_pos2(ri,:)');
end

% Criss-cross: TX1->RX2, TX2->RX1
fprintf('  Computing criss-cross rays (TX1->RX2, TX2->RX1)...\n');
rays_tx1_rx2 = raytrace(tx1_site, rx2_sites, pm);
rays_tx2_rx1 = raytrace(tx2_site, rx1_sites, pm);

% Parallel: TX1->RX1, TX2->RX2
fprintf('  Computing parallel rays (TX1->RX1, TX2->RX2)...\n');
rays_tx1_rx1 = raytrace(tx1_site, rx1_sites, pm);
rays_tx2_rx2 = raytrace(tx2_site, rx2_sites, pm);

close(viewer);
fprintf('  Ray tracing complete.\n');

%% Count rays
n_cross = count_rays(rays_tx1_rx2) + count_rays(rays_tx2_rx1);
n_par = count_rays(rays_tx1_rx1) + count_rays(rays_tx2_rx2);
fprintf('  Criss-cross: %d rays | Parallel: %d rays\n', n_cross, n_par);

%% Generate individual figures

% === PARALLEL ===
fig_par = figure('Position', [50 50 900 700], 'Color', 'w', 'Visible', 'off');
ax1 = axes(fig_par); hold on;
draw_scene(ax1, world_pos1, world_pos2, nTotal);
draw_rays(rays_tx1_rx1, [1.0 0.4 0.1], 0.6, 1.5);  % orange: TX1->RX1
draw_rays(rays_tx2_rx2, [0.1 0.5 1.0], 0.6, 1.5);  % blue: TX2->RX2
title(sprintf('PARALLEL (TX1\\rightarrowRX1, TX2\\rightarrowRX2)\n%d rays — SBR, max 3 reflections', n_par), ...
    'FontSize', 13, 'FontWeight', 'bold');
set_view(ax1);
hold off;
savefig(fig_par, fullfile(output_dir, 'Architecture_Parallel.fig'));
exportgraphics(fig_par, fullfile(output_dir, 'Architecture_Parallel.png'), 'Resolution', 200);
fprintf('Saved: %s/Architecture_Parallel.fig + .png\n', output_dir);
close(fig_par);

% === CRISS-CROSS ===
fig_cross = figure('Position', [50 50 900 700], 'Color', 'w', 'Visible', 'off');
ax2 = axes(fig_cross); hold on;
draw_scene(ax2, world_pos1, world_pos2, nTotal);
draw_rays(rays_tx1_rx2, [1.0 0.4 0.1], 0.6, 1.5);  % orange: TX1->RX2
draw_rays(rays_tx2_rx1, [0.1 0.5 1.0], 0.6, 1.5);  % blue: TX2->RX1
title(sprintf('CRISS-CROSS (TX1\\rightarrowRX2, TX2\\rightarrowRX1)\n%d rays — SBR, max 3 reflections', n_cross), ...
    'FontSize', 13, 'FontWeight', 'bold');
set_view(ax2);
hold off;
savefig(fig_cross, fullfile(output_dir, 'Architecture_CrissCross.fig'));
exportgraphics(fig_cross, fullfile(output_dir, 'Architecture_CrissCross.png'), 'Resolution', 200);
fprintf('Saved: %s/Architecture_CrissCross.fig + .png\n', output_dir);
close(fig_cross);

% === COMBINED (for results.md) ===
fig = figure('Position', [50 50 1600 700], 'Color', 'w', 'Visible', 'off');
ax3 = subplot(1,2,1); hold on;
draw_scene(ax3, world_pos1, world_pos2, nTotal);
draw_rays(rays_tx1_rx1, [1.0 0.4 0.1], 0.6, 1.5);
draw_rays(rays_tx2_rx2, [0.1 0.5 1.0], 0.6, 1.5);
title(sprintf('PARALLEL\n%d rays', n_par), 'FontSize', 13, 'FontWeight', 'bold');
set_view(ax3); hold off;

ax4 = subplot(1,2,2); hold on;
draw_scene(ax4, world_pos1, world_pos2, nTotal);
draw_rays(rays_tx1_rx2, [1.0 0.4 0.1], 0.6, 1.5);
draw_rays(rays_tx2_rx1, [0.1 0.5 1.0], 0.6, 1.5);
title(sprintf('CRISS-CROSS\n%d rays', n_cross), 'FontSize', 13, 'FontWeight', 'bold');
set_view(ax4); hold off;

sgtitle('Zoomed Antenna View — Ray-Traced Multipath (SBR, max 3 reflections)', ...
    'FontSize', 14, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(output_dir, 'Architecture_Diagram_Zoomed.png'), 'Resolution', 200);
fprintf('Saved: %s/Architecture_Diagram_Zoomed.png\n', output_dir);
close(fig);

%% ===== LOCAL FUNCTIONS =====

function draw_scene(~, world_pos1, world_pos2, nTotal)
    % Ground plane (mm)
    ground_color = [0.6 0.45 0.25];
    patch([-300 300 300 -300], [-200 -200 200 200], [0 0 0 0], ...
        ground_color, 'FaceAlpha', 0.3, 'EdgeColor', ground_color, 'LineWidth', 1);
    
    % Grid on ground for reference
    for gx = -200:100:200
        plot3([gx gx], [-200 200], [0 0], '-', 'Color', [0.5 0.4 0.3 0.3], 'LineWidth', 0.5);
    end
    for gy = -200:100:200
        plot3([-300 300], [gy gy], [0 0], '-', 'Color', [0.5 0.4 0.3 0.3], 'LineWidth', 0.5);
    end
    
    % PCB boards (green rectangles, tilted)
    % Sensor 1
    draw_pcb_3d(world_pos1, nTotal, [0.1 0.6 0.1]);
    % Sensor 2
    draw_pcb_3d(world_pos2, nTotal, [0.1 0.6 0.1]);
    
    % TX markers (red triangles)
    scatter3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, ...
        120, 'r', '^', 'filled', 'MarkerEdgeColor', 'k');
    scatter3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, ...
        120, 'r', '^', 'filled', 'MarkerEdgeColor', 'k');
    
    % RX markers (blue dots)
    scatter3(world_pos1(2:end,1)*1000, world_pos1(2:end,2)*1000, world_pos1(2:end,3)*1000, ...
        20, 'b', 'filled');
    scatter3(world_pos2(2:end,1)*1000, world_pos2(2:end,2)*1000, world_pos2(2:end,3)*1000, ...
        20, 'b', 'filled');
    
    % Labels
    text(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000 + 30, ...
        'TX1', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'r', ...
        'HorizontalAlignment', 'center');
    text(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000 + 30, ...
        'TX2', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'r', ...
        'HorizontalAlignment', 'center');
    text(world_pos1(1,1)*1000 - 20, world_pos1(1,2)*1000, world_pos1(1,3)*1000 - 50, ...
        'Sensor 1', 'FontSize', 9, 'FontAngle', 'italic', 'HorizontalAlignment', 'center');
    text(world_pos2(1,1)*1000 + 20, world_pos2(1,2)*1000, world_pos2(1,3)*1000 - 50, ...
        'Sensor 2', 'FontSize', 9, 'FontAngle', 'italic', 'HorizontalAlignment', 'center');
end

function draw_pcb_3d(world_pos, nTotal, color)
    % Draw PCB as convex hull of element positions
    pts = world_pos(2:nTotal, :) * 1000;
    k = convhull(pts(:,1), pts(:,3));
    % Use mean Y for all board vertices
    my = mean(pts(:,2));
    fill3(pts(k,1), ones(size(k))*my, pts(k,3), color, ...
        'FaceAlpha', 0.4, 'EdgeColor', color*0.7, 'LineWidth', 1.5);
end

function draw_rays(ray_cell, color, alpha, lw)
    for ri = 1:numel(ray_cell)
        ray_set = ray_cell{ri};
        for rj = 1:numel(ray_set)
            ray = ray_set(rj);
            tx_loc = ray.TransmitterLocation(:)';
            rx_loc = ray.ReceiverLocation(:)';
            
            if ray.NumInteractions == 0
                path_pts = [tx_loc; rx_loc] * 1000;
            else
                interactions = ray.Interactions;
                int_pts = zeros(ray.NumInteractions, 3);
                for ki = 1:ray.NumInteractions
                    int_pts(ki,:) = interactions(ki).Location(:)';
                end
                path_pts = [tx_loc; int_pts; rx_loc] * 1000;
            end
            
            plot3(path_pts(:,1), path_pts(:,2), path_pts(:,3), '-', ...
                'Color', [color alpha], 'LineWidth', lw);
        end
    end
end

function set_view(ax)
    % Front-facing view: looking along Y-axis toward the antennas
    axes(ax);
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    grid on;
    set(ax, 'Projection', 'orthographic');
    view([0, 5]);  % Front view, slight elevation
    daspect([1 1 1]);
    xlim([-250 250]);
    ylim([-150 150]);
    zlim([-20 180]);
    light('Position', [0 -500 300]);
end

function n = count_rays(ray_cell)
    n = 0;
    for ri = 1:numel(ray_cell)
        n = n + numel(ray_cell{ri});
    end
end
