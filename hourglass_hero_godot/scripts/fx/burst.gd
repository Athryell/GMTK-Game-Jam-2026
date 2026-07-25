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
	SWEAT, ## Nearly out of sand: a bead shaken off the trembling glass.
}

const GRAVITY := 900.0

var kind: Kind = Kind.RING
var colour := Color.WHITE
var duration := 0.35
var radius := 46.0

var _elapsed := 0.0
var _bits: Array[Vector2] = []
var _velocities: Array[Vector2] = []


## The plane swap. Sized to read at a glance without covering the platform you
## are about to land on.
static func ring(parent: Node, at: Vector2, tint: Color) -> void:
	var b := _make(parent, at, Kind.RING, tint, 0.38)
	b.radius = 58.0


## Landing. `force` is 0 at a gentle touchdown and 1 at terminal velocity, and
## scales both the count and the spread, so a drop looks heavier than a step.
static func dust(parent: Node, at: Vector2, tint: Color, force: float) -> void:
	var b := _make(parent, at, Kind.DUST, tint, 0.42)
	b._scatter(int(4 + 9 * force), 70.0 + 210.0 * force, -0.9, 0.9)


## Death. Thrown wider and lasting longer than dust — this one is meant to be
## looked at, not felt.
static func shards(parent: Node, at: Vector2, tint: Color) -> void:
	var b := _make(parent, at, Kind.SHARDS, tint, 0.9)
	b._scatter(14, 300.0, -PI, PI)


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
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - t
	match kind:
		Kind.RING:
			# Eased out: the ring leaps away from the player and then settles,
			# which reads as an impulse rather than as a growing circle.
			var eased := 1.0 - pow(1.0 - t, 3.0)
			draw_arc(Vector2.ZERO, radius * eased, 0.0, TAU, 48,
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
		Kind.SHARDS:
			for i in _bits.size():
				var size := 3.0 + 4.0 * fade
				draw_rect(Rect2(_bits[i] - Vector2(size, size) / 2.0, Vector2(size, size)),
					Color(colour, fade))
