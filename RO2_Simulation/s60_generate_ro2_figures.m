%% 60_generate_ro2_figures.m - Generate experiment setup and publication figures
% Creates the main setup diagram showing antenna, terrain block, layers, and voids.

fprintf('=== RO2 Figure Generation ===\n');

% Setup
if ~exist('ro2_root','var'), ro2_root=pwd; addpath('config'); end
ro2_config;

%% Load geometry for void visualization
geom_file = fullfile(ro2_root, cfg.path_data_raw, 'ro2_geometry.mat');
if exist(geom_file, 'file')
    load(geom_file, 'all_geometry', 'bulk_nx', 'bulk_ny', 'bulk_nz');
    has_geometry = true;
else
    has_geometry = false;
end

fig_dir = fullfile(ro2_root, cfg.path_figures_setup);

%% === Figure dimensions (for visualization) ===
% Material block: 120x120x120mm
fig_block = 120;  % mm
fig_x_range = [-fig_block/2, fig_block/2];  % [-60, 60]
fig_y_range = [-fig_block/2, fig_block/2];
fig_cover_thickness = 10;   % mm
fig_cover_z_top = -10;
fig_cover_z_bot = -20;
fig_bulk_z_bot = fig_cover_z_bot - (fig_block - fig_cover_thickness);  % -130
fig_bulk_thickness = fig_block - fig_cover_thickness;  % 110mm

% Antenna: 8x4 = 32 RX + 1 TX center on 100x100mm FR4 PCB
fig_ant_z = 30;         % height above ground
fig_pcb_w = 100;        % mm (matches AntennaArrayS11.m)
fig_pcb_h = 100;        % mm
fig_ant_cols = 8;
fig_ant_rows = 4;

%% === Generate 3 Setup Figures: Low / Medium / High Density ===
% Sample indices: 200 per class, class order from config
%   Class 7 = Soil 700 (lowest density, void_frac=0.583)
%   Class 3 = Cement 1000 (medium density, void_frac=0.230)
%   Class 5 = Cement 1200 (high density, void_frac=0.078)
density_cases = struct();
density_cases(1).label = 'Low Density (Soil 700)';
density_cases(1).sample_idx = (7-1)*200 + 1;
density_cases(1).filename = 'ro2_setup_low_density';
density_cases(1).n_show = 1500;  % many voids visible

density_cases(2).label = 'Medium Density (Cement 1000)';
density_cases(2).sample_idx = (3-1)*200 + 1;
density_cases(2).filename = 'ro2_setup_medium_density';
density_cases(2).n_show = 500;   % moderate voids

density_cases(3).label = 'High Density (Cement 1200)';
density_cases(3).sample_idx = (5-1)*200 + 1;
density_cases(3).filename = 'ro2_setup_high_density';
density_cases(3).n_show = 120;   % sparse voids

