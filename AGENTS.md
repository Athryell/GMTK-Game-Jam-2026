# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

Sandbound is a Godot 4.7 (GL Compatibility) 2D platformer where the player **is**
an hourglass. The sand drains continuously and zero sand kills. One jump does
three things at once: it **flips** the glass (`sand` → `sand_max - sand`),
**swaps plane** (teleports to a superimposed version of the level at the same
`(x, y)`), and **launches** the player. So the player can only refuel by *net
changing plane*. A spring launches without flipping; a flip-pad flips without
jumping or changing plane.

That single rule is the reason for most of the architecture below — read
[docs/DESIGN.md](docs/DESIGN.md) before changing sand, planes, gravity or light.

## Commands

```bash
godot --path .                       # run the game
godot --headless --import --path .   # build .godot/ in a fresh checkout
```

The import step is not optional in a new checkout or worktree: `.godot/` is
gitignored, `project.godot` names the main scene by UID, and with no UID table
Godot aborts before the game starts.

### Tests

Each test is its own scene with no runner around it. They run headless, print
`ok` / `FAIL` per check, and quit with exit code 1 if any check failed:

```bash
godot --headless --path . tests/sand_test.tscn
```

| Scene | Covers |
|---|---|
| `sand_test.tscn` | Sand economy, bulb geometry, flip identity, inversion flow |
| `chamber_layout_test.tscn` | N-chamber roles, pour map, plane tints |
| `polygon_test.tscn` | Ground/shadow polygon geometry (screen space, y down) |
| `backdrop_test.tscn` | Where parallax art is planted and how far it lags |
| `level_order_test.tscn` | Level numbering and menu order from filenames |
| `run_clock_test.tscn` | `Game.format_time` |

`tests/screenshot.tscn` and `tests/flow_sheet.tscn` are capture harnesses, not
tests, and need a **real window** — under `--headless` the viewport comes back
blank:

```bash
godot --path . tests/screenshot.tscn -- shots
```

There is no lint step and no coverage tooling.

**Only test pure maths** — sand arithmetic, geometry, plane steps, layout
numbers, filename parsing. Nothing here plays a level, scripts input, or
compares screenshots. When a change is not expressible as a number, say so and
hand over a run command instead of inventing a test around it.

## Architecture

### Autoloads

Registered in this order in `project.godot`, and the order matters — `Game`
spells out `user://settings.cfg` itself rather than reading it off `Audio`,
because `Audio` does not exist yet when `Game._ready()` runs.

| Autoload | Script | Owns |
|---|---|---|
| `Tuning` | `scripts/autoload/tuning.gd` | The one `GameConfig`, read as `Tuning.cfg.<name>` |
| `Game` | `scripts/autoload/game.gd` | Run state: sand, chambers, plane, status, progression |
| `Glass` | `scripts/autoload/glass.gd` | The single `HourglassMotion` (tumble/slosh) |
| `Screen` | `scripts/autoload/screen.gd` | Fullscreen toggle, nothing else |
| `Audio` | `scripts/autoload/audio.gd` | Playback by id + bus volumes |

### Nobody talks to anybody directly

`Game` holds the run state and no rendering. It emits `plane_changed`,
`next_plane_changed`, `flipped`, `status_changed`, `gravity_changed`,
`flow_changed` and `level_loaded`; entities and the HUD listen. **Adding an
entity type means writing one script** — it connects to the signals it cares
about and nothing else has to learn it exists.

Two consequences worth knowing before touching `Game`:

- `Game.sand` is a **property computed over the draining chambers**, and it must
  stay writable. A getter-only property is not an error in GDScript:
  `Game.sand = x` compiles, does nothing, and the next read returns the old
  value.
- The inversion flow is **polled**, not pushed (`poll_sand_flow`, over the
  `inversion_zones` group). A group rather than a registry so unloading a level
  deregisters every zone for free, and polling so a reload inside a zone cannot
  leave an `entered` owing its `exited`.

### Plane switching is one uniform rule

`Planes` (`scripts/planes.gd`) is the whole of it: `Kind` is `P0..P3` plus
`BOTH`, and `BOTH` deliberately sits *after* the real planes so `int(kind) <
COUNT` means "a real plane". On `plane_changed` every entity asks
`Planes.is_active(plane, current)` and either drops off the physics layer
(solids: `collision_layer = 0`) or stops monitoring (areas), then redraws as a
ghost. `Planes.step` is the only place a jump's plane arithmetic lives.

A plane-bound **solid** is never brightened towards looking solid — it carries a
dashed `PlaneMarker` line instead. Hazards and zones do lift, because there is
nothing to stand on there to be misled about.

### The glass is derived, not tabulated

`ChamberLayout` (`scripts/chamber_layout.gd`) derives everything from one
sentence: chamber `i` points at `i * TAU / N`, clockwise from straight up. Which
chambers drain (`UPPER`), receive (`LOWER`), are sealed (`LEVEL`), and who pours
into whom all fall out of that — so there is no table to keep in sync with the
picture. Valid for 2–4 chambers; the cap lives on `Level.chambers`, where a
designer can see it.

