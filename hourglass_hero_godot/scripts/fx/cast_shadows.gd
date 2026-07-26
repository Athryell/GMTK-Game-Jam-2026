## The solids' shadows. Every solid gets a [LightOccluder2D] built from the same
## outline it is drawn from, so the player's lamp does not arrive behind it.
##
## Subtractive: nothing is painted over the world. What you see in a shadow is
## the world with the lamp taken out of it, which is why two shadows crossing
## are no darker than one and a shadow never darkens the thing that cast it.
##
## Occluders are parented to their caster, so a moving platform drags its shadow
## along and unloading a level takes every occluder with it.
class_name CastShadows
extends Node2D

## The light mask an occluder in the player's plane sits on, matching the lamp's
## `shadow_item_cull_mask`. A solid in the other plane is taken off it.
const MASK := 1

## How far an occluder is pulled inside its solid, in px. The shadow map darkens
## everything past the first thing a ray meets, the caster included, so an
## outline sitting exactly on the drawn surface bands along it. Pulled in, the
## lit face is the stone's own and the seam is buried under it.
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
	# A slab thinner than twice the inset turns itself inside out; it keeps its
	# own outline rather than a knot.
	shape.polygon = inset if Polygons.winding(inset) == Polygons.winding(outline) \
		else outline
	# Both faces block: these are closed rings, and the level is walked from
	# either side of one.
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
