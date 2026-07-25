# Multi-chamber glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the two-bulb hourglass into an N-lobed glass that rotates a `TAU/N`
step per jump, and ship two levels built on it — one with three chambers, one
with four.

**Architecture:** A new `ChamberLayout` derives everything about a glass from its
chamber count and nothing else: where each chamber sits, whether it drains,
receives or is sealed, and who pours into whom. `HourglassShape` reads it for
polygons, `Game` reads it for the sand economy. `Game.sand` stops being state and
becomes the sum of the draining chambers, so the HUD, the light, the tremble and
`danger()` need no change. At two chambers every formula reproduces what ships
today, arithmetically rather than by a special case, which is what protects the
twelve existing levels.

**Tech Stack:** Godot 4.7.1, GDScript, GL Compatibility renderer. Everything is
drawn at runtime with `_draw()` primitives — there is not one texture in the repo.

**Spec:** `docs/superpowers/specs/2026-07-25-multi-chamber-glass-design.md`

---

## Before you start

Read these once; every task assumes them.

- **Run from the project directory.** Every command below assumes
  `cd /Users/justinchapon/GMTK-Game-Jam-2026/.claude/worktrees/multi-chamber-glass/hourglass_hero_godot`.
  The shell's working directory sometimes resets between calls — prefix the `cd`
  rather than trusting it to persist.
- **Never write GDScript through a bash heredoc.** Heredocs strip tab
  indentation and GDScript is indentation-sensitive; you get a parse error every
  time. Use the Write/Edit tools, or `python3` with explicit `\t`.
- **`.godot/` is gitignored.** After adding any `class_name`, regenerate the
  class cache before the tests can see it:
  `godot --path . --headless --editor --quit`
- **The two suites are the gate.** After every task:
  - `godot --path . --headless tests/sand_test.tscn`
  - `godot --path . --headless tests/smoke_test.tscn`
  Both print `All checks passed.` and exit 0. If either goes red, stop and fix
  before committing.
- **Type annotations are not optional.** `var x := scene.instantiate()` fails to
  parse with "Cannot infer the type"; write `var x: PlaneArea = ...`.
- **A subclass cannot redeclare a parent `const` or `@export var`.** Per-entity
  defaults go in `_init()`.

`godot` is at `/opt/homebrew/bin/godot`.

---

## File Structure

**Created**

| File | Responsibility |
|------|----------------|
| `scripts/chamber_layout.gd` | Everything derivable from the chamber count: a slot's axis, its role, and who it pours into. Pure maths, no state, no drawing. |
| `tests/chamber_layout_test.gd` + `.tscn` | The layout theorems — the role table, the pour map, the two permutation lessons. |
| `scenes/levels/level_13_trefoil.tscn` | Three chambers. Teaches that one consistent direction collects both halves. |
| `scenes/levels/level_14_quarters.tscn` | Four chambers. Teaches that the refill is two rotations away. |

**Modified**

| File | Change |
|------|--------|
| `scripts/planes.gd` | Two planes become four, plus `step()` in place of `opposite()`. |
| `scripts/hourglass_shape.gd` | The two hard-coded bulbs become a loop over the layout. |
| `scripts/hourglass_motion.gd` | Turns `TAU/N` instead of `PI`; hands back a fill per slot. |
| `scripts/autoload/game.gd` | `sand` becomes derived; the chambers become the state. |
| `scripts/entities/palette.gd` | Four plane hues and four room ramps. |
| `scripts/level.gd` | Gains `chambers`. |
| `scripts/main.gd` | Reads it, and stops writing `Game.sand` directly. |
| `scripts/entities/player.gd` | Passes the held input, not `velocity.x`. |
| `scripts/entities/monster.gd` | `Planes.Kind.FRONT` → `P0`. |
| `scripts/entities/platform.gd` | Same rename. |
| `scripts/ui/hud.gd` | A plane label that works past two. |
| `scenes/**/*.tscn` | 32 nodes: `plane = 2` → `plane = 4`. |
| `tests/sand_test.gd`, `tests/smoke_test.gd` | The new invariants. |

---

## Task 1: The chamber layout

Everything the rest of the plan builds on. Pure functions of the chamber count —
no drawing, no state, no `Game`.

**Files:**
- Create: `scripts/chamber_layout.gd`
- Create: `tests/chamber_layout_test.gd`, `tests/chamber_layout_test.tscn`

- [ ] **Step 1: Write the failing test**

Create `tests/chamber_layout_test.gd`:

```gdscript
## Chamber layout test: the glass's geometry and its consequences, with nothing
## rendered and no game running.
##
##   godot --headless tests/chamber_layout_test.tscn
##
## Everything here is a claim the design makes in prose. If one of them stops
## holding, a level stops teaching what it was built to teach.
extends Node

var _failures := 0


func _ready() -> void:
	_roles()
	_pour_map()
	_trefoil_lesson()
	_quarters_lesson()
	_finish()


## §1 of the spec: which chambers drain, which receive, which are sealed.
func _roles() -> void:
	var expected := {
		2: [ChamberLayout.Role.UPPER, ChamberLayout.Role.LOWER],
		3: [ChamberLayout.Role.UPPER, ChamberLayout.Role.LOWER, ChamberLayout.Role.LOWER],
		4: [ChamberLayout.Role.UPPER, ChamberLayout.Role.LEVEL,
			ChamberLayout.Role.LOWER, ChamberLayout.Role.LEVEL],
	}
	for count in expected:
		var got: Array[int] = []
		for i in count:
			got.append(ChamberLayout.role(count, i))
		_check("N=%d: the roles come out of the angles" % count, got == expected[count],
			"got %s, wanted %s" % [got, expected[count]])

	_check("N=4: exactly two chambers are sealed",
		ChamberLayout.lowers(4).size() == 1 and ChamberLayout.uppers(4).size() == 1)
	_check("every glass has exactly one chamber that drains",
		ChamberLayout.uppers(2).size() == 1 and ChamberLayout.uppers(3).size() == 1
			and ChamberLayout.uppers(4).size() == 1)


## The "opposite chambers only" rule and the "half and half" rule are the same
## rule seen at two chamber counts. Neither is written down anywhere.
func _pour_map() -> void:
	_check("N=2: the top pours straight into the bottom",
		ChamberLayout.targets(2, 0) == [1] as Array[int])
	_check("N=4: the top pours into the bottom and into neither side",
		ChamberLayout.targets(4, 0) == [2] as Array[int])
	var three := ChamberLayout.targets(3, 0)
	three.sort()
	_check("N=3: the top splits half and half", three == [1, 2] as Array[int],
		"got %s" % [three])


## The three-chamber lesson: turning the same way visits every chamber; going
## back and forth starves one of them for good.
func _trefoil_lesson() -> void:
	var visited := {}
	var slot := 0
	for turn in 3:
		slot = posmod(slot + 1, 3)
		visited[slot] = true
	_check("N=3: three turns the same way visit all three chambers",
		visited.size() == 3)

	visited = {}
	slot = 0
	for turn in 6:
		slot = posmod(slot + (1 if turn % 2 == 0 else -1), 3)
		visited[slot] = true
	_check("N=3: alternating never reaches the third chamber", visited.size() == 2,
		"reached %d chambers" % visited.size())


## The four-chamber lesson: the sand you drained is whole, but it has to travel
## through a sealed side chamber, so it is two turns away — and turning back
## undoes exactly the turn before it.
func _quarters_lesson() -> void:
	var bottom := ChamberLayout.lowers(4)[0]
	var after_one := posmod(bottom + 1, 4)
	var after_two := posmod(bottom + 2, 4)
	_check("N=4: one turn parks the drained sand in a sealed chamber",
		ChamberLayout.role(4, after_one) == ChamberLayout.Role.LEVEL)
	_check("N=4: two turns the same way bring it back to the top",
		ChamberLayout.role(4, after_two) == ChamberLayout.Role.UPPER)

	var slot := 1
	slot = posmod(slot + 1, 4)
	slot = posmod(slot - 1, 4)
	_check("N=4: turning back undoes the turn exactly", slot == 1)


func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s%s" % [label, "  (%s)" % detail if detail else ""])


func _finish() -> void:
	print("")
	print("All checks passed." if _failures == 0 else "%d check(s) FAILED." % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
```

Create `tests/chamber_layout_test.tscn` (write it with the Write tool, not a
heredoc):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/chamber_layout_test.gd" id="1_test"]

[node name="ChamberLayoutTest" type="Node"]
script = ExtResource("1_test")
```

- [ ] **Step 2: Run it to verify it fails**

```bash
/opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

Expected: a parse error — `Identifier "ChamberLayout" not declared in the
current scope`.

- [ ] **Step 3: Write the layout**

Create `scripts/chamber_layout.gd`:

