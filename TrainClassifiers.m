%% TrainClassifiers.m - Train ML models on RSSI data
% 6 classes: {DrySand, GrassySoil, Rocks} x {Object, NoObject}
% Features: 128 RSSI + 13 statistical features = 141 total
% Models: SVM, MLP, Ensemble (Boosted Trees), Bagged Trees, KNN

clear; close all; clc;

%% Load shared configuration
SimConfig;

%% Parameters
nRX = cfg.nCols * cfg.nRows;  % 32
y_positions = cfg.track_y_start:cfg.track_y_step:cfg.track_y_end;
nPositions = length(y_positions);
nTerrains = length(cfg.terrains);

%% Determine object/no-object labels for each Y position
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
fprintf('Positions over object: %d / %d\n', sum(is_object), nPositions);

%% Build feature matrix and labels
% Each row: [S1_Low(1:32), S1_High(1:32), S2_Low(1:32), S2_High(1:32), ...
%            S1_mean, S1_std, S1_min, S1_max, S1_iqr, ...
%            S2_mean, S2_std, S2_min, S2_max, S2_iqr, ...
%            diff_mean, diff_std, xcorr]

nFeatures_RSSI = 128;  % 32*4
nFeatures_Stats = 27;  % 13 original + 14 additional
nFeatures_Total = nFeatures_RSSI + nFeatures_Stats;
nRows_Total = nPositions * nTerrains;

X = zeros(nRows_Total, nFeatures_Total);
Y_labels = cell(nRows_Total, 1);

row = 0;
for ti = 1:nTerrains
    terrain_name = cfg.terrains(ti).name;
    fprintf('Loading %s data...\n', terrain_name);
    
    % Load CSVs
    s1_file = fullfile(cfg.output_dir, sprintf('RSSI_Sensor1_%s.csv', terrain_name));
    s2_file = fullfile(cfg.output_dir, sprintf('RSSI_Sensor2_%s.csv', terrain_name));
    
    s1_raw = readmatrix(s1_file);  % [Y_mm, 32_low, 32_high]
    s2_raw = readmatrix(s2_file);
    
    % Extract RSSI columns (skip Y_mm column)
    s1_low = s1_raw(:, 2:nRX+1);          % 32 columns
    s1_high = s1_raw(:, nRX+2:2*nRX+1);   % 32 columns
    s2_low = s2_raw(:, 2:nRX+1);          % 32 columns
    s2_high = s2_raw(:, nRX+2:2*nRX+1);   % 32 columns
    
    for pi = 1:nPositions
        row = row + 1;
        
        % 128 RSSI features
        X(row, 1:32) = s1_low(pi, :);
        X(row, 33:64) = s1_high(pi, :);
        X(row, 65:96) = s2_low(pi, :);
        X(row, 97:128) = s2_high(pi, :);
        
        % Sensor 1 stats (computed from low-power 32 antennas)
        a1 = s1_low(pi, :);
        q1 = quantile(a1, [0.25, 0.75]);
        X(row, 129) = mean(a1);
        X(row, 130) = std(a1);
        X(row, 131) = min(a1);
        X(row, 132) = max(a1);
        X(row, 133) = q1(2) - q1(1);  % IQR
        
        % Sensor 2 stats (computed from low-power 32 antennas)
        a2 = s2_low(pi, :);
        q2 = quantile(a2, [0.25, 0.75]);
        X(row, 134) = mean(a2);
        X(row, 135) = std(a2);
        X(row, 136) = min(a2);
        X(row, 137) = max(a2);
        X(row, 138) = q2(2) - q2(1);  % IQR
        
        % Between-sensor features
        X(row, 139) = mean(a1) - mean(a2);       % diff_mean
        X(row, 140) = std(a1) - std(a2);         % diff_std
        r = corrcoef(a1, a2);
        X(row, 141) = r(1,2);                    % cross-correlation
        
        % Additional features for object detection (142-155)
        % High-power stats for both sensors
        a1h = s1_high(pi, :);
        a2h = s2_high(pi, :);
        X(row, 142) = std(a1h);                  % S1_high_std
        X(row, 143) = std(a2h);                  % S2_high_std
        X(row, 144) = max(a1) - min(a1);         % S1_range
        X(row, 145) = max(a2) - min(a2);         % S2_range
        X(row, 146) = max(a1h) - min(a1h);       % S1_high_range
        X(row, 147) = max(a2h) - min(a2h);       % S2_high_range
        % Ratio features (variance ratio between sensors)
        X(row, 148) = std(a1) / (std(a2) + 1e-10);
        X(row, 149) = mean(a1h) - mean(a2h);     % diff_mean_high
        % Combined sensor stats
        a_all = [a1, a2];
        X(row, 150) = std(a_all);                % combined_std
        X(row, 151) = max(a_all) - min(a_all);   % combined_range
        q_all = quantile(a_all, [0.25, 0.75]);
        X(row, 152) = q_all(2) - q_all(1);       % combined_iqr
        % Kurtosis and skewness (sensitive to distribution shape change over objects)
        X(row, 153) = kurtosis(a1);
        X(row, 154) = kurtosis(a2);
        X(row, 155) = skewness(a1) - skewness(a2);
        
        % Label: Terrain + Object/NoObject
        if is_object(pi)
            Y_labels{row} = sprintf('%s_Object', terrain_name);
        else
            Y_labels{row} = sprintf('%s_NoObject', terrain_name);
        end
    end
