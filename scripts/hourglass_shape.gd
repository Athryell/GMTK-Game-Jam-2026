## The hourglass, drawn (player sprite and HUD gauge share it). Centred on the
## canvas origin; the caller positions it. Free surfaces are cut square to
## `down`, gravity in the glass's own frame, which `HourglassMotion` computes.
class_name HourglassShape
extends RefCounted

## Half-width of the throat, as a fraction of the glass's half-width.
const NECK_RATIO := 0.13
## Half-height of the throat, as a fraction of the glass's half-height.
const THROAT_RATIO := 0.07
## Fraction of a chamber's reach from the neck that the trickle covers before the
## pile hides it.
const STREAM_REACH := 0.82
## Bisection steps used to place a free surface; 16 lands inside a pixel.
const LEVEL_STEPS := 16
## How much of its own `PI / count` wedge a chamber may fill. Must sit strictly
## between 0 and 1: the cap is a tangent, so past the wedge `tan` comes back
## negative and the chamber turns inside out. Overlapping chambers also draw
## their sand twice and make `shell` self-intersect at the neck.
const WEDGE_FILL := 0.8

## The sand's grain: how far the two speckle tones sit either side of the sand
## colour, and how many cells in [constant GRAIN_BUCKETS] wear each. The tones
## are deliberately close — with real contrast the eye reads them as sand moving,
## which is the surface's job.
const GRAIN_LIGHT := 0.17
const GRAIN_DARK := 0.13
const GRAIN_BUCKETS := 16
const GRAIN_LIT_CELLS := 2
## Cumulative, not a second count: buckets 2 and 3 are the shaded ones. Turned
## down from three-eighths, which read as gravel.
const GRAIN_SHADE_CELLS := 4

## What [method _tone] answers with. `TONE_BODY` draws nothing of its own — the
## row's base rect is already that colour underneath.
const TONE_BODY := -1
const TONE_LIT := 0
const TONE_SHADE := 1


## How far a chamber reaches from the neck, and how wide it is at the far end,
## both in px. NOTE the axes swap: `.x` is a reach ALONG the chamber's axis and
## `.y` a half-width ACROSS it.
##
## At two chambers the glass keeps its authored width and height, which is what
## makes the twelve two-plane levels pixel-identical. Above two it is a rosette
## of equal radius, because the sand economy assumes every chamber holds the
## same area.
##
## `sin(PI / count)` bounds the FAR corner only; the NECK corner comes from two
## hand-tuned ratios that know nothing of `count` and is bounded in `chamber`.
static func _span(size: Vector2, count: int) -> Vector2:
	if count == 2:
		return Vector2(size.y / 2.0, size.x / 2.0)
	var radius := (size.x + size.y) / 4.0
	return Vector2(radius, radius * sin(PI / float(count)))


## Chamber `index` as a convex polygon in the glass's own frame: a trapezoid with
## its narrow end at the neck. Corners run far-side, far-other-side,
## neck-other-side, neck-side, which is the order `shell` walks.
static func chamber(size: Vector2, count: int, index: int) -> PackedVector2Array:
	var span := _span(size, count)
	var axis := ChamberLayout.axis(count, index)
	var side := Vector2(-axis.y, axis.x)
	var wide := span.y
	var throat := span.x * THROAT_RATIO
	# `NECK_RATIO` of the full width is a wide corner at a tiny reach, and it
	# overruns the wedge at four chambers. Capping at the wedge keeps neighbours
	# apart; the authored ratio wins wherever there is room, which at two chambers
	# is always.
	var narrow := minf(wide * NECK_RATIO, throat * tan(PI / float(count) * WEDGE_FILL))
	return PackedVector2Array([
		axis * span.x - side * wide,
		axis * span.x + side * wide,
		axis * throat + side * narrow,
		axis * throat - side * narrow,
	])


