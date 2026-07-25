## The hourglass, drawn (player sprite and HUD gauge share it). Drawn centred on
## the canvas origin; the caller positions it. Free surfaces are cut square to
## `down`, gravity in the glass's own frame, which `HourglassMotion` computes.
class_name HourglassShape
extends RefCounted

## Half-width of the throat, as a fraction of the glass's half-width.
const NECK_RATIO := 0.13
## Half-height of the throat, as a fraction of the glass's half-height.
const THROAT_RATIO := 0.07
## Fraction of a bulb's height the trickle reaches before the pile hides it.
const STREAM_REACH := 0.82
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
## `phase` animates the trickle's wobble.
static func draw_glass(canvas: CanvasItem, size: Vector2, chambers: Vector2, sand: Color,
		down: Vector2, phase: float, line_width := 1.5) -> void:
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

	_pour(canvas, upper, down, chambers.x * bulb_area, sand)
	_pour(canvas, lower, down, chambers.y * bulb_area, sand)

	# The trickle, falling straight down and drying up as the glass tips. Spent at
	# the bulb wall's own angle, so it is never drawn outside the glass.
	var wall := cos(atan2(hw - nw, hh - nh))
	# Which bulb feeds the trickle is decided by gravity, not by the drawing:
	# invert `down` and the lower bulb becomes the one on top. The rate reads off
	# `absf(down.y)` because the signed version silently returned zero, leaving
	# both bulbs correctly filled with no sand visibly moving between them.
	var source: float = chambers.x if down.y >= 0.0 else chambers.y
	var pouring := clampf((absf(down.y) - wall) / (1.0 - wall), 0.0, 1.0)
	if source > 0.01 and pouring > 0.01:
		var sideways := Vector2(-down.y, down.x)
		# Starts at the underside of the source bulb, not the origin, or the
		# throat's height shows as a gap of bare glass.
		var head := sideways * sin(phase) * 0.6 - down * nh
		canvas.draw_line(head, head + down * (hh * STREAM_REACH + nh),
			Color(sand, sand.a * pouring), line_width * 0.8, true)

	_outline(canvas, shell, line_width)
	var lip := hw + line_width * 1.35
	canvas.draw_line(Vector2(-lip, -hh), Vector2(lip, -hh), Palette.GLASS, line_width * 1.35, true)
	canvas.draw_line(Vector2(-lip, hh), Vector2(lip, hh), Palette.GLASS, line_width * 1.35, true)


## Sand resting in one bulb, covering `target` area, surface square to `down`.
static func _pour(canvas: CanvasItem, bulb: PackedVector2Array, down: Vector2,
		target: float, colour: Color) -> void:
	if target <= 0.001:
		return
	fill(canvas, _clip(bulb, down, _level(bulb, down, target)), colour)


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
