%% QuickView.m - 3D Setup with clean flat terrain
% Shows the robot setup with:
%   1. Clean flat terrain (semi-transparent to reveal buried objects)
%   2. Bright yellow buried objects for high contrast
%   3. Radiation pattern lobes on TX antennas
%   4. Robot STL loaded from SimConfig
%
% Based on QuickView_BumpyTerrain.m layout but without bumpy surface

clear; close all; clc;

%% Load shared configuration
SimConfig;

%% Unpack parameters from cfg
arrayWidth = cfg.arrayWidth / 1000;     % convert mm -> m
arrayHeight = cfg.arrayHeight / 1000;
nCols = cfg.nCols;
nRows = cfg.nRows;
nRX = nCols * nRows;
nTotal = nRX + 1;
tilt_angle = cfg.tilt_angle;
height_center = cfg.sensor_z / 1000;    % convert mm -> m

% Sensor offsets in X (m)
sensor1_x = cfg.sensor1_x / 1000;
sensor2_x = cfg.sensor2_x / 1000;

% Track (mm for plotting)
track_width = cfg.track_width;
track_y_start = cfg.track_y_start;
track_y_end = cfg.track_y_end;
gy_min = track_y_start - 1000;
gy_max = track_y_end;

% Objects (mm)
obj_w = cfg.obj_x_half;
obj_l = cfg.obj_y_half;
obj_z_top = cfg.obj_z_top;
obj_z_bot = cfg.obj_z_bottom;
obj_y_centers = cfg.obj_y_centers;
obj_names = cfg.obj_names;

% Terrain dimensions
gs_x = track_width / 2;   % half-size in X (mm)
total_depth = 500;         % mm

%% Generate antenna positions
dx = arrayWidth / (nCols - 1);
dz = arrayHeight / (nRows - 1);
local_pos = zeros(nTotal, 3);
local_pos(1, :) = [0, 0, 0];
idx = 2;
for row = 1:nRows
    for col = 1:nCols
        x = -arrayWidth/2 + (col-1) * dx;
        y = -arrayHeight/2 + (row-1) * dz;
        local_pos(idx, :) = [x, y, 0];
        idx = idx + 1;
    end
end

theta_rad = deg2rad(tilt_angle);
Rx = [1, 0, 0; 0, cos(theta_rad), -sin(theta_rad); 0, sin(theta_rad), cos(theta_rad)];
rotated_pos = (Rx * local_pos')';

world_pos1 = rotated_pos;
world_pos1(:,1) = world_pos1(:,1) + sensor1_x;
world_pos1(:,3) = world_pos1(:,3) + height_center;

world_pos2 = rotated_pos;
world_pos2(:,1) = world_pos2(:,1) + sensor2_x;
world_pos2(:,3) = world_pos2(:,3) + height_center;

%% === 3D FIGURE ===
figure('Name', 'RO4 Setup - Transparent View', 'Position', [50, 50, 1400, 900], 'Visible', 'off');
hold on;

% --- Flat terrain (semi-transparent so buried objects are visible) ---
fill_alpha = 0.2;
fill_color = [0.50 0.32 0.15];

% Top surface
patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_end track_y_end], ...
    [0 0 0 0], fill_color, 'FaceAlpha', fill_alpha, 'EdgeColor', 'none');
% Bottom
patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_end track_y_end], ...
    [-total_depth -total_depth -total_depth -total_depth], fill_color*0.7, 'FaceAlpha', fill_alpha, 'EdgeColor', 'none');
% Right wall
patch([gs_x gs_x gs_x gs_x], [track_y_start track_y_end track_y_end track_y_start], ...
    [0 0 -total_depth -total_depth], fill_color*0.85, 'FaceAlpha', fill_alpha, 'EdgeColor', 'none');
% Left wall
patch([-gs_x -gs_x -gs_x -gs_x], [track_y_start track_y_end track_y_end track_y_start], ...
    [0 0 -total_depth -total_depth], fill_color*0.85, 'FaceAlpha', fill_alpha, 'EdgeColor', 'none');
