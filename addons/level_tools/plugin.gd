@tool
## Editor-only: the handles a level is built with, drawn over the 2D viewport.
##
## Every gizmo writes the same exported properties the inspector does, so a
## level's numbers stay the one place its shape is stored.
extends EditorPlugin

const PatrolGizmo := preload("res://addons/level_tools/patrol_gizmo.gd")
const BoxGizmo := preload("res://addons/level_tools/box_gizmo.gd")

var _node: Node2D = null
## The patrol knob is drawn last and asked first: it sits over the middle of a
## platform, where a side handle never reaches.
var _gizmos := [PatrolGizmo.new(), BoxGizmo.new()]
var _dragging: RefCounted = null


func _handles(object: Object) -> bool:
	return object is Node2D and not _fitting(object as Node2D).is_empty()


func _edit(object: Object) -> void:
	_node = object as Node2D
	_dragging = null
	update_overlays()


func _fitting(node: Node2D) -> Array:
	return _gizmos.filter(func(gizmo: RefCounted) -> bool: return gizmo.fits(node))


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _node == null or not is_instance_valid(_node):
		return
	var fitting := _fitting(_node)
	fitting.reverse()
	for gizmo in fitting:
		gizmo.draw(overlay, _node)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _node == null or not is_instance_valid(_node):
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			return _grab(event.position)
		if _dragging != null:
			_dragging.commit(_node, get_undo_redo())
			_dragging = null
			update_overlays()
			return true
	elif event is InputEventMouseMotion and _dragging != null:
		_dragging.drag(_node, event.position)
		update_overlays()
		return true
	return false


func _grab(where: Vector2) -> bool:
	for gizmo in _fitting(_node):
		if gizmo.grab(_node, where):
			_dragging = gizmo
			return true
	return false
