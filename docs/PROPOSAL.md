# HydroFlux — Revamp proposal

Status: proposed on 2026-11-07. Once accepted, fold it into `BLUEPRINT.md`, `NARRATIVE.md` and `ROADMAP.md`, then delete this file. Until then `BLUEPRINT.md` stays the build decision, with one exception: Level 0 surface tuning is frozen.

## Why change course

From a review of the splash, the chapter list and Level 0, rendered in Godot 4.7.2:

- **The premise isn't on screen.** "Light exists only inside the water" is the hook, but the whole cavern is lit teal. The lights on Gloop and the well had no texture, so they gave no light, and no rock cast a shadow.
- **Gloop can't be read as a character.** It is 24 px across with 3 px eyes: about 13 pt and under 2 pt on an iPhone in landscape.
- **Level 0 is a slingshot with an aim line**, solved in one throw. Stars reward speed.
- **The surface behaviors only happen after a miss.** Spread, wall glide, ceiling cling, split and reform are the richest code in the game, and they decorate failure.
- **The story is a premise and a tone.** Nothing says where the water goes, what the well is, or what changes when it is lit.
- **The roadmap lists 13+ toys**, most of them props any physics puzzler has.
- **The tone breaks after the splash:** stock chapter list, stars, points.

## Pillars

1. **Light lives in the water.** Rooms are dark; Gloop is the light.
2. **Don't aim at the goal. Aim at what will carry the water there.** Rooms are solved by what the liquid does after it lands.
3. **The world changes; there is no score.** The reward is a cave that wakes up.

## Light

- Rooms keep a faint backlight (`LevelBase.room_ambient`, about 0.3) so their shapes stay readable. Detail only shows in Gloop's light.
- Gloop's light casts real shadows. Every cavern `CollisionPolygon2D` under a `StaticBody2D` gets a matching `LightOccluder2D` at load.
- **Wet stone remembers.** Where Gloop lands, spreads or glides, it leaves a glow that fades over about 16 s (`WetGlow`). A miss maps the room.
- When the well is fed, the backlight blooms to full (`bloom_ambient`).
- The Dark, the last room of Act 1, has no backlight at all.

## Surface behaviors become tools

Put the well where a direct throw can't reach it.

| Behavior | Room use |
| --- | --- |
| Wall glide | Bank the drop down a face into a well below |
| Ceiling cling | Stick it to the roof above a pit; it drips straight down |
| Slope | Roll it along a lip into a pocket |
| Hard split | Beads reach two places at once |

Only the first room shows the flight path.

## The well is alive

A closed root or seed that drinks the light. Fed, it blooms, and glowing veins run through the black rock to the next room's entrance. The only optional goal: one or two sleeping pods per room that show only in Gloop's light. No stars, points or timer.

## Story: the water cycle

The spring that lit the deep cave has run dry. One drop forms on the last wet stone, and it still glows. Gloop doesn't know the way, but water does: down through the cave, into the cold, into the heat, up as vapor and back as rain. The last scene refills the spring and the first stalactite forms a drop again, so the splash screen is also the ending.

| Act | Water | New behavior | Opening line (draft) |
| --- | --- | --- | --- |
| Seep | Liquid | Throw, glide, drip, split and merge | "The spring went dry. One stone stayed wet." |
| Frost | Ice | Slides, won't cling, breaks thin crystal, thaws on warm stone | "Deeper, the water forgets how to run." |
| Ember | Vapor | Rises, ignores the vine, follows drafts, condenses on cold rock | "Then heat. The water lets go of its shape." |
| Rain | Many drops | Guide the rain back into the spring | "Up through the stone. Then down." |

Cut the props that aren't water: sponge, valve, shade, channel. The Breath moves to Ember; The Cup becomes the Rain finale.

**Text:** one line at the start of each act; read in order, they tell the story. Inside a room, at most three lines: while forming, while waiting, after the first miss.

## Chapter 1 — Seep

Eight rooms, one idea each, all built from the vine, Gloop and the well.

| # | Room | Idea |
| --- | --- | --- |
| 1 | The First Drop | Throw. Flight path shown. Dim room, living well |
| 2 | The Wall | Well under an overhang: glide down the pillar face |
| 3 | The Roof | Well in a pit: cling to the roof, drip |
| 4 | The Vein | Two vines: throw onto the second |
| 5 | The Lip | Roll along a slope into a pocket |
| 6 | The Thread | Hard split: two pods must drink |
| 7 | The Shelf | A ledge you can only find by its wet glow |
| 8 | The Dark | No backlight. Only the drop and what it wets |

## Presentation

- Gloop radius 12 → about 24 px; eye sizes derived from `base_radius`, not fixed pixels.
- Vine: a black strand with an inner channel that glows where wet. No dashes.
- The chapter list becomes a map of the cave that lights up room by room.
- Win: the room blooms and the camera follows the vein to the next room.

