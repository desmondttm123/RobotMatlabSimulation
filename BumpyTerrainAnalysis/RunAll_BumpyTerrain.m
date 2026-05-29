%% RunAll_BumpyTerrain.m - Master script to run entire experiment pipeline
% Executes in order:
%   1. TrackSimulation_Bumpy (RF sim with randomized terrain)
%   2. TrainClassifiers_Bumpy (7 ML models)
%   3. AdvancedTuning_Bumpy (10 tuning experiments)
%
% All output saved to BumpyTerrainAnalysis/Results/
% NOTE: Each sub-script calls 'clear', so timing uses evalc/tic wrapping

fprintf('============================================================\n');
fprintf('   BUMPY TERRAIN EXPERIMENT - FULL PIPELINE\n');
fprintf('   Chunks: 100mm x 100mm, Surface: 0-10mm, Depth: 500mm\n');
fprintf('   Property variation: ±5%% εr and σ\n');
fprintf('============================================================\n\n');

t_total = tic;

%% Phase 1: RF Simulation
fprintf('============ PHASE 1: RF SIMULATION ============\n');
t1 = tic;
run('TrackSimulation_Bumpy.m');
fprintf('\nPhase 1 complete (%.1f min)\n\n', toc(t1)/60);

%% Phase 2: Train Classifiers
fprintf('\n============ PHASE 2: TRAIN CLASSIFIERS ============\n');
t2 = tic;
run('TrainClassifiers_Bumpy.m');
fprintf('\nPhase 2 complete (%.1f min)\n\n', toc(t2)/60);

%% Phase 3: Advanced Tuning
fprintf('\n============ PHASE 3: ADVANCED TUNING ============\n');
t3 = tic;
run('AdvancedTuning_Bumpy.m');
fprintf('\nPhase 3 complete (%.1f min)\n\n', toc(t3)/60);

%% Summary
fprintf('\n============================================================\n');
fprintf('   FULL PIPELINE COMPLETE\n');
fprintf('   Total time: %.1f minutes\n', toc(t_total)/60);
fprintf('   Output directory: Results/\n');
fprintf('============================================================\n');
