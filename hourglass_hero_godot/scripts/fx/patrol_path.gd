## The track a patrolling entity runs along, drawn in the editor only.
##
## Screen space, node-local: the caller's origin is the TOP-LEFT of its `size`,
## so everything here is offset by half of it to sit on the centre.
##
## `addons/level_tools` draws the grab handles over the same track. This part is
## in the entity so every patrol shows up at once, selected or not.
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


## Where the grab handles sit: the entity's centre at each end of the track.
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
