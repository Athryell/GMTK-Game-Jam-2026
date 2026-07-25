# Multi-chamber glass — design

Date: 2026-07-25
Status: approved, ready for an implementation plan

## The idea

The hourglass stops being a two-bulb object with a flip and becomes an **N-lobed
glass with a rotation**. Two new levels use it: one with three chambers that
turns a third of a turn, one with four chambers that turns a quarter.

The direction you are travelling when you jump decides which way it turns, and
that is the whole new game: the sand is never destroyed, only **stranded** in a
chamber you did not choose to bring back up.

## 1. Geometry

A chamber is a **trapezoid pointing outward from the neck**: narrow end at the
centre, wide end at radius `R`. The chambers sit at evenly spaced angles,
starting from straight up:

```
slot i sits at angle  i * TAU / N,  measured clockwise from straight up
```

There is no per-N offset table. The layout that results:

| N | slots | upper | level (inactive) | lower |
|---|-------|-------|------------------|-------|
| 2 | up, down | 1 | 0 | 1 |
| 3 | up, down-right, down-left | 1 | 0 | 2 |
| 4 | up, right, down, left | 1 | 2 | 1 |

N=2 falls out of the same formula as a trapezoid pointing up and one pointing
down, which is exactly the `upper`/`lower` pair `hourglass_shape.gd` draws
today. **The existing silhouette is reproduced, not special-cased.**

Half-width of the wide end is `R * WIDTH_RATIO[N]`, tabulated so neighbouring
bulbs nearly touch without overlapping (roughly `sin(PI/N)`). For N=2 the values
must land on today's `size.x/2` and `size.y/2` so the 12 existing levels do not
shift by a pixel; the plan should confirm this against a screenshot.

Every chamber is convex, which is the one property `_clip`, `_level` and `_pour`
in `hourglass_shape.gd` depend on. **None of the sand-surface maths changes** —
the drawing loop goes from two hard-coded calls to a loop over N.

### Who pours into whom is derived, not tabulated

A slot's role comes from where its axis points relative to the horizon:

- **upper** — points above it. Drains.
- **lower** — points below it. Receives.
- **level** — points along it. **Sealed: neither drains nor receives.** At N=4
  this is what makes the two side chambers inactive; it is a consequence of the
  geometry, not a rule bolted on beside it.

An upper slot pours into the lower slot(s) at minimal angular distance, and
**ties split evenly**. This produces exactly "transfers happen between opposite
chambers":

- N=2 — up pours into the single lower slot, straight down.
- N=4 — up is 180° from down and 90° from both sides, which are sealed anyway:
  **one flow, top to bottom.**
- N=3 — there is no chamber diametrically opposite the top; the opposite
  direction falls exactly between the two lower slots, which tie: **half and
  half.**

So the "opposite chambers only" rule and the "half and half at N=3" rule are the
same rule seen at two values of N. There is no pour table to keep in sync with
the geometry.

## 2. The sand economy

`Game.sand` (one float) becomes `Game.chambers` (N floats, indexed by **slot**,
i.e. by fixed position on screen).

**`Game.sand` stays, derived: the sum of the upper slots.** The HUD, `danger()`,
the player's light and the sweat all keep reading it and need no change. At
N=3 and N=4 there is exactly one upper slot, so it is simply the top chamber.

### Capacity scales with the number of chambers

`sand_max` is **one chamber's capacity**, not the glass's. That is already what
it means today: at N=2 all 6000 of the sand fits into a single bulb, which is
why `flip_sand()` can clamp to it.

So the glass holds `sand_max * N / 2` — 6000 at N=2, 9000 at N=3, 12000 at N=4.
More chambers means proportionally more sand, and a chamber's resting fill is
the same whatever N is.

Two things fall out of this and neither needs a rule of its own:

- **Pacing is uniform.** The top slot always starts at `sand_start` = 3000
  against a 1000 ms/s drain, so every glass gives the same 3 s of runway before
  the first rotation is compulsory. N does not make the game faster, only
  wider.
