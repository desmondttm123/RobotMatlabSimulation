%% CompareArchitectures.m - Criss-Cross vs Same-Antenna Architecture Comparison
% Simulates both TX/RX configurations on bumpy terrain and compares:
%   1. Criss-cross: TX1->RX2, TX2->RX1 (wider scan area, more ground interaction)
%   2. Same-antenna: TX1->RX1, TX2->RX2 (short path, less ground interaction)
%
% Trains identical MLP classifiers on both and compares accuracy.
% Output: comparison figures + accuracy table in Results/

clear; close all; clc;

%% Add parent path for SimConfig
addpath('..');
SimConfig;

rng(123);

output_dir = 'Results';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% Terrain generation (same as TrackSimulation_Bumpy)
chunk_size = 100;
variation_pct = 2;
surface_z_max = 10;

track_width = cfg.track_width;
track_y_start = cfg.track_y_start;
track_y_end = cfg.track_y_end;

n_chunks_x = track_width / chunk_size;
n_chunks_y = (track_y_end - track_y_start) / chunk_size;
gs_x = track_width / 2;

x_edges = linspace(-gs_x, gs_x, n_chunks_x + 1);
y_edges = linspace(track_y_start, track_y_end, n_chunks_y + 1);
x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
y_centers = (y_edges(1:end-1) + y_edges(2:end)) / 2;

terrains = cfg.terrains;
nTerrains = length(terrains);

terrain_chunks = struct();
for ti = 1:nTerrains
    base_er = terrains(ti).er;
    base_sigma = terrains(ti).sigma;
    er_field = base_er + base_er * (variation_pct/100) * randn(n_chunks_y, n_chunks_x);
    er_field = max(er_field, base_er * (1 - variation_pct/100*2));
    er_field = min(er_field, base_er * (1 + variation_pct/100*2));
    sigma_field = base_sigma + base_sigma * (variation_pct/100) * randn(n_chunks_y, n_chunks_x);
    sigma_field = max(sigma_field, base_sigma * (1 - variation_pct/100*2));
    sigma_field = min(sigma_field, base_sigma * (1 + variation_pct/100*2));
    terrain_chunks(ti).er = er_field;
    terrain_chunks(ti).sigma = sigma_field;
end

surface_heights = rand(n_chunks_y, n_chunks_x) * surface_z_max;
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

%% Physical constants
c = 299792458;
eps0 = 8.854187817e-12;
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

%% ====================================================================
%  SIMULATE BOTH ARCHITECTURES
%  ====================================================================
fprintf('=== Architecture Comparison: Criss-Cross vs Same-Antenna ===\n');
fprintf('Track: %d positions, %d terrains, %d RX elements\n', nPositions, nTerrains, nRX);
fprintf('Sensor separation: %d mm\n', sensor2_x - sensor1_x);

% Storage for both architectures
% Each: [nPositions x 64] per terrain (32 low + 32 high per sensor pair)
data_cross_s1 = cell(nTerrains, 1);  % Criss-cross: TX2->RX1
data_cross_s2 = cell(nTerrains, 1);  % Criss-cross: TX1->RX2
data_same_s1 = cell(nTerrains, 1);   % Same-antenna: TX1->RX1
data_same_s2 = cell(nTerrains, 1);   % Same-antenna: TX2->RX2

omega = 2*pi*freq;

