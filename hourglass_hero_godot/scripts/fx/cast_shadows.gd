## The terrain's shadows, drawn by hand: each solid is stamped again, pushed away
## from the lamp. Replaces Godot's 2D shadow map, which bands badly here because
## the player's lamp sits on the surfaces it lights.
##
## Casters are `Platform` and `Terrain` alike. Each is asked once for its outline
## in its own space; from then on this follows the node's transform, so a moving
## platform costs no more than a still one and a ramp throws a ramp-shaped
## shadow.
##
## Must sit BETWEEN the backdrop and the level in `main.tscn` — a solid covering
## its own stamp is what keeps a shadow off the thing that cast it.
class_name CastShadows
extends Node2D

## Stacked copies per shadow, each pushed further and carrying 1/LAYERS of the
## darkness: a penumbra without a blur or a shader.
const LAYERS := 4

## How much wider than its caster a shadow is drawn, in px.
const SPREAD := 2.0

var lamp: Node2D
var _casters: Array[Node2D] = []
## Per caster, parallel to `_casters`.
var _outlines: Array[PackedVector2Array] = []
var _triangles: Array[PackedInt32Array] = []
var _planes: Array[Planes.Kind] = []
var _reach := 1.0


## Called on every level load. Shapes and planes are measured once — neither
## changes while a level runs — and only the transform is read per frame, since
## platforms move.
func configure(level: Level) -> void:
	_casters.clear()
	_outlines.clear()
	_triangles.clear()
	_planes.clear()
	for node in level.find_children("*", "Platform", true, false):
		var slab := node as Platform
		_add(slab, slab.plane, slab.shadow_outline())
	for node in level.find_children("*", "Terrain", true, false):
		var ground := node as Terrain
		_add(ground, ground.plane, ground.shadow_outline())


func _add(caster: Node2D, plane: Planes.Kind, outline: PackedVector2Array) -> void:
	var grown := Polygons.grow(outline, SPREAD)
	if grown.size() < 3:
		return
	_casters.append(caster)
	_outlines.append(grown)
	# Indices, not points: a caster only ever moves, and translating a polygon
	# never re-triangulates it. So this is computed once and re-used every frame.
	_triangles.append(Geometry2D.triangulate_polygon(grown))
	_planes.append(plane)


func _process(_delta: float) -> void:
	# The lamp is the player's, so its reach is the player light's. Read every
	# frame rather than cached: it is live on the tuning panel.
	_reach = maxf(Tuning.cfg.player_light_radius, 1.0)
	queue_redraw()


func _draw() -> void:
	if lamp == null or not is_instance_valid(lamp):
		return
	var cfg := Tuning.cfg
	var origin := to_local(lamp.global_position)
	var into_mine := global_transform.affine_inverse()

	for index in _casters.size():
		var caster := _casters[index]
		if not is_instance_valid(caster):
			continue
		# A solid in the other plane is walk-through, so it casts nothing.
		if not Planes.is_active(_planes[index], Game.plane):
			continue

		var outline := _outlines[index]
		var to_here := into_mine * caster.global_transform
		var points := PackedVector2Array()
		points.resize(outline.size())
		var centre := Vector2.ZERO
		for i in outline.size():
			points[i] = to_here * outline[i]
			centre += points[i]
		centre /= float(points.size())

		var away := centre - origin
		var distance := away.length()
		# Past the edge of the light, or the lamp is inside the solid and there
		# is no "away" to push towards.
		if distance >= _reach or distance < 0.001:
			continue

		# Throw and darkness both fall off towards the rim of the light; the
		# darkness is squared so shadows fade out before they shrink away.
		var closeness := 1.0 - distance / _reach
		var throw := away / distance * cfg.shadow_throw * closeness
		var shade := Color(0.0, 0.0, 0.02, cfg.shadow_strength * closeness * closeness / LAYERS)

		for i in LAYERS:
			_stamp(points, _triangles[index], throw * float(i + 1) / LAYERS, shade)


## One copy of a shadow, pushed by `step`. Triangles rather than one call:
## `draw_colored_polygon` only fills a convex shape honestly, and ground almost
## never is one.
func _stamp(points: PackedVector2Array, triangles: PackedInt32Array,
		step: Vector2, shade: Color) -> void:
	var i := 0
	while i + 2 < triangles.size():
		draw_colored_polygon(PackedVector2Array([
			points[triangles[i]] + step,
			points[triangles[i + 1]] + step,
			points[triangles[i + 2]] + step,
		]), shade)
		i += 3
