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


## The outline of the whole glass, centred on the origin: both bulbs joined
## through the throat, wound clockwise from the top-left.
##
## Public because the death shatter cuts its fragments out of this exact
## polygon. A second hand-written copy of these eight points would be a silent
## trap: widen the neck here and the glass that breaks would stop being the
## glass that was standing there.
static func silhouette(size: Vector2) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var nw := hw * NECK_RATIO
	var nh := hh * THROAT_RATIO
	return PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(nw, -nh), Vector2(nw, nh),
		Vector2(hw, hh), Vector2(-hw, hh), Vector2(-nw, nh), Vector2(-nw, -nh),
	])


## `size` is the full width and height of the glass. `chambers` is how full each
## bulb is, 0 to 1: `x` the one at local -y, `y` the one at local +y. `down` is
## gravity in the glass's own frame — pass `Vector2.DOWN` for an upright glass.
## `phase` animates the trickle's wobble.
static func draw_glass(canvas: CanvasItem, size: Vector2, chambers: Vector2, sand: Color,
		down: Vector2, phase: float, line_width := 1.5) -> void:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var nw := hw * NECK_RATIO
	var nh := hh * THROAT_RATIO

	# The glass itself: one ring, both bulbs joined through the throat. Drawing
	# it in a single piece is what puts walls on the neck.
	var shell := silhouette(size)
	canvas.draw_colored_polygon(shell, Color(Palette.GLASS, 0.10))

	# The two bulbs the sand sits in, without the throat. Convex on purpose:
	# cutting a convex polygon with a half-plane always leaves exactly one convex
	# piece, which is the assumption `_level` and `_chord` are built on.
	var upper := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(nw, -nh), Vector2(-nw, -nh),
	])
	var lower := PackedVector2Array([
		Vector2(-nw, nh), Vector2(nw, nh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	# The bulbs are each other turned half a turn, so one area serves for both —
	# and that same symmetry is why a completed flip is seamless.
	var bulb_area := _area(upper)

	_pour(canvas, upper, down, chambers.x * bulb_area, sand)
	_pour(canvas, lower, down, chambers.y * bulb_area, sand)

	# The trickle, falling straight down whatever the glass is doing, and drying
	# up as the glass tips — tilt a real hourglass and the neck stops feeding.
	# It is spent by the angle of the bulb's own wall, which is exactly the tilt
	# at which falling sand would start missing the bulb: the trickle can never
	# be drawn outside the glass.
	var wall := cos(atan2(hw - nw, hh - nh))
	var pouring := clampf((down.y - wall) / (1.0 - wall), 0.0, 1.0)
	if chambers.x > 0.01 and pouring > 0.01:
		var sideways := Vector2(-down.y, down.x)
		# Starts at the UNDERSIDE of the upper bulb, not at the centre of the glass.
		# The bulb's sand stops at the top of the throat, so a trickle beginning at
		# the origin leaves the height of the throat as a gap of bare glass — the
		# sand reads as cut in two right where it should be one continuous fall.
		var head := sideways * sin(phase) * 0.6 - down * nh
		canvas.draw_line(head, head + down * (hh * STREAM_REACH + nh),
			Color(sand, sand.a * pouring), line_width * 0.8, true)

	# Frame: the outline, then the plates capping it.
	_outline(canvas, shell, line_width)
	var lip := hw + line_width * 1.35
	canvas.draw_line(Vector2(-lip, -hh), Vector2(lip, -hh), Palette.GLASS, line_width * 1.35, true)
	canvas.draw_line(Vector2(-lip, hh), Vector2(lip, hh), Palette.GLASS, line_width * 1.35, true)


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