## Sound

- Per-room beds cut from the recordings in `sound/`.
- New cues: a wet hiss when a film spreads, a drink when the well takes the drop, a slow chord as the vein lights, a fiber stretch that rises with tension (`TENDRIL_STRAIN` exists but has no sound).
- The Dark drops the bed. Only the drop is heard.

## Order of work

0. **Light spike** (in progress): textured light, rock shadows, wet glow, dim backlight, bloom on win. Done when the dim room reads on a phone.
1. Design the 8 rooms on paper: geometry, intended solution, likely misses.
2. Split `Gloop.gd` (725 lines) into body, surface and face files so later tasks read only what they touch.
3. Add a solve probe: scripted pulls per room that print one JSON line (reached the well or not).
4. Greybox rooms 2–8 with existing objects only.
5. Playtest with three people who haven't seen the game. Gate: the rooms produce "aha" moments without text.
6. Add mechanics only where rooms demand them (second vine, split into bodies, The Dark).
7. Presentation and sound passes. Then Frost.

## Token budget and agent plan

Estimate for steps 0–7: the revamp plus all of Chapter 1. It excludes human playtests, recording or buying audio, store builds, and Acts 2–4.

Tokens are counted as an agent processes them: context size × turns. About 90% are cache reads.

| # | Work | Model | Input (M) | Output (k) |
| --- | --- | --- | --- | --- |
| 1 | This proposal, then fold it into the docs | Opus | 0.6 | 20 |
| 2 | Light spike | Opus | 1.5 | 25 |
| 3 | Room designs ×8 | Opus | 1.0 | 35 |
| 4 | Split `Gloop.gd` | Sonnet | 0.8 | 20 |
| 5 | Solve probe harness | Sonnet | 0.8 | 12 |
| 6 | Greybox rooms 2–8 from the designs | Haiku | 4.0 | 90 |
| 7 | Run probes and frame checks, 8 rooms | Haiku | 2.5 | 15 |
| 8 | Mechanics: second vine, split and merge, The Dark | Sonnet | 5.0 | 80 |
| 9 | Presentation: bigger Gloop, vine, living well, bloom, no scoring | Sonnet | 4.5 | 70 |
| 10 | Cave map | Sonnet | 1.2 | 20 |
| 11 | Act lines (Opus) and wiring (Haiku) | Opus + Haiku | 0.4 | 6 |
| 12 | Sound: cue design and wiring (Sonnet), asset trimming (Haiku) | Sonnet + Haiku | 2.0 | 25 |
| 13 | Silhouette art plates, 8 rooms | Sonnet | 3.5 | 90 |
| 14 | Two rounds of playtest fixes | Sonnet | 6.0 | 80 |
| 15 | Milestone reviews of diffs, ×4 | Opus | 2.0 | 20 |
| | **Total** | | **≈36M** | **≈610k** |

Expect ±50%; rework after playtests is the main unknown. A realistic range is 25–55M tokens processed.

Cost at API list prices (Opus 5.5 $4/$20 per M input/output, Sonnet 5.5 $2/$10, both $0.20 per M cache reads; Haiku 5.5 $0.10/$0.50 for prompts up to 100K tokens):

| Plan | Cost |
| --- | --- |
| All Opus | ≈ $33 |
| All Sonnet | ≈ $20 |
| Mixed, as above | ≈ $18 |

On a subscription, the token counts are what count against usage limits; the costs are the API equivalent.

### What actually saves tokens

Model choice changes the price per token far more than the number of tokens. Opus and Sonnet cache reads cost the same, so moving bulk work from Opus to Sonnet saves about 40%, not 2×. Haiku is the big price lever, but only for mechanical work with an exact spec. The token count itself only falls with smaller contexts and fewer turns:

1. **One fresh worker per work package.** The orchestrating session keeps summaries, never file dumps. A long session re-reads its whole history on every turn.
2. **Briefs carry file:line pointers** and the exact acceptance check. Never "read the codebase".
3. **Split `Gloop.gd` first** (step 2). Most tasks read it; at ~9k tokens it costs ~350k per 40-turn session.
4. **Verify with probe output, not screenshots.** One JSON line is ~100 tokens; a screenshot is ~700–1,200. Two images per room at most.
5. **Keep Haiku prompts under 100K tokens.** Past that, its price is five times higher.
6. **People judge feel.** Agents check that a room is solvable and free of errors, not whether it is fun.

### Roles

- **Opus (orchestrator, design, review):** room designs, act lines, milestone reviews. Reads diffs and probe output only.
- **Sonnet (builder):** systems, mechanics, presentation, art plates, fixes.
- **Haiku (runner):** greyboxing from coordinate specs, running probes, renames, asset trimming with ffmpeg.

In Claude Code, run the orchestrator in the main session and start each worker with the Agent tool's `model` option (`sonnet`, `haiku`): one work package per worker, independent packages in parallel.