for ti = 1:nTerrains
    terrain = terrains(ti);
    fprintf('\n--- Terrain: %s ---\n', terrain.name);
    
    chunk_er = terrain_chunks(ti).er;
    chunk_sigma = terrain_chunks(ti).sigma;
    
    cross_s1 = zeros(nPositions, 64);
    cross_s2 = zeros(nPositions, 64);
    same_s1 = zeros(nPositions, 64);
    same_s2 = zeros(nPositions, 64);
    
    for pi_idx = 1:nPositions
        y_pos = y_positions(pi_idx);
        
        tx1_pos = [sensor1_x, y_pos, sensor_z];
        tx2_pos = [sensor2_x, y_pos, sensor_z];
        
        for rx_idx = 1:nRX
            % RX positions for each sensor
            rx1_pos = [sensor1_x + rx_offset_x(rx_idx), ...
                       y_pos + rx_offset_y(rx_idx), ...
                       sensor_z + rx_offset_z(rx_idx)];
            rx2_pos = [sensor2_x + rx_offset_x(rx_idx), ...
                       y_pos + rx_offset_y(rx_idx), ...
                       sensor_z + rx_offset_z(rx_idx)];
            
            % --- CRISS-CROSS: TX1->RX2, TX2->RX1 ---
            [rssi_low, rssi_high] = compute_rssi_bumpy(tx1_pos, rx2_pos, ...
                objects, obj_x_half, obj_y_half, obj_er, obj_sigma, ...
                freq, lambda, G_tx, G_rx, low_power_range, high_power_range, cfg, ...
                chunk_er, chunk_sigma, surface_heights, ...
                x_edges, y_edges, n_chunks_x, n_chunks_y, eps0, omega);
            cross_s2(pi_idx, rx_idx) = rssi_low;
            cross_s2(pi_idx, rx_idx + nRX) = rssi_high;
            
            [rssi_low, rssi_high] = compute_rssi_bumpy(tx2_pos, rx1_pos, ...
                objects, obj_x_half, obj_y_half, obj_er, obj_sigma, ...
                freq, lambda, G_tx, G_rx, low_power_range, high_power_range, cfg, ...
                chunk_er, chunk_sigma, surface_heights, ...
                x_edges, y_edges, n_chunks_x, n_chunks_y, eps0, omega);
            cross_s1(pi_idx, rx_idx) = rssi_low;
            cross_s1(pi_idx, rx_idx + nRX) = rssi_high;
            
            % --- SAME-ANTENNA: TX1->RX1, TX2->RX2 ---
            [rssi_low, rssi_high] = compute_rssi_bumpy(tx1_pos, rx1_pos, ...
                objects, obj_x_half, obj_y_half, obj_er, obj_sigma, ...
                freq, lambda, G_tx, G_rx, low_power_range, high_power_range, cfg, ...
                chunk_er, chunk_sigma, surface_heights, ...
                x_edges, y_edges, n_chunks_x, n_chunks_y, eps0, omega);
            same_s1(pi_idx, rx_idx) = rssi_low;
            same_s1(pi_idx, rx_idx + nRX) = rssi_high;
            
            [rssi_low, rssi_high] = compute_rssi_bumpy(tx2_pos, rx2_pos, ...
                objects, obj_x_half, obj_y_half, obj_er, obj_sigma, ...
                freq, lambda, G_tx, G_rx, low_power_range, high_power_range, cfg, ...
                chunk_er, chunk_sigma, surface_heights, ...
                x_edges, y_edges, n_chunks_x, n_chunks_y, eps0, omega);
            same_s2(pi_idx, rx_idx) = rssi_low;
            same_s2(pi_idx, rx_idx + nRX) = rssi_high;
        end
        
        if mod(pi_idx, 500) == 0
            fprintf('  Position %d/%d\n', pi_idx, nPositions);
        end
    end
    
    data_cross_s1{ti} = cross_s1;
    data_cross_s2{ti} = cross_s2;
    data_same_s1{ti} = same_s1;
    data_same_s2{ti} = same_s2;
end

fprintf('\nSimulation complete.\n');

%% ====================================================================
%  BUILD FEATURE MATRICES FOR BOTH ARCHITECTURES
%  ====================================================================
fprintf('\nBuilding feature matrices...\n');

% Labels
is_object = false(nPositions, 1);
for pi = 1:nPositions
    y = y_positions(pi);
    for oi = 1:length(cfg.obj_y_centers)
        if abs(y - cfg.obj_y_centers(oi)) <= cfg.obj_y_half
            is_object(pi) = true;
            break;
        end
    end
