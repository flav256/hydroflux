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

Teach by the room. Level 0 may show one short line. Later levels stay quiet.

The story in `docs/NARRATIVE.md` is a working draft. Chapters, verbs, and the order of rooms will change as we play. Do not treat that file as a locked script.

## Stack

- Engine: Godot 4.x, `gl_compatibility` renderer (mobile + HTML5).
- Physics: 2D rigid bodies for droplets, custom spring for tendrils.
- Input: real touch, and mouse on desktop. The tendril listens in `_input` and converts with the viewport canvas transform. Full-screen `ColorRect` nodes use `mouse_filter = IGNORE` so they cannot eat the drag. Mouse emulation of touch is off.
- Boot: Splash → level select → level. Chapter 1 rooms that are not built stay grey. A debug run of Godot can still open them.
- Score: up to 3 stars (cleared, at most one miss, under the level’s time). Points follow the stars, with a small penalty for extra misses. Best stars and best points are kept.
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
| `GameManager` | Level list, routing, stars, points |
| `AudioController` | Looping bed and one-shot cues |
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

Two fixed anchors, quadratic bezier through a dragged midpoint, clamp to `max_stretch_distance`. The drop sits on the upper side of the curve and stays there until release. On release: restorative impulse, then the vine springs back without pulling the drop through. Desktop: press on the vine, drag, release the mouse button anywhere.

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

1. A light forms on the stalactite and settles on the vine.
2. One line tells you to pull the vine back, then release.
3. The snap throws it into the well. Stars and points appear, with a short chime. The bed is `assets/audio/level0_bed.wav`. The drop is `drop.wav`.

## Boot

Splash, then the chapter list. Level 0 is open. The other Chapter 1 rooms are grey until they exist. In a development run they can still be opened.

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
