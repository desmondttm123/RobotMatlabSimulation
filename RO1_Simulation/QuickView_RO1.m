%% QuickView_RO1.m
% 3D visualization of RO1 setup: single antenna array facing a material
% panel at 1m distance, with ray-traced multipath showing TX bouncing off
% the material and returning to RX elements.
%
% Outputs: Results/RO1_Setup_3D.fig + .png

clear; close all; clc;

%% Parameters (antenna array same as SimConfig)
freq = 2.45e9;
arrayWidth = 100;    % mm (PCB width)
arrayHeight = 100;   % mm (PCB height)
nCols = 4;           % columns in RX grid
nRows = 8;           % rows in RX grid
nRX = nCols * nRows;
tilt_angle = 0;      % degrees — facing FORWARD (not tilted down)
sensor_z = 300;      % mm height of array center (centered on material)

% Material panel
mat_distance = 1000;   % mm (1 meter in front)
mat_width = 600;       % mm (60cm)
mat_height = 600;      % mm (60cm)

% Output
output_dir = 'Results';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% Generate antenna element positions (mm)
% TX at center, 32 RX in 4x8 grid
nTotal = nRX + 1;
dx = arrayWidth / (nCols - 1);
dz = arrayHeight / (nRows - 1);

local_pos = zeros(nTotal, 3);
local_pos(1,:) = [0, 0, 0]; % TX at center
idx = 2;
for row = 1:nRows
    for col = 1:nCols
        local_pos(idx,:) = [-arrayWidth/2 + (col-1)*dx, ...
                            -arrayHeight/2 + (row-1)*dz, 0];
        idx = idx + 1;
    end
end