end

Y_labels = categorical(Y_labels);
fprintf('\nDataset: %d samples x %d features\n', size(X,1), size(X,2));
fprintf('Classes:\n');
cats = categories(Y_labels);
for ci = 1:length(cats)
    fprintf('  %s: %d samples\n', cats{ci}, sum(Y_labels == cats{ci}));
end

%% Save merged training CSV
fprintf('\nSaving merged training data...\n');

% Feature names
feat_names = cell(1, nFeatures_Total);
for i = 1:32, feat_names{i} = sprintf('S1_RX%d_Low', i); end
for i = 1:32, feat_names{32+i} = sprintf('S1_RX%d_High', i); end
for i = 1:32, feat_names{64+i} = sprintf('S2_RX%d_Low', i); end
for i = 1:32, feat_names{96+i} = sprintf('S2_RX%d_High', i); end
feat_names{129} = 'S1_mean'; feat_names{130} = 'S1_std';
feat_names{131} = 'S1_min'; feat_names{132} = 'S1_max'; feat_names{133} = 'S1_iqr';
feat_names{134} = 'S2_mean'; feat_names{135} = 'S2_std';
feat_names{136} = 'S2_min'; feat_names{137} = 'S2_max'; feat_names{138} = 'S2_iqr';
feat_names{139} = 'diff_mean'; feat_names{140} = 'diff_std'; feat_names{141} = 'xcorr';
feat_names{142} = 'S1_high_std'; feat_names{143} = 'S2_high_std';
feat_names{144} = 'S1_range'; feat_names{145} = 'S2_range';
feat_names{146} = 'S1_high_range'; feat_names{147} = 'S2_high_range';
feat_names{148} = 'std_ratio'; feat_names{149} = 'diff_mean_high';
feat_names{150} = 'combined_std'; feat_names{151} = 'combined_range';
feat_names{152} = 'combined_iqr';
feat_names{153} = 'S1_kurtosis'; feat_names{154} = 'S2_kurtosis';
feat_names{155} = 'skew_diff';

T = array2table(X, 'VariableNames', feat_names);
T.Label = Y_labels;
writetable(T, fullfile(cfg.output_dir, 'TrainingData.csv'));
fprintf('Saved: %s\n', fullfile(cfg.output_dir, 'TrainingData.csv'));

%% Train/Test Split (80/20 stratified)
rng(42);  % reproducibility
cv = cvpartition(Y_labels, 'HoldOut', 0.2);
X_train = X(training(cv), :);
Y_train = Y_labels(training(cv));
X_test = X(test(cv), :);
Y_test = Y_labels(test(cv));

fprintf('\nTrain: %d samples, Test: %d samples\n', size(X_train,1), size(X_test,1));

%% Oversample minority classes (Object classes) to balance training set
fprintf('\nOversampling minority classes...\n');
train_cats = categories(Y_train);
counts = countcats(Y_train);
max_count = max(counts);