- **An even split is automatic.** Top gets `sand_start` = 3000, the remainder
  `sand_max * N / 2 - 3000` divides evenly by N−1 into 3000 each. The new
  levels need no `sand_start_override` at all.

A chamber's **drawn** fill is `its sand / sand_max`, clamped to 1 — so a resting
chamber reads half full, exactly as a resting bulb does today.

Rules:

- The total is always `sand_max * N / 2`.
- At level start the **top** slot holds `sand_start` (or the level's
  `sand_start_override`), and the remainder is split evenly among the other
  N−1 slots.
- Drain: the total rate stays `sand_drain_rate`, split evenly between the
  **non-empty upper slots**. What leaves a slot arrives in the slot(s) it pours
  into, by the map above.
- **Death when the upper slots are empty** — today's rule, with N=2 as the
  special case.
- Rotating one step permutes the array: `new[(i + dir) mod N] = old[i]`.
- Rotation adds `sand_flip_base` to the upper slots, then the total is clamped
  back to `sand_max` by taking the excess from the fullest lower slot. This term
  is 0 in the shipped config, so it is inert today; it is kept so the tuning
  slider keeps meaning what it means.

### Why this is provably safe for the 12 existing levels

`sand_start` is 3000 and `sand_max` is 6000, so at N=2 the start rule gives
3000/3000 — today's opening state exactly, and `sand_start_override = 1200` on
*The Last Grain* still gives 1200/4800.

For N=2 the lower slot always holds `sand_max - top`, so after a rotation the
new top is `sand_max - old_top + sand_flip_base` — **character for character the
current `flip_sand()`**. The reservoir model is a strict generalisation of the
formula already shipped, not a replacement for it.

### The even split the new levels want

The start rule is uniform, so an even split is a level-authoring choice, not a
special case: a level sets `sand_start_override` to `sand_max / N` and the
remainder divides evenly by construction.

- `level_13_trefoil` — override 2000 → 2000 in each of the three chambers.
- `level_14_quarters` — override 1500 → 1500 in each of the four chambers.

### The two lessons

Verified by hand against the permutations:

- **N=3 is about division.** What you drain is split in two, so a rotation
  never hands back more than half of it. Turning the same way consistently
  cycles through all three slots (period 3) and collects both halves;
  **alternating** bounces between two slots and starves the third.
- **N=4 is about delay.** What you drain comes back *whole*, but the bottom
  slot has to travel through a sealed side chamber to reach the top, so it
  takes **two rotations in the same direction**. You have to commit two jumps
  ahead. Alternating cancels itself exactly — CW then CCW restores the previous
  arrangement — which re-serves the same two chambers and strands the other
  half of the glass.

One level punishes hesitation, the other punishes short-sightedness.

## 3. Planes

- `Planes.Kind` becomes `P0, P1, P2, P3, BOTH`. `BOTH` moves from 2 to 4, so the
  32 nodes storing `plane = 2` in `scenes/` need a sed to `plane = 4`. Do this
  as its own commit, with a screenshot pass before and after.
- `Planes.opposite()` becomes `Planes.step(kind, dir, count)`. It has exactly one
  caller (`game.gd:178`).
- `Planes.is_active()` is unchanged — it is the chokepoint all four consumers
  (`plane_area`, `platform`, `entity_light`, `cast_shadows`) already go through.
- `Level` gains `@export_range(2, 4) var chambers := 2`, which fixes both the
  glass and the number of planes. `Game.start_level` reads it.

## 4. Rotation direction

