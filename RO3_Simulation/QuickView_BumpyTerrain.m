%% QuickView_BumpyTerrain.m - 3D Setup with randomized bumpy terrain blocks
% Shows the robot setup with:
%   1. 100mm x 100mm terrain chunks as 3D blocks
%   2. Top surface: random height 0-10mm per chunk
%   3. Block depth: 100mm below surface
%   4. Shades of brown for property variation
%   5. Robot STL loaded from parent folder
%
% Standalone script - does not modify original QuickView.m

clear; close all; clc;

%% Add parent path for SimConfig and STL
addpath('..');
SimConfig;

rng(123); % reproducible terrain

%% Terrain chunk parameters
chunk_size = 100;           % mm (100mm x 100mm XY per chunk)
variation_pct = 2;          % ±2% property variation
surface_z_max = 10;         % mm (top surface height: 0 to 10mm)
layer_thickness = 100;      % mm per layer
total_depth = 500;          % mm total depth
n_layers = total_depth / layer_thickness;  % 5 layers

%% Track dimensions
track_width = cfg.track_width;       % 1500 mm
track_y_start = cfg.track_y_start;   % 0 mm
track_y_end = cfg.track_y_end;       % 20000 mm

n_chunks_x = track_width / chunk_size;    % 1500/100 = 15
n_chunks_y = (track_y_end - track_y_start) / chunk_size;  % 20000/100 = 200

gs_x = track_width / 2;  % ±750mm

%% Unpack sensor parameters
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

gy_min = track_y_start - 1000;  % extended to show full robot (offset=-500, STL extends ~2000mm)
gy_max = track_y_end;

obj_w = cfg.obj_x_half;
obj_l = cfg.obj_y_half;
obj_z_top = cfg.obj_z_top;
obj_z_bot = cfg.obj_z_bottom;
obj_y_centers = cfg.obj_y_centers;
obj_names = cfg.obj_names;

%% Generate per-chunk random heights (0 to 10mm)
surface_heights = rand(n_chunks_y, n_chunks_x) * surface_z_max;

% Zero out chunks over objects
x_edges = linspace(-gs_x, gs_x, n_chunks_x + 1);
y_edges = linspace(track_y_start, track_y_end, n_chunks_y + 1);
x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
y_centers = (y_edges(1:end-1) + y_edges(2:end)) / 2;

for oi = 1:length(obj_y_centers)
    oc = obj_y_centers(oi);
    for iy = 1:n_chunks_y
        for ix = 1:n_chunks_x
            if abs(x_centers(ix)) <= obj_w && abs(y_centers(iy) - oc) <= obj_l
                surface_heights(iy, ix) = 0;
            end
        end
    end
end

%% Generate εr variation per chunk per layer (for brown shade mapping)
base_er = cfg.terrains(1).er;  % DrySand = 3.5
% Each layer gets independent random εr
er_layers = cell(n_layers, 1);
er_norm_layers = cell(n_layers, 1);
for layer = 1:n_layers
    er_l = base_er + base_er * (variation_pct/100) * randn(n_chunks_y, n_chunks_x);
    er_l = max(er_l, base_er * 0.9);
    er_l = min(er_l, base_er * 1.1);
    er_layers{layer} = er_l;
    er_norm_layers{layer} = (er_l - base_er*0.9) / (base_er*0.1*2);
end
% Surface layer norm (layer 1)
er_norm = er_norm_layers{1};

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
figure('Name', 'Bumpy Terrain Setup', 'Position', [50, 50, 1400, 900], 'Visible', 'off');
hold on;

% --- Draw terrain blocks: 5 layers of 100mm each, down to -500mm ---
fprintf('Drawing %d chunks x %d layers = %d blocks...\n', ...
    n_chunks_x * n_chunks_y, n_layers, n_chunks_x * n_chunks_y * n_layers);

% --- Solid terrain fill (semi-transparent interior so objects visible) ---
fill_alpha = 0.4;
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

% Top surface faces (layer 1 top)
for iy = 1:n_chunks_y
    for ix = 1:n_chunks_x
        x0 = x_edges(ix); x1 = x_edges(ix+1);
        y0 = y_edges(iy); y1 = y_edges(iy+1);
        z_top = surface_heights(iy, ix);
        
        shade = 0.85 + 0.30 * er_norm_layers{1}(iy, ix);
        brown = min([0.55, 0.35, 0.17] * shade, 1);
        
        % Top face of surface layer
        patch([x0 x1 x1 x0], [y0 y0 y1 y1], [z_top z_top z_top z_top], ...
            brown, 'EdgeColor', brown * 0.8, 'LineWidth', 0.3);
    end
