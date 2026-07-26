# Sandbound — Godot 4

A platformer where the player **is** an hourglass. The sand drains continuously;
at zero, you die. Every jump does three things at once:

1. **Flips the hourglass** — the drained sand comes back, so `sand` becomes
   `SAND_MAX - sand`. Flip while nearly empty and you refill; flip while full
   and you are left with almost nothing.
2. **Swaps plane** — a level exists as two (or up to four) superimposed
   versions with different platforms and monsters. The jump teleports you
   between them at the same `(x, y)`.
3. **Launches you** — an ordinary upward impulse.

So **you can only refuel by net-changing plane**. Two elements bend that: a
**spring** throws you with no flip, and a **flip-pad** flips the sand with no jump
and no plane change.

Godot 4 port of the vanilla-JS prototype in `../hourglass_hero`.

## Running

```bash
godot --path hourglass_hero_godot
```

`←`/`→` or `A`/`D` move, `Space`/`W`/`↑` jump, `R` restarts, `Esc` returns to
the menu, `Alt+Enter` (or `F11`) leaves fullscreen.

It launches fullscreen at a 960×540 design resolution — every level coordinate
is in those units — letterboxed to fit, so a level frames identically on every
display.

## The menu

`scenes/ui/main_menu.tscn` is the entry point: one button per level, built from
`Game.level_scenes`, each label titled from the level's own filename
(`level_04_the_spring.tscn` → "The Spring"). A new level shows up on the next
run with nothing to wire.

Every level is unlocked. Set `Game.unlock_all = false` and `Game.is_unlocked()`
falls back to `levels_reached`.

## Tuning

Every gameplay number lives in [`scripts/game_config.gd`](scripts/game_config.gd).
Edit `resources/game_config.tres` in the Inspector.

Adding a tunable is one line:

```gdscript
@export_range(0.0, 500.0, 5.0) var dash_speed: float = 320.0
```

| Home | For | Example |
|---|---|---|
| `game_config.gd` | One value for the whole game | `gravity`, `sand_drain_rate` |
| `@export` on an entity | Varies per instance in a level | a platform's `size`, a spring's `power` |
| `const` in the script | Drawing detail that never usefully varies | chevron length, eye radius |

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

### The building blocks

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
into a faint, non-solid ghost. A plane-bound *solid* is never lifted back towards
looking solid — looking solid is the one thing that would lie about it. It
carries a dashed line outside its silhouette instead, in its plane's hue,
strongest in the plane the next jump lands in (`PlaneMarker`,
`next_outline_gap`). Hazards and zones do lift (`ghost_next_lift`): there is
nothing to stand on there to be misled about.

Moving entities travel `move_distance` px from where you placed them and back,
so you author the *start* of the path. `move_phase` is the only way to break two
movers of equal period out of lockstep.

Spikes kill on the inner 75% of the band, not on the outline: the tips are
visual overhang, because spikes that kill on their silhouette feel cheap.

### The rules a level may bend

On the level root, under **Rules**:

| Property | Effect |
|---|---|
| `chambers` | How many chambers the glass has, 2 to 4 — and so how many planes, and how far a jump turns you. |
| `sand_start_override` | Sand you begin with, in ms. 0 uses the tuned `sand_start`. |
| `clock_starts_on_move` | The sand does not run until the player first steers. |
| `jump_locked_first_life` | No jump until this level has killed you once. |

All are applied by `main.gd` after the scene exists and reset between levels, so
a level cannot leak its rules into the next.

### Gravity

Gravity is a pad you place, not a level rule, so any level can gain one without
being rebuilt. Underneath it is one signed number, `Game.gravity_sign`: every
vertical quantity is a downward component times that sign, so an upside-down
world runs the same arithmetic as every other.

A pad SETS a direction and never toggles one. That is what makes it safe to
stand on and lets two pads facing the same way agree instead of cancelling.
Every level starts the right way up.

### The sand economy

The glass carries one bulb of sand per turn it takes to get a drained bulb back
on top — one at two and three chambers, two at four, where the sand lands
opposite. The top always opens at `sand_start`, so the runway before the first
turn is the same everywhere; the count only changes what comes back. Three
chambers split every drain in two and hand back only the half you turn into.

`sand_flip_base` is 0, so on a two-chamber glass a turn gives back exactly
`max - sand`: an involution. Two turns return you to your starting plane **and**
your starting sand, so a double jump is pure height and pure time — free while
you are full, ruinous while you are empty. `sand_test.gd` guards the identity.

### The levels

| # | Level | What it teaches |
|---|---|---|
| 1 | Wake-Up | The tutorial, taught by killing you once. Frozen and jumpless, so the only thing to try is walking — and walking is 68 px short of the door. |
| 2 | The Void | The far floor is `BACK`: the last hop has to be a step, not a jump. |
| 3 | The Ledge | A spike ceiling forbids refuelling for 820 px. Fill up *before* you commit. |
| 4 | The Spring | Height without a flip, climbing a shaft. |
| 5 | The Fountain | One plane, no jumping: the flip-pad ferries are the only refuel. |
| 6 | Parity | Flip count is a resource. A ghost ledge that can never be stood on. |
| 7 | Ten | Ten ledges, each narrower, planes forced to alternate all the way up. |
| 8 | Metronome | Five movers, one period, five phases. Cross on the beat. |
| 9 | The Well | Descending. Every depth is half solid; a flip swaps which half. |
| 10 | Double or Nothing | One feather, one air jump. Reach bought with time, never sand — and only once. |
| 11 | Midnight | The gauntlet: everything so far, over a spike pit, finishing in `BACK`. |
| 12 | The Last Grain | 1.2 s on the clock. Empty is not a problem, it is the resource. |
| 13 | The Updraft | An inversion zone runs the glass backwards: standing still fills you, and a full glass shatters. |
| 14 | Trefoil | Three chambers, three planes. A jump turns you a third of the way. |
| 15 | Quarters | Four chambers, and sand that can be stranded two turns from where you need it. |
| 16 | Crossfire | Two lasers lock on before they fire. Dodging the shot is the jump, and the jump is the refuel. |
| 17 | Downside Up | A pad turns the world over. The ceiling is the only bridge across the pit. |