for di = 1:3
    figure('Name', density_cases(di).label, 'Position', [50 50 1000 800], 'Visible', 'off');
    hold on;

    % --- Terrain block ---
    cover_color = [0.7 0.7 0.75];
    bulk_color = [0.55 0.35 0.17];

    % Cover layer - top face
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(1) fig_y_range(2) fig_y_range(2)], ...
          [fig_cover_z_top fig_cover_z_top fig_cover_z_top fig_cover_z_top], ...
          cover_color, 'FaceAlpha', 0.6, 'EdgeColor', cover_color*0.6, 'LineWidth', 1);
    % Cover - front face
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(1) fig_y_range(1) fig_y_range(1)], ...
          [fig_cover_z_top fig_cover_z_top fig_cover_z_bot fig_cover_z_bot], ...
          cover_color*0.85, 'FaceAlpha', 0.6, 'EdgeColor', cover_color*0.5, 'LineWidth', 1);
    % Cover - right face
    patch([fig_x_range(2) fig_x_range(2) fig_x_range(2) fig_x_range(2)], ...
          [fig_y_range(1) fig_y_range(2) fig_y_range(2) fig_y_range(1)], ...
          [fig_cover_z_top fig_cover_z_top fig_cover_z_bot fig_cover_z_bot], ...
          cover_color*0.9, 'FaceAlpha', 0.6, 'EdgeColor', cover_color*0.5, 'LineWidth', 1);

    % Bulk - front face
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(1) fig_y_range(1) fig_y_range(1)], ...
          [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color, 'FaceAlpha', 0.5, 'EdgeColor', bulk_color*0.5, 'LineWidth', 1);
    % Bulk - right face
    patch([fig_x_range(2) fig_x_range(2) fig_x_range(2) fig_x_range(2)], ...
          [fig_y_range(1) fig_y_range(2) fig_y_range(2) fig_y_range(1)], ...
          [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color*0.85, 'FaceAlpha', 0.5, 'EdgeColor', bulk_color*0.5, 'LineWidth', 1);
    % Bulk - bottom face
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(1) fig_y_range(2) fig_y_range(2)], ...
          [fig_bulk_z_bot fig_bulk_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color*0.6, 'FaceAlpha', 0.5, 'EdgeColor', bulk_color*0.4, 'LineWidth', 1);
    % Bulk - left face
    patch([fig_x_range(1) fig_x_range(1) fig_x_range(1) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(2) fig_y_range(2) fig_y_range(1)], ...
          [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color*0.75, 'FaceAlpha', 0.3, 'EdgeColor', bulk_color*0.4, 'LineWidth', 1);
    % Bulk - back face
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(2) fig_y_range(2) fig_y_range(2) fig_y_range(2)], ...
          [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color*0.7, 'FaceAlpha', 0.3, 'EdgeColor', bulk_color*0.4, 'LineWidth', 1);

    % --- Voids for this density level ---
    if has_geometry
        sample_for_voids = all_geometry(density_cases(di).sample_idx);
        void_idx = sample_for_voids.void_indices;
        
        if ~isempty(void_idx)
            scale_x = fig_block / (bulk_nx * cfg.void_size);
            scale_y = fig_block / (bulk_ny * cfg.void_size);
            scale_z = fig_bulk_thickness / (bulk_nz * cfg.void_size);
            
            n_show = min(density_cases(di).n_show, length(void_idx));
            show_idx = void_idx(randperm(length(void_idx), n_show));
            
            [vxi, vyi, vzi] = ind2sub([bulk_nx, bulk_ny, bulk_nz], show_idx);
            void_x = fig_x_range(1) + (vxi-1) * cfg.void_size * scale_x;
            void_y = fig_y_range(1) + (vyi-1) * cfg.void_size * scale_y;
            void_z = fig_cover_z_bot - (vzi-1) * cfg.void_size * scale_z;
            
            void_color = [1.0 1.0 0.85];
            vs_x = cfg.void_size * scale_x * 0.9;
            vs_y = cfg.void_size * scale_y * 0.9;
            vs_z = cfg.void_size * scale_z * 0.9;
            
            for vi = 1:n_show
                vx0 = void_x(vi); vy0 = void_y(vi); vz0 = void_z(vi);
                patch([vx0 vx0+vs_x vx0+vs_x vx0], ...
                      [vy0 vy0 vy0 vy0], ...
                      [vz0 vz0 vz0-vs_z vz0-vs_z], ...
                      void_color, 'FaceAlpha', 0.7, 'EdgeColor', [0.4 0.4 0.3], 'LineWidth', 0.3);
                patch([vx0 vx0+vs_x vx0+vs_x vx0], ...
                      [vy0 vy0 vy0+vs_y vy0+vs_y], ...
                      [vz0 vz0 vz0 vz0], ...
                      void_color*0.95, 'FaceAlpha', 0.7, 'EdgeColor', [0.4 0.4 0.3], 'LineWidth', 0.3);
            end
        end
    end

    % --- Antenna (8x4 = 32 RX + 1 TX at center) ---
    scatter3(0, 0, fig_ant_z, 80, 'r', '^', 'filled');
    text(4, 0, fig_ant_z + 5, 'TX', 'FontSize', 9, 'FontWeight', 'bold', 'Color', 'r');

    dx_ant = fig_pcb_w / (fig_ant_cols - 1);
    dy_ant = fig_pcb_h / (fig_ant_rows - 1);
    for row = 1:fig_ant_rows
        for col = 1:fig_ant_cols
            rx_x = -fig_pcb_w/2 + (col-1)*dx_ant;
            rx_y = -fig_pcb_h/2 + (row-1)*dy_ant;
            scatter3(rx_x, rx_y, fig_ant_z, 12, 'b', 'filled');
        end
    end

    pcb_margin = 3;
    pcb_x = [-fig_pcb_w/2-pcb_margin, fig_pcb_w/2+pcb_margin, ...
              fig_pcb_w/2+pcb_margin, -fig_pcb_w/2-pcb_margin];
    pcb_y = [-fig_pcb_h/2-pcb_margin, -fig_pcb_h/2-pcb_margin, ...
              fig_pcb_h/2+pcb_margin, fig_pcb_h/2+pcb_margin];
    pcb_z = [fig_ant_z fig_ant_z fig_ant_z fig_ant_z];
    fill3(pcb_x, pcb_y, pcb_z, [0.1 0.6 0.1], 'FaceAlpha', 0.3, 'EdgeColor', [0 0.4 0], 'LineWidth', 1.5);

    % --- Radiation pattern ---
    n_pat = 3.5;
    pat_scale = 50;
    n_pts = 30;
    theta_pat = linspace(0, pi/2, n_pts);
    phi_pat = linspace(0, 2*pi, n_pts);
    [THETA, PHI] = meshgrid(theta_pat, phi_pat);
    G_norm = max(cos(THETA), 0).^n_pat;
    R_pat = pat_scale * G_norm;
    X_pat = R_pat .* sin(THETA) .* cos(PHI);
    Y_pat = R_pat .* sin(THETA) .* sin(PHI);
    Z_pat = -R_pat .* cos(THETA);
    surf(X_pat, Y_pat, Z_pat + fig_ant_z, G_norm, ...
        'FaceAlpha', 0.35, 'EdgeColor', 'none', 'FaceColor', [1 0.3 0.1]);

    % --- Labels ---
    text(fig_x_range(2)+3, fig_y_range(1), (fig_cover_z_top+fig_cover_z_bot)/2, ...
        'Cover', 'FontSize', 8, 'Color', [0.3 0.3 0.4]);
    text(fig_x_range(2)+3, fig_y_range(1), (fig_cover_z_bot+fig_bulk_z_bot)/2, ...
        'Bulk', 'FontSize', 8, 'Color', bulk_color*0.7);

    % --- View ---
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    title(sprintf('RO2 Setup - %s', density_cases(di).label));
    grid on;
    view([-35, 25]);
    daspect([1 1 1]);
    xlim([fig_x_range(1)-15 fig_x_range(2)+20]);
    ylim([fig_y_range(1)-15 fig_y_range(2)+20]);
    zlim([fig_bulk_z_bot-5 fig_ant_z+20]);
    light('Position', [80 -80 150]);
    hold off;

    set(gcf, 'Visible', 'on');
    savefig(gcf, fullfile(fig_dir, [density_cases(di).filename '.fig']));
    exportgraphics(gcf, fullfile(fig_dir, [density_cases(di).filename '.png']), 'Resolution', 200);
    close(gcf);
    fprintf('  Saved: %s\n', density_cases(di).filename);
end

%% === Figure 2: Cross-section diagram (2D) ===
figure('Name', 'RO2 Cross-Section', 'Position', [50 50 900 600], 'Visible', 'off');
hold on;

% Air block (touching the cover, from cover top to antenna height + margin)
air_top = fig_ant_z + 10;
rectangle('Position', [fig_x_range(1), fig_cover_z_top, fig_block, air_top - fig_cover_z_top], ...
    'FaceColor', [0.93 0.96 1.0], 'EdgeColor', 'k', 'LineWidth', 0.8);