end

nRows_Total = nPositions * nTerrains;

% --- Build features for both architectures ---
[X_cross, Y_labels] = build_features(data_cross_s1, data_cross_s2, ...
    nPositions, nTerrains, nRX, terrains, is_object, y_positions);
[X_same, ~] = build_features(data_same_s1, data_same_s2, ...
    nPositions, nTerrains, nRX, terrains, is_object, y_positions);

fprintf('Feature matrix: %d samples x %d features\n', size(X_cross, 1), size(X_cross, 2));

%% ====================================================================
%  TRAIN AND EVALUATE MLP ON BOTH
%  ====================================================================
fprintf('\n=== Training MLP Classifiers ===\n');

rng(42);
cv = cvpartition(Y_labels, 'HoldOut', 0.2);
train_idx = training(cv);
test_idx = test(cv);

% --- CRISS-CROSS ---
fprintf('\n--- Criss-Cross Architecture (TX1->RX2, TX2->RX1) ---\n');
X_train_c = X_cross(train_idx, :);
Y_train_c = Y_labels(train_idx);
X_test_c = X_cross(test_idx, :);
Y_test_c = Y_labels(test_idx);

mdl_cross = fitcnet(X_train_c, Y_train_c, ...
    'LayerSizes', [128 64 32], ...
    'Standardize', true, ...
    'IterationLimit', 2000, ...
    'Verbose', 0);
Y_pred_cross = predict(mdl_cross, X_test_c);
acc_cross = sum(Y_pred_cross == Y_test_c) / numel(Y_test_c) * 100;
fprintf('  Test Accuracy: %.2f%%\n', acc_cross);

% --- SAME-ANTENNA ---
fprintf('\n--- Same-Antenna Architecture (TX1->RX1, TX2->RX2) ---\n');
X_train_s = X_same(train_idx, :);
Y_train_s = Y_labels(train_idx);
X_test_s = X_same(test_idx, :);
Y_test_s = Y_labels(test_idx);

mdl_same = fitcnet(X_train_s, Y_train_s, ...
    'LayerSizes', [128 64 32], ...
    'Standardize', true, ...
    'IterationLimit', 2000, ...
    'Verbose', 0);
Y_pred_same = predict(mdl_same, X_test_s);
acc_same = sum(Y_pred_same == Y_test_s) / numel(Y_test_s) * 100;
fprintf('  Test Accuracy: %.2f%%\n', acc_same);

%% ====================================================================
%  ADDITIONAL METRICS
%  ====================================================================

% Per-class accuracy
cats = categories(Y_labels);
nClasses = numel(cats);
per_class_cross = zeros(nClasses, 1);
per_class_same = zeros(nClasses, 1);

for ci = 1:nClasses
    mask = Y_test_c == cats{ci};
    per_class_cross(ci) = sum(Y_pred_cross(mask) == Y_test_c(mask)) / sum(mask) * 100;
    per_class_same(ci) = sum(Y_pred_same(mask) == Y_test_s(mask)) / sum(mask) * 100;
end

% Scan area calculation
% Criss-cross: signal travels between sensors = 180mm horizontal separation
% Same-antenna: signal stays within same sensor = ~0mm horizontal separation
% The ground footprint of the reflected path is wider for criss-cross
separation_cross = abs(sensor2_x - sensor1_x);  % 180 mm
separation_same = 0;  % TX and RX on same board

% Effective scan width per measurement (simplified geometry)
% Reflection point midway: criss-cross covers ±90mm, same covers ±0mm in X
scan_width_cross = separation_cross;  % mm ground coverage in X
scan_width_same = max(rx_offset_x) - min(rx_offset_x);  % just the array spread

