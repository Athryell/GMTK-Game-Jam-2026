## The hourglass, drawn (player sprite and HUD gauge share it). Drawn centred on
## the canvas origin; the caller positions it. Free surfaces are cut square to
## `down`, gravity in the glass's own frame, which `HourglassMotion` computes.
class_name HourglassShape
extends RefCounted

## Half-width of the throat, as a fraction of the glass's half-width.
const NECK_RATIO := 0.13
## Half-height of the throat, as a fraction of the glass's half-height.
const THROAT_RATIO := 0.07
## Fraction of a chamber's reach from the neck that the trickle covers before the
## pile hides it. That reach is `_span(...).x` — half the glass's height at two
## chambers, the rosette's radius above two.
const STREAM_REACH := 0.82
## Bisection steps used to place a free surface; 16 lands inside a pixel.
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
## `phase` animates the trickle's wobble. `invert` is how far the flow has turned
## over, 0 (down the glass) to 1 (up it).
static func draw_glass(canvas: CanvasItem, size: Vector2, fills: PackedFloat32Array,
		sand: Color, down: Vector2, phase: float, line_width := 1.5,
		invert := 0.0) -> void:
	var count := fills.size()
	if count < 2:
		# Below two there is nowhere for sand to fall, and `chamber` would turn its
		# own polygon inside out rather than say so. Drawing nothing is the only
		# safe answer, but doing it quietly would take the player's glass AND the
		# HUD gauge off the screen with no trace of why.
		push_error("HourglassShape: a glass needs at least two chambers, got %d" % count)
		return

	# The glass itself, in one piece.
	var ring := shell(size, count)
	canvas.draw_colored_polygon(ring, Color(Palette.GLASS, 0.10))

	# The sand. Every chamber is the same trapezoid turned, so one area serves
	# for all of them — the same symmetry that makes a completed turn seamless.
	#
	# Turning the flow over never turns the glass over: the surfaces stay square
	# to `down` throughout, and only the piles climb.
	var capacity := _area(chamber(size, count, 0))
	for i in count:
		var poly := chamber(size, count, i)
		if fills[i] > 0.001:
			fill(canvas, pile(poly, down, fills[i] * capacity, invert), sand)

	_trickle(canvas, size, count, fills, sand, down, phase, line_width, invert)

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
##
## `invert` runs the same falls backwards. The thread occupies the same segment
## either way, so all that turns over is which end has to hold sand for there to
## be anything to draw — plus the wobble, which stops: a column still shimmying
## reads as still running.
static func _trickle(canvas: CanvasItem, size: Vector2, count: int,
		fills: PackedFloat32Array, sand: Color, down: Vector2, phase: float,
		line_width: float, invert: float) -> void:
	var span := _span(size, count)
	var throat := span.x * THROAT_RATIO
	# Measured off the polygon that actually gets drawn, not rebuilt from the
	# ratios: above two chambers `chamber` caps its neck corner at the wedge, so
	# the authored `NECK_RATIO` is not the wall you can see. Reproduces the
	# shipped 0.8485 exactly at two.
	var edge := chamber(size, count, 0)
	var wall := cos(absf((edge[0] - edge[3]).angle_to(ChamberLayout.axis(count, 0))))
	var pouring := clampf((down.y - wall) / (1.0 - wall), 0.0, 1.0)
	if pouring <= 0.01:
		return
	var climbing := invert >= 0.5
	for i in count:
		if fills[i] <= 0.01 and not climbing:
			continue
		var below := -ChamberLayout.axis(count, i)
		for j in ChamberLayout.targets(count, i):
			if climbing and fills[j] <= 0.01:
				continue
			# One thread per (draining chamber -> target) pair, and it is aimed by
			# turning gravity through the angle from straight-below-the-draining-
			# chamber to where the target actually sits.
			#
			# Aiming it along plain `down` is what a two-bulb glass gets away with
			# and a three-lobed one does not: at three there is no chamber opposite
			# the top one, so straight down lands in the dead V between the two
			# receivers and the thread hangs over bare background. Aiming it along
			# the target's own axis instead would fix the upright case and break
			# every tilted one, because a tipped glass's sand does not swing round
			# with the walls. Turning `down` keeps both — the fall still leans with
			# gravity, and when the target IS straight below (which is every
			# draining chamber at two and at four) the rotation is zero and this is
			# bit-for-bit the line that shipped, at any tilt.
			var dir := down.rotated(below.angle_to(ChamberLayout.axis(count, j)))
			var sideways := Vector2(-dir.y, dir.x)
			# Starts at the UNDERSIDE of the draining chamber, not at the centre of
			# the glass: the sand stops at the top of the throat, so a trickle
			# beginning at the origin leaves the height of the throat as a gap of
			# bare glass, and the fall reads as cut in two right where it should be
			# one thing.
			var head := sideways * sin(phase) * 0.6 * absf(1.0 - 2.0 * invert) - dir * throat
			canvas.draw_line(head, head + dir * (span.x * STREAM_REACH + throat),
				Color(sand, sand.a * pouring), line_width * 0.8, true)


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
	# Trim back to `target`; at rest `piece` already holds exactly that.
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
