# Inversion Zone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a region of the level where the hourglass runs backwards — sand flows bottom to top, `Game.sand` rises, and an empty *bottom* bulb kills.

**Architecture:** `Game` keeps sole ownership of the clock. It asks a Godot group (`inversion_zones`) once per frame whether the player stands in a zone, caches the answer as `Game.sand_flow` (+1 or −1), and applies it to both the drain and `danger()`. `InversionZone extends PlaneArea`, so it inherits size, plane-awareness, ghosting and light for free; it reports containment by polling `has_overlapping_bodies()` rather than tracking enter/exit state. The reversed *visual* falls out of multiplying `HourglassMotion.down()` by `sand_flow`, plus one generalisation in `HourglassShape.draw_glass` so the trickle stops assuming gravity points down.

**Tech Stack:** Godot 4.7.1, GDScript, GL Compatibility. No new dependencies.

**Design doc:** `docs/superpowers/specs/2026-07-25-inversion-zone-design.md`

---

## Deviations from the spec

Two, both found by reading the code after the spec was approved. Each is
implemented as written here, not as written in the spec.

1. **The trickle needs a real fix, not just a flipped vector.** The spec said
   flipping `down` "should" work and flagged it unverified. It does not work
   alone: `pouring` is computed from `down.y` (negative when inverted → zero
   flow) and the source bulb is hard-coded to `chambers.x`. Task 4 generalises
   both. The spec's fallback (an explicit `up` flag) is **not** used — it would
   add a parameter that duplicates information `down` already carries.

2. **Tests split across two suites.** The spec put every test in
   `sand_test.gd`. That file is a pure-maths bench: no scene tree, no player, no
   physics frame, so it cannot make an `Area2D` overlap a body. Arithmetic and
   `danger()` go there (Task 2); real containment, death at `sand_max` and the
   plane rule go to `smoke_test.gd` (Task 6), which boots the actual game.

3. **Group membership is added in `_ready()`, not in the `.tscn`.** The spec
   said "from the scene file". Doing it in code lets `Game.INVERSION_GROUP` be
   the single source of the string; a group name typed into a `.tscn` can drift
   from the constant with nothing to catch it.

Also confirmed while reading: **`HourglassMotion.chambers()` needs no change.**
It fills the upper bulb from `Game.sand / sand_max`, and `Game.sand` rising *is*
the upper bulb filling. Nothing to do.

---

## Setup (do this once, before Task 1)

The worktree has no Godot import cache. Scenes will hang without it.

- [ ] **Step 0: Prime the import cache**

```bash
cd /private/tmp/claude-501/-Users-justinchapon-GMTK-Game-Jam-2026/3f8102ba-d742-4ca9-8a1d-4e1f47db11d5/scratchpad/wt-gravity/hourglass_hero_godot
godot --path . --headless --editor --quit
```

Expected: exits 0. A `.godot/` directory now exists.

- [ ] **Step 1: Confirm the suites pass before any change**

```bash
godot --path . --headless tests/sand_test.tscn && godot --path . --headless tests/smoke_test.tscn
```

Expected: both print `All checks passed.` and exit 0.

**Note on tooling, learned the hard way on earlier work in this repo:**
- Never write GDScript through a bash heredoc — it strips tab indentation and
  every file becomes a parse error. Use the Write/Edit tools.
- Never pipe a long `godot` run through `| tail` — output buffers and you see
  nothing. Redirect to a file and read the file.
- `var x := scene.instantiate()` fails to infer a type. Write
  `var x: Node2D = scene.instantiate()`.
- `Game.Status` is `{ PLAY, DEAD, LEVEL_CLEAR, VICTORY }`. There is no `PLAYING`.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `scripts/game_config.gd` | Tunables | Modify: add `sand_reverse_rate` |
| `scripts/autoload/game.gd` | Owns the clock and the death rule | Modify: `INVERSION_GROUP`, `sand_flow`, `poll_sand_flow()`, `_process`, `danger()` |
| `scripts/entities/inversion_zone.gd` | One zone: containment + its own look | Create |
| `scenes/entities/inversion_zone.tscn` | The placeable entity | Create |
| `scripts/hourglass_motion.gd` | How a drawn glass moves | Modify: `down()` |
| `scripts/hourglass_shape.gd` | Pure drawing | Modify: trickle source and rate |
| `scenes/levels/level_13_the_updraft.tscn` | Teaches the mechanic | Create |
| `tests/sand_test.gd` | Pure-maths bench | Modify: flow + danger checks |
| `tests/smoke_test.gd` | Plays the real game | Modify: containment + death checks |