% Back wall
patch([-gs_x gs_x gs_x -gs_x], [track_y_end track_y_end track_y_end track_y_end], ...
    [0 0 -total_depth -total_depth], fill_color*0.8, 'FaceAlpha', fill_alpha, 'EdgeColor', 'none');
% Front wall
patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_start track_y_start], ...
    [0 0 -total_depth -total_depth], fill_color*0.75, 'FaceAlpha', fill_alpha, 'EdgeColor', 'none');

% Track boundary outline
plot3([-gs_x gs_x gs_x -gs_x -gs_x], ...
      [track_y_start track_y_start track_y_end track_y_end track_y_start], ...
      [0 0 0 0 0], '-', 'Color', [0.4 0.25 0.1], 'LineWidth', 1.5);

% --- Embedded objects (bright yellow for high contrast) ---
obj_color = [1.0 0.85 0.0];      % bright yellow
obj_edge = [0.8 0.6 0.0];        % darker gold edge
for oi = 1:length(obj_y_centers)
    oy = obj_y_centers(oi);
    % Top face
    patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy+obj_l oy+obj_l], ...
        [obj_z_top obj_z_top obj_z_top obj_z_top], obj_color, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
    % Front face
    patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy-obj_l oy-obj_l], ...
        [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.85, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
    % Right face
    patch([obj_w obj_w obj_w obj_w], [oy-obj_l oy+obj_l oy+obj_l oy-obj_l], ...
        [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.9, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
    % Bottom face
    patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy+obj_l oy+obj_l], ...
        [obj_z_bot obj_z_bot obj_z_bot obj_z_bot], obj_color*0.7, 'FaceAlpha', 0.9, 'EdgeColor', obj_edge);
    % Label
    text(-gs_x - 100, oy, 100, obj_names{oi}, ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.85 0.6 0.0], 'HorizontalAlignment', 'right');
end

% --- PCB boards ---
board_corners = [-arrayWidth/2, -arrayHeight/2, 0; arrayWidth/2, -arrayHeight/2, 0;
                  arrayWidth/2, arrayHeight/2, 0; -arrayWidth/2, arrayHeight/2, 0];
bc1 = (Rx * board_corners')';
bc1(:,1) = bc1(:,1) + sensor1_x;
bc1(:,3) = bc1(:,3) + height_center;
fill3(bc1(:,1)*1000, bc1(:,2)*1000, bc1(:,3)*1000, ...
    [0.1 0.6 0.1], 'FaceAlpha', 0.6, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);

bc2 = (Rx * board_corners')';
bc2(:,1) = bc2(:,1) + sensor2_x;
bc2(:,3) = bc2(:,3) + height_center;
fill3(bc2(:,1)*1000, bc2(:,2)*1000, bc2(:,3)*1000, ...
    [0.1 0.6 0.1], 'FaceAlpha', 0.6, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);

% --- Sensor antennas ---
scatter3(world_pos1(2:end,1)*1000, world_pos1(2:end,2)*1000, world_pos1(2:end,3)*1000, ...
    30, 'b', 'filled');
scatter3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, ...
    100, 'r', '^', 'filled');
scatter3(world_pos2(2:end,1)*1000, world_pos2(2:end,2)*1000, world_pos2(2:end,3)*1000, ...
    30, 'b', 'filled');
scatter3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, ...
    100, 'r', '^', 'filled');