text(fig_x_range(1)+5, air_top - 8, 'Air', 'FontSize', 9, 'Color', [0.3 0.4 0.6]);

% Cover layer (directly below air)
rectangle('Position', [fig_x_range(1), fig_cover_z_bot, fig_block, fig_cover_thickness], ...
    'FaceColor', cover_color, 'EdgeColor', 'k', 'LineWidth', 0.8);
text(0, (fig_cover_z_top+fig_cover_z_bot)/2, 'Cover (Tile/Slab)', ...
    'HorizontalAlignment', 'center', 'FontSize', 9);

% Bulk layer
rectangle('Position', [fig_x_range(1), fig_bulk_z_bot, fig_block, fig_bulk_thickness], ...
    'FaceColor', [0.75 0.55 0.35], 'EdgeColor', 'k', 'LineWidth', 0.8);
text(0, (fig_cover_z_bot+fig_bulk_z_bot)/2, 'Bulk Material + Voids', ...
    'HorizontalAlignment', 'center', 'FontSize', 9);

% --- Antenna array (8x4 visible elements) ---
ant_pcb_w = 50;  % visual width in cross-section
ant_pcb_h = 3;   % visual thickness
% PCB rectangle
rectangle('Position', [-ant_pcb_w/2, fig_ant_z - ant_pcb_h/2, ant_pcb_w, ant_pcb_h], ...
    'FaceColor', [0.15 0.6 0.15], 'EdgeColor', [0 0.4 0], 'LineWidth', 1, ...
    'Curvature', 0.1);
% 8 element positions across the PCB width (cross-section slice)
n_vis_elements = 8;
el_spacing = ant_pcb_w / (n_vis_elements + 1);
for ei = 1:n_vis_elements
    ex = -ant_pcb_w/2 + ei * el_spacing;
    plot(ex, fig_ant_z, 'bs', 'MarkerSize', 4, 'MarkerFaceColor', [0.2 0.4 0.9]);
end
% TX at center
plot(0, fig_ant_z, 'r^', 'MarkerSize', 7, 'MarkerFaceColor', 'r');
% Label (offset to avoid overlap)
text(ant_pcb_w/2 + 4, fig_ant_z, '8\times4 Array', 'FontSize', 9, ...
    'VerticalAlignment', 'middle');

% --- Radiation pattern (larger transparent lobe) ---
n_ang = 80;
theta_lobe = linspace(-pi/2.5, pi/2.5, n_ang);  % wider beamwidth visual
n_pat_exp = 3.5;
lobe_scale = 80;  % mm - large, extends past cover into bulk

G_lobe = max(cos(theta_lobe), 0).^n_pat_exp;
lobe_x = lobe_scale * G_lobe .* sin(theta_lobe);
lobe_z = fig_ant_z - lobe_scale * G_lobe .* cos(theta_lobe);

lobe_x = [0, lobe_x, 0];
lobe_z = [fig_ant_z, lobe_z, fig_ant_z];

fill(lobe_x, lobe_z, [1 0.3 0.1], 'FaceAlpha', 0.15, 'EdgeColor', [0.8 0.2 0], 'LineWidth', 1.2);

% Void representation (more visible)
rng(99);
for vi = 1:30
    vx = fig_x_range(1) + 5 + rand()*(fig_block-15);
    vz = fig_cover_z_bot - 5 - rand()*(fig_bulk_thickness-10);
    rectangle('Position', [vx, vz, 4, 4], ...
        'FaceColor', [1 1 0.85], 'EdgeColor', [0.4 0.4 0.3], 'LineWidth', 0.5);
end

xlabel('X (mm)'); ylabel('Z (mm)');
title('RO2 Cross-Section: Antenna \rightarrow Cover \rightarrow Bulk + Voids');
axis equal;
xlim([fig_x_range(1)-15 fig_x_range(2)+15]);
ylim([fig_bulk_z_bot-5 air_top+5]);
grid on;
hold off;

set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(fig_dir, 'ro2_cross_section.fig'));
exportgraphics(gcf, fullfile(fig_dir, 'ro2_cross_section.png'), 'Resolution', 150);
close(gcf);
fprintf('Cross-section figure saved.\n');

%% === SBR Ray Trace Figures ===
fprintf('\n=== SBR Ray Trace Figures ===\n');

% Antenna positions (meters for SBR)
ant_z_m = cfg.antenna_z / 1000;  % 0.030 m
aw = cfg.array_width / 1000;     % 0.160 m
ah = cfg.array_height / 1000;    % 0.160 m
dx_rx = aw / (cfg.nCols - 1);
dy_rx = ah / (cfg.nRows - 1);

tx_pos = [cfg.antenna_x/1000, cfg.antenna_y/1000, ant_z_m];
rx_pos = zeros(cfg.nRX, 3);
idx = 1;
for row = 1:cfg.nRows
    for col = 1:cfg.nCols
        rx_pos(idx,:) = [-aw/2 + (col-1)*dx_rx, -ah/2 + (row-1)*dy_rx, ant_z_m];
        idx = idx + 1;
    end
end

% Build STL scene: material block as ground slab
block_x = 0.100;  % half-size in m (200mm / 2)
block_y = 0.100;
block_z_top = cfg.terrain_z_top / 1000;     % -0.010 m
block_z_bot = cfg.terrain_z_bottom / 1000;  % -0.210 m

V_block = [-block_x, -block_y, block_z_top;
            block_x, -block_y, block_z_top;
            block_x,  block_y, block_z_top;
           -block_x,  block_y, block_z_top;
           -block_x, -block_y, block_z_bot;
            block_x, -block_y, block_z_bot;
            block_x,  block_y, block_z_bot;
           -block_x,  block_y, block_z_bot];
F_block = [1 2 3;1 3 4;5 7 6;5 8 7;1 5 6;1 6 2;4 3 7;4 7 8;1 4 8;1 8 5;2 6 7;2 7 3];

stl_rt = fullfile(fig_dir, 'ro2_raytrace_scene.stl');
stlwrite(triangulation(F_block, V_block), stl_rt);

