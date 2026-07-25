# Hourglass Hero — Godot 4

A platformer where the player **is** an hourglass. A sand gauge drains
continuously; at zero, you die. Every jump does three things at once:

1. **Flips the hourglass** — the drained sand comes back, so `sand` becomes
   `SAND_MAX - sand`. Waiting until you are nearly empty refills you almost
   completely; flipping while still full leaves you with almost nothing.
2. **Swaps plane** — each level exists as two superimposed versions (front and
   back) with different platforms and monsters. The jump teleports you between
   them at an identical `(x, y)`. You may land on a platform that only exists in
   the other plane… or drop into a pit.
3. **Launches you** — an ordinary upward impulse.

The consequence that drives every level: **you can only refuel by net-changing
plane.** Two designed elements bend that rule — a **spring** bounces you with no
flip, and a **flip-pad** flips the sand with no jump and no plane change.

Godot 4 port of the vanilla-JS prototype in `../hourglass_hero`.

## Running

```bash
godot --path hourglass_hero_godot
```

Controls: `←`/`→` or `A`/`D` to move, `Space`/`W`/`↑` to jump, `R` to restart,
`Esc` to go back to the menu, `F1` for the tuning panel, `Alt+Enter` (or `F11`)
to leave fullscreen.

It launches fullscreen. 960×540 stays the design resolution — every level
coordinate is in those units — and the picture is letterboxed to fit, so a level
frames identically on every display. Widening it instead (`stretch/aspect`) would
hand taller screens more world to see, because `main.gd` derives the camera
limits from the viewport size.

## The menu

`scenes/ui/main_menu.tscn` is the entry point: a title screen with one button
per level. The list is built from `Game.level_scenes`, and each label comes from
the level's own `level_name` read straight out of the `.tscn` — a new level
shows up on the next run with nothing to wire.

**Every level is unlocked.** Gating lives in one place, `Game.is_unlocked()`:
set `Game.unlock_all = false` and it falls back to `levels_reached`, which the
game already keeps up to date. The menu greys out locked buttons on its own.

## Tuning the game

Every gameplay number lives in one place: [`scripts/game_config.gd`](scripts/game_config.gd).

- **In the editor** — open `resources/game_config.tres` and edit it in the
  Inspector.
- **While playing** — press `F1`. The panel builds one slider per variable,
  changes apply on the next frame, and **Save** writes the values back into the
  `.tres` so they survive a restart and land in git. (Saving is editor-only; an
  exported build cannot write to `res://`.)

**Adding a tunable variable** is one line in `game_config.gd`:

```gdscript
@export_range(0.0, 500.0, 5.0) var dash_speed: float = 320.0
```

Its slider appears in the panel automatically, under the heading of whatever
`@export_group` it sits in. There is no UI code to touch.

### Which numbers live where

Three homes, and the choice is about *scope*, not importance:

| Home | For | Example |
|---|---|---|
| `game_config.gd` → F1 panel | One value for the whole game | `gravity`, `sand_drain_rate` |
| `@export` on an entity | Varies per instance in a level | a platform's `size`, a spring's `power` |
| `const` in the script | Never usefully varies; drawing detail | chevron length, eye radius |

The third row is deliberate: putting every drawing constant in the F1 panel
would bury the dozen sliders that actually change how the game plays.

## Adding a level

1. Duplicate `scenes/levels/level_01_wake_up.tscn` and rename it, keeping the
   numbered prefix — **play order follows the filename** (`level_07_….tscn`).
2. On the root node, set `level_name` (shown in the HUD) and `world_size`
   (bounds the camera; falling below it kills). The editor draws the bounds.
3. Move the `Spawn` marker to where the hourglass should appear.
4. Drag scenes from `scenes/entities/` into the `Entities` node and lay them
   out. Each has `size` and `plane` in the Inspector and redraws live.
5. Run. Levels are discovered by scanning the folder — there is no list to
   update anywhere.

### The building blocks

| Scene | What it is | Key properties |
|---|---|---|
| `platform.tscn` | Floor, wall or platform. `kind = FLIP_PAD` turns it into a refuel pad. | `size`, `plane`, `kind`, `move_axis`/`move_distance`/`move_speed` |
| `spring.tscn` | Bounces you upward — no flip, no plane change. | `size`, `plane`, `power` (0 = use the tuned default) |
| `monster.tscn` | Patrols an axis, kills on contact, but only in its own plane. | `size`, `plane`, `move_axis`/`move_distance`/`move_speed` |
| `spikes.tscn` | A monster that does not walk. Says "do not jump here" in a way you can see. | `size`, `plane`, `facing` |
| `door.tscn` | The exit. A `BACK` door forces you to *arrive* in the back plane. | `size`, `plane` |

`plane` is `FRONT`, `BACK` or `BOTH`. Anything not in the player's current plane
turns into a faint, non-solid ghost. Moving entities travel `move_distance` px
from where you placed them and back, so you author the *start* of the path;
`move_phase` shifts where in that cycle they begin, which is the only way to
break two movers of equal period out of lockstep.

Spikes kill on the inner 75% of the band, not on the outline — the tips are
visual overhang, because spikes that kill on their silhouette feel cheap.

### Two rules a level may bend for itself

On the level root, under **Rules**:

| Property | Effect |
|---|---|
| `sand_start_override` | Sand you begin with, in ms. 0 uses the tuned `sand_start`. |
| `double_jump` | Grants one extra jump in mid-air, for this level only. |

Both are applied by `main.gd` after the scene exists, and both reset between
levels, so a level cannot leak its rules into the next one.

