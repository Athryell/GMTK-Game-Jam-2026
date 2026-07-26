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

## The sand's grain: how far the two speckle tones sit either side of the sand
## colour, and how many cells in [constant GRAIN_BUCKETS] wear each.
##
## Three tones is the whole palette — a body, something catching the light and
## something in shadow. A fourth reads as noise at one world px a grain rather
## than as sand, and the tones are deliberately close: they are texture, and the
## moment they carry real contrast the eye starts reading them as sand MOVING,
## which is the surface's job and not theirs.
const GRAIN_LIGHT := 0.17
const GRAIN_DARK := 0.13
const GRAIN_BUCKETS := 16
const GRAIN_LIT_CELLS := 2
## Cumulative, not a second count: buckets 2 and 3 are the shaded ones, so a
## quarter of the pile is speckled at all and three quarters are plain sand.
##
## Turned DOWN from three-eighths, which read as gravel. The failure is not
## subtle when it happens: past about a third the speckle stops being a surface
## the sand has and starts being what the sand is made of.
const GRAIN_SHADE_CELLS := 4

## What [method _tone] answers with. `TONE_BODY` draws nothing of its own — the
## row's base rect is already that colour underneath.
const TONE_BODY := -1
const TONE_LIT := 0
const TONE_SHADE := 1


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
## `invert` is how far the flow has turned over, 0 (down the glass) to 1 (up it). `tints` optionally gives one colour per
## chamber for its end plate — the plane each side of the glass stands for; empty
## leaves every plate plain glass.
static func draw_glass(canvas: CanvasItem, size: Vector2, fills: PackedFloat32Array,
		sand: Color, down: Vector2, line_width := 1.5,
		invert := 0.0, tints := PackedColorArray()) -> void:
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
			fill_grains(canvas, pile(poly, down, fills[i] * capacity, invert), sand)

	_trickle(canvas, size, count, fills, sand, down, line_width, invert)

	# Frame: the outline, then a plate capping each chamber. A tinted plate is
	# drawn heavier than a plain one — at the size the HUD gauge runs, a plane's
	# hue laid on at hairline width reads as a smudge rather than as a label.
	_outline(canvas, ring, line_width)
	for i in count:
		var poly := chamber(size, count, i)
		var tinted := i < tints.size()
		var weight := line_width * (2.1 if tinted else 1.35)
		var overhang := (poly[1] - poly[0]).normalized() * weight
		canvas.draw_line(poly[0] - overhang, poly[1] + overhang,
			tints[i] if tinted else Palette.GLASS, weight, true)


## The sand in the air: one thread from each draining chamber to each chamber it
## pours into. At two chambers that is the single fall down the middle; at three
## it is the pair that splits half and half, and nothing here had to be told the
## difference.
##
## The fall dries up as the glass tips, spent by the angle of a chamber's own
## wall — which is exactly the tilt at which falling sand would start missing the
## chamber below, so a trickle can never be drawn outside the glass.
##
## `invert` runs the same falls backwards, and the thread has to turn over with
## them: sand in flight sits between the neck and whichever chamber it is heading
## for, so a climbing fall belongs ABOVE the neck, in the chamber being filled.
## Drawn on the falling side throughout, it reads as still pouring downwards
## while every pile around it climbs.
##
## Turned over through a signed reach rather than a branch, so the column
## shortens into the neck, vanishes as the flow hands over, and grows back out
## the other side.
static func _trickle(canvas: CanvasItem, size: Vector2, count: int,
		fills: PackedFloat32Array, sand: Color, down: Vector2,
		line_width: float, invert: float) -> void:
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
		for j in ChamberLayout.targets(count, i):
			if climbing and fills[j] <= 0.01:
				continue
			# One thread per (draining chamber -> target) pair.
			var seg := trickle_segment(size, count, i, j, down, invert)
			fill_grains(canvas, thread_quad(seg[0], seg[1], line_width * 0.8),
				Color(sand, sand.a * pouring))


## The thread of sand in flight from chamber `index` into chamber `target`, as
## its two endpoints in the glass's own frame.
##
## Split out of the drawing so the reversal can be measured rather than merely
## looked at; `tests/sand_test.gd` holds it to mirroring through the neck.
##
## It starts at the UNDERSIDE of the draining chamber, not at the centre of the
## glass: the sand stops at the top of the throat, so a thread beginning at the
## origin leaves the height of the throat as a gap of bare glass, and the fall
## reads as cut in two right where it should be one thing.
##
## `way` is +1 running down the glass, 0 at the hand-over and -1 running up it,
## and every term is signed by it — so the column mirrors through the neck as the
## flow turns over instead of hanging on the falling side, shrinking away to
## nothing as it changes its mind.
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
##
## Not what the sand uses any more — see [method fill_grains]. Still the right
## answer for a shape that is not pixel art, like a spike.
static func fill(canvas: CanvasItem, poly: PackedVector2Array, colour: Color) -> void:
	if poly.size() < 3:
		return
	canvas.draw_colored_polygon(poly, colour)
	canvas.draw_polyline(_closed(poly), colour, 1.0, true)


## The same polygon, laid down on the pixel grid instead of filled smoothly.
##
## Nothing about the sand's MOVEMENT changes here. `poly` is whatever [method
## pile] produced — the surfaces still sit square to gravity, still find their
## level by area, still climb through a turn. All that changes is how the result
## is put on screen: a cell is sand when its CENTRE lies inside `poly`, so the
## surface comes out stepped in whole pixels the size of the painted ones, and
## slides down in whole pixels as the bulb drains.
##
## `cell` is a world px, which is an art px everywhere in this game. Left as a
## number rather than read off anything, because a glass drawn at some other
## scale still wants grains the size of the brick's pixels, not of its own.
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
		# Where the row's centre line crosses the outline. The pile is convex in
		# practice, so the extreme crossings bound the run — taking the min and max
		# rather than pairing crossings up leaves a concave one filled solid, which
		# is the failure that is worth having: a stripe of bare glass across the
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
		# Then the speckle over it, merged into runs: neighbouring cells wearing one
		# tone go down as a single rect. At this density that is most of them, and
		# it is the difference between a few rects a row and one per grain.
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


## A segment as a rectangle, so a thread of falling sand can go through [method
## fill_grains] and land on the same grid as the piles it runs between. Drawn as
## a line it stayed smooth while everything around it went blocky, which showed.
static func thread_quad(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var across := (b - a).orthogonal().normalized() * (width * 0.5)
	return PackedVector2Array([a - across, b - across, b + across, a + across])


## Which tone a grain wears.
##
## Hashed from the cell's place on the GRID, not from the sand sitting in it.
## That pins the speckle to the glass rather than to the pile, so a draining bulb
## uncovers a texture that was already there instead of one that boils as it
## goes. Every bit of movement the eye picks up then comes from the surface —
## which is the only thing that is actually moving.
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