X_train_bal = X_train;
Y_train_bal = Y_train;

for ci = 1:length(train_cats)
    class_mask = Y_train == train_cats{ci};
    class_X = X_train(class_mask, :);
    class_count = size(class_X, 1);
    
    if class_count < max_count
        % Oversample with small noise perturbation
        n_needed = max_count - class_count;
        oversample_idx = randi(class_count, n_needed, 1);
        X_new = class_X(oversample_idx, :) + 0.02 * randn(n_needed, size(X_train, 2));
        Y_new = repmat(categorical(train_cats(ci)), n_needed, 1);
        X_train_bal = [X_train_bal; X_new];
        Y_train_bal = [Y_train_bal; Y_new];
    end
end
fprintf('Balanced training set: %d samples (from %d)\n', size(X_train_bal,1), size(X_train,1));

%% Compute class weights (inverse frequency) for cost-sensitive learning
class_counts_train = countcats(Y_train);
class_weights = max(class_counts_train) ./ class_counts_train;
cost_matrix = ones(length(train_cats)) - eye(length(train_cats));
for ci = 1:length(train_cats)
    cost_matrix(:, ci) = cost_matrix(:, ci) * class_weights(ci);
end

%% Train classifiers
results = struct();

% --- 1. SVM (multiclass via ECOC, with cost) ---
fprintf('\n--- Training SVM (ECOC, Gaussian, cost-sensitive) ---\n');
tic;
mdl_svm = fitcecoc(X_train_bal, Y_train_bal, ...
    'Learners', templateSVM('KernelFunction', 'gaussian', 'KernelScale', 'auto', ...
        'Standardize', true, 'BoxConstraint', 10), ...
    'Coding', 'onevsone');
t_svm = toc;
Y_pred_svm = predict(mdl_svm, X_test);
results(1).name = 'SVM (Gaussian)';
results(1).time = t_svm;
results(1).predictions = Y_pred_svm;
fprintf('  Done (%.1f s)\n', t_svm);

% --- 2. MLP (Neural Network, larger + longer) ---
fprintf('\n--- Training MLP ---\n');
tic;
mdl_mlp = fitcnet(X_train_bal, Y_train_bal, ...
    'LayerSizes', [256 128 64], ...
    'Standardize', true, ...
    'IterationLimit', 2000, ...
    'GradientTolerance', 1e-7);
t_mlp = toc;
Y_pred_mlp = predict(mdl_mlp, X_test);
results(2).name = 'MLP [256-128-64]';
results(2).time = t_mlp;
results(2).predictions = Y_pred_mlp;
fprintf('  Done (%.1f s)\n', t_mlp);

% --- 3. Ensemble (AdaBoostM2, more cycles) ---
fprintf('\n--- Training Ensemble (AdaBoostM2) ---\n');
tic;
mdl_ens = fitcensemble(X_train_bal, Y_train_bal, ...
    'Method', 'AdaBoostM2', ...
    'NumLearningCycles', 300, ...
    'Learners', templateTree('MaxNumSplits', 100), ...
    'LearnRate', 0.1);
t_ens = toc;
Y_pred_ens = predict(mdl_ens, X_test);
results(3).name = 'Ensemble (Boosted)';
results(3).time = t_ens;
results(3).predictions = Y_pred_ens;
fprintf('  Done (%.1f s)\n', t_ens);

% --- 4. Bagged Trees (more trees, deeper) ---
fprintf('\n--- Training Bagged Trees ---\n');
tic;
mdl_bag = fitcensemble(X_train_bal, Y_train_bal, ...
    'Method', 'Bag', ...
    'NumLearningCycles', 500, ...
    'Learners', templateTree('MaxNumSplits', 300, 'MinLeafSize', 1));
t_bag = toc;
Y_pred_bag = predict(mdl_bag, X_test);
results(4).name = 'Bagged Trees';
results(4).time = t_bag;
results(4).predictions = Y_pred_bag;
fprintf('  Done (%.1f s)\n', t_bag);

% --- 5. KNN (tuned k, weighted) ---
fprintf('\n--- Training KNN ---\n');
tic;
mdl_knn = fitcknn(X_train_bal, Y_train_bal, ...
    'NumNeighbors', 7, ...
    'Standardize', true, ...
    'Distance', 'euclidean', ...
    'DistanceWeight', 'squaredinverse');