```gdscript
## What a glass with N chambers is, before anything is drawn or any sand moves.
##
## Every rule the multi-chamber glass has is a consequence of one sentence:
## chamber `i` points at angle `i * TAU / N`, measured clockwise from straight
## up. Which chambers drain, which receive, which are sealed shut, and who pours
## into whom all fall out of that — there is no table anywhere to keep in sync
## with the picture, which is the only reason four chambers cost about as much
## as two.
##
## Two chambers is not a special case here. It is this formula at N=2, and it
## lands on exactly the hourglass that shipped.
class_name ChamberLayout
extends RefCounted

## What a chamber does with sand, decided by where it points.
enum Role {
	UPPER, ## Points above the neck. It drains.
	LOWER, ## Points below it. It receives.
	LEVEL, ## Points along the horizon. Sealed: it neither drains nor receives.
}

## How far off the horizon a chamber's axis has to point before it counts as
## draining. Small, and only ever tripped by floating-point noise — the axes are
## exact multiples of a turn, so a side chamber's `y` is 0 to within an epsilon,
## never to within a design choice.
const HORIZON := 0.001


## Which way chamber `index` points, in the glass's own frame. Slot 0 is
## straight up and the rest follow clockwise on screen, where `y` grows downward.
static func axis(count: int, index: int) -> Vector2:
	return Vector2.UP.rotated(TAU * index / float(count))


static func role(count: int, index: int) -> Role:
	var y := axis(count, index).y
	if y < -HORIZON:
		return Role.UPPER
	if y > HORIZON:
		return Role.LOWER
	return Role.LEVEL


static func uppers(count: int) -> Array[int]:
	return _with_role(count, Role.UPPER)


static func lowers(count: int) -> Array[int]:
	return _with_role(count, Role.LOWER)


## Where chamber `index` sends its sand: the receiving chambers nearest to
## straight down as it sees it. A tie splits the fall evenly, and that tie is the
## whole of the three-chamber glass — there is no chamber opposite the top one,
## so the sand goes half into each of the two below.
##
## Empty for a chamber that does not drain.
static func targets(count: int, index: int) -> Array[int]:
	if role(count, index) != Role.UPPER:
		return []
	var falling := -axis(count, index)
	var best := INF
	var out: Array[int] = []
	for i in lowers(count):
		var angle := absf(falling.angle_to(axis(count, i)))
		if angle < best - HORIZON:
			best = angle
			out = [i]
		elif angle < best + HORIZON:
			out.append(i)
	return out


static func _with_role(count: int, wanted: Role) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		if role(count, i) == wanted:
			out.append(i)
	return out
```

- [ ] **Step 4: Regenerate the class cache and run the test**

```bash
/opt/homebrew/bin/godot --path . --headless --editor --quit
```

```bash
/opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

Expected: every line `ok`, then `All checks passed.`, exit 0.

- [ ] **Step 5: Run the existing suites — nothing has been touched yet**

```bash
/opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn
```

Expected: both print `All checks passed.`

- [ ] **Step 6: Commit**

```bash
git add scripts/chamber_layout.gd scripts/chamber_layout.gd.uid tests/chamber_layout_test.gd tests/chamber_layout_test.gd.uid tests/chamber_layout_test.tscn && git commit -m "feat(hourglass-hero): the chamber layout, derived from one angle"
```

---

## Task 2: Chamber polygons

`HourglassShape` learns to build any chamber. Nothing draws differently yet —
this task only has to prove that at two chambers the new formula lands on the
polygons that ship today, because that is what protects the twelve levels.

**Files:**
- Modify: `scripts/hourglass_shape.gd`
- Modify: `tests/sand_test.gd`

- [ ] **Step 1: Write the failing test**

Add to `tests/sand_test.gd`, immediately before the `_finish()` call at the end
of `_ready()`:

```gdscript
	# --- The two-bulb glass is the N-chamber formula at N=2 --------------------
	# Not "close enough": the twelve shipped levels must not move by a pixel, and
	# the cheapest way to know that is to hold the new polygons against the ones
	# written out by hand above.
	var drift_upper := _polygon_drift(HourglassShape.chamber(Vector2(48.0, 72.0), 2, 0), upper)
	_check("chamber 0 of a two-chamber glass IS the upper bulb", drift_upper < 0.0001,
		"corners move %.6f px" % drift_upper)
	var drift_lower := _polygon_drift(HourglassShape.chamber(Vector2(48.0, 72.0), 2, 1), lower)
	_check("chamber 1 of a two-chamber glass IS the lower bulb", drift_lower < 0.0001,
		"corners move %.6f px" % drift_lower)

	# Every chamber holds the same, whatever the count — the sand economy hands
	# each one the same amount at rest and expects it to read the same depth.
	for count in [2, 3, 4]:
		var areas: Array[float] = []
		for i in count:
			areas.append(HourglassShape._area(
				HourglassShape.chamber(Vector2(48.0, 72.0), count, i)))
		var spread: float = areas.max() - areas.min()
		_check("N=%d: every chamber has the same capacity" % count,
			spread / areas.max() < 0.001, "areas %s" % [areas])

	# Convex, because `_clip`, `_level` and `_pour` are built on it: cutting a
	# convex polygon with a half-plane leaves exactly one convex piece.
	for count in [2, 3, 4]:
		var convex := true
		for i in count:
			convex = convex and _is_convex(HourglassShape.chamber(Vector2(48.0, 72.0), count, i))
		_check("N=%d: every chamber is convex" % count, convex)
```

And add these two helpers at the bottom of `tests/sand_test.gd`, just above
`_check`:

```gdscript
## The furthest any corner of `got` sits from the nearest corner of `wanted`.
## Compares the shapes rather than the vertex lists: the same quadrilateral
## written starting from another corner, or wound the other way, is the same
## quadrilateral, and nothing downstream can tell the difference.
func _polygon_drift(got: PackedVector2Array, wanted: PackedVector2Array) -> float:
	if got.size() != wanted.size():
		return INF
	var worst := 0.0
	for p in got:
		var nearest := INF
		for q in wanted:
			nearest = minf(nearest, p.distance_to(q))
		worst = maxf(worst, nearest)
	return worst