---

## Task 1: The tunable

**Files:**
- Modify: `scripts/game_config.gd` (near `sand_drain_rate`, line ~43)

- [ ] **Step 1: Add the setting**

Insert immediately after the `sand_drain_rate` export:

```gdscript
## How fast sand flows the WRONG way, inside an inversion zone, in ms per
## second. Defaults to `sand_drain_rate` so the two directions are symmetric:
## `sand_start` is half of `sand_max`, which leaves the same headroom whichever
## end is trying to kill you. Raise it to make zones a place you cannot linger.
@export_range(0.0, 5000.0, 10.0) var sand_reverse_rate: float = 1000.0
```

- [ ] **Step 2: Verify the project still loads**

```bash
godot --path . --headless tests/sand_test.tscn
```

Expected: `All checks passed.`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add scripts/game_config.gd
git commit -m "feat(hourglass-hero): add sand_reverse_rate"
```

---

## Task 2: `Game` owns the direction

**Files:**
- Modify: `scripts/autoload/game.gd`
- Test: `tests/sand_test.gd`

- [ ] **Step 1: Write the failing tests**

In `tests/sand_test.gd`, insert this block immediately before the final
`_finish()` call (currently line 123):

```gdscript
	# --- The inversion zone reverses the clock --------------------------------
	# `Game.sand_flow` is asked of a Godot group, so a stub in that group is
	# enough to drive it. That keeps this bench pure: no level, no player, no
	# physics frame. Real containment is smoke_test's job.
	_check("no zones means the sand flows normally", Game.poll_sand_flow() > 0.0)

	var empty_zone := _StubZone.new(false)
	var full_zone := _StubZone.new(true)
	add_child(empty_zone)
	add_child(full_zone)

	empty_zone.add_to_group(Game.INVERSION_GROUP)
	_check("a zone the player is NOT in leaves the flow alone",
		Game.poll_sand_flow() > 0.0)

	full_zone.add_to_group(Game.INVERSION_GROUP)
	_check("standing in a zone reverses the flow", Game.poll_sand_flow() < 0.0)

	# Two zones must not invert twice. The flow is a direction, not a total.
	var second: _StubZone = _StubZone.new(true)
	add_child(second)
	second.add_to_group(Game.INVERSION_GROUP)
	_check("overlapping zones invert once, not twice",
		is_equal_approx(Game.poll_sand_flow(), -1.0),
		"flow = %.2f" % Game.sand_flow)
	second.queue_free()
	full_zone.remove_from_group(Game.INVERSION_GROUP)
	_check("leaving every zone restores the normal flow",
		Game.poll_sand_flow() > 0.0)

	# --- Danger measures the death that is ACTUALLY active --------------------
	# Read the wrong end and the gauge says "all clear" while you climb towards
	# your death. Palette.sand() feeds the sprite, the HUD and the player's
	# light off this one number, so getting it wrong lies in three places.
	full_zone.add_to_group(Game.INVERSION_GROUP)
	Game.poll_sand_flow()
	Game.sand = cfg.sand_max
	_check("inverted, a FULL glass is maximum danger",
		is_equal_approx(Game.danger(), 1.0), "danger = %.3f" % Game.danger())
	Game.sand = 0.0
	_check("inverted, an EMPTY glass is safe",
		is_zero_approx(Game.danger()), "danger = %.3f" % Game.danger())

	full_zone.remove_from_group(Game.INVERSION_GROUP)
	Game.poll_sand_flow()
	Game.sand = 0.0
	_check("normally, an EMPTY glass is maximum danger",
		is_equal_approx(Game.danger(), 1.0), "danger = %.3f" % Game.danger())
	Game.sand = cfg.sand_max
	_check("normally, a FULL glass is safe", is_zero_approx(Game.danger()),
		"danger = %.3f" % Game.danger())

	empty_zone.queue_free()
	full_zone.queue_free()
