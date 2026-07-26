@tool
## A stretch of ground drawn as a polygon: floor, ledge, wall and SLOPE, all in
## one node instead of a staircase of rectangles.
##
## Authoring is Godot's own. The points live on the child `CollisionPolygon2D`,
## so selecting it hands you the built-in polygon tool — drag a handle to move a
## point, ctrl-click an edge to insert one, and the ground redraws as you go. A
## Terrain added from the Create Node dialog plants that child itself, with a
## rectangle to start pulling on.
##
## There is no second copy of the shape to keep in sync, because there is no
## second copy: this script draws the collision polygon. What you can see is
## exactly what you can stand on.
##
## `Platform` is not going anywhere — it is still the right node for a small
## rectangle that MOVES, and for the flip-pad. Terrain is for the ground.
class_name Terrain
extends StaticBody2D

## The rectangle a freshly added Terrain starts as, purely so there is something
## to drag. Not a `const`: `PackedVector2Array(…)` is a constructor call, and a
## constant may only hold an expression the parser can fold.
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
## True while a jump would land the player in this plane: brighter, still inert.
var _next := false


func _ready() -> void:
	# A Terrain collides with nothing; it is the thing others collide with.
	collision_layer = Layers.SOLID
	collision_mask = 0
	# Ground is measured in hundreds of px and the brick tile in tens, so the UVs
	# run well past 1 and have to wrap.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
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


## The polygon is edited on the child node, so there is no signal to wait on:
## the editor writes straight into it. Comparing a handful of points once a
## frame while a level is open costs nothing and keeps the drawing honest.
func _process(_delta: float) -> void:
	_refresh()


func _draw() -> void:
	if _points.size() < 3 or _triangles.size() < 3:
		return
	draw_set_transform_matrix(_shape.transform)
	var body := _colour()
	var i := 0
	while i + 2 < _triangles.size():
		Bricks.polygon(self, PackedVector2Array([
			_points[_triangles[i]],
			_points[_triangles[i + 1]],
			_points[_triangles[i + 2]],
		]), body)
		i += 3

	# A rectangle has one top face; a polygon has as many as it likes, and a ramp
	# is one of them. So the lip follows the geometry rather than the node: every
	# edge the light could land on gets it, and the walls get nothing.
	#
	# Filled inwards from the edge rather than stroked along it. A stroke is
	# centred, so it overhangs the silhouette, and two strokes meeting at a fold
	# leave a notch on the outside of the corner — the joint is mitred here
	# because both edges read the SAME inset vertex.
	var lip := body.lightened(Bricks.LIP_LIFT)
	var wind := Polygons.winding(_points)
	var inner := Polygons.grow(_points, -Bricks.LIP_WIDTH)
	for j in _points.size():
		var next := (j + 1) % _points.size()
		if Polygons.faces_up(_points[j], _points[next], wind):
			Bricks.polygon(self, PackedVector2Array([
				_points[j], _points[next], inner[next], inner[j]]), lip)


func _get_configuration_warnings() -> PackedStringArray:
	if _first_polygon() == null:
		return PackedStringArray([
			"No CollisionPolygon2D child: add one and draw the ground on it."])
	if _first_polygon().polygon.size() < 3:
		return PackedStringArray([
			"The CollisionPolygon2D needs at least three points to be ground."])
	return PackedStringArray()


## The outline this casts a shadow from, in this node's own space. `CastShadows`
## asks every solid for one of these once and then follows the node's transform,
## which is why it is local: a shadow must not be re-measured every frame just
## because its caster slid sideways.
func shadow_outline() -> PackedVector2Array:
	if _points.size() < 3:
		return PackedVector2Array()
	var out := PackedVector2Array()
	out.resize(_points.size())
	for i in _points.size():
		out[i] = _shape.transform * _points[i]
	return out


# ----- Shape -----------------------------------------------------------------

func _first_polygon() -> CollisionPolygon2D:
	for child in get_children():
		if child is CollisionPolygon2D:
			return child
	return null


## A Terrain with no polygon is a Terrain you cannot edit, so a fresh one is
## given a rectangle to start dragging.
##
## The child is owned by the EDITED SCENE, not by this node: an unowned child is
## one the editor hides from the tree, and hiding it would hide the very handles
## this node exists to expose.
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


# ----- Plane -----------------------------------------------------------------

func _on_plane_changed(current: Planes.Kind) -> void:
	_active = Planes.is_active(plane, current)
	# Ground in another plane sits on no layer: the player passes through it.
	collision_layer = Layers.SOLID if _active else 0
	queue_redraw()


func _on_next_plane_changed(next: Planes.Kind) -> void:
	_next = plane == next
	queue_redraw()


func _colour() -> Color:
	var level := 0 if Engine.is_editor_hint() else Game.level_index
	return Palette.ghost(Palette.bricks(level),
		_active or Engine.is_editor_hint(), _next)


func _set_plane(value: Planes.Kind) -> void:
	plane = value
	queue_redraw()
