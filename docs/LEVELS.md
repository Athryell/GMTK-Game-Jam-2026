# Building a level

Reference for authoring levels and tuning the game. For why the systems behave
the way they do, see [DESIGN.md](DESIGN.md).

## Adding a level

1. Duplicate `scenes/levels/level_01_wake_up.tscn` and rename it, keeping the
   numbered prefix — **play order follows the filename, and so does the title
   shown in the menu and the HUD**.
2. On the root, set `world_size` (bounds the camera; falling below it kills).
3. Move the `Spawn` marker.
4. Draw the ground: add a **`Terrain`** node under `Entities`, select its
   `Shape` child and use Godot's polygon tool. What you draw is what you stand
   on, slopes included.
5. Drag scenes from `scenes/entities/` into `Entities`. Each has `size` and
   `plane` in the Inspector and redraws live.
6. Run. Levels are discovered by scanning the folder.

## The building blocks

| Node / Scene | What it is | Key properties |
|---|---|---|
| **`Terrain`** (node) | The ground, as a polygon: floor, ledge, wall and **slope** in one node. | `plane` |
| `platform.tscn` | A rectangle that MOVES, or a refuel pad (`kind = FLIP_PAD`). Static ground belongs in a `Terrain`. | `size`, `plane`, `kind`, `move_axis`/`move_distance`/`move_speed` |
| `spring.tscn` | Throws you the way it is turned — no flip, no plane change. Rotate the node and the launch follows it, at any angle. | `size`, `plane`, `rotation`, `power` (0 = tuned default) |
| `monster.tscn` | Patrols an axis, kills on contact, in its own plane only. | `size`, `plane`, `move_axis`/`move_distance`/`move_speed` |
| `spikes.tscn` | A monster that does not walk. | `size`, `plane`, `facing` |
| `cannon.tscn` | Tracks you while it charges, then fires along the line it held. Blocked by solids, so cover is real. | `plane`, `aim_time`, `fire_time`, `phase` |
| `gravity_pad.tscn` | Gravity pulls the way its arrows point, until another pad says otherwise. | `size`, `plane`, `pulls_up` |
| `inversion_zone.tscn` | The sand runs backwards inside it: standing still refills you, and a full glass kills. | `size`, `plane` |
| `feather.tscn` | Picked up, it buys ONE mid-air jump. Spending it empties it for good; landing does not hand it back. | `size`, `plane` |
| `door.tscn` | The exit. A `BACK` door forces you to *arrive* in the back plane. | `size`, `plane` |
| `hint_sign.tscn` | A line of text where the lesson is. `after_deaths` holds it back; `hide_after_deaths` takes it away. | `text`, `after_deaths`, `hide_after_deaths` |

`plane` is `FRONT`, `BACK` or `BOTH`. Anything outside the player's plane turns
into a faint, non-solid ghost. A plane-bound *solid* is never lifted back
towards looking solid — that is the one thing that would lie about it. It
carries a dashed line outside its silhouette instead, in its plane's hue,
strongest in the plane the next jump lands in (`PlaneMarker`,
`next_outline_gap`). Hazards and zones do lift (`ghost_next_lift`): there is
nothing to stand on there to be misled about.

Moving entities travel `move_distance` px from where you placed them and back,
so you author the *start* of the path. `move_phase` is the only way to break two
movers of equal period out of lockstep.

Spikes kill on the inner 75% of the band, not on the outline: the tips are
visual overhang, because spikes that kill on their silhouette feel cheap.

## The rules a level may bend

On the level root, under **Rules**:

| Property | Effect |
|---|---|
| `chambers` | How many chambers the glass has, 2 to 4 — and so how many planes, and how far a jump turns you. |
| `sand_start_override` | Sand you begin with, in ms. 0 uses the tuned `sand_start`. |
| `clock_starts_on_move` | The sand does not run until the player first steers. |
| `jump_locked_first_life` | No jump until this level has killed you once. |

All are applied by `main.gd` after the scene exists and reset between levels, so
a level cannot leak its rules into the next.

## Tuning

Every gameplay number lives in
[`scripts/game_config.gd`](../scripts/game_config.gd). Edit
`resources/game_config.tres` in the Inspector.

Adding a tunable is one line:

```gdscript
@export_range(0.0, 500.0, 5.0) var dash_speed: float = 320.0
```

| Home | For | Example |
|---|---|---|
| `game_config.gd` | One value for the whole game | `gravity`, `sand_drain_rate` |
| `@export` on an entity | Varies per instance in a level | a platform's `size`, a spring's `power` |
| `const` in the script | Drawing detail that never usefully varies | chevron length, eye radius |

## The menu

`scenes/ui/main_menu.tscn` is the entry point: one button per level, built from
`Game.level_scenes`, each label titled from the level's own filename. A new
level shows up on the next run with nothing to wire.

Every level is unlocked. Set `Game.unlock_all = false` and `Game.is_unlocked()`
falls back to `levels_reached`.
