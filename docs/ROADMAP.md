# HydroFlux — Development roadmap

`docs/NARRATIVE.md` is a working draft. `docs/BLUEPRINT.md` is the build decision. This file is the order we will actually make things.

The playable page is [https://flav256.github.io/hydroflux/](https://flav256.github.io/hydroflux/). Source is on `main`. App Store and Play Store builds do not exist yet.

## Where we are

- [x] Splash, then the Chapter 1 list. Level 0 is playable. Later rooms are grey.
- [x] Membrane. The drop sits, follows the pull, and leaves on release.
- [x] The vine is a dashed curve. Level 0 shows the flight path while you pull. Later rooms do not.
- [x] Eyes while waiting, while the pointer passes over, and while the vine is held.
- [x] Recorded water for the bed and the cues.
- [x] Stars, points, save.
- [x] HTML5 on GitHub Pages. One tap starts the sound. A phone stays sideways.
- [x] Liquid hitting the Level 0 cone splashes and runs down the face instead of tumbling.
- [x] Eyes in flight and in a long fall
- [ ] Hand-drawn silhouette plates instead of generated polygons

## 0 — Finish the liquid drop

The membrane stays. This pass only changes the body.

- In flight the eyes narrow and fade. In a long fall they look down.
- The Level 0 cone splashes and the drop runs down the face.
- Hit a vertical wall: flatten, stick, creep downward. No marble bounce.
- Still one rigid body. No joint ring.

**Exit:** Level 0 feels the same to throw, and a test wall shows the cling.

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
