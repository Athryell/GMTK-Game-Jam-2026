@tool
## Resize handles on the four corners and four sides of a solid: a `Platform`'s
## rectangle, or the box a `Terrain`'s ground fits in.
##
## Dragging a side moves THAT side only — the opposite one stays where it is, so
## a floor grows away from the wall it was butted against.
extends "res://addons/level_tools/gizmo.gd"

## Half a handle square's side, in screen px.
const HANDLE := 4.0
## The smallest a box may be dragged to, in world px.
const MIN_SPAN := 4.0
const COLOUR := Color("4cc9f0")

## The eight handles, as the side each one pulls on: -1 low, +1 high, 0 fixed.
## Not a `const` — a `Vector2i(…)` is a constructor call, which a constant cannot
## hold.
static var PULLS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _pull := Vector2i.ZERO
var _start_box := Rect2()
var _start_position := Vector2.ZERO
var _start_points := PackedVector2Array()


func fits(node: Node2D) -> bool:
	return node is Platform or (node is Terrain and node.shape() != null)


## The space the box is measured in: a platform's own, and for a terrain the
## child the points actually live on.
func _space(node: Node2D) -> Transform2D:
	if node is Terrain:
		return to_screen(node) * node.shape().transform
	return to_screen(node)


func _box(node: Node2D) -> Rect2:
	if node is Terrain:
		return Polygons.bounds(node.shape().polygon)
	return Rect2(Vector2.ZERO, node.size)


## Where a handle sits in box space: the middle of the side it pulls on.
static func _anchor(box: Rect2, pull: Vector2i) -> Vector2:
	return box.position + box.size * Vector2(pull.x + 1, pull.y + 1) * 0.5


func draw(overlay: Control, node: Node2D) -> void:
	var space := _space(node)
	var box := _box(node)
	if box.size == Vector2.ZERO:
		return
	var outline := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1),
			Vector2(-1, -1)]:
		outline.append(space * _anchor(box, Vector2i(corner)))
	overlay.draw_polyline(outline, Color(COLOUR, 0.7), 1.0, true)
	for pull in PULLS:
		var at := space * _anchor(box, pull)
		overlay.draw_rect(Rect2(at - Vector2(HANDLE, HANDLE),
			Vector2(HANDLE, HANDLE) * 2.0), COLOUR)
	overlay.draw_string(overlay.get_theme_default_font(),
		space * box.position + Vector2(0.0, -HANDLE - 6.0),
		"%d x %d" % [roundi(box.size.x), roundi(box.size.y)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, overlay.get_theme_default_font_size(), COLOUR)


func grab(node: Node2D, where: Vector2) -> bool:
	var space := _space(node)
	var box := _box(node)
	if box.size == Vector2.ZERO:
		return false
	var closest := GRAB_RADIUS
	_pull = Vector2i.ZERO
	for pull in PULLS:
		var away := where.distance_to(space * _anchor(box, pull))
		if away <= closest:
			closest = away
			_pull = pull
	if _pull == Vector2i.ZERO:
		return false
	_start_box = box
	_start_position = node.position
	_start_points = node.shape().polygon if node is Terrain else PackedVector2Array()
	return true


## Rebuilt from the box the drag STARTED on rather than from the last frame's,
## so a drag that crosses the far side and comes back lands where the mouse is.
func drag(node: Node2D, where: Vector2) -> void:
	var point := _space(node).affine_inverse() * where
	var low := _start_box.position
	var high := _start_box.end
	# Whole px, like everything else placed in these levels.
	if _pull.x < 0:
		low.x = minf(roundf(point.x), high.x - MIN_SPAN)
	elif _pull.x > 0:
		high.x = maxf(roundf(point.x), low.x + MIN_SPAN)
	if _pull.y < 0:
		low.y = minf(roundf(point.y), high.y - MIN_SPAN)
	elif _pull.y > 0:
		high.y = maxf(roundf(point.y), low.y + MIN_SPAN)
	_apply(node, Rect2(low, high - low))


func _apply(node: Node2D, box: Rect2) -> void:
	if node is Terrain:
		node.shape().polygon = Polygons.fit(_start_points, box)
		return
	node.size = box.size
	# The rectangle starts at the node's origin, so moving its top-left IS moving
	# the node. `basis_xform` because the offset is in the node's own space.
	node.position = _start_position \
		+ node.transform.basis_xform(box.position - _start_box.position)


func commit(node: Node2D, history: EditorUndoRedoManager) -> void:
	if _box(node) == _start_box:
		return
	history.create_action("Resize solid")
	if node is Terrain:
		history.add_do_property(node.shape(), "polygon", node.shape().polygon)
		history.add_undo_property(node.shape(), "polygon", _start_points)
	else:
		history.add_do_property(node, "size", node.size)
		history.add_do_property(node, "position", node.position)
		history.add_undo_property(node, "size", _start_box.size)
		history.add_undo_property(node, "position", _start_position)
	history.commit_action(false)
