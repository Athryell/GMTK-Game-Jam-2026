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

## What fraction of the sand's own pixels are thrown when the painted glass
## breaks. The pile is a solid block of them and every one would be several
## hundred rects a frame, so it is sampled — but sampled thinly enough and the
## sand stops leaving the glass and starts puffing out of it. A third reads as the
## pile coming apart while it is still recognisably the pile.
const SPILL_KEEP := 0.34

## How hard the sand is thrown out of the break, in px/s: outwards from the throat
## first, then lifted, so it leaves the glass rather than dropping through it. Well
## under the wedges' own numbers — sand is what the glass was carrying, and it has
## to be seen falling out of the pieces rather than racing them off screen.
const SPILL_OUT := Vector2(50.0, 175.0)
const SPILL_LIFT := Vector2(90.0, 280.0)

## What the sand falls at, against [constant GRAVITY] for everything else. The
## glass is thrown clear and forgotten; the sand has to be followed from the break
## to the floor, and at full weight — most deaths happening a body length above the
## ground — that is over before the eye has found it. Light enough to watch, heavy
## enough that it still reads as falling rather than drifting.
const SPILL_GRAVITY := 520.0

## How much of a wedge's own glass is left under the painting. The art paints the
## frame and leaves the cavity clear, so a piece of pure texture is a piece of
## outline with a hole in it; this is the body it broke off with.
const PIECE_BODY := 0.22

## How strongly the fresh cut down the side of a piece is drawn, against the fade
## the piece is already at. The art paints the glass's own outline; this is the
## edge that was not there a frame ago, and it is what keeps a wedge reading as
## broken glass rather than as a torn-off scrap.
const PIECE_EDGE := 0.5

## One world px, and one art px: the grid the whole game's pixels sit on. Every
## death effect is snapped to it, so a flying piece or grain crosses the screen a
## whole pixel at a time instead of sliding smoothly between two of them.
const PIXEL := 1.0

## Held near-opaque and dropped late, exactly as the wedges are: the pieces are
## the same break, and glass that thins out slowly reads as smoke.
const PIECE_SOLID := 2.2

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
## SAND only: which grains have landed. A landed grain stops dead and stays put
## for the rest of the death, so the spill ends as a heap on the floor.
var _rested: Array[bool] = []


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
## glass, so those wedges are cut OUT of the painting — each carries the texels
## that stood on it a frame ago — instead of being filled with flat glass. Any
## other count is a rosette the game draws itself, with no painting to cut from.
## `turned` is whether the glass was standing on its head when it died, which is
## the one attitude the pieces can honour exactly — see [method _break_sprite].
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
## sand itself. Each bulb's pile is the polygon the glass was drawing a frame ago,
## rasterised on the same grid it was drawn on, so the first frame of the death is
## the player's own sand, standing where it stood, and only then does it come out
## through the break. `fills` is how full each bulb was, `size` the glass it was
## drawn at, and `turned` whether that glass was on its head.
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


## Turns each bulb's pile into flying grains, one per sampled pixel of it.
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
		for cell in _sample(pile, rng):
			var from := cell * facing
			var away := from.normalized() if from.length() > 0.01 else Vector2.UP
			_bits.append(from)
			_velocities.append(away * rng.randf_range(SPILL_OUT.x, SPILL_OUT.y)
				+ Vector2(0.0, -rng.randf_range(SPILL_LIFT.x, SPILL_LIFT.y)))


