# RO2 - Getting Started

## Overview

RO2 is a single-antenna material density classification experiment using RF sensing. A downward-facing antenna array measures RSSI reflections from a small terrain block (200×200×200 mm) containing known void distributions. The raw RSSI data is used to classify 12 material density classes.

## Requirements

- MATLAB R2024b (or later)
- Statistics and Machine Learning Toolbox (for `fitcnet`, `cvpartition`)

## Quick Start

Run the entire pipeline from `RobotSimulationAnalysis/RO2/`:

```
matlab -batch "run_all_RO2"
```

## Step-by-Step Execution

All commands run from `RobotSimulationAnalysis/RO2/`:

### 1. Setup paths
```
matlab -batch "run('01_setup_ro2_paths.m')"
```

### 2. View configuration
```
matlab -batch "run('02_config_ro2_simulation.m')"
```

### 3. Generate terrain geometry (void placement)
```
matlab -batch "run('10_generate_ro2_geometry.m')"
```
Output: `data/raw/ro2_geometry.mat`

### 4. Simulate RSSI dataset
```
matlab -batch "run('20_simulate_ro2_rssi_dataset.m')"
```
Output: `data/raw/ro2_rssi_dataset.mat`, `data/raw/ro2_rssi_dataset.csv`

### 5. Review dataset (generate plots)
```
matlab -batch "run('30_review_ro2_dataset.m')"
```
Output: `figures/dataset/*.fig`, `figures/dataset/*.png`

### 6. Train MLP classifier
```
matlab -batch "run('40_train_ro2_mlp.m')"
```
Output: `models/ro2_mlp_model.mat`, `figures/training/mlp_training_curve.png`

### 7. Evaluate MLP
```
matlab -batch "run('50_evaluate_ro2_mlp.m')"
```
Output: `results/ro2_mlp_results.mat`, `results/ro2_mlp_results.csv`, `figures/confusion_matrices/*.png`

### 8. Generate setup figures
```
matlab -batch "run('60_generate_ro2_figures.m')"
```
Output: `figures/setup/ro2_experiment_setup.png`, `figures/setup/ro2_cross_section.png`

## Output Structure

```
RO2/
├── config/
│   └── ro2_config.m           # All simulation parameters
├── data/
│   ├── raw/
│   │   ├── ro2_geometry.mat   # Terrain + void data
│   │   ├── ro2_rssi_dataset.mat
│   │   └── ro2_rssi_dataset.csv
│   └── processed/
├── models/
│   └── ro2_mlp_model.mat      # Trained MLP + split indices
├── results/
│   ├── ro2_mlp_results.mat    # Full evaluation struct
│   └── ro2_mlp_results.csv    # Per-class metrics table
├── figures/
│   ├── setup/                 # 3D setup + cross-section
│   ├── dataset/               # RSSI distributions, correlations
│   ├── training/              # Loss curve, per-class F1
│   └── confusion_matrices/    # Confusion matrix
└── docs/
    └── 00_getting_started.md  # This file
```

## Configuration

Edit `config/ro2_config.m` to change:
- Antenna position and array geometry
- Terrain dimensions and layer thicknesses
- Material properties (permittivity, conductivity)
- Void size and variation percentage
- Density class definitions
- MLP architecture and training parameters
- Number of samples per class

## Density Classes (12 total)

### Cement with tile top (6 classes)
| Class | Mass (g) | Density (g/cm³) |
|-------|----------|-----------------|
| Cement 800 | 800 | 1.33 |
| Cement 900 | 900 | 1.50 |
| Cement 1000 | 1000 | 1.67 |
| Cement 1100 | 1100 | 1.83 |
| Cement 1200 | 1200 | 2.00 |
| Cement 1300 | 1300 | 2.17 |

### Soil with concrete/gravel slab top (6 classes)
| Class | Mass (g) | Density (g/cm³) |
|-------|----------|-----------------|
| Soil 700 | 700 | 0.35 |
| Soil 900 | 900 | 0.45 |
| Soil 1100 | 1100 | 0.55 |
| Soil 1300 | 1300 | 0.65 |
| Soil 1500 | 1500 | 0.74 |
| Soil 1700 | 1700 | 0.84 |

## How RO2 Differs from BumpyTerrainAnalysis

| Aspect | BumpyTerrainAnalysis | RO2 |
|--------|---------------------|-----|
| **Antenna** | 2 sensors (32 RX each), 45° tilt | 1 sensor (16 RX), 90° downward |
| **Geometry** | 2000×20000 mm track | 200×200×200 mm block |
| **Terrain** | Uniform chunks, bumpy surface | Layered: cover + bulk with voids |
| **Object** | Large subsurface voids | 3mm void cubes (density control) |
| **Features** | 128 RSSI + 27 statistical | 32 raw RSSI only |
| **Classes** | 6 (material × object) | 12 (density levels) |
| **Classifiers** | 7 (SVM, MLP, Ensemble, ...) | MLP only |
| **Robot** | STL model rendered | No robot |
| **Variation** | ±2% per terrain chunk | ±2% per sample |
| **Movement** | Scans along track | Static (single position) |
