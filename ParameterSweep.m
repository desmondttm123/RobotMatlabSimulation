%% ParameterSweep.m - Try different simulation settings to maximize F1
% Tests multiple configurations and reports the best one

clear; close all; clc;

%% Define experiments
% Each experiment changes object/RF parameters from the baseline
experiments = struct();

experiments(1).name = 'Baseline (current)';
experiments(1).obj_y_half = 150;
experiments(1).obj_x_half = 250;
experiments(1).pattern_loss_direct = 25;
experiments(1).noise_std = 0.05;
experiments(1).obj_z_top = -30;

experiments(2).name = 'Larger objects (Y=300mm)';
experiments(2).obj_y_half = 300;
experiments(2).obj_x_half = 250;
experiments(2).pattern_loss_direct = 25;
experiments(2).noise_std = 0.05;
experiments(2).obj_z_top = -10;

experiments(3).name = 'Shallow+Wide objects';
experiments(3).obj_y_half = 250;
experiments(3).obj_x_half = 400;
experiments(3).pattern_loss_direct = 28;
experiments(3).noise_std = 0.03;
experiments(3).obj_z_top = -10;

experiments(4).name = 'Large+Shallow+LowNoise';
experiments(4).obj_y_half = 300;
experiments(4).obj_x_half = 400;
experiments(4).pattern_loss_direct = 30;
experiments(4).noise_std = 0.02;
experiments(4).obj_z_top = -5;

experiments(5).name = 'Max contrast';
experiments(5).obj_y_half = 350;
experiments(5).obj_x_half = 500;
experiments(5).pattern_loss_direct = 30;
experiments(5).noise_std = 0.02;
experiments(5).obj_z_top = -5;

nExperiments = length(experiments);
fprintf('=== Parameter Sweep: %d experiments ===\n\n', nExperiments);

%% Run each experiment
sweep_results = struct();

for ei = 1:nExperiments
    exp = experiments(ei);
    fprintf('--- Experiment %d: %s ---\n', ei, exp.name);
    fprintf('  obj_y_half=%d, obj_x_half=%d, PL_direct=%d, noise=%.3f\n', ...
        exp.obj_y_half, exp.obj_x_half, exp.pattern_loss_direct, exp.noise_std);
    
    % Modify SimConfig values
    SimConfig;
    cfg.obj_y_half = exp.obj_y_half;
    cfg.obj_x_half = exp.obj_x_half;
    cfg.obj_z_top = exp.obj_z_top;
    cfg.pattern_loss_direct = exp.pattern_loss_direct;
    cfg.noise_std = exp.noise_std;
    
    % Run simulation inline (abbreviated - only need training data)
    [X, Y_labels, ~] = run_simulation_for_training(cfg);
    
    % Train and evaluate
    [acc, f1, prec, rec, per_class] = train_and_evaluate(X, Y_labels);
    
    sweep_results(ei).name = exp.name;
    sweep_results(ei).accuracy = acc;
    sweep_results(ei).f1 = f1;
    sweep_results(ei).precision = prec;
    sweep_results(ei).recall = rec;
    sweep_results(ei).per_class = per_class;
    sweep_results(ei).params = exp;
    
    fprintf('  => Accuracy: %.2f%%, Macro F1: %.4f, Precision: %.4f, Recall: %.4f\n\n', ...
        acc, f1, prec, rec);
end

%% Summary
fprintf('\n============================================================\n');
fprintf('                 PARAMETER SWEEP RESULTS\n');
fprintf('============================================================\n');
fprintf('%-30s %8s %8s %8s %8s\n', 'Experiment', 'Acc%', 'F1', 'Prec', 'Recall');
fprintf('%-30s %8s %8s %8s %8s\n', '----------', '----', '--', '----', '------');
for ei = 1:nExperiments
    fprintf('%-30s %7.2f%% %7.4f %7.4f %7.4f\n', ...
        sweep_results(ei).name, sweep_results(ei).accuracy, ...
        sweep_results(ei).f1, sweep_results(ei).precision, sweep_results(ei).recall);
end
fprintf('============================================================\n');

% Find best
f1_scores = [sweep_results.f1];
[best_f1, best_idx] = max(f1_scores);
fprintf('\nBest F1: Experiment %d - %s (F1=%.4f, Acc=%.2f%%)\n', ...
    best_idx, sweep_results(best_idx).name, best_f1, sweep_results(best_idx).accuracy);

% Print best per-class
fprintf('\nPer-class F1 for best experiment:\n');
pc = sweep_results(best_idx).per_class;
for ci = 1:size(pc, 1)
    fprintf('  %-25s: F1=%.4f, Prec=%.4f, Recall=%.4f\n', ...
        pc{ci,1}, pc{ci,2}, pc{ci,3}, pc{ci,4});
end

