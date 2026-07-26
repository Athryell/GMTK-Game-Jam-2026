## A one-shot particle effect that draws itself for a moment and then frees itself.
## Spawn through the static helpers; they add the node to the tree for you.
class_name Burst
extends Node2D

enum Kind {
	RING, ## Flip: a ring in the plane just landed in.
	DUST, ## Landing chips.
	SHARDS, ## Death: glass fragments, for a glass with no painting of its own.
	PIECES, ## Death: the same fragments, wearing the painted glass's own texels.
	SAND, ## Death: spilled sand.
	SWEAT, ## Low on sand: a single bead.
}

const GRAVITY := 900.0
## Reach of the plane-swap ring, in px.
const RING_RADIUS := 58.0

## Spin of a glass fragment, in rad/s. Sign randomised per fragment.
const SPIN := 7.0

## Grains spilled by a glass with no painting of its own, at completely full.
const GRAINS_FULL := 46

## How hard the sand is thrown out of the break, in px/s: outwards from the throat
## first, then lifted, so it leaves the glass rather than dropping through it.
## Sized against [constant SPILL_GRAVITY] — the slower the fall, the longer these
## carry — so the sand is back on the floor before the death screen ends.
const SPILL_OUT := Vector2(20.0, 70.0)
const SPILL_LIFT := Vector2(10.0, 60.0)

## What the sand falls at, against [constant GRAVITY] for everything else. A
## seventh of it: the glass is thrown clear and forgotten, while the sand has to be
## watched leaving the break.
const SPILL_GRAVITY := 120.0

## One world px, and one art px. Every death effect is snapped to it, so a flying
## piece crosses the screen a whole pixel at a time.
const PIXEL := 1.0

## How big a spilled grain is, in px a side. Bigger than the one-px cells the sand
## is drawn with in the glass, deliberately: packed edge to edge one px reads as
## texture, alone against the sky it reads as dust.
const SPILL_GRAIN := 2.0

## Runaway guard on [method _settle], in cells: taller than any heap a glass this
## size can pour.
const HEAP_STACK := 24

## How much faster than the death itself a piece fades: full strength for the first
## two thirds, so the painting is up long enough to be read.
const PIECE_SOLID := 3.0

var kind: Kind = Kind.RING
var colour := Color.WHITE
var duration := 0.35

var _elapsed := 0.0
var _bits: Array[Vector2] = []
var _velocities: Array[Vector2] = []
## SHARDS only: the polygon each fragment is, and the angle it has turned to.
var _pieces: Array[PackedVector2Array] = []
var _angles: Array[float] = []
var _spins: Array[float] = []
## PIECES only: where on the art each corner of each fragment came from, in the
## texture's own pixels — the wedge cut out of the painting rather than filled in.
var _uvs: Array[PackedVector2Array] = []
## SAND only: which grains have landed. A landed grain stops dead and stays put,
## so the spill ends as a heap on the floor.
var _rested: Array[bool] = []
## SAND only: the grid cells landed grains occupy, in this node's own frame, so the
## next one lands ON them rather than inside them. Used as a set.
var _heap: Dictionary = {}


## The plane swap.
static func ring(parent: Node, at: Vector2, tint: Color) -> void:
	_make(parent, at, Kind.RING, tint, 0.38)


## Landing. `force` is 0 at a gentle touchdown and 1 at terminal velocity; it
## scales both the count and the spread.
static func dust(parent: Node, at: Vector2, tint: Color, force: float) -> void:
	var b := _make(parent, at, Kind.DUST, tint, 0.42)
	b._scatter(int(4 + 9 * force), 70.0 + 210.0 * force, -0.9, 0.9)


## Death, the glass half: the hourglass comes apart and its bits fan out from its
## centre. `life` must not exceed the death-screen pause — the level, and every
## effect in it, is freed when that pause ends.
##
## Every count breaks into the same traced wedges. Two chambers is the painted
## glass, so those wedges are cut OUT of the painting; any other count is a rosette
## the game draws itself, with nothing to cut from. `turned` is whether the glass
## died on its head — see [method _break_sprite].
static func shatter(parent: Node, at: Vector2, size: Vector2, tint: Color, life: float,
		turned := false) -> void:
	if Game.chamber_count == 2:
		var p := _make(parent, at, Kind.PIECES, tint, life)
		p._break_sprite(size, turned)
		return
	var b := _make(parent, at, Kind.SHARDS, tint, life)
	# The glass the player was actually holding, not a two-bulb stand-in: a
	# three-lobed level must shatter into a three-lobed outline.
	b._split(HourglassShape.shell(size, Game.chamber_count))


