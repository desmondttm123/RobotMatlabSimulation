%% 40_train_ro2_mlp.m - Train MLP classifier on RO2 RSSI data
% Uses fitcnet (MATLAB's built-in neural network classifier)
% Architecture: [128, 64, 32] hidden layers
% Standardization: built-in z-score
% Split: 80/20 stratified with oversampling for balanced training

fprintf('=== RO2 MLP Training ===\n');
tic;

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

%% Prepare labels
Y_labels = categorical(metadata.Label, cfg.all_labels);
X = rssi_data;

%% Train/Test Split (80/20, stratified)
rng(cfg.rng_seed_split);
cv = cvpartition(Y_labels, 'HoldOut', cfg.test_fraction);
train_idx = training(cv);
test_idx = test(cv);

X_train = X(train_idx, :);
Y_train = Y_labels(train_idx);
X_test = X(test_idx, :);
Y_test = Y_labels(test_idx);

fprintf('Train: %d, Test: %d\n', sum(train_idx), sum(test_idx));

%% Oversample minority classes (balance training set)
classes = categories(Y_train);
class_counts = countcats(Y_train);
max_count = max(class_counts);

X_train_bal = X_train;
Y_train_bal = Y_train;

for ci = 1:length(classes)
    cls = classes{ci};
    cls_mask = Y_train == cls;
    cls_X = X_train(cls_mask, :);
    cls_count = sum(cls_mask);
    
    if cls_count < max_count
        n_to_add = max_count - cls_count;
        % Random oversampling with jitter
        oversample_idx = randi(cls_count, n_to_add, 1);
        X_new = cls_X(oversample_idx, :) + 0.02 * randn(n_to_add, size(X_train, 2));
        Y_new = repmat(categorical({cls}, cfg.all_labels), n_to_add, 1);
        X_train_bal = [X_train_bal; X_new];
        Y_train_bal = [Y_train_bal; Y_new];
    end
end

fprintf('Balanced training set: %d samples (oversampled from %d)\n', ...
    length(Y_train_bal), sum(train_idx));

%% Train MLP
fprintf('\nTraining MLP [%s]...\n', num2str(cfg.mlp_layers, '%d-'));

mdl_mlp = fitcnet(X_train_bal, Y_train_bal, ...
    'LayerSizes', cfg.mlp_layers, ...
    'Standardize', true, ...
    'IterationLimit', cfg.mlp_iter_limit, ...
    'GradientTolerance', cfg.mlp_grad_tol);

fprintf('MLP training complete. Final loss: %.6f\n', mdl_mlp.TrainingHistory.TrainingLoss(end));

%% Quick training evaluation
Y_pred_train = predict(mdl_mlp, X_train);
train_acc = sum(Y_pred_train == Y_train) / length(Y_train);
fprintf('Training accuracy: %.2f%%\n', train_acc * 100);

%% Save model and split info
model_file = fullfile(ro2_root, cfg.path_models, 'ro2_mlp_model.mat');
save(model_file, 'mdl_mlp', 'train_idx', 'test_idx', 'cfg', ...
    'feature_names', 'X_train_bal', 'Y_train_bal', '-v7.3');
fprintf('Model saved: %s\n', model_file);

%% Save training curve
if isprop(mdl_mlp, 'TrainingHistory') && ~isempty(mdl_mlp.TrainingHistory)
    figure('Position', [50 50 800 400], 'Visible', 'off');
    plot(mdl_mlp.TrainingHistory.Iteration, ...
         mdl_mlp.TrainingHistory.TrainingLoss, 'b-', 'LineWidth', 1.5);
    xlabel('Iteration');
    ylabel('Training Loss');
    title(sprintf('RO2 MLP Training Curve [%s]', num2str(cfg.mlp_layers, '%d-')));
    grid on;
    set(gcf, 'Visible', 'on');
    fig_dir = fullfile(ro2_root, cfg.path_figures_training);
    savefig(gcf, fullfile(fig_dir, 'mlp_training_curve.fig'));
    exportgraphics(gcf, fullfile(fig_dir, 'mlp_training_curve.png'), 'Resolution', 150);
    close(gcf);
    fprintf('Training curve saved.\n');
end

elapsed = toc;
fprintf('Elapsed: %.1f seconds\n', elapsed);
fprintf('=== MLP Training Complete ===\n');
