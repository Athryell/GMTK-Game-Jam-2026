## The light an entity gives off. It follows `Game.plane_changed` itself, so
## hosts attach one and never mention it again. Hazards carry one so they stay
## readable at any `world_light`.
class_name EntityLight
extends PointLight2D

var plane: Planes.Kind = Planes.Kind.BOTH
## Per-light multiplier on the global `entity_light_energy`.
var energy_scale := 1.0
## Breaths per second; 0 means steady and stops `_process` entirely.
var pulse_rate := 0.0
## How much of `energy_scale` a breath swings.
var pulse_depth := 0.0

var _pulse := 0.0


## Builds and attaches a light to `host`, centred on its rectangle. Entity
## origins are top-left corners, hence the `size / 2` offset.
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
	# A ghost in the other plane must not light this one.
	enabled = Planes.is_active(plane, current)
	_refresh()


## The only place `energy` is written, so one tuning slider moves every light.
func _refresh() -> void:
	var breath := 1.0 + pulse_depth * sin(_pulse * pulse_rate)
	energy = Tuning.cfg.entity_light_energy * energy_scale * breath
