# Getting Started

## Requirements

- MATLAB R2024b (or later)
- No additional toolboxes required

## Commands (from CMD)

Generate the 3D setup figure:

```
matlab -batch "QuickView"
```

Run the full RF track simulation:

```
matlab -batch "TrackSimulation"
```

## Configuration

Edit `SimConfig.m` to change shared parameters (track size, object positions, materials, etc.).

All outputs (CSV, .fig, .png) are saved to the `Results/` folder.