fprintf('\n=== RESULTS SUMMARY ===\n');
fprintf('┌─────────────────────────────────────────────────────┐\n');
fprintf('│ Metric               │ Criss-Cross │ Same-Antenna   │\n');
fprintf('├─────────────────────────────────────────────────────┤\n');
fprintf('│ Overall Accuracy     │   %6.2f%%   │   %6.2f%%      │\n', acc_cross, acc_same);
fprintf('│ TX-RX Separation     │   %4d mm   │   %4d mm      │\n', separation_cross, separation_same);
fprintf('│ Ground Scan Width    │   %4d mm   │   %4.0f mm      │\n', scan_width_cross, scan_width_same);
fprintf('└─────────────────────────────────────────────────────┘\n');

fprintf('\nPer-class accuracy:\n');
fprintf('  %-20s  Criss-Cross  Same-Antenna  Diff\n', 'Class');
for ci = 1:nClasses
    diff = per_class_cross(ci) - per_class_same(ci);
    fprintf('  %-20s  %6.2f%%      %6.2f%%     %+.2f%%\n', ...
        char(cats{ci}), per_class_cross(ci), per_class_same(ci), diff);
end

%% ====================================================================
%  FIGURES
%  ====================================================================
fprintf('\nGenerating comparison figures...\n');

% --- 1. Accuracy Bar Chart ---
figure('Position', [50 50 800 500], 'Visible', 'off');

