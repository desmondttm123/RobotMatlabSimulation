# Getting Started

## Requirements

- MATLAB R2024b (or later)
- No additional toolboxes required

## Flat Terrain (Uniform Ground)

Commands run from `RobotSimulationAnalysis/`:

Generate the 3D setup figure:

```
matlab -batch "QuickView"
```

Run the full RF track simulation:

```
matlab -batch "TrackSimulation"
```

Train classifiers (SVM, MLP, Ensemble, Bagged Trees, KNN, RUSBoost):

```
matlab -batch "TrainClassifiers"
```

## Bumpy Terrain (Randomized Heterogeneous Ground)

Commands run from `RobotSimulationAnalysis/BumpyTerrainAnalysis/`:

Generate the 3D bumpy terrain setup figure:

```
matlab -batch "QuickView_BumpyTerrain"
```

Run RF simulation with ±2% chunk-based material variation:

```
matlab -batch "TrackSimulation_Bumpy"
```

Train classifiers on bumpy terrain data:

```
matlab -batch "TrainClassifiers_Bumpy"
```

Run advanced hyperparameter tuning (10 experiments):

```
matlab -batch "AdvancedTuning_Bumpy"
```

Run the entire bumpy terrain pipeline in one go:

```
matlab -batch "RunAll_BumpyTerrain"
```

## Configuration

Edit `SimConfig.m` to change shared parameters (track size, object positions, materials, etc.).

Bumpy terrain parameters (chunk size, variation %, surface roughness) are set at the top of each `*_Bumpy.m` script.

All outputs (CSV, .fig, .png) are saved to the respective `Results/` folder.
