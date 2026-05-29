%% RF Material Sensing Simulation - Robot Track Traverse
% Two material sensors in criss-cross configuration
% Sensor 1 TX -> Sensor 2 RX, Sensor 2 TX -> Sensor 1 RX
% Robot moves along 20m track, RSSI recorded at 10mm increments
%
% All geometry/material parameters loaded from SimConfig.m

clear; close all; clc;

%% Load shared configuration
SimConfig;

%% Physical Constants
c = 299792458;
eps0 = 8.854187817e-12;
eta0 = 120*pi;

%% Unpack parameters from cfg
freq = cfg.freq;
lambda = c / freq;
k = 2*pi / lambda;

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

% Terrains
terrains = cfg.terrains;
nTerrains = length(terrains);

fprintf('=== RF Material Sensing Simulation ===\n');
fprintf('Frequency: %.2f GHz\n', freq/1e9);
fprintf('Sensors: X = %d mm and X = %d mm, Z = %.2f mm\n', sensor1_x, sensor2_x, sensor_z);
fprintf('Track: Y = %d to %d mm (%d positions at %d mm steps)\n', ...
    y_start, y_end, nPositions, y_step);
fprintf('Objects: 4 voids (air), 500mm x 300mm\n');
fprintf('Terrains: %s, %s, %s\n', terrains(1).name, terrains(2).name, terrains(3).name);
fprintf('Acquisition: 32 low power + 32 high power per sensor\n');
fprintf('Total data points per terrain: %d positions x 128 readings = %d\n\n', ...
    nPositions, nPositions*128);

%% Generate RX antenna positions (local frame, board-centered)
dx = arrayWidth / (nCols - 1);
dy = arrayHeight / (nRows - 1);

% Local positions on PCB [x_local, y_local] in mm
rx_local = zeros(nRX, 2);
idx = 1;
for row = 1:nRows
    for col = 1:nCols
        rx_local(idx, 1) = -arrayWidth/2 + (col-1)*dx;
        rx_local(idx, 2) = -arrayHeight/2 + (row-1)*dy;
        idx = idx + 1;
    end
end

% Apply 45-degree tilt rotation (about X-axis)
% After tilt: local Y becomes split into world Y and Z components
theta_rad = deg2rad(tilt_angle);

% For each RX on Sensor 1 (at X = -90mm):
% World position = [sensor_x + rx_local_x, Y_travel + rx_local_y*cos(tilt), sensor_z + rx_local_y*sin(tilt)]
% But since board tilts forward (toward ground), the Z component decreases for +y_local
% RX positions relative to sensor center (in world frame):
rx_offset_x = rx_local(:,1);                      % X offset (mm)
rx_offset_y = rx_local(:,2) * cos(theta_rad);     % Y offset (mm)
rx_offset_z = -rx_local(:,2) * sin(theta_rad);    % Z offset (mm, negative = lower)

fprintf('RX Z range relative to center: %.1f to %.1f mm\n', min(rx_offset_z), max(rx_offset_z));

%% Compute RSSI model
% Criss-cross: TX1 -> RX2 array, TX2 -> RX1 array
% Signal path: TX -> ground reflection -> RX (dominant path for tilted sensors)
% Also includes direct path (weaker, since sensors face ground not each other)
%
% For each RX element at position P_rx:
%   Reflected path: TX -> reflection point on ground -> RX
%   Path loss = free-space spreading + reflection coefficient magnitude
%   RSSI = P_tx + G_tx + G_rx - PathLoss_total

% TX antenna gain (dBi)
G_tx = cfg.G_tx;
G_rx = cfg.G_rx;

fprintf('\nStarting simulation...\n');

