## The hourglass, drawn (player sprite and HUD gauge share it). Drawn centred on
## the canvas origin; the caller positions it. Free surfaces are cut square to
## `down`, gravity in the glass's own frame, which `HourglassMotion` computes.
class_name HourglassShape
extends RefCounted

## Half-width of the throat, as a fraction of the glass's half-width.
const NECK_RATIO := 0.13
## Half-height of the throat, as a fraction of the glass's half-height.
const THROAT_RATIO := 0.07
## Bisection steps used to place a free surface; 16 lands inside a pixel.
const LEVEL_STEPS := 16


## Outline of the whole glass, centred on the origin, wound clockwise from the
## top-left. Public: the death shatter cuts its fragments from this same polygon.
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
## `phase` animates the trickle's wobble. `invert` is how far the flow has turned
## over, 0 (down the glass) to 1 (up it).
static func draw_glass(canvas: CanvasItem, size: Vector2, chambers: Vector2, sand: Color,
		down: Vector2, phase: float, line_width := 1.5, invert := 0.0) -> void:
	var hw := size.x / 2.0
	var hh := size.y / 2.0
	var nw := hw * NECK_RATIO
	var nh := hh * THROAT_RATIO

	# One ring, both bulbs joined through the throat, so the neck gets walls.
	var shell := silhouette(size)
	canvas.draw_colored_polygon(shell, Color(Palette.GLASS, 0.10))

	# The two bulbs, without the throat. MUST stay convex: `_level` and `_chord`
	# assume a half-plane cut leaves exactly one piece.
	var upper := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(nw, -nh), Vector2(-nw, -nh),
	])
	var lower := PackedVector2Array([
		Vector2(-nw, nh), Vector2(nw, nh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	# The bulbs are a half turn apart, so one area serves for both.
	var bulb_area := _area(upper)

	# Turning the flow over never turns the glass over: the free surface stays
	# square to `down` the whole way through. What moves is the pile, which lets
	# go of the floor of its bulb and rises to the ceiling in one piece.
	var up := -down
	var upper_sand := pile(upper, down, chambers.x * bulb_area, invert)
	var lower_sand := pile(lower, down, chambers.y * bulb_area, invert)
	fill(canvas, upper_sand, sand)
	fill(canvas, lower_sand, sand)

	# The trickle is drawn as the gap between the two piles, so it stays joined to
	# both whatever the sand is doing: throat to surface at rest, stretched taut
	# mid-turn as the slabs pull away from each other. Fading it out instead left
	# the two blocks hanging with nothing between them.
	var flow := down if invert < 0.5 else up
	var source: float = chambers.x if flow.y >= 0.0 else chambers.y
	var pouring := trickle_rate(size, flow)
	if source > 0.01 and pouring > 0.01:
		# An empty bulb has no face to reach from, so the throat stands in.
		var from := _reach(upper_sand, down, true, -nh)
		var to := _reach(lower_sand, down, false, nh)
		# The wobble is the only part that stops: a column of sand still shimmying
		# while the flow is held at zero says it is moving when it is not.
		var sideways := Vector2(-down.y, down.x)
		var wobble := sideways * sin(phase) * 0.6 * absf(1.0 - 2.0 * invert)
		canvas.draw_line(down * from + wobble, down * to + wobble,
			Color(sand, sand.a * pouring), line_width * 0.8, true)

	_outline(canvas, shell, line_width)
	var lip := hw + line_width * 1.35
	canvas.draw_line(Vector2(-lip, -hh), Vector2(lip, -hh), Palette.GLASS, line_width * 1.35, true)
	canvas.draw_line(Vector2(-lip, hh), Vector2(lip, hh), Palette.GLASS, line_width * 1.35, true)


## How hard the trickle runs, 0 (stopped) to 1. It dries up as the glass tips,
## spent at the bulb wall's own angle so it is never drawn outside the glass.
## Public so the tests measure the rate the drawing actually uses.
static func trickle_rate(size: Vector2, flow: Vector2) -> float:
	var wall := cos(atan2(size.x * (1.0 - NECK_RATIO), size.y * (1.0 - THROAT_RATIO)))
	return clampf((absf(flow.y) - wall) / (1.0 - wall), 0.0, 1.0)


## How far a pile reaches along `down` (`far`) or against it, in that axis alone.
## `fallback` answers for an empty pile, which has no face to measure.
static func _reach(poly: PackedVector2Array, down: Vector2, far: bool,
		fallback: float) -> float:
	if poly.size() < 3:
		return fallback
	var best := -INF if far else INF
	for v in poly:
		var d := v.dot(down)
		best = maxf(best, d) if far else minf(best, d)
	return best


## The sand lying in one bulb: `target` area of it, both surfaces square to
## `down`. Public so the tests can measure the pile the drawing actually uses.
##
## `lift` walks it from the floor of the bulb (0) to its ceiling (1) as the flow
## turns over. It stays one slab throughout — drawing a share at each end and
## crossfading between them splits the sand in two, with a band of bare glass
## across the middle, which is what the first version did and it read as a fault.
## The slab's underside is what is driven; its thickness is re-solved each time so
## the amount of sand drawn never changes on the way up.
static func pile(bulb: PackedVector2Array, down: Vector2, target: float,
		lift := 0.0) -> PackedVector2Array:
	var bottom := INF
	for v in bulb:
		bottom = minf(bottom, v.dot(down))
	var piece := _clip(bulb, down,
		lerpf(_level(bulb, down, target), bottom, clampf(lift, 0.0, 1.0)))
	# Trim off the top, which `_level` places so that `target` is left underneath
	# it. At rest there is nothing to trim: `piece` already holds exactly `target`.
	var up := -down
	return _clip(piece, up, _level(piece, up, target))


## How far along `down` to cut so exactly `target` area lies below, by bisection.
## `down` must be a unit vector.
static func _level(poly: PackedVector2Array, down: Vector2, target: float) -> float:
	var low := INF
	var high := -INF
	for v in poly:
		var d := v.dot(down)
		low = minf(low, d)
		high = maxf(high, d)
	# Answer a brim-full bulb exactly; bisection would stop short and leave a seam
	# of bare glass, which is the state a glass at rest sits in.
	if target >= _area(poly):
		return low
	# Area is monotonic in the cut: `low` holds too much, `high` too little.
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
## misses. Unused by the drawing; `tests/sand_test.gd` measures the surface with it.
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


## A filled polygon with a smooth edge. `draw_colored_polygon` has no AA flag and
## MSAA does not reach it under Compatibility, so the edge is restroked. Public:
## used by anything in the game that draws a diagonal.
static func fill(canvas: CanvasItem, poly: PackedVector2Array, colour: Color) -> void:
	if poly.size() < 3:
		return
	canvas.draw_colored_polygon(poly, colour)
	canvas.draw_polyline(_closed(poly), colour, 1.0, true)


static func _outline(canvas: CanvasItem, poly: PackedVector2Array, width: float) -> void:
	canvas.draw_polyline(_closed(poly), Palette.GLASS, width, true)


## `poly` with its first point repeated, so `draw_polyline` closes the loop.
static func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.append(poly[0])
	return out
