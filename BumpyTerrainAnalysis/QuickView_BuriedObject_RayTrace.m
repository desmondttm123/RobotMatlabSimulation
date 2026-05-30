%% QuickView_BuriedObject_RayTrace.m
% Visualize the EFFECT of a buried void on received signal power.
% SBR ray tracing gives identical geometry in both cases (rays can't
% penetrate ground). The difference is in the Fresnel reflection
% coefficient at each bounce point — the void changes effective εr.
%
% Produces two separate figures:
%   - BuriedObject_NoVoid.fig/.png  (uniform ground, all bounces same εr)
%   - BuriedObject_WithVoid.fig/.png (void changes εr over its footprint)
%
% Rays are color-coded by received power: brighter/thicker = more power.
% Over the void, reflection coefficient changes → visible power difference.

clear; close all; clc;

addpath('..');
SimConfig;

output_dir = 'Results';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% Parameters
freq = cfg.freq;
lambda = 299792458 / freq;
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

% Object (buried void)
obj_x_half = cfg.obj_x_half / 1000;
obj_y_half = cfg.obj_y_half / 1000;
obj_z_top = cfg.obj_z_top / 1000;
obj_z_bot = cfg.obj_z_bottom / 1000;

% Ground material
er_ground = cfg.terrains(1).er;    % DrySand = 3.5
er_void = 1.0;                     % Air void
sigma_ground = cfg.terrains(1).sigma;

%% Generate antenna positions (centered at Y=0)
dx = arrayWidth / (nCols - 1);
dz = arrayHeight / (nRows - 1);
local_pos = zeros(nTotal, 3);
local_pos(1,:) = [0, 0, 0];
idx = 2;
for row = 1:nRows
    for col = 1:nCols
        local_pos(idx,:) = [-arrayWidth/2 + (col-1)*dx, ...
                            -arrayHeight/2 + (row-1)*dz, 0];
        idx = idx + 1;
    end
end

