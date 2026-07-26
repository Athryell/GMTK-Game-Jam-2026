## Plain polygon geometry, shared by the ground that is drawn and the shadow it
## throws.
##
## Screen space throughout: y grows DOWNWARD, so "up" is negative y and a
## clockwise-looking polygon has a positive signed area.
class_name Polygons
extends RefCounted


## +1 when `points` wind clockwise on screen, -1 anticlockwise. Every outward
## normal below is turned by this, which is what makes the winding free.
static func winding(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return 1.0 if area >= 0.0 else -1.0


## The outward unit normal of the edge running from `a` to `b`, or zero for an
## edge too short to have a direction. `wind` comes from `winding()`.
static func edge_normal(a: Vector2, b: Vector2, wind: float) -> Vector2:
	var along := b - a
	if along.length_squared() < 0.0001:
		return Vector2.ZERO
	return Vector2(along.y, -along.x).normalized() * wind


## Does the edge from `a` to `b` face the sky? True for floors and for ramps
## gentle enough to stand on, false for walls and ceilings. The threshold keeps a
## vertical face out, whose normal is horizontal to within rounding.
static func faces_up(a: Vector2, b: Vector2, wind: float) -> bool:
	return edge_normal(a, b, wind).y < -0.2


## The same polygon pushed `amount` px outwards along its own normals. A corner
## belongs to two edges, so it leaves along the sum of theirs — and travels
## further than `amount`, by the miter length `amount / cos(half the corner)`,
## which falls out of that sum's own length.
static func grow(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var count := points.size()
	if count < 3:
		return points
	var wind := winding(points)
	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		var here := points[i]
		var previous := points[(i + count - 1) % count]
		var next := points[(i + 1) % count]
		var away := edge_normal(previous, here, wind) + edge_normal(here, next, wind)
		# A corner folded flat back on itself: the two normals cancel and there is
		# no outwards to go in. Left where it is rather than flung to infinity.
		var spread := away.length_squared()
		out[i] = here if spread < 0.01 else here + away * (2.0 * amount / spread)
	return out
