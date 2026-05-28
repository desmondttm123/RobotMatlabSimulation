%% Quick 3D Setup Visualization (with Robot STL)
% All geometry parameters loaded from SimConfig.m
clear; close all; clc;

%% Load shared configuration
SimConfig;

%% Unpack parameters from cfg
c = 299792458;
freq = cfg.freq;
lambda = c / freq;
arrayWidth = cfg.arrayWidth / 1000;     % convert mm -> m for this script
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
gy_min = cfg.track_y_start - 1000;
gy_max = cfg.track_y_end;

% Objects (mm)
obj_w = cfg.obj_x_half;
obj_l = cfg.obj_y_half;
obj_z_top = cfg.obj_z_top;
obj_z_bot = cfg.obj_z_bottom;
obj_y_centers = cfg.obj_y_centers;
obj_names = cfg.obj_names;

%% Generate positions
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

% Sensor 1: offset X = -90mm, Z = 95.26mm
world_pos1 = rotated_pos;
world_pos1(:,1) = world_pos1(:,1) + sensor1_x;
world_pos1(:,3) = world_pos1(:,3) + height_center;

% Sensor 2: offset X = +90mm, Z = 95.26mm
world_pos2 = rotated_pos;
world_pos2(:,1) = world_pos2(:,1) + sensor2_x;
world_pos2(:,3) = world_pos2(:,3) + height_center;

%% 3D Visualization
figure('Name', '3D Setup View', 'Position', [50, 50, 1000, 700]);

% Ground plane with 500mm depth (large: spans full Y range)
gs_x = track_width / 2;   % half-size in X (mm)
gd = -500;     % ground depth in mm
patch([-gs_x gs_x gs_x -gs_x], [gy_min gy_min gy_max gy_max], [0 0 0 0], ...
    [0.6 0.4 0.2], 'FaceAlpha', 0.4, 'EdgeColor', [0.4 0.3 0.1]);
hold on;
patch([-gs_x gs_x gs_x -gs_x], [gy_min gy_min gy_min gy_min], [0 0 gd gd], ...
    [0.5 0.35 0.15], 'FaceAlpha', 0.3, 'EdgeColor', [0.4 0.3 0.1]);
patch([gs_x gs_x gs_x gs_x], [gy_min gy_max gy_max gy_min], [0 0 gd gd], ...
    [0.5 0.35 0.15], 'FaceAlpha', 0.3, 'EdgeColor', [0.4 0.3 0.1]);
patch([-gs_x gs_x gs_x -gs_x], [gy_min gy_min gy_max gy_max], [gd gd gd gd], ...
    [0.4 0.3 0.1], 'FaceAlpha', 0.2, 'EdgeColor', [0.4 0.3 0.1]);

% PCB board - Sensor 1 (X = -90mm)
board_corners = [-arrayWidth/2, -arrayHeight/2, 0; arrayWidth/2, -arrayHeight/2, 0;
                  arrayWidth/2, arrayHeight/2, 0; -arrayWidth/2, arrayHeight/2, 0];
bc1 = (Rx * board_corners')';
bc1(:,1) = bc1(:,1) + sensor1_x;
bc1(:,3) = bc1(:,3) + height_center;
fill3(bc1(:,1)*1000, bc1(:,2)*1000, bc1(:,3)*1000, ...
    [0.1 0.6 0.1], 'FaceAlpha', 0.5, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);

% PCB board - Sensor 2 (X = +90mm)
bc2 = (Rx * board_corners')';
bc2(:,1) = bc2(:,1) + sensor2_x;
bc2(:,3) = bc2(:,3) + height_center;
fill3(bc2(:,1)*1000, bc2(:,2)*1000, bc2(:,3)*1000, ...
    [0.1 0.6 0.1], 'FaceAlpha', 0.5, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);

% Sensor 1 antennas
scatter3(world_pos1(2:end,1)*1000, world_pos1(2:end,2)*1000, world_pos1(2:end,3)*1000, ...
    40, 'b', 'filled');
scatter3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, ...
    120, 'r', '^', 'filled');

% Sensor 2 antennas
scatter3(world_pos2(2:end,1)*1000, world_pos2(2:end,2)*1000, world_pos2(2:end,3)*1000, ...
    40, 'b', 'filled');
scatter3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, ...
    120, 'r', '^', 'filled');

