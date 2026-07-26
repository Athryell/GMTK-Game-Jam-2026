## The track a patrolling entity runs along, drawn in the editor only.
##
## Node-local, and the caller's origin is the TOP-LEFT of its `size` — so
## everything here is offset by half of it to sit on the centre.
##
## Drawn by the entity rather than by `addons/level_tools`, which only adds the
## grab knob: this way every patrol in the level shows up at once, unselected.
class_name PatrolPath
extends RefCounted

const LINE_ALPHA := 0.55
const GHOST_ALPHA := 0.3
const DASH := 6.0
const KNOB := 3.0


## The far end of the track, in the entity's own space.
static func travel(axis: PingPong.Axis, distance: float) -> Vector2:
	match axis:
		PingPong.Axis.X:
			return Vector2(distance, 0.0)
		PingPong.Axis.Y:
			return Vector2(0.0, distance)
		_:
			return Vector2.ZERO


## The two ends of the track, where the grab knob sits.
static func handles(size: Vector2, axis: PingPong.Axis,
		distance: float) -> PackedVector2Array:
	var centre := size * 0.5
	return PackedVector2Array([centre, centre + travel(axis, distance)])


static func draw(node: CanvasItem, size: Vector2, axis: PingPong.Axis,
		distance: float, tint: Color) -> void:
	if axis == PingPong.Axis.NONE or distance <= 0.0:
		return
	var ends := handles(size, axis, distance)
	node.draw_dashed_line(ends[0], ends[1],
		Color(tint, LINE_ALPHA), 1.0, DASH, true, true)
	# The pose at the far end, so a patrol's reach reads as the box that kills
	# rather than as a bare line.
	node.draw_rect(Rect2(ends[1] - size * 0.5, size),
		Color(tint, GHOST_ALPHA), false, 1.0)
	for point in ends:
		node.draw_circle(point, KNOB, Color(tint, LINE_ALPHA))
