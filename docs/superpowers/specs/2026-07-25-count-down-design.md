# Hourglass Hero — the Count Down pass

**Date:** 2026-07-25
**Jam theme:** Count Down
**Scope:** one new mechanic, one new hazard, twelve levels.

## Why this pass exists

Hourglass Hero already fits the theme, but passively. The sand drains on its own
and the player repairs it. The countdown is a punishment to be undone rather than
a thing to be played with.

Two findings from reading the existing game decided the shape of this pass:

1. **No level has ever scrolled vertically.** All six have `world_size.y = 540`,
   exactly one screen. Six flat rooms in a row. That, not the content, is why
   they feel alike. The camera has supported both axes all along
   (`main.gd:86-99`), so verticality costs no engine work.
2. **`monster.tscn` appears in one level out of six.** A whole entity, written
   and tested, sitting unused.

Free variety, twice over.

## The numbers this rests on

`sand_max = 6000`, `sand_drain_rate = 1000`: **the glass runs for six seconds.**
Every level is a handful of seconds long. Twelve levels is less content than it
sounds, and the game is a countdown in the most literal sense.

`sand_flip_base = 0`, so `flip_sand()` is exactly `max - sand`. **Flipping is an
involution: `flip(flip(s)) == s`, exactly.** Everything about the double jump
below follows from that one fact.

Jump physics, used to size every gap: `gravity = 2200`, `jump_velocity = 760`
gives a 131 px rise over 0.69 s of air time; at `move_speed = 260` that is about
180 px of horizontal reach. A double jump roughly doubles both.

## Engine changes

Three additions. Nothing touches `Game`'s rules, `HourglassMotion`, or rendering.

### `spikes.tscn` — a static hazard

An `Area2D` that kills on contact, with `size` and `plane` like every other
entity, drawn as a row of triangles. It listens to `plane_changed` and goes
inert as a ghost outside the player's plane — the same contract `monster.gd`
already honours. No new concept enters the architecture; it is a monster that
does not walk.

Spikes exist to say **"do not jump here"** in a way the player can see. A low
ceiling would forbid the jump; spikes show why it is forbidden, which teaches.

### `sand_start_override` on `level.gd`

```gdscript
@export_range(0.0, 20000.0, 100.0) var sand_start_override := 0.0
```

At `0.0` the level uses `Tuning.cfg.sand_start`, as today. Otherwise the level
dictates its own starting fill. `main.gd` applies it after instantiating the
level, since `Game.start_level()` runs before the scene exists.

### `double_jump` on `level.gd`

```gdscript
@export var double_jump := false
```

The double jump is a property of the **level**, not of the player. No persistent
unlock system to write, earlier levels are untouched by construction, and it is
a checkbox in the Inspector.

In `player.gd` it is an air-jump counter reset on landing. The second jump calls
`Game.jump_flip()` exactly like the first — **no special-case code anywhere.**

## The double jump, and why it needs no balancing

Two flips return you to your starting plane and, because flipping is an
involution, to your starting sand *to the grain*. So a double jump is pure
height: a spring you carry.

The cost is intrinsic, and it is the exact mirror of the single jump:

| Sand before | Single jump | Double jump |
|---|---|---|
| Full | ruinous — you drop to nearly empty | **free** — you end up full again |
| Nearly empty | free — you refill completely | **ruinous** — you throw the refill away |

A player who double-jumps while nearly empty lands nearly empty and dies. That
is the whole subject of level 10, and it required no tuning knob: it falls out
of `max - sand`.

It also survives contact with `Ten`: cancelling that level's forced parity is
possible, but only while full — which is never when it would help.

## The twelve levels

Order follows the filename. One new idea per level; the last two combine.

