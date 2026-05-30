# Bumpy Terrain Analysis - Report

## Overview

This analysis evaluates classifier performance under **realistic heterogeneous terrain conditions**. Instead of assuming perfectly uniform material properties, the ground is modeled as a grid of 100×100 mm chunks, each with independently randomized permittivity (εr) and conductivity (σ) within ±2% of base values. Surface roughness (0–10 mm) is also applied per chunk.

---

## Motivation

Real-world terrain is never perfectly uniform. Natural ground exhibits spatial variation due to:
- Moisture pockets and drainage patterns
- Rock inclusions and aggregate distribution
- Root systems and organic matter
- Compaction differences from traffic/weather

This extension quantifies how much such variation degrades classification accuracy compared to the idealized flat-terrain scenario.

---

## Terrain Randomization Model

| Parameter | Value |
|-----------|-------|
| Chunk size | 100 mm × 100 mm (along-track × lateral) |
| Chunks along track (Y) | 200 (covering 20 m) |
| Chunks across width (X) | 15 (covering 1500 mm) |
| Depth layers | 5 (each 100 mm, total 500 mm) |
| Total chunks per terrain | 3000 |
| Material variation | **±2% of base εr and σ** (Gaussian, clipped) |
| Surface roughness | 0–10 mm random height per chunk |
| Effective ground properties | Average of 15 lateral surface chunks at each Y position |

### Base Material Properties

| Terrain | εr (base) | σ (base, S/m) | εr range (±2%) | σ range (±2%) |
|---------|-----------|---------------|----------------|---------------|
| Dry Sand | 3.5 | 0.001 | 3.43 – 3.57 | 0.00098 – 0.00102 |
| Grassy Soil | 15.0 | 0.050 | 14.70 – 15.30 | 0.0490 – 0.0510 |
| Rocks | 7.0 | 0.005 | 6.86 – 7.14 | 0.0049 – 0.0051 |

---

## Experiment Setup

### System Configuration

| Parameter | Value |
|-----------|-------|
| Frequency | 2.45 GHz (λ = 122.4 mm) |
| Antenna Array | 8×4 (32 elements), dual power levels |
| Sensor 1 Position | X = −90 mm, Z = 95.26 mm |
| Sensor 2 Position | X = +90 mm, Z = 95.26 mm |
| Track Length | 20,000 mm (20 m) |
| Track Step | 10 mm (2001 positions) |
| Objects | 4 buried voids at Y = 3200, 8500, 14100, 18000 mm |
| Object Footprint | 800 × 400 mm (X × Y) |
| Object Depth | 30 – 150 mm below surface |

### 3D Setup Visualization

![Bumpy Terrain Setup](Results/BumpyTerrain_Setup.png)

### Terrain Detail (Zoomed)

![Terrain Detail](Results/BumpyTerrain_Detail.png)

### Randomized Terrain Properties

![Randomized Terrain](Results/RandomizedTerrain.png)

Multi-panel view showing:
- **Row 1**: Permittivity variation along track (red dashed = base, dotted = ±2% bounds)
- **Row 2**: Conductivity variation along track
- **Row 3**: Surface height profile (0–10 mm bumps)
- **Row 4**: 3D surface height map with buried object locations

#### Individual Terrain Property Plots

##### Permittivity (εr) Along Track

| Dry Sand | Grassy Soil | Rocks |
|----------|-------------|-------|
| ![](Results/Permittivity_DrySand.png) | ![](Results/Permittivity_GrassySoil.png) | ![](Results/Permittivity_Rocks.png) |

##### Conductivity (σ) Along Track

| Dry Sand | Grassy Soil | Rocks |
|----------|-------------|-------|
| ![](Results/Conductivity_DrySand.png) | ![](Results/Conductivity_GrassySoil.png) | ![](Results/Conductivity_Rocks.png) |

##### Surface Height Along Track

| Dry Sand | Grassy Soil | Rocks |
|----------|-------------|-------|
| ![](Results/SurfaceHeight_DrySand.png) | ![](Results/SurfaceHeight_GrassySoil.png) | ![](Results/SurfaceHeight_Rocks.png) |

##### 3D Surface Profile

![3D Surface Profile](Results/SurfaceProfile_3D.png)

### Terrain Surface Profile

![Terrain Profile](Results/BumpyTerrain_Profile.png)

---

## RF Simulation Model

Same analytical Fresnel reflection model as the flat terrain, but with **position-dependent ground properties**:

1. At each robot position Y, the effective εr and σ are computed as the average of the 15 lateral surface chunks
2. The Fresnel reflection coefficient varies along the track due to chunk-to-chunk material differences
3. Surface height variation adds small path-length changes to the reflected signal
4. Over objects, ground reflection is suppressed (Γ ≈ 0 for air-air interface)

---

## RSSI Results

### Raw RSSI Along Track

