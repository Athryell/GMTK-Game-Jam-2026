## A one-shot particle effect that draws itself for a moment and then frees itself.
## Spawn through the static helpers; they add the node to the tree for you.
class_name Burst
extends Node2D

enum Kind {
	RING, ## Flip: a ring in the plane just landed in.
	DUST, ## Landing chips.
	SHARDS, ## Death: glass fragments, for a glass with no painting of its own.
	PIECES, ## Death: the player's sprite, broken along the pixel grid.
	SAND, ## Death: spilled sand.
	SWEAT, ## Low on sand: a single bead.
}

const GRAVITY := 900.0
## Reach of the plane-swap ring, in px.
const RING_RADIUS := 58.0

## Spin of a glass fragment, in rad/s. Sign randomised per fragment.
const SPIN := 7.0

## Grains spilled by a completely full hourglass.
##
## A grain is one world px, the size it was in the bulb, so the spill only reads
## as sand if there is a MASS of it: a few dozen single pixels scatter into
## nothing before the eye has found them. This is roughly what a full glass holds
## on screen, and it is meant to be — what pours out is what was in there.
const GRAINS_FULL := 170

## How far the spill is thrown, in px/s, and how wide. Deliberately slower than a
## landing's chips: sand that is fired out of the frame in three frames is sand
## nobody sees fall. It wants to lift, hang, and come down inside the pause.
const SPILL_SPEED := 74.0
const SPILL_SPREAD := 1.2

## Gravity on a grain, against [constant GRAVITY] on everything else. Sand is
## small and slow to fall; this is also what keeps the spill on screen for the
## length of the death pause rather than a third of it.
const SPILL_GRAVITY := 620.0

## The last fraction of the spill's life, over which it fades out. Before that the
## sand is at full strength.
const SPILL_FADE := 0.22

## How big a piece of the player's sprite is, in art px a side. The art is 32×64,
## so 8 cuts it into a 4×8 grid — big enough that a piece still reads as a bit of
## the glass rather than as confetti, small enough that a dozen or more fly.
const PIECE_CELL := 8

## How hard the break flashes. The pieces are drawn through this, lerped back to
## plain white — an unlit multiply — over [constant PIECE_FLASH_TIME].
##
## The art is a thin dark outline and two wooden caps against a dark room, and
## broken up it is thinner still. Without a flash the moment of the break has
## nothing loud in it at all, and the first thing the eye finds is already debris.
const PIECE_FLASH := 2.4
const PIECE_FLASH_TIME := 0.16

## One world px, and one art px: the grid the whole game's pixels sit on. Every
## death effect is snapped to it, so a flying piece or grain crosses the screen a
## whole pixel at a time instead of sliding smoothly between two of them.
const PIXEL := 1.0

## How much of its life a piece keeps its pixels at full strength before it starts
## blinking out. Pixel art has no honest way to half-fade, so the pieces flicker
## away on the grid's own terms instead.
const PIECE_SOLID := 0.55

## Blink rate of a piece on its way out, in Hz.
const PIECE_BLINK := 13.0

## How long the broken glass hangs in the air before its pieces fly, in seconds.
##
## Six frames of the sprite standing there in pieces, which is the whole reason
## to break the art rather than a traced outline: for that beat the player still
## sees themselves, cracked — the pieces have shifted a pixel apart along the way
## they are about to go, so the cracks are open and readable. Without it the glass
## is a cloud of debris on the frame it dies and the eye never gets to read what
## came apart.
const PIECE_HOLD := 0.1

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
## PIECES only: the region of the art each piece carries, the size it is drawn at,
## and the fraction of `duration` it survives.
var _regions: Array[Rect2] = []
var _piece_sizes: Array[Vector2] = []
var _lives: Array[float] = []
## PIECES only: whether the art is drawn a half turn round, because the glass was.
var _turned := false
## SAND only: the floor, in this node's own frame. `INF` is no floor at all.
var _floor := INF


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
## Two chambers is the painted glass, and it breaks into pieces of its own art:
## the sprite cut along the pixel grid, each piece keeping the texels that were on
## screen the frame before. Any other count is a rosette the game draws itself,
## with no painting to break, so that one still shatters into traced wedges.
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


## Death, the sand half. `left` is how full the glass was, 0 to 1, and sets the
## grain count. Same `life` constraint as [method shatter].
## `ground` is the world Y the grains come to rest on — the floor the glass was
## standing on. Leave it off and they fall straight through, which is what the
## effect used to do and the reason the spill was over before it was seen: sand
## that lands stays on screen for the rest of the pause, in a heap, and a heap is
## what says the glass emptied.
static func spill(parent: Node, at: Vector2, tint: Color, left: float, life: float,
		ground := INF) -> void:
	var b := _make(parent, at, Kind.SAND, tint, life)
	b._floor = ground - b.global_position.y
	b._scatter(int(round(GRAINS_FULL * clampf(left, 0.0, 1.0))),
		SPILL_SPEED, -SPILL_SPREAD, SPILL_SPREAD)
	# Spread over the body of the glass rather than issued from a single point.
	var rng := RandomNumberGenerator.new()
	for i in b._bits.size():
		b._bits[i] = Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-14.0, 14.0))


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
func _split(outline: PackedVector2Array) -> void:
	var rng := RandomNumberGenerator.new()
	for edge in _segments(outline):
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
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


