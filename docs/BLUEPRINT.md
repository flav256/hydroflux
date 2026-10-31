# HydroFlux — Technical Blueprint

Atmospheric physics-based fluid puzzler inspired by *Contre-Jour*.
Built in **Godot 4.3+** (GDScript), targeting iOS and Android at 60/120 FPS.

## Aesthetic

| Token | Value |
| --- | --- |
| Background | `#09090b` charcoal / obsidian |
| Fluid | `#06b6d4` bioluminescent cyan |
| Rock | near-black silhouettes, no outlines |
| Particles | soft neon dust, low count |
| Audio | ambient pads, water drops, cello swells on interaction |

Teach by environment, not pop-up walls of text.

## Stack

- Engine: Godot 4.x, `gl_compatibility` renderer (mobile + HTML5).
- Physics: 2D rigid bodies for droplets, custom spring for tendrils.
- Input: multi-touch + mouse fallback (`emulate_touch_from_mouse`).
- Saves: `user://hydroflux.save` via `GameManager`.

## Architecture

```
InputManager          viewport → world coordinates
     │
ElasticTendril        bezier + spring + launch impulse
     │
FluidDroplet          form → fall → squash → absorb
     │
TargetCore            volume threshold → victory
     │
LevelBase / Level_00  phase machine
     │
GameManager           scenes, unlocks, pause
AudioController       cue playback (silent until streams exist)
```

### Autoloads

| Name | Role |
| --- | --- |
| `GameManager` | Level routing, unlocks, pause |
| `AudioController` | Named SFX / ambient cues |
| `InputManager` | Touch/mouse to local/world space |

Do not put gameplay logic in autoloads. Levels own flow; objects own physics.

### Collision layers

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | Cavern_Geometry | Static rock |
| 2 | Fluid_Droplets | RigidBody2D drops |
| 3 | Elastic_Tendril | Tendril Area2D |
| 4 | Target_Receptacle | TargetCore |

Droplets collide with geometry (1), tendril (3), and core (4). Mask `13`.

## Core systems

### Elastic tendril

Two fixed anchors, quadratic bezier through a dragged midpoint, clamp to `max_stretch_distance`. On release: restorative impulse on overlapping droplets + damped harmonic rebound of the vine.

### Fluid droplet

1. **Form** at a spawner (frozen, scale-in teardrop).
2. **Detach** (unfreeze, gravity).
3. **Flight** velocity-aligned stretch.
4. **Impact** short squash, optional splash cue.
5. **Absorb** tween into TargetCore.

Streams later: clusters of droplets with soft damping, not a GPU fluid sim on mobile v1.

### Target core

Area2D volume counter. Glow fill ratio = `current / required`. Emits `core_activated` once.

## Level 0 — The First Drop

1. **Observation (0–5s)** — one drop forms on the stalactite, falls into the left basin.
2. **Tendril (5–15s)** — barrier blocks the path; vine pulses; player drags.
3. **Launch** — snap sends a drop over the barrier into the core.

## File map

```
res://
├── assets/{audio,shaders,textures}
├── scenes/{core,ui,levels,objects}
├── scripts/{managers,objects,levels,ui}
├── docs/{BLUEPRINT,CODING_STRATEGY,ROADMAP}
└── poc/gemini-level-0   # original Gemini export, not loaded by the game
```

## Non-goals (v1)

- Full Navier–Stokes / SPH fluid
- Online multiplayer
- Heavy 3D lighting
- Text-heavy tutorial overlays
