## A one-shot particle effect that draws itself for a moment and then frees itself.
## Spawn through the static helpers; they add the node to the tree for you.
class_name Burst
extends Node2D

enum Kind {
	RING, ## Flip: a ring in the plane just landed in.
	DUST, ## Landing chips.
	SHARDS, ## Death: glass fragments.
	SAND, ## Death: spilled sand.
	SWEAT, ## Low on sand: a single bead.
}

const GRAVITY := 900.0
## Reach of the plane-swap ring, in px.
const RING_RADIUS := 58.0

## Spin of a glass fragment, in rad/s. Sign randomised per fragment.
const SPIN := 7.0

## Grains spilled by a completely full hourglass.
const GRAINS_FULL := 46

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


## The plane swap.
static func ring(parent: Node, at: Vector2, tint: Color) -> void:
	_make(parent, at, Kind.RING, tint, 0.38)


## Landing. `force` is 0 at a gentle touchdown and 1 at terminal velocity; it
## scales both the count and the spread.
static func dust(parent: Node, at: Vector2, tint: Color, force: float) -> void:
	var b := _make(parent, at, Kind.DUST, tint, 0.42)
	b._scatter(int(4 + 9 * force), 70.0 + 210.0 * force, -0.9, 0.9)


## Death, the glass half: the hourglass breaks into wedges fanning out from its
## centre. `life` must not exceed the death-screen pause — the level, and every
## effect in it, is freed when that pause ends.
static func shatter(parent: Node, at: Vector2, size: Vector2, tint: Color, life: float) -> void:
	var b := _make(parent, at, Kind.SHARDS, tint, life)
	# The glass the player was actually holding, not a two-bulb stand-in: a
	# three-lobed level must shatter into a three-lobed outline.
	b._split(HourglassShape.shell(size, Game.chamber_count))


## Death, the sand half. `left` is how full the glass was, 0 to 1, and sets the
## grain count. Same `life` constraint as [method shatter].
static func spill(parent: Node, at: Vector2, tint: Color, left: float, life: float) -> void:
	var b := _make(parent, at, Kind.SAND, tint, life)
	b._scatter(int(round(GRAINS_FULL * clampf(left, 0.0, 1.0))), 120.0, -1.3, 1.3)
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
	for i in _bits.size():
		_velocities[i] += Vector2(0.0, GRAVITY * delta)
		_bits[i] += _velocities[i] * delta
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
			for p in _bits:
				draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3.0, 3.0)),
					Color(colour, fade * 0.95))
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