% Apply tilt (0° = facing forward along +Y axis)
% Rotate so array normal points along +Y (forward)
% Local coordinate: Z is array normal. Rotate -90° about X to make it face +Y.
theta_rad = deg2rad(90 - tilt_angle);  % 90° rotation = facing forward
Rx = [1, 0, 0; 0, cos(theta_rad), -sin(theta_rad); 0, sin(theta_rad), cos(theta_rad)];
rotated_pos = (Rx * local_pos')';

% Place array at (0, 0, sensor_z) — facing +Y direction
world_pos = rotated_pos;
world_pos(:,3) = world_pos(:,3) + sensor_z;

%% Create terrain STL for ray tracing (material panel as a thin box)
% Material panel center at (0, mat_distance, sensor_z) — same height as antenna
panel_center = [0, mat_distance, sensor_z] / 1000;  % convert to meters
panel_w = mat_width / 2 / 1000;   % half-width (m)
panel_h = mat_height / 2 / 1000;  % half-height (m)
panel_d = 0.01;                    % 10mm thickness

% Build STL: panel as a thin slab
V = [panel_center(1)-panel_w, panel_center(2),         panel_center(3)-panel_h;
     panel_center(1)+panel_w, panel_center(2),         panel_center(3)-panel_h;
     panel_center(1)+panel_w, panel_center(2),         panel_center(3)+panel_h;
     panel_center(1)-panel_w, panel_center(2),         panel_center(3)+panel_h;
     panel_center(1)-panel_w, panel_center(2)+panel_d, panel_center(3)-panel_h;
     panel_center(1)+panel_w, panel_center(2)+panel_d, panel_center(3)-panel_h;
     panel_center(1)+panel_w, panel_center(2)+panel_d, panel_center(3)+panel_h;
     panel_center(1)-panel_w, panel_center(2)+panel_d, panel_center(3)+panel_h];

F = [1 2 3; 1 3 4;   % front face
     5 7 6; 5 8 7;   % back face
     1 5 6; 1 6 2;   % bottom
     4 3 7; 4 7 8;   % top
     1 4 8; 1 8 5;   % left
     2 6 7; 2 7 3];  % right

% Also add a ground plane
gnd_size = 1.5;  % 1.5m
V_gnd = [-gnd_size, -0.5, 0;
           gnd_size, -0.5, 0;
           gnd_size,  gnd_size, 0;
          -gnd_size,  gnd_size, 0;
          -gnd_size, -0.5, -0.02;
           gnd_size, -0.5, -0.02;
           gnd_size,  gnd_size, -0.02;
          -gnd_size,  gnd_size, -0.02];
F_gnd = F + size(V,1);
V_all = [V; V_gnd];
F_all = [F; F_gnd];

stl_path = fullfile(output_dir, 'ro1_scene.stl');
TR = triangulation(F_all, V_all);
stlwrite(TR, stl_path);

%% Ray trace using Communications Toolbox
fprintf('Ray tracing...\n');
viewer = siteviewer("SceneModel", stl_path, "ShowOrigin", false);

pm = propagationModel("raytracing", ...
    "CoordinateSystem", "cartesian", ...
    "Method", "sbr", ...
    "SurfaceMaterial", "custom", ...
    "SurfaceMaterialPermittivity", 7.0, ...
    "SurfaceMaterialConductivity", 0.01);
pm.MaxNumReflections = 2;

% Create TX site (center of array)
tx_pos = world_pos(1,:) / 1000;  % convert to meters
tx_site = txsite("cartesian", "AntennaPosition", tx_pos', ...
    "TransmitterFrequency", freq);

% Create RX sites (all 32 RX elements)
rx_sites = rxsite.empty;
for ri = 2:nTotal
    rx_pos = world_pos(ri,:) / 1000;
    rx_sites(ri-1) = rxsite("cartesian", "AntennaPosition", rx_pos');
end

% Trace rays TX -> material -> RX
rays_all = raytrace(tx_site, rx_sites, pm);
close(viewer);

n_rays = 0;
for ri = 1:numel(rays_all)
    n_rays = n_rays + numel(rays_all{ri});
end
fprintf('  Traced %d rays\n', n_rays);

%% Generate 3D figure
fig = figure('Position', [50 50 1100 800], 'Color', 'w', 'Visible', 'off');
ax = axes(fig); hold on;

% --- Ground plane ---
ground_color = [0.55 0.45 0.3];
patch([-800 800 800 -800], [-300 -300 1400 1400], [0 0 0 0], ...
    ground_color, 'FaceAlpha', 0.25, 'EdgeColor', ground_color, 'LineWidth', 0.5);
% Grid lines
for gx = -600:200:600
    plot3([gx gx], [-300 1400], [0 0], '-', 'Color', [0.5 0.4 0.3 0.2], 'LineWidth', 0.3);
end
for gy = 0:200:1200
    plot3([-800 800], [gy gy], [0 0], '-', 'Color', [0.5 0.4 0.3 0.2], 'LineWidth', 0.3);
end

% --- Material panel (60cm x 60cm at 1m) ---
panel_color = [0.3 0.3 0.8];
panel_x = [-mat_width/2, mat_width/2, mat_width/2, -mat_width/2];
panel_y = [mat_distance, mat_distance, mat_distance, mat_distance];
panel_z = [sensor_z - mat_height/2, sensor_z - mat_height/2, ...
           sensor_z + mat_height/2, sensor_z + mat_height/2];
patch(panel_x, panel_y, panel_z, panel_color, ...
    'FaceAlpha', 0.5, 'EdgeColor', panel_color*0.7, 'LineWidth', 2);
text(0, mat_distance + 30, sensor_z + mat_height/2 + 40, ...
    sprintf('Material Panel\n600×600 mm'), ...
    'FontSize', 10, 'FontWeight', 'bold', 'Color', panel_color*0.7, ...
    'HorizontalAlignment', 'center');

% --- PCB board ---
pcb_color = [0.1 0.6 0.1];
pcb_pts = world_pos(2:end, :);
k_hull = convhull(pcb_pts(:,1), pcb_pts(:,3));
my = mean(pcb_pts(:,2));
fill3(pcb_pts(k_hull,1), ones(size(k_hull))*my, pcb_pts(k_hull,3), ...
    pcb_color, 'FaceAlpha', 0.5, 'EdgeColor', pcb_color*0.7, 'LineWidth', 1.5);

% --- TX marker ---
scatter3(world_pos(1,1), world_pos(1,2), world_pos(1,3), ...
    150, 'r', '^', 'filled', 'MarkerEdgeColor', 'k');
text(world_pos(1,1), world_pos(1,2) - 40, world_pos(1,3) + 50, ...
    'TX', 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'r', ...
    'HorizontalAlignment', 'center');

% --- RX markers ---
scatter3(world_pos(2:end,1), world_pos(2:end,2), world_pos(2:end,3), ...
    25, 'b', 'filled');
text(world_pos(nTotal,1) + 30, world_pos(nTotal,2), world_pos(nTotal,3), ...
    '32 RX', 'FontSize', 9, 'Color', [0 0 0.7], 'FontAngle', 'italic');

% --- Ray paths (TX leg = red, RX leg = blue) ---
tx_color = [0.9 0.1 0.1];  % red for outgoing TX->material
rx_color = [0.1 0.3 0.9];  % blue for returning material->RX
for ri = 1:numel(rays_all)
    ray_set = rays_all{ri};
    for rj = 1:numel(ray_set)
        ray = ray_set(rj);
        tx_loc = ray.TransmitterLocation(:)' * 1000;  % back to mm
        rx_loc = ray.ReceiverLocation(:)' * 1000;
        
        if ray.NumInteractions == 0
            % Direct path — draw as TX color
            plot3([tx_loc(1) rx_loc(1)], [tx_loc(2) rx_loc(2)], [tx_loc(3) rx_loc(3)], '-', ...
                'Color', [tx_color 0.5], 'LineWidth', 1.2);
        else
            interactions = ray.Interactions;
            int_pts = zeros(ray.NumInteractions, 3);
            for ki = 1:ray.NumInteractions
                int_pts(ki,:) = interactions(ki).Location(:)' * 1000;
            end
            % TX leg: TX -> first interaction (outgoing, red)
            first_hit = int_pts(1,:);
            plot3([tx_loc(1) first_hit(1)], [tx_loc(2) first_hit(2)], [tx_loc(3) first_hit(3)], '-', ...
                'Color', [tx_color 0.5], 'LineWidth', 1.2);
            % RX leg: last interaction -> RX (returning, blue)
            last_hit = int_pts(end,:);
            plot3([last_hit(1) rx_loc(1)], [last_hit(2) rx_loc(2)], [last_hit(3) rx_loc(3)], '-', ...
                'Color', [rx_color 0.5], 'LineWidth', 1.2);
            % Middle segments (if multi-bounce)
            if ray.NumInteractions > 1
                mid_pts = [int_pts];
                for si = 1:size(mid_pts,1)-1
                    plot3([mid_pts(si,1) mid_pts(si+1,1)], [mid_pts(si,2) mid_pts(si+1,2)], ...
                        [mid_pts(si,3) mid_pts(si+1,3)], '-', ...
                        'Color', [0.6 0.2 0.6 0.4], 'LineWidth', 1.0);
                end
            end
        end
    end
end

% --- Distance annotation ---
plot3([0 0], [0 mat_distance], [10 10], 'k--', 'LineWidth', 1.2);
text(0, mat_distance/2, 20, '1 m', 'FontSize', 11, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

% --- Formatting ---
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title(sprintf('RO1 Setup — Single Antenna Array vs Material'), ...
    'FontSize', 13, 'FontWeight', 'bold');
grid on;
set(ax, 'Projection', 'perspective');
view([35, 25]);
daspect([1 1 1]);
xlim([-500 500]);
ylim([-200 1200]);
zlim([-20 500]);
light('Position', [500 -500 800]);
hold off;

% --- Save ---
savefig(fig, fullfile(output_dir, 'RO1_Setup_3D.fig'));
exportgraphics(fig, fullfile(output_dir, 'RO1_Setup_3D.png'), 'Resolution', 200);
fprintf('Saved: %s/RO1_Setup_3D.fig + .png\n', output_dir);
close(fig);
fprintf('Done.\n');
