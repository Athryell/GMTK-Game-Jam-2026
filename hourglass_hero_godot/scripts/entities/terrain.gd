@tool
## A stretch of ground drawn as a polygon: floor, ledge, wall and SLOPE in one
## node. The points live on the child `CollisionPolygon2D`, so selecting it hands
## you Godot's own polygon tool, and this script draws that same polygon.
##
## `Platform` is still the right node for a small rectangle that MOVES, and for
## the flip-pad.
class_name Terrain
extends StaticBody2D

## The rectangle a freshly added Terrain starts as. Not a `const`:
## `PackedVector2Array(…)` is a constructor call, which a constant cannot hold.
static var STARTER := PackedVector2Array([
	Vector2(0.0, 0.0), Vector2(240.0, 0.0), Vector2(240.0, 60.0), Vector2(0.0, 60.0),
])

@export var plane: Planes.Kind = Planes.Kind.BOTH: set = _set_plane

var _shape: CollisionPolygon2D
var _points := PackedVector2Array()
## Vertex indices, three per triangle. Cached because the ground does not move
## and `draw_colored_polygon` only fills a convex shape honestly — terrain is
## almost never convex.
var _triangles := PackedInt32Array()
var _active := true
var _next := false
var _marker := PlaneMarker.new()


func _ready() -> void:
	collision_layer = Layers.SOLID
	collision_mask = 0
	# Ground is measured in hundreds of px and the brick tile in tens, so the UVs
	# run well past 1 and have to wrap.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Set here rather than project-wide: the lights and the sky are gradients, and
	# nearest-filtering those bands them.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if Engine.is_editor_hint():
		_plant_shape()
		_refresh()
		return
	# Polling is an editor affordance only (see `_process`).
	set_process(false)
	_refresh()
	Game.plane_changed.connect(_on_plane_changed)
	Game.next_plane_changed.connect(_on_next_plane_changed)
	Tuning.changed.connect(queue_redraw)
	_on_plane_changed(Game.plane)
	_on_next_plane_changed(Game.next_plane)


## The polygon is edited on the child node, so there is no signal to wait on.
func _process(_delta: float) -> void:
	_refresh()


func _draw() -> void:
	if _points.size() < 3 or _triangles.size() < 3:
		return
	draw_set_transform_matrix(_shape.transform)
	var body := _colour()
	Outline.polygon(self, _points, body.a)
	var i := 0
	while i + 2 < _triangles.size():
		Bricks.polygon(self, PackedVector2Array([
			_points[_triangles[i]],
			_points[_triangles[i + 1]],
			_points[_triangles[i + 2]],
		]), body)
		i += 3

	# Filled inwards from the edge rather than stroked along it: both edges of a
	# fold read the SAME inset vertex, so the joint mitres instead of notching.
	var lip := body.lightened(Bricks.LIP_LIFT)
	var wind := Polygons.winding(_points)
	var inner := Polygons.grow(_points, -Bricks.LIP_WIDTH)
	for j in _points.size():
		var next := (j + 1) % _points.size()
		if Polygons.faces_up(_points[j], _points[next], wind):
			Bricks.polygon(self, PackedVector2Array([
				_points[j], _points[next], inner[next], inner[j]]), lip)

	_marker.draw(self, _points, plane)


func _get_configuration_warnings() -> PackedStringArray:
	if _first_polygon() == null:
		return PackedStringArray([
			"No CollisionPolygon2D child: add one and draw the ground on it."])
	if _first_polygon().polygon.size() < 3:
		return PackedStringArray([
			"The CollisionPolygon2D needs at least three points to be ground."])
	return PackedStringArray()


## The outline this casts a shadow from, in this node's own space. `CastShadows`
## asks once and then follows the node's transform.
func shadow_outline() -> PackedVector2Array:
	if _points.size() < 3:
		return PackedVector2Array()
	var out := PackedVector2Array()
	out.resize(_points.size())
	for i in _points.size():
		out[i] = _shape.transform * _points[i]
	return out


# ----- Size ------------------------------------------------------------------
#
# `size` is the polygon's bounding box, typed rather than dragged. NOT stored:
# the polygon on the child stays the one truth, and this is only read off it and
# written back into it.

const MIN_SIZE := 1.0


func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "size",
		"type": TYPE_VECTOR2,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_EDITOR,
	}]


func _get(property: StringName) -> Variant:
	if property != &"size":
		return null
	return Polygons.bounds(_points).size


func _set(property: StringName, value: Variant) -> bool:
	if property != &"size":
		return false
	_resize(value)
	return true


func _resize(wanted: Vector2) -> void:
	_refresh()
	if _shape == null or _points.size() < 3:
		return
	var scaled := Polygons.resize(_points,
		Vector2(maxf(wanted.x, MIN_SIZE), maxf(wanted.y, MIN_SIZE)))
	if scaled == _points:
		return
	_shape.polygon = scaled
	_refresh()
	# Fetched by name: `EditorInterface` does not exist outside an editor build.
	if Engine.has_singleton("EditorInterface"):
		Engine.get_singleton("EditorInterface").mark_scene_as_unsaved()


# ----- Shape -----------------------------------------------------------------

## The child the ground's points live on. `addons/level_tools` resizes it.
func shape() -> CollisionPolygon2D:
	return _first_polygon()


func _first_polygon() -> CollisionPolygon2D:
	for child in get_children():
		if child is CollisionPolygon2D:
			return child
	return null


## The child is owned by the EDITED SCENE, not by this node: the editor hides
## unowned children, and with them the handles this node exists to expose. That
## is also why `scenes/entities/terrain.tscn` carries no polygon of its own — one
## saved in there would be an instance child, and stay hidden.
func _plant_shape() -> void:
	if _first_polygon() != null or not is_inside_tree():
		return
	var root := get_tree().edited_scene_root
	if root == null or not (self == root or root.is_ancestor_of(self)):
		return
	var shape := CollisionPolygon2D.new()
	shape.name = "Shape"
	shape.polygon = STARTER
	add_child(shape)
	shape.owner = root
	# `_edit_group_` makes the children unselectable in the viewport, so a click
	# drags the ground whole instead of grabbing the polygon under it. Ctrl+G.
	if self != root:
		set_meta(&"_edit_group_", true)


func _refresh() -> void:
	var found := _first_polygon()
	var points := found.polygon if found != null else PackedVector2Array()
	if found == _shape and points == _points:
		return
	_shape = found
	_points = points
	_triangles = Geometry2D.triangulate_polygon(points) if points.size() >= 3 \
		else PackedInt32Array()
	update_configuration_warnings()
	queue_redraw()
	# The points just moved, so the `size` shown in the inspector is stale.
	if Engine.is_editor_hint():
		notify_property_list_changed()


# ----- Plane -----------------------------------------------------------------

func _on_plane_changed(current: Planes.Kind) -> void:
	_active = Planes.is_active(plane, current)
	# Ground in another plane sits on no layer: the player passes through it.
	collision_layer = Layers.SOLID if _active else 0
	_aim_marker()
	queue_redraw()


func _on_next_plane_changed(next: Planes.Kind) -> void:
	_next = plane == next
	_aim_marker()
	queue_redraw()


func _aim_marker() -> void:
	_marker.aim(plane != Planes.Kind.BOTH, _active, _next)


func _colour() -> Color:
	# `next` is deliberately not passed on: the ground says where the jump lands
	# with its dashes, not by looking more solid than it is.
	return Palette.ghost(Palette.bricks(Level.group_of(self)),
		_active or Engine.is_editor_hint())


func _set_plane(value: Planes.Kind) -> void:
	plane = value
	queue_redraw()
