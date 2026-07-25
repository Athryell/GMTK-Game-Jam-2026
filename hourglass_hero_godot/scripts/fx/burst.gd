## A one-shot effect that draws itself for a moment and then removes itself.
##
## Three shapes, one node. They are the same code because they are the same
## thing — a short clock, a fade, and a `_draw()` — and three near-identical
## scenes would drift apart the first time one of them was tweaked.
##
## Spawn through the static helpers; they add the node to the tree for you, so a
## caller can fire an effect on one line and never hold a reference to it.
class_name Burst
extends Node2D

enum Kind {
	RING, ## The flip: a ring in the plane you just landed in.
	DUST, ## Landing: chips kicked along the floor.
	SHARDS, ## Death: the glass comes apart.
	SAND, ## Death: what was inside it, spilling.
	SWEAT, ## Nearly out of sand: a bead shaken off the trembling glass.
}

const GRAVITY := 900.0
## How far the plane-swap ring reaches, in px. Sized to read at a glance without
## covering the platform you are about to land on.
const RING_RADIUS := 58.0

## Spin given to a glass fragment, in rad/s. Randomised in sign per fragment.
## Glass tumbles and sand does not — that difference is most of what tells the
## two apart once they are both in the air.
const SPIN := 7.0

## Grains a completely full hourglass spills. Sand is the one thing on screen
## that is allowed to be numerous: a dozen grains reads as crumbs, and the point
## is that your remaining time is now on the floor.
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


## Landing. `force` is 0 at a gentle touchdown and 1 at terminal velocity, and
## scales both the count and the spread, so a drop looks heavier than a step.
static func dust(parent: Node, at: Vector2, tint: Color, force: float) -> void:
	var b := _make(parent, at, Kind.DUST, tint, 0.42)
	b._scatter(int(4 + 9 * force), 70.0 + 210.0 * force, -0.9, 0.9)


## Death, the glass half: the hourglass comes apart into the wedges it was made
## of. They fan out from the centre, so for the first frame or two they still
## spell out the shape that was standing there — the break is legible only
## because the pieces start assembled.
##
## `life` should be the pause the game actually holds on the death screen. The
## level is freed when that pause ends, and every effect in it with it, so an
## animation longer than the pause is an animation with its end cut off.
static func shatter(parent: Node, at: Vector2, size: Vector2, tint: Color, life: float) -> void:
	var b := _make(parent, at, Kind.SHARDS, tint, life)
	b._split(HourglassShape.silhouette(size))


## Death, the sand half. `left` is how full the glass was, 0 to 1: dying with a
## full hourglass should cost visibly more than dying on the last grain.
##
## Sand falls where glass is thrown. It gets almost no outward speed and no
## spin, which is what stops the two halves of the death from reading as one
## grey puff.
static func spill(parent: Node, at: Vector2, tint: Color, left: float, life: float) -> void:
	var b := _make(parent, at, Kind.SAND, tint, life)
	b._scatter(int(round(GRAINS_FULL * clampf(left, 0.0, 1.0))), 120.0, -1.3, 1.3)
	# Spread over the body of the glass rather than issued from a single point:
	# sand was filling a volume, and a spill that starts as a dot reads as a
	# firework instead.
	var rng := RandomNumberGenerator.new()
	for i in b._bits.size():
		b._bits[i] = Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-14.0, 14.0))


## Nerves. A single bead, flicked off the shaking glass and then simply dropped.
##
## One at a time rather than a puff, because sweat is not an event — it is a
## state the player is in, and it has to be able to keep going for as long as
## they are in it without ever becoming the loudest thing on screen.
static func sweat(parent: Node, at: Vector2, tint: Color) -> void:
	var b := _make(parent, at, Kind.SWEAT, tint, 0.55)
	# Barely thrown: it should look shaken loose, not spat out.
	b._scatter(1, 105.0, -0.7, 0.7)


static func _make(parent: Node, at: Vector2, kind_: Kind, tint: Color, life: float) -> Burst:
	var b := Burst.new()
	b.kind = kind_
	b.colour = tint
	b.duration = life
	b.global_position = at
	# Above every solid: an effect that plays behind the floor it was kicked off
	# is an effect nobody sees.
	b.z_index = 20
	parent.add_child(b)
	return b


## The outline's edges, with the long ones cut down so no fragment ends up
## several times the size of its neighbours.
##
## One wedge per edge, taken literally, gives an hourglass two fragments the
## size of a bulb and six splinters — and once the big two have tumbled away
## there is visibly nothing left to break. Chopping to a maximum length spreads
## the mass out without needing to know which edge is which.
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


## Cuts `outline` into one wedge per edge, each running from the centre of the
## glass out to that edge, and throws every wedge along its own outward
## direction. Fanning from the centre rather than dicing the shape into a grid
## is what makes the break look like a break: the pieces separate along the
## lines the object was already built from.
##
## Each polygon is stored relative to its own centroid, and the centroid is what
## moves. A fragment spun about a shared origin orbits instead of tumbling.
func _split(outline: PackedVector2Array) -> void:
	var rng := RandomNumberGenerator.new()
	for edge in _segments(outline):
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var centre := (a + b) / 3.0
		# The throat wedges sit almost on the origin and have no outward
		# direction to speak of; send those out along the edge's own midpoint.
		var away := centre if centre.length() > 0.5 else (a + b) / 2.0
		away = away.normalized() if away.length() > 0.01 else Vector2.UP

		_pieces.append(PackedVector2Array([-centre, a - centre, b - centre]))
		_bits.append(centre)
		# Lifted as well as thrown outwards: with a purely radial kick the lower
		# wedges are fired straight into the floor and vanish on frame one.
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
			# Eased out: the ring leaps away from the player and then settles,
			# which reads as an impulse rather than as a growing circle.
			var eased := 1.0 - pow(1.0 - t, 3.0)
			draw_arc(Vector2.ZERO, RING_RADIUS * eased, 0.0, TAU, 48,
				Color(colour, fade * 0.85), 3.0 * fade + 1.0, true)
		Kind.DUST:
			for p in _bits:
				draw_rect(Rect2(p - Vector2(2.0, 2.0), Vector2(4.0, 4.0)),
					Color(colour, fade * 0.8))
		Kind.SWEAT:
			# Round, where every other effect in the game is square. That is the
			# whole read: a bead is a liquid, and the world it comes off is not.
			for p in _bits:
				draw_circle(p, 1.4 + 1.4 * fade, Color(colour, fade * 0.9))
		Kind.SAND:
			# Small and square, like the dust: sand is the same material the
			# world is made of, so it has no business looking special.
			for p in _bits:
				draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3.0, 3.0)),
					Color(colour, fade * 0.95))
		Kind.SHARDS:
			# Held near-opaque and dropped late. Glass that starts fading on the
			# first frame never reads as glass — it reads as smoke.
			var solid := clampf(fade * 2.2, 0.0, 1.0)
			for i in _pieces.size():
				var piece := PackedVector2Array()
				for point in _pieces[i]:
					piece.append(_bits[i] + point.rotated(_angles[i]))
				draw_colored_polygon(piece, Color(colour, solid * 0.22))
				# Outlined, not just filled: the edge is the only part of a pane
				# of glass you actually see, and it is what catches the light.
				piece.append(piece[0])
				draw_polyline(piece, Color(colour, solid), 1.4, true)
