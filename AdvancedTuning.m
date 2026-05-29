%% AdvancedTuning.m - Exhaustive search for best F1 score
% Tries multiple strategies: feature subsets, model hyperparams, ensembles
% Uses the existing simulation data from TrackSimulation output

clear; clc;
cd(fileparts(mfilename('fullpath')));
SimConfig;  % loads cfg into workspace

%% Load data and build features (same as TrainClassifiers)
fprintf('=== Advanced Tuning: Exhaustive F1 Optimization ===\n\n');

% Load CSV data
terrain_names = {cfg.terrains.name};
nTerrains = length(terrain_names);
nPositions = length(cfg.track_y_start:cfg.track_y_step:cfg.track_y_end);

% Determine object positions
positions = cfg.track_y_start:cfg.track_y_step:cfg.track_y_end;
is_object = false(1, nPositions);
for oi = 1:length(cfg.obj_y_centers)
    oc = cfg.obj_y_centers(oi);
    is_object = is_object | (abs(positions - oc) <= cfg.obj_y_half);
end
fprintf('Positions over object: %d / %d\n', sum(is_object), nPositions);

% Build full feature matrix (155 features)
nFeatures = 155;
nRows = nPositions * nTerrains;
X = zeros(nRows, nFeatures);
Y_labels = cell(nRows, 1);

row = 0;
for ti = 1:nTerrains
    terrain_name = terrain_names{ti};
    s1_file = fullfile(cfg.output_dir, sprintf('RSSI_Sensor1_%s.csv', terrain_name));
    s2_file = fullfile(cfg.output_dir, sprintf('RSSI_Sensor2_%s.csv', terrain_name));
    s1_raw = readmatrix(s1_file);
    s2_raw = readmatrix(s2_file);
    
    s1_low  = s1_raw(:, 2:33);
    s1_high = s1_raw(:, 34:65);
    s2_low  = s2_raw(:, 2:33);
    s2_high = s2_raw(:, 34:65);
    
    for pi = 1:nPositions
        row = row + 1;
        % Raw RSSI (128 features)
        X(row, 1:32)   = s1_low(pi, :);
        X(row, 33:64)  = s1_high(pi, :);
        X(row, 65:96)  = s2_low(pi, :);
        X(row, 97:128) = s2_high(pi, :);
        
        % Stats features
        a1 = s1_low(pi, :);
        q1 = quantile(a1, [0.25, 0.75]);
        X(row, 129) = mean(a1); X(row, 130) = std(a1);
        X(row, 131) = min(a1);  X(row, 132) = max(a1);
        X(row, 133) = q1(2) - q1(1);
        
        a2 = s2_low(pi, :);
        q2 = quantile(a2, [0.25, 0.75]);
        X(row, 134) = mean(a2); X(row, 135) = std(a2);
        X(row, 136) = min(a2);  X(row, 137) = max(a2);
        X(row, 138) = q2(2) - q2(1);
        
        X(row, 139) = mean(a1) - mean(a2);
        X(row, 140) = std(a1) - std(a2);
        r = corrcoef(a1, a2);
        X(row, 141) = r(1,2);
        
        a1h = s1_high(pi, :);
        a2h = s2_high(pi, :);
        X(row, 142) = std(a1h);  X(row, 143) = std(a2h);
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
        
        if is_object(pi)
            Y_labels{row} = sprintf('%s_Object', terrain_name);
        else
            Y_labels{row} = sprintf('%s_NoObject', terrain_name);
        end
    end
end
Y_labels = categorical(Y_labels);

%% Train/Test Split
rng(42);
cv = cvpartition(Y_labels, 'HoldOut', 0.2);
X_train = X(training(cv), :);
Y_train = Y_labels(training(cv));
X_test = X(test(cv), :);
Y_test = Y_labels(test(cv));

train_cats = categories(Y_train);
fprintf('Train: %d, Test: %d\n\n', size(X_train,1), size(X_test,1));