subplot(1,2,1);
bar_data = [acc_cross, acc_same];
b = bar(bar_data, 0.6);
b.FaceColor = 'flat';
b.CData(1,:) = [0.2 0.6 0.9];
b.CData(2,:) = [0.9 0.4 0.2];
set(gca, 'XTickLabel', {'Criss-Cross', 'Same-Antenna'});
ylabel('Accuracy (%)');
title('Overall Classification Accuracy');
ylim([0 100]);
text(1, acc_cross+2, sprintf('%.2f%%', acc_cross), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(2, acc_same+2, sprintf('%.2f%%', acc_same), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
grid on;

subplot(1,2,2);
bar_data_pc = [per_class_cross, per_class_same];
b2 = bar(bar_data_pc, 0.8);
b2(1).FaceColor = [0.2 0.6 0.9];
b2(2).FaceColor = [0.9 0.4 0.2];
set(gca, 'XTickLabel', cats, 'XTickLabelRotation', 45);
ylabel('Accuracy (%)');
title('Per-Class Accuracy');
legend('Criss-Cross', 'Same-Antenna', 'Location', 'southwest');
ylim([0 100]);
grid on;

sgtitle('Architecture Comparison: Criss-Cross vs Same-Antenna');
exportgraphics(gcf, fullfile(output_dir, 'Architecture_Comparison_Accuracy.png'), 'Resolution', 150);
savefig(gcf, fullfile(output_dir, 'Architecture_Comparison_Accuracy.fig'));
close(gcf);

% --- 2. RSSI Spatial Diversity Comparison ---
figure('Position', [50 50 1200 500], 'Visible', 'off');

% Show RSSI variance across RX elements (spatial diversity indicator)
% Use terrain 1 (DrySand) as example
ti_example = 1;
cross_rssi = data_cross_s1{ti_example}(:, 1:nRX);
same_rssi = data_same_s1{ti_example}(:, 1:nRX);

% Variance per position (across 32 RX elements)
var_cross = var(cross_rssi, 0, 2);
var_same = var(same_rssi, 0, 2);

subplot(1,2,1);
plot(y_positions/1000, var_cross, 'b-', 'LineWidth', 1); hold on;
plot(y_positions/1000, var_same, 'r-', 'LineWidth', 1);
xlabel('Distance along track (m)');
ylabel('RSSI Variance across RX elements (dB^2)');
title('Spatial Diversity: RSSI Variance');
legend('Criss-Cross', 'Same-Antenna', 'Location', 'best');
grid on;
% Mark objects
for oi = 1:length(cfg.obj_y_centers)
    xline(cfg.obj_y_centers(oi)/1000, 'k--', 'Alpha', 0.3);
end

subplot(1,2,2);
% Mean absolute difference between adjacent RX elements (gradient)
grad_cross = mean(abs(cross_rssi(:,2:end) - cross_rssi(:,1:end-1)), 2);
grad_same = mean(abs(same_rssi(:,2:end) - same_rssi(:,1:end-1)), 2);
plot(y_positions/1000, grad_cross, 'b-', 'LineWidth', 1); hold on;
plot(y_positions/1000, grad_same, 'r-', 'LineWidth', 1);
xlabel('Distance along track (m)');
ylabel('Mean |ΔRSSI| between adjacent RX (dB)');
title('Spatial Gradient (Object Sensitivity)');
legend('Criss-Cross', 'Same-Antenna', 'Location', 'best');
grid on;
for oi = 1:length(cfg.obj_y_centers)
    xline(cfg.obj_y_centers(oi)/1000, 'k--', 'Alpha', 0.3);
end

sgtitle(sprintf('Spatial Diversity Comparison (%s terrain)', terrains(ti_example).name));
exportgraphics(gcf, fullfile(output_dir, 'Architecture_Comparison_Diversity.png'), 'Resolution', 150);
savefig(gcf, fullfile(output_dir, 'Architecture_Comparison_Diversity.fig'));
close(gcf);

% --- 3. Confusion Matrices Side-by-Side ---
figure('Position', [50 50 1200 500], 'Visible', 'off');

subplot(1,2,1);
cm_cross = confusionmat(Y_test_c, Y_pred_cross);
imagesc(cm_cross);
colorbar;
set(gca, 'XTick', 1:nClasses, 'XTickLabel', cats, 'XTickLabelRotation', 45);
set(gca, 'YTick', 1:nClasses, 'YTickLabel', cats);
xlabel('Predicted'); ylabel('True');
title(sprintf('Criss-Cross (%.2f%%)', acc_cross));
colormap(gca, parula);

subplot(1,2,2);
cm_same = confusionmat(Y_test_s, Y_pred_same);
imagesc(cm_same);
colorbar;
set(gca, 'XTick', 1:nClasses, 'XTickLabel', cats, 'XTickLabelRotation', 45);
set(gca, 'YTick', 1:nClasses, 'YTickLabel', cats);
xlabel('Predicted'); ylabel('True');
title(sprintf('Same-Antenna (%.2f%%)', acc_same));
colormap(gca, parula);

sgtitle('Confusion Matrices: Architecture Comparison');
exportgraphics(gcf, fullfile(output_dir, 'Architecture_Comparison_ConfMat.png'), 'Resolution', 150);
savefig(gcf, fullfile(output_dir, 'Architecture_Comparison_ConfMat.fig'));
close(gcf);

% --- 4. Geometry Diagram ---
figure('Position', [50 50 800 400], 'Visible', 'off');

subplot(1,2,1);
% Criss-cross diagram (side view)
hold on;
% Ground
patch([-200 200 200 -200], [-50 -50 0 0], [0.6 0.4 0.2], 'FaceAlpha', 0.3);
% TX1 and RX2
plot(-90, 95, 'r^', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
plot(90, 95, 'bs', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
% Ray path
plot([-90 0 90], [95 0 95], 'r-', 'LineWidth', 2);
plot([-90 90], [95 95], 'r--', 'LineWidth', 1, 'Color', [1 0.5 0.5]);
% Labels
text(-90, 110, 'TX1', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(90, 110, 'RX2', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(0, -25, sprintf('Scan width: %dmm', separation_cross), 'HorizontalAlignment', 'center');
% Scan width arrow
annotation_x = [0.15 0.42];
plot([-90 90], [-15 -15], 'k-', 'LineWidth', 1.5);
plot(-90, -15, 'k<', 'MarkerFaceColor', 'k');
plot(90, -15, 'k>', 'MarkerFaceColor', 'k');
axis equal; xlim([-200 200]); ylim([-60 130]);
title('Criss-Cross');
xlabel('X (mm)'); ylabel('Z (mm)');
grid on;
hold off;

subplot(1,2,2);
% Same-antenna diagram (side view)
hold on;
patch([-200 200 200 -200], [-50 -50 0 0], [0.6 0.4 0.2], 'FaceAlpha', 0.3);
% TX1 and RX1 (same side)
plot(-90, 95, 'r^', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
plot(-90+33, 95-23, 'bs', 'MarkerSize', 8, 'MarkerFaceColor', 'b');  % offset within array
% Ray path (nearly vertical)
plot([-90 -80 -57], [95 0 72], 'r-', 'LineWidth', 2);
plot([-90 -57], [95 72], 'r--', 'LineWidth', 1, 'Color', [1 0.5 0.5]);
text(-90, 110, 'TX1', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(-57, 85, 'RX1', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
scan_w = max(rx_offset_x) - min(rx_offset_x);
text(-73, -25, sprintf('Scan width: %.0fmm', scan_w), 'HorizontalAlignment', 'center');
plot([-90 -90+scan_w], [-15 -15], 'k-', 'LineWidth', 1.5);
plot(-90, -15, 'k<', 'MarkerFaceColor', 'k');
plot(-90+scan_w, -15, 'k>', 'MarkerFaceColor', 'k');
axis equal; xlim([-200 200]); ylim([-60 130]);
title('Same-Antenna');
xlabel('X (mm)'); ylabel('Z (mm)');
grid on;
hold off;

sgtitle('TX/RX Geometry: Ground Scan Width');
exportgraphics(gcf, fullfile(output_dir, 'Architecture_Comparison_Geometry.png'), 'Resolution', 150);
close(gcf);

%% Save results summary
fid = fopen(fullfile(output_dir, 'Architecture_Comparison_Results.txt'), 'w');
fprintf(fid, '=== ARCHITECTURE COMPARISON RESULTS ===\n');
fprintf(fid, 'Date: %s\n\n', datestr(now));
fprintf(fid, 'Configuration:\n');
fprintf(fid, '  Frequency: %.2f GHz\n', freq/1e9);
fprintf(fid, '  Sensor separation: %d mm\n', separation_cross);
fprintf(fid, '  Array: %dx%d = %d RX\n', nCols, nRows, nRX);
fprintf(fid, '  Track: %d positions, %d terrains\n', nPositions, nTerrains);
fprintf(fid, '  Terrain: bumpy (±%d%% variation, 0-%dmm surface)\n', variation_pct, surface_z_max);
fprintf(fid, '  MLP: [128 64 32], 2000 iterations\n\n');
fprintf(fid, 'RESULTS:\n');
fprintf(fid, '  Criss-Cross Accuracy:  %.2f%%\n', acc_cross);
fprintf(fid, '  Same-Antenna Accuracy: %.2f%%\n', acc_same);
fprintf(fid, '  Improvement:           %+.2f%%\n\n', acc_cross - acc_same);
fprintf(fid, 'Ground Scan Width:\n');
fprintf(fid, '  Criss-Cross: %d mm (TX-RX on different sensors)\n', separation_cross);
fprintf(fid, '  Same-Antenna: %.0f mm (TX-RX on same sensor)\n\n', scan_width_same);
fprintf(fid, 'Per-Class Accuracy:\n');
fprintf(fid, '  %-20s  Criss-Cross  Same-Antenna  Improvement\n', 'Class');
for ci = 1:nClasses
    fprintf(fid, '  %-20s  %6.2f%%      %6.2f%%      %+.2f%%\n', ...
        char(cats{ci}), per_class_cross(ci), per_class_same(ci), ...
        per_class_cross(ci) - per_class_same(ci));
end
fclose(fid);

fprintf('\n=== All outputs saved to %s ===\n', output_dir);
fprintf('  Architecture_Comparison_Accuracy.png\n');
fprintf('  Architecture_Comparison_Diversity.png\n');
fprintf('  Architecture_Comparison_ConfMat.png\n');
fprintf('  Architecture_Comparison_Geometry.png\n');
fprintf('  Architecture_Comparison_Results.txt\n');

%% ====================================================================
%  LOCAL FUNCTION: Build feature matrix
%  ====================================================================
function [X, Y_labels] = build_features(data_s1, data_s2, nPositions, nTerrains, nRX, terrains, is_object, y_positions)
    nRows_Total = nPositions * nTerrains;
    nFeatures = 155;
    X = zeros(nRows_Total, nFeatures);
    Y_labels = cell(nRows_Total, 1);
    
    row = 0;
    for ti = 1:nTerrains
        s1_low = data_s1{ti}(:, 1:nRX);
        s1_high = data_s1{ti}(:, nRX+1:end);
        s2_low = data_s2{ti}(:, 1:nRX);
        s2_high = data_s2{ti}(:, nRX+1:end);
        
        for pi = 1:nPositions
            row = row + 1;
            
            % 128 RSSI features
            X(row, 1:32) = s1_low(pi, :);
            X(row, 33:64) = s1_high(pi, :);
            X(row, 65:96) = s2_low(pi, :);
            X(row, 97:128) = s2_high(pi, :);
            
            % Sensor 1 stats
            a1 = s1_low(pi, :);
            q1 = quantile(a1, [0.25, 0.75]);
            X(row, 129) = mean(a1);
            X(row, 130) = std(a1);
            X(row, 131) = min(a1);
            X(row, 132) = max(a1);
            X(row, 133) = q1(2) - q1(1);
            
            % Sensor 2 stats
            a2 = s2_low(pi, :);
            q2 = quantile(a2, [0.25, 0.75]);
            X(row, 134) = mean(a2);
            X(row, 135) = std(a2);
            X(row, 136) = min(a2);
            X(row, 137) = max(a2);
            X(row, 138) = q2(2) - q2(1);
            
            % Between-sensor features
            X(row, 139) = mean(a1) - mean(a2);
            X(row, 140) = std(a1) - std(a2);
            r = corrcoef(a1, a2);
            X(row, 141) = r(1,2);
            
            % Additional features
            a1h = s1_high(pi, :);
            a2h = s2_high(pi, :);
            X(row, 142) = std(a1h);
            X(row, 143) = std(a2h);
            X(row, 144) = max(a1) - min(a1);
            X(row, 145) = max(a2) - min(a2);
            X(row, 146) = max(a1h) - min(a1h);
            X(row, 147) = max(a2h) - min(a2h);
            X(row, 148) = std(a1) / (std(a2) + 1e-10);
            X(row, 149) = mean(a1h) - mean(a2h);
            a_all = [a1, a2];
            X(row, 150) = std(a_all);
            X(row, 151) = max(a_all) - min(a_all);
            q_all = quantile(a_all, [0.25, 0.75]);
            X(row, 152) = q_all(2) - q_all(1);
            X(row, 153) = kurtosis(a1);
            X(row, 154) = kurtosis(a2);
            X(row, 155) = skewness(a1) - skewness(a2);
            
            % Label
            if is_object(pi)
                Y_labels{row} = sprintf('%s_Object', terrains(ti).name);
            else
                Y_labels{row} = sprintf('%s_NoObject', terrains(ti).name);
            end
        end
    end
    Y_labels = categorical(Y_labels);
end

%% ====================================================================
%  LOCAL FUNCTION: compute_rssi_bumpy (same as TrackSimulation_Bumpy)
%  ====================================================================
function [rssi_low, rssi_high] = compute_rssi_bumpy(tx_pos, rx_pos, ...
    objects, obj_x_half, obj_y_half, obj_er, obj_sigma, ...
    freq, lambda, G_tx, G_rx, low_pwr, high_pwr, cfg, ...
    chunk_er, chunk_sigma, surface_heights, ...
    x_edges, y_edges, n_chunks_x, n_chunks_y, eps0, omega)
    
    tx_z = tx_pos(3);
    rx_z = rx_pos(3);
    dx = rx_pos(1) - tx_pos(1);
    dy = rx_pos(2) - tx_pos(2);
    d_horiz = sqrt(dx^2 + dy^2);
    
    total_z = tx_z + rx_z;
    frac = tx_z / total_z;
    ref_x = tx_pos(1) + frac * dx;
    ref_y = tx_pos(2) + frac * dy;
    
    % Find chunk
    ix = find(ref_x >= x_edges(1:end-1) & ref_x < x_edges(2:end), 1);
    iy = find(ref_y >= y_edges(1:end-1) & ref_y < y_edges(2:end), 1);
    if isempty(ix), ix = 1; end
    if isempty(iy), iy = 1; end
    ix = max(1, min(n_chunks_x, ix));
    iy = max(1, min(n_chunks_y, iy));
    
    z_surface = surface_heights(iy, ix);
    
    % Check void
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
        z_surface = 0;
    else
        local_er = chunk_er(iy, ix);
        local_sigma = chunk_sigma(iy, ix);
        eps_ground = local_er - 1j*local_sigma/(omega*eps0);
    end
    
    eff_tx_z = tx_z - z_surface;
    eff_rx_z = rx_z - z_surface;
    
    d_direct = norm(tx_pos - rx_pos) / 1000;
    
    eff_total_z = eff_tx_z + eff_rx_z;
    eff_frac = eff_tx_z / eff_total_z;
    
    d_tx_ref = sqrt(eff_tx_z^2 + (eff_frac*d_horiz)^2) / 1000;
    d_ref_rx = sqrt(eff_rx_z^2 + ((1-eff_frac)*d_horiz)^2) / 1000;
    d_reflected = d_tx_ref + d_ref_rx;
    
    theta_i = atan2(eff_frac*d_horiz, eff_tx_z);
    
    cos_t = cos(theta_i);
    sin_t = sin(theta_i);
    sqrt_term = sqrt(eps_ground - sin_t^2);
    
    Gamma_TE = (cos_t - sqrt_term) / (cos_t + sqrt_term);
    Gamma_TM = (eps_ground*cos_t - sqrt_term) / (eps_ground*cos_t + sqrt_term);
    Gamma = (Gamma_TE + Gamma_TM) / 2;
    Gamma_mag = abs(Gamma);
    
    FSPL_direct = 20*log10(4*pi*d_direct/lambda);
    FSPL_reflected = 20*log10(4*pi*d_reflected/lambda);
    reflection_loss = -20*log10(Gamma_mag + 1e-10);
    
    pattern_loss_direct = cfg.pattern_loss_direct;
    pattern_loss_reflected = cfg.pattern_loss_reflected;
    
    P_direct_lin = 10^((-FSPL_direct + G_tx + G_rx - pattern_loss_direct)/10);
    P_reflected_lin = 10^((-FSPL_reflected - reflection_loss + G_tx + G_rx - pattern_loss_reflected)/10);
    
    phase_diff = 2*pi*(d_reflected - d_direct)/lambda;
    P_total_lin = P_direct_lin + P_reflected_lin * exp(1j*phase_diff);
    P_total_dB = 10*log10(abs(P_total_lin) + 1e-20);
    
    noise_std = cfg.noise_std;
    
    P_tx_low = low_pwr(1) + (low_pwr(2)-low_pwr(1))*rand();
    rssi_low = P_tx_low + P_total_dB + noise_std*randn();
    
    P_tx_high = high_pwr(1) + (high_pwr(2)-high_pwr(1))*rand();
    rssi_high = P_tx_high + P_total_dB + noise_std*randn();
end
