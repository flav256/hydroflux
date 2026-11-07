# Chapter 1 — Seep: room designs

Status: paper design, step 1 of `docs/PROPOSAL.md` (2026-11-07). Step 4 greyboxes the rooms from this file. Step 3's solve check uses the pulls listed for each room.

## Conventions

- **Coordinates.** World is 1280×720 with y pointing down. Every `StaticBody2D` sits at the origin, so polygon points are world points. Each polygon is one `CollisionPolygon2D` and gets a shadow-caster from `LevelBase.setup_light_room`. The one exception is the hidden shelf in room 7.
- **Shorthand.**
  - `roof(x)` is the roof band with a spawner tooth at x: `(0,0) (1280,0) (1280,110) (x+20,110) (x,147) (x-20,110) (0,110)`. The spawner sits at `(x,160)`, directly above the middle of the vine.
  - `lwall` = `(0,110) (30,110) (30,720) (0,720)`
  - `rwall` = `(1250,110) (1280,110) (1280,720) (1250,720)`
- **Vines.** An `ElasticTendril` at the listed position. Anchors are (−95,0) and (95,0) unless stated. All vines use Level 0's `max_stretch_distance` 220 and `launch_force_multiplier` 5.5, so the top speed is about 1860 px/s. Only room 1 shows the flight path.
- **Pull.** A pull means `vine._begin_drag(vine.rest_midpoint + pull, -1)`, then `_release_tendril()`, as in `scripts/dev/LightProbe.gd`.
  - Angles in this file are measured from +x toward +y: 90° pulls straight down, and 180° pulls straight left, which launches the drop to the right.
  - The drop launches from `anchor_mid + (pull + (0,26))/2 − (0,26)`.
- **Wells drink bodies, not films.** While the drop is a film it has `collision_layer = 0` (`Gloop.gd:558`), so the well's `body_entered` (`TargetCore.gd:40`) never fires for it. Every carrier must therefore end with the drop leaving the surface as a body:
  - a fall off a free edge,
  - a drip,
  - or a roll.

  When a film leaves a surface, it starts falling at (0, 90) px/s from `film_pos + n·6` (`Gloop.gd:622`).

## How the throws were checked

A Python sweep, ballistics only: `python3 tools/room_check/ch1_check.py` (add `24` to run it at radius 24; it takes about a minute).

**Physics.** Gravity 632.5 px/s². Each 1/60 s step, velocity is multiplied by `exp(−0.22·dt)·(1−0.08·dt)`. Radius 12. Contact with a well counts at 48 + 12 px from its center.

**Grid.** For each vine, 5,074 pulls: angles from 2° to 178° in steps of 1.5°, stretch from 10 to 220 px in steps of 5.

**What's recorded.** The first contact, with its normal speed. Roof drips and falls off a free edge are simulated as straight drops from (0, 90).

**What isn't.** Nothing else after landing is simulated. Every step that depends on what the drop does after it lands is marked **[after landing]**. The step 3 solve check must confirm those in the game.

**How to read the numbers.**
- **Share** is the fraction of the whole grid that solves the room. Only about 40% of the grid throws up and to the right at all.
- **Window** is the range of pull angles and stretches that land on the intended carrier.

**Radius 24.** The sweep was run again at radius 24, the planned size. Every room stays solvable.

| # | Room | Carrier | Share at r 12 / r 24 | Direct to the well | Window | New mechanic |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | The First Drop | none: a direct throw | 3.6% / 4.3% | 3.6% (intended) | 124–178° × 90–220 px | — |
| 2 | The Wall | glides down a face, through a crack | 2.2% / 1.6% | 0 | 142–178° × 90–220 | — |
| 3 | The Roof | clings to a low roof, then drips | 0.8% / 0.5% | 0 | 144–155° × 125–220 | — |
| 4 | The Vein | lands on a second vine, then straight up | 2.8% / 2.7%, then 7.6% / 6.4% | 0 | 122–178° × 90–220; vine 2: 80–100° × 75–220 | second vine |
| 5 | The Lip | rolls down a slope into a pocket | 2.3% / 2.0% (+1.2% from roof drips) | 0 | 119–172° × 85–145 | — |
| 6 | The Thread | splits hard on an anvil | 0.7% / 0.5% (+0.7% from roof drips) | 3.5% (feeds one pod, which closes again) | 121–149° × 45–60 | split into bodies, twin pods |
| 7 | The Shelf | rolls down a hidden ledge | 1.5% / 1.3% (+0.8% from roof drips) | 0 | 121–168° × 90–135 | hidden rock |
| 8 | The Dark | glides down a face past a ridge, in the dark | 5.0% / 4.1% | 0 | 126–173° × 95–220 | zero backlight |

