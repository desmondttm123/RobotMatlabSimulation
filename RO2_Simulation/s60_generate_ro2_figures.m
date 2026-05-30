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

fprintf('=== Figure Generation Complete ===\n');
