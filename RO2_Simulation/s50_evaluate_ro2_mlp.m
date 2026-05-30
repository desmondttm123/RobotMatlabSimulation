%% 50_evaluate_ro2_mlp.m - Evaluate MLP classifier performance
% Computes accuracy, macro F1, confusion matrix, and per-class metrics.

fprintf('=== RO2 MLP Evaluation ===\n');

% Setup
if ~exist('ro2_root','var'), ro2_root=pwd; addpath('config'); end
ro2_config;

%% Load model and dataset
model_file = fullfile(ro2_root, cfg.path_models, 'ro2_mlp_model.mat');
data_file = fullfile(ro2_root, cfg.path_data_raw, 'ro2_rssi_dataset.mat');

if ~exist(model_file, 'file')
    error('Model not found. Run 40_train_ro2_mlp.m first.');
end
if ~exist(data_file, 'file')
    error('Dataset not found. Run 20_simulate_ro2_rssi_dataset.m first.');
end

load(model_file, 'mdl_mlp', 'train_idx', 'test_idx');
load(data_file, 'rssi_data', 'metadata', 'feature_names');

Y_labels = categorical(metadata.Label, cfg.all_labels);
X_test = rssi_data(test_idx, :);
Y_test = Y_labels(test_idx);

fprintf('Test set: %d samples\n', length(Y_test));

%% Predict
Y_pred = predict(mdl_mlp, X_test);

%% Overall metrics
accuracy = sum(Y_pred == Y_test) / length(Y_test);
fprintf('\nOverall Accuracy: %.2f%%\n', accuracy * 100);

%% Per-class metrics
classes = categories(Y_test);
n_cls = length(classes);
precision = zeros(n_cls, 1);
recall = zeros(n_cls, 1);
f1 = zeros(n_cls, 1);
support = zeros(n_cls, 1);

fprintf('\n%-20s %8s %8s %8s %8s\n', 'Class', 'Prec', 'Recall', 'F1', 'Support');
fprintf('%s\n', repmat('-', 1, 56));

for ci = 1:n_cls
    tp = sum(Y_pred == classes{ci} & Y_test == classes{ci});
    fp = sum(Y_pred == classes{ci} & Y_test ~= classes{ci});
    fn = sum(Y_pred ~= classes{ci} & Y_test == classes{ci});
    support(ci) = sum(Y_test == classes{ci});
    
    if tp + fp > 0
        precision(ci) = tp / (tp + fp);
    end
    if tp + fn > 0
        recall(ci) = tp / (tp + fn);
    end
    if precision(ci) + recall(ci) > 0
        f1(ci) = 2 * precision(ci) * recall(ci) / (precision(ci) + recall(ci));
    end
    
    fprintf('%-20s %8.4f %8.4f %8.4f %8d\n', ...
        classes{ci}, precision(ci), recall(ci), f1(ci), support(ci));
end

macro_f1 = mean(f1);
macro_precision = mean(precision);
macro_recall = mean(recall);
fprintf('%s\n', repmat('-', 1, 56));
fprintf('%-20s %8.4f %8.4f %8.4f %8d\n', ...
    'MACRO AVG', macro_precision, macro_recall, macro_f1, sum(support));

fprintf('\nMacro F1 Score: %.4f\n', macro_f1);

%% Confusion Matrix
fig_dir_cm = fullfile(ro2_root, cfg.path_figures_cm);

figure('Position', [50 50 900 700], 'Visible', 'off');
cm = confusionchart(Y_test, Y_pred);
cm.Title = sprintf('RO2 MLP Confusion Matrix (Acc=%.1f%%, F1=%.4f)', accuracy*100, macro_f1);
cm.RowSummary = 'row-normalized';
cm.ColumnSummary = 'column-normalized';
set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(fig_dir_cm, 'confusion_matrix_mlp.fig'));
exportgraphics(gcf, fullfile(fig_dir_cm, 'confusion_matrix_mlp.png'), 'Resolution', 150);
close(gcf);

%% Per-class F1 bar chart
fig_dir_train = fullfile(ro2_root, cfg.path_figures_training);

figure('Position', [50 50 1000 450], 'Visible', 'off');
bar(categorical(classes, cfg.all_labels), f1);
xlabel('Density Class');
ylabel('F1 Score');
title(sprintf('RO2 MLP: Per-Class F1 Score (Macro F1 = %.4f)', macro_f1));
yline(macro_f1, 'r--', sprintf('Macro=%.3f', macro_f1), 'LineWidth', 1.5);
ylim([0 1]);
grid on;
set(gcf, 'Visible', 'on');
savefig(gcf, fullfile(fig_dir_train, 'per_class_f1.fig'));
exportgraphics(gcf, fullfile(fig_dir_train, 'per_class_f1.png'), 'Resolution', 150);
close(gcf);

%% Save evaluation results
results = struct();
results.accuracy = accuracy;
results.macro_f1 = macro_f1;
results.macro_precision = macro_precision;
results.macro_recall = macro_recall;
results.per_class_precision = precision;
results.per_class_recall = recall;
results.per_class_f1 = f1;
results.per_class_support = support;
results.class_names = classes;
results.Y_test = Y_test;
results.Y_pred = Y_pred;

results_file = fullfile(ro2_root, cfg.path_results, 'ro2_mlp_results.mat');
save(results_file, 'results', '-v7.3');

% Also save as readable table
results_table = table(classes, precision, recall, f1, support, ...
    'VariableNames', {'Class', 'Precision', 'Recall', 'F1', 'Support'});
writetable(results_table, fullfile(ro2_root, cfg.path_results, 'ro2_mlp_results.csv'));

fprintf('\nResults saved to: %s\n', fullfile(ro2_root, cfg.path_results));
fprintf('Figures saved to: %s\n', fig_dir_cm);
fprintf('=== MLP Evaluation Complete ===\n');