## The whole glass as ONE ring: every chamber walked in turn and joined through
## the neck. Outlining each chamber separately would rule a line through the
## middle of the glass.
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
## chamber is, 0 to 1, indexed by the slot it is drawn in — its size is the
## number of chambers. `down` is gravity in the glass's own frame. `invert` is
## how far the flow has turned over, 0 (down the glass) to 1 (up it). `tints`
## optionally gives one colour per chamber for its end plate; empty leaves every
## plate plain glass.
static func draw_glass(canvas: CanvasItem, size: Vector2, fills: PackedFloat32Array,
		sand: Color, down: Vector2, line_width := 1.5,
		invert := 0.0, tints := PackedColorArray()) -> void:
	var count := fills.size()
	if count < 2:
		# `chamber` would turn its own polygon inside out rather than say so, and
		# failing quietly would take the player's glass and the HUD gauge off screen
		# with no trace of why.
		push_error("HourglassShape: a glass needs at least two chambers, got %d" % count)
		return

	var ring := shell(size, count)
	canvas.draw_colored_polygon(ring, Color(Palette.GLASS, 0.10))

	# Every chamber is the same trapezoid turned, so one area serves for all.
	var capacity := _area(chamber(size, count, 0))
	for i in count:
		var poly := chamber(size, count, i)
		if fills[i] > 0.001:
			fill_grains(canvas, pile(poly, down, fills[i] * capacity, invert), sand)

	_trickle(canvas, size, count, fills, sand, down, line_width, invert)

	# A tinted plate is drawn heavier than a plain one: at the size the HUD gauge
	# runs, a hue laid on at hairline width reads as a smudge rather than a label.
	_outline(canvas, ring, line_width)
	for i in count:
		var poly := chamber(size, count, i)
		var tinted := i < tints.size()
		var weight := line_width * (2.1 if tinted else 1.35)
		var overhang := (poly[1] - poly[0]).normalized() * weight
		canvas.draw_line(poly[0] - overhang, poly[1] + overhang,
			tints[i] if tinted else Palette.GLASS, weight, true)


## The sand in the air: one thread from each draining chamber to each chamber it
## pours into.
##
## The fall dries up as the glass tips, spent by the angle of a chamber's own
## wall — the tilt at which falling sand would start missing the chamber below,
## so a trickle is never drawn outside the glass.
static func _trickle(canvas: CanvasItem, size: Vector2, count: int,
		fills: PackedFloat32Array, sand: Color, down: Vector2,
		line_width: float, invert: float) -> void:
	# Measured off the polygon that actually gets drawn: above two chambers
	# `chamber` caps its neck corner, so the authored `NECK_RATIO` is not the wall
	# you can see.
	var edge := chamber(size, count, 0)
	var wall := cos(absf((edge[0] - edge[3]).angle_to(ChamberLayout.axis(count, 0))))
	var pouring := clampf((down.y - wall) / (1.0 - wall), 0.0, 1.0)
	if pouring <= 0.01:
		return
	var climbing := invert >= 0.5
	for i in count:
		if fills[i] <= 0.01 and not climbing:
			continue
		for j in ChamberLayout.targets(count, i):
			if climbing and fills[j] <= 0.01:
				continue
			var seg := trickle_segment(size, count, i, j, down, invert)
			fill_grains(canvas, thread_quad(seg[0], seg[1], line_width * 0.8),
				Color(sand, sand.a * pouring))


## The thread of sand in flight from chamber `index` into chamber `target`, as
## its two endpoints in the glass's own frame.
##
## It starts at the UNDERSIDE of the draining chamber: from the origin, the
## height of the throat would show as a gap of bare glass mid-fall.
##
## `way` is +1 running down the glass, 0 at the hand-over and -1 running up it,
## and signs every term — so the column mirrors through the neck as the flow
## turns over instead of hanging on the falling side.
static func trickle_segment(size: Vector2, count: int, index: int, target: int,
		down: Vector2, invert := 0.0) -> PackedVector2Array:
	var span := _span(size, count)
	var throat := span.x * THROAT_RATIO
	var below := -ChamberLayout.axis(count, index)
	var dir := down.rotated(below.angle_to(ChamberLayout.axis(count, target)))
	var way := 1.0 - 2.0 * invert
	var head := -dir * throat * way
	return PackedVector2Array([head, head + dir * way * (span.x * STREAM_REACH + throat)])


## How hard the trickle runs, 0 (stopped) to 1. It dries up as the glass tips,
## spent at the bulb wall's own angle so it is never drawn outside the glass.
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
## `down`. `lift` walks it from the floor of the bulb (0) to its ceiling (1), in
## one slab: split it in two and a band of bare glass opens across the middle.
static func pile(bulb: PackedVector2Array, down: Vector2, target: float,
		lift := 0.0) -> PackedVector2Array:
	var bottom := INF
	for v in bulb:
		bottom = minf(bottom, v.dot(down))
	var piece := _clip(bulb, down,
		lerpf(_level(bulb, down, target), bottom, clampf(lift, 0.0, 1.0)))
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
## misses. Used only by `tests/sand_test.gd`.
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
## MSAA does not reach it under Compatibility, so the edge is restroked. For
## shapes that are not pixel art, like a spike; the sand uses [method
## fill_grains].
static func fill(canvas: CanvasItem, poly: PackedVector2Array, colour: Color) -> void:
	if poly.size() < 3:
		return
	canvas.draw_colored_polygon(poly, colour)
	canvas.draw_polyline(_closed(poly), colour, 1.0, true)


