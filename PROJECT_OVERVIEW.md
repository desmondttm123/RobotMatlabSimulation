# MaterialSensingProjectV3 - Project Overview

## Summary

RF-based material identification system combining physics simulation (ray tracing), antenna arrays, and machine learning classifiers to identify materials from received signal patterns.

---

## Project Structure

| Folder | Role |
|--------|------|
| `Simulation/` | Main simulation with custom conductivity/permittivity per material |
| `SimulationObstacle/` | Alternative simulation using pre-built 3D obstacle models (.glb) |
| `DESKTOP FILES/` | Older version + analysis/plotting scripts + saved figures |
| `RobotSimulationAnalysis/` | New work (this folder) |

---

## Main Scripts

### Core Simulation
| Script | Purpose |
|--------|---------|
| `Simulation/SimulationScript.m` | **PRIMARY ENTRY POINT** - Full simulation pipeline: antenna setup → ray tracing → ML training → export |
| `SimulationObstacle/ObstacleSimulation.m` | Alternative approach using 3D scene models instead of direct material properties |

### Classifiers & Training
| Script | Algorithm |
|--------|-----------|
| `Simulation/trainClassifier_MLP.m` | Neural Network (2-layer, 274→294 nodes) |
| `Simulation/trainClassifier_SVM.m` | SVM (One-vs-One ECOC, Polynomial kernel) |
| `Simulation/trainClassifier_TREE.m` | Bagged Decision Trees |

### Testing & Analysis
| Script | Purpose |
|--------|---------|
| `Simulation/SimulationTester.m` | k-fold cross-validation, accuracy calculation |
| `Simulation/SimulationClassifier.m` | Applies trained classifiers to new data |
| `Simulation/Graph_Plotter.m` | Accuracy plots across power levels, distances, antenna counts |

---

## 3D Geometry Files

| File | Location | Purpose |
|------|----------|---------|
| `Material.stl` | `Simulation/` | Generic material slab for ray tracing |
| `Chamber.stl` | `Simulation/` | Chamber/containment geometry |
| `Scene_concrete.glb` | `SimulationObstacle/` | Concrete wall model |
| `Scene_human.glb` | `SimulationObstacle/` | Human body obstacle |
| `Scene_metal.glb` | `SimulationObstacle/` | Metal plate/frame |
| `Scene_wood.glb` | `SimulationObstacle/` | Wood obstruction |

---

## Materials (12 Total)

Each material is defined by conductivity (σ) and relative permittivity (ε_r):

| Material | Conductivity (S/m) | Permittivity | Category |
|----------|-------------------|--------------|----------|
| ABS | 1.0e-16 | 3.2 | Plastic |
| Acrylic | 1.0e-13 | 3.5 | Plastic |
| Ceramic | 1.0e-10 | 50.0 | Ceramic |
| Concrete | 1.0e-7 | 6.0 | Construction |
| Glass | 1.0e-15 | 5.0 | Transparent |
| HDPE | 1.0e-19 | 2.3 | Plastic |
| Human | 0.1 | 30.0 | Biological |
| Metal | 3.8e7 | 1.0 | Conductor |
| PolyCarbonate | 1.0e-18 | 3.0 | Plastic |
| Polyethylene | 1.0e-17 | 2.1 | Plastic |
| RubberWood | 1.0e-13 | 2.7 | Wood |
| Styrofoam | 1.0e-15 | 1.7 | Foam |

### How Materials Are Configured

**Method 1: Direct (SimulationScript.m)**
```matlab
MaterialConductivity = 10e-16;
MaterialPermitivity = 3.2;
```

**Method 2: Via 3D Models (ObstacleSimulation.m)**
```matlab
viewer = siteviewer(SceneModel="Scene_concrete.glb", ShowEdges=true);
```

---

## Antenna Array Configuration

- **Total Antennas**: 32 RX + 1 TX = 33 active
- **Array Layout**: Grid arrangement of RX antennas around the TX
- **Scalable**: Parameter `AntennaNumberHalf` allows 8, 16, or 32 antenna configurations
- **Features**: 64 RF features total (32 RX × 2 for low/high power pairs), named `RF1`–`RF64`

---

## Key Parameters

| Parameter | Range | Purpose |
|-----------|-------|---------|
| `Distance_From_Material` | -0.1 to -1 m | Distance between array and test material |
| `Power_Iterate` | -100 to +100 dBm | Transmitter output power |
| `AntennaNumberHalf` | 8, 16, 32 | RX antenna count |
| `RayPath` | 2–10 | Max reflections in ray tracing |
| `NumberOfDataSets` | 100–3600 | Samples per material |

---

## Pipeline

1. Configure antenna array (32 RX + 1 TX)
2. Loop over power levels (-100 to +100 dBm)
3. For each power level, simulate all 12 materials via ray tracing
4. Collect RSSI data (64 features)
5. Train classifiers (MLP, SVM, Bagged Trees)
6. Export results to `Data.xlsx`
7. Generate confusion matrices and accuracy plots