| # | Level | | Subject | Shape |
|---|---|---|---|---|
| 1 | Wake-Up | edit | the loop: jump = flip + swap plane | flat |
| 2 | The Void | edit | read the plane *before* you leap | flat |
| 3 | **The Ledge** | new | sometimes you must not jump | flat |
| 4 | The Spring | edit | height without a refuel | **vertical** |
| 5 | The Fountain | edit | the flip-pad, but you must catch it | flat |
| 6 | Parity | edit | odd/even becomes a real puzzle | flat |
| 7 | **Ten** | new | parity under pressure | **vertical** |
| 8 | **Metronome** | new | the level has a tempo | flat |
| 9 | **The Well** | new | choosing *when* to refuel | **vertical** |
| 10 | **Double or Nothing** | new | the double jump and its trap | flat |
| 11 | Midnight | edit | the gauntlet: everything but the double jump | wide |
| 12 | **The Last Grain** | new | everything, one breath from death | wide |

### The six new levels

**3 · The Ledge.** A flat corridor with a band of spikes across its ceiling for
its whole length. Jumping kills, so there is no refuel: the crossing is pure
drain, sized at roughly 60% of a full glass. Before the entrance sits a safe
alcove — its floor in plane `BOTH`, so parity does not muddy the lesson — where
the player may jump freely. **The level does not ask how to cross. It asks when
to enter.**

**7 · Ten.** Ten platforms *descending*, alternating front/back, so each jump's
plane swap forces the alternation rather than merely allowing it. The player
counts ten, nine, eight on the way down. The gaps are deliberately uneven, and
the widest sit on the steps where the flip leaves you nearly empty — so they
cannot be crossed without having decided, at the top, what fill to start with.
This is `Parity` turned into an actual problem.

**8 · Metronome.** A spike-floored chasm spanned by two moving platforms, one per
plane, in antiphase — same `move_distance` and `move_speed`, offset starts. The
safe ground alternates on a fixed beat, and since every jump swaps plane, the
level *wants* to be played on the beat. Being off-beat does not only cost a life:
it inverts your sand at the wrong moment.

**9 · The Well.** A vertical shaft, ledges alternating between the walls at
growing intervals. You cannot jump in mid-air, so a fall is pure drain. On each
ledge: jump (refuel and swap plane, but the next ledge down may not exist in the
new plane) or don't. The further you fall before landing, the larger the refuel.
The level rewards nerve.

**10 · Double or Nothing.** `double_jump = true` for the first time. A run of
gaps no single jump can clear, each preceded by a flip-pad. A player who has
understood nothing double-jumps on empty, lands on empty, and dies a few metres
on. A player who has understood tops up at the pad *first*. The level teaches the
inverse of everything learned so far: here you jump when **full**.

**12 · The Last Grain.** `sand_start_override` around `1200` — you start dying.
Every platform is placed so you arrive on the edge, jump, refill, and move on.
Spikes, spring, flip-pad, moving platforms, double jump: all of it. The only
level where the countdown is played backwards from the first second to the last.

### What changes in the six existing levels

**1 · Wake-Up — barely touched, deliberately.** A tutorial that punishes loses
the player in thirty seconds. It keeps its job: discovering that jumping
refuels. It is also load-bearing for two smoke-test assertions.

**2 · The Void.** The floor exists only in `FRONT` for the first half and only in
`BACK` for the second. You must jump exactly at the seam — early or late and you
fall. The other plane's ghost floor is visible ahead, so the information is
there: this is a level that teaches looking. A monster in the back half means
arriving is not enough.

**4 · The Spring — becomes vertical.** A shaft climbed by spring alone. Since the
spring does not flip the glass, you rise with your sand still draining and your
plane unchanged. Spikes at the top forbid refuelling on arrival. The lesson
becomes *fill up before you bounce*, not after.

**5 · The Fountain.** A single-plane room with the flip-pad mounted on a **moving
platform**. You have to catch it, repeatedly, to cross. A monster patrols
beneath. Same concept, real difficulty.

**6 · Parity.** The door is `BACK`, so you must arrive after an odd number of
jumps. Two routes of opposite parity, long and short; a monster blocks the short
one. So you either take the long way or burn an extra jump somewhere — and that
extra jump costs sand at the worst possible moment. The game's first true puzzle.

**11 · Midnight.** Promoted to a skill check: everything the player has learned
except the double jump. It already has a monster and moving platforms; it mainly
needs widening and spikes.