The **horizontal input held at the moment of the jump** decides: right is
clockwise, left is counter-clockwise, neither keeps the last direction used
(today's `flip_dir` behaviour). Reading the input rather than `velocity.x` means
the player can still choose their chamber while pinned against a wall.

`HourglassMotion` turns `TAU / N` instead of `PI`. During the animation it draws
the **pre-rotation array rotated by `dir * TAU / N`**, which lands exactly on the
post-rotation array at rest — the same trick that makes today's flip seamless,
generalised.

## 5. Colours

Four plane hues, 90° apart. No rotation of four equidistant hues can clear both
the danger red (350°) and the time amber (40°) — they are 50° apart and a 90°
lattice always lands within 45° of something. The quartet below keeps 25°:

| slot | hue | hex | name |
|------|-----|-----|------|
| P0 | 195° | `#4cc9f0` | cyan — unchanged, the game's identity |
| P1 | 285° | `#b57bff` | violet — today's, nudged 20° |
| P2 | 105° | `#7fe04c` | lime |
| P3 | 15° | `#f0764c` | terracotta |

The order confines the risk: **a 3-chamber level only uses P0–P2 (cyan, violet,
lime) and has no collision at all.** Only the 4-chamber level brings in the
terracotta, where it separates from the danger red by register rather than by
hue — solids are large, matte and unlit; spikes and monsters are small,
saturated and carry a light.

`Palette.solid()` becomes a lookup into a `PLANE_HUES` array. `Palette.room()`
gains backdrop ramps for P2 and P3, built the same way as the existing ones (the
plane's hue drained of saturation, four depths). The hue-budget docstring at the
top of `palette.gd` must be rewritten to describe the new split — it currently
claims the world is cool and that is about to stop being true.

## 6. The levels

- `scenes/levels/level_13_trefoil.tscn` — `chambers = 3`,
  `sand_start_override = 2000`. Teaches that a consistent direction collects
  both halves.
- `scenes/levels/level_14_quarters.tscn` — `chambers = 4`,
  `sand_start_override = 1500`. Teaches that the refill is two rotations away.

Both go after *The Last Grain*. Level discovery is by filename, so there is
nothing to register.

## 7. Testing

`tests/sand_test.gd` — pure logic, no rendering:

- Total sand is conserved across an arbitrary sequence of rotations.
- N=2 reproduces `flip_sand()` exactly (the regression guard for the 12 levels).
- Slot roles match the table in §1 for N = 2, 3, 4, including the two sealed
  side chambers at N=4.
- The pour map derived from angles is "opposite only" at N=2 and N=4, and an
  even split at N=3.
- The N=3 permutation theorem: same direction visits all three slots in three
  rotations; alternating never visits the third.
- The N=4 permutation theorem: the drained bottom reaches the top in exactly two
  same-direction rotations, and CW-then-CCW is the identity.

`tests/smoke_test.gd`:

- Rotation direction follows the held input, and a neutral input keeps the last.
- Death fires when the upper slots empty.
- Landing plane after a rotation is `(previous + dir) mod N`.

Screenshots: levels 1 and 12 to prove nothing shifted, plus 13 and 14.

## 8. Risks

- **The N=4 rotation cadence is tight.** An even split puts 1500 ms in the top
  against a 1000 ms/s drain, so the glass demands a rotation every ~1.5 s —
  half of today's 3 s. That may be exactly the intensity *Quarters* wants, but
  it is the first thing to check in playtesting. The levers are the level's
  `sand_start_override` (breaking the even split) or global `sand_max`; resist
  inventing a per-level drain multiplier before the level has been played.
- **The palette rewrite is the least reversible part.** Terracotta next to the
  danger red is the one call that may not survive contact with the screen; if it
  reads badly, the fallback is to give P3 a cooler, darker treatment rather than
  to re-pick the hue.
- **The `plane = 2` sed touches every level file.** Its own commit, screenshotted
  either side.
- The 4-chamber glass is small on screen at HUD size; four wedges with sand
  levels in each may not read at gauge scale. If not, the HUD gauge can show
  only the upper slot.

## 9. Out of scope

Chamber counts above 4. Levels that change their chamber count mid-run. Any
change to the 12 existing levels beyond the mechanical `plane = 2` migration.