## Cuts the player's sprite into pieces of [constant PIECE_CELL] art px and throws
## each one from where it stood on the glass.
##
## Nothing is turned by any angle but a half circle. A texture turned off the axis
## has to resample, and the art comes back with its pixels smeared into sizes no
## other pixel on screen has — which is the one thing this effect exists to avoid.
## A half turn is exact, which is why `turned` gets one and the tilt of a glass
## caught mid-flip gets nothing. The tumble the wedges get from spinning, the
## pieces get from their spread instead: each is thrown along the line from the
## throat out through its own centre, so the caps go up, the bulbs go wide, and
## the pieces at the throat get the hardest kick.
func _break_sprite(size: Vector2, turned: bool) -> void:
	_turned = turned
	var rng := RandomNumberGenerator.new()
	for region in HourglassSprite.chunks(PIECE_CELL):
		var piece_size := HourglassSprite.chunk_size(size, region)
		var corner := HourglassSprite.chunk_offset(size, region)
		if turned:
			# The half turn, applied to where the piece starts. The art it carries is
			# turned with it at draw time.
			corner = -corner - piece_size
		var centre := corner + piece_size * 0.5
		var away := centre.normalized() if centre.length() > 0.01 else Vector2.UP

		_regions.append(region)
		_piece_sizes.append(piece_size)
		# Held as the piece's top-left, which is what gets drawn and what gets
		# snapped: snapping a centre would move whole pixels by half of one.
		#
		# Opened by one pixel along the way it is about to go, so the hold shows a
		# glass with cracks in it rather than one that merely stopped. One pixel is
		# the smallest crack this art can have and the largest it can take without
		# the outline coming apart before the piece has moved.
		_bits.append(corner + Vector2(signf(away.x), signf(away.y)) * PIXEL)
		# Lifted as well as thrown outwards, for the same reason the wedges are: a
		# purely radial kick fires the lower half straight into the floor. Slower
		# than the wedges' throw — these are read, not just registered, and a piece
		# that has left the screen by the third frame is not read at all.
		_velocities.append((away * rng.randf_range(52.0, 118.0))
			+ Vector2(0.0, rng.randf_range(-185.0, -85.0)))
		_lives.append(rng.randf_range(0.72, 1.0))


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
	if kind == Kind.PIECES and _elapsed < PIECE_HOLD:
		# Broken but not yet flying — see [constant PIECE_HOLD].
		queue_redraw()
		return
	var pull := SPILL_GRAVITY if kind == Kind.SAND else GRAVITY
	for i in _bits.size():
		# A landed grain is done; nothing moves it again.
		if kind == Kind.SAND and _velocities[i] == Vector2.ZERO:
			continue
		_velocities[i] += Vector2(0.0, pull * delta)
		_bits[i] += _velocities[i] * delta
		# A grain that reaches the floor stops there and stays for the rest of the
		# pause, a pixel or two into a heap rather than all of them on one row. Not
		# a bounce and not sand that settles — three lines, and what they buy is the
		# only part of the spill the eye has time to read: a heap on the ground where
		# the glass was. Everything else has fallen out of frame by then.
		if kind == Kind.SAND and _bits[i].y > _floor:
			_bits[i].y = _floor - (i % 3) * PIXEL
			_velocities[i] = Vector2.ZERO
	for i in _angles.size():
		_angles[i] += _spins[i] * delta
	queue_redraw()


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
			#
			# Held at full strength and dropped at the very end, the way the glass
			# pieces are: sand thinning out over half a second reads as smoke, and a
			# heap on the floor that is already half gone reads as nothing at all.
			var grain := clampf(fade / SPILL_FADE, 0.0, 1.0)
			for p in _bits:
				HourglassShape.draw_grain(self, p, Color(colour, grain), PIXEL)
		Kind.PIECES:
			# The break, lit. A multiply above white, decaying to none: the art keeps
			# its own colours, they are simply blown out for a sixth of a second.
			var glare := lerpf(PIECE_FLASH, 1.0,
				clampf(_elapsed / PIECE_FLASH_TIME, 0.0, 1.0))
			var lit := Color(glare, glare, glare)
			for i in _regions.size():
				var life: float = _lives[i]
				if t >= life:
					continue
				# Solid, then blinking out. No alpha ramp: a piece of pixel art either
				# has its colours or it does not, and a half-transparent one reads as
				# the glass having been smoke all along.
				var own := t / life
				if own > PIECE_SOLID:
					var blink := (own - PIECE_SOLID) / (1.0 - PIECE_SOLID)
					if sin(TAU * PIECE_BLINK * duration * own) < blink * 2.0 - 1.0:
						continue
				var at: Vector2 = _bits[i].snapped(Vector2(PIXEL, PIXEL))
				if _turned:
					# A half turn as a scale of -1 on both axes: exact, so every texel
					# still lands on one whole pixel. `draw_set_transform` with an angle
					# would be the same picture through a resample.
					draw_set_transform(at + _piece_sizes[i], 0.0, Vector2(-1.0, -1.0))
					draw_texture_rect_region(HourglassSprite.TEXTURE,
						Rect2(Vector2.ZERO, _piece_sizes[i]), _regions[i], lit)
				else:
					draw_texture_rect_region(HourglassSprite.TEXTURE,
						Rect2(at, _piece_sizes[i]), _regions[i], lit)
			if _turned:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
