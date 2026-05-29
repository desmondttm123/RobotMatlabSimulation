%% TrackSimulation_Bumpy.m - RF Simulation with Randomized Terrain
% Modified TrackSimulation that uses per-chunk terrain properties:
%   - 100mm x 100mm chunks with ±5% εr/σ variation
%   - Surface height offset 0-10mm per chunk (affects reflection geometry)
%   - 5 layers of 100mm each (top layer properties used for reflection)
%
% Output: RSSI CSVs + figures in Results/ folder

clear; close all; clc;

%% Add parent path for SimConfig
addpath('..');
SimConfig;

rng(123); % Same seed as terrain visualization for consistency

%% Terrain chunk generation
chunk_size = 100;           % mm
variation_pct = 5;          % ±5% property variation
surface_z_max = 10;         % mm (0 to 10mm surface height)

track_width = cfg.track_width;       % 1500 mm
track_y_start = cfg.track_y_start;   % 0 mm
track_y_end = cfg.track_y_end;       % 20000 mm

n_chunks_x = track_width / chunk_size;    % 15
n_chunks_y = (track_y_end - track_y_start) / chunk_size;  % 200
gs_x = track_width / 2;  % ±750mm

% Chunk edges and centers
x_edges = linspace(-gs_x, gs_x, n_chunks_x + 1);
y_edges = linspace(track_y_start, track_y_end, n_chunks_y + 1);
x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
y_centers = (y_edges(1:end-1) + y_edges(2:end)) / 2;

%% Generate per-chunk properties for each terrain type
% Each terrain gets its own randomized field
terrains = cfg.terrains;
nTerrains = length(terrains);

terrain_chunks = struct();
for ti = 1:nTerrains
    base_er = terrains(ti).er;
    base_sigma = terrains(ti).sigma;
    
    % εr variation: ±5% of base
    er_field = base_er + base_er * (variation_pct/100) * randn(n_chunks_y, n_chunks_x);
    er_field = max(er_field, base_er * (1 - variation_pct/100*2));
    er_field = min(er_field, base_er * (1 + variation_pct/100*2));
    
    % σ variation: ±5% of base
    sigma_field = base_sigma + base_sigma * (variation_pct/100) * randn(n_chunks_y, n_chunks_x);
    sigma_field = max(sigma_field, base_sigma * (1 - variation_pct/100*2));
    sigma_field = min(sigma_field, base_sigma * (1 + variation_pct/100*2));
    
    terrain_chunks(ti).er = er_field;
    terrain_chunks(ti).sigma = sigma_field;
end

% Surface heights (shared across all terrains - same physical terrain profile)
surface_heights = rand(n_chunks_y, n_chunks_x) * surface_z_max;

% Zero out chunks over objects (objects are flat voids)
for oi = 1:length(cfg.obj_y_centers)
    oc = cfg.obj_y_centers(oi);
    for iy = 1:n_chunks_y
        for ix = 1:n_chunks_x
            if abs(x_centers(ix)) <= cfg.obj_x_half && abs(y_centers(iy) - oc) <= cfg.obj_y_half
                surface_heights(iy, ix) = 0;
            end
        end
    end
end

fprintf('=== Bumpy Terrain RF Simulation ===\n');
fprintf('Chunks: %d x %d = %d (100mm x 100mm each)\n', n_chunks_x, n_chunks_y, n_chunks_x*n_chunks_y);
fprintf('Surface height: 0 to %.1f mm\n', surface_z_max);
fprintf('Property variation: ±%d%%\n', variation_pct);

%% Physical Constants
c = 299792458;
eps0 = 8.854187817e-12;

%% Unpack parameters from cfg
freq = cfg.freq;
lambda = c / freq;

sensor1_x = cfg.sensor1_x;
sensor2_x = cfg.sensor2_x;
sensor_z = cfg.sensor_z;

arrayWidth = cfg.arrayWidth;
arrayHeight = cfg.arrayHeight;
nCols = cfg.nCols;
nRows = cfg.nRows;
nRX = nCols * nRows;
tilt_angle = cfg.tilt_angle;

