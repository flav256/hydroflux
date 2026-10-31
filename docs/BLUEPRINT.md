# HydroFlux — Master blueprint

Atmospheric puzzle. Black silhouettes, one cyan light, and water that carries it.
Godot 4.x, GDScript, `gl_compatibility`, aimed at a phone and a laptop browser.

`docs/NARRATIVE.md` is still a draft. This file is the build decision. When they disagree, build from this file and then correct the narrative.

## What stays

The Level 0 membrane is the core verb. Two anchors, a quadratic curve, a drop that sits on the upper side, a pull, a release. The player never grabs the drop. They shape the vine and the water decides.

The dashed line is the vine itself. Level 0 also draws the flight the drop will take, so the first throw can be learned. Later vines leave that path off.

The liquid is Gloop. In code that is `Gloop`. It is one body, drawn with viscosity and surface tension: it stretches into a neck, pulls stray beads home, and beads up again instead of staying smeared. Personality is two pinpricks inside it. The game is still called HydroFlux.

## How the drop is built

One `RigidBody2D`. The softness is drawn: the outline conserves volume, flattens where it rests, stretches along its motion, and the bright inside lags the skin.

A ring of `SpringJoint2D` nodes is a later experiment, and only if a chapter cannot be done with one body. A joint mesh fights the vine (the drop is seated on the curve on purpose) and costs too much on a phone. Do not start there.

### Eyes

Two dots, inside the volume, never a mouth or brows.

| Moment | When | What the eyes do |
| --- | --- | --- |
| Waiting | Sitting still, nothing near, about a second | They appear, look up, blink slowly |
| Near | The pointer passes over the drop | The skin shivers. The eyes pinch into a small laugh |
| Held | The vine is pulled and the drop is on it | They go still and look along the pull. The body tightens |
| Flight | Leaving the vine, moving fast | They narrow along the motion and then fade. The drop is water again |
| Fall | A long drop down a shaft | They look down and open a little. No panic face |

Waiting, near, held, flight, and fall are in the game. The eyes fade into the water during flight and look down during a long fall.

### Level 0 liquid response

Gloop stays one main `RigidBody2D`. Its response comes from the incoming speed along the contact normal and the surface normal, not from total speed alone. Tangential speed carries water along a face; normal speed controls the splash.

| Contact | Desired response | Recovery |
| --- | --- | --- |
| Gentle contact | The body squashes and settles. No detached beads. | Returns to its round form while staying supported by the surface. |
| Firm contact | The body spreads along the face and sheds a few small water beads. | Beads arc under gravity, are pulled toward Gloop by surface tension, and merge when they reach it. No bead becomes a second full physics body. |
| Hard contact | A wider splash and a short, visible split. The core mass remains one body. | Detached beads rejoin; the main drop reforms before it continues. No lasting loss of water. |
| Horizontal floor or ledge | Spread sideways, then gather into one supported drop. | It remains on the surface; it must not repeatedly bounce or re-enter splash. |
| Vertical wall | Flatten against the wall and glide down under gravity. | It gathers at an edge or when motion ends, then continues as one drop. |
| Incline | Follow the face in gravity's tangent direction. Shallow slopes allow gathering; steep slopes carry a glide. | The drop rounds up when it reaches a resting place or leaves the face. |
| Ceiling | Spread along the underside and cling briefly. | Slowly gather into one drop, then detach and fall. No indefinite ceiling film. |

Use incoming normal impact speed for the gentle/firm/hard thresholds. Starting values: below 70 px/s, squash without a film; 70–159, spread without satellites; 160–519, spread with two returning beads; 520 and above, a wider split with five returning beads. Tune them in the room, not as hidden constants. A surface film grows over about 0.24 seconds, spans roughly 5.6 drop-radii on a wall and up to 12.4 drop-radii on a horizontal face, and gathers slowly enough to feel viscous. Detached beads use small-mass visual physics (gravity, drag, and attraction) and merge back; they do not collide as independent Gloops. Surface attachment is temporary and ends when the ray can no longer find the face or when a ceiling drop reforms.

Treat this as a state sequence: `AIRBORNE → IMPACT_SPREAD → SURFACE_GLIDE or REFORM → AIRBORNE/RESTING`. The bead satellites exist only during a firm or hard impact and are cleared when they merge. The Level 0 cone, wall, slope, floor, and ceiling all use the same contact rules with different normals and gravity tangents.

### Liquid, then the other temperatures

Temperature is not a move the player selects. The room changes the water.

```
ICE  --heat-->  LIQUID  --heat-->  VAPOR
 ^                ^                  |
 |                |                  v
 +---- cold ------+            hits something cold
                         and condenses back to LIQUID
```