## Shared requirement: the miss rule

`Level_00._drop_missed` only counts a drop that stops below y 520 as a miss. In these rooms the drop can stop on a gallery floor at y 400, a block top at y 440, or a ledge at y 380.

Proposed `LevelBase` default for rooms 2–8. A drop has missed when:
- it is out of bounds: x < −20, x > 1300, or y > 690;
- or it has stopped: it is on no vine, is not a film, and has moved slower than 25 px/s for 1.0 s;
- or it is a film below y 690. Otherwise a film never counts as a miss.

The 1.0 s covers the moment when a film on a slope turns back into a body at zero speed, before it starts to roll.

Room 6 resolves only when every body from the split has either drunk or missed.

---

## 1 · The First Drop

**Idea:** throw. **Carrier:** none; the flight path is shown. This is Level 0 as built, with its geometry unchanged (its surface tuning is frozen).

**Layout** (the existing `scenes/levels/Level_00.tscn`):
- Spawner (275,168), under the tooth tip at (275,155). Vine at (270,400), anchors (−90,0) and (100,0). Well (1000,460).
- Roof `(0,0) (1280,0) (1280,78) (980,96) (760,54) (520,110) (340,48) (180,92) (0,64)`
- Tooth `(240,0) (310,0) (280,140) (275,155) (270,140)`
- Phase1Basin `(220,680) (230,620) (320,620) (330,680)`
- CentralBarrier `(480,720) (500,500) (512,484) (528,484) (540,500) (560,720)`
- RightPlatform `(860,720) (880,620) (1120,620) (1140,720)`

**Solution:** pull (−117, 27). The drop launches from (216,400) at (990, −228) px/s and enters the well at (945,438) after 0.82 s.

**Likely misses:**
- **Too steep** (27.5%). It hits the roof near its dip at x ≈ 500, clings, and drips onto the pillar or the floor. The glow marks the spot on the roof.
- **Too low** (2.9%). It hits the pillar's left face and leaves a streak down it.
- **Under the well** (2.7%). It lands on the platform and leaves a puddle directly below the well, which shows that the arc dropped too soon.

**Text** (while the drop forms): "The spring went dry. One stone stayed wet."

**Mechanics:** none.

**Note:** LightProbe's default pull, (−70, 110), does not solve this room: it hits the roof at (492,112). To check the win bloom, run LightProbe with pull (−117, 27).

## 2 · The Wall

**Idea:** a wall carries the drop down. **Carrier:** the drop glides down the face of the right-hand rock mass, through a crack too narrow for the drop's body, and falls off the face's free edge into the well.

**Layout:**
- Spawner (300,160). Vine (300,260). Well (1004,520), sealed in a chamber under the gallery floor.
- `roof(300)`, `lwall`
- Gallery (the floor plus the chamber walls): `(30,400) (1006,400) (1006,425) (890,425) (890,600) (1100,600) (1100,720) (30,720)`
- Mass: `(960,110) (1280,110) (1280,720) (1100,720) (1100,445) (1020,445) (1020,260) (960,260)`
  - The face is at x 1020 from y 260 to 445.
  - Above it, a lip reaches out to x 960.
  - Below it, a notch runs to x 1100.
- **The crack** is x 1006–1020 at y 400–425: 14 px, narrower than the drop (24 px now, 48 later).
  - A gliding film has no collision, so it passes.
  - A body can't.
  - The well's light leaks up through the crack onto the face.

**Solution:** pull (−75, 50).
1. The drop launches from (262,272) at (635, −423) px/s.
2. After 1.45 s it hits the face at (1009,361) at a normal speed of 409: film plus 2 beads.
3. It glides 84 px down to the free edge at y 445, which takes about 3–4 s at 21–30 px/s.
4. It leaves at x ≈ 1004 and falls into the well.