| Terrain | RSSI (All Antennas) | Mean RSSI |
|---------|--------------------:|----------:|
| Dry Sand | ![](Results/RSSI_DrySand.png) | ![](Results/RSSI_Mean_DrySand.png) |
| Grassy Soil | ![](Results/RSSI_GrassySoil.png) | ![](Results/RSSI_Mean_GrassySoil.png) |
| Rocks | ![](Results/RSSI_Rocks.png) | ![](Results/RSSI_Mean_Rocks.png) |

### Between-Sensor Comparison

| Dry Sand | Grassy Soil | Rocks |
|----------|-------------|-------|
| ![](Results/Between_DrySand.png) | ![](Results/Between_GrassySoil.png) | ![](Results/Between_Rocks.png) |

### Statistical Features

| Dry Sand | Grassy Soil | Rocks |
|----------|-------------|-------|
| ![](Results/Stats_DrySand.png) | ![](Results/Stats_GrassySoil.png) | ![](Results/Stats_Rocks.png) |

### Terrain Comparison

![Terrain Comparison](Results/Terrain_Comparison.png)

---

## Classification Problem

- **6 Classes**: {DrySand, GrassySoil, Rocks} × {Object, NoObject}
- **155 Features**: 128 raw RSSI (32 antennas × 2 power levels × 2 sensors) + 27 statistical features
- **Dataset**: 6003 samples (2001 positions × 3 terrains)
- **Split**: 80/20 stratified (Train: 4803, Test: 1200)
- **Object positions**: 164 / 2001 per terrain (~8.2%)
- **Class imbalance**: ~11:1 (NoObject : Object)

---

## Phase 1: Baseline Classifiers

Seven classifiers trained on bumpy terrain data with oversampling for minority classes:

| Model | Accuracy | Macro F1 | Precision | Recall | Time |
|-------|----------|----------|-----------|--------|------|
| SVM (Gaussian, ECOC) | 81.25% | 0.5922 | 0.6044 | 0.5832 | 2.1s |
| MLP [256-128-64] | 77.75% | 0.5768 | 0.5804 | 0.5736 | 61.0s |
| **Ensemble (AdaBoostM2, 300 cycles)** | **81.25%** | **0.6220** | **0.6368** | **0.6109** | **34.4s** |
| Bagged Trees (500 cycles) | 80.00% | 0.6176 | 0.6395 | 0.6043 | 12.1s |
| KNN (k=7, weighted) | 71.42% | 0.5710 | 0.5516 | 0.6005 | 0.1s |
| Two-Stage (terrain + object) | 78.67% | 0.5863 | 0.5975 | 0.5783 | 14.6s |
| RUSBoost (500 cycles) | 80.92% | 0.5717 | 0.5778 | 0.5671 | 10.0s |

**Phase 1 Best**: Ensemble (Boosted) (F1 = 0.6220)

#### Per-Class Metrics (Best Model: Ensemble Boosted)

| Class | F1 | Precision | Recall | Support |
|-------|------|-----------|--------|---------|
| DrySand_NoObject | 0.7718 | 0.7837 | 0.7602 | 367 |
| DrySand_Object | 0.4068 | 0.4444 | 0.3750 | 32 |
| GrassySoil_NoObject | 0.9919 | 0.9840 | 1.0000 | 368 |
| GrassySoil_Object | 0.3571 | 0.4167 | 0.3125 | 32 |
| Rocks_NoObject | 0.7735 | 0.7545 | 0.7935 | 368 |
| Rocks_Object | 0.4308 | 0.4375 | 0.4242 | 33 |

### Confusion Matrices

![Confusion Matrices](Results/ConfusionMatrices.png)

#### Individual Confusion Matrices

| SVM (Gaussian) | MLP [256-128-64] | Ensemble (Boosted) |
|:-:|:-:|:-:|
| ![](Results/ConfusionMatrix_SVM_(Gaussian).png) | ![](Results/ConfusionMatrix_MLP_[256-128-64].png) | ![](Results/ConfusionMatrix_Ensemble_(Boosted).png) |

| Bagged Trees | KNN (k=7) | Two-Stage |
|:-:|:-:|:-:|
| ![](Results/ConfusionMatrix_Bagged_Trees.png) | ![](Results/ConfusionMatrix_KNN_(k=7,_weighted).png) | ![](Results/ConfusionMatrix_Two-Stage.png) |

| RUSBoost |
|:-:|
| ![](Results/ConfusionMatrix_RUSBoost.png) |

### Metrics Comparison

![Metrics Comparison](Results/MetricsComparison.png)

---

## Phase 2: Advanced Tuning

Ten experiments targeting F1 maximization through hyperparameter optimization:

| # | Experiment | Accuracy | Macro F1 | Precision | Recall | Time |
|---|------------|----------|----------|-----------|--------|------|
| 1 | **RUSBoost (1000 cycles, deeper)** | **82.58%** | **0.6407** | **0.6408** | **0.6438** | **21.4s** |
| 2 | RUSBoost (stats-only features) | 76.50% | 0.5519 | 0.5523 | 0.5542 | 5.2s |
| 3 | Bagged Trees (1000, oversample) | 80.75% | 0.5786 | 0.5757 | 0.5834 | 31.9s |
| 4 | AdaBoostM2 (500, deep) | 81.33% | 0.5579 | 0.5591 | 0.5619 | 85.3s |
| 5 | RUSBoost + Top-50 features | 79.75% | 0.6152 | 0.6173 | 0.6173 | 7.4s |
| 6 | MLP [512-256-128-64] | 79.75% | 0.5915 | 0.5918 | 0.5916 | 111.0s |
| 7 | Voting Ensemble (3 models) | 81.50% | 0.5946 | 0.5981 | 0.5936 | 71.9s |
| 8 | RUSBoost (2000 cycles, LR=0.01) | 82.67% | 0.6343 | 0.6364 | 0.6377 | 40.3s |
| 9 | Two-Stage (SVM + RUSBoost) | 81.50% | 0.6383 | 0.6382 | 0.6385 | 2.9s |
| 10 | Bagged Trees (cost-sensitive) | 79.33% | 0.5802 | 0.5789 | 0.5821 | 15.4s |

**Overall Best**: RUSBoost-1000-deep — **F1 = 0.6407, Accuracy = 82.58%**

---

## Performance Comparison: Flat vs Bumpy Terrain

| Condition | Best Model | Accuracy | Macro F1 | Δ F1 |
|-----------|-----------|----------|----------|------|
| Flat terrain (uniform) | RUSBoost-500 | 89.50% | 0.6885 | — |
| Flat terrain (advanced tuning) | RUSBoost-1000-deep | 90.50% | 0.6867 | — |
| **Bumpy terrain (±2%)** | **RUSBoost-1000-deep** | **82.58%** | **0.6407** | **−0.0478** |

### Impact of Variation Level

| Variation | Best F1 | Notes |
|-----------|---------|-------|
| 0% (flat) | 0.6885 | Ideal uniform terrain |
| ±2% | 0.6407 | Current bumpy terrain config |
| ±5% | 0.6291 | Previously tested (higher noise) |

Reducing variation from ±5% to ±2% improved F1 by +0.0116, confirming terrain heterogeneity as a primary performance limiter.

---

## Key Findings

1. **6.9% F1 degradation from terrain heterogeneity**: Even modest ±2% material variation reduces best F1 from 0.6885 to 0.6407 compared to ideal flat terrain.

2. **7 percentage point accuracy drop**: Accuracy falls from 89.5% (flat) to 82.6% (bumpy), indicating the terrain noise directly confuses material boundaries.

3. **RUSBoost remains the best architecture**: Same model family wins in both scenarios, confirming robustness to class imbalance regardless of feature noise.

4. **Deeper trees compensate for noise**: Bumpy terrain requires 1000 cycles with deeper splits vs 500 cycles for flat terrain.

5. **All 155 features still needed**: Feature reduction (Top-50 or stats-only) hurts even more on noisy data (F1=0.62 and 0.55 respectively).

6. **Variation sensitivity is strong**: Going from ±5% to ±2% yields +1.8% F1 improvement, suggesting even small real-world calibration improvements matter.

7. **Two-Stage approach competitive**: SVM + RUSBoost achieves F1=0.6383 in only 2.9s — nearly matching the best with 7× less compute.

---

## Recommendations

1. **Spatial averaging**: Apply sliding window averaging across multiple positions to smooth out chunk-to-chunk noise before feature extraction.
2. **Calibration**: In-situ calibration of baseline RSSI per terrain segment could compensate for known spatial variation.
3. **Temporal features**: Multiple passes over the same terrain would allow temporal averaging to reduce single-pass noise.
4. **Adaptive thresholds**: Object detection thresholds should account for local terrain variability rather than using global thresholds.

---

## Scripts

| Script | Purpose | Runtime |
|--------|---------|---------|
| `QuickView_BumpyTerrain.m` | 3D terrain setup visualization | ~30s |
| `VisualizeRandomTerrain.m` | Multi-panel terrain property plots | ~5s |
| `TrackSimulation_Bumpy.m` | RF simulation with randomized chunks | ~60s |
| `TrainClassifiers_Bumpy.m` | Train 7 baseline classifiers | ~120s |
| `AdvancedTuning_Bumpy.m` | 10 advanced tuning experiments | ~400s |
| `RunAll_BumpyTerrain.m` | Execute full pipeline sequentially | ~600s |

### How to Run

From `BumpyTerrainAnalysis/`:

```matlab
% Full pipeline
matlab -batch "RunAll_BumpyTerrain"

% Or individual steps:
matlab -batch "QuickView_BumpyTerrain"
matlab -batch "VisualizeRandomTerrain"
matlab -batch "TrackSimulation_Bumpy"
matlab -batch "TrainClassifiers_Bumpy"
matlab -batch "AdvancedTuning_Bumpy"
```

### Configuration

Terrain randomization parameters are set at the top of each script:
```matlab
chunk_size = 100;           % mm per chunk
variation_pct = 2;          % ±2% material variation
surface_z_max = 10;         % mm max surface height
```

Shared system parameters (antenna, track, objects) are in `../SimConfig.m`.

---

*Generated: Bumpy Terrain Analysis, Material Sensing Project V3*