## Does the polygon turn the same way at every corner?
func _is_convex(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	var sign_seen := 0.0
	for i in n:
		var a := poly[(i + 1) % n] - poly[i]
		var b := poly[(i + 2) % n] - poly[(i + 1) % n]
		var cross := a.cross(b)
		if absf(cross) < 0.0001:
			continue
		if sign_seen != 0.0 and signf(cross) != sign_seen:
			return false
		sign_seen = signf(cross)
	return true
```

The `upper` and `lower` locals the first check compares against are already
built at the top of `_ready()` from `hw := 24.0` / `hh := 36.0`, which is the
`Vector2(48.0, 72.0)` passed here.

- [ ] **Step 2: Run it to verify it fails**

```bash
/opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn
```

Expected: a parse error — `Invalid call. Nonexistent function 'chamber' in base
'GDScript'`.

- [ ] **Step 3: Add the polygons**

In `scripts/hourglass_shape.gd`, insert these three functions immediately after
the `LEVEL_STEPS` const and before `draw_glass`:

```gdscript
## How far a chamber reaches from the neck, and how wide it is at the far end,
## both in px, for a glass of `size`.
##
## At two chambers the glass keeps the width and height it was authored with —
## which is what makes the twelve two-plane levels pixel-identical, and it costs
## one branch. Above two it is a rosette, so it takes one radius in every
## direction: an ellipse of chambers would give the side lobes a different area
## from the top one, and the sand economy assumes every chamber holds the same.
##
## `sin(PI / count)` is the widest a chamber can be without touching its
## neighbour — they touch at `tan`, and sin is the same number pulled safely
## short of it.
static func _span(size: Vector2, count: int) -> Vector2:
	if count == 2:
		return Vector2(size.y / 2.0, size.x / 2.0)
	var radius := (size.x + size.y) / 4.0
	return Vector2(radius, radius * sin(PI / float(count)))


## Chamber `index` as a convex polygon in the glass's own frame: a trapezoid
## with its narrow end at the neck and its wide end out at the rim. Corners run
## far-side, far-other-side, neck-other-side, neck-side, which is the order
## `shell` walks to join the chambers into one ring.
static func chamber(size: Vector2, count: int, index: int) -> PackedVector2Array:
	var span := _span(size, count)
	var axis := ChamberLayout.axis(count, index)
	var side := Vector2(-axis.y, axis.x)
	var wide := span.y
	var narrow := wide * NECK_RATIO
	var throat := span.x * THROAT_RATIO
	return PackedVector2Array([
		axis * span.x - side * wide,
		axis * span.x + side * wide,
		axis * throat + side * narrow,
		axis * throat - side * narrow,
	])


## The whole glass as ONE ring: every chamber walked in turn and joined through
## the neck. Drawing it in a single piece is what puts walls on the throat and
## leaves no seam across it — outlining each chamber separately would rule a
## line through the middle of the glass.
static func shell(size: Vector2, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in count:
		var poly := chamber(size, count, i)
		out.append(poly[3])
		out.append(poly[0])
		out.append(poly[1])
		out.append(poly[2])
	return out
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
/opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn
```

Expected: the new checks all `ok`, `All checks passed.`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/hourglass_shape.gd tests/sand_test.gd && git commit -m "feat(hourglass-hero): a chamber is a trapezoid at i * TAU / N"
```

---

## Task 3: Draw the glass as a loop

`draw_glass` stops naming two bulbs and walks the chambers instead. The signature
changes: a `PackedFloat32Array` of fills, one per chamber, whose **size is the
chamber count**. `HourglassMotion` changes with it, still reading `Game.sand`, so
the picture is byte-identical at two chambers.

**Files:**
- Modify: `scripts/hourglass_shape.gd:37-89`
- Modify: `scripts/hourglass_motion.gd:83-95`

- [ ] **Step 1: Replace `draw_glass`**

In `scripts/hourglass_shape.gd`, replace the whole of `draw_glass` (the
docstring above it through the two `draw_line` lip calls) with:

```gdscript
## `size` is the full width and height of the glass. `fills` is how full each
## chamber is, 0 to 1, indexed by the slot it is drawn in — and its SIZE is the
## number of chambers, so one array says both how many and how much. `down` is
## gravity in the glass's own frame; pass `Vector2.DOWN` for a glass at rest.
## `phase` animates the trickle's wobble.
static func draw_glass(canvas: CanvasItem, size: Vector2, fills: PackedFloat32Array,
		sand: Color, down: Vector2, phase: float, line_width := 1.5) -> void:
	var count := fills.size()
	if count < 2:
		return

	# The glass itself, in one piece.
	var ring := shell(size, count)
	canvas.draw_colored_polygon(ring, Color(Palette.GLASS, 0.10))

	# The sand. Every chamber is the same trapezoid turned, so one area serves
	# for all of them — and that same symmetry is why a completed turn is
	# seamless.
	var capacity := _area(chamber(size, count, 0))
	for i in count:
		_pour(canvas, chamber(size, count, i), down, fills[i] * capacity, sand)

	_trickle(canvas, size, count, fills, sand, down, phase, line_width)

	# Frame: the outline, then a plate capping each chamber.
	_outline(canvas, ring, line_width)
	for i in count:
		var poly := chamber(size, count, i)
		var overhang := (poly[1] - poly[0]).normalized() * (line_width * 1.35)
		canvas.draw_line(poly[0] - overhang, poly[1] + overhang, Palette.GLASS,
			line_width * 1.35, true)


## The sand in the air: one thread from each draining chamber to each chamber it
## pours into. At two chambers that is the single fall down the middle; at three
## it is the pair that splits half and half, and nothing here had to be told the
## difference.
##
## The fall dries up as the glass tips, spent by the angle of a chamber's own
## wall — which is exactly the tilt at which falling sand would start missing the
## chamber below, so a trickle can never be drawn outside the glass.
static func _trickle(canvas: CanvasItem, size: Vector2, count: int,
		fills: PackedFloat32Array, sand: Color, down: Vector2, phase: float,
		line_width: float) -> void:
	var span := _span(size, count)
	var wall := cos(atan2(span.y - span.y * NECK_RATIO, span.x - span.x * THROAT_RATIO))
	var pouring := clampf((down.y - wall) / (1.0 - wall), 0.0, 1.0)
	if pouring <= 0.01:
		return
	var sideways := Vector2(-down.y, down.x)
	var throat := span.x * THROAT_RATIO
	for i in count:
		if fills[i] <= 0.01 or ChamberLayout.targets(count, i).is_empty():
			continue
		# One thread per DRAINING chamber, not per target. Falling sand follows
		# gravity and nothing else, so a chamber pouring into two of them is one
		# fall that parts on the way down — drawing it once per target would rule
		# the same line twice and read as a thread twice as bright.
		#
		# Starts at the UNDERSIDE of the draining chamber, not at the centre of
		# the glass: the sand stops at the top of the throat, so a trickle
		# beginning at the origin leaves the height of the throat as a gap of
		# bare glass, and the fall reads as cut in two right where it should be
		# one thing.
		var head := sideways * sin(phase) * 0.6 - down * throat
		canvas.draw_line(head, head + down * (span.x * STREAM_REACH + throat),
			Color(sand, sand.a * pouring), line_width * 0.8, true)
```

Note what moved: `wall` used to be `cos(atan2(hw - nw, hh - nh))`. `span.y` is
the old `hw` and `span.x` the old `hh`, `span.y * NECK_RATIO` is `nw` and
`span.x * THROAT_RATIO` is `nh` — the same number at two chambers.

- [ ] **Step 2: Make the motion hand back an array**

In `scripts/hourglass_motion.gd`, replace `chambers()` (the docstring and the
function, lines 83-95) with:

```gdscript
## How full each chamber is, 0 to 1, indexed by the slot it is drawn in. The
## size of the array is the chamber count, so this one value tells the shape both
## how many chambers to draw and how much is in each.
func chambers() -> PackedFloat32Array:
	var frac := clampf(Game.sand / maxf(Tuning.cfg.sand_max, 1.0), 0.0, 1.0)
	if Game.flip_anim > 0.0:
		# Mid-tumble the neck gates the sand and each chamber keeps what it held.
		# `Game.sand` jumped to the post-flip figure the instant the jump began,
		# and a flip is exactly `max - sand`, so the pre-flip split is its mirror.
		# Holding it fixed is what makes the tumble land seamlessly: at a half
		# turn the two chambers have swapped places on screen, which is precisely
		# when the roles below take over.
		return PackedFloat32Array([1.0 - frac, frac])
	return PackedFloat32Array([frac, 1.0 - frac])
```

- [ ] **Step 3: Run both suites and the layout test**

```bash
/opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

Expected: all three print `All checks passed.`

- [ ] **Step 4: Shoot a screenshot and look at it**

The suites never look at a pixel; this is the only check that the glass still
draws right. It needs a real window — `--headless` returns a blank viewport.

```bash
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-task3 1 12
```

Read `/tmp/shots-task3/level_01.png` and `/tmp/shots-task3/level_12.png` with the
Read tool. The gauge in the top-left must be an hourglass with sand in it, the
player's glass the same shape. If either is empty, mis-shaped or has a line ruled
across its neck, stop — the polygons are wrong and nothing downstream will fix it.

- [ ] **Step 5: Commit**

```bash
git add scripts/hourglass_shape.gd scripts/hourglass_motion.gd && git commit -m "feat(hourglass-hero): draw the glass one chamber at a time"
```

---

## Task 4: Four planes

`Planes.Kind` goes from three entries to five, which moves `BOTH` from 2 to 4 and
so touches every level file. The rename and the migration land together because
either alone leaves the game broken.

**Files:**
- Modify: `scripts/planes.gd`
- Modify: `scripts/autoload/game.gd:33,127,178`
- Modify: `scripts/entities/monster.gd:24`
- Modify: `scripts/entities/platform.gd:80`
- Modify: `scripts/entities/palette.gd:61-62,87`
- Modify: `scripts/ui/hud.gd:52`
- Modify: `tests/smoke_test.gd:144,146,148`
- Modify: `scenes/**/*.tscn` (32 nodes)

- [ ] **Step 1: Rewrite `scripts/planes.gd`**

Replace the whole file with:

```gdscript
## The level's superimposed planes — one per chamber of its glass.
##
## Every entity belongs to one plane (or to all of them). The player moves to the
## next one on every jump, so a `P1` platform is only solid while the glass has
## chamber 1 on top. Two planes is the original game; three and four are the same
## rule with more places to be.
class_name Planes
extends RefCounted

enum Kind {
	P0, ## The plane a level opens in.
	P1,
	P2, ## Only reached on a three-chamber level or better.
	P3, ## Only reached on a four-chamber level.
	BOTH, ## Present in every plane (shared floor, walls).
}

## The most planes a level may use. `BOTH` is not one of them — it sits after the
## real planes precisely so that `int(kind) < COUNT` means "a real plane".
const COUNT := 4


## Is an entity in plane `kind` active while the player is in `current`?
static func is_active(kind: Kind, current: Kind) -> bool:
	return kind == Kind.BOTH or kind == current


## Where `kind` lands after `steps` turns of a glass with `count` chambers.
## Negative steps turn the other way. `BOTH` is everywhere, so it never moves.
static func step(kind: Kind, steps: int, count: int) -> Kind:
	if kind == Kind.BOTH or count <= 0:
		return kind
	return posmod(int(kind) + steps, count) as Kind
```

- [ ] **Step 2: Rename the old two names at every call site**

There are exactly nine, and every one is a straight substitution of
`Planes.Kind.FRONT` → `Planes.Kind.P0` and `Planes.Kind.BACK` → `Planes.Kind.P1`:

```bash
grep -rln "Planes.Kind.FRONT\|Planes.Kind.BACK" scripts/ tests/ | xargs sed -i '' -e 's/Planes\.Kind\.FRONT/Planes.Kind.P0/g' -e 's/Planes\.Kind\.BACK/Planes.Kind.P1/g'
```

Then verify nothing was missed:

```bash
grep -rn "Planes.Kind.FRONT\|Planes.Kind.BACK" scripts/ tests/ ; echo "exit=$?"
```

Expected: no output, `exit=1`.

- [ ] **Step 3: Point `jump_flip` at `step`**

In `scripts/autoload/game.gd:178`, replace:

```gdscript
	set_plane(Planes.opposite(plane))
```

with:

```gdscript
	set_plane(Planes.step(plane, int(flip_dir), 2))
```

The hard-coded 2 is temporary and Task 7 replaces it with the level's chamber
count. Move this line so it sits **after** the `flip_dir` assignment — `step`
reads it, and the old ordering set it last. The function's body becomes:

```gdscript
func jump_flip(travel_dir: float) -> void:
	sand = flip_sand()
	# Tumble rolls the way you travel — moving right spins clockwise, like a
	# wheel. Keep the last direction on a straight-up jump.
	if not is_zero_approx(travel_dir):
		flip_dir = signf(travel_dir)
	set_plane(Planes.step(plane, int(flip_dir), 2))
	flip_anim = Tuning.cfg.flip_duration
	flipped.emit(false)
```

- [ ] **Step 4: Fix the two-valued lookups that assumed a boolean**

`scripts/entities/palette.gd:60-62` — replace `solid`:

```gdscript
static func solid(plane: Planes.Kind, current: Planes.Kind) -> Color:
	var effective := current if plane == Planes.Kind.BOTH else plane
	return FRONT_SOLID if effective == Planes.Kind.P0 else BACK_SOLID
```

`scripts/entities/palette.gd:86-89` — replace `room`:

```gdscript
static func room(plane: Planes.Kind) -> Array[Color]:
	if plane == Planes.Kind.P1:
		return [BACK_SKY, BACK_FLOOR, BACK_FAR, BACK_NEAR]
	return [FRONT_SKY, FRONT_FLOOR, FRONT_FAR, FRONT_NEAR]
```

Both stay two-valued for now; Task 5 gives them four. This step only keeps them
compiling against the renamed enum.

`scripts/ui/hud.gd:52` becomes:

```gdscript
	var front := plane == Planes.Kind.P0
```

- [ ] **Step 5: Migrate the scenes**

`BOTH` moved from 2 to 4, so every node that stored it has to move with it. There
are 32.

```bash
grep -rlZ "plane = 2" scenes/ | xargs -0 sed -i '' 's/^plane = 2$/plane = 4/'
```

Verify the counts moved as expected — 21 `plane = 0`, 29 `plane = 1`, and the 32
that were 2 are now 4, with none left on 2:

```bash
grep -rho "plane = [0-9]" scenes/ | sort | uniq -c
```

Expected exactly:

```
  21 plane = 0
  29 plane = 1
  32 plane = 4
```

- [ ] **Step 6: Run everything**

```bash
/opt/homebrew/bin/godot --path . --headless --editor --quit && /opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

Expected: all three suites `All checks passed.`

- [ ] **Step 7: Screenshot both planes and compare against Task 3**

A wrong `plane` value in a scene shows up as a platform that is solid when it
should be a ghost — invisible to the suites, obvious in a picture.

```bash
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-task4 1 12
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-task4-flip flip 1 12
```

Read all four PNGs. `/tmp/shots-task4/level_01.png` must be indistinguishable
from `/tmp/shots-task3/level_01.png`. Any platform that changed from solid to
ghost or back is a scene the sed missed.

- [ ] **Step 8: Commit**

```bash
git add -A scripts scenes tests && git commit -m "feat(hourglass-hero): four planes, and BOTH moves out of their way"
```

---

## Task 5: Four hues, four rooms

**Files:**
- Modify: `scripts/entities/palette.gd`
- Modify: `scripts/fx/backdrop.gd:62`

- [ ] **Step 1: Rewrite the hue budget and the solids**

In `scripts/entities/palette.gd`, replace the docstring at the top (lines 1-19,
`## The game's colours.` through the MINT paragraph) with:

```gdscript
## The game's colours.
##
## Entities never hard-code a colour: they ask here, which keeps the planes
## readable at a glance.
##
## THE HUE BUDGET. Four families, and nothing may invent a fifth:
##
##   - The world takes a PLANE HUE, one of four sitting 90° apart. Backgrounds
##     and scenery are the same hue drained of saturation, so depth reads as
##     distance rather than as another object.
##   - Time is WARM. Sand, door and flip-pad share one gold family. That is what
##     makes the thing you are chasing pop out of the room, and it is spent on
##     nothing else.
##   - Danger is one saturated MAGENTA-RED, used by spikes, monsters and a
##     nearly-empty glass. It is the only colour allowed to be that loud.
##   - The spring is MINT: helpful furniture, not a reward.
##
## Four planes will not fit politely around the gold and the red — 90° apart,
## some plane always lands within 45° of one of them, and the fourth is a
## terracotta sitting 25° off the danger red. The ORDER is what contains that: a
## three-chamber level only ever reaches P2, so the terracotta is never on screen
## unless the level has four chambers, and there it separates from the red by
## register rather than by hue. Solids are large, matte and unlit; spikes and
## monsters are small, saturated, and carry a light.
```

- [ ] **Step 2: Replace the solid constants with a table**

Replace lines 25-26 (`const FRONT_SOLID` and `const BACK_SOLID`) with:

```gdscript
## One hue per plane, in the order a level reaches them.
const PLANE_SOLIDS: Array[Color] = [
	Color("4cc9f0"), ## P0 — cyan, the game's identity, unchanged.
	Color("b57bff"), ## P1 — violet.
	Color("7fe04c"), ## P2 — lime.
	Color("f0764c"), ## P3 — terracotta.
]
```

- [ ] **Step 3: Replace the room constants with a table**

Replace lines 42-55 (the `# ----- The room` banner through `const BACK_NEAR`)
with:

```gdscript
# ----- The room --------------------------------------------------------------

## Four depths per plane, far to near: sky, floor, far wall, near wall. Each is
## the plane's own hue with the life drained out of it, so the room recolours
## itself when you turn the glass without ever competing with a solid.
##
## P0 and P1 are the ramps that shipped, kept to the byte — they are what the
## twelve two-plane levels look like. P2 and P3 were built to match them: the
## plane's hue at the same saturation and the same four values.
const PLANE_ROOMS: Array[PackedColorArray] = [
	PackedColorArray([Color("102941"), Color("050c15"), Color("14304a"), Color("1b3e5c")]),
	PackedColorArray([Color("201540"), Color("0a0614"), Color("281b4d"), Color("362566")]),
	PackedColorArray([Color("184111"), Color("081505"), Color("1b4a13"), Color("225c18")]),
	PackedColorArray([Color("412711"), Color("150c05"), Color("4a2c13"), Color("5c3718")]),
]
```

- [ ] **Step 4: Point the two lookups at the tables**

Replace `solid` (the version left by Task 4) with:

```gdscript
## A solid's colour for its plane. A "BOTH" solid takes the hue of whichever
## plane the player is in, so you can always read where you are.
static func solid(plane: Planes.Kind, current: Planes.Kind) -> Color:
	var effective := current if plane == Planes.Kind.BOTH else plane
	return PLANE_SOLIDS[clampi(int(effective), 0, PLANE_SOLIDS.size() - 1)]
```

Replace `room` with:

```gdscript
## The four room depths for a plane, far to near: sky, floor, far wall, near
## wall. Returned together because every caller wants the whole set, and
## splitting them into four functions invites one being left on the old plane.
static func room(plane: Planes.Kind) -> Array[Color]:
	var ramp := PLANE_ROOMS[clampi(int(plane), 0, PLANE_ROOMS.size() - 1)]
	return [ramp[0], ramp[1], ramp[2], ramp[3]]
```

- [ ] **Step 5: Fix the one caller of the deleted constants**

`scripts/fx/backdrop.gd:62` reads `Palette.FRONT_SKY` and `Palette.FRONT_FLOOR`,
which no longer exist. Replace that line with:

```gdscript
	var opening := Palette.room(Planes.Kind.P0)
	_gradient.colors = PackedColorArray([opening[0], opening[1]])
```

Check nothing else referenced them:

```bash
grep -rn "FRONT_SOLID\|BACK_SOLID\|FRONT_SKY\|FRONT_FLOOR\|FRONT_FAR\|FRONT_NEAR\|BACK_SKY\|BACK_FLOOR\|BACK_FAR\|BACK_NEAR" scripts/ tests/
```

Expected: only `scripts/ui/hud.gd:54`, which reads
`Palette.FRONT_SOLID if front else Palette.BACK_SOLID`. Replace that whole
`_on_plane_changed` body with:

```gdscript
func _on_plane_changed(plane: Planes.Kind) -> void:
	var front := plane == Planes.Kind.P0
	_plane_label.text = "FRONT" if front else "BACK"
	_plane_label.modulate = Palette.solid(plane, plane)
```

Task 9 gives the label its four-plane form; this step only unhooks it from the
deleted constants.

Re-run the grep. Expected: no output.

- [ ] **Step 6: Run everything, then look**

```bash
/opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

```bash
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-task5 1 12
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-task5-flip flip 1 12
```

Read the four PNGs against Task 4's. The cyan and violet rooms are meant to be
identical to the byte — if either shifted, the ramp was transcribed wrong.

- [ ] **Step 7: Commit**

```bash
git add scripts/entities/palette.gd scripts/fx/backdrop.gd scripts/ui/hud.gd && git commit -m "feat(hourglass-hero): a hue and a room for each of the four planes"
```

---

## Task 6: The sand becomes a reservoir

The heart of it. `Game.sand` stops being state and becomes the sum of the
draining chambers; the chambers become the state. At two chambers every formula
below reduces to the one that ships.

**Files:**
- Modify: `scripts/autoload/game.gd`
- Modify: `scripts/main.gd:97-100`
- Modify: `tests/sand_test.gd`

- [ ] **Step 1: Write the failing test**

In `tests/sand_test.gd`, replace the block that currently reads
`# --- Flipping is an involution ---` through the line
`_check("flipping on full gives back nothing", Game.flip_sand() < 0.0001)` with:

```gdscript
	# --- The reservoir --------------------------------------------------------
	var cfg := Tuning.cfg

	# Capacity scales with the chamber count: `sand_max` is ONE chamber's
	# capacity, which is already what it means today — all 6000 of the sand fits
	# into a single bulb, which is why the old flip could clamp to it.
	for count in [2, 3, 4]:
		Game.arm_glass(count, cfg.sand_start)
		_check("N=%d: the glass holds sand_max * N / 2" % count,
			absf(_total(Game.chambers) - cfg.sand_max * count / 2.0) < 0.0001,
			"holds %.0f, wanted %.0f" % [_total(Game.chambers), cfg.sand_max * count / 2.0])

		# Pacing is uniform: the top always opens at `sand_start` against the same
		# drain, so every glass gives the same runway before the first turn is
		# compulsory. More chambers makes the game wider, never faster.
		var even := true
		for v in Game.chambers:
			even = even and absf(v - cfg.sand_start) < 0.0001
		_check("N=%d: every chamber opens at sand_start" % count, even,
			"opened %s" % [Game.chambers])

	# Nothing is destroyed, only stranded. Drain and turn as much as you like and
	# the glass still holds what it started with.
	for count in [2, 3, 4]:
		Game.arm_glass(count, cfg.sand_start)
		var before := _total(Game.chambers)
		for i in 20:
			Game.drain(cfg.sand_drain_rate * 0.05)
			Game.rotate_glass(1 if i % 3 == 0 else -1)
		_check("N=%d: sand is conserved across drains and turns" % count,
			absf(_total(Game.chambers) - before) < 0.01,
			"%.4f → %.4f" % [before, _total(Game.chambers)])

	# --- Two chambers reproduce the shipped flip, exactly ---------------------
	# `sand_flip_base` is 0, so a turn is `max - sand` and two turns must land on
	# the number you started from — bit for bit, not roughly.
	#
	# This is the single most load-bearing fact in the game. The double jump is
	# two turns, so it is sand-neutral by arithmetic rather than by tuning: free
	# while you are full, ruinous while you are empty. Give `sand_flip_base` a
	# non-zero value and the identity breaks, the air jump silently becomes a
	# refuel or a leak, and "Double or Nothing" stops teaching what it teaches.
	var worst_drift := 0.0
	var worst_from := 0.0
	var worst_flip := 0.0
	for step in 41:
		var start: float = cfg.sand_max * step / 40.0 # includes both 0 and max
		Game.arm_glass(2, start)
		# One turn must give back exactly what the old `max - sand` gave back.
		Game.rotate_glass(1)
		worst_flip = maxf(worst_flip,
			absf(Game.sand - clampf(cfg.sand_max - start + cfg.sand_flip_base, 0.0, cfg.sand_max)))
		Game.rotate_glass(1)
		if absf(Game.sand - start) > worst_drift:
			worst_drift = absf(Game.sand - start)
			worst_from = start
	_check("N=2: one turn is the shipped flip_sand(), to the bit", worst_flip < 0.0001,
		"off by %.6f" % worst_flip)
	_check("N=2: turning twice returns the sand exactly", worst_drift < 0.0001,
		"off by %.6f starting from %.0f — check sand_flip_base" % [worst_drift, worst_from])

	Game.arm_glass(2, 0.0)
	Game.rotate_glass(1)
	_check("N=2: turning on empty gives back a full glass",
		absf(Game.sand - cfg.sand_max) < 0.0001, "got %.4f" % Game.sand)
	Game.arm_glass(2, cfg.sand_max)
	Game.rotate_glass(1)
	_check("N=2: turning on full gives back nothing", Game.sand < 0.0001,
		"got %.4f" % Game.sand)

	# --- The sand you can spend is the sand up top ---------------------------
	# At three and four chambers there is exactly one draining chamber, so
	# `danger()`, the HUD, the player's light and the sweat all keep reading one
	# number and none of them had to learn anything.
	Game.arm_glass(4, 2400.0)
	_check("N=4: `sand` is the top chamber, not the whole glass",
		absf(Game.sand - 2400.0) < 0.0001, "got %.4f" % Game.sand)

	# What leaves the top arrives below it. At three chambers it arrives split in
	# two, which is why a turn can never hand back more than half of what you
	# spent — the whole lesson of the trefoil level.
	Game.arm_glass(3, 3000.0)
	Game.drain(600.0)
	_check("N=3: the fall splits half and half",
		absf(Game.chambers[1] - Game.chambers[2]) < 0.0001
			and absf(Game.chambers[1] - 3300.0) < 0.0001,
		"chambers %s" % [Game.chambers])

	# At four chambers it arrives whole — but in the chamber two turns away.
	Game.arm_glass(4, 3000.0)
	Game.drain(600.0)
	_check("N=4: the fall arrives whole, in the bottom chamber",
		absf(Game.chambers[2] - 3600.0) < 0.0001
			and absf(Game.chambers[1] - 3000.0) < 0.0001
			and absf(Game.chambers[3] - 3000.0) < 0.0001,
		"chambers %s" % [Game.chambers])

	# And the sealed chambers are sealed: a glass whose top is empty is dead even
	# with sand still in it, which is what makes hesitation cost something.
	Game.arm_glass(4, 100.0)
	Game.drain(500.0)
	_check("N=4: draining a chamber dry stops there", Game.sand < 0.0001,
		"top holds %.4f" % Game.sand)
	_check("N=4: and the sand it lost is in the bottom, not gone",
		absf(Game.chambers[2] - 3100.0) < 0.0001, "chambers %s" % [Game.chambers])
```

Add this helper at the bottom of `tests/sand_test.gd`, just above `_check`:

```gdscript
func _total(cells: PackedFloat32Array) -> float:
	var out := 0.0
	for v in cells:
		out += v
	return out
```

- [ ] **Step 2: Run it to verify it fails**

```bash
/opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn
```

Expected: a parse error — `Invalid call. Nonexistent function 'arm_glass' in base
'Node'`.

- [ ] **Step 3: Rewrite the state in `game.gd`**

Replace `var sand: float = 0.0` (line 32) with:

```gdscript
## How much sand sits in each chamber, indexed by SLOT — by fixed position on
## screen, not by which chamber it happens to be. Slot 0 is always the top one.
var chambers := PackedFloat32Array([0.0, 0.0])
## How many chambers this level's glass has, which is also how many planes it
## has. Two is the hourglass the game opens with.
var chamber_count := 2

## The sand you can still spend: everything sitting in a chamber that drains.
##
## Derived rather than stored, which is what let the whole multi-chamber glass
## arrive without the HUD, the light, the tremble or `danger()` changing a line.
## At three and four chambers there is exactly one draining chamber, so this is
## simply the top one.
var sand: float:
	get:
		var total := 0.0
		for i in ChamberLayout.uppers(chamber_count):
			total += chambers[i]
		return total
```

- [ ] **Step 4: Rewrite the hourglass section**

Replace everything from `# ----- The hourglass ---` (line 164) to the end of
`pad_flip` (line 192) with:

```gdscript
# ----- The hourglass ---------------------------------------------------------

## The glass a level is played on: `count` chambers, `top` sand in the one on
## top, and the rest of the glass split evenly among the others.
##
## The split needs no tuning. `sand_start` is half of `sand_max`, and the glass
## holds `sand_max * count / 2`, so the remainder divides into exactly
## `sand_start` per chamber whatever the count. A chamber at rest reads half
## full, and the runway before the first turn is compulsory is the same on every
## glass in the game.
func arm_glass(count: int, top: float) -> void:
	chamber_count = clampi(count, 2, Planes.COUNT)
	chambers = PackedFloat32Array()
	chambers.resize(chamber_count)
	chambers[0] = clampf(top, 0.0, capacity())
	var rest := (capacity() * chamber_count / 2.0 - chambers[0]) / float(chamber_count - 1)
	for i in range(1, chamber_count):
		chambers[i] = maxf(rest, 0.0)


## One chamber's capacity. `sand_max` has always meant this — at two chambers all
## of it fits into a single bulb, which is why the shipped flip could clamp to it.
func capacity() -> float:
	return Tuning.cfg.sand_max


## Moves `amount` of sand out of the draining chambers and into whatever sits
## below them. Never destroys a grain: what a chamber loses, its targets gain.
##
## The rate is the glass's, not a chamber's — two chambers draining at once each
## run at half speed, so the clock does not care how the sand is arranged.
func drain(amount: float) -> void:
	var live: Array[int] = []
	for i in ChamberLayout.uppers(chamber_count):
		if chambers[i] > 0.0:
			live.append(i)
	if live.is_empty():
		return
	var each := amount / float(live.size())
	for i in live:
		var moved := minf(each, chambers[i])
		chambers[i] -= moved
		var targets := ChamberLayout.targets(chamber_count, i)
		if targets.is_empty():
			continue
		var share := moved / float(targets.size())
		for t in targets:
			chambers[t] += share


## One step of the glass. `dir` is +1 clockwise on screen and -1 the other way;
## every chamber keeps its sand and moves to the next slot.
##
## At two chambers this IS the flip that shipped: the lower chamber always holds
## `sand_max - top`, so the new top is `sand_max - old_top + sand_flip_base`,
## character for character.
func rotate_glass(dir: int) -> void:
	var moved := PackedFloat32Array()
	moved.resize(chamber_count)
	for i in chamber_count:
		moved[posmod(i + dir, chamber_count)] = chambers[i]
	chambers = moved
	_pay_flip_bonus()


## The tuning panel's flip bonus, kept meaning what it means at any chamber
## count: it tops the draining chambers up, and the glass takes the cost back out
## of the fullest chamber that does not drain, so the total never moves.
##
## It is 0 in the shipped config and this whole function is inert. It is here so
## that dragging the slider still does something sane rather than quietly
## inventing sand.
func _pay_flip_bonus() -> void:
	var bonus := Tuning.cfg.sand_flip_base
	if is_zero_approx(bonus):
		return
	for i in ChamberLayout.uppers(chamber_count):
		var room := capacity() - chambers[i]
		var added := clampf(bonus, 0.0, room)
		chambers[i] += added
		var payer := -1
		for j in chamber_count:
			if j != i and (payer < 0 or chambers[j] > chambers[payer]):
				payer = j
		if payer >= 0:
			var paid := minf(added, chambers[payer])
			chambers[payer] -= paid
			chambers[i] -= added - paid


## A jump: turns the glass AND moves you to the next plane.
func jump_flip(travel_dir: float) -> void:
	# The turn rolls the way you travel — moving right spins clockwise, like a
	# wheel. Keep the last direction on a straight-up jump.
	if not is_zero_approx(travel_dir):
		flip_dir = signf(travel_dir)
	rotate_glass(int(flip_dir))
	set_plane(Planes.step(plane, int(flip_dir), chamber_count))
	flip_anim = Tuning.cfg.flip_duration
	flipped.emit(false)


## A flip-pad: turns the glass with NO jump and NO plane change. It is the only
## way to refuel while staying where you are.
##
## The plane staying put while the glass turns only reads right on a two-chamber
## glass, where the pad simply swaps the two bulbs. No three- or four-chamber
## level places one, and doing so is out of scope.
func pad_flip() -> void:
	rotate_glass(1)
	pad_flash = Tuning.cfg.pad_flash_duration
	flipped.emit(true)
```

Delete `flip_sand()` entirely — `rotate_glass` replaces it, and the test above is
what proves they agree.

- [ ] **Step 5: Point `_process` and `start_level` at the reservoir**

In `_process` (lines 63-67), replace:

```gdscript
	# Sand drains continuously; empty means dead.
	sand -= delta * Tuning.cfg.sand_drain_rate
	if sand <= 0.0:
		sand = 0.0
		set_status(Status.DEAD)
```

with:

```gdscript
	# Sand drains continuously. Death is the DRAINING chambers running dry, not
	# the glass: at four chambers you can die with half the sand still in it,
	# sealed away in a side chamber you did not turn towards.
	drain(delta * Tuning.cfg.sand_drain_rate)
	if sand <= 0.0:
		set_status(Status.DEAD)
```

In `start_level` (line 121), replace `sand = Tuning.cfg.sand_start` with:

```gdscript
	# Two chambers until the level says otherwise. `main.gd` re-arms the glass
	# once the scene exists and can be asked; this is what a level that never
	# does gets.
	arm_glass(2, Tuning.cfg.sand_start)
```

And line 127, `set_plane(Planes.Kind.P0)`, is already right.

- [ ] **Step 6: Stop `main.gd` writing to a derived property**

In `scripts/main.gd`, replace `_apply_level_rules` (lines 97-100) with:

```gdscript
func _apply_level_rules() -> void:
	Game.double_jump = _level.double_jump
	var top := _level.sand_start_override if _level.sand_start_override > 0.0 \
		else Tuning.cfg.sand_start
	Game.arm_glass(2, top)
```

The hard-coded 2 is temporary; Task 7 replaces it with `_level.chambers`.

- [ ] **Step 7: Run everything**

```bash
/opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

Expected: all three `All checks passed.` If `smoke_test` reports a level whose
`sand_start_override` no longer takes, `_apply_level_rules` ran before
`start_level` — check the order in `_load_current_level`.

- [ ] **Step 8: Commit**

```bash
git add scripts/autoload/game.gd scripts/main.gd tests/sand_test.gd && git commit -m "feat(hourglass-hero): the sand becomes a reservoir per chamber"
```

---

## Task 7: A level chooses its glass

**Files:**
- Modify: `scripts/level.gd`
- Modify: `scripts/main.gd:97-102`
- Modify: `scripts/hourglass_motion.gd`
- Modify: `tests/smoke_test.gd`

- [ ] **Step 1: Write the failing test**

In `tests/smoke_test.gd`, inside the per-level loop, extend the rules check.
Replace the `_check("level %d (%s) grants exactly the rules it declares" ...)`
call (lines 121-126) with:

```gdscript
		_check("level %d (%s) grants exactly the rules it declares" % [i + 1, _level_name()],
			Game.double_jump == level.double_jump
				and Game.chamber_count == level.chambers
				and (level.sand_start_override <= 0.0
					or is_equal_approx(Game.sand, level.sand_start_override)),
			"double_jump=%s chambers=%d/%d sand=%.0f (override %.0f)"
				% [Game.double_jump, Game.chamber_count, level.chambers, Game.sand,
					level.sand_start_override])
```

And add this, immediately after the `# --- Spikes obey the plane` block and
before `_finish()`:

```gdscript
	# --- The glass turns as far as its chamber count says --------------------
	# A jump moves you exactly one plane on, whatever the glass is. At two
	# chambers that is the flip the game shipped with; at four it is a quarter
	# turn, and it takes four of them to get back where you started.
	for count in [2, 3, 4]:
		Game.arm_glass(count, Tuning.cfg.sand_start)
		Game.set_plane(Planes.Kind.P0)
		var walked := true
		for turn in count:
			Game.jump_flip(1.0)
			var wanted := posmod(turn + 1, count)
			walked = walked and int(Game.plane) == wanted
		_check("N=%d: turning one way walks the planes in order" % count, walked,
			"landed on %d" % int(Game.plane))
		_check("N=%d: a full lap comes home" % count, int(Game.plane) == 0)
```

- [ ] **Step 2: Run it to verify it fails**

```bash
/opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn
```

Expected: a parse error — `Invalid access to property or key 'chambers' on a
base object of type 'Node2D (Level)'`.

- [ ] **Step 3: Give `Level` a chamber count**

In `scripts/level.gd`, add inside the `Rules` group, immediately after the
`@export_group("Rules")` line and before `sand_start_override`:

```gdscript
## How many chambers this level's glass has — which is also how many planes the
## level has, and how far a jump turns you: a third of a turn at three, a quarter
## at four.
##
## Two is the hourglass the game is built on and what every level shipped with.
## Raising it does not make the level faster: a chamber still opens half full
## against the same drain, so the runway before your first jump is the same. It
## makes the level WIDER — more places to be, and more places for sand to be
## stranded in.
@export_range(2, 4) var chambers := 2
```

- [ ] **Step 4: Read it**

In `scripts/main.gd`, `_apply_level_rules` becomes:

```gdscript
func _apply_level_rules() -> void:
	Game.double_jump = _level.double_jump
	var top := _level.sand_start_override if _level.sand_start_override > 0.0 \
		else Tuning.cfg.sand_start
	Game.arm_glass(_level.chambers, top)
```

- [ ] **Step 5: Turn the glass a chamber's worth**

In `scripts/hourglass_motion.gd`, replace the flip block inside `update` (lines
53-63, the comment and the `if`/`else`) with:

```gdscript
	# A turn is one chamber over the animation's duration. The glass being
	# regular, it lands visually upright and the spin is constant, so it is read
	# straight off the config rather than differenced frame to frame —
	# differencing would spike on the reset back to 0.
	var cfg := Tuning.cfg
	var spin := 0.0
	if Game.flip_anim > 0.0 and cfg.flip_duration > 0.0:
		var turn := TAU / float(Game.chamber_count)
		tilt = Game.flip_dir * turn * (1.0 - Game.flip_anim / cfg.flip_duration)
		spin = Game.flip_dir * turn / cfg.flip_duration
	else:
		tilt = 0.0
```

And replace `chambers()` entirely with:

```gdscript
## How full each chamber is, 0 to 1, indexed by the slot it is drawn in. The size
## of the array is the chamber count, so this one value tells the shape both how
## many chambers to draw and how much is in each.
func chambers() -> PackedFloat32Array:
	var count := Game.chamber_count
	var cap := maxf(Tuning.cfg.sand_max, 1.0)
	# Mid-turn the neck gates the sand and every chamber keeps what it held.
	# `Game.chambers` moved to the post-turn arrangement the instant the jump
	# began, so drawing it one step BACK — inside a glass that has not finished
	# turning — puts each chamber's sand where the chamber still is. At the end
	# of the animation the glass snaps upright and the two agree exactly, which
	# is what makes the landing seamless.
	var back := -int(Game.flip_dir) if Game.flip_anim > 0.0 else 0
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		out[i] = clampf(Game.chambers[posmod(i + back, count)] / cap, 0.0, 1.0)
	return out
```

- [ ] **Step 6: Run everything**

```bash
/opt/homebrew/bin/godot --path . --headless --editor --quit && /opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

Expected: all three `All checks passed.`

- [ ] **Step 7: Screenshot — the tumble is the risky part here**

```bash
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-task7 1 12
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-task7-flip flip 1 12
```

Read the four. The `flip` shots are taken after a jump has landed, so a glass
drawn with its sand one step out of place shows up as a gauge that is full when
it should be nearly empty. Compare against `/tmp/shots-task5-flip`.

- [ ] **Step 8: Commit**

```bash
git add scripts/level.gd scripts/main.gd scripts/hourglass_motion.gd tests/smoke_test.gd && git commit -m "feat(hourglass-hero): a level picks its glass, and the glass turns to fit"
```

---

## Task 8: The direction you turn

The held input decides, not the velocity. Against a wall `velocity.x` reads zero,
and on a four-chamber glass that is the difference between reaching a chamber and
stranding it.

**Files:**
- Modify: `scripts/entities/player.gd:152-158`
- Modify: `tests/smoke_test.gd`

- [ ] **Step 1: Write the failing test**

In `tests/smoke_test.gd`, add immediately after the block Task 7 added and before
`_finish()`:

```gdscript
	# --- Which way you turn ---------------------------------------------------
	# The input HELD at the moment of the jump decides, not the speed you happen
	# to be carrying. Pinned against a wall your velocity reads zero, and on a
	# four-chamber glass that is the difference between reaching a chamber and
	# stranding it for good.
	Game.arm_glass(4, Tuning.cfg.sand_start)
	Game.set_plane(Planes.Kind.P0)
	Game.jump_flip(1.0)
	_check("holding right turns the glass clockwise", int(Game.plane) == 1,
		"landed on %d" % int(Game.plane))
	Game.jump_flip(-1.0)
	_check("holding left turns it back", int(Game.plane) == 0,
		"landed on %d" % int(Game.plane))
	Game.jump_flip(0.0)
	_check("a jump with nothing held keeps the last direction", int(Game.plane) == 3,
		"landed on %d" % int(Game.plane))
```

- [ ] **Step 2: Run it to verify it fails**

```bash
/opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn
```

Expected: these three checks pass already — `jump_flip` has taken a direction
since Task 4, and the test can only reach it through the same argument the player
does. What this step actually proves is that the checks are wired up and read the
right property, so that when Step 3 changes what feeds them they are watching.
The suite stays green throughout this task, which is the point: the change is a
behaviour swap in one argument, and the thing it fixes cannot be reached from a
headless test at all.

The check that would catch it — a jump made while pinned against a wall — needs a
level, a wall and a body in contact with it. Step 4 does it by hand.

- [ ] **Step 3: Read the input instead of the velocity**

In `scripts/entities/player.gd`, replace `_jump` (lines 152-158) with:

```gdscript
## The signature move: height, a turn of the glass, and a plane change, all off
## one press.
##
## The turn follows the input HELD right now rather than `velocity.x`. They agree
## in open ground, and they disagree in exactly the place it matters: pinned
## against a wall your velocity is zero, and reading it would take the choice of
## chamber away from you at the moment you most want it.
func _jump() -> void:
	_buffer = 0.0
	_coyote = 0.0
	_jumping = true
	velocity.y = -Tuning.cfg.jump_velocity
	Game.jump_flip(Input.get_axis("move_left", "move_right"))
	Audio.sfx("jump", 0.0, 0.04)
```

- [ ] **Step 4: Run the suite, then check the source**

```bash
/opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn
```

Expected: `All checks passed.` — including the three direction checks, which now
prove that whatever `_jump` passes reaches the plane.

That `_jump` passes the input rather than the velocity is the part no headless
test reaches, so check it directly:

```bash
grep -n "Game.jump_flip" scripts/entities/player.gd
```

Expected: exactly one line, and it reads
`Game.jump_flip(Input.get_axis("move_left", "move_right"))`. If `velocity.x`
appears in it, the edit did not land.

- [ ] **Step 5: Commit**

```bash
git add scripts/entities/player.gd tests/smoke_test.gd && git commit -m "feat(hourglass-hero): the input you hold picks the way the glass turns"
```

---

## Task 9: A HUD that counts past two

**Files:**
- Modify: `scripts/ui/hud.gd:51-54,61`

- [ ] **Step 1: Name the planes**

In `scripts/ui/hud.gd`, add below the `gauge_size` export:

```gdscript
## What the two planes are called on a two-chamber level. Past two there is no
## front and no back — the planes are a ring, so they are numbered instead.
const PLANE_NAMES := ["FRONT", "BACK"]
```

And replace `_on_plane_changed` with:

```gdscript
func _on_plane_changed(plane: Planes.Kind) -> void:
	var index := clampi(int(plane), 0, Planes.COUNT - 1)
	_plane_label.text = PLANE_NAMES[index] if Game.chamber_count == 2 \
		else "PLANE %d/%d" % [index + 1, Game.chamber_count]
	_plane_label.modulate = Palette.solid(plane, plane)
```

- [ ] **Step 2: Tell the player what the jump does now**

Replace the `Game.Status.PLAY` hint line (line 61) with:

```gdscript
				_hint.text = "← → move    SPACE jump (turns the glass + moves you on)    R restart    ESC menu    F1 tuning"
```

- [ ] **Step 3: Run the suites**

```bash
/opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

Expected: all three `All checks passed.` The HUD is not asserted on anywhere —
nothing here can go red, which is exactly why Step 4 of Task 10 looks at a
picture of it.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/hud.gd && git commit -m "feat(hourglass-hero): the HUD names more than two planes"
```

---

## Task 10: Level 13 — Trefoil

Three chambers, three planes. The lesson is **division**: what you drain is split
in two, so a turn never hands back more than half of it. Turning the same way
every time cycles through all three chambers and collects both halves; going back
and forth bounces between two and starves the third.

The level teaches it by shape. The route runs left to right across `P0` → `P1` →
`P2` platforms in that order and repeats, so a player who holds right and jumps
is turning clockwise every time — the winning habit — and a player who backtracks
loses the plane they need.

**Files:**
- Create: `scenes/levels/level_13_trefoil.tscn`

- [ ] **Step 1: Write the scene**

Create `scenes/levels/level_13_trefoil.tscn` with the Write tool (a heredoc will
not do — `.tscn` is fine either way, but keep the habit):

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/level.gd" id="1_level"]
[ext_resource type="PackedScene" path="res://scenes/entities/door.tscn" id="2_door"]
[ext_resource type="PackedScene" path="res://scenes/entities/platform.tscn" id="3_platform"]

[node name="Level" type="Node2D"]
script = ExtResource("1_level")
level_name = "Trefoil"
world_size = Vector2(960, 540)
chambers = 3

[node name="Spawn" type="Marker2D" parent="."]
position = Vector2(48, 455)

[node name="Entities" type="Node2D" parent="."]

[node name="Ground" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(0, 478)
size = Vector2(150, 62)
plane = 4
kind = 0

[node name="Step1" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(196, 430)
size = Vector2(118, 18)
plane = 1
kind = 0

[node name="Step2" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(360, 382)
size = Vector2(118, 18)
plane = 2
kind = 0

[node name="Step3" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(524, 334)
size = Vector2(118, 18)
plane = 0
kind = 0

[node name="Step4" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(688, 300)
size = Vector2(118, 18)
plane = 1
kind = 0

[node name="Ledge" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(842, 300)
size = Vector2(118, 18)
plane = 2
kind = 0

[node name="Decoy1" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(280, 300)
size = Vector2(96, 18)
plane = 0
kind = 0

[node name="Decoy2" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(470, 226)
size = Vector2(96, 18)
plane = 1
kind = 0

[node name="Door" parent="Entities" instance=ExtResource("2_door")]
position = Vector2(898, 236)
size = Vector2(34, 64)
plane = 4
```

The three step platforms cycle `P1 → P2 → P0 → P1 → P2`, which is exactly one
clockwise turn per jump. The two decoys sit in the plane you would be in if you
had turned the other way at some point — reachable, and a dead end.

- [ ] **Step 2: Nothing to change in the tests**

`tests/smoke_test.gd` counts the level files off disk and loops over whatever
`Game` discovered, so a new level is picked up, given its rules check and its
"runs without dying" check with no edit at all. That is by design — adding a
level is meant to be "drop a .tscn in", and a hard-coded count would turn it into
"drop a .tscn in and then go fix the test".

- [ ] **Step 3: Run the suite**

```bash
/opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn
```

Expected: `All checks passed.`, including
`level 13 (Trefoil) grants exactly the rules it declares` with `chambers=3/3`,
and `level 13 (Trefoil) runs 60 frames without dying`.

If the level fails the "runs 60 frames" check, the spawn is over a pit — the
ground slab is `plane = 4` (BOTH) so it is solid in every plane, and the spawn at
`(48, 455)` must sit on top of it.

- [ ] **Step 4: Play it in a screenshot**

```bash
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-13 13
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-13-flip flip 13
```

Read both. Check three things: the gauge is a **three**-lobed glass, the room is
the cyan ramp at rest and the violet one after the jump, and the platforms in the
other two planes are drawn as ghosts rather than solids.

- [ ] **Step 5: Commit**

```bash
git add scenes/levels/level_13_trefoil.tscn tests/smoke_test.gd && git commit -m "feat(hourglass-hero): Trefoil, where one direction collects both halves"
```

---

## Task 11: Level 14 — Quarters

Four chambers, four planes. The lesson is **delay**: what you drain comes back
whole, but it has to travel through a sealed side chamber to reach the top, so it
is two turns away. Alternating cancels itself exactly — clockwise then
counter-clockwise restores the arrangement before it — which re-serves the same
two chambers and strands the other half of the glass.

The level teaches it with a stretch where the only footing is two planes apart,
so the player has to jump twice the same way with nothing to land on in between,
committing two jumps ahead.

**Files:**
- Create: `scenes/levels/level_14_quarters.tscn`
- Modify: `tests/smoke_test.gd`

- [ ] **Step 1: Write the scene**

Create `scenes/levels/level_14_quarters.tscn`:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/level.gd" id="1_level"]
[ext_resource type="PackedScene" path="res://scenes/entities/door.tscn" id="2_door"]
[ext_resource type="PackedScene" path="res://scenes/entities/platform.tscn" id="3_platform"]
[ext_resource type="PackedScene" path="res://scenes/entities/spikes.tscn" id="4_spikes"]

[node name="Level" type="Node2D"]
script = ExtResource("1_level")
level_name = "Quarters"
world_size = Vector2(960, 540)
chambers = 4

[node name="Spawn" type="Marker2D" parent="."]
position = Vector2(48, 455)

[node name="Entities" type="Node2D" parent="."]

[node name="Ground" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(0, 478)
size = Vector2(170, 62)
plane = 4
kind = 0

[node name="Rise1" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(216, 434)
size = Vector2(110, 18)
plane = 1
kind = 0

[node name="Rise2" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(372, 390)
size = Vector2(110, 18)
plane = 2
kind = 0

[node name="Rise3" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(528, 346)
size = Vector2(110, 18)
plane = 3
kind = 0

[node name="Rise4" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(684, 302)
size = Vector2(110, 18)
plane = 0
kind = 0

[node name="Ledge" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(830, 268)
size = Vector2(130, 18)
plane = 4
kind = 0

[node name="Trap1" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(300, 320)
size = Vector2(96, 18)
plane = 3
kind = 0

[node name="Trap2" parent="Entities" instance=ExtResource("3_platform")]
position = Vector2(470, 244)
size = Vector2(96, 18)
plane = 0
kind = 0

[node name="Spikes" parent="Entities" instance=ExtResource("4_spikes")]
position = Vector2(660, 484)
size = Vector2(230, 20)
plane = 4

[node name="Door" parent="Entities" instance=ExtResource("2_door")]
position = Vector2(900, 204)
size = Vector2(34, 64)
plane = 4
```

The rises run `P1 → P2 → P3 → P0`: one clockwise turn each, so the level is
walkable by holding right. `Trap1` and `Trap2` sit in the plane you land in if
you turn back once, and lead nowhere — the floor below them is spikes.

- [ ] **Step 2: Guard the two glasses**

The per-level loop already covers the new levels, but it says nothing about the
one thing this pass was for: that a level with more than two chambers exists at
all. Add to `tests/smoke_test.gd`, immediately before `_finish()`:

```gdscript
	# --- The shipped game uses every glass ------------------------------------
	# Without this, deleting a chamber count from the levels folder leaves a
	# perfectly green suite testing a feature nothing plays.
	var counts := {}
	for i in Game.level_scenes.size():
		Game.start_level(i)
		await _load_level_scene()
		var level := _current_level()
		if level != null:
			counts[level.chambers] = true
	_check("some level is played on a three-chamber glass", counts.has(3))
	_check("some level is played on a four-chamber glass", counts.has(4))
	_check("and most of them are still the two-chamber hourglass", counts.has(2))
```

- [ ] **Step 3: Run the suites**

```bash
/opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

Expected: all three `All checks passed.`, with
`level 14 (Quarters) grants exactly the rules it declares` reading
`chambers=4/4`, and `every level scene in the folder is discovered` counting 14.

- [ ] **Step 4: Screenshot it**

```bash
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-14 14
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-14-flip flip 14
```

Read both. The gauge must be a **four**-lobed glass: one chamber up with sand in
it, one down with sand in it, and two on the sides that also hold sand and never
move it. The room after the jump is the violet ramp.

This is where the spec's one real colour risk lands. Nothing on screen is
terracotta yet — you only reach `P3` three jumps in — so if you want to see it,
take the shot and then judge it. If the terracotta room reads as "danger" next to
the red spikes, the spec's fallback applies: give `P3` a cooler, darker room ramp
rather than re-picking the hue. Say so rather than fixing it silently.

- [ ] **Step 5: Commit**

```bash
git add scenes/levels/level_14_quarters.tscn tests/smoke_test.gd && git commit -m "feat(hourglass-hero): Quarters, where the refill is two turns away"
```

---

## Task 12: The sweep

**Files:** none created; this is the check that the plan did what it said.

- [ ] **Step 1: Full suite, from a clean cache**

```bash
rm -rf .godot && /opt/homebrew/bin/godot --path . --headless --editor --quit && /opt/homebrew/bin/godot --path . --headless tests/sand_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/smoke_test.tscn && /opt/homebrew/bin/godot --path . --headless tests/chamber_layout_test.tscn
```

Expected: all three `All checks passed.` Deleting `.godot` is what catches a
`class_name` that only resolves because a stale cache remembers it.

- [ ] **Step 2: Shoot every level, both planes**

```bash
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-final
/opt/homebrew/bin/godot --path . --windowed --resolution 1280x720 tests/screenshot.tscn -- /tmp/shots-final-flip flip
```

Read `level_01`, `level_12`, `level_13` and `level_14` from both directories.
Levels 1 and 12 must be indistinguishable from `/tmp/shots-task3` — that is the
whole promise the reservoir model was built to keep.

- [ ] **Step 3: Check nothing was left behind**

```bash
grep -rn "flip_sand\|Planes.opposite\|Kind.FRONT\|Kind.BACK\|FRONT_SOLID\|BACK_SOLID" scripts/ tests/ ; echo "exit=$?"
```

Expected: no output, `exit=1`. Every one of these is a name the plan deleted; a
survivor means a call site was missed and only compiles because something else
still defines it.

```bash
grep -rho "plane = [0-9]" scenes/ | sort | uniq -c
```

Expected: no `plane = 2` line at all, and `plane = 3` appearing only from the two
new levels.

- [ ] **Step 4: Commit whatever the sweep turned up, then push**

```bash
git add -A && git commit -m "fix(hourglass-hero): the multi-chamber sweep" && git push -u origin feat/multi-chamber-glass
```

If the sweep found nothing, skip the commit and just push.

---

## Notes on where this plan departs from the spec

Two places, both deliberate, both smaller than the spec's version:

1. **The width table is gone.** §1 proposes `WIDTH_RATIO[N]` with the note that
   at N=2 it has to land on `size.x/2` and `size.y/2` — which cannot be a ratio
   of the reach, because the shipped glass is 26×38 and not round.
   `HourglassShape._span` says the same thing in three lines: at two chambers the
   glass keeps its authored aspect, above two it is a rosette of radius
   `(w + h) / 4` with half-width `radius * sin(PI / N)`. One branch, no table.

2. **`Planes.step` takes `(kind, steps, count)`,** where §3 writes
   `step(kind, dir, count)`. Same signature, clearer name for the middle
   argument: it is a number of steps and negative means the other way.

One thing the spec leaves open and this plan closes: **a flip-pad on a glass with
more than two chambers.** `pad_flip` turns the sand without moving the player's
plane, which only reads correctly at two chambers. Neither new level places a
pad, and `game.gd` says so where the function is defined.
