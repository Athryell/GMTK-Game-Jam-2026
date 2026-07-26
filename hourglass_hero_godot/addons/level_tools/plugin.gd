@tool
## Editor-only: makes a patrol track draggable in the 2D viewport.
##
## The track itself is drawn by the entity (see `PatrolPath`), so every patrol in
## the level is visible at once. This adds the grab knob on the SELECTED one:
## drag it to set `move_distance`, and to pick `move_axis` when there is none yet.
extends EditorPlugin

## Screen px around the knob that still count as a grab.
const GRAB_RADIUS := 10.0
## Below this, a drag has no direction yet and cannot choose an axis.
const AXIS_DEADZONE := 6.0
const KNOB_RADIUS := 6.0
const TRACK_COLOUR := Color("ffd166")

var _node: Node2D = null
var _dragging: Node2D = null
var _before_axis := PingPong.Axis.NONE
var _before_distance := 0.0


func _handles(object: Object) -> bool:
	return object is Monster or object is Platform


func _edit(object: Object) -> void:
	_node = object as Node2D
	_dragging = null
	update_overlays()


## Screen positions of the two ends of the selected node's track.
func _ends() -> PackedVector2Array:
	var to_screen := _node.get_viewport_transform() * _node.get_global_transform()
	var local := PatrolPath.handles(_node.size, _node.move_axis, _node.move_distance)
	return PackedVector2Array([to_screen * local[0], to_screen * local[1]])


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _node == null or not is_instance_valid(_node):
		return
	var ends := _ends()
	overlay.draw_line(ends[0], ends[1], Color(TRACK_COLOUR, 0.7), 2.0, true)
	# Hollow at the fixed end, filled at the one that moves.
	overlay.draw_circle(ends[0], KNOB_RADIUS * 0.6, TRACK_COLOUR, false, 2.0, true)
	overlay.draw_circle(ends[1], KNOB_RADIUS, TRACK_COLOUR, true, -1.0, true)
	var font := overlay.get_theme_default_font()
	overlay.draw_string(font, ends[1] + Vector2(KNOB_RADIUS + 4.0, -KNOB_RADIUS),
		"%d px" % roundi(_node.move_distance), HORIZONTAL_ALIGNMENT_LEFT, -1,
		overlay.get_theme_default_font_size(), TRACK_COLOUR)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _node == null or not is_instance_valid(_node):
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			return _grab(event.position)
		if _dragging != null:
			_commit()
			return true
	elif event is InputEventMouseMotion and _dragging != null:
		_drag(event.position)
		return true
	return false


func _grab(where: Vector2) -> bool:
	if where.distance_to(_ends()[1]) > GRAB_RADIUS:
		return false
	_dragging = _node
	_before_axis = _node.move_axis
	_before_distance = _node.move_distance
	return true


## The knob follows the mouse along the node's axis only, so a patrol cannot be
## knocked off its line by a shaky drag. With no axis set yet, the first decisive
## direction picks one.
func _drag(where: Vector2) -> void:
	var to_screen := _dragging.get_viewport_transform() * _dragging.get_global_transform()
	var centre: Vector2 = _dragging.size * 0.5
	var reach := (to_screen.affine_inverse() * where) - centre
	if _dragging.move_axis == PingPong.Axis.NONE:
		if reach.length() < AXIS_DEADZONE:
			return
		_dragging.move_axis = PingPong.Axis.X if absf(reach.x) >= absf(reach.y) \
			else PingPong.Axis.Y
	var along: float = reach.x if _dragging.move_axis == PingPong.Axis.X else reach.y
	# Whole px: the levels are placed on whole px and a patrol has no reason not
	# to be. Never negative — `PingPong` only runs a track forwards.
	_dragging.move_distance = clampf(roundf(along), 0.0, 800.0)
	update_overlays()


## The drag already moved the node, so the do-step is only there for a redo.
func _commit() -> void:
	var node := _dragging
	_dragging = null
	if node.move_axis == _before_axis and node.move_distance == _before_distance:
		return
	var history := get_undo_redo()
	history.create_action("Set patrol track")
	history.add_do_property(node, "move_axis", node.move_axis)
	history.add_do_property(node, "move_distance", node.move_distance)
	history.add_undo_property(node, "move_axis", _before_axis)
	history.add_undo_property(node, "move_distance", _before_distance)
	history.commit_action(false)
