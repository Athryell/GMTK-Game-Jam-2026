## The solids' shadows. Every solid gets a [LightOccluder2D] built from the same
## outline it is drawn from, so the player's lamp does not arrive behind it.
##
## Subtractive: nothing is painted over the world, which is why two shadows
## crossing are no darker than one. Occluders are parented to their caster, so a
## moving platform drags its shadow along and unloading a level takes them all.
class_name CastShadows
extends Node2D

## Matches the lamp's `shadow_item_cull_mask`.
const MASK := 1

## How far an occluder is pulled inside its solid, in px. The shadow map darkens
## everything past the first thing a ray meets, the caster included, so an
## outline sitting exactly on the drawn surface bands along it.
const INSET := 3.0

var _occluders: Array[LightOccluder2D] = []
## Per occluder, parallel to `_occluders`.
var _planes: Array[Planes.Kind] = []


func _ready() -> void:
	Game.plane_changed.connect(_on_plane_changed)


## Called on every level load, once the scene exists.
func configure(level: Level) -> void:
	_occluders.clear()
	_planes.clear()
	for node in level.find_children("*", "Platform", true, false):
		var slab := node as Platform
		_add(slab, slab.plane, slab.shadow_outline())
	for node in level.find_children("*", "Terrain", true, false):
		var ground := node as Terrain
		_add(ground, ground.plane, ground.shadow_outline())
	_on_plane_changed(Game.plane)


func _add(caster: Node2D, plane: Planes.Kind, outline: PackedVector2Array) -> void:
	if outline.size() < 3:
		return
	var inset := Polygons.grow(outline, -INSET)
	var shape := OccluderPolygon2D.new()
	# A slab thinner than twice the inset turns itself inside out.
	shape.polygon = inset if Polygons.winding(inset) == Polygons.winding(outline) \
		else outline
	# These are closed rings, and a level is walked from either side of one.
	shape.cull_mode = OccluderPolygon2D.CULL_DISABLED
	var occluder := LightOccluder2D.new()
	occluder.occluder = shape
	caster.add_child(occluder)
	_occluders.append(occluder)
	_planes.append(plane)


func _on_plane_changed(current: Planes.Kind) -> void:
	for i in _occluders.size():
		var occluder := _occluders[i]
		if not is_instance_valid(occluder):
			continue
		# A solid in the other plane is walk-through, so it casts nothing.
		var active := Planes.is_active(_planes[i], current)
		occluder.occluder_light_mask = MASK if active else 0
