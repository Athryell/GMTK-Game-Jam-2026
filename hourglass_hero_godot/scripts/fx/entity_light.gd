## The light an entity gives off, which knows on its own when to go out.
##
## Every entity in this game already answers the same question the same way —
## "am I in the player's plane?" — so this asks it directly instead of being
## told. A door, a spring, a pad and a spike attach one of these in `_ready()`
## and then never mention it again: no `_light` field to remember, no line to
## add inside `_on_plane_changed`, and no way for one of the five to be left out
## when the contract changes.
##
## Hazards carry a light for a reason beyond looks. Darkening the world for the
## lights would otherwise have made spikes harder to see than they were before,
## which turns atmosphere into unfair deaths. A hazard that emits its own light
## is readable at any `world_light`.
class_name EntityLight
extends PointLight2D

var plane: Planes.Kind = Planes.Kind.BOTH
var tint := Color.WHITE
var radius := 90.0
## Multiplies `entity_light_energy`, so one slider still moves every light in
## the game while a door can stay brighter than a spike.
var energy_scale := 1.0


## Builds and attaches a light to `host`, centred on its rectangle.
##
## Entity origins are top-left corners; a light left on the corner lights the
## room from outside the object it belongs to.
static func attach(host: Node2D, entity_plane: Planes.Kind, size: Vector2,
		tint_: Color, radius_: float, energy_scale_ := 1.0) -> EntityLight:
	var light := EntityLight.new()
	light.plane = entity_plane
	light.tint = tint_
	light.radius = radius_
	light.energy_scale = energy_scale_
	light.position = size / 2.0
	host.add_child(light)
	return light


func _ready() -> void:
	texture = LightKit.falloff()
	texture_scale = radius * 2.0 / LightKit.TEXTURE_SIZE
	color = tint
	shadow_enabled = false
	Game.plane_changed.connect(_on_plane_changed)
	Tuning.changed.connect(_refresh)
	_on_plane_changed(Game.plane)


func _on_plane_changed(current: Planes.Kind) -> void:
	# A ghost is a thing in the other plane. It must not light this one.
	enabled = Planes.is_active(plane, current)
	_refresh()


func _refresh() -> void:
	energy = Tuning.cfg.entity_light_energy * energy_scale