Harder throws also work: the median pull of the window is (−129, 19), with a normal speed of 859 (split plus 5 beads). Face hits fall between y 291 and 374 (10th–90th percentile), so glides run 70–155 px and take 3–7 s.

**[after landing]** Step 3 must confirm:
- A split-plus-5-beads hit still ends as one film on the face.
- The film passes the crack. Its ray starts at `film_pos + n·28`, which is inside the gallery polygon; this relies on the default `hit_from_inside = false` ignoring that polygon.
- The film leaves at the y-445 corner rather than wrapping under the notch. The ray reaches x ≈ 1066, short of the notch wall at 1100.
- The falling body triggers the well.

**Likely misses:**
- **Too steep** (43.8%). It clings to the roof and drips onto the gallery floor. The roof spot and the puddle below it show that the arc peaked before the wall.
- **Short** (26.7%). It lands on the gallery floor and stays. The puddle shows how far short it fell.
- **On the lip.** It glides down the lip's face at x 960 and drips onto the gallery at x ≈ 944. The streak stops 60 px short of the crack, which shows that the face beyond it is the one that keeps going down.

**Text** (after the first miss): "Water knows the way down."

**Mechanics:** none.

**Feel risk:** glide time. If 3–7 s drags in playtests, raise `Gloop.max_wall_glide_speed` for this room only. The uncapped flow on a vertical face is about 41 px/s (`Gloop.gd:578–579`), so to go faster than that, raise the 0.065 factor as well.

## 3 · The Roof

**Idea:** the roof holds the drop, then lets it fall straight. **Carrier:** the drop clings to a low roof just behind a tall wall, then drips into the well hidden behind that wall.

**Layout:**
- Spawner (240,160). Vine (240,450). Well (720,590), in the pit behind the wall.
- Roof, stepping down to a low roof over the right part: `(0,0) (1280,0) (1280,230) (560,230) (560,110) (260,110) (240,147) (220,110) (0,110)`
- `lwall`, `rwall`, floor `(30,650) (1250,650) (1250,720) (30,720)`
- Wall `(600,650) (600,320) (660,320) (660,650)`. The gap between the wall top and the low roof is 90 px.

**Why a direct throw can't work:** to fall into the well, the drop would have to clear the gap moving sideways at under about 110 px/s, and no arc from the vine is that slow there. The sweep found no direct hits.

**Solution:** pull (−159, 85).
1. The drop launches from (160,480) at (1345, −719) px/s.
2. It passes the gap while still rising and hits the low roof at (722,242) after 0.43 s, at a normal speed of 363.
3. It clings for 1.0 s and gathers for about 1.8 s.
4. It drips from about (722,248) and falls about 290 px into the well. From impact to drink takes about 3.5 s.

This is the narrowest window in the chapter.

**[after landing]** Step 3 must confirm:
- The drop clings on the y-230 roof.
- The drip falls from the x where it hit; a level roof gives no flow.
- Any roof hit between x 660 and 780 lands in the well.

**Likely misses:**
- **Too low** (13.9%). It hits the wall's left face and glides to the floor. The streak on the face shows that the arc has to go over the wall.
- **Roof in front of the wall** (21.0%). It clings left of the gap or on the step, then drips in front of the wall. The roof spot and the floor puddle are both on the near side.
- **Over the wall top** (1.2%). The drip lands on the wall top, which lights up; the well is just past it.

**Text** (while the drop clings): "It holds on. Then it lets go."

**Mechanics:** none.

**At radius 24:** the gap leaves 42 px of clearance and the window shrinks to 146–154° (0.5%). If playtests stall here, widen the gap to 110 px by lowering the wall top to y 340.

## 4 · The Vein

**Idea:** water can rest, then be thrown again. **Carrier:** a second vine under a chimney; from there, straight up.

**Layout:**
- Spawner (230,160). Vine 1 at (230,470). Vine 2 at (920,480), anchors (−85,0) and (85,0). Well (920,205), at the top of the chimney.
- `roof(230)`, `lwall`, `rwall`, floor `(30,650) (1250,650) (1250,720) (30,720)`
- Overhang with a chimney (x 865–975, y 140–330): `(760,110) (1250,110) (1250,330) (975,330) (975,140) (865,140) (865,330) (760,330)`

