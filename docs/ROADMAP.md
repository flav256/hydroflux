# HydroFlux — Development roadmap

`docs/NARRATIVE.md` is a working draft. Chapter names, order, and verbs will change as we play. This file follows the build, not a locked story.

Godot 4 can ship this to the web, the App Store, and Google Play. None of those builds exist yet.

Godot 4 can ship to the web, the App Store, and Google Play. The game is not store-ready yet. The path is: finish Level 0 by hand, export HTML5, then mobile signing.

## Where we are

- [x] Splash, then Chapter 1 list. Level 0 is playable. Later rooms are grey, and openable in a development run.
- [x] Membrane holds a drop. Desktop drag uses the mouse button, not emulated touch.
- [x] One-line hint on Level 0
- [x] Stars (clear, few misses, fast) and points, kept per level
- [x] Level 0 bed, drop, and a short completion chime
- [ ] Replace the generated bed with a recorded piece if the loop feels thin
- [ ] Hand-drawn silhouette plates instead of generated polygons

## 0 — Level 0 you can finish with a thumb

- Pull-back throw lands in the well without a perfect angle
- Hint line only, then silence on the next attempt if they already understood
- Drip, vine, snap, well: four sounds
- Double-click `play.command`, or Godot → F5

**Exit:** someone else finishes Level 0 with no spoken help.

## 1 — The Vein and The Thread

Chapters 1 and 2 from the narrative.

- Second membrane in one room
- A counted gate (two drops, not one)
- Drops that share a pace but do not merge yet

## 2 — Breath and Cup

- Vent: tap and hold
- Drops that merge into a pool with one surface
- A well that wants volume

## 3 — The Dark

- Background glow fades. Miss the drop and the room goes quiet and black.
- No new control. The same vine, with the safety of the glow removed.

## 4 — Online

- Godot HTML5 export, `gl_compatibility`, single thread
- Zip and publish on itch.io at 1280×720
- This is the first public build. No store account required.

## 5 — Phones

- Export presets for iOS and Android
- Apple Developer account, signing, and a privacy label for the App Store
- Play Console listing for Android
- Haptics on snap and on the well
- Larger grab, tested on a real phone

**Exit:** TestFlight and an internal Android track, not a public store launch, until Level 0 and Level 1 feel right on a thumb.

## 6 — Ember and The Fall

Only after the first five chapters are in the online build.

- Heat dries a pool. Steam rises and condenses.
- A sheet of water guided by a lip, not a single drop
- Sound: hiss, crackle, a thinner room tone

## Not in this roadmap

- A real fluid solver
- Level editors
- Paragraphs of story text