## Death, the sand half: what the glass was carrying, leaving it.
##
## The grains are not scattered from the middle of the player — they START as the
## sand itself: each bulb's pile, rasterised on the grid it was drawn on, so the
## first frame of the death is the player's own sand standing where it stood.
## `fills` is how full each bulb was and `size` the glass it was drawn at.
##
## A glass with no painting has no bulbs to empty, so it keeps the plain scatter.
## Same `life` constraint as [method shatter].
static func spill(parent: Node, at: Vector2, tint: Color, fills: PackedFloat32Array,
		size: Vector2, life: float, turned := false) -> void:
	var b := _make(parent, at, Kind.SAND, tint, life)
	if Game.chamber_count != 2 or fills.size() < 2:
		# How full the whole glass was, 0 to 1: each chamber reads against its own
		# capacity and the glass holds `count / 2` of those.
		var left := 0.0
		for fill in fills:
			left += fill
		left /= maxf(fills.size() / 2.0, 1.0)
		b._scatter(int(round(GRAINS_FULL * clampf(left, 0.0, 1.0))), 120.0, -1.3, 1.3)
		var rng := RandomNumberGenerator.new()
		for i in b._bits.size():
			b._bits[i] = Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-14.0, 14.0))
		b._rested.resize(b._bits.size())
		return
	b._empty(fills, size, -1.0 if turned else 1.0)
	b._rested.resize(b._bits.size())


## Turns each bulb's pile into flying grains, one per cell of it.
func _empty(fills: PackedFloat32Array, size: Vector2, facing: float) -> void:
	var rng := RandomNumberGenerator.new()
	# The bulb's capacity at this drawing size, exactly as the sprite works it out —
	# a fill of 1 has to come out as the pile that filled the bulb on screen.
	var capacity := HourglassSprite.BULB_AREA \
		* (size.x / HourglassSprite.TRIM.size.x) * (size.y / HourglassSprite.TRIM.size.y)
	for i in 2:
		if fills[i] <= 0.001:
			continue
		# Pass `Vector2.DOWN` and no inversion: the sand is at rest in the glass's own
		# frame the instant it dies, whichever way up that frame is. `facing` carries
		# the half turn afterwards, so it lands on the grains and the wedges alike.
		var pile := HourglassShape.pile(HourglassSprite.bulb(size, i), Vector2.DOWN,
			clampf(fills[i], 0.0, 1.0) * capacity)
		for cell in _sample(pile):
			var from := cell * facing
			var away := from.normalized() if from.length() > 0.01 else Vector2.UP
			_bits.append(from)
			_velocities.append(away * rng.randf_range(SPILL_OUT.x, SPILL_OUT.y)
				+ Vector2(0.0, -rng.randf_range(SPILL_LIFT.x, SPILL_LIFT.y)))