end

% Bottom face (layer 5 bottom at -500mm)
for iy = 1:n_chunks_y
    for ix = 1:n_chunks_x
        x0 = x_edges(ix); x1 = x_edges(ix+1);
        y0 = y_edges(iy); y1 = y_edges(iy+1);
        shade = 0.85 + 0.30 * er_norm_layers{n_layers}(iy, ix);
        brown = min([0.55, 0.35, 0.17] * shade, 1) * 0.4;
        patch([x0 x1 x1 x0], [y0 y0 y1 y1], [-total_depth -total_depth -total_depth -total_depth], ...
            brown, 'EdgeColor', 'none');
    end
end

% --- Front wall (Y = track_y_start) showing all 5 layers ---
for layer = 1:n_layers
    z_layer_top = -(layer-1) * layer_thickness;
    z_layer_bot = -layer * layer_thickness;
    if layer == 1
        % First layer top follows surface height
        for ix = 1:n_chunks_x
            x0 = x_edges(ix); x1 = x_edges(ix+1);
            z_top = surface_heights(1, ix);
            shade = 0.85 + 0.30 * er_norm_layers{layer}(1, ix);
            brown = min([0.55, 0.35, 0.17] * shade, 1) * 0.75;
            patch([x0 x1 x1 x0], [track_y_start track_y_start track_y_start track_y_start], ...
                [z_top z_top z_layer_bot z_layer_bot], brown, 'EdgeColor', brown*0.7, 'LineWidth', 0.3);
        end
    else
        for ix = 1:n_chunks_x
            x0 = x_edges(ix); x1 = x_edges(ix+1);
            shade = 0.85 + 0.30 * er_norm_layers{layer}(1, ix);
            brown = min([0.55, 0.35, 0.17] * shade, 1) * (0.8 - 0.1*layer);
            patch([x0 x1 x1 x0], [track_y_start track_y_start track_y_start track_y_start], ...
                [z_layer_top z_layer_top z_layer_bot z_layer_bot], brown, 'EdgeColor', brown*0.7, 'LineWidth', 0.3);
        end
    end
end

% --- Right wall (X = gs_x) showing all 5 layers ---
for layer = 1:n_layers
    z_layer_top = -(layer-1) * layer_thickness;
    z_layer_bot = -layer * layer_thickness;
    if layer == 1
        for iy = 1:n_chunks_y
            y0 = y_edges(iy); y1 = y_edges(iy+1);
            z_top = surface_heights(iy, n_chunks_x);
            shade = 0.85 + 0.30 * er_norm_layers{layer}(iy, n_chunks_x);
            brown = min([0.55, 0.35, 0.17] * shade, 1) * 0.75;
            patch([gs_x gs_x gs_x gs_x], [y0 y1 y1 y0], ...
                [z_top z_top z_layer_bot z_layer_bot], brown, 'EdgeColor', brown*0.7, 'LineWidth', 0.3);
        end
    else
        for iy = 1:n_chunks_y
            y0 = y_edges(iy); y1 = y_edges(iy+1);
            shade = 0.85 + 0.30 * er_norm_layers{layer}(iy, n_chunks_x);
            brown = min([0.55, 0.35, 0.17] * shade, 1) * (0.8 - 0.1*layer);
            patch([gs_x gs_x gs_x gs_x], [y0 y1 y1 y0], ...
                [z_layer_top z_layer_top z_layer_bot z_layer_bot], brown, 'EdgeColor', brown*0.7, 'LineWidth', 0.3);
        end
    end
end

% --- Embedded objects (bright yellow for high contrast against brown) ---
obj_color = [1.0 0.85 0.0];      % bright yellow
obj_edge = [0.8 0.6 0.0];        % darker gold edge
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

% --- TX Radiation Pattern Lobes ---
% cos^n(theta) model: n chosen so -3dB beamwidth ~60deg (n ~ 3.5)
% and ~25 dB drop at 90 deg off boresight
n_pat = 3.5;
pat_scale = 350;  % mm - visual radius of main lobe at peak
n_pts = 30;       % resolution