% --- Array normals ---
normal_local = [0, 0, -1];
normal_world = (Rx * normal_local')';
quiver3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, ...
    normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, ...
    'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
quiver3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, ...
    normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, ...
    'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);

% --- Sensor labels ---
text(world_pos1(1,1)*1000 - 200, world_pos1(1,2)*1000, world_pos1(1,3)*1000 + 200, ...
    'Sensor 1', 'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
text(world_pos2(1,1)*1000 + 200, world_pos2(1,2)*1000, world_pos2(1,3)*1000 + 200, ...
    'Sensor 2', 'FontSize', 8, 'FontWeight', 'bold');

% --- Robot STL ---
try
    robot_stl = stlread(cfg.robot_stl_path);
    robot_verts = robot_stl.Points;
    Ry90 = [cos(pi/2), 0, sin(pi/2); 0, 1, 0; -sin(pi/2), 0, cos(pi/2)];
    robot_verts = (Ry90 * robot_verts')';
    Rz180 = [cos(pi), -sin(pi), 0; sin(pi), cos(pi), 0; 0, 0, 1];
    robot_verts = (Rz180 * robot_verts')';
    robot_verts(:,2) = robot_verts(:,2) + cfg.robot_y_offset;
    robot_verts(:,3) = robot_verts(:,3) + cfg.robot_z_offset;
    robot_verts(:,1) = robot_verts(:,1) - mean(robot_verts(:,1));
    robot_tri = triangulation(robot_stl.ConnectivityList, robot_verts);
    trisurf(robot_tri, 'FaceColor', [0.75 0.75 0.8], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.3, 'FaceLighting', 'gouraud');
catch me
    fprintf('  (Robot STL not found: %s)\n', me.message);
end

% --- Lighting and view ---
light('Position', [500 -5000 1000]);

xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('RO4 - Buried Object Simulation (Transparent View)');
grid on;
set(gca, 'Projection', 'orthographic');
view([174.6603927156378, 2.043555780726723]);
daspect([1 1 1]);
ylim([gy_min gy_max]);
xlim([-1000 1000]);
zlim([-total_depth-50 800]);
hold off;

% Save
set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(cfg.output_dir, 'Setup_3D.fig'));
exportgraphics(gcf, fullfile(cfg.output_dir, 'Setup_3D.png'), 'Resolution', 150);
close(gcf);
fprintf('Setup_3D.png saved to %s\n', cfg.output_dir);

%% === MULTIPATH RAY TRACING VIEW ===
% Full scene with both sensors, cross-traced rays (TX1->RX2, TX2->RX1),
% radiation patterns, robot STL, and all objects.
fprintf('Generating multipath ray tracing view...\n');

try
    % --- Create terrain box STL for ray tracing scene (meters) ---
    box_x = track_width / 1000;
    box_y = (track_y_end - track_y_start) / 1000;
    box_z = total_depth / 1000;

    bx = box_x/2; by = box_y/2; bz = box_z;
    V = [-bx 0    0;    bx 0    0;    bx by   0;   -bx by   0;
         -bx 0   -bz;   bx 0   -bz;   bx by  -bz;  -bx by  -bz];
    F = [1 2 3; 1 3 4;   5 7 6; 5 8 7;
         1 5 6; 1 6 2;   4 3 7; 4 7 8;
         1 4 8; 1 8 5;   2 6 7; 2 7 3];

    terrain_stl_path = fullfile(cfg.output_dir, 'terrain_scene.stl');
    TR = triangulation(F, V);
    stlwrite(TR, terrain_stl_path);

    % --- Compute rays using siteviewer ---
    viewer = siteviewer("SceneModel", terrain_stl_path, "ShowOrigin", false);

    % Configure ray tracing - more reflections for richer multipath
    pm = propagationModel("raytracing", ...
        "CoordinateSystem", "cartesian", ...
        "Method", "sbr", ...
        "SurfaceMaterial", "custom", ...
        "SurfaceMaterialPermittivity", cfg.terrains(1).er, ...
        "SurfaceMaterialConductivity", cfg.terrains(1).sigma);
    pm.MaxNumReflections = 5;

    % --- Cross-trace: TX1 -> all RX of Sensor 2, TX2 -> all RX of Sensor 1 ---
    % TX1 (center of Sensor 1) -> RX elements of Sensor 2
    tx1_site = txsite("cartesian", "AntennaPosition", world_pos1(1,:)', ...
        "TransmitterFrequency", cfg.freq);
    rx2_sites = rxsite.empty;
    for ri = 2:nTotal
        rx2_sites(ri-1) = rxsite("cartesian", "AntennaPosition", world_pos2(ri,:)');
    end
    rays_tx1_rx2 = raytrace(tx1_site, rx2_sites, pm);
    fprintf('  TX1->RX2 rays computed\n');

    % TX2 (center of Sensor 2) -> RX elements of Sensor 1
    tx2_site = txsite("cartesian", "AntennaPosition", world_pos2(1,:)', ...
        "TransmitterFrequency", cfg.freq);
    rx1_sites = rxsite.empty;
    for ri = 2:nTotal
        rx1_sites(ri-1) = rxsite("cartesian", "AntennaPosition", world_pos1(ri,:)');
    end
    rays_tx2_rx1 = raytrace(tx2_site, rx1_sites, pm);
    fprintf('  TX2->RX1 rays computed\n');

    % Also trace TX1->RX1 and TX2->RX2 (self-reflection)
    rays_tx1_rx1 = raytrace(tx1_site, rx1_sites, pm);
    rays_tx2_rx2 = raytrace(tx2_site, rx2_sites, pm);
    fprintf('  Self-traces TX1->RX1, TX2->RX2 computed\n');

    close(viewer);

    % --- Build the multipath figure (full scene) ---
    fig2 = figure('Name', 'RO4 Setup - Multipath', 'Position', [50, 50, 1400, 900], 'Visible', 'off');
    hold on;

    % --- Terrain (semi-transparent) ---
    fill_alpha_mp = 0.15;
    patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_end track_y_end], ...
        [0 0 0 0], fill_color, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_end track_y_end], ...
        [-total_depth -total_depth -total_depth -total_depth], fill_color*0.7, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([gs_x gs_x gs_x gs_x], [track_y_start track_y_end track_y_end track_y_start], ...
        [0 0 -total_depth -total_depth], fill_color*0.85, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([-gs_x -gs_x -gs_x -gs_x], [track_y_start track_y_end track_y_end track_y_start], ...
        [0 0 -total_depth -total_depth], fill_color*0.85, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([-gs_x gs_x gs_x -gs_x], [track_y_end track_y_end track_y_end track_y_end], ...
        [0 0 -total_depth -total_depth], fill_color*0.8, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_start track_y_start], ...
        [0 0 -total_depth -total_depth], fill_color*0.75, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');

    % Track outline
    plot3([-gs_x gs_x gs_x -gs_x -gs_x], ...
          [track_y_start track_y_start track_y_end track_y_end track_y_start], ...
          [0 0 0 0 0], '-', 'Color', [0.4 0.25 0.1], 'LineWidth', 1.5);

    % --- Embedded objects (bright yellow) ---
    for oi = 1:length(obj_y_centers)
        oy = obj_y_centers(oi);
        patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy+obj_l oy+obj_l], ...
            [obj_z_top obj_z_top obj_z_top obj_z_top], obj_color, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
        patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy-obj_l oy-obj_l], ...
            [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.85, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
        patch([obj_w obj_w obj_w obj_w], [oy-obj_l oy+obj_l oy+obj_l oy-obj_l], ...
            [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.9, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
        patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy+obj_l oy+obj_l], ...
            [obj_z_bot obj_z_bot obj_z_bot obj_z_bot], obj_color*0.7, 'FaceAlpha', 0.9, 'EdgeColor', obj_edge);
        text(-gs_x - 100, oy, 100, obj_names{oi}, 'FontSize', 8, 'FontWeight', 'bold', ...
            'Color', [0.85 0.6 0.0], 'HorizontalAlignment', 'right');
    end

    % --- Both PCB boards ---
    fill3(bc1(:,1)*1000, bc1(:,2)*1000, bc1(:,3)*1000, ...
        [0.1 0.6 0.1], 'FaceAlpha', 0.6, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);
    fill3(bc2(:,1)*1000, bc2(:,2)*1000, bc2(:,3)*1000, ...
        [0.1 0.6 0.1], 'FaceAlpha', 0.6, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);

    % --- Both sensor antennas ---
    % Sensor 1: RX blue, TX red
    scatter3(world_pos1(2:end,1)*1000, world_pos1(2:end,2)*1000, world_pos1(2:end,3)*1000, ...
        30, 'b', 'filled');
    scatter3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, ...
        100, 'r', '^', 'filled');
    % Sensor 2: RX blue, TX red
    scatter3(world_pos2(2:end,1)*1000, world_pos2(2:end,2)*1000, world_pos2(2:end,3)*1000, ...
        30, 'b', 'filled');
    scatter3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, ...
        100, 'r', '^', 'filled');

    % --- Array normals ---
    quiver3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, ...
        normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, ...
        'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
    quiver3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, ...
        normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, ...
        'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);

    % --- Draw ALL computed ray paths ---
    % Color scheme: cross-traced rays brighter, self-traced dimmer
    all_ray_sets = {rays_tx1_rx2, rays_tx2_rx1, rays_tx1_rx1, rays_tx2_rx2};
    ray_set_colors = {[1 0.4 0.1], [0.1 0.5 1], [1 0.7 0.2], [0.3 0.7 1]};  % orange, blue, gold, lightblue
    ray_set_alpha = [0.7, 0.7, 0.4, 0.4];  % cross-traced more visible
    ray_set_lw = [1.8, 1.8, 1.0, 1.0];

    n_rays_drawn = 0;
    for si = 1:numel(all_ray_sets)
        ray_cell = all_ray_sets{si};
        base_color = ray_set_colors{si};
        alpha = ray_set_alpha(si);
        base_lw = ray_set_lw(si);

        for ri = 1:numel(ray_cell)
            ray_set_i = ray_cell{ri};
            for rj = 1:numel(ray_set_i)
                ray = ray_set_i(rj);
                tx_loc = ray.TransmitterLocation(:)';
                rx_loc = ray.ReceiverLocation(:)';

                if ray.NumInteractions == 0
                    path_pts = [tx_loc; rx_loc] * 1000;
                    lw = base_lw * 1.2;
                else
                    interactions = ray.Interactions;
                    int_pts = zeros(ray.NumInteractions, 3);
                    for ki = 1:ray.NumInteractions
                        int_pts(ki,:) = interactions(ki).Location(:)';
                    end
                    path_pts = [tx_loc; int_pts; rx_loc] * 1000;
                    lw = base_lw;
                end

                plot3(path_pts(:,1), path_pts(:,2), path_pts(:,3), '-', ...
                    'Color', [base_color alpha], 'LineWidth', lw);
                n_rays_drawn = n_rays_drawn + 1;
            end
        end
    end
    fprintf('  Drew %d total ray paths (cross + self)\n', n_rays_drawn);

    % --- Sensor labels ---
    text(world_pos1(1,1)*1000 - 200, world_pos1(1,2)*1000, world_pos1(1,3)*1000 + 200, ...
        'Sensor 1', 'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    text(world_pos2(1,1)*1000 + 200, world_pos2(1,2)*1000, world_pos2(1,3)*1000 + 200, ...
        'Sensor 2', 'FontSize', 8, 'FontWeight', 'bold');

    % --- Robot STL ---
    try
        robot_stl2 = stlread(cfg.robot_stl_path);
        rv2 = robot_stl2.Points;
        Ry90_2 = [cos(pi/2), 0, sin(pi/2); 0, 1, 0; -sin(pi/2), 0, cos(pi/2)];
        rv2 = (Ry90_2 * rv2')';
        Rz180_2 = [cos(pi), -sin(pi), 0; sin(pi), cos(pi), 0; 0, 0, 1];
        rv2 = (Rz180_2 * rv2')';
        rv2(:,2) = rv2(:,2) + cfg.robot_y_offset;
        rv2(:,3) = rv2(:,3) + cfg.robot_z_offset;
        rv2(:,1) = rv2(:,1) - mean(rv2(:,1));
        robot_tri2 = triangulation(robot_stl2.ConnectivityList, rv2);
        trisurf(robot_tri2, 'FaceColor', [0.75 0.75 0.8], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.3, 'FaceLighting', 'gouraud');
    catch
        fprintf('  (Robot STL not loaded for multipath figure)\n');
    end

    % --- Lighting and view ---
    light('Position', [500 -5000 1000]);
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    title(sprintf('RO4 - Multipath Ray Tracing (%d rays, max %d reflections)', n_rays_drawn, pm.MaxNumReflections));
    grid on;
    set(gca, 'Projection', 'orthographic');
    view([174.6603927156378, 2.043555780726723]);
    daspect([1 1 1]);
    ylim([gy_min gy_max]);
    xlim([-1000 1000]);
    zlim([-total_depth-50 800]);
    hold off;

    % Save
    set(fig2, 'Visible', 'on');
    savefig(fig2, fullfile(cfg.output_dir, 'Setup_3D_Multipath.fig'));
    exportgraphics(fig2, fullfile(cfg.output_dir, 'Setup_3D_Multipath.png'), 'Resolution', 150);
    close(fig2);
    fprintf('  Setup_3D_Multipath.png saved to %s\n', cfg.output_dir);

    % === SAME-ANTENNA MULTIPATH (TX1->RX1, TX2->RX2 only) ===
    fprintf('  Generating same-antenna multipath figure...\n');
    fig3 = figure('Name', 'RO4 Setup - Same-Antenna Multipath', 'Position', [50, 50, 1400, 900], 'Visible', 'off');
    hold on;

    % Terrain
    patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_end track_y_end], ...
        [0 0 0 0], fill_color, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_end track_y_end], ...
        [-total_depth -total_depth -total_depth -total_depth], fill_color*0.7, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([gs_x gs_x gs_x gs_x], [track_y_start track_y_end track_y_end track_y_start], ...
        [0 0 -total_depth -total_depth], fill_color*0.85, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([-gs_x -gs_x -gs_x -gs_x], [track_y_start track_y_end track_y_end track_y_start], ...
        [0 0 -total_depth -total_depth], fill_color*0.85, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([-gs_x gs_x gs_x -gs_x], [track_y_end track_y_end track_y_end track_y_end], ...
        [0 0 -total_depth -total_depth], fill_color*0.8, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_start track_y_start], ...
        [0 0 -total_depth -total_depth], fill_color*0.75, 'FaceAlpha', fill_alpha_mp, 'EdgeColor', 'none');
    plot3([-gs_x gs_x gs_x -gs_x -gs_x], ...
          [track_y_start track_y_start track_y_end track_y_end track_y_start], ...
          [0 0 0 0 0], '-', 'Color', [0.4 0.25 0.1], 'LineWidth', 1.5);

    % Objects
    for oi = 1:length(obj_y_centers)
        oy = obj_y_centers(oi);
        patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy+obj_l oy+obj_l], ...
            [obj_z_top obj_z_top obj_z_top obj_z_top], obj_color, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
        patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy-obj_l oy-obj_l], ...
            [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.85, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
        patch([obj_w obj_w obj_w obj_w], [oy-obj_l oy+obj_l oy+obj_l oy-obj_l], ...
            [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.9, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
        patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy+obj_l oy+obj_l], ...
            [obj_z_bot obj_z_bot obj_z_bot obj_z_bot], obj_color*0.7, 'FaceAlpha', 0.9, 'EdgeColor', obj_edge);
        text(-gs_x - 100, oy, 100, obj_names{oi}, 'FontSize', 8, 'FontWeight', 'bold', ...
            'Color', [0.85 0.6 0.0], 'HorizontalAlignment', 'right');
    end

    % Both PCB boards
    fill3(bc1(:,1)*1000, bc1(:,2)*1000, bc1(:,3)*1000, ...
        [0.1 0.6 0.1], 'FaceAlpha', 0.6, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);
    fill3(bc2(:,1)*1000, bc2(:,2)*1000, bc2(:,3)*1000, ...
        [0.1 0.6 0.1], 'FaceAlpha', 0.6, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);

    % Both sensor antennas
    scatter3(world_pos1(2:end,1)*1000, world_pos1(2:end,2)*1000, world_pos1(2:end,3)*1000, 30, 'b', 'filled');
    scatter3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, 100, 'r', '^', 'filled');
    scatter3(world_pos2(2:end,1)*1000, world_pos2(2:end,2)*1000, world_pos2(2:end,3)*1000, 30, 'b', 'filled');
    scatter3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, 100, 'r', '^', 'filled');

    % Array normals
    quiver3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, ...
        normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
    quiver3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, ...
        normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);

    % --- Draw SAME-ANTENNA ray paths only (TX1->RX1 orange, TX2->RX2 blue) ---
    same_ray_sets = {rays_tx1_rx1, rays_tx2_rx2};
    same_colors = {[1 0.4 0.1], [0.1 0.5 1]};  % orange for S1, blue for S2

    n_same_drawn = 0;
    for si = 1:numel(same_ray_sets)
        ray_cell = same_ray_sets{si};
        base_color = same_colors{si};
        for ri = 1:numel(ray_cell)
            ray_set_i = ray_cell{ri};
            for rj = 1:numel(ray_set_i)
                ray = ray_set_i(rj);
                tx_loc = ray.TransmitterLocation(:)';
                rx_loc = ray.ReceiverLocation(:)';

                if ray.NumInteractions == 0
                    path_pts = [tx_loc; rx_loc] * 1000;
                    lw = 1.8;
                else
                    interactions = ray.Interactions;
                    int_pts = zeros(ray.NumInteractions, 3);
                    for ki = 1:ray.NumInteractions
                        int_pts(ki,:) = interactions(ki).Location(:)';
                    end
                    path_pts = [tx_loc; int_pts; rx_loc] * 1000;
                    lw = 1.2;
                end

                plot3(path_pts(:,1), path_pts(:,2), path_pts(:,3), '-', ...
                    'Color', [base_color 0.7], 'LineWidth', lw);
                n_same_drawn = n_same_drawn + 1;
            end
        end
    end
    fprintf('  Drew %d same-antenna ray paths\n', n_same_drawn);

    % Sensor labels
    text(world_pos1(1,1)*1000 - 200, world_pos1(1,2)*1000, world_pos1(1,3)*1000 + 200, ...
        'Sensor 1 (TX\rightarrowRX)', 'FontSize', 8, 'FontWeight', 'bold', 'Color', [1 0.4 0.1], 'HorizontalAlignment', 'right');
    text(world_pos2(1,1)*1000 + 200, world_pos2(1,2)*1000, world_pos2(1,3)*1000 + 200, ...
        'Sensor 2 (TX\rightarrowRX)', 'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.1 0.5 1]);

    % Robot STL
    try
        trisurf(robot_tri2, 'FaceColor', [0.75 0.75 0.8], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.3, 'FaceLighting', 'gouraud');
    catch
    end

    % View
    light('Position', [500 -5000 1000]);
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    title(sprintf('RO4 - Same-Antenna Multipath (%d rays, TX\\rightarrowRX per sensor)', n_same_drawn));
    grid on;
    set(gca, 'Projection', 'orthographic');
    view([174.6603927156378, 2.043555780726723]);
    daspect([1 1 1]);
    ylim([gy_min gy_max]);
    xlim([-1000 1000]);
    zlim([-total_depth-50 800]);
    hold off;

    set(fig3, 'Visible', 'on');
    savefig(fig3, fullfile(cfg.output_dir, 'Setup_3D_Multipath_SameAntenna.fig'));
    exportgraphics(fig3, fullfile(cfg.output_dir, 'Setup_3D_Multipath_SameAntenna.png'), 'Resolution', 150);
    close(fig3);
    fprintf('  Setup_3D_Multipath_SameAntenna.png saved to %s\n', cfg.output_dir);

catch me
    fprintf('  Multipath view failed: %s\n', me.message);
    fprintf('  %s (line %d)\n', me.stack(1).name, me.stack(1).line);
end