## Every cell centre inside `poly`, on the [constant SPILL_GRAIN] grid — and all of
## them: sampling a third was cheaper, but a visibly full glass then poured out a
## handful.
func _sample(poly: PackedVector2Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if poly.size() < 3:
		return out
	var box := Rect2(poly[0], Vector2.ZERO)
	for v in poly:
		box = box.expand(v)
	var row := floori(box.position.y / SPILL_GRAIN)
	while row <= floori(box.end.y / SPILL_GRAIN):
		var col := floori(box.position.x / SPILL_GRAIN)
		while col <= floori(box.end.x / SPILL_GRAIN):
			var centre := Vector2((col + 0.5) * SPILL_GRAIN, (row + 0.5) * SPILL_GRAIN)
			if Geometry2D.is_point_in_polygon(centre, poly):
				out.append(centre)
			col += 1
		row += 1
	return out


## Nerves: a single bead flicked off the shaking glass. Called repeatedly while
## the player is low on sand, so it stays deliberately quiet.
static func sweat(parent: Node, at: Vector2, tint: Color) -> void:
	var b := _make(parent, at, Kind.SWEAT, tint, 0.55)
	b._scatter(1, 105.0, -0.7, 0.7)


static func _make(parent: Node, at: Vector2, kind_: Kind, tint: Color, life: float) -> Burst:
	var b := Burst.new()
	b.kind = kind_
	b.colour = tint
	b.duration = life
	b.global_position = at
	# Above every solid, so effects are not hidden behind terrain.
	b.z_index = 20
	if kind_ == Kind.PIECES or kind_ == Kind.SAND:
		# The pieces snap to the grid in the node's own frame, so the node has to start
		# on it too. Safe to move: the player is dead and still.
		b.global_position = b.global_position.snapped(Vector2(PIXEL, PIXEL))
		# The art's own texels, at the size every other pixel in the game is.
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(b)
	return b


## The outline's edges, with long ones chopped to a maximum length so no
## fragment ends up several times the size of its neighbours.
func _segments(outline: PackedVector2Array) -> Array[Array]:
	var longest := 0.0
	for i in outline.size():
		longest = maxf(longest, outline[i].distance_to(outline[(i + 1) % outline.size()]))
	var limit := maxf(longest * 0.55, 1.0)

	var out: Array[Array] = []
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var cuts := maxi(1, int(ceil(a.distance_to(b) / limit)))
		for c in cuts:
			out.append([a.lerp(b, float(c) / cuts), a.lerp(b, float(c + 1) / cuts)])
	return out


## Cuts `outline` into one wedge per segment, each running from the centre out
## to that segment, and throws it outwards. Polygons are stored relative to
## their own centroid, which is what moves — spinning about a shared origin
## would make fragments orbit instead of tumble.
##
## `facing` of -1 breaks the glass upside down: the outline turns first, so a wedge
## is thrown from where it was lying. The lift is added after, in screen terms,
## because fragments fall down the screen either way.
func _split(outline: PackedVector2Array, facing := 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	for edge in _segments(outline):
		var a: Vector2 = edge[0] * facing
		var b: Vector2 = edge[1] * facing
		var centre := (a + b) / 3.0
		# Throat wedges sit almost on the origin and have no outward direction;
		# send those out along the edge's own midpoint.
		var away := centre if centre.length() > 0.5 else (a + b) / 2.0
		away = away.normalized() if away.length() > 0.01 else Vector2.UP

		_pieces.append(PackedVector2Array([-centre, a - centre, b - centre]))
		_bits.append(centre)
		# Lifted as well as thrown outwards: a purely radial kick fires the lower
		# wedges straight into the floor.
		_velocities.append((away * rng.randf_range(90.0, 190.0))
			+ Vector2(0.0, rng.randf_range(-260.0, -120.0)))
		_angles.append(0.0)
		_spins.append(SPIN * rng.randf_range(0.4, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0))


## The wedges of [method _split], cut out of the painted glass rather than filled
## with it: each keeps the texels that stood where it did a frame ago.
##
## Two things the flat wedges have must go. The spin, because a texture turned off
## the axis resamples, and its pixels come back in sizes no other pixel on screen has.
## And the sub-pixel start, because a wedge beginning a third of a pixel off the
## grid samples the art a third of a pixel off it for the whole flight. What is left
## is a pure slide, and the tumble comes from the spread instead.
##
## The glass is broken up at the half turn `turned` says it was standing at, and
## each wedge then reaches BACK through that turn to ask the art what it wore.
func _break_sprite(size: Vector2, turned: bool) -> void:
	var facing := -1.0 if turned else 1.0
	_split(HourglassShape.shell(size, 2), facing)
	for i in _pieces.size():
		_spins[i] = 0.0
		_bits[i] = _bits[i].snapped(Vector2(PIXEL, PIXEL))
		var uv := PackedVector2Array()
		for point in _pieces[i]:
			uv.append(_texel((_bits[i] + point) * facing, size))
		_uvs.append(uv)


## Where a point in the glass's own frame sits on the art, in texture px. The
## sprite is drawn one art px to one world px, so this is a shift and nothing
## else — no scale to round off, and no texel landing between two pixels.
func _texel(local: Vector2, size: Vector2) -> Vector2:
	var art := HourglassSprite.TRIM.position \
		+ (local + size * 0.5) / size * HourglassSprite.TRIM.size
	# Over the whole sheet, not the trim: polygon UVs are read 0 to 1 across the
	# texture, where every other call in the game names a rect in texture px.
	return art / HourglassSprite.TEXTURE.get_size()


func _scatter(count: int, speed: float, from_angle: float, to_angle: float) -> void:
	var rng := RandomNumberGenerator.new()
	for i in count:
		# Measured from straight up, so the default arc throws bits skyward.
		var a := -PI / 2.0 + rng.randf_range(from_angle, to_angle)
		var s := speed * rng.randf_range(0.45, 1.0)
		_bits.append(Vector2.ZERO)
		_velocities.append(Vector2(cos(a), sin(a)) * s)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	# Only the sand is stopped by the world: a wedge is thrown clear of the level and
	# gone before it would land.
	var space: PhysicsDirectSpaceState2D = null
	if kind == Kind.SAND and _rested.size() == _bits.size():
		space = get_world_2d().direct_space_state
	for i in _bits.size():
		if space != null and _rested[i]:
			continue
		_velocities[i] += Vector2(0.0, (SPILL_GRAVITY if kind == Kind.SAND else GRAVITY) * delta)
		var to: Vector2 = _bits[i] + _velocities[i] * delta
		if space != null and _land(space, i, to):
			continue
		_bits[i] = to
	for i in _angles.size():
		_angles[i] += _spins[i] * delta
	queue_redraw()


## Casts grain `i` along the step it is about to take and, if the terrain is in
## the way, lays it down against what it hit and takes it out of the simulation.
##
## A ray over the step rather than a test at the far end: a grain crosses several px
## in a frame, and asking only where it ends up lets it tunnel through a brick.
## Returns whether it landed.
func _land(space: PhysicsDirectSpaceState2D, i: int, to: Vector2) -> bool:
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
		global_position + _bits[i], global_position + to, Layers.SOLID))
	if hit.is_empty():
		return false
	# One grain back out along the surface's own normal, so it sits ON the brick.
	var at: Vector2 = hit.position - global_position + hit.normal * SPILL_GRAIN
	var cell := Vector2i(floori(at.x / SPILL_GRAIN), floori(at.y / SPILL_GRAIN))
	cell = _settle(cell)
	_heap[cell] = true
	# The centre, because that is what [method HourglassShape.draw_grain] reads back
	# down to a cell.
	_bits[i] = (Vector2(cell) + Vector2(0.5, 0.5)) * SPILL_GRAIN
	_velocities[i] = Vector2.ZERO
	_rested[i] = true
	return true


