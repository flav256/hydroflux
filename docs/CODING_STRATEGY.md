# HydroFlux — Coding Strategy

How we implement the blueprint without melting mobile GPUs or the scene tree.

## Principles

1. **One concern per node.** Tendril does sling physics. Droplet does liquid feel. Level scripts only sequence.
2. **Compose scenes.** `Level_00.tscn` instances `Gloop.tscn`, `ElasticTendril.tscn`, `TargetCore.tscn`. Do not duplicate object scripts inside the level file.
3. **Exported tunables.** Feel lives in `@export` on the instance (stiffness, gravity_scale, spawn interval). Code stays generic.
4. **Signals over polling.** `tendril_released`, `core_activated`, `absorbed_by_target`.
5. **Godot 4 typed GDScript.** `bool` not `boolean`, `float` not `number`, `get_node_or_null`, typed arrays when cheap.
6. **Mobile first.** CPUParticles2D, `gl_compatibility`, few PointLights, no per-frame mesh rebuilds beyond the tendril Line2D.
7. **POC is archive.** `poc/gemini-level-0` is the Gemini dump. Production code lives at `res://`. Do not “fix” the POC in place.

## Implementation order (always)

1. Make it playable (input → physics → win).
2. Make it feel (squash, glow, audio cues).
3. Make it shippable (menu, save, export).

Do not add a new mechanic until Level 0 is completable in Godot.

## Script rules

- `class_name` on reusable objects only (`ElasticTendril`, `Gloop`, `TargetCore`, `LevelBase`).
- Autoloads: no `class_name` (name collision with the singleton).
- Input coordinates go through `InputManager`. Never mix `event.position` and `global_position` raw.
- `_draw()` is for silhouettes and glow discs. Heavy VFX later = shaders in `assets/shaders/`.
- No `print` in shipped flow except temporary debug; prefer signals.

## Scene rules

- CollisionPolygon2D + child Polygon2D for cavern silhouettes (same points).
- Packed scenes for anything spawned (`Gloop`).
- Main scene is `MainMenu.tscn`. F6 on `Level_00.tscn` is valid for iteration.

## Agent / PR workflow

- Small vertical slices: one object or one level phase per change.
- Keep docs in `docs/` in sync when architecture changes.
- Cursor rules in `.cursor/rules/` encode this file; update both together.

## Feel targets (Level 0)

| Parameter | Starting value | Notes |
| --- | --- | --- |
| Gravity | 550 | `project.godot` 2D default |
| Droplet gravity_scale | 1.15 | Slightly heavy light |
| Max stretch | 120 px | Tendril instance |
| Launch multiplier | 9.2 | Tunable in editor |
| Form duration | 0.85 s | Drop animation |

Tune in the inspector, not with magic numbers in Level_00.gd.

## Testing

1. Open Godot 4.3+ → Import `project.godot`.
2. Play MainMenu → Play Level 0.
3. Also F6 `Level_00.tscn` for fast iteration.
4. Desktop: click-drag the vine. Mobile: touch-drag.
5. Win condition: one drop in the core after a launch.