The air jump needs no balancing of its own. `sand_flip_base` is 0, so
`flip_sand()` is exactly `max - sand`: an involution. Two flips return you to
your starting plane **and** to your starting sand, so a double jump is pure
height and pure time — free while you are full, ruinous while you are empty.
That is the exact mirror of the single jump, and it falls out of the formula
rather than out of a tuning pass. `sand_test.gd` guards the identity.

### The levels

| # | Level | What it teaches |
|---|---|---|
| 1 | Wake-Up | A jump is a refuel. Walking straight ahead kills you. |
| 2 | The Void | The far floor is `BACK`: the last hop has to be a step, not a jump. |
| 3 | The Ledge | A spike ceiling forbids refuelling for 820 px. Fill up *before* you commit. |
| 4 | The Spring | Height without a flip, climbing a shaft. |
| 5 | The Fountain | One plane, no jumping: the flip-pad ferries are the only refuel. |
| 6 | Parity | Flip count is a resource. A ghost ledge that can never be stood on. |
| 7 | Ten | Ten ledges, each narrower, planes forced to alternate all the way up. |
| 8 | Metronome | Five movers, one period, five phases. Cross on the beat. |
| 9 | The Well | Descending. Every depth is half solid; a flip swaps which half. |
| 10 | Double or Nothing | The air jump buys reach and costs time, never sand. |
| 11 | Midnight | The gauntlet: everything so far, over a spike pit, finishing in `BACK`. |
| 12 | The Last Grain | 1.2 s on the clock. Empty is not a problem, it is the resource. |

## Architecture

```
scripts/
  game_config.gd          Resource: every tunable number
  hourglass_shape.gd      Draws the glass — shared by the player and the HUD gauge
  hourglass_motion.gd     The tumble, the sand's slosh, the trickle's wobble
  planes.gd               FRONT / BACK / BOTH and the "is it active?" rule
  level.gd                Level root: name, bounds, spawn
  main.gd                 Loads levels, spawns the player, drives the camera
  autoload/
    tuning.gd    (Tuning) Owns the single GameConfig; reads @export metadata
    game.gd      (Game)   Sand, plane, status, progression + signals
    glass.gd     (Glass)  The one HourglassMotion: player and HUD share it
    screen.gd    (Screen) The window: launches fullscreen, Alt+Enter toggles
  entities/
    player.gd             CharacterBody2D: coyote time, jump buffer, jump cut
    platform.gd           AnimatableBody2D, carries riders, flip-pad variant
    spring.gd  monster.gd  spikes.gd  door.gd
    hourglass_visual.gd   Draws the glass, the sand and the flip tumble
    ping_pong.gd  palette.gd  layers.gd
  ui/
    main_menu.gd          Title screen + level select, built from the level list
    hud.gd                Sand gauge, level name, plane, end screens
    tuning_panel.gd       F1 panel, sliders generated from GameConfig
```

Two ideas hold it together:

- **Nobody talks to anybody directly.** `Game` owns the run state and emits
  `plane_changed` / `status_changed` / `level_loaded`; entities and the HUD
  listen. Adding an entity type means writing one script, not editing five.
- **Plane switching is one uniform rule.** On `plane_changed`, every entity asks
  `Planes.is_active(plane, current)` and either takes itself off the physics
  layer (solids) or stops monitoring (areas), then redraws as a ghost. Whether
  it is a body or an area, the mechanism is the same.

## Tests

```bash
godot --path hourglass_hero_godot --headless tests/smoke_test.tscn
```

The smoke test boots the real game and plays it: sand drains, a jump swaps
plane and refuels by exactly `max - sand`, two jumps return you to the starting
plane, walking level 1 without jumping runs you dry (the core design
constraint), walking *while* jumping reaches the door, and every level loads and
runs. Exits non-zero on failure, so it drops straight into CI.

```bash
godot --path hourglass_hero_godot --headless tests/sand_test.tscn
```

The sand test checks the geometry the smoke test cannot see: that the area drawn
equals the sand there is at every tilt, that the free surface stays level in
*world* space rather than turning with the walls, and that a flip lands with no
jump in the sand.

```bash
godot --path hourglass_hero_godot --headless tests/chamber_layout_test.tscn
```

The chamber layout test checks the maths underneath the multi-chamber glass
with nothing drawn and no game running: which chambers drain, receive, or seal
shut at each chamber count, who pours into whom, and the two- and three-turn
lessons the three- and four-chamber levels are built to teach.

## How the sand moves

The sand is a liquid, not a block glued inside the glass. `HourglassMotion`
works out `down` — where gravity points *in the glass's own frame* — and
`HourglassShape` cuts every free surface square to it, by bisecting for the cut
that leaves exactly the right area below. Tip the glass and the sand pools in
whatever corner is lowest.

Two consequences worth knowing before you touch it:

- **The neck gates the sand.** Each bulb keeps its own contents mid-tumble; the
  sand does not slosh from one to the other. That is why a real hourglass laid on
  its side does not empty.
- **A flip lands seamlessly because the bulbs are each other turned half a turn.**
  At the end of the tumble the glass snaps from π back to 0, and at that same
  instant `chambers()` swaps which bulb holds what. The two cancel exactly. Break
  one and the sand visibly jumps — `tests/sand_test.tscn` guards it.
- **There is one glass, drawn twice.** The sprite and the HUD gauge both read the
  single `HourglassMotion` held by the `Glass` autoload, which the player feeds
  its sideways speed. Run right and the sand banks against the left wall in both,
  identically — not because the two are tuned alike, but because there is only
  one spring.
