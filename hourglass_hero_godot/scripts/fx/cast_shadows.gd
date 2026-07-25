## The terrain's shadows, drawn by hand: each slab is stamped again, pushed away
## from the lamp. Replaces Godot's 2D shadow map, which bands badly here because
## the player's lamp sits on the surfaces it lights.
##
## Must sit BETWEEN the backdrop and the level in `main.tscn` — a slab covering
## its own stamp is what keeps a shadow off the thing that cast it.
class_name CastShadows
extends Node2D

## Stacked copies per shadow, each pushed further and carrying 1/LAYERS of the
## darkness: a penumbra without a blur or a shader.
const LAYERS := 4

## How much wider than its caster a shadow is drawn, in px.
const SPREAD := 2.0

var lamp: Node2D
var _casters: Array[Platform] = []
var _reach := 1.0


## Called on every level load. Only the list is cached; positions are read per
## frame, since platforms move.
func configure(level: Level) -> void:
	_casters.clear()
	for node in level.find_children("*", "Platform", true, false):
		_casters.append(node as Platform)


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

	for caster in _casters:
		if not is_instance_valid(caster):
			continue
		# A slab in the other plane is walk-through, so it casts nothing.
		if not Planes.is_active(caster.plane, Game.plane):
			continue

		var rect := Rect2(to_local(caster.global_position), caster.size)
		var away := rect.get_center() - origin
		var distance := away.length()
		# Past the edge of the light, or the lamp is inside the slab and there
		# is no "away" to push towards.
		if distance >= _reach or distance < 0.001:
			continue

		# Throw and darkness both fall off towards the rim of the light; the
		# darkness is squared so shadows fade out before they shrink away.
		var closeness := 1.0 - distance / _reach
		var throw := away / distance * cfg.shadow_throw * closeness
		var shade := Color(0.0, 0.0, 0.02, cfg.shadow_strength * closeness * closeness / LAYERS)
		var grown := rect.grow(SPREAD)

		for i in LAYERS:
			var step := throw * float(i + 1) / LAYERS
			draw_rect(Rect2(grown.position + step, grown.size), shade)