%% Oversample helper
oversample = @(Xin, Yin, noise_level) oversample_data(Xin, Yin, noise_level);

%% Define experiments
exp_results = struct();
exp_count = 0;

% ====================================================================
% EXPERIMENT 1: RUSBoost with more cycles + deeper trees
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: RUSBoost (1000 cycles, deeper) ---\n', exp_count);
tic;
mdl = fitcensemble(X_train, Y_train, ...
    'Method', 'RUSBoost', ...
    'NumLearningCycles', 1000, ...
    'Learners', templateTree('MaxNumSplits', 200, 'MinLeafSize', 1), ...
    'LearnRate', 0.05);
pred = predict(mdl, X_test);
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'RUSBoost-1000-deep';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

% ====================================================================
% EXPERIMENT 2: RUSBoost with stats-only features (no raw RSSI)
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: RUSBoost stats-only features (129-155) ---\n', exp_count);
feat_idx = 129:155;
tic;
mdl = fitcensemble(X_train(:, feat_idx), Y_train, ...
    'Method', 'RUSBoost', ...
    'NumLearningCycles', 500, ...
    'Learners', templateTree('MaxNumSplits', 50, 'MinLeafSize', 1), ...
    'LearnRate', 0.1);
pred = predict(mdl, X_test(:, feat_idx));
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'RUSBoost-StatsOnly';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

% ====================================================================
% EXPERIMENT 3: Bagged Trees (1000 cycles, very deep, oversampled 3x)
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: Bagged Trees 1000 + 3x oversample ---\n', exp_count);
[X_bal, Y_bal] = oversample(X_train, Y_train, 0.01);
tic;
mdl = fitcensemble(X_bal, Y_bal, ...
    'Method', 'Bag', ...
    'NumLearningCycles', 1000, ...
    'Learners', templateTree('MaxNumSplits', 500, 'MinLeafSize', 1));
pred = predict(mdl, X_test);
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'BaggedTrees-1000-deep';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

% ====================================================================
% EXPERIMENT 4: AdaBoostM2 500 cycles + deeper trees + oversample
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: AdaBoostM2-500 deep + oversample ---\n', exp_count);
[X_bal, Y_bal] = oversample(X_train, Y_train, 0.02);
tic;
mdl = fitcensemble(X_bal, Y_bal, ...
    'Method', 'AdaBoostM2', ...
    'NumLearningCycles', 500, ...
    'Learners', templateTree('MaxNumSplits', 200), ...
    'LearnRate', 0.05);
pred = predict(mdl, X_test);
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'AdaBoostM2-500-deep';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

% ====================================================================
% EXPERIMENT 5: RUSBoost + feature selection (top 50 by importance)
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: RUSBoost + Top-50 features ---\n', exp_count);
tic;
% Quick importance estimation using Bag
mdl_imp = fitcensemble(X_train, Y_train, 'Method', 'Bag', ...
    'NumLearningCycles', 100, 'Learners', templateTree('MaxNumSplits', 50));
imp = predictorImportance(mdl_imp);
[~, sorted_idx] = sort(imp, 'descend');
top50 = sorted_idx(1:50);
mdl = fitcensemble(X_train(:, top50), Y_train, ...
    'Method', 'RUSBoost', ...
    'NumLearningCycles', 500, ...
    'Learners', templateTree('MaxNumSplits', 100, 'MinLeafSize', 1), ...
    'LearnRate', 0.1);
pred = predict(mdl, X_test(:, top50));
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'RUSBoost-Top50feat';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

% ====================================================================
% EXPERIMENT 6: MLP wider [512-256-128-64] + oversample
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: MLP [512-256-128-64] ---\n', exp_count);
[X_bal, Y_bal] = oversample(X_train, Y_train, 0.02);
tic;
mdl = fitcnet(X_bal, Y_bal, ...
    'LayerSizes', [512 256 128 64], ...
    'Standardize', true, ...
    'IterationLimit', 3000, ...
    'GradientTolerance', 1e-7);