% Ray trace
fprintf('  Tracing rays (SBR)...\n');
viewer_rt = siteviewer("SceneModel", stl_rt, "ShowOrigin", false);
pm_rt = propagationModel("raytracing", "CoordinateSystem","cartesian", ...
    "Method","sbr", "SurfaceMaterial","custom", ...
    "SurfaceMaterialPermittivity", cfg.cover_materials.tile.er, ...
    "SurfaceMaterialConductivity", cfg.cover_materials.tile.sigma);
pm_rt.MaxNumReflections = 3;

tx_site = txsite("cartesian","AntennaPosition", tx_pos', "TransmitterFrequency", cfg.freq);
rx_sites = rxsite.empty;
for ri = 1:cfg.nRX
    rx_sites(ri) = rxsite("cartesian","AntennaPosition", rx_pos(ri,:)');
end

rays_rt = raytrace(tx_site, rx_sites, pm_rt);
close(viewer_rt);

% Count rays and extract paths (in mm)
n_rays_total = 0;
all_paths = {};
for ri = 1:numel(rays_rt)
    ray_set = rays_rt{ri};
    for rj = 1:numel(ray_set)
        ray = ray_set(rj);
        n_rays_total = n_rays_total + 1;
        tx_loc = ray.TransmitterLocation(:)' * 1000;
        rx_loc = ray.ReceiverLocation(:)' * 1000;
        if ray.NumInteractions == 0
            all_paths{end+1} = [tx_loc; rx_loc];
        else
            int_pts = zeros(ray.NumInteractions, 3);
            for ki = 1:ray.NumInteractions
                int_pts(ki,:) = ray.Interactions(ki).Location(:)' * 1000;
            end
            all_paths{end+1} = [tx_loc; int_pts; rx_loc];
        end
    end
end
fprintf('  %d rays traced\n', n_rays_total);

%% --- SBR 3D View ---
fig_rt3d = figure('Position', [50 50 1100 800], 'Color', 'w', 'Visible', 'off');
ax_rt3d = axes(fig_rt3d); hold on;

% Material block (same style as density figures)
% Cover layer
patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
      [fig_y_range(1) fig_y_range(1) fig_y_range(2) fig_y_range(2)], ...
      [fig_cover_z_top fig_cover_z_top fig_cover_z_top fig_cover_z_top], ...
      cover_color, 'FaceAlpha', 0.5, 'EdgeColor', cover_color*0.6, 'LineWidth', 1);
patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
      [fig_y_range(1) fig_y_range(1) fig_y_range(1) fig_y_range(1)], ...
      [fig_cover_z_top fig_cover_z_top fig_cover_z_bot fig_cover_z_bot], ...
      cover_color*0.85, 'FaceAlpha', 0.5, 'EdgeColor', cover_color*0.5, 'LineWidth', 1);
patch([fig_x_range(2) fig_x_range(2) fig_x_range(2) fig_x_range(2)], ...
      [fig_y_range(1) fig_y_range(2) fig_y_range(2) fig_y_range(1)], ...
      [fig_cover_z_top fig_cover_z_top fig_cover_z_bot fig_cover_z_bot], ...
      cover_color*0.9, 'FaceAlpha', 0.5, 'EdgeColor', cover_color*0.5, 'LineWidth', 1);
% Bulk layer
patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
      [fig_y_range(1) fig_y_range(1) fig_y_range(1) fig_y_range(1)], ...
      [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
      bulk_color, 'FaceAlpha', 0.4, 'EdgeColor', bulk_color*0.5, 'LineWidth', 1);
patch([fig_x_range(2) fig_x_range(2) fig_x_range(2) fig_x_range(2)], ...
      [fig_y_range(1) fig_y_range(2) fig_y_range(2) fig_y_range(1)], ...
      [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
      bulk_color*0.85, 'FaceAlpha', 0.4, 'EdgeColor', bulk_color*0.5, 'LineWidth', 1);
patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
      [fig_y_range(1) fig_y_range(1) fig_y_range(2) fig_y_range(2)], ...
      [fig_bulk_z_bot fig_bulk_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
      bulk_color*0.6, 'FaceAlpha', 0.4, 'EdgeColor', bulk_color*0.4, 'LineWidth', 1);
patch([fig_x_range(1) fig_x_range(1) fig_x_range(1) fig_x_range(1)], ...
      [fig_y_range(1) fig_y_range(2) fig_y_range(2) fig_y_range(1)], ...
      [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
      bulk_color*0.75, 'FaceAlpha', 0.3, 'EdgeColor', bulk_color*0.4, 'LineWidth', 1);
patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
      [fig_y_range(2) fig_y_range(2) fig_y_range(2) fig_y_range(2)], ...
      [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
      bulk_color*0.7, 'FaceAlpha', 0.3, 'EdgeColor', bulk_color*0.4, 'LineWidth', 1);
% Interior fill slices
n_slices = 6;
z_slices = linspace(fig_cover_z_bot-5, fig_bulk_z_bot+5, n_slices);
for si = 1:n_slices
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(1) fig_y_range(2) fig_y_range(2)], ...
          [z_slices(si) z_slices(si) z_slices(si) z_slices(si)], ...
          bulk_color*0.7, 'FaceAlpha', 0.08, 'EdgeColor', 'none');
end

% Antenna (PCB + markers)
fill3(pcb_x, pcb_y, pcb_z, [0.1 0.6 0.1], 'FaceAlpha', 0.4, 'EdgeColor', [0 0.4 0], 'LineWidth', 1.5);
scatter3(tx_pos(1)*1000, tx_pos(2)*1000, tx_pos(3)*1000, 100, 'r', '^', 'filled', 'MarkerEdgeColor', 'k');
text(tx_pos(1)*1000+5, tx_pos(2)*1000, tx_pos(3)*1000+5, 'TX', 'FontSize', 9, 'FontWeight', 'bold', 'Color', 'r');
scatter3(rx_pos(:,1)*1000, rx_pos(:,2)*1000, rx_pos(:,3)*1000, 20, 'b', 'filled');