```

Then append this stub class at the very end of the file, after `_finish()`:

```gdscript
## Stands in for an InversionZone so the flow can be tested without a scene
## tree full of physics. `Game` only ever asks a zone one question.
class _StubZone extends Node:
	var _occupied: bool

	func _init(occupied: bool) -> void:
		_occupied = occupied

	func contains_player() -> bool:
		return _occupied
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
godot --path . --headless tests/sand_test.tscn > /tmp/sand.log 2>&1; echo "exit=$?"; cat /tmp/sand.log
```

Expected: FAIL — a parse or runtime error naming `INVERSION_GROUP` and
`poll_sand_flow`, which do not exist yet. Exit code non-zero.

- [ ] **Step 3: Add the group constant and the flow state**

In `scripts/autoload/game.gd`, after `const LEVELS_DIR := "res://scenes/levels"`
(line 7):

```gdscript
## Nodes in this group are asked `contains_player()` once a frame. A group
## rather than a registry the zones write into: membership is managed by the
## scene tree, so unloading a level deregisters every zone for free and no
## stale entry can survive a restart.
const INVERSION_GROUP := "inversion_zones"
```

After `var status: Status = Status.PLAY` (line 34):

```gdscript
## Which way the sand runs: +1 normally, -1 inside an inversion zone. Cached
## once per frame by `poll_sand_flow()` because `danger()` is read several
## times a frame by the HUD, the sprite and the player's light.
var sand_flow := 1.0
```

- [ ] **Step 4: Add the query**

Add this function immediately after `_process` in `scripts/autoload/game.gd`:

```gdscript
## Asks every zone whether it holds the player, caches the answer in
## `sand_flow` and returns it. Zones never push to `Game`: one direction of
## dependency means there is only ever one writer of the clock.
##
## One containing zone is enough — overlapping zones do not stack, because the
## flow is a direction and not a total.
func poll_sand_flow() -> float:
	sand_flow = 1.0
	for zone in get_tree().get_nodes_in_group(INVERSION_GROUP):
		if zone.contains_player():
			sand_flow = -1.0
			break
	return sand_flow
```

- [ ] **Step 5: Make the clock run both ways**

Replace the body of `_process` (currently lines 56–67) with:

```gdscript
func _process(delta: float) -> void:
	if flip_anim > 0.0:
		flip_anim = maxf(0.0, flip_anim - delta)
	if pad_flash > 0.0:
		pad_flash = maxf(0.0, pad_flash - delta)
	if status != Status.PLAY:
		return
	# Sand flows continuously, and BOTH ends of the glass kill. Normally it
	# drains and an empty top bulb is death; inside an inversion zone it runs
	# backwards and an empty BOTTOM bulb — a full gauge — is death instead.
	# There is nowhere in the game where standing still is safe.
	var cfg := Tuning.cfg
	var flow := poll_sand_flow()
	var rate := cfg.sand_reverse_rate if flow < 0.0 else cfg.sand_drain_rate
	sand += delta * rate * flow
	if flow < 0.0:
		if sand >= cfg.sand_max:
			sand = cfg.sand_max
			set_status(Status.DEAD)
	elif sand <= 0.0:
		sand = 0.0
		set_status(Status.DEAD)
```

- [ ] **Step 6: Make `danger()` bilateral**

Replace `danger()` (currently lines 204–209) with:

```gdscript
## How close death is, from 0 (safe) to 1 (about to run out) — measured against
## whichever end is currently lethal. Flowing normally that is an empty glass;
## inverted it is a full one.
##
## One place on purpose: `Palette.sand()` feeds the sprite, the HUD gauge and
## the light the player carries off this single number, and those three are
## documented as readings of one clock that must never disagree.
func danger() -> float:
	var cfg := Tuning.cfg
	var warn := cfg.sand_warn
	if warn <= 0.0:
		return 0.0
	var left := cfg.sand_max - sand if sand_flow < 0.0 else sand
	if left > warn:
		return 0.0
	return clampf(1.0 - left / warn, 0.0, 1.0)
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
godot --path . --headless tests/sand_test.tscn > /tmp/sand.log 2>&1; echo "exit=$?"; cat /tmp/sand.log
```

Expected: `All checks passed.`, exit 0, including the seven new lines.

- [ ] **Step 8: Confirm nothing else broke**

```bash
godot --path . --headless tests/smoke_test.tscn > /tmp/smoke.log 2>&1; echo "exit=$?"; cat /tmp/smoke.log
```

Expected: `All checks passed.`, exit 0.

- [ ] **Step 9: Commit**

```bash
git add scripts/autoload/game.gd tests/sand_test.gd
git commit -m "feat(hourglass-hero): let the clock run both ways