| State | Body | What it is for |
| --- | --- | --- |
| Liquid | Soft, sits on vines, can cling to a tall wall and slide down it | The whole first game |
| Vapor | Rises, ignores the vine, follows a draft | Ember. Born on heat, dies back into a drop on a cold tooth |
| Ice | No squash, slides, does not cling, can break a thin crystal | The cold chapter, after the player trusts liquid |
| Boiling | Still liquid, bubbling, a short timer | A hazard beside extreme heat. Leave, or the drop is gone. Not a fourth toy |

Wall-glide is liquid behavior, not its own chapter. The first tall wall teaches it: the drop flattens and creeps down instead of bouncing off like a marble.

## The verbs, in order

One new verb per chapter. Biomes are the color of that stretch of the game, not a replacement for the order.

| Stretch | Rooms | New thing |
| --- | --- | --- |
| Wet cavern | The First Drop, The Vein, The Thread, The Breath, The Cup, The Dark | Membrane, a second vine, a string of drops, a draft, a bowl that wants volume, then the glow goes out |
| Cold | After The Dark, before heat | Frost. The same drop becomes ice |
| Volcanic | Ember, then The Fall | Heat dries. Steam rises and condenses. Later a sheet, not a marble |

Level 0 is not rebuilt. It already teaches form, sit, pull, release, and the well. A second drop and a pulsing halo are a later room.

### Membrane, and what it can become

Today: hold the drop until the player lets go.

Later, same object, one change at a time:

- A vine that holds, then yields after a short rest, so the drop falls through.
- Two vines in one room. Load one while the other is already moving.
- A vine near heat that shortens until water touches it again.

### What we are not taking from the reference games

- Freehand digging through mud. The silhouette room stays solid. Guiding water is a lip or a vine, not an eraser.
- Spore rings that clone a swarm. A split is a short string of the same water, and those beads merge again when they touch.
- A sponge that becomes a water pistol. A sponge drinks the drop and weeps it back out when the press lifts.
- Trajectory dots, score fireworks, or a named mascot.

## Modules

| Module | File | Job |
| --- | --- | --- |
| Membrane | `scripts/objects/ElasticTendril.gd` | Curve, grab, seat, launch. Already the game |
| Gloop | `scripts/objects/Gloop.gd` | Form, sit, flight, eyes, viscosity, surface tension |
| Well | `scripts/objects/TargetCore.gd` | One arrival now. Volume later |
| Level | `scripts/levels/Level_00.gd` | Phase order for the first room only |
| Routes | `GameManager` | Chapter list, stars, save |
| Sound | `AudioController` | Bed and cues. Recordings live in `assets/audio/` |

`MicroDroplet` does not exist as an independent physics object until The Thread. Level 0 may show short-lived detached beads on a hard impact; they are light cues with gravity and surface-tension attraction, not a swarm or permanent breakage. Sharp scenery does not destroy the main Gloop body.

## Stack

- Renderer: `gl_compatibility`. HTML5 export is single-threaded so it can sit on GitHub Pages.
- Input: touch, and mouse on a laptop. The vine listens in `_input`. Full-screen color rects use `mouse_filter = IGNORE`.
- Boot: splash, then the chapter list. Level 0 is open. Unbuilt rooms are grey. A debug run can still open them.
- Save: `user://hydroflux.save`.

### Collision

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | Cavern | Static rock |
| 2 | Fluid | Drops |
| 3 | Tendril | The vine sensor |
| 4 | Target | The well |

Drops use mask `13` (rock, vine, well).

## Level 0 — The First Drop

A light forms on the tooth, falls, and sits in the vine. Pull back, release, the vine throws it into the well. Stars and a short chime. The bed is the recorded water loop.

Level 0 stays the active build until it reaches game-level quality. Do not start Level 1 until one full run from the menu through formation, membrane, launch, surface response, miss/retry, and well activation works without script errors or a stuck drop. Keep the room to one main drop; do not add a barrier tutorial or paragraph text.

The quality pass covers four connected parts:

- **Style:** silhouettes, water light, motion, and sound should read as one authored world.
- **Behavior and physics:** the drop forms, seats, follows a pulled membrane, launches, responds by impact normal and surface orientation, spreads, glides, briefly splits on hard impact, reforms, clings to a ceiling before falling, and recovers after a miss without getting trapped.
- **Interface:** a first-time player can discover the membrane through the room and its short hint line; touch and mouse both work; a visible map control returns to the chapter list.
- **Finish:** the well gives clear arrival feedback, awards and saves the result, and returns cleanly to the level list.

Keep the checks and remaining work in `docs/ROADMAP.md`. Level 1 is gated on all Level 0 exit checks passing in a real playthrough.

## Non-goals

- A real fluid solver
- A soft-body joint mesh as the default drop
- Online multiplayer
- Paragraphs of tutorial text
- Store builds before a second room feels right on a thumb
