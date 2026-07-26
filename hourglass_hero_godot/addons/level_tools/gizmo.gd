@tool
## Base for the handles drawn over the 2D viewport: the screen transform they all
## need, and the four calls `plugin.gd` drives them by.
##
## A gizmo owns its own drag state; the plugin only decides which one has the
## mouse. `grab` returning true means "this drag is mine", and the plugin then
## sends every motion to that gizmo until the button comes back up.
extends RefCounted

## Screen px around a handle that still count as a grab.
const GRAB_RADIUS := 10.0


## Whether this gizmo has anything to say about `node`.
func fits(_node: Node2D) -> bool:
	return false


func draw(_overlay: Control, _node: Node2D) -> void:
	pass


func grab(_node: Node2D, _where: Vector2) -> bool:
	return false


func drag(_node: Node2D, _where: Vector2) -> void:
	pass


## Called on release. The drag has already moved the node, so a gizmo only files
## the undo entry for it here.
func commit(_node: Node2D, _history: EditorUndoRedoManager) -> void:
	pass


## Node-local to viewport-overlay space.
static func to_screen(node: Node2D) -> Transform2D:
	return node.get_viewport_transform() * node.get_global_transform()