**Why a direct throw can't work:** to enter the chimney, the drop must be rising steeply under x 865–975 while still below y 330, and no arc from vine 1 does that. The sweep found no direct hits.

**Solution:**
1. **Vine 1:** pull (−115, 33). The drop launches from (172,474) at (973, −279) px/s, passes under the overhang's corner at (760,330), and comes down onto vine 2 at (922,486) after 0.87 s.
2. **Vine 2:** pull (0, 150). The drop launches straight up from (920,542) at 1269 px/s and reaches the well at (920,263) after 0.23 s.

Also works: a hit on the overhang's underside above vine 2 (x 819–1021) drips onto vine 2.

**[after landing]** Vine 2 must catch a drop arriving at about 1000 px/s, mostly sideways. `ElasticTendril._fell_onto_curve` (line 382) only checks that the drop crosses the curve going down, and the catch sets its velocity to zero (line 360).

**Likely misses from vine 1:**
- **On the underside, past vine 2** (21.9%). It drips onto the floor. The roof spot hangs over bare floor, which shows the vine is further along.
- **Too high** (7.0%). It hits the overhang's face at x 760, glides off the corner, and falls at x ≈ 744, just left of vine 2. The streak and puddle land just short of the vine.
- **Short.** It lands on the floor.

**Misses from vine 2 are forgiving:**
- A slanted throw hits a chimney wall, glides out of the mouth, and falls back onto vine 2 (5.8%).
- A hit on the underside drips back onto vine 2 (13.5%).
- A throw too far right hits the right wall (14.3%) and ends on the floor.

**Text** (while the drop sits on vine 2): "Rest. Then rise."

**Mechanics:** a second vine.
- A drop seated on either vine is not a miss.
- Both vines take input; only the one under the touch drags.
- Check that `membrane_cooldown` (0.45 s) stops vine 1's snap-back from catching the drop again.

## 5 · The Lip

**Idea:** water rolls to the low place. **Carrier:** a 21° slope runs down into a pocket in the block's right side. A lip at the top of the slope sends anything that lands beyond it the other way.

**Layout:**
- Spawner (230,160). Vine (230,430). Well (700,556), inside the pocket (x 640–760, y 500–610), whose mouth faces right.
- `roof(230)`, `lwall`, `rwall`, floor `(30,650) (560,650) (560,720) (30,720)`
- Block, slope, lip and gutter as one polygon: `(560,440) (760,440) (760,500) (640,500) (640,610) (770,610) (1060,500) (1170,555) (1250,555) (1250,720) (560,720)`
  - The slope runs from (770,610) up to the lip at (1060,500), at 20.8°.
  - Beyond the lip, the rock falls to (1170,555), then a flat gutter runs to the right wall.

**Why a direct throw can't work:** the pocket's mouth faces away from the vine. The sweep found no direct hits.

**Solution:** pull (−55, 80).
1. The drop launches from (202,457) at (465, −677) px/s.
2. After 2.07 s it lands on the slope at (921,541) at a normal speed of 663: split plus 5 beads.
3. The film gathers for about 2 s, then turns back into a body. This happens because the slope is flat enough (0.93 > 0.82) and the drop isn't hanging under it (`Gloop.gd:619`).
4. The body rolls about 160 px down into the pocket.

A roof drip that lands on the slope also rolls in (1.2% more).