t_knn = toc;
Y_pred_knn = predict(mdl_knn, X_test);
results(5).name = 'KNN (k=7, weighted)';
results(5).time = t_knn;
results(5).predictions = Y_pred_knn;
fprintf('  Done (%.1f s)\n', t_knn);

% --- 6. Two-Stage: Terrain + Object Detection ---
fprintf('\n--- Training Two-Stage (Terrain + Object) ---\n');
tic;
% Stage 1: Terrain classification (3 classes)
train_labels_str = cellstr(Y_train_bal);
test_labels_str = cellstr(Y_test);
terrain_train = regexprep(train_labels_str, '_(Object|NoObject)$', '');
terrain_test = regexprep(test_labels_str, '_(Object|NoObject)$', '');
mdl_terrain = fitcensemble(X_train_bal, terrain_train, ...
    'Method', 'Bag', 'NumLearningCycles', 300, ...
    'Learners', templateTree('MaxNumSplits', 200, 'MinLeafSize', 1));

% Stage 2: Binary object detection using RUSBoost on ORIGINAL (imbalanced) data
obj_train = double(endsWith(cellstr(Y_train), '_Object'));
mdl_object = fitcensemble(X_train, categorical(obj_train), ...
    'Method', 'RUSBoost', 'NumLearningCycles', 500, ...
    'Learners', templateTree('MaxNumSplits', 50, 'MinLeafSize', 1), ...
    'LearnRate', 0.1);

% Combine predictions
pred_terrain = cellstr(predict(mdl_terrain, X_test));
pred_obj_cat = predict(mdl_object, X_test);
combined_labels = cell(size(X_test, 1), 1);
for si = 1:size(X_test, 1)
    if pred_obj_cat(si) == '1'
        combined_labels{si} = [pred_terrain{si} '_Object'];
    else
        combined_labels{si} = [pred_terrain{si} '_NoObject'];
    end
end
Y_pred_2stage = categorical(combined_labels, categories(Y_test));
t_2stage = toc;
results(6).name = 'Two-Stage';
results(6).time = t_2stage;
results(6).predictions = Y_pred_2stage;
fprintf('  Done (%.1f s)\n', t_2stage);

% --- 7. RUSBoost (handles imbalance natively) ---
fprintf('\n--- Training RUSBoost ---\n');
tic;
mdl_rus = fitcensemble(X_train, Y_train, ...
    'Method', 'RUSBoost', ...
    'NumLearningCycles', 500, ...
    'Learners', templateTree('MaxNumSplits', 100, 'MinLeafSize', 1), ...
    'LearnRate', 0.1);
t_rus = toc;
Y_pred_rus = predict(mdl_rus, X_test);
results(7).name = 'RUSBoost';
results(7).time = t_rus;
results(7).predictions = Y_pred_rus;
fprintf('  Done (%.1f s)\n', t_rus);

%% Compute metrics: Accuracy, F1 (macro), Precision, Recall per model
fprintf('\n========================================\n');
fprintf('           CLASSIFICATION RESULTS\n');
fprintf('========================================\n');
fprintf('%-22s %8s %8s %8s %8s %7s\n', 'Model', 'Acc%', 'F1', 'Prec', 'Recall', 'Time');
fprintf('%-22s %8s %8s %8s %8s %7s\n', '-----', '----', '--', '----', '------', '----');