Game asks a group whether the player stands in an inversion zone and caches
the direction. Both ends of the gauge now kill, and danger() measures the
death that is actually active instead of always watching the bottom."
```

---

## Task 3: The `InversionZone` entity

**Files:**
- Create: `scripts/entities/inversion_zone.gd`
- Create: `scenes/entities/inversion_zone.tscn`

- [ ] **Step 1: Write the script**

Create `scripts/entities/inversion_zone.gd`:

```gdscript
@tool
## A region where the hourglass runs backwards: sand climbs from the bottom
## bulb to the top one, and an empty BOTTOM bulb kills.
##
## The fiction sold to the player is gravity. Nothing here touches physics —
## you fall, jump and bounce exactly as you do outside. Only the sand turns
## round. A zone is therefore a refuel station AND a trap, told apart by
## nothing but how long you stay, which is why it needs no anti-camping rule:
## there is no safe place to stand at either end of the gauge.
##
## Unlike every other [PlaneArea], this is a state and not an event, so it
## ignores `_touched()` and answers `contains_player()` by polling instead.
## Polling has no state to corrupt: dying or reloading inside a zone cannot
## leave a stale "you are inside" flag set forever, which an enter/exit counter
## can and does.
##
## The node's origin is the TOP-LEFT corner of `size`, like every other solid.
class_name InversionZone
extends PlaneArea

## The interior wash and its boundary, as alpha. The zone must read as a place,
## not as a thing to collect: the gold family is otherwise spent on small bright
## solids (the door, the flip-pad), so this stays large, faint and outlined.
## Same hue budget, opposite treatment.
const FIELD_ALPHA := 0.10
const EDGE_ALPHA := 0.5
## Rising motes: the only part that says "upward" while you stand still.
const MOTE_COLUMNS := 5
const MOTE_SPEED := 110.0 ## px per second
const MOTE_LENGTH := 16.0

var _phase := 0.0


func _init() -> void:
	# Roughly eight player-widths across and tall enough to stand in with room
	# to panic: a zone you can cross by accident teaches nothing.
	size = Vector2(220.0, 240.0)
	light_tint = Palette.FLIP_PAD
	light_radius = 200.0
	light_energy = 0.5


func _ready() -> void:
	super()
	# In code rather than in the .tscn so `Game.INVERSION_GROUP` is the only
	# place the string exists. A group name typed into a scene file can drift
	# from the constant with nothing to catch it.
	add_to_group(Game.INVERSION_GROUP)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_phase = fmod(_phase + delta * MOTE_SPEED, size.y)
	queue_redraw()


## True while the player stands inside AND this zone is in their plane.
##
## No player reference is needed: the collision mask is `Layers.PLAYER`, so an
## overlapping body can only be the player. And `PlaneArea` already drops
## `monitoring` when the zone is out of plane, so a ghost reports nothing and
## the plane rule costs no code at all.
func contains_player() -> bool:
	return _active and has_overlapping_bodies()


func _draw() -> void:
	var tint := _shade(Palette.FLIP_PAD)
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(tint, tint.a * FIELD_ALPHA))
	draw_rect(bounds, Color(tint, tint.a * EDGE_ALPHA), false, 2.0)

	# Motes climb, evenly spread so the column never reads as a single object
	# drifting past. They are clipped to the zone, which keeps the boundary —
	# the thing the player must judge — the strongest line in the drawing.
	for i in MOTE_COLUMNS:
		var x := size.x * (i + 0.5) / MOTE_COLUMNS
		var travelled := fmod(_phase + size.y * i / float(MOTE_COLUMNS), size.y)
		var head := size.y - travelled
		draw_line(Vector2(x, head), Vector2(x, minf(head + MOTE_LENGTH, size.y)),
			Color(tint, tint.a * EDGE_ALPHA), 2.0, true)
```

- [ ] **Step 2: Write the scene**

Create `scenes/entities/inversion_zone.tscn`. Copy the shape of
`scenes/entities/spikes.tscn` exactly — `collision_layer = 0` and
`collision_mask = 2` (`Layers.PLAYER`) are what make `has_overlapping_bodies()`
mean "the player is here":

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/entities/inversion_zone.gd" id="1_inversion"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_inversion"]
resource_local_to_scene = true
size = Vector2(220, 240)

[node name="InversionZone" type="Area2D"]
collision_layer = 0
collision_mask = 2
script = ExtResource("1_inversion")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(110, 120)
shape = SubResource("RectangleShape2D_inversion")
```

