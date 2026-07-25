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
## Multiplies `entity_light_energy`, so one slider still moves every light in
## the game while a door can stay brighter than a spike.
var energy_scale := 1.0
## Breaths per second, and how much of `energy_scale` a breath swings. At rate 0
## the light is steady and does not tick at all.
var pulse_rate := 0.0
var pulse_depth := 0.0

var _pulse := 0.0


## Builds and attaches a light to `host`, centred on its rectangle.
##
## Entity origins are top-left corners; a light left on the corner lights the
## room from outside the object it belongs to.
static func attach(host: Node2D, entity_plane: Planes.Kind, size: Vector2,
		tint: Color, radius: float, scale := 1.0,
		rate := 0.0, depth := 0.0) -> EntityLight:
	var light := EntityLight.new()
	light.plane = entity_plane
	light.color = tint
	light.texture_scale = LightKit.scale_for(radius)
	light.energy_scale = scale
	light.pulse_rate = rate
	light.pulse_depth = depth
	light.position = size / 2.0
	host.add_child(light)
	return light


func _ready() -> void:
	texture = LightKit.falloff()
	shadow_enabled = false
	set_process(pulse_rate > 0.0)
	Game.plane_changed.connect(_on_plane_changed)
	Tuning.changed.connect(_refresh)
	_on_plane_changed(Game.plane)


func _process(delta: float) -> void:
	_pulse += delta
	_refresh()


func _on_plane_changed(current: Planes.Kind) -> void:
	# A ghost is a thing in the other plane. It must not light this one.
	enabled = Planes.is_active(plane, current)
	_refresh()


## The one place a scale becomes a brightness. Every light in the game passes
## through here, which is what lets a single slider move all of them at once.
func _refresh() -> void:
	var breath := 1.0 + pulse_depth * sin(_pulse * pulse_rate)
	energy = Tuning.cfg.entity_light_energy * energy_scale * breath
