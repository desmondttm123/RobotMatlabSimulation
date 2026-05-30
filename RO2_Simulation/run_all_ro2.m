%% run_all_RO2.m - Run the full RO2 pipeline in order
% Execute from the RO2/ directory.

fprintf('============================================\n');
fprintf('  RO2 - Full Pipeline Execution\n');
fprintf('============================================\n\n');

total_tic = tic;

%% Step 1: Setup paths
fprintf('[1/7] Setting up paths...\n');
ro2_root = pwd;
addpath(fullfile(ro2_root, 'config'));
addpath(fullfile(ro2_root, 'code'));
dirs_to_create = {'data/raw','data/processed','models','results', ...
    'figures/setup','figures/dataset','figures/training','figures/confusion_matrices','docs'};
for i = 1:length(dirs_to_create)
    d = fullfile(ro2_root, dirs_to_create{i});
    if ~exist(d, 'dir'), mkdir(d); end
end
fprintf('RO2 paths ready.\n\n');

%% Step 2: Display config
fprintf('[2/7] Loading configuration...\n');
ro2_config;
fprintf('\n');

%% Step 3: Generate geometry
fprintf('[3/7] Generating terrain geometry and voids...\n');
s10_generate_ro2_geometry;
fprintf('\n');

%% Step 4: Simulate RSSI dataset
fprintf('[4/7] Simulating RSSI dataset...\n');
s20_simulate_ro2_rssi_dataset;
fprintf('\n');

%% Step 5: Review dataset
fprintf('[5/7] Reviewing dataset (generating plots)...\n');
s30_review_ro2_dataset;
fprintf('\n');

%% Step 6: Train MLP
fprintf('[6/7] Training MLP classifier...\n');
s40_train_ro2_mlp;
fprintf('\n');

%% Step 7: Evaluate MLP
fprintf('[7/7] Evaluating MLP classifier...\n');
s50_evaluate_ro2_mlp;
fprintf('\n');

%% Step 8: Generate figures
fprintf('[Bonus] Generating experiment setup figures...\n');
s60_generate_ro2_figures;
fprintf('\n');

%% Done
total_elapsed = toc(total_tic);
fprintf('============================================\n');
fprintf('  RO2 Pipeline Complete!\n');
fprintf('  Total time: %.1f seconds (%.1f min)\n', total_elapsed, total_elapsed/60);
fprintf('============================================\n');