- [ ] **Step 3: Verify the scene loads**

```bash
godot --path . --headless --editor --quit > /tmp/import.log 2>&1; echo "exit=$?"; grep -i "error\|SCRIPT" /tmp/import.log || echo "no errors"
```

Expected: exit 0, no script errors.

- [ ] **Step 4: Confirm both suites still pass**

```bash
godot --path . --headless tests/sand_test.tscn && godot --path . --headless tests/smoke_test.tscn
```

Expected: both `All checks passed.`

- [ ] **Step 5: Commit**

```bash
git add scripts/entities/inversion_zone.gd scenes/entities/inversion_zone.tscn
git commit -m "feat(hourglass-hero): add the InversionZone entity"
```

---

## Task 4: The glass runs backwards on screen

**Files:**
- Modify: `scripts/hourglass_motion.gd:79-80`
- Modify: `scripts/hourglass_shape.gd:85-96`
- Test: `tests/sand_test.gd`

Two changes. The first is one line. The second is the one the spec got wrong:
the trickle is written assuming the source is the upper bulb and that gravity
points down, so a flipped vector alone silently deletes it.

- [ ] **Step 1: Write the failing test**

In `tests/sand_test.gd`, insert immediately before the final `_finish()` call —
after the block added in Task 2, and note it reuses `full_zone`, so add it
*before* the `full_zone.queue_free()` line:

```gdscript
	# --- The drawn glass follows the flow -------------------------------------
	# `down()` is what both drawing sites use to decide where sand pools and
	# which way the trickle runs, so reversing the clock has to reverse it too.
	full_zone.add_to_group(Game.INVERSION_GROUP)
	Game.poll_sand_flow()
	var motion := HourglassMotion.new()
	_check("inverted, the sand falls UP the glass", motion.down().y < 0.0,
		"down = %v" % motion.down())
	full_zone.remove_from_group(Game.INVERSION_GROUP)
	Game.poll_sand_flow()
	_check("normally, the sand falls DOWN the glass", motion.down().y > 0.0,
		"down = %v" % motion.down())

	# The trickle must survive the reversal. Read straight off the same maths
	# `draw_glass` uses: with the glass upright, sand pours at full rate in
	# either direction, and it is the SOURCE bulb that must swap.
	var hw := 24.0
	var hh := 36.0
	var wall := cos(atan2(hw - hw * HourglassShape.NECK_RATIO,
		hh - hh * HourglassShape.THROAT_RATIO))
	for dir in [Vector2.DOWN, Vector2.UP]:
		_check("the trickle pours with gravity %v" % dir,
			clampf((absf(dir.y) - wall) / (1.0 - wall), 0.0, 1.0) > 0.99)
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
godot --path . --headless tests/sand_test.tscn > /tmp/sand.log 2>&1; echo "exit=$?"; cat /tmp/sand.log
```

Expected: `FAIL  inverted, the sand falls UP the glass  (down = (0, 1))`.
Exit code non-zero.

- [ ] **Step 3: Turn the glass over**

In `scripts/hourglass_motion.gd`, replace `down()` (lines 76–80) with:

```gdscript
## Gravity as the glass sees it: straight down in the world, expressed in the
## glass's own frame, then leaned by the slosh. This is the one number that
## makes the sand behave like a liquid rather than a block glued to the walls.
##
## `Game.sand_flow` turns the whole vector over inside an inversion zone, which
## is the entire reversed visual: `draw_glass` reads this for where sand pools
## AND for which way the trickle runs, so one sign change moves both. The lean
## rides along, so a glass carried at a sprint still sloshes the right way.
func down() -> Vector2:
	return Vector2.DOWN.rotated(lean - tilt) * Game.sand_flow
```

- [ ] **Step 4: Stop the trickle assuming which way is down**

In `scripts/hourglass_shape.gd`, replace the trickle block (currently lines
85–96, from `var wall :=` through the `draw_line` call) with:

```gdscript
	var wall := cos(atan2(hw - nw, hh - nh))
	# Which bulb feeds the trickle is decided by gravity, not by the drawing:
	# invert `down` and the LOWER bulb becomes the one on top. Reading the rate
	# off `absf(down.y)` rather than `down.y` is what keeps a reversed glass
	# pouring at all — the signed version silently returned zero and the sand
	# just stopped moving, with both bulbs still drawn correctly filled.
	var source: float = chambers.x if down.y >= 0.0 else chambers.y
	var pouring := clampf((absf(down.y) - wall) / (1.0 - wall), 0.0, 1.0)
	if source > 0.01 and pouring > 0.01:
		var sideways := Vector2(-down.y, down.x)
		# Starts at the UNDERSIDE of the source bulb, not at the centre of the
		# glass. The bulb's sand stops at the top of the throat, so a trickle
		# beginning at the origin leaves the height of the throat as a gap of
		# bare glass — the sand reads as cut in two right where it should be
		# one continuous fall.
		var head := sideways * sin(phase) * 0.6 - down * nh
		canvas.draw_line(head, head + down * (hh * STREAM_REACH + nh),
			Color(sand, sand.a * pouring), line_width * 0.8, true)
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
godot --path . --headless tests/sand_test.tscn > /tmp/sand.log 2>&1; echo "exit=$?"; cat /tmp/sand.log
```

Expected: `All checks passed.`, exit 0. In particular the pre-existing checks
`filled area matches the sand asked for` and `the tumble lands with no jump in
the sand` must still pass — they exercise `_pour` at every tilt and are the
guard against this change breaking the normal glass.

- [ ] **Step 6: Confirm the game still plays**

```bash
godot --path . --headless tests/smoke_test.tscn > /tmp/smoke.log 2>&1; echo "exit=$?"; cat /tmp/smoke.log
```

Expected: `All checks passed.`

- [ ] **Step 7: Commit**

```bash
git add scripts/hourglass_motion.gd scripts/hourglass_shape.gd tests/sand_test.gd
git commit -m "feat(hourglass-hero): pour the glass upwards in a zone

down() turns over with the flow, and the trickle stops assuming gravity
points down: it reads its rate off |down.y| and takes its source from
whichever bulb gravity puts on top. Flipping the vector alone left both
bulbs correctly filled with no sand visibly moving between them."
```

---

## Task 5: Level 13 — "The Updraft"

**Files:**
- Create: `scenes/levels/level_13_the_updraft.tscn`

`Game._discover_levels()` scans the folder and sorts by filename, so the file
registers itself. Nothing to wire anywhere.

**The level teaches one sentence: a zone refuels you, and kills you if you
overstay.** Three beats, bottom to top, and the order is the point — the player
must learn a zone is *desirable* before they learn it is lethal, or they will
avoid every zone in the game.

**Trap to avoid, this has already cost time once in this repo:** every entity's
origin is its **TOP-LEFT** corner. A pad or zone resting on a floor sits at
`floor_top − own_height`, not at `floor_top`.

- [ ] **Step 1: Write the level**

Create `scenes/levels/level_13_the_updraft.tscn`:

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/level.gd" id="1_level"]
[ext_resource type="PackedScene" path="res://scenes/entities/door.tscn" id="2_door"]
[ext_resource type="PackedScene" path="res://scenes/entities/platform.tscn" id="3_platform"]
[ext_resource type="PackedScene" path="res://scenes/entities/spring.tscn" id="4_spring"]
[ext_resource type="PackedScene" path="res://scenes/entities/inversion_zone.tscn" id="5_zone"]

[node name="Level" type="Node2D"]
script = ExtResource("1_level")
level_name = "The Updraft"
world_size = Vector2(960, 1600)

[node name="Spawn" type="Marker2D" parent="."]
position = Vector2(90, 1480)

[node name="Entities" type="Node2D" parent="."]