## Where a grain that has just hit the terrain at `cell` actually comes to rest: the
## bricks stop it, but the grains already down there stop it sooner.
##
## Rolls off the shoulder before it stacks, so a column slumps into a mound rather
## than growing into a tower, and only onto something that will hold it — the floor
## row it landed on, or another grain.
func _settle(cell: Vector2i) -> Vector2i:
	const DOWN := Vector2i(0, 1)
	var floor_row := cell.y
	var climbed := 0
	while _heap.has(cell) and climbed < HEAP_STACK:
		var side := Vector2i(1 if randf() < 0.5 else -1, 0)
		if not _heap.has(cell + side) \
				and (cell.y == floor_row or _heap.has(cell + side + DOWN)):
			cell += side
		else:
			cell -= DOWN
		climbed += 1
	return cell


func _draw() -> void:
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - t
	match kind:
		Kind.RING:
			var eased := 1.0 - pow(1.0 - t, 3.0)
			draw_arc(Vector2.ZERO, RING_RADIUS * eased, 0.0, TAU, 48,
				Color(colour, fade * 0.85), 3.0 * fade + 1.0, true)
		Kind.DUST:
			for p in _bits:
				draw_rect(Rect2(p - Vector2(2.0, 2.0), Vector2(4.0, 4.0)),
					Color(colour, fade * 0.8))
		Kind.SWEAT:
			# Round, where every other effect is square: it reads as a liquid.
			for p in _bits:
				draw_circle(p, 1.4 + 1.4 * fade, Color(colour, fade * 0.9))
		Kind.SAND:
			# The same speckle as the sand in the glass a frame ago: a spilled pile is that
			# pile coming apart, and has to be made of the same kind of pixel to read so.
			# No fade at all, where every other effect thins out — a heap that dissolves on
			# the floor reads as the spill having been smoke. It goes when the level does.
			for p in _bits:
				HourglassShape.draw_grain(self, p, colour, SPILL_GRAIN)
		Kind.PIECES:
			# One alpha over a whole piece leaves every texel where it was, so the break
			# thins out on the curve it always did and the pixels pay nothing.
			var strength := clampf(fade * PIECE_SOLID, 0.0, 1.0)
			var glass := Color(1.0, 1.0, 1.0, strength)
			for i in _pieces.size():
				var at: Vector2 = _bits[i].snapped(Vector2(PIXEL, PIXEL))
				var piece := PackedVector2Array()
				for point in _pieces[i]:
					piece.append(at + point)
				# Nothing under the painting and nothing round it: a piece wears the art's
				# own texels and no more, so the wedge it was cut as never shows.
				draw_colored_polygon(piece, glass, _uvs[i], HourglassSprite.TEXTURE)
		Kind.SHARDS:
			# Held near-opaque and dropped late, so glass does not read as smoke.
			var solid := clampf(fade * 2.2, 0.0, 1.0)
			for i in _pieces.size():
				var piece := PackedVector2Array()
				for point in _pieces[i]:
					piece.append(_bits[i] + point.rotated(_angles[i]))
				draw_colored_polygon(piece, Color(colour, solid * 0.22))
				piece.append(piece[0])
				draw_polyline(piece, Color(colour, solid), 1.4, true)
