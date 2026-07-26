@tool
## The grab knob at the far end of a patrol track.
##
## The track itself is drawn by the entity (see `PatrolPath`), so every patrol in
## the level is visible at once. This is the knob on the SELECTED one: drag it to
## set `move_distance`.
##
## An entity with no axis yet gets NO knob: at distance zero it would sit in the
## middle of the node, and swallow the click that moves the node. Pick the axis
## in the inspector once and the knob appears.
extends "res://addons/level_tools/gizmo.gd"

const KNOB_RADIUS := 6.0
const COLOUR := Color("ffd166")

var _before_distance := 0.0


func fits(node: Node2D) -> bool:
	return (node is Monster or node is Platform) \
		and node.move_axis != PingPong.Axis.NONE


## Screen positions of the two ends of the track.
func _ends(node: Node2D) -> PackedVector2Array:
	var space := to_screen(node)
	var local := PatrolPath.handles(node.size, node.move_axis, node.move_distance)
	return PackedVector2Array([space * local[0], space * local[1]])


func draw(overlay: Control, node: Node2D) -> void:
	var ends := _ends(node)
	overlay.draw_line(ends[0], ends[1], Color(COLOUR, 0.7), 2.0, true)
	# Hollow at the fixed end, filled at the one that moves.
	overlay.draw_circle(ends[0], KNOB_RADIUS * 0.6, COLOUR, false, 2.0, true)
	overlay.draw_circle(ends[1], KNOB_RADIUS, COLOUR, true, -1.0, true)
	overlay.draw_string(overlay.get_theme_default_font(),
		ends[1] + Vector2(KNOB_RADIUS + 4.0, -KNOB_RADIUS),
		"%d px" % roundi(node.move_distance), HORIZONTAL_ALIGNMENT_LEFT, -1,
		overlay.get_theme_default_font_size(), COLOUR)


func grab(node: Node2D, where: Vector2) -> bool:
	if where.distance_to(_ends(node)[1]) > GRAB_RADIUS:
		return false
	_before_distance = node.move_distance
	return true


## The knob follows the mouse along the node's axis only, so a patrol cannot be
## knocked off its line by a shaky drag.
func drag(node: Node2D, where: Vector2) -> void:
	var centre: Vector2 = node.size * 0.5
	var reach := (to_screen(node).affine_inverse() * where) - centre
	var along: float = reach.x if node.move_axis == PingPong.Axis.X else reach.y
	# Whole px: the levels are placed on whole px and a patrol has no reason not
	# to be. Never negative — `PingPong` only runs a track forwards.
	node.move_distance = clampf(roundf(along), 0.0, 800.0)


func commit(node: Node2D, history: EditorUndoRedoManager) -> void:
	if node.move_distance == _before_distance:
		return
	history.create_action("Set patrol distance")
	history.add_do_property(node, "move_distance", node.move_distance)
	history.add_undo_property(node, "move_distance", _before_distance)
	history.commit_action(false)