% Draw SBR rays
ray_color = [1.0 0.4 0.1];
for ri = 1:numel(all_paths)
    pts = all_paths{ri};
    plot3(pts(:,1), pts(:,2), pts(:,3), '-', 'Color', [ray_color 0.5], 'LineWidth', 1.2);
end

% Labels
text(fig_x_range(2)+3, fig_y_range(1), (fig_cover_z_top+fig_cover_z_bot)/2, ...
    'Cover', 'FontSize', 8, 'Color', [0.3 0.3 0.4]);
text(fig_x_range(2)+3, fig_y_range(1), (fig_cover_z_bot+fig_bulk_z_bot)/2, ...
    'Bulk', 'FontSize', 8, 'Color', bulk_color*0.7);

xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title(sprintf('RO2 SBR Ray Tracing — 3D View\n%d rays, max 3 reflections', n_rays_total), ...
    'FontSize', 12, 'FontWeight', 'bold');
grid on; view([-35, 25]); daspect([1 1 1]);
xlim([fig_x_range(1)-15 fig_x_range(2)+20]);
ylim([fig_y_range(1)-15 fig_y_range(2)+20]);
zlim([fig_bulk_z_bot-5 fig_ant_z+20]);
light('Position', [80 -80 150]);
hold off;

savefig(fig_rt3d, fullfile(fig_dir, 'ro2_raytrace_3d.fig'));
exportgraphics(fig_rt3d, fullfile(fig_dir, 'ro2_raytrace_3d.png'), 'Resolution', 200);
close(fig_rt3d);
fprintf('  Saved: ro2_raytrace_3d.fig + .png\n');

%% --- SBR Cross-Section View ---
fig_rtcs = figure('Position', [50 50 1000 700], 'Color', 'w', 'Visible', 'off');
ax_rtcs = axes(fig_rtcs); hold on;

% Air
air_top = fig_ant_z + 10;
rectangle('Position', [fig_x_range(1), fig_cover_z_top, fig_block, air_top - fig_cover_z_top], ...
    'FaceColor', [0.93 0.96 1.0], 'EdgeColor', 'k', 'LineWidth', 0.8);
text(fig_x_range(1)+5, air_top - 8, 'Air', 'FontSize', 9, 'Color', [0.3 0.4 0.6]);

% Cover
rectangle('Position', [fig_x_range(1), fig_cover_z_bot, fig_block, fig_cover_thickness], ...
    'FaceColor', cover_color, 'EdgeColor', 'k', 'LineWidth', 0.8);
text(0, (fig_cover_z_top+fig_cover_z_bot)/2, 'Cover (Tile/Slab)', ...
    'HorizontalAlignment', 'center', 'FontSize', 9);

% Bulk
rectangle('Position', [fig_x_range(1), fig_bulk_z_bot, fig_block, fig_bulk_thickness], ...
    'FaceColor', [0.75 0.55 0.35], 'EdgeColor', 'k', 'LineWidth', 0.8);
text(0, (fig_cover_z_bot+fig_bulk_z_bot)/2, 'Bulk Material + Voids', ...
    'HorizontalAlignment', 'center', 'FontSize', 9);

% Antenna PCB + elements
ant_pcb_w = 50; ant_pcb_h = 3;
rectangle('Position', [-ant_pcb_w/2, fig_ant_z - ant_pcb_h/2, ant_pcb_w, ant_pcb_h], ...
    'FaceColor', [0.15 0.6 0.15], 'EdgeColor', [0 0.4 0], 'LineWidth', 1, 'Curvature', 0.1);
n_vis_elements = 8;
el_spacing = ant_pcb_w / (n_vis_elements + 1);
for ei = 1:n_vis_elements
    ex = -ant_pcb_w/2 + ei * el_spacing;
    plot(ex, fig_ant_z, 'bs', 'MarkerSize', 4, 'MarkerFaceColor', [0.2 0.4 0.9]);
end
plot(0, fig_ant_z, 'r^', 'MarkerSize', 7, 'MarkerFaceColor', 'r');
text(ant_pcb_w/2 + 4, fig_ant_z, '4\times4 Array', 'FontSize', 9, 'VerticalAlignment', 'middle');

% Draw rays projected onto XZ plane (cross-section slice at Y≈0)
y_slice_tol = 30;  % mm — include rays within ±30mm of Y=0
for ri = 1:numel(all_paths)
    pts = all_paths{ri};
    % Check if any point is near Y=0
    if any(abs(pts(:,2)) < y_slice_tol)
        plot(pts(:,1), pts(:,3), '-', 'Color', [ray_color 0.6], 'LineWidth', 1.5);
    end
end

% Voids (decorative)
rng(99);
for vi = 1:30
    vx = fig_x_range(1) + 5 + rand()*(fig_block-15);
    vz = fig_cover_z_bot - 5 - rand()*(fig_bulk_thickness-10);
    rectangle('Position', [vx, vz, 4, 4], ...
        'FaceColor', [1 1 0.85], 'EdgeColor', [0.4 0.4 0.3], 'LineWidth', 0.5);
end

xlabel('X (mm)'); ylabel('Z (mm)');
title(sprintf('RO2 SBR Ray Tracing — Cross-Section\n%d rays (showing Y \\approx 0 slice)', n_rays_total), ...
    'FontSize', 12, 'FontWeight', 'bold');
axis equal;
xlim([fig_x_range(1)-15 fig_x_range(2)+15]);
ylim([fig_bulk_z_bot-5 air_top+5]);
grid on; hold off;

savefig(fig_rtcs, fullfile(fig_dir, 'ro2_raytrace_cross_section.fig'));
exportgraphics(fig_rtcs, fullfile(fig_dir, 'ro2_raytrace_cross_section.png'), 'Resolution', 200);
close(fig_rtcs);
fprintf('  Saved: ro2_raytrace_cross_section.fig + .png\n');