`HourglassMotion` works out `down` (gravity in the glass's own frame) and
`HourglassShape` cuts every free surface square to it, bisecting for the cut
that leaves exactly the right area below. There is **one** glass: the player
sprite and the HUD gauge both read `Glass.motion`, so they cannot drift.

### Lifecycle

`scripts/main.gd` on `scenes/main.tscn` is the conductor: it loads the current
level, spawns the player as a **child of the level** (so a reload wipes it),
frames the camera, configures shadows and backdrop, picks the music, then calls
`Game.announce_level`. Level **rules** are applied here (`_apply_level_rules`),
not in `Game.start_level`, which runs before the level scene exists — and they
are reset every load, so a level cannot leak its rules into the next.

### Levels are data, discovered at startup

`scenes/levels/*.tscn` is scanned by `Game._discover_levels()`. A new `.tscn`
needs no wiring: play order comes from the number in the filename
(`Level.number_from_path`) and the title shown in the menu and HUD comes from
the rest of it (`Level.title_from_path`), so `level_04_the_spring.tscn` is
level 4, "The Spring". Sorting is `Game.level_before`, not a plain string sort,
which would file `level_100` between `level_09` and `level_10`.

`Level` (`scripts/level.gd`) is data and scenery only — `world_size`, `theme`,
and the `Rules` group (`chambers`, `sand_start_override`, `clock_starts_on_move`,
`jump_locked_first_life`).

### Entities

Compose off one of two bases instead of writing an entity from scratch:

- **`PlaneArea`** (`scripts/entities/plane_area.gd`) — plane-aware triggers
  (door, spring, spikes, monster). Override `_touched()` and `_paint()`, **not**
  `_draw()`: the base owns the frame so the editor plane tag lands on every
  entity for free.
- **`Platform`** (`scripts/entities/platform.gd`) — a solid rectangle, static or
  moving, plus the flip-pad variant. Static ground belongs in a `Terrain`
  polygon instead.

Origins are the **top-left** corner of `size`, not the centre. Entity scripts
are `@tool` scripts that redraw live in the editor, so anything with runtime
side effects is guarded by `Engine.is_editor_hint()`. `Layers`
(`scripts/entities/layers.gd`) mirrors Project Settings → Layer Names → 2D
Physics and must stay in sync with it by hand.

### Drawing and colour

Entities never hard-code a colour — they ask `Palette`
(`scripts/entities/palette.gd`), which keeps a deliberate four-family hue
budget: plane hue for the world, warm gold for time, magenta-red for danger,
mint for the spring. `Level.group_of(node)` answers which theme a piece of
scenery is in.

Light is subtractive: a `CanvasModulate` sits the world at `world_light` and
lights add back on top. The glass carries the only shadow caster; `CastShadows`
builds a `LightOccluder2D` per solid from the same outline the solid is drawn
from (`shadow_outline()`), inset a few px so it does not band along its own lit
face.

### Gravity is one signed number

`Game.gravity_sign` is +1 or -1 and every vertical quantity is written as a
downward component times it, so an upside-down world runs the same arithmetic.
A `gravity_pad` **SETS** a direction and never toggles one, which is what makes
it safe to stand on. Go through `Game.set_gravity()`; it is idempotent and has
to tell the player.

### Tuning

Every gameplay number lives in `scripts/game_config.gd` and is edited in
`resources/game_config.tres`. Where a number belongs:

| Home | For |
|---|---|
| `game_config.gd` | One value for the whole game (`gravity`, `sand_drain_rate`) |
| `@export` on an entity | Varies per instance in a level (a platform's `size`) |
| `const` in the script | Drawing detail that never usefully varies |

### Editor tooling

`addons/level_tools/` draws viewport handles for patrol tracks and entity sizes.
Every gizmo writes the same exported properties the Inspector does, so a level's
numbers stay in one place.

## Conventions

- **English everywhere** — code, comments, commits, docs, in-game text.
- **Typed GDScript throughout**, including inferred locals (`:=`) and return
  types. `class_name` on anything referenced by name.
- **`##` doc comments** on every script, class, signal, exported property and
  non-obvious function. The script's own `##` header says what it owns.
- **Comments explain *why*, never what.** The house style states the failure a
  line prevents ("Must run after the camera has moved this frame, or the walls
  judder") rather than restating the code. When a change is validated, cut its
  comments back to what the code cannot say itself.
- Pure-maths helpers are `static func` on a `class_name … extends RefCounted`
  utility class (`Planes`, `ChamberLayout`, `Polygons`, `HourglassShape`) — no
  instances, no state, directly testable headless.
- Sections inside a long script are separated by
  `# ----- Section ------------------`.
- Markdown wraps at 80 chars; commands in code blocks are never wrapped.
- Commit subjects say what the change does for the game ("Open the exit as a
  portal instead of a panel"), not which files moved. No `feat:` / `fix:`
  prefixes.

## Further documentation

- [README.md](README.md) — the rules and the layout in brief.
- [docs/DESIGN.md](docs/DESIGN.md) — why the sand, planes, gravity and light
  behave as they do.
- [docs/LEVELS.md](docs/LEVELS.md) — the level-authoring reference: entity
  table, the rules a level may bend, how to tune.
- [audio/README.md](audio/README.md) — the sound bank, the ids the game already
  asks for, buses.