## The same polygon, laid down on the pixel grid instead of filled smoothly: a
## cell is sand when its CENTRE lies inside `poly`, so the surface comes out
## stepped in whole pixels and slides down in whole pixels as the bulb drains.
##
## `cell` is a world px. Left as a number rather than read off anything, because
## a glass drawn at some other scale still wants grains the size of the brick's
## pixels, not of its own.
static func fill_grains(canvas: CanvasItem, poly: PackedVector2Array, colour: Color,
		cell := 1.0) -> void:
	if poly.size() < 3 or cell <= 0.0:
		return
	var top := INF
	var bottom := -INF
	for v in poly:
		top = minf(top, v.y)
		bottom = maxf(bottom, v.y)
	var lit := colour.lightened(GRAIN_LIGHT)
	var shade := colour.darkened(GRAIN_DARK)
	var n := poly.size()
	for row in range(floori(top / cell), floori(bottom / cell) + 1):
		var y := (row + 0.5) * cell
		# The pile is convex in practice, so the extreme crossings bound the run.
		# Taking min and max rather than pairing crossings up fills a concave row
		# solid, which is the failure worth having: a stripe of bare glass across the
		# sand would read as a bug, a slightly over-full row does not.
		var left := INF
		var right := -INF
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			if (a.y <= y) == (b.y <= y):
				continue
			left = minf(left, a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y))
			right = maxf(right, a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y))
		if left > right:
			continue
		var first := ceili(left / cell - 0.5)
		var last := floori(right / cell - 0.5)
		if last < first:
			continue
		canvas.draw_rect(Rect2(first * cell, row * cell,
			(last - first + 1) * cell, cell), colour)
		# Speckle merged into runs: neighbouring cells wearing one tone go down as a
		# single rect, which is a few rects a row instead of one per grain.
		var start := first
		var tone := _tone(first, row)
		for i in range(first + 1, last + 2):
			var next := _tone(i, row) if i <= last else TONE_BODY
			if next == tone:
				continue
			if tone != TONE_BODY:
				canvas.draw_rect(Rect2(start * cell, row * cell, (i - start) * cell, cell),
					lit if tone == TONE_LIT else shade)
			start = i
			tone = next


## One loose grain, laid on the same grid and wearing the same speckle as a pile.
##
## `at` is anywhere in the grain's cell — a spilled grain flies along a smooth arc
## and is snapped here, so it crosses the screen a whole pixel at a time exactly
## as a draining surface slides down one. The tone comes off the CELL, so a grain
## changes shade as it travels: it is the glass's texture showing through a moving
## hole, which is what the piles do and what keeps the spill made of the same sand.
static func draw_grain(canvas: CanvasItem, at: Vector2, colour: Color,
		cell := 1.0) -> void:
	if cell <= 0.0:
		return
	var i := floori(at.x / cell)
	var row := floori(at.y / cell)
	var tone := _tone(i, row)
	var c := colour
	if tone == TONE_LIT:
		c = colour.lightened(GRAIN_LIGHT)
	elif tone == TONE_SHADE:
		c = colour.darkened(GRAIN_DARK)
	canvas.draw_rect(Rect2(i * cell, row * cell, cell, cell), c)


## A segment as a rectangle, so a thread of falling sand can go through [method
## fill_grains] and land on the same grid as the piles it runs between.
static func thread_quad(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var across := (b - a).orthogonal().normalized() * (width * 0.5)
	return PackedVector2Array([a - across, b - across, b + across, a + across])


## Which tone a grain wears. Hashed from the cell's place on the GRID, not from
## the sand sitting in it: that pins the speckle to the glass, so a draining bulb
## uncovers a texture that was already there instead of one that boils as it
## goes.
static func _tone(i: int, row: int) -> int:
	var h := (i * 73856093) ^ (row * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	var bucket: int = absi(h ^ (h >> 16)) % GRAIN_BUCKETS
	if bucket < GRAIN_LIT_CELLS:
		return TONE_LIT
	return TONE_SHADE if bucket < GRAIN_SHADE_CELLS else TONE_BODY


static func _outline(canvas: CanvasItem, poly: PackedVector2Array, width: float) -> void:
	canvas.draw_polyline(_closed(poly), Palette.GLASS, width, true)


## `poly` with its first point repeated, so `draw_polyline` closes the loop.
static func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.append(poly[0])
	return out