theta_rad = deg2rad(tilt_angle);
Rx_rot = [1,0,0; 0,cos(theta_rad),-sin(theta_rad); 0,sin(theta_rad),cos(theta_rad)];
rotated_pos = (Rx_rot * local_pos')';

world_pos1 = rotated_pos;
world_pos1(:,1) = world_pos1(:,1) + sensor1_x;
world_pos1(:,3) = world_pos1(:,3) + height_center;

world_pos2 = rotated_pos;
world_pos2(:,1) = world_pos2(:,1) + sensor2_x;
world_pos2(:,3) = world_pos2(:,3) + height_center;

%% Load robot STL
robot_stl = stlread(fullfile('..', cfg.robot_stl_path));
robot_verts = robot_stl.Points / 1000;
Ry90 = [cos(pi/2),0,sin(pi/2); 0,1,0; -sin(pi/2),0,cos(pi/2)];
robot_verts = (Ry90 * robot_verts')';
Rz180 = [cos(pi),-sin(pi),0; sin(pi),cos(pi),0; 0,0,1];
robot_verts = (Rz180 * robot_verts')';
robot_verts(:,2) = robot_verts(:,2) + cfg.robot_y_offset/1000;
robot_verts(:,3) = robot_verts(:,3) + cfg.robot_z_offset/1000;
robot_verts(:,1) = robot_verts(:,1) - mean(robot_verts(:,1));
robot_faces = robot_stl.ConnectivityList;

%% Build STL (ground + robot only — SBR scene)
gnd_size = 1.5;
gnd_d = 0.02;
V_gnd = [-gnd_size,-gnd_size,0; gnd_size,-gnd_size,0; gnd_size,gnd_size,0; -gnd_size,gnd_size,0;
          -gnd_size,-gnd_size,-gnd_d; gnd_size,-gnd_size,-gnd_d; gnd_size,gnd_size,-gnd_d; -gnd_size,gnd_size,-gnd_d];
F_box = [1 2 3;1 3 4;5 7 6;5 8 7;1 5 6;1 6 2;4 3 7;4 7 8;1 4 8;1 8 5;2 6 7;2 7 3];

V_scene = [V_gnd; robot_verts];
F_scene = [F_box; robot_faces + size(V_gnd,1)];
stl_path = fullfile(output_dir, 'scene_raytrack.stl');
stlwrite(triangulation(F_scene, V_scene), stl_path);

%% Ray trace (one set — geometry is same for both cases)
fprintf('Ray tracing (SBR)...\n');
viewer = siteviewer("SceneModel", stl_path, "ShowOrigin", false);
pm = propagationModel("raytracing", "CoordinateSystem","cartesian", ...
    "Method","sbr", "SurfaceMaterial","custom", ...
    "SurfaceMaterialPermittivity", er_ground, ...
    "SurfaceMaterialConductivity", sigma_ground);
pm.MaxNumReflections = 3;

tx1_site = txsite("cartesian","AntennaPosition",world_pos1(1,:)',"TransmitterFrequency",freq);
tx2_site = txsite("cartesian","AntennaPosition",world_pos2(1,:)',"TransmitterFrequency",freq);
rx1_sites = rxsite.empty; rx2_sites = rxsite.empty;
for ri = 2:nTotal
    rx1_sites(ri-1) = rxsite("cartesian","AntennaPosition",world_pos1(ri,:)');
    rx2_sites(ri-1) = rxsite("cartesian","AntennaPosition",world_pos2(ri,:)');
end

rays_a = raytrace(tx1_site, rx2_sites, pm);
rays_b = raytrace(tx2_site, rx1_sites, pm);
close(viewer);

n_rays = count_rays(rays_a) + count_rays(rays_b);
fprintf('  %d rays traced\n', n_rays);

%% Compute per-ray power for both scenarios using Fresnel model
% For each ray, find ground bounce point(s) and compute reflection coeff
[paths_a, power_novoid_a, power_void_a] = compute_ray_powers(rays_a, er_ground, er_void, obj_x_half, obj_y_half, lambda);
[paths_b, power_novoid_b, power_void_b] = compute_ray_powers(rays_b, er_ground, er_void, obj_x_half, obj_y_half, lambda);

%% Determine colormap range from actual data (narrowed to show difference)
all_power = [power_novoid_a; power_novoid_b; power_void_a; power_void_b];
p_center = median(all_power);
p_range = 6;  % ±6 dB around median — tight enough to see differences
p_min_clr = p_center - p_range;
p_max_clr = p_center + p_range;
fprintf('  Colormap range: [%.1f, %.1f] dB (centered on median %.1f)\n', p_min_clr, p_max_clr, p_center);

%% --- Figure 1: NO VOID (uniform ground) ---
fprintf('Generating figures...\n');
fig1 = figure('Position', [50 50 1100 800], 'Color', 'w', 'Visible', 'off');
ax1 = axes(fig1); hold on;
draw_scene(ax1, world_pos1, world_pos2, nTotal, robot_verts, robot_faces, false, obj_x_half, obj_y_half, obj_z_top, obj_z_bot);
draw_rays_power(paths_a, power_novoid_a, p_min_clr, p_max_clr);
draw_rays_power(paths_b, power_novoid_b, p_min_clr, p_max_clr);
mean_p1 = mean([power_novoid_a; power_novoid_b]);
title(sprintf('NO VOID — Uniform Ground (\\epsilon_r = %.1f)\n%d rays | Mean power: %.1f dB', er_ground, n_rays, mean_p1), ...
    'FontSize', 12, 'FontWeight', 'bold');
set_view(ax1);
colormap(ax1, jet);
caxis(ax1, [p_min_clr p_max_clr]);
% Annotate power stats
text(ax1, -480, -380, 240, sprintf('Mean: %.2f dB\nStd: %.2f dB\nMin: %.2f dB\nMax: %.2f dB', ...
    mean_p1, std([power_novoid_a; power_novoid_b]), min([power_novoid_a; power_novoid_b]), max([power_novoid_a; power_novoid_b])), ...
    'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', [1 1 1 0.8], 'EdgeColor', 'k');
hold off;

savefig(fig1, fullfile(output_dir, 'BuriedObject_NoVoid.fig'));
exportgraphics(fig1, fullfile(output_dir, 'BuriedObject_NoVoid.png'), 'Resolution', 200);
close(fig1);
fprintf('  Saved BuriedObject_NoVoid.fig + .png\n');

%% --- Figure 2: WITH VOID ---
fig2 = figure('Position', [50 50 1100 800], 'Color', 'w', 'Visible', 'off');
ax2 = axes(fig2); hold on;
draw_scene(ax2, world_pos1, world_pos2, nTotal, robot_verts, robot_faces, true, obj_x_half, obj_y_half, obj_z_top, obj_z_bot);
draw_rays_power(paths_a, power_void_a, p_min_clr, p_max_clr);
draw_rays_power(paths_b, power_void_b, p_min_clr, p_max_clr);
mean_p2 = mean([power_void_a; power_void_b]);
title(sprintf('WITH VOID — \\epsilon_r changes over void (\\epsilon_{eff} \\approx 1.75)\n%d rays | Mean power: %.1f dB (\\Delta = %.2f dB)', n_rays, mean_p2, mean_p2-mean_p1), ...
    'FontSize', 12, 'FontWeight', 'bold');
set_view(ax2);
colormap(ax2, jet);
caxis(ax2, [p_min_clr p_max_clr]);
% Annotate power stats
text(ax2, -480, -380, 240, sprintf('Mean: %.2f dB\nStd: %.2f dB\nMin: %.2f dB\nMax: %.2f dB\n\\DeltaMean: %.2f dB', ...
    mean_p2, std([power_void_a; power_void_b]), min([power_void_a; power_void_b]), max([power_void_a; power_void_b]), mean_p2-mean_p1), ...
    'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', [1 1 1 0.8], 'EdgeColor', 'k');
hold off;

savefig(fig2, fullfile(output_dir, 'BuriedObject_WithVoid.fig'));
exportgraphics(fig2, fullfile(output_dir, 'BuriedObject_WithVoid.png'), 'Resolution', 200);
close(fig2);
fprintf('  Saved BuriedObject_WithVoid.fig + .png\n');

%% Print power summary
p1_all = [power_novoid_a; power_novoid_b];
p2_all = [power_void_a; power_void_b];
delta = p2_all - p1_all;
affected = abs(delta) > 0.1;
fprintf('\n=== Power Summary ===\n');
fprintf('  Rays affected by void: %d / %d\n', sum(affected), numel(delta));
fprintf('  Mean power shift (affected rays): %.2f dB\n', mean(delta(affected)));
fprintf('  Max power shift: %.2f dB\n', max(abs(delta)));

%% --- Figure 3: TOP VIEW — NO VOID ---
fig3 = figure('Position', [50 50 1100 800], 'Color', 'w', 'Visible', 'off');
ax3 = axes(fig3); hold on;
draw_scene(ax3, world_pos1, world_pos2, nTotal, robot_verts, robot_faces, false, obj_x_half, obj_y_half, obj_z_top, obj_z_bot);
draw_rays_power(paths_a, power_novoid_a, p_min_clr, p_max_clr);
draw_rays_power(paths_b, power_novoid_b, p_min_clr, p_max_clr);
title(sprintf('TOP VIEW — NO VOID (\\epsilon_r = %.1f)\n%d rays | Mean: %.1f dB', er_ground, n_rays, mean_p1), 'FontSize', 12, 'FontWeight', 'bold');
set_top_view(ax3);
colormap(ax3, jet); caxis(ax3, [p_min_clr p_max_clr]);
hold off;
savefig(fig3, fullfile(output_dir, 'BuriedObject_TopView_NoVoid.fig'));
exportgraphics(fig3, fullfile(output_dir, 'BuriedObject_TopView_NoVoid.png'), 'Resolution', 200);
close(fig3);
fprintf('  Saved BuriedObject_TopView_NoVoid.fig + .png\n');

%% --- Figure 4: TOP VIEW — WITH VOID ---
fig4 = figure('Position', [50 50 1100 800], 'Color', 'w', 'Visible', 'off');
ax4 = axes(fig4); hold on;
draw_scene(ax4, world_pos1, world_pos2, nTotal, robot_verts, robot_faces, true, obj_x_half, obj_y_half, obj_z_top, obj_z_bot);
draw_rays_power(paths_a, power_void_a, p_min_clr, p_max_clr);
draw_rays_power(paths_b, power_void_b, p_min_clr, p_max_clr);
title(sprintf('TOP VIEW — WITH VOID (\\epsilon_{eff} \\approx 1.75)\n%d rays | Mean: %.1f dB (\\Delta = %.2f dB)', n_rays, mean_p2, mean_p2-mean_p1), 'FontSize', 12, 'FontWeight', 'bold');
set_top_view(ax4);
colormap(ax4, jet); caxis(ax4, [p_min_clr p_max_clr]);
hold off;
savefig(fig4, fullfile(output_dir, 'BuriedObject_TopView_WithVoid.fig'));
exportgraphics(fig4, fullfile(output_dir, 'BuriedObject_TopView_WithVoid.png'), 'Resolution', 200);
close(fig4);
fprintf('  Saved BuriedObject_TopView_WithVoid.fig + .png\n');

fprintf('Done.\n');

%% ===== LOCAL FUNCTIONS =====

function [paths, power_novoid, power_void] = compute_ray_powers(ray_cell, er_gnd, er_void, ox, oy, lambda)
    % Extract paths and compute power for each ray under both scenarios
    paths = {};
    power_novoid = [];
    power_void = [];
    
    for ri = 1:numel(ray_cell)
        ray_set = ray_cell{ri};
        for rj = 1:numel(ray_set)
            ray = ray_set(rj);
            tx_loc = ray.TransmitterLocation(:)' * 1000;  % mm
            rx_loc = ray.ReceiverLocation(:)' * 1000;
            
            if ray.NumInteractions == 0
                path_pts = [tx_loc; rx_loc];
                bounce_pts = [];
            else
                interactions = ray.Interactions;
                int_pts = zeros(ray.NumInteractions, 3);
                for ki = 1:ray.NumInteractions
                    int_pts(ki,:) = interactions(ki).Location(:)' * 1000;
                end
                path_pts = [tx_loc; int_pts; rx_loc];
                % Ground bounces = interactions near z=0
                bounce_pts = int_pts(abs(int_pts(:,3)) < 20, :);  % within 20mm of ground
            end
            
            paths{end+1} = path_pts; %#ok<AGROW>
            
            % Compute total path length
            total_dist = 0;
            for si = 1:size(path_pts,1)-1
                total_dist = total_dist + norm(path_pts(si+1,:) - path_pts(si,:));
            end
            
            % Free-space path loss
            fspl = 20*log10(4*pi*total_dist/1000/lambda);
            
            % Fresnel reflection coefficient at ground bounces
            % No void: always er_gnd
            gamma_novoid = 0;
            gamma_void = 0;
            n_bounces_gnd = size(bounce_pts, 1);
            
            if n_bounces_gnd > 0
                for bi = 1:n_bounces_gnd
                    bx = bounce_pts(bi, 1) / 1000;  % m
                    by = bounce_pts(bi, 2) / 1000;
                    
                    % Incidence angle (approximate from geometry)
                    if bi == 1
                        inc_vec = bounce_pts(bi,:) - tx_loc;
                    else
                        inc_vec = bounce_pts(bi,:) - path_pts(bi,:);
                    end
                    theta_i = acos(abs(inc_vec(3)) / norm(inc_vec));
                    
                    % No void: uniform ground
                    G_nv = fresnel_coeff(theta_i, er_gnd);
                    gamma_novoid = gamma_novoid + 20*log10(abs(G_nv));
                    
                    % With void: check if bounce is over void footprint
                    if abs(bx) <= ox && abs(by) <= oy
                        % Over void: effective εr reduced dramatically
                        % Exaggerated for visualization (void dominates)
                        er_eff = er_void * 0.7 + er_gnd * 0.3;  % ~1.75 vs 3.5
                        G_v = fresnel_coeff(theta_i, er_eff);
                    else
                        G_v = fresnel_coeff(theta_i, er_gnd);
                    end
                    gamma_void = gamma_void + 20*log10(abs(G_v));
                end
            end
            
            power_novoid(end+1) = -fspl + gamma_novoid; %#ok<AGROW>
            power_void(end+1) = -fspl + gamma_void; %#ok<AGROW>
        end
    end
    power_novoid = power_novoid(:);
    power_void = power_void(:);
end

%% ===== LOCAL FUNCTIONS =====

function draw_scene(~, world_pos1, world_pos2, nTotal, robot_verts, robot_faces, show_void, ox, oy, oz_top, oz_bot)
    % Ground as solid 3D block from z=0 down to z=-200mm
    ground_color = [0.65 0.5 0.3];
    gp = 700;
    gnd_bot = -200;  % mm — full depth
    % Top face (ground surface)
    patch([-gp gp gp -gp], [-gp -gp gp gp], [0 0 0 0], ...
        ground_color, 'FaceAlpha', 0.4, 'EdgeColor', ground_color*0.5, 'LineWidth', 1);
    % Bottom face
    patch([-gp gp gp -gp], [-gp -gp gp gp], [gnd_bot gnd_bot gnd_bot gnd_bot], ...
        ground_color*0.5, 'FaceAlpha', 0.3, 'EdgeColor', ground_color*0.4, 'LineWidth', 0.8);
    % Front face (Y = -gp — visible when +Y faces viewer)
    patch([-gp gp gp -gp], [-gp -gp -gp -gp], [0 0 gnd_bot gnd_bot], ...
        ground_color*0.8, 'FaceAlpha', 0.45, 'EdgeColor', ground_color*0.4, 'LineWidth', 1);
    % Right face (X = gp)
    patch([gp gp gp gp], [-gp gp gp -gp], [0 0 gnd_bot gnd_bot], ...
        ground_color*0.7, 'FaceAlpha', 0.35, 'EdgeColor', ground_color*0.4, 'LineWidth', 0.8);
    % Left face (X = -gp)
    patch([-gp -gp -gp -gp], [-gp gp gp -gp], [0 0 gnd_bot gnd_bot], ...
        ground_color*0.7, 'FaceAlpha', 0.35, 'EdgeColor', ground_color*0.4, 'LineWidth', 0.8);
    % Back face (Y = gp)
    patch([-gp gp gp -gp], [gp gp gp gp], [0 0 gnd_bot gnd_bot], ...
        ground_color*0.6, 'FaceAlpha', 0.25, 'EdgeColor', ground_color*0.4, 'LineWidth', 0.5);
    % Interior fill: horizontal slices to show solid volume
    n_slices = 8;
    z_slices = linspace(-10, gnd_bot+10, n_slices);
    for si = 1:n_slices
        zs = z_slices(si);
        slice_alpha = 0.08 + 0.04 * (1 - abs(zs - gnd_bot/2) / abs(gnd_bot/2));
        patch([-gp gp gp -gp], [-gp -gp gp gp], [zs zs zs zs], ...
            ground_color*0.7, 'FaceAlpha', slice_alpha, 'EdgeColor', 'none');
    end
    % Grid on top surface
    for g = -600:200:600
        plot3([g g], [-gp gp], [0.5 0.5], '-', 'Color', [0.4 0.3 0.2 0.15], 'LineWidth', 0.3);
        plot3([-gp gp], [g g], [0.5 0.5], '-', 'Color', [0.4 0.3 0.2 0.15], 'LineWidth', 0.3);
    end
    
    % Void (buried inside the ground block)
    oxm = ox*1000; oym = oy*1000;
    if show_void
        obj_color = [1.0 0.85 0.0]; obj_edge = [0.8 0.6 0.0];
        ozt = oz_top*1000; ozb = oz_bot*1000;
        % 3D void box — visible through transparent ground
        patch([-oxm oxm oxm -oxm], [-oym -oym oym oym], [ozt ozt ozt ozt], obj_color, 'FaceAlpha', 0.8, 'EdgeColor', obj_edge, 'LineWidth', 1.5);
        patch([-oxm oxm oxm -oxm], [-oym -oym -oym -oym], [ozt ozt ozb ozb], obj_color*0.85, 'FaceAlpha', 0.7, 'EdgeColor', obj_edge, 'LineWidth', 1.2);
        patch([oxm oxm oxm oxm], [-oym oym oym -oym], [ozt ozt ozb ozb], obj_color*0.9, 'FaceAlpha', 0.7, 'EdgeColor', obj_edge, 'LineWidth', 1.2);
        patch([-oxm -oxm -oxm -oxm], [-oym oym oym -oym], [ozt ozt ozb ozb], obj_color*0.85, 'FaceAlpha', 0.7, 'EdgeColor', obj_edge, 'LineWidth', 1.2);
        patch([-oxm oxm oxm -oxm], [oym oym oym oym], [ozt ozt ozb ozb], obj_color*0.8, 'FaceAlpha', 0.7, 'EdgeColor', obj_edge, 'LineWidth', 1.2);
        patch([-oxm oxm oxm -oxm], [-oym -oym oym oym], [ozb ozb ozb ozb], obj_color*0.5, 'FaceAlpha', 0.6, 'EdgeColor', obj_edge, 'LineWidth', 1.2);
        text(0, 0, ozb-15, sprintf('Void (\\epsilon_r=1.0)'), 'FontSize', 9, 'FontWeight', 'bold', 'Color', obj_edge, 'HorizontalAlignment', 'center');
        % Dashed footprint on ground surface
        plot3([-oxm oxm oxm -oxm -oxm], [-oym -oym oym oym -oym], [1 1 1 1 1], '--', 'Color', [0.9 0.5 0], 'LineWidth', 2.5);
    else
        % Faint footprint reference
        plot3([-oxm oxm oxm -oxm -oxm], [-oym -oym oym oym -oym], [1 1 1 1 1], ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
        text(0, oym+50, 5, '(no void)', 'FontSize', 8, 'Color', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');
    end
    
    % Robot
    rv_mm = robot_verts * 1000;
    trisurf(triangulation(robot_faces, rv_mm), 'FaceColor', [0.7 0.7 0.75], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.25, 'FaceLighting', 'gouraud');
    
    % PCBs
    pcb_color = [0.1 0.6 0.1];
    pts1 = world_pos1(2:end,:)*1000;
    k1 = convhull(pts1(:,1), pts1(:,3));
    fill3(pts1(k1,1), ones(size(k1))*mean(pts1(:,2)), pts1(k1,3), pcb_color, 'FaceAlpha', 0.5, 'EdgeColor', pcb_color*0.7, 'LineWidth', 1.5);
    pts2 = world_pos2(2:end,:)*1000;
    k2 = convhull(pts2(:,1), pts2(:,3));
    fill3(pts2(k2,1), ones(size(k2))*mean(pts2(:,2)), pts2(k2,3), pcb_color, 'FaceAlpha', 0.5, 'EdgeColor', pcb_color*0.7, 'LineWidth', 1.5);
    
    % TX/RX markers
    scatter3(world_pos1(1,1)*1000, world_pos1(1,2)*1000, world_pos1(1,3)*1000, 100, 'r', '^', 'filled', 'MarkerEdgeColor', 'k');
    scatter3(world_pos2(1,1)*1000, world_pos2(1,2)*1000, world_pos2(1,3)*1000, 100, 'r', '^', 'filled', 'MarkerEdgeColor', 'k');
    scatter3(world_pos1(2:end,1)*1000, world_pos1(2:end,2)*1000, world_pos1(2:end,3)*1000, 15, 'b', 'filled');
    scatter3(world_pos2(2:end,1)*1000, world_pos2(2:end,2)*1000, world_pos2(2:end,3)*1000, 15, 'b', 'filled');
    text(world_pos1(1,1)*1000-30, world_pos1(1,2)*1000, world_pos1(1,3)*1000+25, 'TX1', 'FontSize', 8, 'FontWeight', 'bold', 'Color', 'r');
    text(world_pos2(1,1)*1000+10, world_pos2(1,2)*1000, world_pos2(1,3)*1000+25, 'TX2', 'FontSize', 8, 'FontWeight', 'bold', 'Color', 'r');
end

function draw_rays_power(paths, power_dB, p_min, p_max)
    % Color-code rays by power using narrowed range
    cmap = jet(256);
    for ri = 1:numel(paths)
        pts = paths{ri};
        % Normalize power to colormap index
        p_norm = (power_dB(ri) - p_min) / (p_max - p_min);
        p_norm = max(0, min(1, p_norm));
        ci = max(1, round(p_norm * 255) + 1);
        c = cmap(ci, :);
        lw = 0.8 + 3.0 * p_norm;  % thicker = more power
        
        plot3(pts(:,1), pts(:,2), pts(:,3), '-', ...
            'Color', [c 0.7], 'LineWidth', lw);
    end
end

function set_view(ax)
    axes(ax);
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    grid on;
    set(ax, 'Projection', 'perspective');
    view([215, 30]);  % +Y faces viewer (antenna in front, robot behind)
    daspect([1 1 1]);
    xlim([-500 500]);
    ylim([-400 400]);
    zlim([-200 250]);
    light('Position', [500 500 500]);
end

function set_top_view(ax)
    axes(ax);
    xlabel('X (mm)'); ylabel('Y (mm)');
    grid on;
    set(ax, 'Projection', 'orthographic');
    view([0, 90]);  % straight down
    daspect([1 1 1]);
    xlim([-500 500]);
    ylim([-400 400]);
end

function G = fresnel_coeff(theta_i, er)
    % TE Fresnel reflection coefficient (perpendicular polarization)
    cos_i = cos(theta_i);
    cos_t = sqrt(1 - (sin(theta_i)^2) / er);
    G = (cos_i - sqrt(er) * cos_t) / (cos_i + sqrt(er) * cos_t);
end

function n = count_rays(ray_cell)
    n = 0;
    for ri = 1:numel(ray_cell)
        n = n + numel(ray_cell{ri});
    end
end
