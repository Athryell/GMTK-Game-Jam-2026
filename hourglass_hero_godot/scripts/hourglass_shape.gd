## The hourglass, drawn. One routine, two callers: the player sprite and the HUD
## gauge.
##
## Sharing it is the point — the gauge in the corner and the thing you steer are
## the same object seen twice, so they must never drift apart visually. Draws
## centred on the canvas origin; the caller positions it.
##
## The sand behaves like a liquid: the caller passes `down`, the direction
## gravity points *in the glass's own frame*, and every free surface is cut
## square to it. Tip the glass and the sand stays level instead of turning with
## the walls. `HourglassMotion` is what works out that vector.
##
## Everything here is vector, not sprites, so it stays sharp at any size. Smooth
## edges come from `antialiased` on every stroke plus the window override in
## `project.godot` (fills have no per-call AA flag, and MSAA 2D does nothing
## under the Compatibility renderer).
class_name HourglassShape
extends RefCounted

## Half-width of the throat, as a fraction of the glass's half-width. Two
## triangles meeting at a bare point pinch into a single aliased pixel and read
## as a glitch; a short throat is both cleaner and closer to a real hourglass.
const NECK_RATIO := 0.13
## Half-height of the throat, as a fraction of the glass's half-height.
const THROAT_RATIO := 0.07
## Fraction of a bulb's height the trickle reaches before the pile hides it.
const STREAM_REACH := 0.82
## Bisection steps used to place a free surface. Each one halves the error, so
## 16 lands well inside a pixel at any size we draw.
const LEVEL_STEPS := 16
## How much of its own wedge a chamber may fill, measured as an angle off its
## axis. Chamber `i` owns the wedge `PI / count` either side of its axis; at 1.0
## it fills that wedge exactly and touches its neighbours, so the neck corners
## are held to this fraction of it instead.
##
## Must sit strictly between 0 and 1, and 1 is a harder ceiling than it looks:
## the cap is a tangent, so past the wedge the angle goes obtuse, `tan` comes
## back NEGATIVE, and the chamber turns inside out rather than merely touching.
##
## It is not decoration. Two chambers that overlap draw their sand twice over the
## shared sliver, and `shell` — one ring through every chamber — stops being a
## simple polygon, which `draw_colored_polygon` triangulates into a mess right at
## the neck, where the eye is.
const WEDGE_FILL := 0.8


## How far a chamber reaches from the neck, and how wide it is at the far end,
## both in px, for a glass of `size`. NOTE the axes swap: `.x` is a reach ALONG
## the chamber's axis and `.y` a half-width ACROSS it, so at two chambers `.x`
## comes from `size.y` and `.y` from `size.x`. `chamber` renames them the moment
## it has them.
##
## At two chambers the glass keeps the width and height it was authored with —
## which is what makes the twelve two-plane levels pixel-identical, and it costs
## one branch. Above two it is a rosette, so it takes one radius in every
## direction: an ellipse of chambers would give the side lobes a different area
## from the top one, and the sand economy assumes every chamber holds the same.
##
## `sin(PI / count)` sets the FAR end only, and buys it a real margin: a corner
## at half-width `r * sin(t)` and reach `r` sits `atan(sin(t))` off the axis,
## which is comfortably short of `t` (35 degrees of a 45-degree wedge at four).
## It says nothing at all about the NECK end — that corner is `NECK_RATIO` over
## `THROAT_RATIO`, two hand-tuned constants with no idea `count` exists, and at
## four chambers they aim it 52 degrees off a 45-degree wedge. `chamber` is where
## that gets bounded, by `WEDGE_FILL`; see the note there.
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
	var throat := span.x * THROAT_RATIO
	# The throat is short, so `NECK_RATIO` of the full width is a wide corner at a
	# tiny reach — an angle off the axis that grows as the glass gets more
	# chambers to share the same neck, and overruns the wedge at four. Capping it
	# at the wedge is what keeps neighbours apart; the authored ratio wins
	# wherever there is room for it, which at two chambers is always.
	var narrow := minf(wide * NECK_RATIO, throat * tan(PI / float(count) * WEDGE_FILL))
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


## Sand resting in one bulb, covering `target` area, with a surface square to
## `down`. Wherever the bulb's lowest point is, that is where the sand pools.
static func _pour(canvas: CanvasItem, bulb: PackedVector2Array, down: Vector2,
		target: float, colour: Color) -> void:
	if target <= 0.001:
		return
	fill(canvas, _clip(bulb, down, _level(bulb, down, target)), colour)


## Where the free surface sits: how far along `down` to cut so that exactly
## `target` area lies below. Found by bisection rather than by formula, so the
## bulbs can change shape with no maths to redo. `down` must be a unit vector.
static func _level(poly: PackedVector2Array, down: Vector2, target: float) -> float:
	var low := INF
	var high := -INF
	for v in poly:
		var d := v.dot(down)
		low = minf(low, d)
		high = maxf(high, d)
	# A brim-full bulb needs no search, and answering it exactly is worth the one
	# extra area: bisection would stop a hair short and leave a seam of bare glass
	# along the wall, which is the state a glass at rest sits in.
	if target >= _area(poly):
		return low
	# Cutting further down leaves less sand, so the area is monotonic in the cut
	# and plain bisection is enough. `low` always holds too much, `high` too little.
	for _step in LEVEL_STEPS:
		var mid := (low + high) * 0.5
		if _area(_clip(poly, down, mid)) > target:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


## The part of `poly` lying below the surface — Sutherland–Hodgman against the
## half-plane `v.dot(down) >= level`.
static func _clip(poly: PackedVector2Array, down: Vector2, level: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var da := a.dot(down) - level
		var db := b.dot(down) - level
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


## The two points where the surface meets the bulb's walls, or nothing if it
## misses the bulb entirely. Nothing drawn here needs it; `tests/sand_test.gd`
## uses it to measure the angle a free surface actually comes out at.
static func _chord(poly: PackedVector2Array, down: Vector2, level: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var da := a.dot(down) - level
		var db := b.dot(down) - level
		if (da >= 0.0) != (db >= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


static func _area(poly: PackedVector2Array) -> float:
	var n := poly.size()
	if n < 3:
		return 0.0
	var total := 0.0
	for i in n:
		var p := poly[i]
		var q := poly[(i + 1) % n]
		total += p.x * q.y - q.x * p.y
	return absf(total) * 0.5


## A filled polygon with a smooth edge. `draw_colored_polygon` has no
## antialiasing flag and MSAA does not reach it under the Compatibility
## renderer, so the edge is redrawn as an antialiased stroke in the fill's own
## colour — the slanted walls stop being a staircase.
##
## Public because it is not really about hourglasses: anything in this game that
## draws a diagonal needs it, and `Spikes` used to carry its own copy.
static func fill(canvas: CanvasItem, poly: PackedVector2Array, colour: Color) -> void:
	if poly.size() < 3:
		return
	canvas.draw_colored_polygon(poly, colour)
	canvas.draw_polyline(_closed(poly), colour, 1.0, true)


static func _outline(canvas: CanvasItem, poly: PackedVector2Array, width: float) -> void:
	canvas.draw_polyline(_closed(poly), Palette.GLASS, width, true)


## `poly` with its first point repeated at the end, which is what `draw_polyline`
## needs to come all the way back round.
static func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.append(poly[0])
	return out