## Some of the pixel centres inside `poly`, on the [constant PIXEL] grid — the
## same cells [method HourglassShape.fill_grains] would have filled, thinned by
## [constant SPILL_KEEP].
func _sample(poly: PackedVector2Array, rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if poly.size() < 3:
		return out
	var box := Rect2(poly[0], Vector2.ZERO)
	for v in poly:
		box = box.expand(v)
	var row := floori(box.position.y / PIXEL)
	while row <= floori(box.end.y / PIXEL):
		var col := floori(box.position.x / PIXEL)
		while col <= floori(box.end.x / PIXEL):
			var centre := Vector2((col + 0.5) * PIXEL, (row + 0.5) * PIXEL)
			if rng.randf() < SPILL_KEEP and Geometry2D.is_point_in_polygon(centre, poly):
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
		# The death effects are pixel art and are snapped to the grid as they fly.
		# That snap is done in the node's own frame, so the node has to start on the
		# grid too — otherwise every piece lands a fraction of a pixel off it, and
		# the whole point is lost. Safe to move: the player is dead and still.
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
## `facing` of -1 breaks the glass upside down: the outline goes through a half
## turn first, so every wedge is thrown from where it was lying rather than from
## where it would have been the right way up. The lift is added after, in screen
## terms, because the fragments fall down the screen either way.
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
## Two things the flat wedges do have to go. The spin, because a texture turned
## off the axis has to resample, and the art comes back with its pixels smeared
## into sizes no other pixel on screen has — which is the one thing this effect
## exists to avoid. And the sub-pixel start, because a wedge that begins a third
## of a pixel off the grid samples the art a third of a pixel off it for the whole
## flight. Snapped here and snapped again every frame, the two stay a whole number
## of pixels apart, so the texels land square however far the piece has flown.
##
## What is left is a pure slide, which is exact — and the tumble the wedges got
## from spinning, these get from their spread: each is thrown along the line from
## the throat out through its own centre, so the caps go up and the bulbs go wide.
##
## `turned` is the half turn the art was standing at: the glass is broken up in
## that attitude, so the wedges fly the way the picture was lying, and each one
## then reaches BACK through the turn to ask the art what was painted on it.
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
	# Only the sand is stopped by the world. The glass is not: a wedge is thrown
	# clear of the level and gone before it would land, and the same rays spent on
	# it would buy nothing on screen.
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
## A ray over the step rather than a test at the far end: a grain crosses several
## px in a frame, and asking only where it ends up lets it start above a brick and
## end up below it. Returns whether it landed.
func _land(space: PhysicsDirectSpaceState2D, i: int, to: Vector2) -> bool:
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
		global_position + _bits[i], global_position + to, Layers.SOLID))
	if hit.is_empty():
		return false
	# One px back out along the surface's own normal, so the grain sits ON the
	# brick rather than in its first row of pixels.
	_bits[i] = hit.position - global_position + hit.normal * PIXEL
	_velocities[i] = Vector2.ZERO
	_rested[i] = true
	return true


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
			# The same grain, on the same grid, wearing the same speckle as the sand
			# that was in the glass a frame ago: a spilled pile is the pile that was
			# in the bulb, coming apart, and it has to be made of the same pixels to
			# read that way. One cell each, not a 3px blob — a grain in a bulb is one
			# pixel, so a grain in the air is too.
			# No fade at all, where every other effect thins out: sand does not go
			# anywhere once it has landed, and a heap that dissolves on the floor reads
			# as the spill having been a puff of smoke. It goes when the level does.
			for p in _bits:
				HourglassShape.draw_grain(self, p, colour, PIXEL)
		Kind.PIECES:
			# The wedges' own fade, applied to the art instead of to a fill: one alpha
			# over a whole piece leaves every texel where it was, so it costs the pixels
			# nothing and the break still thins out on the curve it always did.
			var strength := clampf(fade * PIECE_SOLID, 0.0, 1.0)
			var glass := Color(1.0, 1.0, 1.0, strength)
			var cut := Color(colour, strength * PIECE_EDGE)
			for i in _pieces.size():
				var at: Vector2 = _bits[i].snapped(Vector2(PIXEL, PIXEL))
				var piece := PackedVector2Array()
				for point in _pieces[i]:
					piece.append(at + point)
				# The wedge's own glass first, then the painting over it: the art is a
				# frame around a clear cavity, so texture alone leaves most of a piece as a
				# hole and the break goes back to reading as a scatter of outlines.
				draw_colored_polygon(piece, Color(colour, strength * PIECE_BODY))
				draw_colored_polygon(piece, glass, _uvs[i], HourglassSprite.TEXTURE)
				piece.append(piece[0])
				# Not antialiased, unlike the flat wedges: a soft line would leave half-lit
				# pixels down every cut, at a size no other pixel in the game comes in.
				draw_polyline(piece, cut, 1.0)
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
