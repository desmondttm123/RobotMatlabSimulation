%% 01_setup_ro2_paths.m - Create folders and define project paths
% Run this first to ensure all output directories exist.

fprintf('=== RO2 Path Setup ===\n');

% Project root (assumes script is run from RO2 folder)
if ~exist('ro2_root', 'var') || isempty(ro2_root)
    ro2_root = pwd;
end

% Add config and code to path
addpath(fullfile(ro2_root, 'config'));
addpath(fullfile(ro2_root, 'code'));

% Create all output directories
dirs_to_create = {
    'data/raw'
    'data/processed'
    'models'
    'results'
    'figures/setup'
    'figures/dataset'
    'figures/training'
    'figures/confusion_matrices'
    'docs'
};

for i = 1:length(dirs_to_create)
    d = fullfile(ro2_root, dirs_to_create{i});
    if ~exist(d, 'dir')
        mkdir(d);
        fprintf('  Created: %s\n', dirs_to_create{i});
    end
end

fprintf('RO2 paths ready. Root: %s\n', ro2_root);