for i = 1:7
    pred = results(i).predictions;
    acc = sum(pred == Y_test) / numel(Y_test) * 100;
    [f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
    results(i).accuracy = acc;
    results(i).f1 = f1;
    results(i).precision = prec;
    results(i).recall = rec;
    fprintf('%-22s %7.2f%% %7.4f %7.4f %7.4f %6.1fs\n', ...
        results(i).name, acc, f1, prec, rec, results(i).time);
end
fprintf('========================================\n');

%% Per-class F1 scores for best model
[~, best_idx] = max([results.f1]);
fprintf('\n--- Per-Class Metrics (Best F1: %s) ---\n', results(best_idx).name);
fprintf('%-25s %8s %8s %8s %8s\n', 'Class', 'F1', 'Prec', 'Recall', 'Support');
fprintf('%-25s %8s %8s %8s %8s\n', '-----', '--', '----', '------', '-------');
best_pred = results(best_idx).predictions;
for ci = 1:length(train_cats)
    tp = sum(best_pred == train_cats{ci} & Y_test == train_cats{ci});
    fp = sum(best_pred == train_cats{ci} & Y_test ~= train_cats{ci});
    fn = sum(best_pred ~= train_cats{ci} & Y_test == train_cats{ci});
    p = tp / (tp + fp + 1e-10);
    r = tp / (tp + fn + 1e-10);
    f = 2*p*r / (p + r + 1e-10);
    support = sum(Y_test == train_cats{ci});
    fprintf('%-25s %7.4f %7.4f %7.4f %8d\n', train_cats{ci}, f, p, r, support);
end

%% Confusion matrices
figure('Name', 'Confusion Matrices', 'Position', [50 50 1800 900], 'Visible', 'off');
for i = 1:7
    subplot(2,4,i);
    confusionchart(Y_test, results(i).predictions);
    title(sprintf('%s\nAcc=%.1f%% F1=%.3f', results(i).name, results(i).accuracy, results(i).f1));
end
sgtitle('Classification Results - Confusion Matrices');
savefig(gcf, fullfile(cfg.output_dir, 'ConfusionMatrices.fig'));
exportgraphics(gcf, fullfile(cfg.output_dir, 'ConfusionMatrices.png'), 'Resolution', 150);
close(gcf);

%% Accuracy + F1 comparison bar chart
figure('Name', 'Metrics Comparison', 'Position', [50 50 1000 400], 'Visible', 'off');
model_names = {results.name};
accuracies = [results.accuracy];
f1_scores = [results.f1];
bar_data = [accuracies'/100, f1_scores'];
b = bar(bar_data);
b(1).FaceColor = [0.2 0.4 0.8]; b(2).FaceColor = [0.8 0.3 0.2];
set(gca, 'XTickLabel', model_names, 'XTickLabelRotation', 20);
ylabel('Score');
title('Classifier Comparison: Accuracy & Macro F1');
legend('Accuracy', 'F1 Score', 'Location', 'best');
ylim([0 1.1]);
grid on;
for i = 1:7
    text(i-0.15, accuracies(i)/100+0.02, sprintf('%.1f%%', accuracies(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
    text(i+0.15, f1_scores(i)+0.02, sprintf('%.3f', f1_scores(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
end
savefig(gcf, fullfile(cfg.output_dir, 'MetricsComparison.fig'));
exportgraphics(gcf, fullfile(cfg.output_dir, 'MetricsComparison.png'), 'Resolution', 150);
close(gcf);

%% Save models
save(fullfile(cfg.output_dir, 'TrainedModels.mat'), 'results', 'mdl_svm', 'mdl_mlp', ...
    'mdl_ens', 'mdl_bag', 'mdl_knn', 'mdl_rus', 'feat_names', 'train_cats');
fprintf('\nModels saved to: %s\n', fullfile(cfg.output_dir, 'TrainedModels.mat'));
fprintf('\nDone.\n');

%% ============ LOCAL FUNCTIONS ============

function [f1_macro, prec_macro, rec_macro] = compute_macro_f1(y_true, y_pred, class_names)
    % Compute macro-averaged F1, precision, recall
    n_classes = length(class_names);
    f1s = zeros(n_classes, 1);
    precs = zeros(n_classes, 1);
    recs = zeros(n_classes, 1);
    
    for ci = 1:n_classes
        tp = sum(y_pred == class_names{ci} & y_true == class_names{ci});
        fp = sum(y_pred == class_names{ci} & y_true ~= class_names{ci});
        fn = sum(y_pred ~= class_names{ci} & y_true == class_names{ci});
        
        precs(ci) = tp / (tp + fp + 1e-10);
        recs(ci) = tp / (tp + fn + 1e-10);
        f1s(ci) = 2 * precs(ci) * recs(ci) / (precs(ci) + recs(ci) + 1e-10);
    end
    
    f1_macro = mean(f1s);
    prec_macro = mean(precs);
    rec_macro = mean(recs);
end