%% === Fresnel Power-Coded Ray Figures (6 densities: 3 Soil + 3 Cement) ===
% Same ray paths, different power based on effective εr from void fraction.
% More voids → lower effective εr → different Fresnel reflection coeff → different power.
fprintf('\n=== Fresnel Power Ray Trace (6 densities) ===\n');

lambda_m = cfg.lambda;  % wavelength in m

% Void fraction formula: void_frac = 1 - density / max_density_in_class
% Soil max density: 0.84 g/cm³ (Soil 1700)
% Cement max density: 2.17 g/cm³ (Cement 1300)

pwr_cases = struct();

% --- 3 Soil cases (ConcreteSlab cover, εr=4.5) ---
pwr_cases(1).label = 'Soil 700 (Low Density)';
pwr_cases(1).filename = 'ro2_power_soil_700';
pwr_cases(1).void_frac = 1 - 0.35/0.84;  % 0.583
pwr_cases(1).er_solid = cfg.bulk_materials.soil.er;              % 12.0
pwr_cases(1).er_cover = cfg.cover_materials.concrete_slab.er;   % 4.5
pwr_cases(1).density = 0.35;
pwr_cases(1).mass = 700;
pwr_cases(1).material = 'Soil';

pwr_cases(2).label = 'Soil 1100 (Medium Density)';
pwr_cases(2).filename = 'ro2_power_soil_1100';
pwr_cases(2).void_frac = 1 - 0.55/0.84;  % 0.345
pwr_cases(2).er_solid = cfg.bulk_materials.soil.er;
pwr_cases(2).er_cover = cfg.cover_materials.concrete_slab.er;
pwr_cases(2).density = 0.55;
pwr_cases(2).mass = 1100;
pwr_cases(2).material = 'Soil';

pwr_cases(3).label = 'Soil 1700 (High Density)';
pwr_cases(3).filename = 'ro2_power_soil_1700';
pwr_cases(3).void_frac = 0.0;  % no voids
pwr_cases(3).er_solid = cfg.bulk_materials.soil.er;
pwr_cases(3).er_cover = cfg.cover_materials.concrete_slab.er;
pwr_cases(3).density = 0.84;
pwr_cases(3).mass = 1700;
pwr_cases(3).material = 'Soil';

% --- 3 Cement cases (Tile cover, εr=6.0) ---
pwr_cases(4).label = 'Cement 800 (Low Density)';
pwr_cases(4).filename = 'ro2_power_cement_800';
pwr_cases(4).void_frac = 1 - 1.33/2.17;  % 0.387
pwr_cases(4).er_solid = cfg.bulk_materials.cement.er;     % 4.0
pwr_cases(4).er_cover = cfg.cover_materials.tile.er;      % 6.0
pwr_cases(4).density = 1.33;
pwr_cases(4).mass = 800;
pwr_cases(4).material = 'Cement';

pwr_cases(5).label = 'Cement 1000 (Medium Density)';
pwr_cases(5).filename = 'ro2_power_cement_1000';
pwr_cases(5).void_frac = 1 - 1.67/2.17;  % 0.230
pwr_cases(5).er_solid = cfg.bulk_materials.cement.er;
pwr_cases(5).er_cover = cfg.cover_materials.tile.er;
pwr_cases(5).density = 1.67;
pwr_cases(5).mass = 1000;
pwr_cases(5).material = 'Cement';

pwr_cases(6).label = 'Cement 1300 (High Density)';
pwr_cases(6).filename = 'ro2_power_cement_1300';
pwr_cases(6).void_frac = 0.0;  % no voids
pwr_cases(6).er_solid = cfg.bulk_materials.cement.er;
pwr_cases(6).er_cover = cfg.cover_materials.tile.er;
pwr_cases(6).density = 2.17;
pwr_cases(6).mass = 1300;
pwr_cases(6).material = 'Cement';

% Compute power for each density case
for di = 1:6
    vf = pwr_cases(di).void_frac;
    er_bulk_eff = (1 - vf) * pwr_cases(di).er_solid + vf * cfg.void_er;
    % Overall effective εr: weighted by layer thickness
    cover_frac = cfg.cover_thickness / (cfg.cover_thickness + cfg.bulk_thickness);
    er_eff = cover_frac * pwr_cases(di).er_cover + (1 - cover_frac) * er_bulk_eff;
    pwr_cases(di).er_eff = er_eff;
    pwr_cases(di).er_bulk_eff = er_bulk_eff;
    
    % Compute per-ray power using Fresnel model
    power_dB = zeros(numel(all_paths), 1);
    for ri = 1:numel(all_paths)
        pts = all_paths{ri};
        total_dist = 0;
        for si = 1:size(pts,1)-1
            total_dist = total_dist + norm(pts(si+1,:) - pts(si,:));
        end
        fspl = 20*log10(4*pi*(total_dist/1000)/lambda_m);
        
        % Find bounce points near cover surface (z ≈ -10mm)
        gamma_dB = 0;
        for pi2 = 2:size(pts,1)-1
            if abs(pts(pi2,3) - fig_cover_z_top) < 15  % near cover surface
                if pi2 == 2
                    inc_vec = pts(pi2,:) - pts(1,:);
                else
                    inc_vec = pts(pi2,:) - pts(pi2-1,:);
                end
                theta_i = acos(abs(inc_vec(3)) / norm(inc_vec));
                cos_i = cos(theta_i);
                cos_t = sqrt(1 - (sin(theta_i)^2) / er_eff);
                G = (cos_i - sqrt(er_eff)*cos_t) / (cos_i + sqrt(er_eff)*cos_t);
                gamma_dB = gamma_dB + 20*log10(abs(G));
            end
        end
        power_dB(ri) = -fspl + gamma_dB;
    end
    pwr_cases(di).power = power_dB;
    fprintf('  %s: εr_eff=%.2f, void=%.1f%%, mean power=%.1f dB\n', ...
        pwr_cases(di).label, er_eff, vf*100, mean(power_dB));
end