pred = predict(mdl, X_test);
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'MLP-512-256-128-64';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

% ====================================================================
% EXPERIMENT 7: Ensemble of RUSBoost + Bagged Trees (voting)
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: Voting Ensemble (RUSBoost + Bag + Boost) ---\n', exp_count);
[X_bal, Y_bal] = oversample(X_train, Y_train, 0.02);
tic;
mdl1 = fitcensemble(X_train, Y_train, 'Method', 'RUSBoost', ...
    'NumLearningCycles', 500, 'Learners', templateTree('MaxNumSplits', 100), 'LearnRate', 0.1);
mdl2 = fitcensemble(X_bal, Y_bal, 'Method', 'Bag', ...
    'NumLearningCycles', 500, 'Learners', templateTree('MaxNumSplits', 300, 'MinLeafSize', 1));
mdl3 = fitcensemble(X_bal, Y_bal, 'Method', 'AdaBoostM2', ...
    'NumLearningCycles', 300, 'Learners', templateTree('MaxNumSplits', 100), 'LearnRate', 0.1);
% Majority vote
p1 = predict(mdl1, X_test);
p2 = predict(mdl2, X_test);
p3 = predict(mdl3, X_test);
pred_labels = cell(size(X_test,1), 1);
for i = 1:size(X_test,1)
    votes = {char(p1(i)), char(p2(i)), char(p3(i))};
    [unique_v, ~, ic] = unique(votes);
    vote_counts = accumarray(ic, 1);
    [~, winner_idx] = max(vote_counts);
    pred_labels{i} = unique_v{winner_idx};
end
pred = categorical(pred_labels, categories(Y_test));
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'VotingEnsemble';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

% ====================================================================
% EXPERIMENT 8: RUSBoost with ALL features + lower learning rate
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: RUSBoost 2000 cycles, LR=0.01 ---\n', exp_count);
tic;
mdl = fitcensemble(X_train, Y_train, ...
    'Method', 'RUSBoost', ...
    'NumLearningCycles', 2000, ...
    'Learners', templateTree('MaxNumSplits', 150, 'MinLeafSize', 1), ...
    'LearnRate', 0.01);
pred = predict(mdl, X_test);
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'RUSBoost-2000-slowLR';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

% ====================================================================
% EXPERIMENT 9: Two-stage with RUSBoost object + SVM terrain
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: Two-Stage (SVM terrain + RUSBoost object) ---\n', exp_count);
tic;
[X_bal, Y_bal] = oversample(X_train, Y_train, 0.02);
% Terrain (3-class)
terrain_labels = regexprep(cellstr(Y_bal), '_(Object|NoObject)$', '');
mdl_t = fitcecoc(X_bal, terrain_labels, ...
    'Learners', templateSVM('KernelFunction', 'gaussian', 'KernelScale', 'auto', ...
        'Standardize', true, 'BoxConstraint', 10), 'Coding', 'onevsone');
% Object (binary) on original imbalanced
obj_labels = categorical(double(endsWith(cellstr(Y_train), '_Object')));
mdl_o = fitcensemble(X_train, obj_labels, ...
    'Method', 'RUSBoost', 'NumLearningCycles', 1000, ...
    'Learners', templateTree('MaxNumSplits', 100), 'LearnRate', 0.05);
% Combine
pt = cellstr(predict(mdl_t, X_test));
po = predict(mdl_o, X_test);
combined = cell(size(X_test,1), 1);
for i = 1:size(X_test,1)
    if po(i) == '1'
        combined{i} = [pt{i} '_Object'];
    else
        combined{i} = [pt{i} '_NoObject'];
    end
end
pred = categorical(combined, categories(Y_test));
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'TwoStage-SVM+RUS';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