% Generate pattern in local coords (boresight = -Z)
theta_pat = linspace(0, pi/2, n_pts);   % 0=boresight, pi/2=broadside
phi_pat = linspace(0, 2*pi, n_pts);
[THETA, PHI] = meshgrid(theta_pat, phi_pat);

% Normalized gain: cos^n(theta), clamped
G_norm = max(cos(THETA), 0).^n_pat;

% Convert to Cartesian in local frame (boresight = -Z direction)
R_pat = pat_scale * G_norm;
X_pat = R_pat .* sin(THETA) .* cos(PHI);
Y_pat = R_pat .* sin(THETA) .* sin(PHI);
Z_pat = -R_pat .* cos(THETA);  % negative Z = boresight direction

% Rotate pattern to world frame (same rotation as array)
for ii = 1:numel(X_pat)
    pt = Rx * [X_pat(ii); Y_pat(ii); Z_pat(ii)];
    X_pat(ii) = pt(1); Y_pat(ii) = pt(2); Z_pat(ii) = pt(3);
end

% Plot radiation pattern on Sensor 1 TX
tx1 = world_pos1(1,:) * 1000;  % mm
surf(X_pat + tx1(1), Y_pat + tx1(2), Z_pat + tx1(3), G_norm, ...
    'FaceAlpha', 0.5, 'EdgeColor', 'none', 'FaceColor', [1 0.3 0.1]);

% Plot radiation pattern on Sensor 2 TX
tx2 = world_pos2(1,:) * 1000;
surf(X_pat + tx2(1), Y_pat + tx2(2), Z_pat + tx2(3), G_norm, ...
    'FaceAlpha', 0.5, 'EdgeColor', 'none', 'FaceColor', [1 0.3 0.1]);

% --- Sensor labels ---
text(world_pos1(1,1)*1000 - 200, world_pos1(1,2)*1000, world_pos1(1,3)*1000 + 200, ...
    'Sensor 1', 'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
text(world_pos2(1,1)*1000 + 200, world_pos2(1,2)*1000, world_pos2(1,3)*1000 + 200, ...
    'Sensor 2', 'FontSize', 8, 'FontWeight', 'bold');

% --- Robot STL (path relative to parent) ---
try
    stl_path = fullfile('..', cfg.robot_stl_path);
    robot_stl = stlread(stl_path);
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
% Removed local light that caused white glow at far end

xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
% title(sprintf('Bumpy Terrain: 100mm chunks, surface 0-%dmm, depth %dmm, \\epsilon_r ±%d%%', ...
%    surface_z_max, total_depth, variation_pct));

title(sprintf('RO4 - Burried Object Simulation with Uneven Terrain'));

grid on;
set(gca, 'Projection', 'orthographic');
% view([azimuth, elevation]) in degrees:
%   azimuth  = rotation around Z-axis (0=looking along -Y, 90=along +X, 180=along +Y)
%   elevation = rotation above XY plane (0=side view, 90=top-down, negative=below)
% Examples: view([0,90])=top-down, view([0,0])=front(YZ), view([90,0])=right side(XZ)
% view([178.9646, 1.2123]);

view([174.6603927156378,2.043555780726723]);
daspect([1 1 1]);
ylim([gy_min gy_max]);
xlim([-1000 1000]);
zlim([-total_depth-50 800]);
hold off;

% Save
output_dir = 'Results';
set(gcf, 'Visible', 'on');  % so .fig opens visible when double-clicked
savefig(gcf, fullfile(output_dir, 'BumpyTerrain_Setup.fig'));
exportgraphics(gcf, fullfile(output_dir, 'BumpyTerrain_Setup.png'), 'Resolution', 150);
close(gcf);
fprintf('BumpyTerrain_Setup.png saved.\n');

%% === LIGHTWEIGHT FIGURE (openable in MATLAB figure viewer) ===
% Draws every Nth chunk, skips robot STL, keeps sensors + radiation + objects
fprintf('Generating lightweight .fig (every 10th chunk)...\n');
figure('Name', 'Bumpy Terrain Setup (Lite)', 'Position', [50, 50, 1400, 900], 'Visible', 'off');
hold on;

skip = 10;  % draw every 10th chunk (reduces 4000 -> ~40 surface patches)
chunk_depth = 80;  % mm visible depth per block in lite view

% Solid ground fill (single opaque surface covering the full track at z=0)
patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_end track_y_end], ...
    [0 0 0 0], [0.50 0.32 0.15], 'EdgeColor', 'none');