## Architecture

```
scripts/
  game_config.gd          Resource: every tunable number
  hourglass_shape.gd      Draws the glass — shared by the player and the HUD gauge
  hourglass_motion.gd     The tumble, the sand's slosh, the trickle's wobble
  chamber_layout.gd       Which chamber drains, receives, or is sealed
  planes.gd               FRONT / BACK / BOTH and the "is it active?" rule
  polygons.gd             Winding, outward normals, offset — the drawn ground
  level.gd                Level root: name, bounds, spawn
  main.gd                 Loads levels, spawns the player, drives the camera
  autoload/
    tuning.gd    (Tuning) Owns the single GameConfig read across the game
    game.gd      (Game)   Sand, plane, status, progression + signals
    glass.gd     (Glass)  The one HourglassMotion: player and HUD share it
    audio.gd     (Audio)  Music, sfx and the volume buses
    screen.gd    (Screen) The window: launches fullscreen, Alt+Enter toggles
  entities/
    player.gd             CharacterBody2D: coyote time, jump buffer, jump cut
    terrain.gd            StaticBody2D drawn FROM its own collision polygon
    platform.gd           AnimatableBody2D, carries riders, flip-pad variant
    spring.gd  monster.gd  spikes.gd  cannon.gd  door.gd  gravity_pad.gd
    inversion_zone.gd  hint_sign.gd  plane_area.gd  feather.gd
    hourglass_visual.gd   Draws the glass, the sand and the flip tumble
    ping_pong.gd  palette.gd  bricks.gd  layers.gd
  fx/
    backdrop.gd  backdrop_layer.gd  Parallax city behind the level
    camera_rig.gd         Follow, lead, slack, shake
    burst.gd              Dust, sparks, shatter, spill
    light_kit.gd          Builds the 2D lights from a shared radial falloff
    entity_light.gd       The glow on doors, springs, pads and hazards
    outline.gd            The ink around a shape, and the dashed marker
    plane_marker.gd       The dashed line saying which plane a solid is in
    cast_shadows.gd       Hands every solid a LightOccluder2D
  ui/
    main_menu.gd          Title screen + level select, built from the level list
    hud.gd                Sand gauge, level name, end screens
    audio_settings.gd     One volume slider per bus
```

Two ideas hold it together:

- **Nobody talks to anybody directly.** `Game` owns the run state and emits
  `plane_changed` / `next_plane_changed` / `status_changed` / `level_loaded`;
  entities and the HUD listen. Adding an entity type means writing one script.
- **Plane switching is one uniform rule.** On `plane_changed`, every entity asks
  `Planes.is_active(plane, current)` and either leaves the physics layer (solids)
  or stops monitoring (areas), then redraws as a ghost.

### Light and shadows

`CanvasModulate` sits the world at `world_light` and every light adds back on
top. The glass carries the only one that casts: `CastShadows` gives each solid a
`LightOccluder2D` built from the outline it is drawn from, parented to the caster
so a moving platform drags its shadow along. A solid in another plane is
walk-through, so it stops casting.

The result is subtractive — nothing is painted over the world, the lamp simply
does not arrive behind a wall — so two shadows crossing are no darker than one.
Occluders are inset a few px inside their solid: Godot's shadow map darkens
everything past the first surface a ray meets, the caster included, so an outline
sitting exactly on the drawn surface bands along its own lit face.

## Tests

The levels are played, not tested. The benches cover the maths under them and
nothing else.

```bash
godot --path hourglass_hero_godot --headless tests/sand_test.tscn
```

The sand test checks the geometry: that the area drawn equals the sand there is
at every tilt, that the free surface stays level in *world* space rather than
turning with the walls, and that a flip lands with no jump in the sand.

```bash
godot --path hourglass_hero_godot --headless tests/chamber_layout_test.tscn
```

The chamber layout test checks the multi-chamber glass: which chambers drain,
receive or seal shut at each count, who pours into whom, and the lessons the
three- and four-chamber levels are built to teach.

```bash
godot --path hourglass_hero_godot --headless tests/polygon_test.tscn
```

The polygon test checks the geometry the drawn ground stands on: which way a
polygon winds, which edges face the sky, and that the occluder inset grows a
long thin slab on all four sides.

## How the sand moves

The sand is a liquid, not a block glued inside the glass. `HourglassMotion`
works out `down` — where gravity points *in the glass's own frame* — and
`HourglassShape` cuts every free surface square to it, bisecting for the cut that
leaves exactly the right area below. Tip the glass and the sand pools in whatever
corner is lowest.

- **The neck gates the sand.** Each bulb keeps its own contents mid-tumble, which
  is why a real hourglass laid on its side does not empty.
- **A flip lands seamlessly because the bulbs are each other turned half a turn.**
  The glass snaps from π back to 0, and at that same instant `chambers()` swaps
  which bulb holds what. The two cancel exactly; `sand_test.tscn` guards it.
- **There is one glass, drawn twice.** The sprite and the HUD gauge both read the
  single `HourglassMotion` held by the `Glass` autoload, so they cannot drift.