% Save best params
best_params = sweep_results(best_idx).params;
fprintf('\nBest parameters:\n');
fprintf('  cfg.obj_y_half = %d;\n', best_params.obj_y_half);
fprintf('  cfg.obj_x_half = %d;\n', best_params.obj_x_half);
fprintf('  cfg.obj_z_top = %d;\n', best_params.obj_z_top);
fprintf('  cfg.pattern_loss_direct = %d;\n', best_params.pattern_loss_direct);
fprintf('  cfg.noise_std = %.3f;\n', best_params.noise_std);

save(fullfile('Results', 'SweepResults.mat'), 'sweep_results', 'best_idx', 'best_params');
fprintf('\nSweep results saved to Results/SweepResults.mat\n');

%% ============ LOCAL FUNCTIONS ============

function [X, Y_labels, y_positions] = run_simulation_for_training(cfg)
    % Compact simulation - generates features directly without saving CSVs
    c = 299792458;
    eps0 = 8.854187817e-12;
    freq = cfg.freq;
    lambda = c / freq;
    
    sensor1_x = cfg.sensor1_x;
    sensor2_x = cfg.sensor2_x;
    sensor_z = cfg.sensor_z;
    
    nCols = cfg.nCols;
    nRows = cfg.nRows;
    nRX = nCols * nRows;
    tilt_angle = cfg.tilt_angle;
    
    arrayWidth = cfg.arrayWidth;
    arrayHeight = cfg.arrayHeight;
    
    y_positions = cfg.track_y_start:cfg.track_y_step:cfg.track_y_end;
    nPositions = length(y_positions);
    nTerrains = length(cfg.terrains);
    
    % Object struct
    nObjects = length(cfg.obj_y_centers);
    objects = struct();
    for oi = 1:nObjects
        objects(oi).y_center = cfg.obj_y_centers(oi);
    end
    
    % RX offsets
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
    
    G_tx = cfg.G_tx;
    G_rx = cfg.G_rx;
    obj_x_half = cfg.obj_x_half;
    obj_y_half = cfg.obj_y_half;
    
    % Determine object labels
    is_object = false(nPositions, 1);
    for pi = 1:nPositions
        y = y_positions(pi);
        for oi = 1:nObjects
            if abs(y - cfg.obj_y_centers(oi)) <= obj_y_half
                is_object(pi) = true;
                break;
            end
        end
    end
    
    % Build feature matrix
    nFeatures = 141;  % 128 RSSI + 13 stats
    X = zeros(nPositions * nTerrains, nFeatures);
    Y_labels = cell(nPositions * nTerrains, 1);
    
    omega = 2*pi*freq;
    row = 0;
    
    for ti = 1:nTerrains
        terrain = cfg.terrains(ti);
        eps_terrain = terrain.er - 1j*terrain.sigma/(omega*eps0);
        eps_void = cfg.obj_er - 1j*cfg.obj_sigma/(omega*eps0);
        
        for pi_idx = 1:nPositions
            row = row + 1;
            y_pos = y_positions(pi_idx);
            
            tx1_pos = [sensor1_x, y_pos, sensor_z];
            tx2_pos = [sensor2_x, y_pos, sensor_z];
            
            s1_low = zeros(1, nRX);
            s1_high = zeros(1, nRX);
            s2_low = zeros(1, nRX);
            s2_high = zeros(1, nRX);
            
            for rx_idx = 1:nRX
                rx2_pos = [sensor2_x + rx_offset_x(rx_idx), ...
                           y_pos + rx_offset_y(rx_idx), ...
                           sensor_z + rx_offset_z(rx_idx)];
                [s2_low(rx_idx), s2_high(rx_idx)] = compute_rssi_fast(tx1_pos, rx2_pos, ...
                    eps_terrain, eps_void, objects, obj_x_half, obj_y_half, ...
                    freq, lambda, G_tx, G_rx, cfg);
                
                rx1_pos = [sensor1_x + rx_offset_x(rx_idx), ...
                           y_pos + rx_offset_y(rx_idx), ...
                           sensor_z + rx_offset_z(rx_idx)];
                [s1_low(rx_idx), s1_high(rx_idx)] = compute_rssi_fast(tx2_pos, rx1_pos, ...
                    eps_terrain, eps_void, objects, obj_x_half, obj_y_half, ...
                    freq, lambda, G_tx, G_rx, cfg);
            end
            
            % Features: 128 RSSI
            X(row, 1:32) = s1_low;
            X(row, 33:64) = s1_high;
            X(row, 65:96) = s2_low;
            X(row, 97:128) = s2_high;
            
            % Stats
            q1 = quantile(s1_low, [0.25, 0.75]);
            q2 = quantile(s2_low, [0.25, 0.75]);
            X(row, 129) = mean(s1_low);
            X(row, 130) = std(s1_low);
            X(row, 131) = min(s1_low);
            X(row, 132) = max(s1_low);
            X(row, 133) = q1(2) - q1(1);
            X(row, 134) = mean(s2_low);
            X(row, 135) = std(s2_low);
            X(row, 136) = min(s2_low);
            X(row, 137) = max(s2_low);
            X(row, 138) = q2(2) - q2(1);
            X(row, 139) = mean(s1_low) - mean(s2_low);
            X(row, 140) = std(s1_low) - std(s2_low);
            r = corrcoef(s1_low, s2_low);
            X(row, 141) = r(1,2);
            
            % Label
            if is_object(pi_idx)
                Y_labels{row} = sprintf('%s_Object', terrain.name);
            else
                Y_labels{row} = sprintf('%s_NoObject', terrain.name);
            end
        end
        
        if mod(ti, 1) == 0
            fprintf('  Terrain %d/%d done\n', ti, nTerrains);
        end
    end
    
    Y_labels = categorical(Y_labels);
