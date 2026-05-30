%% 30_review_ro2_dataset.m - Dataset visualization and quality checks
% Creates plots to verify RSSI distributions and class balance.

fprintf('=== RO2 Dataset Review ===\n');

% Setup
if ~exist('ro2_root','var'), ro2_root=pwd; addpath('config'); end
ro2_config;

%% Load dataset
data_file = fullfile(ro2_root, cfg.path_data_raw, 'ro2_rssi_dataset.mat');
if ~exist(data_file, 'file')
    error('Dataset not found. Run 20_simulate_ro2_rssi_dataset.m first.');
end
load(data_file, 'rssi_data', 'metadata', 'feature_names');
fprintf('Loaded: %d samples × %d features\n', size(rssi_data, 1), size(rssi_data, 2));

fig_dir = fullfile(ro2_root, cfg.path_figures_dataset);

%% 1. Class balance bar chart
figure('Position', [50 50 900 400], 'Visible', 'off');
class_counts = groupcounts(metadata, 'Label');
bar(categorical(class_counts.Label, cfg.all_labels), class_counts.GroupCount);
xlabel('Density Class');
ylabel('Sample Count');
title('RO2 Dataset: Class Balance');
grid on;
set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(fig_dir, 'class_balance.fig'));
exportgraphics(gcf, fullfile(fig_dir, 'class_balance.png'), 'Resolution', 150);
close(gcf);

%% 2. RSSI distribution by class (boxplot - low power)
figure('Position', [50 50 1200 500], 'Visible', 'off');
% Mean RSSI across low-power RX channels
mean_rssi_low = mean(rssi_data(:, 1:cfg.nRX), 2);
boxchart(categorical(metadata.Label, cfg.all_labels), mean_rssi_low);
xlabel('Density Class');
ylabel('Mean RSSI (dBm) - Low Power');
title('RO2: RSSI Distribution by Class (Low Power, Averaged over 16 RX)');
grid on;
set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(fig_dir, 'rssi_by_class_low.fig'));
exportgraphics(gcf, fullfile(fig_dir, 'rssi_by_class_low.png'), 'Resolution', 150);
close(gcf);

%% 3. RSSI distribution by class (boxplot - high power)
figure('Position', [50 50 1200 500], 'Visible', 'off');
mean_rssi_high = mean(rssi_data(:, cfg.nRX+1:end), 2);
boxchart(categorical(metadata.Label, cfg.all_labels), mean_rssi_high);
xlabel('Density Class');
ylabel('Mean RSSI (dBm) - High Power');
title('RO2: RSSI Distribution by Class (High Power, Averaged over 16 RX)');
grid on;
set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(fig_dir, 'rssi_by_class_high.fig'));
exportgraphics(gcf, fullfile(fig_dir, 'rssi_by_class_high.png'), 'Resolution', 150);
close(gcf);

%% 4. RSSI by material group
figure('Position', [50 50 800 400], 'Visible', 'off');
mean_rssi_all = mean(rssi_data, 2);
boxchart(categorical(metadata.MaterialGroup), mean_rssi_all);
xlabel('Material Group');
ylabel('Mean RSSI (dBm)');
title('RO2: RSSI Distribution by Material Group');
grid on;
set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(fig_dir, 'rssi_by_material_group.fig'));
exportgraphics(gcf, fullfile(fig_dir, 'rssi_by_material_group.png'), 'Resolution', 150);
close(gcf);

%% 5. Representative RSSI response (all 32 features for first sample of each class)
figure('Position', [50 50 1400 600], 'Visible', 'off');
hold on;
colors = lines(cfg.n_classes);
legend_entries = cell(cfg.n_classes, 1);
for ci = 1:cfg.n_classes
    idx = find(metadata.ClassIdx == ci, 1, 'first');
    plot(1:size(rssi_data, 2), rssi_data(idx, :), '-o', ...
        'Color', colors(ci,:), 'MarkerSize', 3, 'LineWidth', 1.2);
    legend_entries{ci} = cfg.all_labels{ci};
end
hold off;
xlabel('Feature Index (RX channel)');
ylabel('RSSI (dBm)');
title('RO2: Representative RSSI Response per Class');
legend(legend_entries, 'Location', 'eastoutside', 'FontSize', 7);
grid on;
xline(cfg.nRX + 0.5, 'k--', 'Low|High', 'LineWidth', 1.5);
set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(fig_dir, 'rssi_response_representative.fig'));
exportgraphics(gcf, fullfile(fig_dir, 'rssi_response_representative.png'), 'Resolution', 150);
close(gcf);

%% 6. Feature correlation heatmap
figure('Position', [50 50 700 600], 'Visible', 'off');
R = corrcoef(rssi_data);
imagesc(R);
colorbar;
colormap(jet);
xlabel('Feature Index');
ylabel('Feature Index');
title('RO2: Feature Correlation Matrix (32 RSSI channels)');
axis equal tight;
set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(fig_dir, 'feature_correlation.fig'));
exportgraphics(gcf, fullfile(fig_dir, 'feature_correlation.png'), 'Resolution', 150);
close(gcf);

%% Print summary statistics
fprintf('\n--- Dataset Summary ---\n');
fprintf('Samples: %d\n', size(rssi_data, 1));
fprintf('Features: %d\n', size(rssi_data, 2));
fprintf('Classes: %d\n', cfg.n_classes);
fprintf('RSSI range: [%.2f, %.2f] dBm\n', min(rssi_data(:)), max(rssi_data(:)));
fprintf('RSSI mean: %.2f dBm, std: %.2f dB\n', mean(rssi_data(:)), std(rssi_data(:)));
fprintf('\nPer-class mean RSSI:\n');
for ci = 1:cfg.n_classes
    mask = metadata.ClassIdx == ci;
    fprintf('  %s: %.2f dBm\n', cfg.all_labels{ci}, mean(rssi_data(mask, :), 'all'));
end

fprintf('\nFigures saved to: %s\n', fig_dir);
fprintf('=== Dataset Review Complete ===\n');