% Bottom face
patch([-gs_x gs_x gs_x -gs_x], [track_y_start track_y_start track_y_end track_y_end], ...
    [-total_depth -total_depth -total_depth -total_depth], [0.40 0.25 0.12], 'EdgeColor', 'none');
% Right side wall fill
patch([gs_x gs_x gs_x gs_x], [track_y_start track_y_end track_y_end track_y_start], ...
    [0 0 -total_depth -total_depth], [0.45 0.28 0.13], 'EdgeColor', 'none');
% Left side wall fill
patch([-gs_x -gs_x -gs_x -gs_x], [track_y_start track_y_end track_y_end track_y_start], ...
    [0 0 -total_depth -total_depth], [0.45 0.28 0.13], 'EdgeColor', 'none');
% Back wall fill
patch([-gs_x gs_x gs_x -gs_x], [track_y_end track_y_end track_y_end track_y_end], ...
    [0 0 -total_depth -total_depth], [0.42 0.26 0.12], 'EdgeColor', 'none');

% Top surface chunks (sparse, opaque, with visible edges)
for iy = 1:skip:n_chunks_y
    for ix = 1:n_chunks_x
        x0 = x_edges(ix); x1 = x_edges(ix+1);
        y0 = y_edges(iy); y1 = y_edges(iy+1);
        z_top = surface_heights(iy, ix);
        z_bot = z_top - chunk_depth;
        shade = 0.85 + 0.30 * er_norm_layers{1}(iy, ix);
        brown = min([0.55, 0.35, 0.17] * shade, 1);
        
        % Top face (opaque)
        patch([x0 x1 x1 x0], [y0 y0 y1 y1], [z_top z_top z_top z_top], ...
            brown, 'EdgeColor', brown * 0.5, 'LineWidth', 0.5);
        % Front face (Y = y0)
        patch([x0 x1 x1 x0], [y0 y0 y0 y0], [z_top z_top z_bot z_bot], ...
            brown * 0.7, 'EdgeColor', brown * 0.4, 'LineWidth', 0.3);
        % Right face (X = x1)
        patch([x1 x1 x1 x1], [y0 y1 y1 y0], [z_top z_top z_bot z_bot], ...
            brown * 0.8, 'EdgeColor', brown * 0.4, 'LineWidth', 0.3);
    end
end

% Track boundary outline
plot3([-gs_x gs_x gs_x -gs_x -gs_x], ...
      [track_y_start track_y_start track_y_end track_y_end track_y_start], ...
      [0 0 0 0 0], '-', 'Color', [0.4 0.25 0.1], 'LineWidth', 1.5);

% Front wall (only layer 1, sparse)
for ix = 1:n_chunks_x
    x0 = x_edges(ix); x1 = x_edges(ix+1);
    z_top = surface_heights(1, ix);
    shade = 0.85 + 0.30 * er_norm_layers{1}(1, ix);
    brown = min([0.55, 0.35, 0.17] * shade, 1) * 0.75;
    patch([x0 x1 x1 x0], [track_y_start track_y_start track_y_start track_y_start], ...
        [z_top z_top -total_depth -total_depth], brown, 'EdgeColor', brown*0.7, 'LineWidth', 0.3);
end

% Embedded objects
obj_color = [1.0 0.85 0.0]; obj_edge = [0.8 0.6 0.0];
for oi = 1:length(obj_y_centers)
    oy = obj_y_centers(oi);
    patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy+obj_l oy+obj_l], ...
        [obj_z_top obj_z_top obj_z_top obj_z_top], obj_color, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
    patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy-obj_l oy-obj_l], ...
        [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.85, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
    patch([obj_w obj_w obj_w obj_w], [oy-obj_l oy+obj_l oy+obj_l oy-obj_l], ...
        [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.9, 'FaceAlpha', 0.95, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
    text(-gs_x - 100, oy, 100, obj_names{oi}, 'FontSize', 8, 'FontWeight', 'bold', ...
        'Color', [0.85 0.6 0.0], 'HorizontalAlignment', 'right');
end

% PCB boards
fill3(bc1(:,1)*1000, bc1(:,2)*1000, bc1(:,3)*1000, ...
    [0.1 0.6 0.1], 'FaceAlpha', 0.6, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);
fill3(bc2(:,1)*1000, bc2(:,2)*1000, bc2(:,3)*1000, ...
    [0.1 0.6 0.1], 'FaceAlpha', 0.6, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);

% Sensor antennas
scatter3(world_pos1(2:end,1)*1000, world_pos1(2:end,2)*1000, world_pos1(2:end,3)*1000, 30, 'b', 'filled');
scatter3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, 100, 'r', '^', 'filled');
scatter3(world_pos2(2:end,1)*1000, world_pos2(2:end,2)*1000, world_pos2(2:end,3)*1000, 30, 'b', 'filled');
scatter3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, 100, 'r', '^', 'filled');

% Array normals
quiver3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, ...
    normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
quiver3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, ...
    normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);