end

function [acc, f1, prec, rec, per_class] = train_and_evaluate(X, Y_labels)
    % Quick train with Bagged Trees (best performer) and evaluate
    rng(42);
    cv = cvpartition(Y_labels, 'HoldOut', 0.2);
    X_train = X(training(cv), :);
    Y_train = Y_labels(training(cv));
    X_test = X(test(cv), :);
    Y_test = Y_labels(test(cv));
    
    % Oversample
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
            n_needed = max_count - class_count;
            oversample_idx = randi(class_count, n_needed, 1);
            X_new = class_X(oversample_idx, :) + 0.02 * randn(n_needed, size(X_train, 2));
            Y_new = repmat(categorical(train_cats(ci)), n_needed, 1);
            X_train_bal = [X_train_bal; X_new];
            Y_train_bal = [Y_train_bal; Y_new];
        end
    end
    
    % Train Bagged Trees
    mdl = fitcensemble(X_train_bal, Y_train_bal, ...
        'Method', 'Bag', ...
        'NumLearningCycles', 300, ...
        'Learners', templateTree('MaxNumSplits', 200, 'MinLeafSize', 2));
    
    Y_pred = predict(mdl, X_test);
    acc = sum(Y_pred == Y_test) / numel(Y_test) * 100;
    
    % Compute macro F1
    n_classes = length(train_cats);
    f1s = zeros(n_classes, 1);
    precs = zeros(n_classes, 1);
    recs = zeros(n_classes, 1);
    per_class = cell(n_classes, 4);
    
    for ci = 1:n_classes
        tp = sum(Y_pred == train_cats{ci} & Y_test == train_cats{ci});
        fp = sum(Y_pred == train_cats{ci} & Y_test ~= train_cats{ci});
        fn = sum(Y_pred ~= train_cats{ci} & Y_test == train_cats{ci});
        precs(ci) = tp / (tp + fp + 1e-10);
        recs(ci) = tp / (tp + fn + 1e-10);
        f1s(ci) = 2 * precs(ci) * recs(ci) / (precs(ci) + recs(ci) + 1e-10);
        per_class{ci, 1} = train_cats{ci};
        per_class{ci, 2} = f1s(ci);
        per_class{ci, 3} = precs(ci);
        per_class{ci, 4} = recs(ci);
    end
    
    f1 = mean(f1s);
    prec = mean(precs);
    rec = mean(recs);
end

function [rssi_low, rssi_high] = compute_rssi_fast(tx_pos, rx_pos, ...
    eps_terrain, eps_void, objects, obj_x_half, obj_y_half, ...
    freq, lambda, G_tx, G_rx, cfg)
    
    d_direct = norm(tx_pos - rx_pos) / 1000;
    
    tx_z = tx_pos(3);
    rx_z = rx_pos(3);
    dx = rx_pos(1) - tx_pos(1);
    dy = rx_pos(2) - tx_pos(2);
    d_horiz = sqrt(dx^2 + dy^2);
    
    total_z = tx_z + rx_z;
    frac = tx_z / total_z;
    ref_x = tx_pos(1) + frac * dx;
    ref_y = tx_pos(2) + frac * dy;
    
    d_tx_ref = sqrt(tx_z^2 + (frac*d_horiz)^2) / 1000;
    d_ref_rx = sqrt(rx_z^2 + ((1-frac)*d_horiz)^2) / 1000;
    d_reflected = d_tx_ref + d_ref_rx;
    
    theta_i = atan2(frac*d_horiz, tx_z);
    
    is_void = false;
    for oi = 1:length(objects)
        if abs(ref_x) <= obj_x_half && abs(ref_y - objects(oi).y_center) <= obj_y_half
            is_void = true;
            break;
        end
    end
    
    if is_void
        eps_ground = eps_void;
    else
        eps_ground = eps_terrain;
    end
    
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
    
    P_tx_low = cfg.low_power_range(1) + diff(cfg.low_power_range)*rand();
    rssi_low = P_tx_low + P_total_dB + noise_std*randn();
    
    P_tx_high = cfg.high_power_range(1) + diff(cfg.high_power_range)*rand();
    rssi_high = P_tx_high + P_total_dB + noise_std*randn();
end
