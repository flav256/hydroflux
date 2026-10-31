# HydroFlux - Level 0: The First Drop (Godot 4.x)

## Quick Start
1. Download or copy the project files into your Godot project folder.
2. Open **Godot Engine 4.2+ or 4.3**.
3. Import or open `project.godot`.
4. Open `res://scenes/levels/Level_00.tscn` and press **F6** (or "Play Current Scene").

## Scene Hierarchy
- `Level_00` (Node2D, script: `Level_00.gd`)
  - `WorldEnvironment` (Glow bloom enabled for bioluminescent cyan droplets)
  - `CanvasModulate` (Atmospheric darkness mask)
  - `CavernGeometry` (StaticBody2D with cavern silhouette collision polygons)
  - `ElasticTendril` (Node2D, script: `ElasticTendril.gd` - Slingshot controller)
  - `TargetCore` (Area2D, script: `TargetCore.gd` - Receptacle)
  - `Camera2D` (Smooth position damping)
  - `AmbientParticles` (CPUParticles2D bioluminescent dust motes)

## Core Controls
- **Touch / Left Mouse Drag**: Drag the elastic tendril midpoint to stretch like a bowstring.
- **Release**: Tendril snaps back with elastic impulse force, catapulting fluid droplets colliding with it across the cavern barrier.