for ti = 1:nTerrains
    terrain = terrains(ti);
    fprintf('\n--- Terrain: %s (er=%.1f, sigma=%.4f S/m) ---\n', ...
        terrain.name, terrain.er, terrain.sigma);
    
    % Complex permittivity of terrain
    omega = 2*pi*freq;
    eps_terrain = terrain.er - 1j*terrain.sigma/(omega*eps0);
    
    % Complex permittivity of void (air)
    eps_void = obj_er - 1j*obj_sigma/(omega*eps0);
    
    % Storage: [position, antenna1-32_low, antenna1-32_high] for each sensor
    % Sensor 1 RX receives from Sensor 2 TX
    % Sensor 2 RX receives from Sensor 1 TX
    data_sensor1 = zeros(nPositions, 64);  % 32 low + 32 high
    data_sensor2 = zeros(nPositions, 64);  % 32 low + 32 high
    
    for pi_idx = 1:nPositions
        y_pos = y_positions(pi_idx);
        
        % TX positions (at sensor centers)
        tx1_pos = [sensor1_x, y_pos, sensor_z];  % Sensor 1 TX
        tx2_pos = [sensor2_x, y_pos, sensor_z];  % Sensor 2 TX
        
        for rx_idx = 1:nRX
            % --- Sensor 2 RX receiving from Sensor 1 TX ---
            rx2_pos = [sensor2_x + rx_offset_x(rx_idx), ...
                       y_pos + rx_offset_y(rx_idx), ...
                       sensor_z + rx_offset_z(rx_idx)];
            
            [rssi_low_s2, rssi_high_s2] = compute_rssi(tx1_pos, rx2_pos, ...
                y_pos, eps_terrain, eps_void, objects, obj_x_half, obj_y_half, ...
                freq, lambda, G_tx, G_rx, low_power_range, high_power_range, cfg);
            
            data_sensor2(pi_idx, rx_idx) = rssi_low_s2;        % Low power
            data_sensor2(pi_idx, rx_idx + nRX) = rssi_high_s2;  % High power
            
            % --- Sensor 1 RX receiving from Sensor 2 TX ---
            rx1_pos = [sensor1_x + rx_offset_x(rx_idx), ...
                       y_pos + rx_offset_y(rx_idx), ...
                       sensor_z + rx_offset_z(rx_idx)];
            
            [rssi_low_s1, rssi_high_s1] = compute_rssi(tx2_pos, rx1_pos, ...
                y_pos, eps_terrain, eps_void, objects, obj_x_half, obj_y_half, ...
                freq, lambda, G_tx, G_rx, low_power_range, high_power_range, cfg);
            
            data_sensor1(pi_idx, rx_idx) = rssi_low_s1;        % Low power
            data_sensor1(pi_idx, rx_idx + nRX) = rssi_high_s1;  % High power
        end
        
        % Progress
        if mod(pi_idx, 200) == 0
            fprintf('  Position %d/%d (Y = %d mm)\n', pi_idx, nPositions, y_pos);
        end
    end
    
    %% Save CSV for this terrain
    % Headers
    headers_s1 = ['Y_mm'];
    headers_s2 = ['Y_mm'];
    for i = 1:nRX
        headers_s1 = [headers_s1, sprintf(',S1_RX%d_Low', i)];
        headers_s2 = [headers_s2, sprintf(',S2_RX%d_Low', i)];
    end
    for i = 1:nRX
        headers_s1 = [headers_s1, sprintf(',S1_RX%d_High', i)];
        headers_s2 = [headers_s2, sprintf(',S2_RX%d_High', i)];
    end
    
    % Sensor 1 CSV
    filename_s1 = fullfile(cfg.output_dir, sprintf('RSSI_Sensor1_%s.csv', terrain.name));
    fid = fopen(filename_s1, 'w');
    fprintf(fid, '%s\n', headers_s1);
    fclose(fid);
    dlmwrite(filename_s1, [y_positions', data_sensor1], '-append', 'precision', '%.4f');
    
    % Sensor 2 CSV
    filename_s2 = fullfile(cfg.output_dir, sprintf('RSSI_Sensor2_%s.csv', terrain.name));
    fid = fopen(filename_s2, 'w');
    fprintf(fid, '%s\n', headers_s2);
    fclose(fid);
    dlmwrite(filename_s2, [y_positions', data_sensor2], '-append', 'precision', '%.4f');
    
    fprintf('  Saved: %s\n', filename_s1);
    fprintf('  Saved: %s\n', filename_s2);
    
    %% Plot RSSI vs distance for this terrain
    figure('Name', sprintf('RSSI_%s', terrain.name), 'Position', [50 50 1200 600], 'Visible', 'off');
    
    subplot(2,2,1);
    plot(y_positions/1000, data_sensor1(:, 1:nRX), 'LineWidth', 0.5);
    xlabel('Distance (m)'); ylabel('RSSI (dBm)');
    title(sprintf('Sensor 1 RX - Low Power (%s)', terrain.name));
    grid on; xlim([0 20]);
    % Mark object regions
    yl = ylim;
    for oi = 1:length(objects)
        xr = [(objects(oi).y_center - obj_y_half)/1000, (objects(oi).y_center + obj_y_half)/1000];
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--', 'LineWidth', 0.5);
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
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--', 'LineWidth', 0.5);
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
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--', 'LineWidth', 0.5);
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
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--', 'LineWidth', 0.5);
    end
    
    sgtitle(sprintf('RSSI Along Track - Terrain: %s (\\epsilon_r=%.1f, \\sigma=%.4f)', ...
        terrain.name, terrain.er, terrain.sigma));
    
    savefig(gcf, fullfile(cfg.output_dir, sprintf('RSSI_%s.fig', terrain.name)));
    exportgraphics(gcf, fullfile(cfg.output_dir, sprintf('RSSI_%s.png', terrain.name)), 'Resolution', 150);
    close(gcf);
    
    %% Mean RSSI plot (averaged across all 32 antennas)
    figure('Name', sprintf('RSSI_Mean_%s', terrain.name), 'Position', [50 50 900 400], 'Visible', 'off');
    
    mean_s1_low = mean(data_sensor1(:, 1:nRX), 2);
    mean_s1_high = mean(data_sensor1(:, nRX+1:end), 2);
    mean_s2_low = mean(data_sensor2(:, 1:nRX), 2);
    mean_s2_high = mean(data_sensor2(:, nRX+1:end), 2);
    
    plot(y_positions/1000, mean_s1_low, 'b-', 'LineWidth', 1.2); hold on;
    plot(y_positions/1000, mean_s1_high, 'b--', 'LineWidth', 1.2);
    plot(y_positions/1000, mean_s2_low, 'r-', 'LineWidth', 1.2);
    plot(y_positions/1000, mean_s2_high, 'r--', 'LineWidth', 1.2);
    
    % Mark objects
    for oi = 1:4
        xr = [objects(oi).y_center - obj_y_half, objects(oi).y_center + obj_y_half] / 1000;
        patch([xr(1) xr(2) xr(2) xr(1)], [min(ylim)*[1 1] max(ylim)*[1 1]], ...
            [0.9 0.9 0.5], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    end
    
    xlabel('Distance (m)'); ylabel('RSSI (dBm)');
    title(sprintf('Mean RSSI Along Track - %s', terrain.name));
    legend('Sensor1 Low', 'Sensor1 High', 'Sensor2 Low', 'Sensor2 High', 'Location', 'best');
    grid on; xlim([0 20]);
    hold off;
    
    savefig(gcf, fullfile(cfg.output_dir, sprintf('RSSI_Mean_%s.fig', terrain.name)));
    exportgraphics(gcf, fullfile(cfg.output_dir, sprintf('RSSI_Mean_%s.png', terrain.name)), 'Resolution', 150);
    close(gcf);
    
    %% Per-sensor statistics plot (std, min, max, IQR)
    % Compute stats across 32 antennas at each position (using low power)
    s1_data = data_sensor1(:, 1:nRX);
    s2_data = data_sensor2(:, 1:nRX);
    
    stats_s1.mean = mean(s1_data, 2);
    stats_s1.std = std(s1_data, 0, 2);
    stats_s1.min = min(s1_data, [], 2);
    stats_s1.max = max(s1_data, [], 2);
    q25_s1 = quantile(s1_data, 0.25, 2);
    q75_s1 = quantile(s1_data, 0.75, 2);
    stats_s1.iqr = q75_s1 - q25_s1;
    
    stats_s2.mean = mean(s2_data, 2);
    stats_s2.std = std(s2_data, 0, 2);
    stats_s2.min = min(s2_data, [], 2);
    stats_s2.max = max(s2_data, [], 2);
    q25_s2 = quantile(s2_data, 0.25, 2);
    q75_s2 = quantile(s2_data, 0.75, 2);
    stats_s2.iqr = q75_s2 - q25_s2;
    
    y_km = y_positions / 1000;
    
    % Sensor 1 stats
    figure('Name', sprintf('Stats_S1_%s', terrain.name), 'Position', [50 50 1200 700], 'Visible', 'off');
    subplot(2,3,1); plot(y_km, stats_s1.mean, 'b', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dBm'); title('Sensor 1 - Mean');
    subplot(2,3,2); plot(y_km, stats_s1.std, 'b', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('Sensor 1 - Std');
    subplot(2,3,3); plot(y_km, stats_s1.iqr, 'b', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('Sensor 1 - IQR');
    subplot(2,3,4); plot(y_km, stats_s1.min, 'b', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dBm'); title('Sensor 1 - Min');
    subplot(2,3,5); plot(y_km, stats_s1.max, 'b', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dBm'); title('Sensor 1 - Max');
    subplot(2,3,6); 
    plot(y_km, stats_s1.max - stats_s1.min, 'b', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('Sensor 1 - Range (Max-Min)');
    sgtitle(sprintf('Sensor 1 Statistics - %s', terrain.name));
    savefig(gcf, fullfile(cfg.output_dir, sprintf('Stats_S1_%s.fig', terrain.name)));
    exportgraphics(gcf, fullfile(cfg.output_dir, sprintf('Stats_S1_%s.png', terrain.name)), 'Resolution', 150);
    close(gcf);
    
    % Sensor 2 stats
    figure('Name', sprintf('Stats_S2_%s', terrain.name), 'Position', [50 50 1200 700], 'Visible', 'off');
    subplot(2,3,1); plot(y_km, stats_s2.mean, 'r', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dBm'); title('Sensor 2 - Mean');
    subplot(2,3,2); plot(y_km, stats_s2.std, 'r', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('Sensor 2 - Std');
    subplot(2,3,3); plot(y_km, stats_s2.iqr, 'r', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('Sensor 2 - IQR');
    subplot(2,3,4); plot(y_km, stats_s2.min, 'r', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dBm'); title('Sensor 2 - Min');
    subplot(2,3,5); plot(y_km, stats_s2.max, 'r', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dBm'); title('Sensor 2 - Max');
    subplot(2,3,6); 
    plot(y_km, stats_s2.max - stats_s2.min, 'r', 'LineWidth', 1); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('dB'); title('Sensor 2 - Range (Max-Min)');
    sgtitle(sprintf('Sensor 2 Statistics - %s', terrain.name));
    savefig(gcf, fullfile(cfg.output_dir, sprintf('Stats_S2_%s.fig', terrain.name)));
    exportgraphics(gcf, fullfile(cfg.output_dir, sprintf('Stats_S2_%s.png', terrain.name)), 'Resolution', 150);
    close(gcf);
    
    %% Between-sensor comparison plot (diff_mean, diff_std, cross-correlation)
    diff_mean = stats_s1.mean - stats_s2.mean;
    diff_std = stats_s1.std - stats_s2.std;
    
    % Cross-correlation (sliding window, normalized per position)
    % Use per-position correlation across the 32 antennas
    xcorr_per_pos = zeros(nPositions, 1);
    for pi_idx = 1:nPositions
        r = corrcoef(s1_data(pi_idx,:), s2_data(pi_idx,:));
        xcorr_per_pos(pi_idx) = r(1,2);
    end
    
    figure('Name', sprintf('Between_Sensors_%s', terrain.name), 'Position', [50 50 1100 600], 'Visible', 'off');
    subplot(3,1,1);
    plot(y_km, diff_mean, 'k', 'LineWidth', 1.2); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('\Delta dBm');
    title('Mean Difference (Sensor1 - Sensor2)');
    yl = ylim;
    for oi = 1:length(objects)
        xr = [(objects(oi).y_center - obj_y_half)/1000, (objects(oi).y_center + obj_y_half)/1000];
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--', 'LineWidth', 0.5);
    end
    
    subplot(3,1,2);
    plot(y_km, diff_std, 'm', 'LineWidth', 1.2); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('\Delta dB');
    title('Std Difference (Sensor1 - Sensor2)');
    yl = ylim;
    for oi = 1:length(objects)
        xr = [(objects(oi).y_center - obj_y_half)/1000, (objects(oi).y_center + obj_y_half)/1000];
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--', 'LineWidth', 0.5);
    end
    
    subplot(3,1,3);
    plot(y_km, xcorr_per_pos, 'Color', [0 0.5 0], 'LineWidth', 1.2); grid on; xlim([0 20]);
    xlabel('Distance (m)'); ylabel('Correlation');
    title('Cross-Correlation (S1 vs S2, per position)');
    ylim([-1 1]);
    yl = ylim;
    for oi = 1:length(objects)
        xr = [(objects(oi).y_center - obj_y_half)/1000, (objects(oi).y_center + obj_y_half)/1000];
        patch([xr(1) xr(2) xr(2) xr(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'r', 'LineStyle', '--', 'LineWidth', 0.5);
    end
    
    sgtitle(sprintf('Between-Sensor Comparison - %s', terrain.name));
    savefig(gcf, fullfile(cfg.output_dir, sprintf('Between_Sensors_%s.fig', terrain.name)));
    exportgraphics(gcf, fullfile(cfg.output_dir, sprintf('Between_Sensors_%s.png', terrain.name)), 'Resolution', 150);
    close(gcf);
end

%% Comparison plot: all terrains mean RSSI
figure('Name', 'Terrain Comparison', 'Position', [50 50 1000 500], 'Visible', 'off');
colors = {'b', 'g', [0.6 0.3 0]};
hold on;

for ti = 1:nTerrains
    % Reload CSVs
    d1 = readmatrix(fullfile(cfg.output_dir, sprintf('RSSI_Sensor1_%s.csv', terrains(ti).name)));
    mean_rssi = mean(d1(:, 2:nRX+1), 2);  % Mean of low-power Sensor 1
    plot(y_positions/1000, mean_rssi, 'Color', colors{ti}, 'LineWidth', 1.5);
end

% Mark objects
yl = ylim;
for oi = 1:4
    xr = [objects(oi).y_center - obj_y_half, objects(oi).y_center + obj_y_half] / 1000;
    patch([xr(1) xr(2) xr(2) xr(1)], [yl(1)*[1 1] yl(2)*[1 1]], ...
        [0.9 0.9 0.5], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
end

xlabel('Distance (m)'); ylabel('Mean RSSI (dBm)');
title('Terrain Comparison - Mean RSSI (Sensor 1, Low Power)');
legend(terrains(1).name, terrains(2).name, terrains(3).name, 'Location', 'best');
grid on; xlim([0 20]);
hold off;

savefig(gcf, fullfile(cfg.output_dir, 'Terrain_Comparison.fig'));
exportgraphics(gcf, fullfile(cfg.output_dir, 'Terrain_Comparison.png'), 'Resolution', 150);
close(gcf);

fprintf('\n=== Simulation Complete ===\n');
fprintf('CSV files saved for all terrains.\n');
fprintf('Figures saved as .fig and .png\n');

%% ============ LOCAL FUNCTIONS ============

function [rssi_low, rssi_high] = compute_rssi(tx_pos, rx_pos, y_sensor, ...
    eps_terrain, eps_void, objects, obj_x_half, obj_y_half, ...
    freq, lambda, G_tx, G_rx, low_pwr, high_pwr, cfg)
    % Compute RSSI for a TX->RX pair considering ground reflection
    % tx_pos, rx_pos: [x, y, z] in mm
    % Returns RSSI in dBm for low and high power
    
    % Direct path (line of sight between sensors)
    d_direct = norm(tx_pos - rx_pos) / 1000;  % meters
    
    % Reflected path via ground (Z = 0)
    % Find specular reflection point
    tx_z = tx_pos(3);  % height in mm
    rx_z = rx_pos(3);
    dx = rx_pos(1) - tx_pos(1);  % horizontal separation X
    dy = rx_pos(2) - tx_pos(2);  % horizontal separation Y
    d_horiz = sqrt(dx^2 + dy^2);  % horizontal distance mm
    
    % Reflection point (using image method)
    % Image of TX at (tx_x, tx_y, -tx_z)
    % Line from image TX to RX hits ground at reflection point
    total_z = tx_z + rx_z;
    frac = tx_z / total_z;  % fraction along horizontal from TX
    ref_x = tx_pos(1) + frac * dx;
    ref_y = tx_pos(2) + frac * dy;
    
    % Path lengths for reflected path
    d_tx_ref = sqrt(tx_z^2 + (frac*d_horiz)^2) / 1000;  % meters
    d_ref_rx = sqrt(rx_z^2 + ((1-frac)*d_horiz)^2) / 1000;  % meters
    d_reflected = d_tx_ref + d_ref_rx;
    
    % Angle of incidence (from normal to ground)
    theta_i = atan2(frac*d_horiz, tx_z);  % radians
    
    % Determine material at reflection point
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
        eps_ground = eps_void;
    else
        eps_ground = eps_terrain;
    end
    
    % Fresnel reflection coefficient (average TE + TM)
    cos_t = cos(theta_i);
    sin_t = sin(theta_i);
    sqrt_term = sqrt(eps_ground - sin_t^2);
    
    Gamma_TE = (cos_t - sqrt_term) / (cos_t + sqrt_term);
    Gamma_TM = (eps_ground*cos_t - sqrt_term) / (eps_ground*cos_t + sqrt_term);
    Gamma = (Gamma_TE + Gamma_TM) / 2;
    Gamma_mag = abs(Gamma);
    
    % Free-space path loss (dB)
    % lambda in meters, distances in meters
    FSPL_direct = 20*log10(4*pi*d_direct/(lambda));
    FSPL_reflected = 20*log10(4*pi*d_reflected/(lambda));
    
    % Reflected path has additional loss from reflection
    reflection_loss = -20*log10(Gamma_mag + 1e-10);  % dB (avoid log(0))
    
    % Total received power (combine direct + reflected)
    % Direct path is weaker because sensors face ground (not each other)
    % Apply antenna pattern loss from config
    pattern_loss_direct = cfg.pattern_loss_direct;
    pattern_loss_reflected = cfg.pattern_loss_reflected;
    
    % Power contributions in linear
    P_direct_lin = 10^((-FSPL_direct + G_tx + G_rx - pattern_loss_direct)/10);
    P_reflected_lin = 10^((-FSPL_reflected - reflection_loss + G_tx + G_rx - pattern_loss_reflected)/10);
    
    % Phase difference between paths (creates interference pattern)
    phase_diff = 2*pi*(d_reflected - d_direct)/(lambda);
    
    % Coherent sum (with phase) - reflection already in P_reflected_lin
    P_total_lin = P_direct_lin + P_reflected_lin * exp(1j*phase_diff);
    P_total_dB = 10*log10(abs(P_total_lin) + 1e-20);
    
    % Add measurement noise (RSSI quantization + thermal)
    noise_std = cfg.noise_std;
    
    % Low power RSSI
    P_tx_low = low_pwr(1) + (low_pwr(2)-low_pwr(1))*rand();
    rssi_low = P_tx_low + P_total_dB + noise_std*randn();
    
    % High power RSSI
    P_tx_high = high_pwr(1) + (high_pwr(2)-high_pwr(1))*rand();
    rssi_high = P_tx_high + P_total_dB + noise_std*randn();
end