**[after landing]** Step 3 must confirm the whole carrier: the body has to roll rather than stick (this depends on the physics material's friction and bounce) and get through the 110-px mouth. If it stalls, steepen the slope to 30°, which is still under the 35° limit for turning back into a body.

**Likely misses:**
- **Short** (4.4%). It lands on the block top and stays. The puddle on top sits just above the pocket.
- **Past the lip** (1.0%). It rolls right into the gutter. The landing mark beyond the lip and the trail down to the gutter outline the ridge.
- **Long** (6.8%). It hits the right wall and glides into the gutter, leaving a streak on the wall.

**Text** (after the first miss): "Low places fill first."

**Mechanics:** none.

## 6 · The Thread

**Idea:** a drop that falls far enough, and straight enough, breaks in two. **Carrier:** the drop lands hard on a flat anvil, and its halves leave over both edges into two pods.

**Layout:**
- Spawner (250,160). Vine (250,240), above a high ledge. Pods at (555,628) and (850,628).
- `roof(250)`, `lwall`, `rwall`
- Ledge `(30,380) (400,380) (400,720) (30,720)`
- Floor `(400,680) (1250,680) (1250,720) (400,720)`
- Anvil, a flat top at x 600–700 with 20-px corners cut at 45°: `(600,600) (700,600) (720,620) (720,680) (580,680) (580,620)`

**Split model assumed here** (to be decided in step 6):
- An impact of 520 px/s or more along the normal, on a near-flat face, makes two half-volume bodies.
- Each half moves along the surface at u = v_t ± 0.35·v_n, where v_t is the speed along the surface and v_n the speed into it.
- Both halves go the same way, which is lopsided, unless |v_t| < 0.35·v_n.

**Solution:** pull (−38, 40), a soft toss off the ledge.
1. The drop launches from (231,247) at (322, −338) px/s.
2. After 1.70 s it lands on the anvil top at (661,590), at a normal speed of 644 and a sideways speed of about 190.
3. It splits. The left half barely moves (u ≈ −35) and drops off the near edge, landing at x ≈ 580. The right half moves at u ≈ +415 and lands at x ≈ 854.

**Range.** Over the whole window, the halves land at x 566–588 and 845–858, all inside the pods. The pods sit asymmetrically because a throw always carries sideways momentum.

**A second way.** A roof hit above the anvil drips straight down onto it, landing at about 740 px/s with no sideways speed (0.7% more). That split is symmetric: the halves land at about x 498 and 802, so this way misses the left pod as placed now.

**Pod positions** have to be fitted once the split mechanic exists.

**[after landing]** Everything after the impact is new mechanics.

**Likely misses:**
- **A whole drop straight into one pod** (3.5%). The pod drinks, then closes again 2 s later. Its light flares and fades, which shows that one is not enough.
- **Too hard and flat.** Both halves go right, so the right pod gets two and the left pod none. The two bead trails on the same side show that the throw came in too flat.
- **Too soft** (15.2%). It lands on the vine's own ledge.

**Text** (after the first miss): "From high up, one becomes two."

**Mechanics:**
- **Split into separate bodies** (as above).
- **Twin pods.** Each pod drinks one body. The room wins only when both have drunk within 2.0 s of each other; otherwise the first pod closes again. The spawner's time to form a new drop must be longer than 2.0 s, so two separate throws can't do it.
- **Miss resolution** must wait for both halves.

## 7 · The Shelf

**Idea:** what you can't see, you find by wetting it. **Carrier:** a hidden ledge sloping 22° down into a pocket whose mouth faces away from the vine.

**Layout:**
- Spawner (230,160). Vine (230,430). Well (755,535), inside the pocket (x 690–820, y 480–590), whose mouth faces right.
- `roof(230)`, `lwall`, `rwall`, floor `(30,650) (600,650) (600,720) (30,720)`
- Block: `(600,440) (820,440) (820,480) (690,480) (690,590) (820,590) (820,720) (600,720)`
- **Hidden shelf:** `(820,590) (1040,500) (1040,516) (820,606)`. It runs from the pocket's floor up and out to the right.
- Pit floor: `(820,680) (1250,680) (1250,720) (820,720)`

**Why a direct throw can't work:** the mouth faces away from the vine. The sweep found no direct hits.

**Solution:** pull (−65, 65).
1. The drop launches from (198,450) at (550, −550) px/s.
2. After 1.73 s it lands on the shelf at (944,527) at a normal speed of 617.
3. It gathers, turns back into a body, and rolls about 130 px into the pocket.

A roof drip over the shelf also lands on it (0.8% more).

**[after landing]** Same as room 5: the body has to roll rather than stick.

**Likely misses:**
- **Long** (7.4%). It hits the right wall and glides to the pit floor. While the film glides past the shelf's upper end, Gloop's light shows the shelf for the first time.
- **Short** (4.4%). It lands on the block top and stays.
- **Into the gap past the shelf's end.** It lands on the pit floor.

A landing on the shelf wets it, and the shelf stays visible for about 16 s.

**Text** (after the first miss): "Wet stone remembers."

**Mechanics:** hidden rock (not in the original expected list).
- The shelf's `Polygon2D` uses a light-only material (`CanvasItemMaterial.light_mode = LIGHT_MODE_LIGHT_ONLY`).
- `setup_light_room` skips its shadow-caster. Mark the shelf with a group such as `"hidden"`.
- The well's light must not light it. Give the shelf a `light_mask` bit outside the well light's `range_item_cull_mask`; otherwise the glow from the pocket gives the shelf away.
- Only Gloop's light and `WetGlow` show it.

## 8 · The Dark

**Idea:** no backlight; the drop and what it wets are the only light. Act 1 closes on room 2's lesson in a room the player has to map. **Carrier:** the drop glides down a face past a ridge you can't see, through a crack, into the well. A thin line of the well's light leaking through the crack is the only clue.

**Layout:**
- Spawner (200,160). Vine (200,420). Well (904,596), sealed in the chamber under the gallery floor.
- `roof(200)`, `lwall`, floor `(30,650) (420,650) (420,720) (30,720)`
- Ridge: `(420,650) (510,400) (550,400) (640,650) (640,720) (420,720)`
- Gallery: `(640,470) (906,470) (906,495) (800,495) (800,650) (1100,650) (1100,720) (640,720)`
- Mass: `(870,110) (1280,110) (1280,720) (1100,720) (1100,535) (920,535) (920,250) (870,250)`
  - The face is at x 920 from y 250 to 535, with its free edge at 535.
  - Above it, a lip reaches out to x 870.
- The crack is x 906–920 at y 470–495.

**Solution:** pull (−85, 50).
1. The drop launches from (158,432) at (719, −423) px/s and clears the ridge.
2. After 1.25 s it hits the face at (908,436) at a normal speed of 492: film plus 2 beads.
3. It glides about 100 px through the crack and falls into the well, about 4 s after the hit.

Face hits fall between y 284 and 429 (10th–90th percentile), so glides take 4–10 s. That's long, but each glide paints the longest glow line in the chapter.

**[after landing]** Same as room 2.

**Likely misses:**
- **Too flat** (10.0%). It hits the ridge's left flank and glides to the floor. The first glow streak shows the player there is a ridge.
- **Too steep** (24.9%). It clings to the roof and drips onto the floor or the ridge top.
- **Short** (2.7%). It lands on the gallery floor, and the puddle maps the floor. A hit on the lip glides off onto the gallery, short of the crack.

**Text:** none. Sound drops to the drop alone (see PROPOSAL.md).

**Mechanics:** zero backlight.
- Set `room_ambient = 0`. Check that the `ambient` shader parameter at 0 really goes black.
- The Background and the hand-drawn sprites must go dark too.
- `bloom_ambient` still lights the room on a win.
- Check that the light through the crack reads. The well's light has a radius of about 280 px (`light_soft` 128 px × `texture_scale` 2.2) and is about 120 px from the crack. If the line doesn't read, raise `texture_scale` for this room.

---

## For step 3: what the solve check must confirm in the game

| Room | Pull(s) | Confirm |
| --- | --- | --- |
| 1 | (−117, 27) | Drinks in flight (ballistics alone shows this) |
| 2 | (−75, 50); (−129, 19) | A film forms after a split-plus-5-beads hit; it passes the 14-px crack; it leaves at the y-445 corner; the falling body drinks |
| 3 | (−159, 85) | Clings at y 230; drips from the hit's x; drinks about 3.5 s after the hit |
| 4 | (−115, 33), then (0, 150) on vine 2 | Vine 2 catches a fast arrival; the throw from vine 2 drinks |
| 5 | (−55, 80) | Gathers into a body on a 21° slope, rolls without stopping, drinks |
| 6 | (−38, 40) | Needs the split mechanic: both halves drink within 2 s |
| 7 | (−65, 65) | Same as room 5, on the hidden shelf |
| 8 | (−85, 50) | Same as room 2 |

Re-run all pulls once Gloop's radius is 24. The sweep says every room stays solvable at that size, but its windows narrow by up to a third (room 3 most).