% ====================================================================
% EXPERIMENT 10: Bagged Trees + cost-sensitive (higher cost for Object misclass)
% ====================================================================
exp_count = exp_count + 1;
fprintf('--- Exp %d: Bagged Trees cost-sensitive ---\n', exp_count);
[X_bal, Y_bal] = oversample(X_train, Y_train, 0.02);
% Create cost matrix: misclassifying Object as NoObject costs 3x
class_names_sorted = categories(Y_bal);
n_cls = length(class_names_sorted);
cost_mat = ones(n_cls) - eye(n_cls);
for ci = 1:n_cls
    if contains(class_names_sorted{ci}, 'Object') && ~contains(class_names_sorted{ci}, 'NoObject')
        cost_mat(:, ci) = cost_mat(:, ci) * 3; % Higher cost for missing objects
        cost_mat(ci, ci) = 0;
    end
end
tic;
mdl = fitcensemble(X_bal, Y_bal, ...
    'Method', 'Bag', ...
    'NumLearningCycles', 500, ...
    'Learners', templateTree('MaxNumSplits', 300, 'MinLeafSize', 1), ...
    'Cost', cost_mat);
pred = predict(mdl, X_test);
[f1, prec, rec] = compute_macro_f1(Y_test, pred, train_cats);
acc = sum(pred == Y_test) / numel(Y_test) * 100;
t = toc;
exp_results(exp_count).name = 'BaggedTrees-CostSens';
exp_results(exp_count).acc = acc; exp_results(exp_count).f1 = f1;
exp_results(exp_count).prec = prec; exp_results(exp_count).rec = rec;
exp_results(exp_count).time = t;
fprintf('  Acc=%.2f%%, F1=%.4f (%.1fs)\n', acc, f1, t);

%% Summary
fprintf('\n============================================================\n');
fprintf('            ADVANCED TUNING RESULTS SUMMARY\n');
fprintf('============================================================\n');
fprintf('%-25s %7s %7s %7s %7s %7s\n', 'Experiment', 'Acc%', 'F1', 'Prec', 'Recall', 'Time');
fprintf('%-25s %7s %7s %7s %7s %7s\n', '---------', '----', '--', '----', '------', '----');
for i = 1:exp_count
    fprintf('%-25s %6.2f%% %6.4f %6.4f %6.4f %6.1fs\n', ...
        exp_results(i).name, exp_results(i).acc, exp_results(i).f1, ...
        exp_results(i).prec, exp_results(i).rec, exp_results(i).time);
end
fprintf('============================================================\n');

[best_f1, best_idx] = max([exp_results.f1]);
fprintf('\nBEST: %s (F1=%.4f, Acc=%.2f%%)\n', ...
    exp_results(best_idx).name, best_f1, exp_results(best_idx).acc);

% Save results
save(fullfile(cfg.output_dir, 'AdvancedTuningResults.mat'), 'exp_results');
fprintf('Results saved to: %s\n', fullfile(cfg.output_dir, 'AdvancedTuningResults.mat'));

%% ============ LOCAL FUNCTIONS ============

function [X_bal, Y_bal] = oversample_data(X_train, Y_train, noise_level)
    train_cats = categories(Y_train);
    counts = countcats(Y_train);
    max_count = max(counts);
    X_bal = X_train;
    Y_bal = Y_train;
    for ci = 1:length(train_cats)
        class_mask = Y_train == train_cats{ci};
        class_X = X_train(class_mask, :);
        class_count = size(class_X, 1);
        if class_count < max_count
            n_needed = max_count - class_count;
            oversample_idx = randi(class_count, n_needed, 1);
            X_new = class_X(oversample_idx, :) + noise_level * randn(n_needed, size(X_train, 2));
            Y_new = repmat(categorical(train_cats(ci)), n_needed, 1);
            X_bal = [X_bal; X_new];
            Y_bal = [Y_bal; Y_new];
        end
    end
end

function [f1_macro, prec_macro, rec_macro] = compute_macro_f1(y_true, y_pred, class_names)
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