% Array normals
normal_local = [0, 0, -1];
normal_world = (Rx * normal_local')';
quiver3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, ...
    normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, ...
    'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
quiver3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, ...
    normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, ...
    'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);

% Labels with annotation arrows - placed above and outside
% Sensor 1 label - above left
s1_pt = [world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000];
s1_lbl = [s1_pt(1) - 300, s1_pt(2), s1_pt(3) + 300];
plot3([s1_pt(1), s1_lbl(1)], [s1_pt(2), s1_lbl(2)], [s1_pt(3), s1_lbl(3)], 'k-', 'LineWidth', 1);
scatter3(s1_pt(1), s1_pt(2), s1_pt(3), 20, 'k', 'filled');
text(s1_lbl(1)-10, s1_lbl(2), s1_lbl(3), 'Material Sensor 1', ...
    'FontSize', 8, 'FontWeight', 'bold', 'Color', 'k', 'HorizontalAlignment', 'right');

% Sensor 2 label - above right
s2_pt = [world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000];
s2_lbl = [s2_pt(1) + 300, s2_pt(2), s2_pt(3) + 300];
plot3([s2_pt(1), s2_lbl(1)], [s2_pt(2), s2_lbl(2)], [s2_pt(3), s2_lbl(3)], 'k-', 'LineWidth', 1);
scatter3(s2_pt(1), s2_pt(2), s2_pt(3), 20, 'k', 'filled');
text(s2_lbl(1)+10, s2_lbl(2), s2_lbl(3), 'Material Sensor 2', ...
    'FontSize', 8, 'FontWeight', 'bold', 'Color', 'k');

% Robot STL (already in mm) - apply transforms
robot_stl = stlread(cfg.robot_stl_path);
robot_verts = robot_stl.Points;

% Rotate 90° about Y axis
Ry90 = [cos(pi/2), 0, sin(pi/2); 0, 1, 0; -sin(pi/2), 0, cos(pi/2)];
robot_verts = (Ry90 * robot_verts')';

% Rotate 180° about Z axis
Rz180 = [cos(pi), -sin(pi), 0; sin(pi), cos(pi), 0; 0, 0, 1];
robot_verts = (Rz180 * robot_verts')';

% Translate along Y and Z
robot_verts(:,2) = robot_verts(:,2) + cfg.robot_y_offset;
robot_verts(:,3) = robot_verts(:,3) + cfg.robot_z_offset;

% Center robot at X = 0
robot_verts(:,1) = robot_verts(:,1) - mean(robot_verts(:,1));

robot_tri = triangulation(robot_stl.ConnectivityList, robot_verts);
trisurf(robot_tri, 'FaceColor', [0.75 0.75 0.8], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.35, 'FaceLighting', 'gouraud');
light('Position', [200 200 300]);

% Embedded material objects
obj_color = [0.35 0.2 0.05];  % darker brown

for oi = 1:length(obj_y_centers)
    oy = obj_y_centers(oi);
    % Top face
    patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy+obj_l oy+obj_l], ...
        [obj_z_top obj_z_top obj_z_top obj_z_top], obj_color, 'FaceAlpha', 0.8, 'EdgeColor', [0.2 0.1 0]);
    % Front face
    patch([-obj_w obj_w obj_w -obj_w], [oy-obj_l oy-obj_l oy-obj_l oy-obj_l], ...
        [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.8, 'FaceAlpha', 0.8, 'EdgeColor', [0.2 0.1 0]);
    % Right face
    patch([obj_w obj_w obj_w obj_w], [oy-obj_l oy+obj_l oy+obj_l oy-obj_l], ...
        [obj_z_top obj_z_top obj_z_bot obj_z_bot], obj_color*0.9, 'FaceAlpha', 0.8, 'EdgeColor', [0.2 0.1 0]);
    % Label - placed to the left with arrow
    lbl_pos = [-gs_x - 200, oy, 250];
    plot3([0, lbl_pos(1)], [oy, lbl_pos(2)], [obj_z_top, lbl_pos(3)], 'k-', 'LineWidth', 0.8);
    scatter3(0, oy, obj_z_top, 15, 'k', 'filled');
    text(lbl_pos(1)-10, lbl_pos(2), lbl_pos(3), obj_names{oi}, ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', 'k', 'HorizontalAlignment', 'right');
end

xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('RO4 Simulation Setup');
grid on;
set(gca, 'Projection', 'orthographic');
view([178.9646, 1.2123]);
daspect([1 1 1]);
ylim([gy_min gy_max]);
xlim([-1000 1000]);
zlim([-500 800]);
hold off;

savefig(gcf, fullfile(cfg.output_dir, 'Setup_3D.fig'));
exportgraphics(gcf, fullfile(cfg.output_dir, 'Setup_3D.png'), 'Resolution', 150);
fprintf('Setup_3D.png saved to %s\n', cfg.output_dir);