## Tests

### New checks

- **The double-flip identity.** The most important test of the set. All of level
  10's design rests on `flip(flip(s)) == s`. If anyone ever sets
  `sand_flip_base` away from zero, the double jump silently becomes either a
  leak or a sand generator, and level 10 loses its subject without anything
  breaking loudly. Checked across the range, including `0` and `sand_max`.
- **Spikes** kill inside your plane and are inert outside it — `monster.gd`'s
  contract, a different entity.
- **`sand_start_override`** is honoured when set and ignored at `0.0`.
- **`double_jump`**: off by default, a second airborne press does nothing; on,
  it fires and returns you to your starting plane.

### Two existing assertions this pass breaks

**`smoke_test.gd:21` hard-codes `Game.level_scenes.size() == 6`.** The fix is not
to write 12: it is to compare against the number of `.tscn` files in the folder.
The test still catches a broken scan and stops needing maintenance per level.

**`smoke_test.gd:104` runs each level for 60 frames and demands `status == PLAY`.**
`The Last Grain` starts with under a second of sand, so **the finale would fail
the suite by design.** The assertion splits in two: "the level loads and spawns a
player", which is the real smoke check, and "it survives a second", skipped when
`sand_start_override` is below one second of drain. The condition is computed,
not a hand-maintained blocklist.

## Order of work

1. **Engine** — `spikes.tscn`, the two `@export`s, the air jump, and the tests
   above. Nothing else can be built first.
2. **A throwaway vertical level, immediately.** The claim that the camera has
   always handled the vertical axis rests on reading `main.gd`. Better to prove
   it in ten minutes than to discover it at level 9.
3. **Renumber the level files** (`git mv`) before authoring, so nothing gets
   renamed twice.
4. **The five edits** — cheapest, only known bricks.
5. **The three new flat levels** — Ledge, Metronome, Double or Nothing.
6. **The two vertical ones** — Ten, The Well.
7. **The Last Grain** last: it combines everything.

If time runs out, the cut line is `Metronome` and `The Well` — the two that teach
the least. That leaves ten levels and drops no lesson. The cut falls naturally at
steps 5 and 6, breaking nothing downstream.

## Deliberately not done

- **Numbered countdown blocks** that tick on every flip. Strong on theme, but it
  is a system, and this pass is levels.
- **A flip budget per level** ("7 FLIPS LEFT"). Competes with the sand: two
  draining resources and the player reads neither.
- **Spending sand for a power-up.** Reads as a mana bar, not as a countdown.

## As built

Three things the plan did not foresee, recorded here so the next pass starts from
what is true rather than from what was intended:

- **`move_phase` had to be added.** Every mover derives its position from one
  shared clock, so two entities of equal period sit in lockstep forever and no
  amount of nudging positions breaks them apart. `Metronome` is five movers of
  one period at five phases; without the export it is five movers in unison,
  which is not a metronome. It lives on `PingPong.offset_vector`, so platforms
  and monsters both get it for one line each.
- **Nothing was cut.** All twelve levels are in, so the `Metronome` / `The Well`
  cut line was never reached.
- **The vertical probe was deleted** once it had answered its question, as
  planned. Its answer: `limit_bottom` 1600 on a 960×1600 level, camera tracking
  y 270 → 1330. Verticality needed no engine change at all.

One real bug surfaced, and it was in the test rather than in the game.
`_load_current_level` only `queue_free`s the level it replaces, so for the rest
of that frame **both** are in the tree and `find_children` hands back the old
one. The existing suite hid this by always sleeping 60 frames before looking; the
new per-level rule check looks immediately, and so read every level's rules off
its predecessor — and, in `_check_air_jump`, touched a freed player. The fix is a
single `await` inside `_load_level_scene`, and the reason is written down there.

`Spikes` also needs Godot's global class cache to have seen it, which only the
editor writes and `.godot/` is gitignored. A clone that has never opened the
project fails the smoke test on a parse error. That is pre-existing and
project-wide — every `class_name` in the repo has it — not something the spikes
introduced.