[node name="Ground" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(40, 1540)
size = Vector2(880, 60)

[node name="ZoneSee" parent="Entities" instance=ExtResource("5_zone")]
position = Vector2(300, 1380)
size = Vector2(200, 160)

[node name="SpringUp" parent="Entities" instance=ExtResource("4_spring")]
position = Vector2(800, 1526)
size = Vector2(56, 14)
power = 1400.0

[node name="LedgeMid" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(620, 1180)
size = Vector2(300, 20)

[node name="LedgeLong" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(60, 1000)
size = Vector2(560, 20)

[node name="ZoneWant" parent="Entities" instance=ExtResource("5_zone")]
position = Vector2(80, 800)
size = Vector2(200, 200)

[node name="LedgeHigh" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(340, 720)
size = Vector2(280, 20)

[node name="ZoneFear" parent="Entities" instance=ExtResource("5_zone")]
position = Vector2(660, 420)
size = Vector2(240, 300)

[node name="LedgeTop" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(600, 400)
size = Vector2(320, 20)

[node name="Door" parent="Entities" instance=ExtResource("2_door")]
position = Vector2(720, 338)
size = Vector2(34, 62)
```

Geometry notes, so the numbers can be re-derived rather than nudged blindly:
- `Ground` top is 1540; `SpringUp` sits at `1540 − 14 = 1526`.
- `ZoneSee` bottom is `1380 + 160 = 1540` — flush with the ground, crossed on
  the way right. **Beat 1: see it.**
- `LedgeLong` is a 560 px run with nothing on it — the drain that empties you.
  `ZoneWant` sits at its far end. **Beat 2: want it.**
- `ZoneFear` is 300 tall and wraps the approach to `LedgeTop` and the door, so
  the last climb is made from inside a zone that is filling you towards death.
  **Beat 3: fear it.**

- [ ] **Step 2: Verify it is discovered and completable**

```bash
godot --path . --headless tests/smoke_test.tscn > /tmp/smoke.log 2>&1; echo "exit=$?"; cat /tmp/smoke.log
```

Expected: `All checks passed.` — including `every level scene in the folder is
discovered`, which counts the folder rather than a hard-coded number and will
now expect 13.

- [ ] **Step 3: Look at it, in the real renderer**

```bash
godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/updraft level_13_the_updraft
```

Then read the PNG in `/tmp/updraft/`. Every visual in this game is `_draw()`
primitives, so this *is* the shipping render — judge it here, not from a mockup.

Check specifically:
- The zones read as **places**, not as objects to collect. If a zone competes
  with the gold door for attention, drop `FIELD_ALPHA` or `EDGE_ALPHA` in
  `inversion_zone.gd`.
- No zone is sunk into or floating above a platform.
- The motes read as rising.

- [ ] **Step 4: Play it and tune the beats**

```bash
godot --path . --windowed --resolution 1280x720
```

Pick "The Updraft" from the menu. The three beats must land in order: beat 1
survivable while ignoring the zone entirely, beat 2 arriving near-empty so the
zone is a relief, beat 3 forcing a departure before the gauge fills. Adjust
platform spans and zone sizes until they do — **the coordinates above are a
starting point, not a result.** Re-run Step 3 after any change.

- [ ] **Step 5: Commit**

```bash
git add scenes/levels/level_13_the_updraft.tscn scripts/entities/inversion_zone.gd
git commit -m "feat(hourglass-hero): add level 13, The Updraft

Teaches the zone in three beats, deliberately in this order: see it, want
it, fear it. A player who learns a zone is lethal before learning it is
useful will simply avoid every zone in the game."
```

---

## Task 6: Prove it in the real game

**Files:**
- Modify: `tests/smoke_test.gd`

Task 2 tested the arithmetic against a stub. This tests the thing that stub
stood in for: a real `Area2D` really overlapping the real player.

- [ ] **Step 1: Write the failing test**

In `tests/smoke_test.gd`, add this function at the end of the file, after
`_finish()`:

```gdscript
## The zone, in the real game: a real Area2D overlapping the real player.
## `sand_test` can only reach the arithmetic — this is what proves containment,
## the plane rule, and that a full glass actually kills.
func _check_inversion_zone() -> void:
	var index := Game.level_names.find("The Updraft")
	if index < 0:
		_check("level 'The Updraft' exists", false, "not in %s" % [Game.level_names])
		return
	Game.start_level(index)
	await _load_level_scene()
	await _frames(5)

	var zones := get_tree().get_nodes_in_group(Game.INVERSION_GROUP)
	_check("the level's zones join the inversion group", zones.size() >= 3,
		"found %d" % zones.size())
	if zones.is_empty():
		return

	var player := _find_player()
	if player == null:
		_check("player is instantiated on The Updraft", false)
		return

	# Drop the player into a zone and let the clock run.
	var zone: InversionZone = zones[0]
	Game.sand = Tuning.cfg.sand_max / 2.0
	player.global_position = zone.global_position + zone.size / 2.0
	player.velocity = Vector2.ZERO
	await _frames(20)
	_check("standing in a zone reverses the flow", Game.sand_flow < 0.0)
	_check("sand climbs inside a zone", Game.sand > Tuning.cfg.sand_max / 2.0,
		"%.0f → %.0f" % [Tuning.cfg.sand_max / 2.0, Game.sand])

	# A full glass in a zone is death, exactly as an empty one is outside.
	Game.sand = Tuning.cfg.sand_max - 50.0
	var died := false
	for i in 120:
		await get_tree().physics_frame
		player.global_position = zone.global_position + zone.size / 2.0
		if Game.status == Game.Status.DEAD:
			died = true
			break
	_check("a FULL glass kills inside a zone", died, "sand=%.0f" % Game.sand)

	# A zone in the other plane must do nothing at all.
	Game.restart()
	await _frames(5)
	player = _find_player()
	zone = get_tree().get_nodes_in_group(Game.INVERSION_GROUP)[0] as InversionZone
	zone.plane = Planes.opposite(Game.plane)
	zone._on_plane_changed(Game.plane)
	await _frames(2)
	player.global_position = zone.global_position + zone.size / 2.0
	await _frames(10)
	_check("a zone in the other plane leaves the flow alone", Game.sand_flow > 0.0)

	# And stepping out of one resumes the drain.
	zone.plane = Planes.Kind.BOTH
	zone._on_plane_changed(Game.plane)
	await _frames(2)
	player.global_position = zone.global_position - Vector2(0.0, zone.size.y + 200.0)
	await _frames(10)
	var before := Game.sand
	await _frames(20)
	_check("leaving a zone resumes the drain", Game.sand < before,
		"%.0f → %.0f" % [before, Game.sand])
```

- [ ] **Step 2: Call it**

In `tests/smoke_test.gd`, find the call to `_check_camera_holds_a_launch()` in
`_ready()` and add the new call on the line immediately after it, before
`_finish()`:

```gdscript
	await _check_inversion_zone()
```

- [ ] **Step 3: Run it**

```bash
godot --path . --headless tests/smoke_test.tscn > /tmp/smoke.log 2>&1; echo "exit=$?"; cat /tmp/smoke.log
```

Expected: `All checks passed.`, exit 0, with seven new `ok` lines.

- [ ] **Step 4: Prove the test can fail**

A test that cannot fail proves nothing. Temporarily break the feature and
confirm the new checks go red:

```bash
git stash push scripts/autoload/game.gd
godot --path . --headless tests/smoke_test.tscn > /tmp/broken.log 2>&1; echo "exit=$?"; grep FAIL /tmp/broken.log
git stash pop
```

Expected: several `FAIL` lines from `_check_inversion_zone`, non-zero exit.
Then, after the pop, re-run and confirm green again:

```bash
godot --path . --headless tests/smoke_test.tscn > /tmp/smoke.log 2>&1; echo "exit=$?"; tail -3 /tmp/smoke.log
```

Expected: `All checks passed.`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/smoke_test.gd
git commit -m "test(hourglass-hero): prove the inversion zone in the real game"
```

---

## Task 7: Final pass

- [ ] **Step 1: Both suites, clean run**

```bash
godot --path . --headless tests/sand_test.tscn > /tmp/sand.log 2>&1; echo "sand exit=$?"
godot --path . --headless tests/smoke_test.tscn > /tmp/smoke.log 2>&1; echo "smoke exit=$?"
tail -3 /tmp/sand.log /tmp/smoke.log
```

Expected: both exit 0.

**Known pre-existing noise, not caused by this work:** the run may print
`1 resources still in use at exit` / `2 ObjectDB instances leaked`. This was
confirmed on commit `17f19fa`, before any of this branch's changes, and comes
from audio streams cached in the `Audio` autoload. Do not chase it here; do not
claim it as fixed.

- [ ] **Step 2: Screenshot every level**

```bash
godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/all
```

Read the PNGs. Levels 1–12 must be unchanged — `down()` and the trickle are
shared by every glass in the game, so a regression there shows up everywhere at
once. Compare the HUD gauge and the player sprite against what you expect from
an unmodified build if anything looks off.

- [ ] **Step 3: Sync with main before pushing**

Another collaborator pushes to this repo, and `git push` has been rejected as
non-fast-forward twice during earlier work. Fetch first, rebase, then **re-run
both suites after the rebase** — not before.

```bash
git fetch origin && git rebase origin/main
godot --path . --headless tests/sand_test.tscn && godot --path . --headless tests/smoke_test.tscn
```

Expected: both `All checks passed.` Only then is the branch ready.

- [ ] **Step 4: Stop and report**

Do **not** push. Summarise for the user: what landed, what the screenshots
showed, and anything in Task 5 Step 4 that had to be tuned away from the
coordinates in this plan. Pushing is a separate, explicitly requested step.