low_power_range = cfg.low_power_range;
high_power_range = cfg.high_power_range;

y_start = cfg.track_y_start;
y_end = cfg.track_y_end;
y_step = cfg.track_y_step;
y_positions = y_start:y_step:y_end;
nPositions = length(y_positions);

% Objects
nObjects = length(cfg.obj_y_centers);
objects = struct();
for oi = 1:nObjects
    objects(oi).y_center = cfg.obj_y_centers(oi);
    objects(oi).name = cfg.obj_names{oi};
end
obj_x_half = cfg.obj_x_half;
obj_y_half = cfg.obj_y_half;
obj_er = cfg.obj_er;
obj_sigma = cfg.obj_sigma;

G_tx = cfg.G_tx;
G_rx = cfg.G_rx;

fprintf('Frequency: %.2f GHz\n', freq/1e9);
fprintf('Track: %d to %d mm (%d positions)\n', y_start, y_end, nPositions);
fprintf('Terrains: %s, %s, %s\n', terrains(1).name, terrains(2).name, terrains(3).name);

%% Generate RX antenna positions
dx = arrayWidth / (nCols - 1);
dy = arrayHeight / (nRows - 1);

rx_local = zeros(nRX, 2);
idx = 1;
for row = 1:nRows
    for col = 1:nCols
        rx_local(idx, 1) = -arrayWidth/2 + (col-1)*dx;
        rx_local(idx, 2) = -arrayHeight/2 + (row-1)*dy;
        idx = idx + 1;
    end
end

theta_rad = deg2rad(tilt_angle);
rx_offset_x = rx_local(:,1);
rx_offset_y = rx_local(:,2) * cos(theta_rad);
rx_offset_z = -rx_local(:,2) * sin(theta_rad);

%% Main simulation loop
fprintf('\nStarting simulation...\n');
output_dir = 'Results';

