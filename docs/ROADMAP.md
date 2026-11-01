# HydroFlux — Development roadmap

`docs/NARRATIVE.md` is a working draft. `docs/BLUEPRINT.md` is the build decision. This file is the order we will actually make things.

The playable page is [https://flav256.github.io/hydroflux/](https://flav256.github.io/hydroflux/). Source is on `main`. App Store and Play Store builds do not exist yet.

## Where we are

**Current focus: Level 0 quality.** Level 1 stays blocked until the Level 0 exit checks below pass in a full playthrough.

- [x] Splash, then the Chapter 1 list. Level 0 is playable. Later rooms are grey.
- [x] Membrane. The drop sits, follows the pull, and leaves on release.
- [x] The vine is a dashed curve. Level 0 shows the flight path while you pull. Later rooms do not.
- [x] Eyes while waiting, while the pointer passes over, and while the vine is held.
- [x] Recorded water for the bed and the cues.
- [x] Stars, points, save.
- [x] HTML5 on GitHub Pages. One tap starts the sound. A phone stays sideways.
- [x] Verify Gloop is visible while seated in the exported HTML. The live Pages build now shows Gloop on the membrane with its face, glow, and falling trail visible. The previous render order let the thick membrane cover it.
- [x] Republish the current web export after the live page was found behind the source branch. Pages now serves the export built from the current Level 0 source, including the visibility and visual polish changes (`gh-pages` commit `744f010`).
- [x] Liquid hitting the Level 0 cone splashes and runs down the face instead of tumbling.
- [x] Eyes in flight and in a long fall
- [x] Hand-drawn silhouette plates instead of generated polygons

## 0 — Finish the liquid drop

The membrane stays. This pass finishes the style, behavior, interface, and physics of the first room before any Level 1 work begins. The response rules are specified in `docs/BLUEPRINT.md`; implement and tune them in this order:

- [x] In flight the eyes narrow and fade. In a long fall they look down.
- [x] The Level 0 cone splashes and the drop runs down the face.
- [x] Capture pre-solver velocity and read its normal speed separately from tangent speed; gentle impacts squash, firm/hard impacts spread. Thresholds are exported for tuning.
- [x] Firm impacts emit a few temporary beads; hard impacts emit a short split. Beads are attracted back to the one main Gloop body.
- [x] Ceiling contact spreads, waits briefly, reforms slowly, and drops as one body.
- [ ] Tune all surface responses in a visible Level 0 playthrough. Current target is a 6–13.2 radius span and no more than 0.52 spread units/second on broad faces and shallow inclines.
- [ ] Tune the new slow caustic and light-shaft pass at iPad scale; check that the animation supports the puzzle focus and remains smooth in WebGL.
- [ ] Tune Gloop's new specular highlight on the free body and surface film so it reads as wet volume rather than a flat cyan shape.
- [ ] Check 60/120 Hz motion and touch-to-render response. Physics interpolation is off; enable it only after launch, membrane seating, and surface repositioning are verified without visual streaks.
- [ ] Horizontal faces spread and gather without bounce loops. Collision probe entered film at the expected upward-facing normal (spread 0.58 at 1.2 s; gathered back to one drop by 3.8 s); visible feel and bounce behavior still need tuning.
- [ ] Vertical faces cling and glide down under gravity. Collision probe entered film with a horizontal normal (spread 0.89 at 1.2 s) and was still flowing lower on the wall at 3.8 s; visible glide speed and release need tuning.
- [ ] Slopes carry the drop along gravity's tangent, with shallow slopes allowing it to gather. Collision probe entered film with the expected diagonal normal (spread 0.58 at 1.2 s); it flowed to the lower edge by 3.8 s. Recheck on the authored Level 0 surfaces.
- [x] Ceiling contact spreads, clings through the hold, gathers, then falls. A probe using the actual Level 0 roof now confirms impact-normal orientation, a full cling, gradual reformation, and detachment into a fall by 3.8 s. Still needs visible feel tuning.
- [x] Use authored silhouette plates for Level 0 scenery, with collision geometry kept separate.
- [x] Directly loading Level 0 spawns one Gloop after formation; no GDScript errors.
- [ ] Verify the menu-to-Level-0 handoff in the current working build. The published Pages build was played through Splash → Chapter 1 → Level 0; it predates these local changes.
- [ ] Complete the full loop: seat, pull, launch, miss and retry, then activate the well.
- [x] Disconnect membrane physics callbacks on teardown; clean shutdown no longer calls freed level nodes.
- [x] Keep a visible route from Level 0 back to the chapter list.
- [ ] Verify mouse and touch input, readable hints, and clear win feedback. Membrane drag and Gloop's near-hand response now use shared `InputManager` world coordinates for both devices.
- [ ] Tune the drop, membrane, light, and sound together in a full playthrough.
- [x] Keep one main rigid body and no joint ring; impact beads remain temporary visual satellites.

**Exit:** every check above passes in a full playthrough on desktop and a touch device. Only then begin Level 1 — The Vein.

## 1 — The Vein

Same vine, a second one, and a vine that does not hold forever.

- Two membranes in one room. One is already loaded while you touch the other.
- A membrane that carries the drop for a short rest, then lets it through.

**Exit:** someone finishes the room with no new sentence on screen.

## 2 — The Thread

- One drop becomes a short string of smaller drops.
- Small drops fit a narrow gap.
- Drops that touch pull together and become one body again.
- Nothing in Level 0 shatters.

## 3 — Breath and the sponge

- A vent: tap flicks, hold is a draft.
- A sponge: press to drink the drop, release and it weeps back out.

## 4 — The Cup, then The Dark

- The well wants volume. A pool has one surface. A vine lifts the surface.
- Then the background glow dies. Miss the drop and the room goes quiet. No new control.

## 5 — Cold

Only after liquid rooms are in the Pages build.

- Frost. The drop becomes ice: it slides, it does not cling, it can break a thin wall.
- Heat brings it back to liquid.

## 6 — Ember

- Heat dries a pool.
- Steam rises, ignores the vine, and condenses on a cold tooth.
- Beside extreme heat the drop boils. That is a timer, not a new move.
- A sheet of water comes after steam works, guided by a lip.

## 7 — Phones

- iOS and Android export presets
- A real-phone grab, larger than the laptop one
- Haptics on the snap and on the well
- TestFlight and an internal Android track before any public store page

## Not in this roadmap

- A fluid solver, or a SpringJoint drop as the first refactor
- Digging tunnels through the rock
- Cloning swarms
- A named mascot, or a mouth. A flight path only on Level 0.
- Level editors
- Paragraphs of story text