% Radiation pattern lobes
surf(X_pat + tx1(1), Y_pat + tx1(2), Z_pat + tx1(3), G_norm, ...
    'FaceAlpha', 0.5, 'EdgeColor', 'none', 'FaceColor', [1 0.3 0.1]);
surf(X_pat + tx2(1), Y_pat + tx2(2), Z_pat + tx2(3), G_norm, ...
    'FaceAlpha', 0.5, 'EdgeColor', 'none', 'FaceColor', [1 0.3 0.1]);

% Labels
text(world_pos1(1,1)*1000 - 200, world_pos1(1,2)*1000, world_pos1(1,3)*1000 + 200, ...
    'Sensor 1', 'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
text(world_pos2(1,1)*1000 + 200, world_pos2(1,2)*1000, world_pos2(1,3)*1000 + 200, ...
    'Sensor 2', 'FontSize', 8, 'FontWeight', 'bold');

% View settings (same as full figure, no light to avoid specular glow)
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('RO4 - Burried Object Simulation with Uneven Terrain (Lite)');
grid on;
set(gca, 'Projection', 'orthographic');
view([174.6603927156378,2.043555780726723]);
daspect([1 1 1]);
ylim([gy_min gy_max]);
xlim([-1000 1000]);
zlim([-total_depth-50 800]);
hold off;

set(gcf, 'Visible', 'on');  % so .fig opens visible when double-clicked
savefig(gcf, fullfile(output_dir, 'BumpyTerrain_Setup_Lite.fig'));
exportgraphics(gcf, fullfile(output_dir, 'BumpyTerrain_Setup_Lite.png'), 'Resolution', 150);
close(gcf);
fprintf('BumpyTerrain_Setup_Lite.fig saved (lightweight - openable in figure viewer).\n');

%% === ZOOMED DETAIL FIGURE ===
figure('Name', 'Terrain Detail', 'Position', [50, 50, 1000, 600], 'Visible', 'off');
hold on;

% Zoom: Y = 2000 to 5000, show individual blocks clearly
zoom_y_start = 2000;
zoom_y_end = 5000;
iy_start = max(1, floor((zoom_y_start - track_y_start) / chunk_size) + 1);
iy_end = min(n_chunks_y, ceil((zoom_y_end - track_y_start) / chunk_size));

% Draw all 5 layers in detail view
for layer = 1:n_layers
    z_layer_top = -(layer-1) * layer_thickness;
    z_layer_bot = -layer * layer_thickness;
    for iy = iy_start:iy_end
        for ix = 1:n_chunks_x
            x0 = x_edges(ix); x1 = x_edges(ix+1);
            y0 = y_edges(iy); y1 = y_edges(iy+1);
            
            shade = 0.85 + 0.30 * er_norm_layers{layer}(iy, ix);
            brown = min([0.55, 0.35, 0.17] * shade, 1);
            % Darken deeper layers slightly
            depth_factor = 1.0 - 0.1*(layer-1);
            brown = brown * depth_factor;
            
            if layer == 1
                z_top = surface_heights(iy, ix);
            else
                z_top = z_layer_top;
            end
            
            % Top face
            patch([x0 x1 x1 x0], [y0 y0 y1 y1], [z_top z_top z_top z_top], ...
                brown, 'EdgeColor', brown*0.7, 'LineWidth', 0.5);
            % Front face
            patch([x0 x1 x1 x0], [y0 y0 y0 y0], [z_top z_top z_layer_bot z_layer_bot], ...
                brown*0.85, 'EdgeColor', brown*0.6, 'LineWidth', 0.3);
            % Right face  
            patch([x1 x1 x1 x1], [y0 y1 y1 y0], [z_top z_top z_layer_bot z_layer_bot], ...
                brown*0.9, 'EdgeColor', brown*0.6, 'LineWidth', 0.3);
        end
    end
end

% Object 1 at Y=3200 (bright yellow)
oy = 3200;
obj_c = [1.0 0.85 0.0]; obj_e = [0.8 0.6 0.0];
patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy+obj_l oy+obj_l], ...
    [obj_z_top obj_z_top obj_z_top obj_z_top], obj_c, ...
    'FaceAlpha', 0.95, 'EdgeColor', obj_e, 'LineWidth', 1.5);
patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy-obj_l oy-obj_l], ...
    [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_c*0.85, ...
    'FaceAlpha', 0.95, 'EdgeColor', obj_e);
patch([obj_w obj_w obj_w obj_w], [oy-obj_l oy+obj_l oy+obj_l oy-obj_l], ...
    [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_c*0.9, ...
    'FaceAlpha', 0.95, 'EdgeColor', obj_e);

light('Position', [0, 3000, 500]);
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title(sprintf('Detail: 100mm blocks, top 0-%dmm, depth %dmm (5 layers)', surface_z_max, total_depth));
grid on;
% view([azimuth, elevation]): azimuth=rotate around Z, elevation=tilt up from XY
view([-25, 35]);
daspect([1 1 1]);
zlim([-total_depth-20 surface_z_max+20]);
ylim([zoom_y_start zoom_y_end]);
hold off;

set(gcf, 'Visible', 'on');  % so .fig opens visible when double-clicked
savefig(gcf, fullfile(output_dir, 'BumpyTerrain_Detail.fig'));
exportgraphics(gcf, fullfile(output_dir, 'BumpyTerrain_Detail.png'), 'Resolution', 150);
close(gcf);
fprintf('BumpyTerrain_Detail.png saved.\n');

%% === TERRAIN SURFACE PROFILE (2D cross-section) ===
figure('Name', 'Terrain Profile', 'Position', [50, 50, 1400, 500], 'Visible', 'off');

% Plot surface height profile along the center line (X=0, chunk ix=8)
center_ix = round(n_chunks_x / 2);  % middle column
y_positions = y_centers;  % center of each Y chunk
height_profile = surface_heights(:, center_ix);

% Also plot a few adjacent lines for context
subplot(2,1,1);
hold on;
colors = lines(5);
plot_ix = [1, 4, 8, 12, 15];  % spread across X
for pi = 1:length(plot_ix)
    ix = plot_ix(pi);
    plot(y_positions/1000, surface_heights(:, ix), '-', ...
        'Color', colors(pi,:), 'LineWidth', 1.2);
end
legend(arrayfun(@(ix) sprintf('X=%.0fmm', x_centers(ix)), plot_ix, 'UniformOutput', false), ...
    'Location', 'eastoutside');

% Mark object locations
for oi = 1:length(obj_y_centers)
    xline(obj_y_centers(oi)/1000, 'r--', 'LineWidth', 1);
end

xlabel('Y position along track (m)');
ylabel('Surface height (mm)');
title(sprintf('Terrain Surface Profile (±%d%% variation, 0-%dmm roughness)', variation_pct, surface_z_max));
grid on;
ylim([-1 surface_z_max+1]);
hold off;

% Bottom subplot: εr variation along center line
subplot(2,1,2);
hold on;
er_profile = er_layers{1}(:, center_ix);
plot(y_positions/1000, er_profile, 'k-', 'LineWidth', 1.2);
yline(base_er, 'b--', ['Base \epsilon_r = ' num2str(base_er, '%.1f')], 'LineWidth', 1);
yline(base_er * (1 + variation_pct/100), 'r:', sprintf('+%d%%', variation_pct));
yline(base_er * (1 - variation_pct/100), 'r:', sprintf('-%d%%', variation_pct));

for oi = 1:length(obj_y_centers)
    xline(obj_y_centers(oi)/1000, 'r--', 'LineWidth', 1);
end

xlabel('Y position along track (m)');
ylabel('\epsilon_r (relative permittivity)');
title('Surface Layer Permittivity Along Track Center (X=0)');
grid on;
hold off;

exportgraphics(gcf, fullfile(output_dir, 'BumpyTerrain_Profile.png'), 'Resolution', 150);
close(gcf);
fprintf('BumpyTerrain_Profile.png saved.\n');