% Compute colormap range across all 6 densities (narrowed)
all_pwr = vertcat(pwr_cases.power);
p_center = median(all_pwr);
p_range = max(3, (max(all_pwr) - min(all_pwr))/2 + 1);
p_min_clr = p_center - p_range;
p_max_clr = p_center + p_range;
fprintf('  Colormap range: [%.1f, %.1f] dB\n', p_min_clr, p_max_clr);

% Generate figures for each density
for di = 1:6
    power_dB = pwr_cases(di).power;
    cmap = jet(256);
    
    %% --- 3D Power View ---
    fig_p3d = figure('Position', [50 50 1100 800], 'Color', 'w', 'Visible', 'off');
    ax_p3d = axes(fig_p3d); hold on;
    
    % Material block (cover + bulk + fill)
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(1) fig_y_range(2) fig_y_range(2)], ...
          [fig_cover_z_top fig_cover_z_top fig_cover_z_top fig_cover_z_top], ...
          cover_color, 'FaceAlpha', 0.5, 'EdgeColor', cover_color*0.6, 'LineWidth', 1);
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(1) fig_y_range(1) fig_y_range(1)], ...
          [fig_cover_z_top fig_cover_z_top fig_cover_z_bot fig_cover_z_bot], ...
          cover_color*0.85, 'FaceAlpha', 0.5, 'EdgeColor', cover_color*0.5, 'LineWidth', 1);
    patch([fig_x_range(2) fig_x_range(2) fig_x_range(2) fig_x_range(2)], ...
          [fig_y_range(1) fig_y_range(2) fig_y_range(2) fig_y_range(1)], ...
          [fig_cover_z_top fig_cover_z_top fig_cover_z_bot fig_cover_z_bot], ...
          cover_color*0.9, 'FaceAlpha', 0.5, 'EdgeColor', cover_color*0.5, 'LineWidth', 1);
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(1) fig_y_range(1) fig_y_range(1)], ...
          [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color, 'FaceAlpha', 0.4, 'EdgeColor', bulk_color*0.5, 'LineWidth', 1);
    patch([fig_x_range(2) fig_x_range(2) fig_x_range(2) fig_x_range(2)], ...
          [fig_y_range(1) fig_y_range(2) fig_y_range(2) fig_y_range(1)], ...
          [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color*0.85, 'FaceAlpha', 0.4, 'EdgeColor', bulk_color*0.5, 'LineWidth', 1);
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(1) fig_y_range(2) fig_y_range(2)], ...
          [fig_bulk_z_bot fig_bulk_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color*0.6, 'FaceAlpha', 0.4, 'EdgeColor', bulk_color*0.4, 'LineWidth', 1);
    patch([fig_x_range(1) fig_x_range(1) fig_x_range(1) fig_x_range(1)], ...
          [fig_y_range(1) fig_y_range(2) fig_y_range(2) fig_y_range(1)], ...
          [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color*0.75, 'FaceAlpha', 0.3, 'EdgeColor', bulk_color*0.4, 'LineWidth', 1);
    patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
          [fig_y_range(2) fig_y_range(2) fig_y_range(2) fig_y_range(2)], ...
          [fig_cover_z_bot fig_cover_z_bot fig_bulk_z_bot fig_bulk_z_bot], ...
          bulk_color*0.7, 'FaceAlpha', 0.3, 'EdgeColor', bulk_color*0.4, 'LineWidth', 1);
    for si = 1:n_slices
        patch([fig_x_range(1) fig_x_range(2) fig_x_range(2) fig_x_range(1)], ...
              [fig_y_range(1) fig_y_range(1) fig_y_range(2) fig_y_range(2)], ...
              [z_slices(si) z_slices(si) z_slices(si) z_slices(si)], ...
              bulk_color*0.7, 'FaceAlpha', 0.08, 'EdgeColor', 'none');
    end
    
    % Antenna
    fill3(pcb_x, pcb_y, pcb_z, [0.1 0.6 0.1], 'FaceAlpha', 0.4, 'EdgeColor', [0 0.4 0], 'LineWidth', 1.5);
    scatter3(tx_pos(1)*1000, tx_pos(2)*1000, tx_pos(3)*1000, 100, 'r', '^', 'filled', 'MarkerEdgeColor', 'k');
    text(tx_pos(1)*1000+5, tx_pos(2)*1000, tx_pos(3)*1000+5, 'TX', 'FontSize', 9, 'FontWeight', 'bold', 'Color', 'r');
    scatter3(rx_pos(:,1)*1000, rx_pos(:,2)*1000, rx_pos(:,3)*1000, 20, 'b', 'filled');
    
    % Power-coded rays
    for ri = 1:numel(all_paths)
        pts = all_paths{ri};
        p_norm = (power_dB(ri) - p_min_clr) / (p_max_clr - p_min_clr);
        p_norm = max(0, min(1, p_norm));
        ci = max(1, round(p_norm * 255) + 1);
        c = cmap(ci,:);
        lw = 0.8 + 3.0 * p_norm;
        plot3(pts(:,1), pts(:,2), pts(:,3), '-', 'Color', [c 0.7], 'LineWidth', lw);
    end
    
    % Labels
    text(fig_x_range(2)+3, fig_y_range(1), (fig_cover_z_top+fig_cover_z_bot)/2, ...
        'Cover', 'FontSize', 8, 'Color', [0.3 0.3 0.4]);
    text(fig_x_range(2)+3, fig_y_range(1), (fig_cover_z_bot+fig_bulk_z_bot)/2, ...
        'Bulk', 'FontSize', 8, 'Color', bulk_color*0.7);
    
    % Power annotation
    text(fig_x_range(1)-12, fig_y_range(2)+15, fig_ant_z+15, ...
        sprintf('\\epsilon_{r,eff} = %.2f\nVoid: %.1f%%\nMean: %.1f dB', ...
        pwr_cases(di).er_eff, pwr_cases(di).void_frac*100, mean(power_dB)), ...
        'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', [1 1 1 0.8], 'EdgeColor', 'k');
    
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    title(sprintf('RO2 Ray Power — %s\n%d rays, \\epsilon_{r,eff} = %.2f', ...
        pwr_cases(di).label, n_rays_total, pwr_cases(di).er_eff), 'FontSize', 12, 'FontWeight', 'bold');
    grid on; view([-35, 25]); daspect([1 1 1]);
    colormap(ax_p3d, jet); caxis(ax_p3d, [p_min_clr p_max_clr]);
    xlim([fig_x_range(1)-15 fig_x_range(2)+20]);
    ylim([fig_y_range(1)-15 fig_y_range(2)+20]);
    zlim([fig_bulk_z_bot-5 fig_ant_z+20]);
    light('Position', [80 -80 150]);
    hold off;
    
    savefig(fig_p3d, fullfile(fig_dir, [pwr_cases(di).filename '_3d.fig']));
    exportgraphics(fig_p3d, fullfile(fig_dir, [pwr_cases(di).filename '_3d.png']), 'Resolution', 200);
    close(fig_p3d);
    fprintf('  Saved: %s_3d.fig + .png\n', pwr_cases(di).filename);
    
    %% --- Cross-Section Power View ---
    fig_pcs = figure('Position', [50 50 1000 700], 'Color', 'w', 'Visible', 'off');
    ax_pcs = axes(fig_pcs); hold on;
    
    % Air
    rectangle('Position', [fig_x_range(1), fig_cover_z_top, fig_block, air_top - fig_cover_z_top], ...
        'FaceColor', [0.93 0.96 1.0], 'EdgeColor', 'k', 'LineWidth', 0.8);
    text(fig_x_range(1)+5, air_top - 8, 'Air', 'FontSize', 9, 'Color', [0.3 0.4 0.6]);
    
    rectangle('Position', [fig_x_range(1), fig_cover_z_bot, fig_block, fig_cover_thickness], ...
        'FaceColor', cover_color, 'EdgeColor', 'k', 'LineWidth', 0.8);
    text(0, (fig_cover_z_top+fig_cover_z_bot)/2, 'Cover', ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
    
    rectangle('Position', [fig_x_range(1), fig_bulk_z_bot, fig_block, fig_bulk_thickness], ...
        'FaceColor', [0.75 0.55 0.35], 'EdgeColor', 'k', 'LineWidth', 0.8);
    text(0, (fig_cover_z_bot+fig_bulk_z_bot)/2, ...
        sprintf('Bulk (void %.0f%%)', pwr_cases(di).void_frac*100), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
    
    % Antenna
    rectangle('Position', [-ant_pcb_w/2, fig_ant_z - ant_pcb_h/2, ant_pcb_w, ant_pcb_h], ...
        'FaceColor', [0.15 0.6 0.15], 'EdgeColor', [0 0.4 0], 'LineWidth', 1, 'Curvature', 0.1);
    for ei = 1:n_vis_elements
        ex = -ant_pcb_w/2 + ei * el_spacing;
        plot(ex, fig_ant_z, 'bs', 'MarkerSize', 4, 'MarkerFaceColor', [0.2 0.4 0.9]);
    end
    plot(0, fig_ant_z, 'r^', 'MarkerSize', 7, 'MarkerFaceColor', 'r');
    
    % Power-coded rays (XZ projection, Y≈0 slice)
    for ri = 1:numel(all_paths)
        pts = all_paths{ri};
        if any(abs(pts(:,2)) < y_slice_tol)
            p_norm = (power_dB(ri) - p_min_clr) / (p_max_clr - p_min_clr);
            p_norm = max(0, min(1, p_norm));
            ci = max(1, round(p_norm * 255) + 1);
            c = cmap(ci,:);
            lw = 1.0 + 3.0 * p_norm;
            plot(pts(:,1), pts(:,3), '-', 'Color', [c 0.7], 'LineWidth', lw);
        end
    end
    
    % Power annotation
    text(fig_x_range(1)+3, air_top - 3, ...
        sprintf('\\epsilon_{r,eff} = %.2f | Mean: %.1f dB', pwr_cases(di).er_eff, mean(power_dB)), ...
        'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', [1 1 1 0.8], 'EdgeColor', 'k');
    
    xlabel('X (mm)'); ylabel('Z (mm)');
    title(sprintf('RO2 Ray Power Cross-Section — %s\n\\epsilon_{r,eff} = %.2f, void fraction = %.1f%%', ...
        pwr_cases(di).label, pwr_cases(di).er_eff, pwr_cases(di).void_frac*100), ...
        'FontSize', 12, 'FontWeight', 'bold');
    axis equal;
    xlim([fig_x_range(1)-15 fig_x_range(2)+15]);
    ylim([fig_bulk_z_bot-5 air_top+5]);
    grid on; hold off;
    
    savefig(fig_pcs, fullfile(fig_dir, [pwr_cases(di).filename '_cross_section.fig']));
    exportgraphics(fig_pcs, fullfile(fig_dir, [pwr_cases(di).filename '_cross_section.png']), 'Resolution', 200);
    close(fig_pcs);
    fprintf('  Saved: %s_cross_section.fig + .png\n', pwr_cases(di).filename);
end

% Print comparison summary
fprintf('\n=== Density Power Comparison ===\n');
fprintf('  %-30s  εr_eff   Void%%   Mean Power\n', 'Material & Density');
fprintf('  %-30s  ------   -----   ----------\n', '------------------');
for di = 1:6
    fprintf('  %-30s  %5.2f   %4.1f%%   %6.1f dB\n', ...
        pwr_cases(di).label, pwr_cases(di).er_eff, pwr_cases(di).void_frac*100, mean(pwr_cases(di).power));
end
fprintf('\n  Soil power range:   %.2f dB (700 vs 1700)\n', mean(pwr_cases(1).power) - mean(pwr_cases(3).power));
fprintf('  Cement power range: %.2f dB (800 vs 1300)\n', mean(pwr_cases(4).power) - mean(pwr_cases(6).power));

fprintf('=== Figure Generation Complete ===\n');