for ti = 1:nTerrains
    terrain = terrains(ti);
    fprintf('\n--- Terrain: %s (base er=%.1f, sigma=%.4f S/m) ---\n', ...
        terrain.name, terrain.er, terrain.sigma);
    
    omega = 2*pi*freq;
    
    % Get per-chunk εr and σ for this terrain
    chunk_er = terrain_chunks(ti).er;
    chunk_sigma = terrain_chunks(ti).sigma;
    
    % Storage
    data_sensor1 = zeros(nPositions, 64);  % 32 low + 32 high
    data_sensor2 = zeros(nPositions, 64);
    
    for pi_idx = 1:nPositions
        y_pos = y_positions(pi_idx);
        
        tx1_pos = [sensor1_x, y_pos, sensor_z];
        tx2_pos = [sensor2_x, y_pos, sensor_z];
        
        for rx_idx = 1:nRX
            % Sensor 2 RX receiving from Sensor 1 TX
            rx2_pos = [sensor2_x + rx_offset_x(rx_idx), ...
                       y_pos + rx_offset_y(rx_idx), ...
                       sensor_z + rx_offset_z(rx_idx)];
            
            [rssi_low_s2, rssi_high_s2] = compute_rssi_bumpy(tx1_pos, rx2_pos, ...
                objects, obj_x_half, obj_y_half, obj_er, obj_sigma, ...
                freq, lambda, G_tx, G_rx, low_power_range, high_power_range, cfg, ...
                chunk_er, chunk_sigma, surface_heights, ...
                x_edges, y_edges, n_chunks_x, n_chunks_y, eps0, omega);
            
            data_sensor2(pi_idx, rx_idx) = rssi_low_s2;
            data_sensor2(pi_idx, rx_idx + nRX) = rssi_high_s2;
            
            % Sensor 1 RX receiving from Sensor 2 TX
            rx1_pos = [sensor1_x + rx_offset_x(rx_idx), ...
                       y_pos + rx_offset_y(rx_idx), ...
                       sensor_z + rx_offset_z(rx_idx)];
            
            [rssi_low_s1, rssi_high_s1] = compute_rssi_bumpy(tx2_pos, rx1_pos, ...
                objects, obj_x_half, obj_y_half, obj_er, obj_sigma, ...
                freq, lambda, G_tx, G_rx, low_power_range, high_power_range, cfg, ...
                chunk_er, chunk_sigma, surface_heights, ...
                x_edges, y_edges, n_chunks_x, n_chunks_y, eps0, omega);
            
            data_sensor1(pi_idx, rx_idx) = rssi_low_s1;
            data_sensor1(pi_idx, rx_idx + nRX) = rssi_high_s1;
        end
        
        if mod(pi_idx, 200) == 0
            fprintf('  Position %d/%d (Y = %d mm)\n', pi_idx, nPositions, y_pos);
        end
    end
    
    %% Save CSV
    headers_s1 = 'Y_mm';
    headers_s2 = 'Y_mm';
    for i = 1:nRX
        headers_s1 = [headers_s1, sprintf(',S1_RX%d_Low', i)];
        headers_s2 = [headers_s2, sprintf(',S2_RX%d_Low', i)];
    end
    for i = 1:nRX
        headers_s1 = [headers_s1, sprintf(',S1_RX%d_High', i)];
        headers_s2 = [headers_s2, sprintf(',S2_RX%d_High', i)];
    end
    
    filename_s1 = fullfile(output_dir, sprintf('RSSI_Sensor1_%s.csv', terrain.name));
    fid = fopen(filename_s1, 'w');
    fprintf(fid, '%s\n', headers_s1);
    fclose(fid);
    dlmwrite(filename_s1, [y_positions', data_sensor1], '-append', 'precision', '%.4f');
    
    filename_s2 = fullfile(output_dir, sprintf('RSSI_Sensor2_%s.csv', terrain.name));
    fid = fopen(filename_s2, 'w');
    fprintf(fid, '%s\n', headers_s2);
    fclose(fid);
    dlmwrite(filename_s2, [y_positions', data_sensor2], '-append', 'precision', '%.4f');
    
    fprintf('  Saved: %s\n', filename_s1);
    fprintf('  Saved: %s\n', filename_s2);
    
    %% Plot RSSI vs distance
    figure('Name', sprintf('RSSI_%s', terrain.name), 'Position', [50 50 1200 600], 'Visible', 'off');
    
    subplot(2,2,1);
    plot(y_positions/1000, data_sensor1(:, 1:nRX), 'LineWidth', 0.5);
    xlabel('Distance (m)'); ylabel('RSSI (dBm)');
    title(sprintf('Sensor 1 RX - Low Power (%s)', terrain.name));
    grid on; xlim([0 20]);
    yl = ylim;
    for oi = 1:length(objects)
        xr = [(objects(oi).y_center - obj_y_half)/1000, (objects(oi).y_center + obj_y_half)/1000];
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--');
    end
    
    subplot(2,2,2);
    plot(y_positions/1000, data_sensor1(:, nRX+1:end), 'LineWidth', 0.5);
    xlabel('Distance (m)'); ylabel('RSSI (dBm)');
    title(sprintf('Sensor 1 RX - High Power (%s)', terrain.name));
    grid on; xlim([0 20]);
    yl = ylim;
    for oi = 1:length(objects)
        xr = [(objects(oi).y_center - obj_y_half)/1000, (objects(oi).y_center + obj_y_half)/1000];
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--');
    end
    
    subplot(2,2,3);
    plot(y_positions/1000, data_sensor2(:, 1:nRX), 'LineWidth', 0.5);
    xlabel('Distance (m)'); ylabel('RSSI (dBm)');
    title(sprintf('Sensor 2 RX - Low Power (%s)', terrain.name));
    grid on; xlim([0 20]);
    yl = ylim;
    for oi = 1:length(objects)
        xr = [(objects(oi).y_center - obj_y_half)/1000, (objects(oi).y_center + obj_y_half)/1000];
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--');
    end
    
    subplot(2,2,4);
    plot(y_positions/1000, data_sensor2(:, nRX+1:end), 'LineWidth', 0.5);
    xlabel('Distance (m)'); ylabel('RSSI (dBm)');
    title(sprintf('Sensor 2 RX - High Power (%s)', terrain.name));
    grid on; xlim([0 20]);
    yl = ylim;
    for oi = 1:length(objects)
        xr = [(objects(oi).y_center - obj_y_half)/1000, (objects(oi).y_center + obj_y_half)/1000];
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--');
    end
    
    sgtitle(sprintf('RSSI Along Track - %s (Bumpy Terrain, \\epsilon_r±%d%%)', ...
        terrain.name, variation_pct));
    savefig(gcf, fullfile(output_dir, sprintf('RSSI_%s.fig', terrain.name)));
    exportgraphics(gcf, fullfile(output_dir, sprintf('RSSI_%s.png', terrain.name)), 'Resolution', 150);
    close(gcf);
    
    %% Mean RSSI plot
    figure('Name', sprintf('RSSI_Mean_%s', terrain.name), 'Position', [50 50 900 400], 'Visible', 'off');
    
    mean_s1_low = mean(data_sensor1(:, 1:nRX), 2);
    mean_s1_high = mean(data_sensor1(:, nRX+1:end), 2);
    mean_s2_low = mean(data_sensor2(:, 1:nRX), 2);
    mean_s2_high = mean(data_sensor2(:, nRX+1:end), 2);
    
    plot(y_positions/1000, mean_s1_low, 'b-', 'LineWidth', 1.2); hold on;
    plot(y_positions/1000, mean_s1_high, 'b--', 'LineWidth', 1.2);
    plot(y_positions/1000, mean_s2_low, 'r-', 'LineWidth', 1.2);
    plot(y_positions/1000, mean_s2_high, 'r--', 'LineWidth', 1.2);
    
    for oi = 1:4
        xr = [objects(oi).y_center - obj_y_half, objects(oi).y_center + obj_y_half] / 1000;
        yl = ylim;
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.9 0.9 0.5], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    end
    
    xlabel('Distance (m)'); ylabel('RSSI (dBm)');
    title(sprintf('Mean RSSI - %s (Bumpy)', terrain.name));
    legend('S1 Low', 'S1 High', 'S2 Low', 'S2 High', 'Location', 'best');
    grid on; xlim([0 20]); hold off;
    
    savefig(gcf, fullfile(output_dir, sprintf('RSSI_Mean_%s.fig', terrain.name)));
    exportgraphics(gcf, fullfile(output_dir, sprintf('RSSI_Mean_%s.png', terrain.name)), 'Resolution', 150);
    close(gcf);
    
    %% Statistics plot
    s1_data = data_sensor1(:, 1:nRX);
    s2_data = data_sensor2(:, 1:nRX);
    y_km = y_positions / 1000;
    
    figure('Name', sprintf('Stats_%s', terrain.name), 'Position', [50 50 1200 500], 'Visible', 'off');
    subplot(2,3,1); plot(y_km, mean(s1_data,2), 'b', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dBm'); title('S1 Mean');
    subplot(2,3,2); plot(y_km, std(s1_data,0,2), 'b', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('S1 Std');
    subplot(2,3,3); plot(y_km, max(s1_data,[],2)-min(s1_data,[],2), 'b', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('S1 Range');
    subplot(2,3,4); plot(y_km, mean(s2_data,2), 'r', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dBm'); title('S2 Mean');
    subplot(2,3,5); plot(y_km, std(s2_data,0,2), 'r', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('S2 Std');
    subplot(2,3,6); plot(y_km, max(s2_data,[],2)-min(s2_data,[],2), 'r', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('S2 Range');
    sgtitle(sprintf('Statistics - %s (Bumpy)', terrain.name));
    savefig(gcf, fullfile(output_dir, sprintf('Stats_%s.fig', terrain.name)));
    exportgraphics(gcf, fullfile(output_dir, sprintf('Stats_%s.png', terrain.name)), 'Resolution', 150);
    close(gcf);
    
    %% Between-sensor comparison
    diff_mean = mean(s1_data,2) - mean(s2_data,2);
    xcorr_per_pos = zeros(nPositions, 1);
    for pp = 1:nPositions
        r = corrcoef(s1_data(pp,:), s2_data(pp,:));
        xcorr_per_pos(pp) = r(1,2);
    end
    
    figure('Name', sprintf('Between_%s', terrain.name), 'Position', [50 50 1000 500], 'Visible', 'off');
    subplot(2,1,1);
    plot(y_km, diff_mean, 'k', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('\Delta dBm'); title('Mean Diff (S1-S2)');
    yl = ylim;
    for oi = 1:4
        xr = [(objects(oi).y_center - obj_y_half)/1000, (objects(oi).y_center + obj_y_half)/1000];
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--');
    end
    subplot(2,1,2);
    plot(y_km, xcorr_per_pos, 'Color', [0 0.5 0], 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('Corr'); title('Cross-Correlation (S1 vs S2)');
    ylim([-1 1]);
    sgtitle(sprintf('Between-Sensor - %s (Bumpy)', terrain.name));
    savefig(gcf, fullfile(output_dir, sprintf('Between_%s.fig', terrain.name)));
    exportgraphics(gcf, fullfile(output_dir, sprintf('Between_%s.png', terrain.name)), 'Resolution', 150);
    close(gcf);
end

%% Terrain comparison plot
figure('Name', 'Terrain Comparison', 'Position', [50 50 1000 500], 'Visible', 'off');
colors = {'b', 'g', [0.6 0.3 0]};
hold on;
for ti = 1:nTerrains
    d1 = readmatrix(fullfile(output_dir, sprintf('RSSI_Sensor1_%s.csv', terrains(ti).name)));
    mean_rssi = mean(d1(:, 2:nRX+1), 2);
    plot(y_positions/1000, mean_rssi, 'Color', colors{ti}, 'LineWidth', 1.5);
end
yl = ylim;
for oi = 1:4
    xr = [objects(oi).y_center - obj_y_half, objects(oi).y_center + obj_y_half] / 1000;
    patch([xr(1) xr(2) xr(2) xr(1)], [yl(1)*[1 1] yl(2)*[1 1]], ...
        [0.9 0.9 0.5], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
end
xlabel('Distance (m)'); ylabel('Mean RSSI (dBm)');
title('Terrain Comparison - Mean RSSI (Bumpy Terrain)');
legend(terrains(1).name, terrains(2).name, terrains(3).name, 'Location', 'best');
grid on; xlim([0 20]); hold off;
savefig(gcf, fullfile(output_dir, 'Terrain_Comparison.fig'));
exportgraphics(gcf, fullfile(output_dir, 'Terrain_Comparison.png'), 'Resolution', 150);
close(gcf);

%% Save terrain data for reference
save(fullfile(output_dir, 'TerrainChunks.mat'), 'terrain_chunks', 'surface_heights', ...
    'x_edges', 'y_edges', 'chunk_size', 'variation_pct', 'surface_z_max');
fprintf('\n=== Bumpy Terrain Simulation Complete ===\n');

%% ============ LOCAL FUNCTIONS ============

function [rssi_low, rssi_high] = compute_rssi_bumpy(tx_pos, rx_pos, ...
    objects, obj_x_half, obj_y_half, obj_er, obj_sigma, ...
    freq, lambda, G_tx, G_rx, low_pwr, high_pwr, cfg, ...
    chunk_er, chunk_sigma, surface_heights, ...
    x_edges, y_edges, n_chunks_x, n_chunks_y, eps0, omega)
    % Compute RSSI with per-chunk terrain properties and surface height offset
    
    % Find reflection point using image method (approximate ground at Z=0 first)
    tx_z = tx_pos(3);
    rx_z = rx_pos(3);
    dx = rx_pos(1) - tx_pos(1);
    dy = rx_pos(2) - tx_pos(2);
    d_horiz = sqrt(dx^2 + dy^2);
    
    total_z = tx_z + rx_z;
    frac = tx_z / total_z;
    ref_x = tx_pos(1) + frac * dx;
    ref_y = tx_pos(2) + frac * dy;
    
    % Determine which chunk the reflection point falls in
    ix = find(ref_x >= x_edges(1:end-1) & ref_x < x_edges(2:end), 1);
    iy = find(ref_y >= y_edges(1:end-1) & ref_y < y_edges(2:end), 1);
    
    % Clamp to valid range
    if isempty(ix), ix = 1; end
    if isempty(iy), iy = 1; end
    ix = max(1, min(n_chunks_x, ix));
    iy = max(1, min(n_chunks_y, iy));
    
    % Get surface height at this chunk
    z_surface = surface_heights(iy, ix);  % 0 to 10mm above Z=0
    
    % Check if reflection point is over an object (void)
    is_void = false;
    for oi = 1:length(objects)
        if abs(ref_x) <= obj_x_half && ...
           abs(ref_y - objects(oi).y_center) <= obj_y_half
            is_void = true;
            break;
        end
    end
    
    if is_void
        eps_ground = obj_er - 1j*obj_sigma/(omega*eps0);
        z_surface = 0;  % Objects are flat
    else
        % Use per-chunk εr and σ
        local_er = chunk_er(iy, ix);
        local_sigma = chunk_sigma(iy, ix);
        eps_ground = local_er - 1j*local_sigma/(omega*eps0);
    end
    
    % Recalculate paths with surface height offset
    % Ground is now at Z = z_surface (slightly above 0)
    % Effective heights above reflection surface:
    eff_tx_z = tx_z - z_surface;
    eff_rx_z = rx_z - z_surface;
    
    % Direct path
    d_direct = norm(tx_pos - rx_pos) / 1000;  % meters
    
    % Reflected path lengths (using effective heights)
    eff_total_z = eff_tx_z + eff_rx_z;
    eff_frac = eff_tx_z / eff_total_z;
    
    d_tx_ref = sqrt(eff_tx_z^2 + (eff_frac*d_horiz)^2) / 1000;
    d_ref_rx = sqrt(eff_rx_z^2 + ((1-eff_frac)*d_horiz)^2) / 1000;
    d_reflected = d_tx_ref + d_ref_rx;
    
    % Angle of incidence
    theta_i = atan2(eff_frac*d_horiz, eff_tx_z);
    
    % Fresnel reflection coefficient (average TE + TM)
    cos_t = cos(theta_i);
    sin_t = sin(theta_i);
    sqrt_term = sqrt(eps_ground - sin_t^2);
    
    Gamma_TE = (cos_t - sqrt_term) / (cos_t + sqrt_term);
    Gamma_TM = (eps_ground*cos_t - sqrt_term) / (eps_ground*cos_t + sqrt_term);
    Gamma = (Gamma_TE + Gamma_TM) / 2;
    Gamma_mag = abs(Gamma);
    
    % Path loss
    FSPL_direct = 20*log10(4*pi*d_direct/lambda);
    FSPL_reflected = 20*log10(4*pi*d_reflected/lambda);
    reflection_loss = -20*log10(Gamma_mag + 1e-10);
    
    % Antenna pattern loss
    pattern_loss_direct = cfg.pattern_loss_direct;
    pattern_loss_reflected = cfg.pattern_loss_reflected;
    
    % Power contributions
    P_direct_lin = 10^((-FSPL_direct + G_tx + G_rx - pattern_loss_direct)/10);
    P_reflected_lin = 10^((-FSPL_reflected - reflection_loss + G_tx + G_rx - pattern_loss_reflected)/10);
    
    % Coherent sum with phase
    phase_diff = 2*pi*(d_reflected - d_direct)/lambda;
    P_total_lin = P_direct_lin + P_reflected_lin * exp(1j*phase_diff);
    P_total_dB = 10*log10(abs(P_total_lin) + 1e-20);
    
    % Noise
    noise_std = cfg.noise_std;
    
    % RSSI
    P_tx_low = low_pwr(1) + (low_pwr(2)-low_pwr(1))*rand();
    rssi_low = P_tx_low + P_total_dB + noise_std*randn();
    
    P_tx_high = high_pwr(1) + (high_pwr(2)-high_pwr(1))*rand();
    rssi_high = P_tx_high + P_total_dB + noise_std*randn();
end
