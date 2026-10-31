# HydroFlux — Roadmap

Status: **Level 0 scaffolded from the Gemini POC**. Next: run in Godot, then water-stream feel, then levels.

## Now — Milestone 0 (this repo)

- [x] Godot 4 project tree (`assets`, `scenes`, `scripts`)
- [x] Production scripts: tendril, droplet (form/detach/squash), target, Level 0 phases
- [x] Autoloads: GameManager, AudioController, InputManager
- [x] Main menu → Level 0
- [ ] Open in Godot 4.3+ and play Level 0 end-to-end
- [ ] Drop in ambient + snap audio under `assets/audio/`
- [ ] Silhouette art pass (replace debug polygons)

## Milestone 1 — Playable vertical slice (Level 0 shippable)

- Tune sling so a downward pull consistently clears the barrier
- Stalactite drip animation (shader or sprite frames)
- Pooling: 2–4 droplets in the left basin look like a small volume of water
- Victory chime + cavern light ripple
- HTML5 export (`gl_compatibility`, single-thread) + itch.io draft

**Exit:** a stranger can finish Level 0 on phone without instructions.

## Milestone 2 — Fluid language

- Droplet clusters with soft collision damping
- Merge-on-contact (optional: combine radii, cap count)
- Air jets / vents (tap impulse fields)
- Second tendril in one scene
- Simple refraction / glow shader on the liquid

**Exit:** water reads as a stream, not only isolated balls.

## Milestone 3 — Campaign spine

| Level | Teaching |
| --- | --- |
| 00 | Gravity, one tendril, one core |
| 01 | Timing: drop while vine is loaded |
| 02 | Two tendrils, split path |
| 03 | Air jet + tendril |
| 04 | Volume: fill the core with a pool, not one drop |
| 05 | Darkness: light only follows the water |

- Level select, unlocks already stubbed in `GameManager`
- Pause / restart HUD

## Milestone 4 — Mobile store path

- iOS + Android export presets
- 120 Hz input sampling, no physics hitch on mid devices
- Haptics on snap / absorb
- Accessibility: color-blind safe cyan+white cores, larger grab radius option

## Milestone 5 — Atmosphere pack

- Hand-drawn cavern plates
- Cello / water SFX set
- Dynamic bloom masks
- Trailer scene (no gameplay)

## Explicit later / maybe never

- True SPH or Navier–Stokes
- User-generated levels
- Narrative text chapters

## Suggested next session (after GitHub)

1. Install Godot 4.3+ and import this folder.
2. F6 `scenes/levels/Level_00.tscn`.
3. Tune launch so Phase 3 is reliable.
4. Add two audio files: drip + snap.
5. Start Level 01 scene cloned from Level 00.
